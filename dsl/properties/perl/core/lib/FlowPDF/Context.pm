package FlowPDF::Context;

=head1 NAME

FlowPDF::Context

=head1 AUTHOR

CloudBees

=head1 DESCRIPTION

FlowPDF::Context is a class that represents current running context.

This class allows user to access procedure parameters, config values and define a step result.

=head1 METHODS

=cut


use base qw/FlowPDF::BaseClass2/;
use FlowPDF::Types;
__PACKAGE__->defineClass({
    procedureName           => FlowPDF::Types::Scalar(),
    stepName                => FlowPDF::Types::Scalar(),
    runContext              => FlowPDF::Types::Scalar(),
    pluginObject            => FlowPDF::Types::Any(),
    ec                      => FlowPDF::Types::Reference('ElectricCommander'),
    currentStepParameters   => FlowPDF::Types::Reference('FlowPDF::StepParameters'),
    currentStepConfigValues => FlowPDF::Types::Reference('FlowPDF::Config'),
    currentProjectName      => FlowPDF::Types::Scalar(),
});

use strict;
use warnings;

use FlowPDF::Config;
use FlowPDF::StepParameters;
use FlowPDF::Parameter;
use FlowPDF::Credential;
use FlowPDF::StepResult;
use FlowPDF::Log;
use FlowPDF::Client::REST;
use FlowPDF::Helpers qw/bailOut trim/;
use Carp;
use Data::Dumper;
use ElectricCommander;

sub new {
    my ($class, @params) = @_;

    my $self = $class->SUPER::new(@params);
    my $configValues = $self->getConfigValues();
    if ($configValues) {
        # TODO: Move this to the plugin constants.
        my $debugLevel = $configValues->getParameter('debugLevel');
        # TODO: Create a function to set this.
        if ($debugLevel) {
            $FlowPDF::Log::LOG_LEVEL = $debugLevel->getValue();
            logDebug("Debug level is set to ", $debugLevel->getValue());
        }
    }
    unless ($self->getEc()) {
        $self->setEc(ElectricCommander->new());
    }

    $self->setRunContext($self->buildRunContext());
    $self->setCurrentProjectName($self->retrieveCurrentProjectName());
    return $self;
}


=head2 getRuntimeParameters()

=head3 Description

A simplified accessor for the step parameters and config values.
This function returns a regular perl HASH ref from  parameters and config values.

Credentials from 'credential' parameter will be present in this hashref as 'user' and password.
Credentials, that have name like 'proxy_credential' will be mapped to 'proxy_user' and 'proxy_password' parameters.

=head3 Parameters

=over 4

=item None

=back

=head3 Returns

=over 4

=item (HASH ref) A merged parameters from step parameters and config values.

=back

=head3 Usage

For example, you have 'query' parameter and 'location' parameter in your procedure form.xml.
In your configuration you have 'credential', 'proxy_credential', 'contentType' and 'userAgent'.
In that case you can get runtime parameters like:

%%%LANG=perl%%%

    my $simpleParams = $context->getRuntimeParameters();

%%%LANG%%%

Now, $simpleParams is:

%%%LANG=perl%%%

    {
        # Values from config
        user => 'admin',
        password => '12345',
        proxy_user => 'proxy',
        proxy_password => 'qwerty',
        contentType => 'application/json',
        userAgent => 'Mozilla',
        # values from step parameters
        location => 'California',
        query => 'SELECT * FROM commander.plugins'
    }

%%%LANG%%%

=cut

