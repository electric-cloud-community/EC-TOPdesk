package FlowPDF::Types::Regexp;
use strict;
use warnings;
use Carp;

sub new {
    my ($class, @regexps) = @_;

    if (!@regexps) {
        croak "Regexps are mandatory for that type.";
    }

    for my $reg (@regexps) {
        if (ref $reg ne 'Regexp') {
            croak "Expected a regexp reference for regexp type";
        }
    }
    my $self = {
        regexps => \@regexps,
    };
    bless $self, $class;
    return $self;
}

sub match {
    my ($self, $value) = @_;

    if (ref $value) {
        return 0;
    }
    for my $reg (@{$self->{regexps}}) {
        if ($value =~ m/$reg/ms) {
            return 1;
        }
    }
    return 0;
}


sub describe {
    my ($self) = @_;

    my $regs = join ', ', @{$self->{regexps}};
    return "a scalar value that matches following regexps: ($regs).";
}


1;
