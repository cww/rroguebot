package Bot::V::Log;

=head1 NAME

Bot::V::Log - Basic singleton logger.

=head1 SYNOPSIS

    use Bot::V::Log;

    Bot::V::Log->instance()->log('Hello, world!');

=cut

use common::sense;

use base 'Class::Singleton';

=head1 METHODS

=cut

=head2 log($msg, ...)

Writes a log message to the standard output.

The log message may be a single $msg parameter or a list of strings.  If the
message is a list, the list will be joined together using a single space as
the message part separator.

Each log message is prepended with a string representing the current GMT time.

=cut

sub log
{
    my $self = shift;

    my $msg = join(q{ }, @_);
    $msg =~ s/\n*$//g;

    my $timestamp = scalar gmtime;
    say "[$timestamp] $msg";
}

1;

=head1 AUTHOR

Colin Wetherbee <cww@denterprises.org>

=head1 COPYRIGHT

Copyright (c) 2011 Colin Wetherbee

=head1 LICENSE

See the COPYING file included with this distribution.

=cut