sub getRuntimeParameters {
    my ($self) = @_;

    my $p = $self->getStepParameters();
    my $c = $self->getConfigValues();
    my ($pKeys, $cKeys);

    my $retval = {};
    if ($p) {
        $pKeys = $p->getParametersList();
        for my $key (@$pKeys) {
            my $row = $p->getParameter($key);

            next unless $row;
            if (ref $row eq 'FlowPDF::Credential') {
                my $prefix = '';

                if ($key =~ m/^(.*?_)credential/) {
                    $prefix = $1;
                }

                my $userName = $row->getUserName();
                my $password = $row->getSecretValue();

                if ($userName) {
                    $retval->{$prefix . 'user'} = $userName;
                }
                if ($password) {
                    $retval->{$prefix . 'password'} = $password;
                }
            }
            else {
                $retval->{$key} = $row->getValue();
            }
        }
    }
    if ($c) {
        $cKeys = $c->getParametersList();
        for my $key (@$cKeys) {
            my $row = $c->getParameter($key);

            next unless $row;
            if (ref $row eq 'FlowPDF::Credential') {
                my $prefix = '';

                if ($key =~ m/^(.*?_)credential/) {
                    $prefix = $1;
                }

                my $userName = $row->getUserName();
                my $password = $row->getSecretValue();

                if ($userName) {
                    $retval->{$prefix . 'user'} = $userName;
                }
                if ($password) {
                    $retval->{$prefix . 'password'} = $password;
                }
            }
            else {
                $retval->{$key} = $row->getValue();
            }
        }
    }

    return $retval;
}


=head2 getStepParameters()

=head3 Description

Returns a L<FlowPDF::StepParameters> object to be used as accessor for current step parameters.
This method does not require parameters.

=head3 Parameters

=over 4

=item None

=back

=head3 Returns

=over 4

=item (L<FlowPDF::StepParameters>) Parameters for the current step

=back

=head3 Usage

%%%LANG=perl%%%

    my $params = $context->getStepParameters();
    # this method returns a L<FlowPDF::Parameter> object, or undef, if no parameter with that name has been found.
    my $param = $params->getParameter('myStepParameter');
    if ($param) {
        print "Param value is:", $param->getValue(), "\n";
    }

%%%LANG%%%

=cut

sub getStepParameters {
    my ($context) = @_;

    if (my $retval = $context->getCurrentStepParameters()) {
        return $retval;
    }
    my $stepParametersHash = $context->getCurrentStepParametersAsHash();

    my $parametersList = [];
    my $parameters = {};
    for my $k (keys %$stepParametersHash) {
        push @{$parametersList}, $k;
        my $p;
        if (!ref $stepParametersHash->{$k}) {
            $p = FlowPDF::Parameter->new({
                name  => $k,
                value => $stepParametersHash->{$k}
            });
        }
        else {
            # it is a hash reference, so it is credential
            my $value = FlowPDF::Credential->new({
                credentialName => $k,
                # TODO: Change it to something more reliable later.
                # Currently we have support of default credentials only.
                credentialType => 'default',
                userName => $stepParametersHash->{$k}->{userName},
                secretValue => $stepParametersHash->{$k}->{password},
            });
        }
        $parameters->{$k} = $p;
    }

    my $stepParameters = FlowPDF::StepParameters->new({
        parametersList => $parametersList,
        parameters => $parameters
    });

    $context->setCurrentStepParameters($stepParameters);
    return $stepParameters;
}


=head2 getConfigValues()

=head3 Description

This method returns a L<FlowPDF::Config> object that represents plugin configuration. This method does not require parameters.

=head3 Parameters

=over 4

=item None

=back

=head3 Returns

=over 4

=item (L<FlowPDF::Config>) Plugin configuration for current run context

=back

=head3 Usage

%%%LANG=perl%%%

    my $configValues = $context->getConfigValues();
    my $cred = $configValues->getParameter('credential');
    if ($cred) {
        print "Secret value is: ", $cred->getSecretValue(), "\n";
    }

%%%LANG%%%

=cut

