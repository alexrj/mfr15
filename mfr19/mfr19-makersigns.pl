#!/usr/bin/perl

BEGIN {
    use FindBin;
    use lib "$FindBin::Bin/../lib";
}

use strict;
use warnings;

use App;
use HTML::Escape qw(escape_html);
use Imager::QRCode;
use List::MoreUtils qw(uniq);
use List::Util qw(first max);
use MIME::Base64 qw(encode_base64);
use XXX;
$|++;

our $MFR = 'mfr19';
our $OUTPUT_FILE = "/var/www/$MFR/makersigns.html";

my $master = App::master();
my $app = App::master->table('apps')->find($MFR);

my $dbix = $app->dbix('project')
    ->search({ f_status => 'Selected' })
    ->inner_join('o_exhibit', { 'me.f_exhibit' => 'o_exhibit.id' })
    ->search({ f_location_public_name => { '!=' => '' } })
    ->select_also('o_exhibit.f_location_number')
    ->order_by('o_exhibit.f_location_number');

open my $fh, '>', $OUTPUT_FILE;
binmode $fh, ':utf8';
print $fh <<"EOF";
<html>
<head>
<meta charset="UTF-8">
<meta http-equiv="content-type" content="text/html; charset=UTF-8">
</head>
EOF

while (my $row = $dbix->next) {
    my $url = sprintf 'https://www.mycicero.it/makerfairerome/QR/redirect?type=ex&ID=%d', $row->id;
    
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
    
    printf $fh "<h1>%s</h1>\n", escape_html($row->f_title);
    printf $fh "<h2>%s</h2>\n", escape_html($row->f_author)
        if $row->f_author;
    
    printf $fh "<h3>%s</h3>\n", escape_html($row->f_short_description_en)
        if $row->f_short_description_en;
    
    printf $fh "<h4>%s</h4>\n", escape_html($row->f_short_description_it)
        if $row->f_short_description_it;
    
    printf $fh "<h5>%s</h5>\n", escape_html($row->f_location_number);
}

print $fh "</html>\n";

print "Written to $OUTPUT_FILE\n";

__END__
