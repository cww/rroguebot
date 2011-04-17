=head1 NAME

20-bot-m-reddit.t

=head1 SYNOPSIS

    % prove -Ilib t/20-bot-m-reddit.t

=cut

use common::sense;

use Test::MockObject;
use Test::Most;

use Bot::M::Reddit;

my @tests;
my $num_tests = 0;

push(@tests, 'get_msgs_no_subreddit');
$num_tests += 1;
sub get_msgs_no_subreddit
{
    my $m = Test::MockObject->new();
    $m->fake_module
    (
        'JSON',
        new => sub { bless {}, shift },
    );
    $m->fake_module
    (
        'LWP::UserAgent',
        new => sub { bless {}, shift },
    );

    my $e = Bot::M::Reddit->instance()->get_msgs(undef);

    ok(!defined($e), 'Undefined response from get_msgs(undef)');
}

push(@tests, 'get_msgs_get_fail');
$num_tests += 1;
sub get_msgs_get_fail
{
    my $m = Test::MockObject->new();
    $m->fake_module
    (
        'JSON',
        new => sub { bless {}, shift },
    );
    $m->fake_module
    (
        'LWP::UserAgent',
        new => sub { bless {}, shift },
        get => sub { undef },
    );

    my $e = Bot::M::Reddit->instance()->get_msgs('roguelikes');

    ok(!defined($e), 'Undefined response from get_msgs() w/ bad get()');
}

push(@tests, 'get_msgs_http_error');
$num_tests += 1;
sub get_msgs_http_error
{
    SKIP:
    {
        $@ = q{};
        eval { require HTTP::Response; };
        skip 'HTTP::Response not installed', 1 if $@;

        my $m = Test::MockObject->new();
        $m->fake_module
        (
            'JSON',
            new => sub { bless {}, shift },
        );
        $m->fake_module
        (
            'HTTP::Response',
            new => sub { bless {}, shift },
            is_success => sub { 0 },
        );
        $m->fake_module
        (
            'LWP::UserAgent',
            new => sub { bless {}, shift },
            get => sub { HTTP::Response->new() },
        );

        my $e = Bot::M::Reddit->instance()->get_msgs('roguelikes');

        ok(!defined($e), 'Undefined response from get_msgs() w/ !is_success');
    }
}

push(@tests, 'get_msgs_success');
$num_tests += 3 + 2 * 2;
sub get_msgs_success
{
    SKIP:
    {
        $@ = q{};
        eval { require HTTP::Response; };
        skip 'HTTP::Response not installed', 3 + 2 * 2 if $@;

        my $m = Test::MockObject->new();
        $m->fake_module
        (
            'JSON',
            new    => sub { bless {}, shift },
            decode => sub
            {
                return
                {
                    data =>
                    {
                        children =>
                        [
                            {
                                data =>
                                {
                                    id     => 'foo1',
                                    author => 'cww1',
                                    title  => 'Foo One',
                                },
                            },
                            {
                                data =>
                                {
                                    id     => 'foo2',
                                    author => 'cww2',
                                    title  => 'Foo Two',
                                },
                            }
                        ],
                    },
                };
            },
        );
        $m->fake_module
        (
            'HTTP::Response',
            new             => sub { bless {}, shift },
            is_success      => sub { 1 },
            decoded_content => sub { q{} },
        );
        $m->fake_module
        (
            'LWP::UserAgent',
            new => sub { bless {}, shift },
            get => sub { HTTP::Response->new() },
        );
        $m->fake_module
        (
            'Bot::M::DB',
            instance  => sub { bless {}, shift },
            have_seen => sub { 0 },
            add_seen  => sub { 1 },
        );

        my $msgs_ref = Bot::M::Reddit->instance()->get_msgs('roguelikes');

        ok(defined($msgs_ref), 'Received object');
        is(ref($msgs_ref), 'ARRAY', 'Received array');
        is(scalar(@$msgs_ref), 2, 'Received array with 2 elements');
        for (my $i = 0; $i < 2; ++$i)
        {
            isnt($msgs_ref->[$i], undef, "Message [$i] is defined");
            isnt($msgs_ref->[$i], q{}, "Message [$i] is non-empty");
        }
    }

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
        undef $Bot::M::Reddit::_instance;
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

