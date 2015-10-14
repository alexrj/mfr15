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
    my $exhibit = $dbix->table('exhibits')->find({ oid => param 'oid' })
        or redirect '/';
    
    template 'exhibit', {
        exhibit => $exhibit,
        setup_badges => $exhibit->badges->search({ badge_type => 'setup' })->order_by('lastname'),
        event_badges => $exhibit->badges->search({ badge_type => 'event' })->order_by('lastname'),
    };
};

get '/event' => sub {
    my $event = $dbix->table('events')->find({ oid => param 'oid' })
        or redirect '/';
    
    template 'event', {
        event => $event,
        event_badges => $event->badges->order_by('lastname'),
    };
};

post '/checkin' => sub {
    my $badges = param 'badges';
    $badges = [$badges] if ref($badges) ne 'ARRAY';
    
    $dbix->table('badges')->search({ local_id => $badges })->update({
        checkin => \ "NOW()",
        checkin_person => param('checkin_person'),
        checkin_person_contact => param('checkin_person_contact'),
        to_sync => 1,
    });
    
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
    my $badges = $dbix->table('badges');
    
    template 'status', {
        setup_collected     => $badges->search({ badge_type => 'setup', checkin => { '!=' => undef } })->count,
        setup_not_collected => $badges->search({ badge_type => 'setup', checkin => undef })->count,
        event_collected     => $badges->search({ badge_type => 'event', checkin => { '!=' => undef } })->count,
        event_not_collected => $badges->search({ badge_type => 'event', checkin => undef })->count,
    };
};

42;
