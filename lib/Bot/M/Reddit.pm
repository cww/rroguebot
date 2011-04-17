package Bot::M::Reddit;

=head1 NAME

Bot::M::Reddit - A singleton that implements the ability to check Reddit for
new posts in a specific subreddit.

=head1 SYNOPSIS

    use Bot::M::Reddit;
    use Bot::V::IRC;

    my $msgs_ref = Bot::M::Reddit->instance()->get_msgs('steampunk');
    if (defined($msgs_ref))
    {
        for my $msg (@$msgs_ref)
        {
            Bot::V::IRC->instance()->privmsg('#steampunk', $msg);
        }
    }

=cut

use common::sense;

use base 'Class::Singleton';

use JSON;
use LWP::UserAgent;

use Bot::M::DB;
use Bot::V::Log;

sub _new_instance
{
    my $ua = LWP::UserAgent->new();
    $ua->timeout(4);
    my $json = JSON->new();

    my %self =
    (
        ua   => $ua,
        json => $json,
    );

    bless \%self, shift;
}

sub _reddit_new_url
{
    my ($self, $subreddit) = @_;

    return undef unless $subreddit;
    return "http://www.reddit.com/r/$subreddit/new/.json";
}

=head1 METHODS

=cut

=head2 get_msgs($subreddit)

Retrieves the latest posts from the $subreddit subreddit, formats them into
messages suitable for sending directly to an IRC user or channel, and returns
an array ref containing those messages.  Returns undef on error (e.g. if
Reddit is down, etc.).

=cut
sub get_msgs
{
    my ($self, $subreddit) = @_;

    my $url = $self->_reddit_new_url($subreddit);
    return undef unless $url;

    Bot::V::Log->instance()->log("Requesting URL [$url]");
    my $r = $self->{ua}->get($url);
    return undef unless $r;

    my @msgs;

    if ($r->is_success)
    {
        my $data = $self->{json}->decode($r->decoded_content);
        return undef unless $data;

        my @links;
        $@ = q{};
        eval
        {
            my $raw_links_ref = $data->{data}->{children};

            # For each link we found, get the vital information store it for
            # later.  Don't record links we've already seen or links that do
            # not match the Reddit entity ID whitelist pattern.
            for my $link_ref (@$raw_links_ref)
            {
                my $id = $link_ref->{data}->{id};
                next unless defined($id) && $id =~ /^\w+$/;

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
            return undef;
        }
        else
        {
            # Format each link and add to the message list.
            for my $link_ref (@links)
            {
                my $msg = "$link_ref->{author}: $link_ref->{title} " .
                          "<$link_ref->{_url}>";
                push(@msgs, $msg);
            }
        }
    }
    else
    {
        Bot::V::Log->instance()->log
        (
            "Reddit request for subreddit [$subreddit] did not succeed"
        );
        return undef;
    }

    return \@msgs;
}

1;

=head1 AUTHOR

Colin Wetherbee <cww@denterprises.org>

=head1 COPYRIGHT

Copyright (c) 2011 Colin Wetherbee

=head1 LICENSE

See the COPYING file included with this distribution.

=cut
