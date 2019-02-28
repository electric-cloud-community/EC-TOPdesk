package EC::Plugin::Validators;

use strict;
use warnings;

use base qw(EC::Plugin::ValidatorsCore);

=head1 SYNOPSYS

Validators are used to validate input parameters (check format, for example).
In config they are described in the following manner:

    property: startDate
    type: entry
    validators:
        - date

The validator may look like:

    sub date {
        my ($self, $value) = @_;

        if ($value =~ m/\d{4}-\d{2}-\d{2}/) {
            # If everything is ok, undef is returned
            return;
        }
        else {
            # Otherwise the error text is returned
            return "$value has wrong date format";
        }
    }

No validators defined by default.

=cut

1;
