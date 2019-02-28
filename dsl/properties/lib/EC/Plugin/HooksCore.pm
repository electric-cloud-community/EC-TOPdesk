package EC::Plugin::HooksCore;

use strict;
use warnings;

use constant {
    RESPONSE_HOOK => 'response',
    REQUEST_HOOK => 'request',
    AFTER_HOOK => 'after',
    BEFORE_HOOK => 'before',
    PARSED_HOOK => 'parsed',
    PARAMETERS_HOOK => 'parameters',
    UA_HOOK => 'ua',
    CONTENT_CALLBACK => 'content_callback'
};

sub new {
    my ($class, $plugin) = @_;

    die 'No plugin' unless $plugin;
    my $self = {hooks_storage => {}, plugin => $plugin};
    return bless $self, $class;
}

sub define_hook {
    my ($self, $step_name, $hook_name, $hook, $options) = @_;

    $self->{hooks_storage}->{$step_name}->{$hook_name} = {hook => $hook, options => $options};
}

sub ua_hook {
    my ($self, $step_name, $ua) = @_;
    $self->_run($step_name, UA_HOOK, $ua);
}

sub define_hooks {
    die 'Not implemented'
}

sub before_hook {
    my ($self, $step_name) = @_;
    $self->_run($step_name, BEFORE_HOOK);
}

sub after_hook {
    my ($self, $step_name, $parsed) = @_;
    $self->_run($step_name, AFTER_HOOK, $parsed);
}

sub parameters_hook {
    my ($self, $step_name, $parameters) = @_;
    $self->_run($step_name, PARAMETERS_HOOK, $parameters);
}

sub response_hook {
    my ($self, $step_name, $response) = @_;
    $self->_run($step_name, RESPONSE_HOOK, $response);
}

sub request_hook {
    my ($self, $step_name, $request) = @_;
    $self->_run($step_name, REQUEST_HOOK, $request);
}


sub content_callback_hook {
    my ($self, $step_name) = @_;
    $self->_run($step_name, CONTENT_CALLBACK, $_[2]);
}

sub parsed_hook {
    my ($self, $step_name, $parsed) = @_;
    $self->_run($step_name, PARSED_HOOK, $parsed);
}


sub _get_hook {
    my ($self, $step_name, $hook_name) = @_;
    return $self->{hooks_storage}->{$step_name}->{$hook_name}->{hook};
}

sub _get_hook_options {
    my ($self, $step_name, $hook_name) = @_;

    return $self->{hooks_storage}->{$step_name}->{$hook_name}->{options} || {};
}

sub _run {
    my $self = shift;
    my $step_name = shift;
    my $hook_name = shift;

    my $shared_hook = $self->{hooks_storage}->{'*'}->{$hook_name}->{hook};
    my $own_hook = $self->_get_hook($step_name, $hook_name);

    my $own_hook_options = $self->_get_hook_options($step_name, $hook_name);

    my @hooks = ();
    if ($own_hook_options->{run_before_shared}) {
        push @hooks, $own_hook, $shared_hook;
    }
    else {
        push @hooks, $shared_hook, $own_hook;
    }

    for my $hook (@hooks) {
        if ($hook) {
            $hook->($self, @_);
        }
    }
}

#@returns EC::Plugin::Core
sub plugin {
    return shift->{plugin};
}

1;
