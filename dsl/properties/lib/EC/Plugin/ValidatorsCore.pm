package EC::Plugin::ValidatorsCore;

use strict;
use warnings;

sub new {
    my ($class) = @_;
    return bless {}, $class;
}

sub positive_int {
    my ($self, $value) = @_;

    return $value =~ m/^\d+$/;
}

1;
