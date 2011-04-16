=head1 NAME

20-bot-m-db.t

=head1 SYNOPSIS

    % prove -Ilib t/20-bot-m-db.t

=cut

use common::sense;

use Test::MockObject;
use Test::Most;

use Bot::M::DB;

my @tests;
my $num_tests = 0;

push(@tests, 'add_cached_no_redis');
$num_tests += 1;
sub add_cached_no_redis
{
    my $m = Test::MockObject->new();
    $m->fake_module
    (
        'Bot::M::Config',
        instance => sub { undef },
    );

    my $e = Bot::M::DB->instance()->add_cached('foo', 'bar');

    ok(!defined($e), 'Key/value pair not added');
}

push(@tests, 'add_cached_value_exists');
$num_tests += 3;
sub add_cached_value_exists
{
    my ($key, $value) = qw(foo bar);

    my $m = Test::MockObject->new();
    $m->fake_module
    (
        'Bot::M::Config',
        instance => sub { bless {}, shift },
        get_key => sub { 'foo' },
    );
    $m->fake_module
    (
        'Redis',
        new => sub { bless {}, shift },
        llen => sub { 1 },
        lindex => sub { $value },
        rpush => sub { BAIL_OUT('Bad code path'); },
    );

    my $e = Bot::M::DB->instance()->add_cached($key, $value);

    ok(defined($e), 'Add cache response is defined');
    isnt($e, q{}, 'Add cache response is non-empty');
    like($e, qr/at index/, 'Add cache response is correct');
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
        undef $Bot::M::DB::_instance;
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

