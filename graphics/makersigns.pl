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

my ($project_id, $output_file, $style);
GetOptions(
    'cachedir=s'    => \$MFR::cachedir,
    'project=i'     => \$project_id,
    'output|o=s'    => \$output_file,
);
die "Missing --output\n" unless $output_file;

{
    printf "Loading data... ";
    my $projects_json = MFR::get_json(2);
    printf "Done.\n";
    
    open my $fh, '>', $output_file;
    binmode $fh, ':utf8';
    print $fh <<"EOF";
<html>
<head>
<meta charset="UTF-8">
<meta http-equiv="content-type" content="text/html; charset=UTF-8">
</head>
EOF
    
    # sort projects by location
    @{ $projects_json->{records} } = sort { $a->{field_618} cmp $b->{field_618} }
        grep $_->{field_618}, @{ $projects_json->{records} };
    
    my %count = ();
    foreach my $p (@{ $projects_json->{records} }) {
        # Ignore projects with no exhibit
        my $exhibit_oid = $p->{field_29_raw}[0]{id} or next;
        
        # Only consider Selected projects
        next if $p->{field_19} ne 'Selected';
        
        next if $project_id && $project_id != $p->{field_30};
        
        $p->{"field_${_}_raw"} =~ s/^[-.]$// for grep defined($p->{"field_${_}_raw"}), qw(158 159 90 160 89 157);
        
        printf $fh "<h1>%s</h1>\n", escape_html($p->{field_10_raw});
        printf $fh "<h2>%s</h2>\n", escape_html($p->{field_12_raw});
        printf $fh "<h3>%s</h3>\n", escape_html($p->{field_89_raw}) if $p->{field_89_raw};
        printf $fh "<h4>%s</h4>\n", escape_html($p->{field_157_raw}) if $p->{field_157_raw};
        
        printf $fh "<h5>%s</h5>\n", escape_html($p->{field_618});
    }
    
    print $fh "</html>\n";
}

__END__
