#!/usr/bin/perl

BEGIN {
    use FindBin;
    use lib "$FindBin::Bin/../lib";
}

use strict;
use warnings;

use App;
use Encode qw(decode);
use Getopt::Long qw(:config no_auto_abbrev);
use List::MoreUtils qw(uniq);
use List::Util qw(first max);
use PDF::API2;
use XXX;
$|++;

our $MFR = 'mfr19';
use constant mm => 25.4 / 72;
use constant MF_BLUE => '#009fe3';
use constant MF_RED  => '#dc0714';
use constant TITLE_X => 1190/mm;
use constant TITLE_MIN_Y => 60/mm;
use constant TITLE_MAX_Y => 265/mm;
use constant LIMITED_TITLE_WIDTH => (2950/mm - TITLE_X);
use constant FULL_TITLE_WIDTH   => (3300/mm - TITLE_X);
our $TEMPLATE_DIR = "/var/www/$MFR/banner/templates";
our $OUTPUT_DIR = "/var/www/$MFR/banner/output";

our %topic_colors = (
    4 => '#52B24E',   # 82 178 78
    5 => '#264C8D',   # 38 76 141
    6 => '#2A8A72',   # 42 138 114
    7 => '#EE7A43',   # 238 122 67
    8 => '#58635A',   # 88 99 90
    9 => '#E13C7E',   # 225 60 126
    10 => '#9D4A83',  # 157 74 131
    uni => '#008E72', # 0 142 114
);

my ($booth, $batch, $black, $category, $exclude_category, $force_template);
GetOptions(
    'booth=s@'              => \$booth,
    'batch=s'               => \$batch,
    'black'                 => \$black,
    'category=s@'           => \$category,
    'exclude-category=s@'   => \$exclude_category,
    'template=s'            => \$force_template,
);

my $master = App::master();
my $app = App::master->table('apps')->find($MFR);

our ($page, $font);

{
    my $dbix = $app->dbix('location')->search({
            'f_type' => 'Shell Scheme (4x2m)',
        })
        ->left_join('o_exhibit', {
            'o_exhibit.id' => 'me.f_exhibit',
        })
        ->select(qw(
            me.f_code me.f_padded_code me.f_pavilion me.f_banner_template
            me.f_banner_num
            o_exhibit.f_public_exhibitor_name o_exhibit.f_public_title
            o_exhibit.f_main_topic
        ))
        ->order_by('f_code');
    
    if ($booth) {
        $dbix = $dbix->search({ 'me.f_code' => $booth });
    }
    if ($batch) {
        $dbix = $dbix->search({ 'me.f_banner_batch' => $batch });
    }
    if ($category) {
        $dbix = $dbix->search({ 'o_exhibit.f_category' => $category });
    }
    if ($exclude_category) {
        $dbix = $dbix->search({ 'o_exhibit.f_category' => { -not_in => $exclude_category } });
    }
    
    while (my $row = $dbix->next) {
        my $template = $force_template || $row->f_banner_template;
        
        my $max_width = $template =~ /_blank$/ ? FULL_TITLE_WIDTH : LIMITED_TITLE_WIDTH;
        
        my $pdf = PDF::API2->open("$TEMPLATE_DIR/$template.pdf");
        $font = $pdf->ttfont("$TEMPLATE_DIR/bentonsans-black-webfont.ttf");
        
        my $color = $black ? 'black'
            : $template =~ /^red/ ? MF_RED : MF_BLUE;
        
        $page = $pdf->openpage(1);
        
        booth_public_number($row->f_banner_num, $page, $font, $color); 
        
        my $s1_fontsize = actual_font_size($row->f_public_exhibitor_name, 81/mm, $max_width);
        my $s2_fontsize = actual_font_size($row->f_public_title, 123/mm, $max_width);
        
        if ($row->f_public_title) {
            my $margin = 10/mm;
            if ($s1_fontsize + $s2_fontsize + $margin > (TITLE_MAX_Y - TITLE_MIN_Y)) {
                warn "Too large - resizing\n";
                $s1_fontsize = (TITLE_MAX_Y - TITLE_MIN_Y) - ($s2_fontsize + $margin);
            }

            # spacing between the two lines
            my $spacing = (TITLE_MAX_Y - TITLE_MIN_Y - $s1_fontsize - $s2_fontsize)/3;

            write_title(
                $row->f_public_exhibitor_name,
                $color,
                $s1_fontsize,
                TITLE_X,
                TITLE_MAX_Y - $s1_fontsize - $spacing,
            );
            write_title(
                $row->f_public_title,
                $color,
                $s2_fontsize,
                TITLE_X,
                TITLE_MIN_Y + $spacing,
            );
        } else {
            # no title, center exhibitor name
            write_title(
                $row->f_public_exhibitor_name,
                $color,
                $s1_fontsize,
                TITLE_X,
                (TITLE_MAX_Y + TITLE_MIN_Y)/2 - $s1_fontsize/2,
            );
        }
        
        # Topic
        if ($template =~ /^blue_(\d+)/) {
            write_title(
                uc $row->f_main_topic,
                $topic_colors{$1},
                actual_font_size(uc $row->f_main_topic, 40/mm, 330/mm),
                3685/mm,
                75/mm,
                1, # centered
            );
        }
        
        # booth code
        write_title(
            $row->f_code,
            '#000000',
            15/mm,
            90/mm,
            20/mm,
            0, # centered,
        );
        
        $pdf->saveas(sprintf "$OUTPUT_DIR/%s.pdf", $row->f_padded_code);
        printf "Saved %s.pdf\n", $row->f_padded_code;
        
        $page = undef;
        $font = undef;
    }
}

sub booth_public_number {
    my ($b, $page, $font, $color) = @_;
    
    my $text = $page->text;
    $text->fillcolor($color);
    $text->font($font, 200/mm);
    $text->translate(882/mm, 80/mm);
    $text->text_center($b);
}

sub write_title {
    my ($string, $color, $fontsize, $x, $y, $centered_x, $rotate) = @_;
    
    return if !$string;
    #$string = uc decode('utf-8', $string);
    $string = uc $string;
    
    my $text = $page->text;
    $text->fillcolor($color);
    
    # determine font size
    $text->font($font, $fontsize);
    
    # determine placement
    $text->translate($x, $y);
    $text->rotate($rotate) if defined $rotate;
    
    # write
    if ($centered_x) {
        $text->text_center($string);
    } else {
        $text->text($string);
    }
    
    return $fontsize;
}

sub actual_font_size {
    my ($string, $fontsize, $max_width) = @_;
    
    my $text = $page->text;
    $text->font($font, $fontsize);
    my $w = $text->advancewidth($string);
    if ($w > $max_width) {
        $fontsize = ($fontsize * $max_width)/$w;
    }
    return $fontsize;
}

__END__
