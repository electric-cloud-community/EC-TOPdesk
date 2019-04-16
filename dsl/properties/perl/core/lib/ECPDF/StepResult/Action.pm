package ECPDF::StepResult::Action;
use base qw/ECPDF::BaseClass/;
use strict;
use warnings;
use Carp;

my $supportedActions = {
    setOutputParameter => 1,
    setPipelineSummary => 1,
    setJobStepOutcome  => 1,
    setJobOutcome      => 1,
    setOutcomeProperty => 1,
    setJobSummary      => 1,
    setJobStepSummary  => 1
};


sub classDefinition {
    return {
        actionType => 'str',
        entityName => 'str',
        entityValue => 'str'
    };
}


sub new {
    my ($class, $params) = @_;

    # TODO: Improve validation later.
    if (!$supportedActions->{$params->{actionType}}) {
        croak "Action Type $params->{actionType} is not supported. Supported actions are: ", join(', ', keys %$supportedActions);
    }

    return $class->SUPER::new($params);
}

1;
