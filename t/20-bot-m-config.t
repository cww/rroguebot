=head1 NAME

20-bot-m-config.t

=head1 SYNOPSIS

    % prove -Ilib t/20-bot-m-config.t

=cut

use common::sense;

use Test::MockObject;
use Test::Most;

use Bot::M::Config;

my @tests;
my $num_tests = 0;

push(@tests, 'parse_config_no_open');
$num_tests += 1;
sub parse_config_no_open
{
    my $m = Test::MockObject->new();
    $m->fake_module
    (
        'IO::File',
        new => sub { undef },
    );

    my $e = Bot::M::Config->instance()->parse_config('/dev/null');

    ok(!$e, 'Configuration not parsed.');
}

push(@tests, 'parse_config_invalid_json');
$num_tests += 1;
sub parse_config_invalid_json
{
    my $m = Test::MockObject->new();
    $m->fake_module
    (
        'IO::File',
        new => sub { bless {}, shift },
        read => sub { 0 },
        close => sub { },
    );
    $m->fake_module
    (
        'JSON',
        new => sub { bless {}, shift },
        decode => sub { undef },
    );

    my $e = Bot::M::Config->instance()->parse_config('/dev/null');

    ok(!$e, 'Configuration not parsed.');
}

push(@tests, 'parse_config_success');
$num_tests += 2;
sub parse_config_success
{
    my $m = Test::MockObject->new();
    $m->fake_module
    (
        'IO::File',
        new => sub { bless {}, shift },
        read => sub { 0 },
        close => sub { },
    );
    $m->fake_module
    (
        'JSON',
        new => sub { bless {}, shift },
        decode => sub { { foo => 'bar' } },
    );

    my $e = Bot::M::Config->instance()->parse_config('/dev/null');

    ok($e, 'Configuration parsed.');

    my $value = Bot::M::Config->instance()->get_key('foo');

    is($value, 'bar', 'Configuration key successfully stored.');
}

push(@tests, 'get_key_no_config');
$num_tests += 1;
sub get_key_no_config
{
    my $value = Bot::M::Config->instance()->get_key('foo');

    ok(!defined($value), 'No configuration available.');
}

sub run_tests
{
    plan tests => $num_tests;

    for my $test (@tests)
    {
        if (!defined &$test)
        {
            BAIL_OUT("Test \"$test\" not defined.");
        }
    }

    for my $test (@tests)
    {
        undef $Bot::M::Config::_instance;
        eval "$test";
    }
}

run_tests();
done_testing();

=head1 AUTHOR

Colin Wetherbee <cww@denterprises.org>

=head1 COPYRIGHT

Copyright (c) 2011 Colin Wetherbee

=head1 LICENSE

See the COPYING file included with this distribution.

=cut
