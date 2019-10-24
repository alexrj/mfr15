#!/usr/bin/perl

BEGIN {
    use FindBin;
    use lib "$FindBin::Bin/../lib";
}

use strict;
use warnings;

use App;
use Getopt::Long qw(:config no_auto_abbrev);
use HTML::Escape qw(escape_html);
use Imager::QRCode;
use List::MoreUtils qw(uniq);
use List::Util qw(first max);
use MIME::Base64 qw(encode_base64);
use URI::Escape qw(uri_escape);
use XXX;
$|++;
use utf8;

our $MFR = 'mfr19';
our $OUTPUT_FILE = "/var/www/$MFR/calendars.html";

my %opt;
GetOptions(
    'by-day' => \$opt{by_day},
);

my $master = App::master();
my $app = App::master->table('apps')->find($MFR);

open my $fh, '>', $OUTPUT_FILE;
binmode $fh, ':utf8';
print $fh <<"EOF";
<html>
<head>
<meta charset="UTF-8">
<meta http-equiv="content-type" content="text/html; charset=UTF-8">
</head>
<body>
EOF

my %days = qw(18 Venerdì 19 Sabato 20 Domenica);

my $dbix_loc = $app->dbix('location')
    ->search({
        f_type => [qw(Room Stage)],
        f_public_name => { -not_like => '%Kids%' },
    })
    ->order_by('me.f_public_name');

if ($opt{by_day}) {
    my @locs = $dbix_loc->all;
    foreach my $day (sort keys %days) {
        foreach my $loc (@locs) {
            day_loc($day, $loc);
        }
    }
} else {
    while (my $loc = $dbix_loc->next) {
        foreach my $day (sort keys %days) {
            day_loc($day, $loc);
        }
    }
}

print $fh "</body></html>\n";

sub day_loc {
    my ($day, $loc) = @_;
    
    my $dbix_inst = $app->dbix('event_instance')
        ->inner_join('o_event', { 'me.f_event' => 'o_event.id' })
        ->search({
            f_location          => $loc->id,
            f_day               => $day,
            'o_event.f_status'  => 'Selected',
            #'o_event.f_contract_status'  => ['Signed Online', 'Signed Offline'],
            'o_event.f_contract_status'  => { '!=' => 'Cancelled' },
            'o_event.f_hide'    => 0,
        })
        ->select('me.*')
        ->select_also('o_event.f_title_en', 'o_event.f_title_it', 'o_event.f_speaker',
            'o_event.f_full_id')
        ->order_by('f_start', 'f_title_en');
    
    return if $dbix_inst->count == 0;
    
    printf $fh "<h5>%s - %s</h5>\n",
        escape_html($loc->f_public_name),
        escape_html($days{$day} . ' ' . $day);
    
    while (my $row = $dbix_inst->next) {
        my $start = $row->f_start;
        my $end = $row->f_end;
        $start =~ s/:\d+$//;
        $end =~ s/:\d+$//;
        $start =~ s/:/./g;
        $end =~ s/:/./g;
        printf $fh "<h1>%s</h1>\n", escape_html("$start-$end");
        
        printf $fh "<h2>%s</h2>\n", escape_html($row->f_title_en // $row->f_title_it // '');
        printf $fh "<h3>%s</h3>\n", escape_html($row->f_title_it // '')
            if ($row->f_title_it // '') ne ($row->f_title_en // '');
        printf $fh "<h4>%s</h4>\n", escape_html($row->f_speaker);
    }


    my $url = sprintf 'https://www.mycicero.it/makerfairerome/QR/redirect?type=room&ID=%s',
        uri_escape($loc->f_public_name);
    my $qrcode = Imager::QRCode->new(
        size          => 2,
        margin        => 2,
        version       => 1,
        level         => 'M',
        casesensitive => 1,
        lightcolor    => Imager::Color->new(255, 255, 255),
        darkcolor     => Imager::Color->new(0, 0, 0),
    );
    my $img = $qrcode->plot($url);
    my $img_data;
    $img->write(data => \$img_data, type => 'png') or die "Failed to write PNG data";
    
    printf $fh "<img src=\"data:image/png;base64,%s\" />\n",
        encode_base64($img_data);
}

__END__