sub getConfigValues {
    my ($context, $optionalConfigName) = @_;

    if (my $retval = $context->getCurrentStepConfigValues()) {
        return $retval;
    }
    my $stepParameters = $context->getStepParameters();
    my $po = $context->getPluginObject();
    logTrace("Plugin Object: ", Dumper $po);
    my $configLocations = $po->getConfigLocations();
    my $configFields    = $po->getConfigFields();

    my $configField = undef;
    for my $field (@$configFields) {
        if ($stepParameters->isParameterExists($field)) {
            $configField = $field;
            last;
        }
    }

    if (!$configField) {
        croak "No config field detected in current step parameters";
    }
    my $configHash = undef;
    for my $location (@$configLocations) {
        my $tempConfig = $context->retrieveConfigByNameAndLocation(
            $stepParameters->getParameter($configField)->getValue(),
            $location
        );

        if ($tempConfig) {
            $configHash = $tempConfig;
            last;
        }
    }

    # TODO: Improve this error message.
    if (!$configHash) {
        croak "Config does not exist";
    }

    my $keys = [];
    my $configValuesHash = {};
    for my $k (keys %$configHash) {
        push @$keys, $k;

        my $tempRow = $configHash->{$k};
        # TODO: Refactor this a bit, move my $value to this line
        if (!ref $tempRow) {
            my $value = FlowPDF::Parameter->new({
                name => $k,
                value => $configHash->{$k}
            });
            $configValuesHash->{$k} = $value;
        }
        else {
            my $value = FlowPDF::Credential->new({
                credentialName => $k,
                # TODO: Change it to something more reliable later.
                credentialType => 'default',
                userName => $configHash->{$k}->{userName},
                secretValue => $configHash->{$k}->{password},
            });
            $configValuesHash->{$k} = $value;
        }
    }

    my $retval = FlowPDF::Config->new({
        parametersList => $keys,
        parameters => $configValuesHash
    });

    $context->setCurrentStepConfigValues($retval);
    return $retval;
}

sub retrieveConfigByNameAndLocation {
    my ($self, $configName, $configLocation) = @_;

    my $po = $self->getPluginObject();
    my $plugin_project_name = sprintf(
        '%s-%s',
        $po->getPluginName(),
        $po->getPluginVersion()
    );
    # my $ec = $self->getEc();
    # Retrieving a places where plugin configs could be stored. They will be queued from first to last.
    my $config_locations = $po->getConfigLocations();
    my $config_fields = $po->getConfigFields();

    my $config_property_sheet = sprintf("/projects/%s/%s/%s", $plugin_project_name, $configLocation, $configName);
    logDebug("Config property sheet: $config_property_sheet");
    my $property_sheet_id = eval { $self->getEc->getProperty($config_property_sheet)->findvalue('//propertySheetId')->string_value };
    if ($@) {
        return undef;
    }
    my $properties = $self->getEc->getProperties({propertySheetId => $property_sheet_id});

    my $retval = {};
    for my $node ( $properties->findnodes('//property')) {
        my $value = $node->findvalue('value')->string_value;
        my $name = $node->findvalue('propertyName')->string_value;
        if ($name =~ m/_?credential$/s) {
            # here we're doing a trick. We know, that credential in our config will be always named credential or
            # %keyword%_credential. Resulting credential is being stored by plugins as %cofingName%_%credentialField%.
            # So, for example, let's say that we have a config named config1, so,
            # credential, as exception, will be stored as config1, proxy_credential field will be stored as config1_proxy_credential
            # following logic implements this concept.
            my $credentialName = $configName;
            if ($name =~ m/(.*?_credential)$/m) {
                $credentialName = $configName . '_' . $1;
            }
            my $credentials = $self->getEc->getFullCredential($credentialName);
            my $user_name = $credentials->findvalue('//userName')->string_value;
            my $password = $credentials->findvalue('//password')->string_value;
            # $retval->{$name} = {};
            $retval->{$name}->{userName} = $user_name;
            $retval->{$name}->{password} = $password;
        }
        else {
            if (!defined $value || $value eq '') {
                next;
            }
            $retval->{$name} = $value;
        }

    }

    logDebug("Retval", Dumper $retval);
    return $retval;

}

=head2 newStepResult()

=head3 Description

This method returns an L<FlowPDF::StepResult> object, which is being used to work with procedure or pipeline stage output.

=head3 Parameters

=over 4

=item None

=back

=head3 Returns

=over 4

=item (L<FlowPDF::StepResult>) Object for manipulation with pipeline/procedure results.

=back

=head3 Usage

%%%LANG=perl%%%

    my $stepResult = $context->newStepResult();
    ...;
    $stepResult->apply();

%%%LANG%%%

=cut

sub newStepResult {
    my ($self) = @_;

    return FlowPDF::StepResult->new({
        context => $self,
        actions => [],
        cache   => {}
    });
}

