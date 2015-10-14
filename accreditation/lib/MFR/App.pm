package MFR::APP;
use Dancer ':syntax';
use strict;
use warnings;
use Cwd;
use MFR;
use MFR::Accreditation;

our $VERSION = '1.0';

my $dbix = MFR::Accreditation::dbix();

get '/' => sub {
    template 'index';
};

get '/search' => sub {
    my $badge_local_id = param 'same_name_as_lid';
    redirect '/' if !$badge_local_id;
    
    my $badge = $dbix->table('badges')->find($badge_local_id);
    my $badges = $dbix->table('badges')->search({
        name        => $badge->name,
        lastname    => $badge->lastname,
    });
    
    if (param 'collected') {
        $badges = $badges->search({ checkin => { '!=' => undef } });
    }
    
    my $exhibits = $dbix->table('exhibits')->search({
        oid => { -in => [ map $_->exhibit_oid, $badges->search({ exhibit_oid => { '!=' => undef } })->all ] },
    });
    
    my $events = $dbix->table('events')->search({
        oid => { -in => [ map $_->event_oid, $badges->search({ event_oid => { '!=' => undef } })->all ] },
    });
    
    template 'search_results', {
        query       => $badge->name . " " . $badge->lastname,
        exhibits    => $exhibits,
        events      => $events,
    };
};

post '/search' => sub {
    my $query = param 'query';
    redirect '/' if !$query;
    
    my $projects = $dbix->table('projects')->search([
        {
            id => $query,
        },
        {
            title => { -like => "%$query%" },
        },
        {
            author => { -like => "%$query%" },
        }
    ]);
    
    my $locations = $dbix->table('locations')->search([
        {
            public_name => $query,
        },
    ]);
    
    my $badges = $dbix->table('badges')->search([
        {
            name => { -like => "%$query%" },
        },
        {
            lastname => { -like => "%$query%" },
        },
    ]);
    
    my $exhibits = $dbix->table('exhibits')->search([
        {
            exhibitor_name => { -like => "%$query%" },
        },
        {
            title => { -like => "%$query%" },
        },
        {
            oid => { -in => [ map $_->exhibit_oid, $projects->all ] },
        },
        {
            oid => { -in => [ map $_->exhibit_oid, $locations->all ] },
        },
        {
            oid => { -in => [ map $_->exhibit_oid, $badges->search({ exhibit_oid => { '!=' => undef } })->all ] },
        },
    ])->limit(50);
    
    my $events = $dbix->table('events')->search([
        {
            id => $query,
        },
        {
            id => { -like => "_$query" },
        },
        {
            title => { -like => "%$query%" },
        },
        {
            speaker => { -like => "%$query%" },
        },
        {
            oid => { -in => [ map $_->event_oid, $badges->search({ event_oid => { '!=' => undef } })->all ] },
        },
    ])->limit(50);
    
    template 'search_results', {
        exhibits    => $exhibits,
        events      => $events,
    };
};

get '/exhibit' => sub {
    my $exhibit = $dbix->table('exhibits')->find({ 'me.oid' => param 'oid' })
        or redirect '/';
    
    my $badges = filter_badges($exhibit->badges);
    
    template 'exhibit', {
        exhibit      => $exhibit,
        setup_badges => $badges->search({ 'me.badge_type' => 'setup' })->order_by('me.lastname'),
        event_badges => $badges->search({ 'me.badge_type' => 'event' })->order_by('me.lastname'),
    };
};

get '/event' => sub {
    my $event = $dbix->table('events')->find({ 'me.oid' => param 'oid' })
        or redirect '/';
    
    my $badges = filter_badges($event->badges);
    
    template 'event', {
        event        => $event,
        event_badges => $badges->order_by('me.lastname'),
    };
};

sub filter_badges {
    my ($badges) = @_;
    
    return $badges
        ->left_join('badges_name_count', { 'me.name' => 'badges_name_count.name', 'me.lastname' => 'badges_name_count.lastname' })
        ->select_also(['badges_name_count.badge_count' => 'same_name_count'])
        ->left_join('collected_badges', { 'me.name' => 'collected_badges.name', 'me.lastname' => 'collected_badges.lastname' })
        ->select_also(['collected_badges.local_id' => 'collected_badge_local_id']);
}

post '/checkin' => sub {
    my $badges = param 'badges';
    $badges = [$badges] if ref($badges) ne 'ARRAY';
    
    my $badges_rs = $dbix->table('badges')->search({
        local_id    => $badges,
        checkin     => undef,
    });
    
    if (param 'delete') {
        $badges_rs->update({
            deleted => 1,
            to_sync => 1,
        });
    } else {
        $badges_rs->update({
            checkin                 => \ "NOW()",
            checkin_person          => param('checkin_person'),
            checkin_person_contact  => param('checkin_person_contact'),
            to_sync => 1,
        });
    }
    
    if (param 'exhibit_oid') {
        redirect '/exhibit?oid=' . param('exhibit_oid');
    } elsif (param 'event_oid') {
        redirect '/event?oid=' . param('event_oid');
    } else {
        redirect '/';
    }
};

post '/add' => sub {
    $dbix->table('badges')->insert({
        name        => param('name'),
        lastname    => param('lastname'),
        badge_type  => param('badge_type'),
        exhibit_oid => param('exhibit_oid') || undef,
        event_oid   => param('event_oid') || undef,
        to_sync     => 1,
    });
    
    if (param 'exhibit_oid') {
        redirect '/exhibit?oid=' . param('exhibit_oid');
    } elsif (param 'event_oid') {
        redirect '/event?oid=' . param('event_oid');
    } else {
        redirect '/';
    }
};

get '/cancel' => sub {
    my $badge = $dbix->table('badges')->search({
        local_id => param('lid'),
        oid      => [ undef, param('oid') ],
    })->single;
    
    if ($badge) {
        $badge->update({
            checkin                 => undef,
            checkin_person          => undef,
            checkin_person_contact  => undef,
            deleted                 => undef,
            to_sync                 => 1,
        });
    
        if ($badge->exhibit_oid) {
            redirect '/exhibit?oid=' . $badge->exhibit_oid;
            return;
        } elsif ($badge->event_oid) {
            redirect '/event?oid=' . $badge->event_oid;
            return;
        }
    }
    
    redirect '/';
};

get '/status' => sub {
    my $badges = $dbix->table('badges')->search([
        {
            exhibit_oid => { '!=', undef },
        },
        {
            event_oid => { '!=', undef },
        },
    ]);
    
    template 'status', {
        setup_collected     => $badges->search({ badge_type => 'setup', checkin => { '!=' => undef } })->count,
        setup_not_collected => $badges->search({ badge_type => 'setup', checkin => undef })->count,
        event_collected     => $badges->search({ badge_type => 'event', checkin => { '!=' => undef } })->count,
        event_not_collected => $badges->search({ badge_type => 'event', checkin => undef })->count,
    };
};

42;
