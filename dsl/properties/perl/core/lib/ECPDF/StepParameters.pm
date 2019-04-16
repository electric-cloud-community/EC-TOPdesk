=head1 NAME

ECPDF::StepParameters

=head1 AUTHOR

Electric Cloud

=head1 DESCRIPTION

This class represents current step parameters, that are defined for current procedure step or current pipeline task.

=head1 SYNOPSIS

To get an ECPDF::StepParameters object you need to use newStepParameters() method from L<ECPDF::Context>.

=head1 METHODS

=cut

package ECPDF::StepParameters;
use base qw/ECPDF::BaseClass/;
use strict;
use warnings;
use Carp;

use ECPDF::Helpers qw/bailOut/;

sub classDefinition {
    return {
        parametersList => '*',
        parameters => '*'
    };
}

# sub isParameterExists {};
# sub getParameter {};
# sub setParameter {};
# sub setCredential {};
# sub getCredential {};


=head2 isParameterExists()

=head3 Description

Returns true if parameter exists in the current step.

=head3 Parameters

=over 4

=item None

=back

=head3 Returns

=over 4

=item (Boolean) True if parameter exists.

=back

=head3 Usage

%%%LANG=perl%%%

    if ($stepParameters->isParameterExists('query')) {
        ...;
    }

%%%LANG%%%

=cut

sub isParameterExists {
    my ($self, $parameterName) = @_;

    my $p = $self->getParameters();
    if ($p->{$parameterName}) {
        return 1;
    }
    return 0;
}

=head2 getParameter($parameterName)

=head3 Description

Returns an L<ECPDF::Parameter> object or L<ECPDF::Credential> object.

=head3 Parameter

=over 4

=item (String) Name of parameter to get.

=back

=head3 Returns

=over 4

=item (L<ECPDF::Parameter>|L<ECPDF::Credential>) Parameter or credential by it's name

=back

=head3 Usage

To get parameter object:

%%%LANG=perl%%%

    my $query = $stepParameters->getParameter('query');

%%%LANG%%%

If your parameter is an L<ECPDF::Parameter> object, you can get its value either by getValue() method, or using string context:

%%%LANG=perl%%%

    print "Query:", $query->getValue();

%%%LANG%%%

Or:

%%%LANG=perl%%%

    print "Query: $query"

%%%LANG%%%

If your parameter is L<ECPDF::Credential>, follow its own documentation.

=cut



sub getParameter {
    my ($self, $parameterName) = @_;

    if (!defined $parameterName) {
        bailOut("Parameter name is mandatory parameter");
    }
    if (!$self->isParameterExists($parameterName)) {
        return undef;
    }

    return $self->getParameters()->{$parameterName};
}


=head2 getRequiredParameter($parameterName)

=head3 Description

Returns an L<ECPDF::Parameter> object or L<ECPDF::Credential> object if this parameter exists.

If parameter does not exist, this method aborts execution with exit code 1.

This exception can't be catched.

=head3 Parameter

=over 4

=item (String) Name of parameter to get.

=back

=head3 Returns

=over 4

=item (L<ECPDF::Parameter>|L<ECPDF::Credential>) Parameter or credential by it's name

=back

=head3 Usage

To get parameter object:

%%%LANG=perl%%%

    my $query = $stepParameters->getRequiredParameter('query');

%%%LANG%%%

If your parameter is an L<ECPDF::Parameter> object, you can get its value either by getValue() method, or using string context:

%%%LANG=perl%%%

    print "Query:", $query->getValue();

%%%LANG%%%

Or:

%%%LANG=perl%%%

    print "Query: $query"

%%%LANG%%%

If your parameter is L<ECPDF::Credential>, follow its own documentation.

=cut

sub getRequiredParameter {
    my ($self, $parameterName) = @_;

    my $value = $self->getParameter($parameterName);
    if (!defined $value) {
        bailOut("Required parameter $parameterName does noet exist");
    }

    return $value;
}

1;