# private function for now
sub buildRunContext {
    my ($self) = @_;

    my $ec = $self->getEc();
    my $context = 'pipeline';
    my $flowRuntimeId = '';

    eval {
        $flowRuntimeId = $ec->getProperty('/myFlowRuntimeState/id')->findvalue('//value')->string_value;
    };
    return $context if $flowRuntimeId;

    eval {
        $flowRuntimeId = $ec->getProperty('/myFlowRuntime/id')->findvalue('/value')->string_value();
    };
    return $context if $flowRuntimeId;

    eval {
        $flowRuntimeId = $ec->getProperty('/myPipelineStageRuntime/id')->findvalue('/value')->string_value();
    };
    return $context if $flowRuntimeId;

    $context = 'schedule';
    my $scheduleName = '';
    eval {
        $scheduleName = $self->getCurrentScheduleName();
        1;
    } or do {
        logError("error occured: $@");
    };

    if ($scheduleName) {
        return $context;
    }
    $context = 'procedure';
    return $context;
}

# private
sub getCurrentScheduleName {
    my ($self, $jobId) = @_;

    $jobId ||= $ENV{COMMANDER_JOBID};

    my $scheduleName = '';
    eval {
        my $result = $self->getEc()->getJobDetails($jobId);
        $scheduleName = $result->findvalue('//scheduleName')->string_value();
        if ($scheduleName) {
            # $self->logger()->info('Schedule found: ', $scheduleName);
            logDebug("Schedule found: $scheduleName");
        };
        1;
    } or do {
        # $self->logger()->error($@);
        logError("Error: $@");
    };

    return $scheduleName;
}

# private
sub isParameterRequired {
    my ($self, $param) = @_;

    if (!$param) {
        bailOut("Parameter name is mandatory for isParameterRequired method");
    }
    my $procedureName = $self->getProcedureName();
    my $projectName   = $self->getPluginObject()->getPluginProjectName();
    my $ec            = $self->getEc();
    my $formalParameter = $ec->getFormalParameter({
        projectName         => $projectName,
        procedureName       => $procedureName,
        formalParameterName => $param
    });

    my $required = $formalParameter->findvalue('//required')->string_value();
    return $required;
}
# private
sub readActualParameter {
    my ($self, $param) = @_;

    my $ec = $self->getEc();
    my $retval;
    my $xpath;


    my @subs = ();
    push @subs, sub {
        my $jobId = $ec->getProperty('/myJob/id')->findvalue('//value')->string_value;
        my $xpath = $ec->getActualParameter({
            jobId => $jobId,
            actualParameterName => $param
        });
        return $xpath;
    };

    push @subs, sub {
        my $jobStepId = $ec->getProperty('/myJobStep/id')->findvalue('//value')->string_value;
        my $xpath = $ec->getActualParameter({
            jobStepId => $jobStepId,
            actualParameterName => $param,
        });
        return $xpath;
    };

    push @subs, sub {
        my $jobStepId = $ec->getProperty('/myJobStep/parent/id')->findvalue('//value')->string_value;
        my $xpath = $ec->getActualParameter({
            jobStepId => $jobStepId,
            actualParameterName => $param,
        });
        return $xpath;
    };


    push @subs, sub {
        my $jobStepId = $ec->getProperty('/myJobStep/parent/parent/id')->findvalue('//value')->string_value;
        my $xpath = $ec->getActualParameter({
            jobStepId => $jobStepId,
            actualParameterName => $param,
        });
        return $xpath;
    };


    for my $sub (@subs) {
        my $xpath = eval { $sub->() };

        if (!$@ && $xpath && $xpath->exists('//actualParameterName')) {
            my $val = $xpath->findvalue('//value')->string_value;

            if ($self->isParameterRequired($param)) {
                if (!defined $val || $val eq '') {
                    my $procedureName = $self->getProcedureName();
                    bailOut "Parameter '$param' of procedure '$procedureName' is marked as required, but it does not have a value. Aborting with fatal error.";
                }
            }
            return $val;
        }

    }

    die qq{Failed to get actual parameter $param};
}


# private
sub get_param {
    my ($self, $param) = @_;

    my $retval;
    eval {
        $retval = $self->readActualParameter($param);
        logInfo(qq{Got parameter "$param" with value "$retval"\n});
        1;
    } or do {
        logError("Error '$@' was occured while getting property: $param");
        $retval = undef;
    };
    return $retval;
}


