# Version: Thu Oct 25 17:19:39 2018
# Copied from https://github.com/electric-cloud/plugins-core-modules/blob/master/perl/lib/ElectricCommander/Bootstrap.pm
# Package name changed to EC::Bootstrap

package EC::Bootstrap;

use strict;
use warnings;
# no warnings qw/redefine/;
use Carp;
use ElectricCommander;
use Data::Dumper;

sub import {
    my $ec_version = $ElectricCommander::VERSION;

    my $bootstrap = get_bootstrap_by_version($ec_version);
    bootstrap_functions($bootstrap);
};

sub get_bootstrap_by_version {
    my ($version) = @_;

    if ($version < 8.0300) {
        return bootstrap_prior_83();
    }
    return {};
}
sub bootstrap_prior_83 {
    return {
        setOutputParameter => 0E0
    };
}

sub bootstrap_functions {
    my ($h) = @_;

    # print Dumper $h;
    for my $k (keys %$h) {
        no strict qw/refs/;
        $h->{$k} = 'ok' unless defined $h->{$k};
        if (ref $h->{$k} eq 'CODE') {
            *{'ElectricCommander' . "::$k"} = $h->{$k};
        }
        elsif ($h->{$k} =~ m/^(?:ok|error|warning|exit_ok|exit_error)$/s) {
            my $function_name = 'default_' . $h->{$k};
            *{'ElectricCommander' . "::$k"} = sub {$function_name->($k)};
        }
        elsif ($h->{$k} =~ m/forward_to\s(.*?)$/s) {
            *{'ElectricCommander' . "::$k"} = sub {
                my $f = 'ElectricCommander::' . $1;
                return $f(@_)
            };
        }
        else {
            *{'ElectricCommander' . "::$k"} = sub {default_ok($k)};
        }
    }
}

sub default_ok {
    return 1;
}

sub default_error {
    my ($function_name) = @_;
    croak sprintf("Can't call function $function_name");
}

sub default_warning {
    my ($function_name) = @_;
    croak sprintf("Can't call function $function_name");
}
sub default_exit_ok {
    my ($function_name) = @_;
    exit 0;
}
sub default_exit_error {
    my ($function_name) = @_;
    exit 1;
}
1;

=head1 NAME

ElectricCommander

=head1 DESCRIPTION

=cut


1;