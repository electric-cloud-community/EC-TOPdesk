package FlowPlugin::TOPdesk;
use strict;
use warnings;
use base qw/FlowPDF/;
use Data::Dumper;
# Feel free to use new libraries here, e.g. use File::Temp;

# Service function that is being used to set some metadata for a plugin.
sub pluginInfo {
    return {
        pluginName    => '@PLUGIN_KEY@',
        pluginVersion => '@PLUGIN_VERSION@',
        configFields  => ['config'],
        configLocations => ['ec_plugin_cfgs']
    };
}

# Auto-generated method for the procedure createOperatorChange/createOperatorChange
# Add your code into this method and it will be called when step runs
use JSON;
sub createOperatorChange {
    my ($pluginObject) = @_;
    my $context = $pluginObject->newContext();
    my $params = $context->getStepParameters();
    #print "Parameters: " . Dumper $params;
    # Config is an FlowPDF::Config object;
    my $config = $context->getConfigValues();
    #print "Configuration: " . Dumper $config;

    my $url = $config->getParameter('endpoint')->getValue();
    $url .= "/tas/api/operatorChanges";

    my $payload = $params->getParameter('payload')->getValue();

    # loading component here using PluginObject;
    my $restComponent = $context->newRESTClient($config);
    my $request = $restComponent->newRequest('POST' => $url);
    $request->content($payload);
    $request->header('Content-type', "application/json");

    if (my $cred = $config->getParameter('credential')) {
      my $user=$cred->getUserName();
      my $pwd =$cred->getSecretValue();
      $request->authorization_basic($user, $pwd);
    }
    #print  "Request: " . Dumper($request);

    my $response = $restComponent->doRequest($request);
    my $stepResult = $context->newStepResult();

    if ($response->is_success()) {
      #print "Success Response : " . Dumper $response;
      #print "Response decoded: " . Dumper $response->decoded_content;
      my $respContent = from_json($response->decoded_content);
      my $changeId=$respContent->{id};
      $stepResult->setJobStepSummary("Change request $changeId created successfully");
      $stepResult->setOutputParameter('change', $response->decoded_content);
      $stepResult->setOutputParameter('changeId', $changeId);
    }
    else {
      $stepResult->setJobStepOutcome('error');
      $stepResult->setJobStepSummary("Failed POST request to $url");
      printf("Failed  POST request to $url\n\t%s\n",$response->status_line);
      # this will abort whole procedure during apply, otherwise just step will be aborted.
      # $stepResult->abortProcedureOnApply(1);
    }
    # $stepResult->apply();
    # print "Created stepresult\n";
    # $stepResult->setJobStepOutcome('warning');
    # print "Set stepResult\n";
    #
    # $stepResult->setJobSummary("See, this is a whole job summary");
    # $stepResult->setJobStepSummary('And this is a job step summary');

    $stepResult->apply();
}

sub getOperatorChange {
    my ($pluginObject) = @_;
    my $context = $pluginObject->newContext();
    my $params = $context->getStepParameters();
    my $config = $context->getConfigValues();

    my $url = $config->getParameter('endpoint')->getValue();
    my $id = $params->getParameter('changeId')->getValue();
    $url .= "/tas/api/operatorChanges/$id";

    # loading component here using PluginObject;
    my $restComponent = $context->newRESTClient();
    my $request = $restComponent->newRequest('GET' => $url);

    if (my $cred = $config->getParameter('credential')) {
      my $user=$cred->getUserName();
      my $pwd =$cred->getSecretValue();
      $request->authorization_basic($user, $pwd);
    }

    my $response = $restComponent->doRequest($request);
    my $stepResult = $context->newStepResult();

    if ($response->is_success()) {
      my $respContent = from_json($response->decoded_content);
      $stepResult->setJobStepSummary("Change request $id retrieved successfully");
      $stepResult->setOutputParameter('change', $response->decoded_content);
    }
    else {
      $stepResult->setJobStepOutcome('error');
      $stepResult->setJobStepSummary("Failed GET request to $url");
      printf("Failed  GET request to $url\n\t%s\n",$response->status_line);
    }

    $stepResult->apply();
}
## === step ends ===
# Please do not remove the marker above, it is used to place new procedures into this file.


1;
