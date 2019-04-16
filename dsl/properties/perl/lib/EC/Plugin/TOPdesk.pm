package EC::Plugin::TOPdesk;
use strict;
use warnings;
use base qw/ECPDF/;
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
sub createOperatorChange {
    my ($pluginObject) = @_;
    my $context = $pluginObject->newContext();
    my $params = $context->getStepParameters();
    print "Parameters: " . Dumper $params;
    # Config is an ECPDF::Config object;
    my $config = $context->getConfigValues();
    print "Configuration: " . Dumper $config;

    my $url = $params->getValue('endpoint');
    if (!$url->isValid()) {
        $pluginObject->bail_out("Url %s is invalid", $url);
    }
    $url .= "/tas/api/operatorChanges";

    # loading component here using PluginObject;
    my $restComponent = $pluginObject->loadComponent('REST');
    my $request = $restComponent->newRequest('POST' => $url);
    if (my $cred = $config->getCredential('credential')) {
        $request->auth('basic', $cred);
    }
    my $response = $restComponent->doRequest($request);

    my $stepResult = $context->newStepResult();
    if ($response->success()) {
        $stepResult->success();
        $stepResult->setMessage("REST request with method POST to %s has been successful", $url);
    }
    else {
        $stepResult->failure();
        $stepResult->setMessage("Failed during REST request to %s using POST", $url);
        # this will abort whole procedure during apply, otherwise just step will be aborted.
        $stepResult->abortProcedureOnApply(1);
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
## === step ends ===
# Please do not remove the marker above, it is used to place new procedures into this file.


1;
