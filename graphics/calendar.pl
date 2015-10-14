#!/usr/bin/perl

use strict;
use warnings;

BEGIN {
    use FindBin;
    use lib "$FindBin::Bin/../accreditation/lib";
}

use DateTime;
use Encode qw(decode);
use Getopt::Long qw(:config no_auto_abbrev);
use HTML::Escape qw(escape_html);
use List::MoreUtils qw(uniq);
use List::Util qw(first);
use MFR;
use Sort::Naturally;
use XXX;
$|++;

my ($room, $output_file, $style);
GetOptions(
    'cachedir=s'    => \$MFR::cachedir,
    'room=s'        => \$room,
    'output|o=s'    => \$output_file,
    'style=s'       => \$style,
);
die "Missing --output\n" unless $output_file;

$style //= 'program';

{
    printf "Loading data... ";
    my $events_json = MFR::get_json(8);
    my $instances_json = MFR::get_json(14);
    printf "Done.\n";
    
    open my $fh, '>', $output_file;
    binmode $fh, ':utf8';
    print $fh <<"EOF";
<head>
<meta charset="UTF-8">
<meta http-equiv="content-type" content="text/html; charset=UTF-8">
</head>
EOF

    # sort locations by public location, day, hour
    @{ $instances_json->{records} } = sort {
        ($a->{field_200} cmp $b->{field_200}) || ($a->{field_314} cmp $b->{field_314}) || ($a->{field_199} cmp $b->{field_199})
    } @{ $instances_json->{records} };
    
    my @locations = nsort uniq map $_->{field_200_raw}[0]{identifier}, @{ $instances_json->{records} };
    
    my %count = ();
    foreach my $loc_name (@locations) {
        next if $loc_name =~ /Kids/i && $style eq 'program';
        
        if ($style eq 'program') {
            printf $fh "<h2>%s</h2>\n\n", $loc_name;
        }
        
        foreach my $day (16, 17, 18) {
            my @instances = grep { $_->{field_314} == $day && $_->{field_200_raw}[0]{identifier} eq $loc_name }
                @{ $instances_json->{records} };
            next if !@instances;
            
            if ($style eq 'program') {
                printf $fh "<h3>%s</h3>\n\n",
                    ($day == 16) ? 'Friday'
                        : ($day == 17) ? 'Saturday'
                        : 'Sunday';
            } else {
                printf $fh "<h1>%s - %d</h1>\n\n", $loc_name, $day;
            }
            
            my @events = map {
                my $i = $_;
                first { $_->{id} eq $i->{field_201_raw}[0]{id} } @{ $events_json->{records} }
            } @instances;
            
            my @topics = uniq sort grep $_ && $_ ne '-', map $_->{field_391_raw}, @events;
            
            if (@topics && $style eq 'rooms') {
                printf $fh "<h2>%s</h2>\n", escape_html(decode('utf-8', join ' - ', @topics));
            }
            
            foreach my $k (0..$#instances) {
                my $i = $instances[$k];
                my $event = $events[$k];
            
                next unless $event->{field_426} =~ /^Signed/;
                next if $event->{field_426} eq 'User Cancelled';
                
                my $title_en = $event->{field_48_raw} // '';
                my $title_it = $event->{field_171_raw} // '';
                $title_en =~ s/^-$//;
                $title_it =~ s/^-$//;
            
                my $title;
                if ($title_en eq $title_it) {
                    $title = $title_en;
                } elsif ($title_en && $title_it) {
                    $title = "$title_en - $title_it";
                } else {
                    $title = $title_en || $title_it;
                }
            
                next if !$title;
                
                $count{$loc_name}++;
                my $start = sprintf '%d.%02d',
                    (($i->{field_199_raw}{am_pm} eq 'PM' ? 12 : 0) + ($i->{field_199_raw}{hours} % 12)) % 24,
                    $i->{field_199_raw}{minutes};
                my $end = sprintf '%d.%02d',
                    (($i->{field_389_raw}{am_pm} eq 'PM' ? 12 : 0) + ($i->{field_389_raw}{hours} % 12)) % 24,
                    $i->{field_389_raw}{minutes};
                my $speaker = $event->{field_110_raw};
                $speaker =~ s/^-$//;
                
                if ($style eq 'rooms') {
                    printf $fh "<h3>%s-%s</h3>\n", $start, $end;
                    print $fh "<h4>";
                    print $fh escape_html(decode('utf-8', $title));
                    print $fh "</h4>\n";
                    
                    # speaker
                    if ($speaker) {
                        print $fh "<h5>";
                        printf $fh "<i>[%s]</i>", escape_html(decode('utf-8', $speaker));
                        print $fh "</h5>\n";
                    }
                } else {
                    printf $fh "<p><small>%s-%s:</small> %s",
                        $start, $end,
                        escape_html(decode('utf-8', $title));
                
                    # speaker
                    if ($speaker) {
                        printf $fh " <i>[%s]</i>", escape_html(decode('utf-8', $speaker));
                    }
                }
                
                print $fh "\n\n";
            }
        }
    }
}

__END__
