#!/usr/bin/perl

=head1 NAME

rroguebot.pl - An IRC bot designed for the freenode #rrogue IRC channel.

=head1 SYNOPSIS

    % perl rroguebot.pl -c /opt/rroguebot-config/BotName.json

=cut

use common::sense;

use File::Basename;
use Getopt::Long;

use Bot::C::Core;
use Bot::M::Config;
use Bot::M::DB;
use Bot::V::Log;

use constant ARGS => qw(config|c=s);

sub _usage
{
    my $script = basename($0);

    say "Usage: $script -c FILE";
    say;
    say '  -c, --config=FILE    Location of configuration file';
    say;
    say 'This bot is free software.  See the COPYING file included in this';
    say 'distribution for licensing terms.';
    exit 1;
}

sub _parse_args
{
    my %args;

    if (!GetOptions(\%args, ARGS))
    {
        _usage();
    }

    if (!$args{config})
    {
        say 'Must specify configuration file.';
        _usage();
    }

    if (!-r $args{config})
    {
        say 'Configuration file is not readable.';
        exit 2;
    }

    return \%args;
}

$| = 1;

my $args_ref = _parse_args();

my $config = Bot::M::Config->instance();
die 'Unable to configure' unless $config->parse_config($args_ref->{config});

my $core = Bot::C::Core->instance();
exit $core->run();

=head1 AUTHOR

Colin Wetherbee <cww@denterprises.org>

=head1 COPYRIGHT

Copyright (c) 2011 Colin Wetherbee

=head1 LICENSE

See the COPYING file included with this distribution.

=cut
