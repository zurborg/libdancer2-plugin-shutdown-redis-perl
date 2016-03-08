use strictures 2;

package Dancer2::Plugin::Shutdown::Redis;

# ABSTRACT: Graceful shutdown your Dancer2 application with Redis propagation

use Dancer2::Plugin;
use Scalar::Util qw(blessed);
use Redis;
use Carp qw(croak);
use Tie::Redis::Candy 1.001 qw(redis_hash);
with 'Dancer2::Plugin::Role::Shutdown';

# VERSION

has _redis => (
    is => 'rw',
);

sub _shutdown_redis {
    my $self = shift;
    return $self->_redis unless @_;
    my ($redis, $key) = @_;
    croak "you have specify a key" unless $key;
    if (blessed $redis and ($redis->isa('Redis') or $redis->isa('Test::Mock::Redis'))) {
        $self->_redis($redis);
    } elsif (defined $redis and not ref $redis) {
        $self->_redis(Redis->new(server => $redis));
    } else {
        croak("Not a Redis instance: $redis");
    }
    my $shared = redis_hash($self->_redis, $key, %{ $self->shared });
    $self->_set_shared($shared);
    return $self->_redis;
}

=func shutdown_at

See L<Dancer2::Plugin::Shutdown/shutdown_at>

=cut

register shutdown_at => \&_shutdown_at;

=func shutdown_session_validator

See L<Dancer2::Plugin::Shutdown/shutdown_session_validator>

=cut

register shutdown_session_validator => sub {
    shift->validator(@_)
}, { is_global => 1 };

=func shutdown_redis

B<Invokation:> C<shutdown_redis( $redis, $key )>

Set the instance of L<Redis> and the correspondig key. Both arguments are mandatory.

Hint: the author recommends L<Dancer2::Plugin::Redis>.

=cut

register shutdown_redis => sub {
    shift->_shutdown_redis(@_)
}, { is_global => 1 };

on_plugin_import {
    my $self = shift;
    $self->app->add_hook(
        Dancer2::Core::Hook->new(
            name => 'before',
            code => sub { $self->before_hook(@_) },
        )
    );
};

register_plugin;

1;

=head1 SYNOPSIS

    use Dancer2;
    use Dancer2::Plugin::Redis;
    use Dancer2::Plugin::Shutdown;
    
    shutdown_redis(redis_plugin(), 'my_shutdown_key');
    
    $SIG{HUP} = sub {
        # on hangup, shutdown in 120 seconds
        shutdown_at(120);
    };

=head1 DESCRIPTION

This module is based on L<Dancer2::Plugin::Shutdown> so see there for an introduction.

The difference is the way the shutdown is propagated in multi-instance setups like L<Starman> or L<Corona>. The state is stored in a shared variable, tied with L<Tie::Redis::Candy> to a Redis key. On every request this Redis key is checked so every instance get the very latest state.

One instance call L</shutdown_at>, all instances react by gracefully shutdown your application.

=cut
