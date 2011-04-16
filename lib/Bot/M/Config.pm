package Bot::M::Config;

=head1 NAME

Bot::M::Config - A singleton that stores configuration data.

=head1 SYNOPSIS

    use Bot::M::Config;

    my $config = Bot::M::Config->instance();
    $config->parse_config('/opt/botconfig.json');
    my $nick = $config->get_key('irc_nick');

=cut

use common::sense;

use base 'Class::Singleton';

use Carp;
use JSON;

use Bot::V::Log;

=head1 METHODS

=cut

=head2 parse_config($file)

Parses the configuration file $file and stores configuration data internally.
Returns a true value if the parse is successful or false otherwise.

=cut

sub parse_config
{
    my ($self, $file) = @_;

    my $fh = IO::File->new($file, '<') or return undef;
    my $buf;
    my $num_read_total = 0;
    while (my $num_read_cur = $fh->read($buf, 4096, $num_read_total))
    {
        $num_read_total += $num_read_cur;
    }
    $fh->close();

    my $json = JSON->new();
    $self->{config} = $json->decode($buf);

    if ($self->{config})
    {
        Bot::V::Log->instance()->log('Parsed configuration');
    }
    else
    {
        Bot::V::Log->instance()->log('Failed to parse configuration');
    }

    return $self->{config} ? 1 : 0;
}

=head2 get_key($key)

Retrieves a value for the specified configuration key or undef if the key does
not exist.

The parse_config() method should be called before any keys are retrieved.

=cut
sub get_key
{
    my ($self, $key) = @_;

    carp 'Configuration not available yet' and return unless $self->{config};
    return $self->{config}->{$key};
}

1;

=head1 AUTHOR

Colin Wetherbee <cww@denterprises.org>

=head1 COPYRIGHT

Copyright (c) 2011 Colin Wetherbee

=head1 LICENSE

See the COPYING file included with this distribution.

=cut
