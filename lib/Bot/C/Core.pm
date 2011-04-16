package Bot::C::Core;

=head1 NAME

Bot::C::Core - A singleton that implements the core bot controller.

=head1 SYNOPSIS

    use Bot::C::Core;

    # Enter the application's main loop.
    Bot::C::Core->instance()->run();

=cut

use common::sense;

use base 'Class::Singleton';

use Carp;
use JSON;
use List::MoreUtils qw(any);
use LWP::UserAgent;
use POE;
use POE::Component::IRC;
use Time::HiRes qw(time);

use Bot::V::IRC;

sub _new_instance
{
    my $class = shift;
    my $self = bless {}, $class;

    return $self;
}

# XXX Most of the logic in here needs to move somewhere else.
sub _ev_tick
{   
    my ($self) = @_[OBJECT];

    Bot::V::Log->instance()->log
    (
        'Checking Reddit for new /r/roguelikes posts'
    );

    my $ua = LWP::UserAgent->new();
    $ua->timeout(4);
    my $r = $ua->get('http://www.reddit.com/r/roguelikes/new/.json');
    if ($r->is_success)
    {
        my $json = JSON->new();
        my $data = $json->decode($r->decoded_content);

        my @links;
        $@ = q{};
        eval
        {
            my $raw_links_ref = $data->{data}->{children};
            for my $link_ref (@$raw_links_ref)
            {
                my $id = $link_ref->{data}->{id};
                next unless defined($id);

                my $db = Bot::M::DB->instance();
                next if $db->have_seen('reddit', $id);

                my %link = map
                {
                    $_ => $link_ref->{data}->{$_}
                } qw(id author title);

                $link{_url} = "http://redd.it/$link{id}";

                push(@links, \%link);

                $db->add_seen('reddit', $id);
            }
        };

        if ($@)
        {
            Bot::V::Log->instance()->log("Unable to parse Reddit JSON: $@");
        }
        else
        {
            for my $link_ref (@links)
            {
                Bot::V::Log->instance()->log
                (
                    "Saying Reddit link [$link_ref->{_url}]."
                );
                my $msg = "$link_ref->{author}: $link_ref->{title} " .
                          "<$link_ref->{_url}>";
                Bot::V::IRC->instance()->privmsg('#rrogue', $msg);
            }
        }
    }
    else
    {
        Bot::V::Log->instance()->log('Reddit request did not succeed');
    }

    $_[HEAP]->{next_alarm_time} = int(time() + 300 + rand(120));
    $_[KERNEL]->alarm(tick => $_[HEAP]->{next_alarm_time});
    Bot::V::Log->instance()->log
    (
        "Set next alarm [$_[HEAP]->{next_alarm_time}]"
    );
}

# The bot is starting up.
sub _ev_bot_start
{
    my ($self) = @_[OBJECT];

    $_[HEAP]->{next_alarm_time} = int(time() + 30 + rand(45));
    Bot::V::Log->instance()->log
    (
        "Set next alarm [$_[HEAP]->{next_alarm_time}]"
    );
    $_[KERNEL]->alarm(tick => $_[HEAP]->{next_alarm_time});

    Bot::V::IRC->instance()->start_session();
}

# The bot has successfully connected to a server.  Join a channel.
sub _ev_on_connect
{
    my ($self) = @_[OBJECT];

    my $config = Bot::M::Config->instance();

    my $password = $config->get_key('irc_nickserv_password');
    Bot::V::Log->instance()->log('Identifying to NickServ');
    Bot::V::IRC->instance()->privmsg('NickServ', "identify $password");

    for my $channel (@{$config->get_key('irc_channels')})
    {
        Bot::V::Log->instance()->log("Joining channel [$channel]");
        Bot::V::IRC->instance()->join($channel);
    }
}

