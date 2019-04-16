=head1 NAME

ECPDF::ContextFactory

=head1 AUTHOR

Electric Cloud

=head1 DESCRIPTION

A context factory that generates the L<ECPDF::Context> object.

=head1 METHODS


=cut

package ECPDF::ContextFactory;
use base qw/ECPDF::BaseClass/;
use strict;
use warnings;
use Data::Dumper;
use ECPDF::Context;
use ElectricCommander;

sub classDefinition {
    return {
        procedureName => 'str',
        stepName      => 'str'
    };
}

=over

=item B<newContext>

Creates new context object. Accepts as parameters a hashref with the following fields:

=over 4

=item B<procedureName>

Name of procedure where we are.

=item B<stepName>

Name of current step that is being executed.

=item B<pluginObject>

An L<ECPDF> object or an object that inherits ECPDF.

=item B<ec>

An ElectricCommander object.

This method should not be used directly without reason. ContextFactory has been designed to be used inside of L<ECPDF> in a seamless way.

=back

=cut

sub newContext {
    my ($self, $ecpdf) = @_;

    my $context = ECPDF::Context->new({
        procedureName => $self->getProcedureName(),
        stepName      => $self->getStepName(),
        pluginObject  => $ecpdf,
        ec            => ElectricCommander->new()
    });
    return $context;
}

=back

=cut

1;
