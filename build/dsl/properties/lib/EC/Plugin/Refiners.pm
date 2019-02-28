package EC::Plugin::Refiners;

use strict;
use warnings;

=head1 SYNOPSIS

Refiners are used to transform field value in some way. E.g. we have in our config

    property: myProp
    type: checkbox
    refiner: convert_checkbox


And we want value 'info' in case of TRUE and undefined otherwize.
Then we have to add refiner (subroutine), named convert_checkbox:

    sub convert_checkbox {
        my ($self, $value) = @_;

        return $value ? 'info' : undef;
    }

No refiners are created by default.

=cut


sub new {
    my ($class) = @_;
    return bless {}, $class;
}

1;
