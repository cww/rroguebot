package Bot::V::IRC;

=head1 NAME

Bot::V::IRC - A singleton that implements an IRC view.

=head1 SYNOPSIS

    use POE::Component::IRC;
    use Bot::V::IRC;

    my $irc = POE::Component::IRC->spawn();
    Bot::V::IRC->instance()->configure($irc);

    # Set up your POE::Session event handlers, etc. ...

    Bot::V::IRC->instance()->start_session();
    Bot::V::IRC->instance()->join('#foo');
    Bot::V::IRC->instance()->privmsg('#foo', 'Hello, World!');

=cut

use common::sense;

use base 'Class::Singleton';

use Carp;

sub _new_instance
{
    my $class = shift;
    my $self = bless {}, $class;

    return $self;
}

=head1 METHODS

=cut

=head2 configure($irc)

Configure this singleton with the specified POE::Component::IRC object.

=cut
sub configure
{
    my ($self, $irc) = @_;

    $self->{irc} = $irc;
}

=head2 start_session()

Uses the configuration stored in the Bot::M::Config singleton to configure and
begin an IRC session.

=cut
sub start_session
{
    my ($self) = @_;
    confess 'Not yet configured' unless $self->{irc};

    my $config = Bot::M::Config->instance();

    $self->{irc}->yield(register => 'all');
    $self->{irc}->yield
    (
        connect =>
        {
            Nick     => $config->get_key('irc_nick'),
            Username => $config->get_key('irc_username'),
            Ircname  => $config->get_key('irc_ircname'),
            Server   => $config->get_key('irc_server'),
            Port     => $config->get_key('irc_port'),
        }
    );
}

=head2 join($channel)

Join a channel.

=cut
sub join
{
    my ($self, $channel) = @_;
    confess 'Not yet configured' unless $self->{irc};

    $self->{irc}->yield(join => $channel);
}

=head2 privmsg($target, $msg)

Sends a private message $msg to $target, which may be a username or a channel
name.

=cut
sub privmsg
{
    my ($self, $target, $msg) = @_;
    confess 'Not yet configured' unless $self->{irc};

    $self->{irc}->yield(privmsg => $target, $msg);
}

1;

=head1 AUTHOR

Colin Wetherbee <cww@denterprises.org>

=head1 COPYRIGHT

Copyright (c) 2011 Colin Wetherbee

=head1 LICENSE

See the COPYING file included with this distribution.

=cut
