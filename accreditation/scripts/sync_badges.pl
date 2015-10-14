#!/usr/bin/perl

use strict;
use warnings;

BEGIN {
    use FindBin;
    use lib "$FindBin::Bin/../lib";
}

use DateTime;
use DateTime::Format::MySQL;
use Getopt::Long qw(:config no_auto_abbrev);
use MFR;
use MFR::Accreditation;
use XXX;
$|++;

GetOptions(
    'cachedir=s' => \$MFR::cachedir,
);

my $dbix = MFR::Accreditation::dbix();

{
    my $badges = $dbix->table('badges')->search({ to_sync => 1 });
    while (my $badge = $badges->next) {
        print "Syncing upstream... ";
        my %fields = (
            field_601 => $badge->checkin_person,
            field_602 => $badge->checkin_person_contact,
            field_621 => ($badge->deleted ? 'Yes' : 'No'),
        );
        if ($badge->checkin) {
            my $dt = DateTime::Format::MySQL->parse_datetime($badge->checkin);
            $fields{field_146} = {
                date    => $dt->strftime('%d/%m/%Y'),
                hours   => $dt->hour_12,
                minutes => $dt->minute,
                am_pm   => $dt->am_or_pm,
            };
        } else {
            $fields{field_146} = '';
        }
        
        if ($badge->oid) {
            # update an existing badge
            MFR::update(12, $badge->oid, { %fields });
            $badge->update({ to_sync => 0 });
        } else {
            # insert a new badge
            my $oid = MFR::insert(12, {
                field_137 => {
                    first => $badge->name,
                    last  => $badge->lastname,
                },
                %fields,
            });
            $badge->update({ oid => $oid });
            
            eval {
                # connect it to the exhibit or event
                if ($badge->exhibit_oid) {
                    my @badges_oids = map $_->oid, $dbix->table('badges')->search({
                        oid         => { '!=', undef },
                        exhibit_oid => $badge->exhibit_oid,
                        badge_type  => $badge->badge_type,
                    })->all;
                
                    MFR::update(3, $badge->exhibit_oid, {
                        ($badge->badge_type eq 'setup' ? 'field_140' : 'field_141') => [ @badges_oids ],
                    });
                } elsif ($badge->event_oid) {
                    my @badges_oids = map $_->oid, $dbix->table('badges')->search({
                        oid         => { '!=', undef },
                        event_oid   => $badge->event_oid,
                    })->all;
                
                    MFR::update(8, $badge->event_oid, {
                        field_451 => [ @badges_oids ],
                    });
                }
            
                $badge->update({ to_sync => 0 });
            };
            if ($@) {
                warn $@;
            }
        }
        print "Done.\n";
    }
}

{
    $dbix->txn(sub {
        $dbix->dbh->do("LOCK TABLES badges_import WRITE");
        $dbix->dbh->do("TRUNCATE TABLE badges_import");
        
        {
            my $sth = $dbix->dbh->prepare("INSERT INTO badges_import SET oid = ?,
                name = ?, lastname = ?, checkin = ?, checkin_person = ?,
                checkin_person_contact = ?, deleted = ?");
        
            my $badges_json = MFR::get_json(12);
            foreach my $b (@{ $badges_json->{records} }) {
                my $dt;
            
                if ($b->{field_146}) {
                    my ($month, $day, $year) = split /\//, $b->{field_146_raw}{date};
                    $dt = DateTime->new(
                        year    => $year,
                        month   => $month,
                        day     => $day,
                        hour    => (($b->{field_146_raw}{am_pm} eq 'PM' ? 12 : 0) + ($b->{field_146_raw}{hours} % 12)) % 24,
                        minute  => $b->{field_146_raw}{minutes},
                    );
                }
            
                $sth->execute(
                    $b->{id},
                    $b->{field_137_raw}{first},
                    $b->{field_137_raw}{last},
                    ($dt ? $dt->iso8601 : undef),
                    $b->{field_601},
                    $b->{field_602},
                    ($b->{field_621} eq 'Yes'),
                );
            }
        }
        
        {
            my $sth = $dbix->dbh->prepare("UPDATE badges_import SET exhibit_oid = ?, badge_type = ? 
                WHERE oid = ?");
            
            #my $exhibits_json = MFR::get_json(3);
            my $exhibits_json = MFR::get_view_json(319, 658);
            foreach my $e (@{ $exhibits_json->{records} }) {
                $sth->execute($e->{id}, 'setup', $_) for map $_->{id}, @{ $e->{field_140_raw} };
                $sth->execute($e->{id}, 'event', $_) for map $_->{id}, @{ $e->{field_141_raw} };
            }
        }
        
        {
            my $sth = $dbix->dbh->prepare("UPDATE badges_import SET event_oid = ?,
                badge_type = 'event' WHERE oid = ?");
            
            #my $events_json = MFR::get_json(8);
            my $events_json = MFR::get_view_json(319, 660);
            foreach my $e (@{ $events_json->{records} }) {
                $sth->execute($e->{id}, $_) for map $_->{id}, @{ $e->{field_451_raw} };
            }
        }
        
        $dbix->dbh->do("UNLOCK TABLES");
    });
    
    $dbix->txn(sub {
        $dbix->dbh->do("LOCK TABLES badges WRITE, badges AS b WRITE, badges_import AS i READ,
            badges_name_count WRITE");
        
        # delete all non-local badges that haven't been collected/deleted and do not exist anymore
        $dbix->dbh->do("DELETE FROM badges WHERE oid IS NOT NULL AND checkin IS NULL
            AND deleted = 0 AND oid NOT IN (SELECT oid FROM badges_import i)");
        
        # update all non-local badges that haven't been collected/deleted
        $dbix->dbh->do("UPDATE badges b INNER JOIN badges_import i ON (b.oid = i.oid)
            SET b.badge_type = i.badge_type, b.name = i.name, b.lastname = i.lastname,
            b.checkin = i.checkin, b.checkin_person = i.checkin_person,
            b.checkin_person_contact = i.checkin_person_contact, b.deleted = i.deleted
            WHERE b.oid IS NOT NULL AND b.checkin IS NULL AND b.deleted = 0");
        
        # insert new badges
        $dbix->dbh->do("INSERT IGNORE INTO badges (oid, exhibit_oid, event_oid, badge_type,
            name, lastname, checkin, checkin_person, checkin_person_contact, deleted)
            SELECT oid, exhibit_oid, event_oid, badge_type, name, lastname, checkin, 
            checkin_person, checkin_person_contact, deleted FROM badges_import i 
            WHERE oid NOT IN (SELECT oid FROM badges b)");
        
        $dbix->dbh->do("TRUNCATE TABLE badges_name_count");
        $dbix->dbh->do("INSERT INTO badges_name_count
            SELECT name, lastname, COUNT(*) FROM
                (SELECT name, lastname FROM badges GROUP BY name, lastname, exhibit_oid, event_oid) AS same_name
                GROUP BY name, lastname");
        
        $dbix->dbh->do("UNLOCK TABLES");
    });
}

__END__