# private
sub getCurrentStepParametersAsHash {
    my ($self) = @_;

    my $params = {};
    my $procedure_name = $self->getEc()->getProperty('/myProcedure/name')->findvalue('//value')->string_value;
    my $po = $self->getPluginObject();
    my $xpath = $self->getEc()->getFormalParameters({
        projectName => sprintf('%s-%s', $po->getPluginName(), $po->getPluginVersion()),
        procedureName => $procedure_name
    });
    for my $param ($xpath->findnodes('//formalParameter')) {
        my $name = $param->findvalue('formalParameterName')->string_value;
        my $value = $self->get_param($name);

        my $name_in_list = $name;
        # TODO: Add credentials handling logic. Now we're nexting.
        if ($param->findvalue('type')->string_value() eq 'credential') {
            my $cred = $self->getEc()->getFullCredential($value);
            my $username = $cred->findvalue('//userName')->string_value;
            my $password = $cred->findvalue('//password')->string_value;
            $params->{$name_in_list}->{userName} = $username;
            $params->{$name_in_list}->{password} = $password;
        }
        else {
            $value = trim($value);
            if (!defined $value || $value eq '') {
                next;
            }
            $params->{$name_in_list} = $value;
        }
    }
    return $params;
}


=head2 newRESTClient($creationParams)

=head3 Description

Creates an L<FlowPDF::Client::REST> object, applying components and other useful mechanisms to it during creation.

For now, this method supports following components and tools:

=over 4

=item L<FlowPDF::Component::Proxy>

Proxy can be automatically be enabled. To do that you need to make sure that following parameters are present in your configuration:

=over 8

=item credential with the proxy_credential name.

=item regular parameter with httpProxyUrl name

=back

If your configuration has all fields above, proxy component will be applied silently,
and you can be sure, that all requests that you're doing through L<FlowPDF::Client::REST> methods already have proxy enabled.

Also, note that if you have debugLevel parameter in your configuration, and it will be set to debug,
debug mode for FlowPDF::ComponentProxy will be enabled by default.

=back

=head3 Parameters

=over 4

=item (Optional) (HASHREF) FlowPDF::Client::REST Object creation params.

=back

=head3 Returns

=over 4

=item L<FlowPDF::Client::REST>

=back

=head3 Usage

%%%LANG=perl%%%

    my $rest = $context->newRestClient();
    my $req = $rest->newRequest(GET => 'https://electric-cloud.com');
    my $response = $rest->doRequest($req);
    print $response->decoded_content();

%%%LANG%%%

=cut

sub newRESTClient {
    my ($context, $params) = @_;

    my $creationParams = {};
    my $configValues = $context->getConfigValues();
    # TODO: Move all magic field names to the constants
    if ($configValues) {
        # handling the proxy here
        my $proxyUrl = $configValues->getParameter('httpProxyUrl');
        logDebug("ProxyURL Parameter is " . Dumper $proxyUrl);
        if ($proxyUrl) {
            logDebug("proxyUrl parameter has been found in configuration, using proxy ", $proxyUrl->getValue());
            # setting a proxy URL;
            $creationParams->{proxy}->{debug} = $FlowPDF::Log::LOG_LEVEL;
            $creationParams->{proxy}->{url} = $proxyUrl->getValue();

            # TODO: change this to getCredential later
            if (my $proxyCredential = $configValues->getParameter('proxy_credential')) {
                $creationParams->{proxy}->{username} = $proxyCredential->getUserName();
                $creationParams->{proxy}->{password} = $proxyCredential->getSecretValue();
            }
        }
    }
    logDebug("REST client creation parameters are: ", Dumper $creationParams);

    if ($params->{oauth}) {
        $creationParams->{oauth} = $params->{oauth};
    }
    my $retval = FlowPDF::Client::REST->new($creationParams);
    return $retval;
}


sub retrieveCurrentProjectName {
    my ($self, $jobId) = @_;

    if (!$jobId) {
        $jobId = $ENV{COMMANDER_JOBID};
    }

    my $projectName = '';
    eval {
        my $result = $self->getEc()->getJobDetails($jobId);
        $projectName = $result->findvalue('//job/projectName')->string_value();
        1;
    } or do {
        bailOut "Can't retrieve project for job $jobId";
    };

    return $projectName;
}

1;
