package Bot::M::DB;

=head1 NAME

Bot::M::DB - A singleton wrapper for the Redis-based IRC bot back-end.

=head1 SYNOPSIS

    use Bot::M::DB;

    my $key = 'foo';
    my $value = 'bar';

    # Single-valued keys...
    Bot::M::DB->instance()->add_cached($key, $value);
    Bot::M::DB->instance()->query_cached($key);
    Bot::M::DB->instance()->del_cached($key, 1);

    # Multi-valued keys...
    Bot::M::DB->instance()->add_cached($key, $value);
    Bot::M::DB->instance()->add_cached($key, $value);
    Bot::M::DB->instance()->query_cached($key, 1);
    Bot::M::DB->instance()->query_cached($key, 2);
    Bot::M::DB->instance()->del_cached($key, 2);
    Bot::M::DB->instance()->del_cached($key, 1);

    # Seen topics (e.g. a Reddit post's unique ID)...
    if (!Bot::M::DB->instance()->have_seen('reddit', 'g95hf'))
    {
        Bot::M::DB->instance()->add_seen('reddit', 'g95hf');
    }

=cut

use common::sense;

use base 'Class::Singleton';

use Redis;

use Bot::V::Log;

sub _get_redis
{
    my ($self) = @_;

    if (!$self->{redis} || !$self->{redis}->ping())
    {
        $self->{redis} = Redis->new();
    }

    return $self->{redis};
}

=head1 METHODS

=cut

=head2 add_cached($key, $value)

Adds $value to the list of values for the case-insensitive key $key.

If $value already exists in the list of values for $key, no modification is
made to the database.

Returns a message suitable for sending to an IRC channel or IRC user in
response to the operation.

=cut
sub add_cached
{
    my ($self, $raw_key, $raw_value) = @_;

    my $redis = $self->_get_redis() || return undef;

    my $key = lc("cache.$raw_key");
    my $value = $raw_value;

    my $len = $redis->llen($key);
    my $exists = 0;

    # Check whether this value already exists in the specified key.  If it
    # does, save the natural index (always greater than 0) to $exists.
    if (defined($len) && $len > 0)
    {
        for (my $i = 0; $i < $len; ++$i)
        {
            my $tmp_value = $redis->lindex($key, $i);
            if ($tmp_value eq $value)
            {
                $exists = $i + 1;
                last;
            }
        }
    }

    my $msg;

    if ($exists == 0)
    {
        Bot::V::Log->instance()->log("ADD($raw_key:$raw_value)");
        $redis->rpush($key, $value);

        $msg = "Learned about $raw_key.";
    }
    else
    {
        $msg = "I already know that; it's at index {$exists}.";
    }

    return $msg;
}

=head2 del_cached($key, [$index])

Removes the key $key from the database.

If $index is not specified and the key $key is multi-valued, no modification
is made to the database.  In other words, you should only omit $index if you
are certain that $key is single-valued.

If $index is specified, removes the value at the 1-based index $index from the
list of values for the specified key.

Returns a message suitable for sending to an IRC channel or IRC user in
response to the operation.

=cut
sub del_cached
{
    my ($self, $raw_key, $raw_index) = @_;

    my $redis = $self->_get_redis() || return undef;

    my $key = lc("cache.$raw_key");
    my $count = $redis->llen($key);
    my $index = $raw_index // 1;
    my $out;

    if (!defined($raw_index) || ($index =~ /^\d*$/ && $index >= 1))
    {
        my $raw_idx_text = $raw_index // '(null)';
        Bot::V::Log->instance()->log
        (
            "DEL(${raw_key}{$raw_idx_text}) (${key}{$index})"
        );
        my $raw_value = $redis->lindex($key, $index - 1);

        if (defined $raw_value)
        {
            if ($count == 1 && $index == 1)
            {
                $redis->del($key);
                $out = "Forgot about $raw_key; was: $raw_value";
            }
            elsif ($count > 1 && defined($raw_index))
            {
                $redis->lrem($key, 0, $raw_value);
                $out = "Forgot about ${raw_key}{$index}; " .
                       "was: $raw_value";
            }
            else
            {
                $out = 'You must specify an index to delete for ' .
                       'multi-valued keys.'
            }
        }
        else
        {
            $out = qq{No value for key "$raw_key" at index {$index}.};
        }
    }
    else
    {
        $out = qq{Invalid index "$index"};
    }

    return $out;
}

=head2 query_cached($key, [$index])

Query the database for the specified key at the (optional) index.  The index
defaults to 1.

Returns a formatted, natural-language response to the query, suitable for
sending directly to an IRC channel or IRC user.

=cut
sub query_cached
{
    my ($self, $raw_key, $raw_index) = @_;

    my $redis = $self->_get_redis() || return undef;

    my $key = lc("cache.$raw_key");
    my $index = $raw_index // 1;
    my $value;

    my $raw_idx_text = $raw_index // '(null)';
    Bot::V::Log->instance()->log
    (
        "QUERY(${raw_key}{$raw_idx_text}) (${key}{$index})"
    );

    if ($index =~ /^\d+$/ && $index >= 1)
    {
        my $raw_value = $redis->lindex($key, $index - 1);

        if (defined $raw_value)
        {
            my $count = $redis->llen($key);
            if ($count == 1)
            {
                $value = "$raw_key: $raw_value";
            }
            else
            {
                $value = "${raw_key}{$index/$count}: $raw_value";
            }
        }
        else
        {
            $value = qq{No value for key "$raw_key" at index {$index}.};
        }
    }
    else
    {
        $value = qq{Invalid index "$index"};
    }

    return $value;
}

=head2 have_seen($topic, $id)

Returns a true value if $topic and $id have been recorded as having been
seen in the past.  Returns false otherwise.

=cut
sub have_seen
{
    my ($self, $topic, $id) = @_;

    my $redis = $self->_get_redis() || return undef;

    my $key = "$topic.seen.$id";

    return $redis->exists($key) ? 1 : 0;
}

=head2 add_seen($topic, $id)

Increments the counter for the $topic and $id so that have_seen() will return
true for this combination in the future.

=cut
sub add_seen
{
    my ($self, $topic, $id) = @_;

    my $redis = $self->_get_redis() || return undef;

    my $key = "$topic.seen.$id";

    $redis->incr($key);
}

1;

=head1 AUTHOR

Colin Wetherbee <cww@denterprises.org>

=head1 COPYRIGHT

Copyright (c) 2011 Colin Wetherbee

=head1 LICENSE

See the COPYING file included with this distribution.

=cut
