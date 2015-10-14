package MFR::Accreditation;
use strict;
use warnings;

use DBIx::Lite;

sub dbix {
    my $dbix = DBIx::Lite->connect("dbi:mysql:dbname=mfr15", 'root', '',
        { mysql_enable_utf8 => 1 });
    
    $dbix->schema->one_to_many('exhibits.oid' => 'locations.exhibit_oid');
    $dbix->schema->one_to_many('exhibits.oid' => 'badges.exhibit_oid');
    $dbix->schema->one_to_many('exhibits.oid' => 'projects.exhibit_oid');
    $dbix->schema->one_to_many('events.oid' => 'badges.event_oid');
    $dbix->schema->table('badges')->autopk('local_id');
    
    return $dbix;
}

42;