# The bot has received a public message.  Parse it for commands and
# respond to interesting things.
sub _ev_on_public
{
    my ($self) = @_[OBJECT];

    my ($kernel, $who, $where, $msg) = @_[KERNEL, ARG0, ARG1, ARG2];
    my $nick    = (split /!/, $who)[0];
    my $channel = $where->[0];

    Bot::V::Log->instance()->log("MSG($channel) <$nick> $msg");

    my $config = Bot::M::Config->instance();
    my $nick = $config->get_key('irc_nick');

    # Query proxy to Henzell.
    if ($msg =~ /^\?\?/)
    {
        my $target = 'Henzell';
        Bot::V::Log->instance()->log("MSG_OUT(${target}) $msg");
        Bot::V::IRC->instance()->privmsg($target, $msg);
    }
    # Learn a key/value pair using "nick, foo = bar" or @learn@.
    elsif ($msg =~ /^${nick}[,:]\s*(\S.*?)\s*=\s*(\S.*?)\s*$/i ||
           $msg =~ /^\@learn\@\s*(\S.*?)\s*=\s*(\S.*?)\s*$/i)
    {
        my ($raw_key, $raw_value) = ($1, $2);

        my $msg = Bot::M::DB->instance()->add_cached($raw_key, $raw_value);

        if ($msg)
        {
            Bot::V::IRC->instance()->privmsg($channel, $msg);
        }
        else
        {
            Bot::V::Log->instance()->
            (
                "Unable to add key [$raw_key] and value [$raw_value]"
            );
        }
    }
    # Delete a key/value pair using @delete@.
    elsif ($msg =~ /^\@delete\@\s*(\S.*?)(?:\s*{(.*?)})?\s*$/i)
    {
        my ($raw_key, $raw_index) = ($1, $2);

        my $msg = Bot::M::DB->instance()->del_cached($raw_key, $raw_index);

        if ($msg)
        {
            Bot::V::IRC->instance()->privmsg($channel, $msg);
        }
        else
        {
            Bot::V::Log->instance()->
            (
                "Unable to delete key [$raw_key] at index [$raw_index]"
            );
        }
    }
    # Retrieve a key/value pair using @@ or @query@.
    elsif ($msg =~ /^\@(?:query)?\@\s*(\S.*?)(?:{(.*?)})?\s*$/i)
    {
        my ($raw_key, $raw_index) = ($1, $2);

        my $msg = Bot::M::DB->instance()->query_cached($raw_key, $raw_index);

        if ($msg)
        {
            Bot::V::IRC->instance()->privmsg($channel, $msg);
        }
        else
        {
            Bot::V::Log->instance()->
            (
                "Unable to query key [$raw_key] at index [$raw_index]"
            );
        }
    }
}

sub _ev_on_msg
{
    my ($self) = @_[OBJECT];

    my ($kernel, $who, $where, $msg) = @_[KERNEL, ARG0, ARG1, ARG2];
    my $nick    = (split /!/, $who)[0];

    Bot::V::Log->instance()->log("MSG_IN($nick) $msg");

    if (any { $nick eq $_ } qw(Henzell))
    {
        Bot::V::IRC->instance()->privmsg('#rrogue', "<$nick> $msg");
    }
}

=head1 METHODS

=cut

=head2 run()

Configures the IRC session and begins the POE kernel loop.

=cut
sub run
{
    my ($self) = @_;

    my $config = Bot::M::Config->instance();

    my $irc = POE::Component::IRC->spawn();
    Bot::V::IRC->instance()->configure($irc);

    # Set up events to handle.
    POE::Session->create
    (
        object_states =>
        [
            $self =>
            {
                _start     => '_ev_bot_start',
                irc_001    => '_ev_on_connect',
                irc_public => '_ev_on_public',
                irc_msg    => '_ev_on_msg',
                tick       => '_ev_tick',
            },
        ],
    );

    # XXX move this
    my $nick = $config->get_key('irc_nick');
    Bot::V::Log->instance()->log("Nick is $nick");

    # Run the bot until it is done.
    $poe_kernel->run();
    return 0;
}

1;

=head1 AUTHOR

Colin Wetherbee <cww@denterprises.org>

=head1 COPYRIGHT

Copyright (c) 2011 Colin Wetherbee

=head1 LICENSE

See the COPYING file included with this distribution.

=cut