#!/usr/bin/perl

use strict;
use warnings;

BEGIN {
    use FindBin;
    use lib "$FindBin::Bin/../lib";
}

use Getopt::Long qw(:config no_auto_abbrev);
use MFR;
use MFR::Accreditation;

GetOptions(
    'cachedir=s' => \$MFR::cachedir,
);

my $dbix = MFR::Accreditation::dbix();

{
    #my $exhibits_json = MFR::get_json(3);
    my $exhibits_json = MFR::get_view_json(319, 658);
    
    $dbix->txn(sub {
        $dbix->dbh->do("LOCK TABLES exhibits WRITE");
        $dbix->dbh->do("TRUNCATE TABLE exhibits");
        
        my $sth = $dbix->dbh->prepare("INSERT INTO exhibits SET id = ?, oid = ?, category = ?,
            badges_category = ?, exhibitor_name = ?, title = ?, max_setup_badges = ?, max_event_badges = ?");
        
        foreach my $e (@{ $exhibits_json->{records} }) {
            next unless $e->{field_148} =~ /^Signed (?:Offline|Online)$/;
            
            $sth->execute(
                $e->{field_117},
                $e->{id},
                $e->{field_122},
                ($e->{field_122} =~ /^(?:sponsors|partners)$/) ? 'partner' : 'maker',
                join(' - ', grep defined($_), $e->{field_118}, $e->{field_617}),
                $e->{field_364} // '',
                $e->{field_136},
                $e->{field_139},
            );
        }
        
        $dbix->dbh->do("UNLOCK TABLES");
    });
}

{
    #my $projects_json = MFR::get_json(2);
    my $projects_json = MFR::get_view_json(319, 657);
    
    $dbix->txn(sub {
        $dbix->dbh->do("LOCK TABLES projects WRITE");
        $dbix->dbh->do("TRUNCATE TABLE projects");
        
        my $sth = $dbix->dbh->prepare("INSERT INTO projects SET id = ?, oid = ?,
            exhibit_oid = ?, title = ?, author = ?");
        
        foreach my $p (@{ $projects_json->{records} }) {
            next if !@{ $p->{field_29_raw} };
            next unless $p->{field_19} =~ /^Selected$/;
            
            $sth->execute(
                $p->{field_30},
                $p->{id},
                $p->{field_29_raw}[0]{id},
                $p->{field_10},
                $p->{field_12},
            );
        }
        
        $dbix->dbh->do("UNLOCK TABLES");
    });
}

{
    #my $locations_json = MFR::get_json(5);
    my $locations_json = MFR::get_view_json(319, 659);
    
    $dbix->txn(sub {
        $dbix->dbh->do("LOCK TABLES locations WRITE");
        $dbix->dbh->do("TRUNCATE TABLE locations");
        
        my $sth = $dbix->dbh->prepare("INSERT INTO locations SET oid = ?,
            exhibit_oid = ?, public_name = ?, gate = ?");
        
        foreach my $loc (@{ $locations_json->{records} }) {
            next if !@{ $loc->{field_111_raw} };
            
            $sth->execute(
                $loc->{id},
                $loc->{field_111_raw}[0]{id},
                $loc->{field_454},
                $loc->{field_592},
            );
        }
        
        $dbix->dbh->do("UNLOCK TABLES");
    });
}

{
    #my $events_json = MFR::get_json(8);
    my $events_json = MFR::get_view_json(319, 660);
    
    $dbix->txn(sub {
        $dbix->dbh->do("LOCK TABLES events WRITE");
        $dbix->dbh->do("TRUNCATE TABLE events");
        
        my $sth = $dbix->dbh->prepare("INSERT INTO events SET id = ?, oid = ?,
            badges_category = ?, title = ?, speaker = ?, category = ?, max_badges = ?");
        
        foreach my $e (@{ $events_json->{records} }) {
            next unless $e->{field_426} =~ /^Signed (?:Offline|Online)$/;
            
            $sth->execute(
                $e->{field_76},
                $e->{id},
                ($e->{field_220} eq 'Performance') ? 'maker' : 'speaker',
                join(' - ', grep $_, $e->{field_48}, $e->{field_171}),
                $e->{field_110},
                (($e->{field_391} // '') eq 'Cortocircuiti') ? 'Cortocircuiti' : $e->{field_220},
                $e->{field_450},
            );
        }
        
        $dbix->dbh->do("UNLOCK TABLES");
    });
}

__END__
