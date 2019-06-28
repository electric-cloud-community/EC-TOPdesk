=head1 NAME

FlowPDF::Component::EF::Reporting::Payload

=head1 AUTHOR

CloudBees

=head1 DESCRIPTION

A payload object.

=head1 METHODS

=head2 getReportObjectType()

=head3 Description

Returns a report object type for current payload.

=head3 Parameters

=over 4

=item None

=back

=head3 Returns

=over 4

=item (String) Report object type for current payload

=back

=head3 Exceptions

=over 4

=item None

=back

=head3 Usage

%%%LANG=perl%%%

    my $reportObhectType = $payload->getReportObjectType();

%%%LANG%%%



=head2 getValues()

=head3 Description

Returns a values that will be sent for the current payload.

=head3 Parameters

=over 4

=item None

=back

=head3 Returns

=over 4

=item (HASH ref) A values for the current payload to be sent.

=back

=head3 Usage

%%%LANG=perl%%%

    my $values = $payload->getValues();

%%%LANG%%%

=head2 getDependentPayloads()

=head3 Note

B<This method still experimental>

=head3 Description

This method returns a dependent payloads for the current payload.

This method may be used when there is more than one report object type should be send in the context of a single payload.

=head3 Parameters

=over 4

=item None

=back

=head3 Returns

=over 4

=item (ARRAY ref of FlowPDF::Component::EF::Reporting::Payload)

=back

=head3 Exceptions

=head3 Usage

%%%LANG=perl%%%

    my $payloads = $payload->getDependentPayloads();

%%%LANG%%%

=cut


package FlowPDF::Component::EF::Reporting::Payload;
use base qw/FlowPDF::BaseClass2/;
use FlowPDF::Types;

__PACKAGE__->defineClass({
    reportObjectType  => FlowPDF::Types::Scalar(),
    values            => FlowPDF::Types::Reference('HASH'),
    dependentPayloads => FlowPDF::Types::ArrayrefOf(FlowPDF::Types::Reference('FlowPDF::Component::EF::Reporting::Payload')),
});

use strict;
use warnings;
use JSON;
use ElectricCommander;
use FlowPDF::Helpers qw/bailOut/;
use FlowPDF::Log;

# local $| = 1;

my $ELECTRIC_COMMANDER_OBJECT;

sub setEc {
    my ($ec) = @_;

    # TODO: Improve this to force static context.
    # if (!ref $ec) {

    # }
    if (!$ec) {
        bailOut "Missing EC parameter";
    }
    if (ref $ec ne 'ElectricCommander') {
        bailOut "Expected an ElectricCommander reference";
    }

    $ELECTRIC_COMMANDER_OBJECT = $ec;
    return $ec;
}


sub getEc {
    return $ELECTRIC_COMMANDER_OBJECT if $ELECTRIC_COMMANDER_OBJECT;

    logDebug "ElectricCommander object has not been set for " . __PACKAGE__ . ", creating default object.";
    my $ec = ElectricCommander->new();
    return setEc($ec);
}


sub encode {
    my ($self) = @_;

    my $encodedPayload = encode_json($self->getValues());
    return $encodedPayload;
}

# TODO: Switch logic to this method.
sub sendAllReportsToEF {
    my ($self) = @_;

    my $result = $self->sendReportToEF();

    my $dependentPayloads = $self->getDependentPayloads();

    unless (@$dependentPayloads) {
        return $result;
    }

    my $result2 = [];
    for my $dp (@$dependentPayloads) {
        my $tempResult = $dp->sendReportToEF();
        push @$result2, $tempResult;
    }

    # TODO: add error handling here.
    return $result2;
}
sub sendReportToEF {
    my ($self) = @_;

    my $ec = $self->getEc();
    my $retval = {
        ok => 1,
        message => '',
    };

    my $payload = $self->getValues();
    my $reportObjectType = $self->getReportObjectType();
    my $encodedPayload = $self->encode();
    logInfo "Encoded payload to send: $encodedPayload";

    if (FlowPDF::Component::EF::Reporting->isPreview()) {
        logInfo("Preview mode is enabled, nothing to send");
        return 1;
    }

    my $xpath = $ec->sendReportingData({
        payload => $encodedPayload,
        reportObjectTypeName => $reportObjectType
    });

    my $errorCode = $xpath->findvalue('//error/code')->string_value();
    if ($errorCode) {
        $retval->{ok} = 0;
        $retval->{message} = $errorCode;
        logError "Error occured during reporting: " . Dumper $retval;
        if (!$retval->{message}) {
            logError "No error message found. Full error xml: $xpath->{_xml}";
        }
    }
    return $retval;
}

# TODO: Implement addition of dependent payload.

sub createNewDependentPayload {
    my ($self, $reportObjectType, $values) = @_;

    if (!$reportObjectType) {
        bailOut("mising reportObjectType parameter for createNewDependentPayload");
    }
    if (!$values) {
        $values = {};
    }
    my $dep = $self->getDependentPayloads();
    my $payload = __PACKAGE__->new({
        reportObjectType => $reportObjectType,
        values => $values,
        dependentPayloads => [],
    });
    push @$dep, $payload;
    return $payload;
}


sub addDependentPayload {
    my ($self, $reportObjectType) = @_;

    return $self;
}

1;

