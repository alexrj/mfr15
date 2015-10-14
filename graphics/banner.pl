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
use List::MoreUtils qw(uniq);
use List::Util qw(first max);
use MFR;
use PDF::API2;
use XXX;
$|++;

use constant mm => 25.4 / 72;
use constant MF_BLUE => '#009fe3';
use constant MF_RED  => '#dc0714';
use constant CENTER_Y => 150;
use constant TITLE_X => 740;
use constant TITLE_MIN_Y => 50;
use constant TITLE_MAX_Y => 262;
use constant TITLE_CENTER_Y => (TITLE_MIN_Y + TITLE_MAX_Y)/2;
use constant SPONSORS_TITLE_MAX_WIDTH => (2300 - TITLE_X);
use constant MAKERS_TITLE_MAX_WIDTH   => (2580 - TITLE_X);

my ($test, $booth, $black, $type);
GetOptions(
    'test'          => \$test,
    'cachedir=s'    => \$MFR::cachedir,
    'booth=s'       => \$booth,
    'black'         => \$black,
    'type=s'        => \$type,
);

if ($test) {
    my $pdf = PDF::API2->open('banner_makers.pdf');
    my $font = $pdf->ttfont('bentonsans-black-webfont.ttf');
    
    my $page = $pdf->openpage(1);
    
    booth_public_number('B14', $page, $font, MF_BLUE);
    
    {
        my $text = $page->text;
        $text->fillcolor($black ? 'black' : MF_BLUE);
        $text->font($font, 123/mm);
        $text->translate(TITLE_X/mm, 150/mm);
        $text->text('MARIO ROSSI');
    }
    
    {
        my $text = $page->text;
        $text->fillcolor($black ? 'black' : MF_BLUE);
        $text->font($font, 81/mm);
        $text->translate(TITLE_X/mm, 65/mm);
        $text->text(uc 'Titolo del progetto');
    }
    
    artigiani_digitali($page, $font);
    
    $pdf->saveas('Banner/output/B14.pdf');
    
    exit;
}

{
    printf "Loading data... ";
    my $locations_json = MFR::get_json(5);
    my $exhibits_json = MFR::get_json(3);
    printf "Done.\n";
    
    # sort locations by public location
    @{ $locations_json->{records} } = sort { $a->{field_454} cmp $b->{field_454} } @{ $locations_json->{records} };
    
    foreach my $loc (@{ $locations_json->{records} }) {
        next if $loc->{field_42} !~ /^(?:3x2|4x1\.5)$/;
        
        my $b = $loc->{field_454};
        next if defined $booth && $booth ne $b;
        
        my $exhibit_oid = $loc->{field_111_raw}[0]{id};
        my $e;
        if ($exhibit_oid) {
            $e = first { $_->{id} eq $exhibit_oid } @{$exhibits_json->{records}};
            if (!$e) {
                die "Exhibit $exhibit_oid not found! (booth = $b)\n";
            }
        }
        my $is_sponsor = $e && $e->{field_122} =~ /^(?:sponsors|partners|universities)$/;
        my $max_width = $is_sponsor ? SPONSORS_TITLE_MAX_WIDTH : MAKERS_TITLE_MAX_WIDTH;
        
        next if defined($type) && (($type eq 'sponsors' && !$is_sponsor) || ($type eq 'makers' && $is_sponsor));
        
        my $pdf = PDF::API2->open
            ($is_sponsor ? 'Banner/banner_sponsors.pdf' : 'Banner/banner_makers.pdf');
        my $font = $pdf->ttfont('bentonsans-black-webfont.ttf');
        
        my $color = $black ? 'black'
            : $is_sponsor ? MF_RED
                : MF_BLUE;
        
        my $page = $pdf->openpage(1);
        
        booth_public_number($b, $page, $font, $color); 
        
        if ($e) {
            # Public Exhibitor Name
            write_title(
                $page,
                $font,
                $e->{field_118},
                $color,
                123,
                $max_width,
                $e->{field_364} ? 220 : TITLE_CENTER_Y,
            );
        
            # Public Title
            write_title(
                $page,
                $font,
                $e->{field_364},
                $color,
                81,
                $max_width,
                $e->{field_118} ? 100 : TITLE_CENTER_Y,
            );
            
            my @marks = @{ $e->{field_523_raw} // [] };
            warn "Booth $b needs more than two marks!!!\n" if @marks > 2;
            push @marks, $marks[0] if @marks == 1;
            if (@marks) {
                put_mark($pdf, $page, $marks[0], 158.5);
                put_mark($pdf, $page, $marks[1], 2742.5);
            }
        }
        
        $pdf->saveas(sprintf('Banner/output/%s/%s.pdf', ($is_sponsor ? 'sponsors' : 'makers'), $b));
        printf "Saved $b.pdf\n";
    }
}

sub booth_public_number {
    my ($b, $page, $font, $color) = @_;
    
    my $text = $page->text;
    $text->fillcolor($color);
    $text->font($font, 118/mm);
    $text->translate(500/mm, 45/mm);
    $text->text_center($b);
}

sub write_title {
    my ($page, $font, $string, $color, $fontsize, $max_width, $center_y) = @_;
    
    return if !$string;
    $string = uc decode('utf-8', $string);
    
    my $text = $page->text;
    $text->fillcolor($color);
    
    # determine font size
    $text->font($font, $fontsize/mm);
    {
        my $w = $text->advancewidth($string) * mm;
        if ($w > $max_width) {
            $fontsize = ($fontsize * $max_width)/$w;
            $text->font($font, $fontsize/mm);
        }
    }
    
    # determine placement
    $text->translate(TITLE_X/mm, ($center_y - $fontsize/2)/mm);
    
    # write
    $text->text($string);
}

sub put_mark {
    my ($pdf, $page, $mark, $x_center) = @_;
    
    my $orig_pdf = PDF::API2->open("Banner/$mark.pdf");
    my @bb = $orig_pdf->openpage(1)->get_mediabox;
    my @size = (($bb[2] - $bb[0])*mm, ($bb[3] - $bb[1])*mm);
    
    # box is 150x150mm
    my $box_size = 150;
    my $scale = $box_size / max(@size);
    
    my $xo = $pdf->importPageIntoForm($orig_pdf, 1);
    my $gfx = $page->gfx->formimage($xo, ($x_center - $box_size/2)/mm, (CENTER_Y - $box_size/2)/mm, $scale);
}

__END__
