package EC::RESTPlugin;

use strict;
use warnings;

use base qw(EC::Plugin::Core);
use EC::Plugin::Hooks;
use EC::Plugin::BatchCommander;
use EC::Plugin::Validators;
use EC::Plugin::ContentProcessor;
use EC::Plugin::Refiners;
use LWP::UserAgent;
use JSON;
use Encode qw(decode);
use Data::Dumper;
use MIME::Base64 qw(encode_base64);
use URI;
use Carp qw(confess);

#according to http://docs.electric-cloud.com/eflow_doc/7_3/User/HTML/content/properties.htm#propertySheet
#this fields will get "_" prefix to prevent job failure on saving
use constant {
    RESULT_PROPERTY_SHEET_FIELD => 'resultPropertySheet',
    FORBIDDEN_FIELD_NAME_PREFIX => '_'
};
use constant FORBIDDEN_FIELD_NAME_PROPERTY_SHEET => qw(acl createTime lastModifiedBy modifyTime owner propertySheetId description);


=head2 after_init_hook

Debug level - we are reading property /projects/EC-PluginName-1.0.0/debugLevel.
If this property exists, it will set the debug level. Otherwize debug level will be 0, which is info.

=cut

sub after_init_hook {
    my ($self, %params) = @_;

    $self->{plugin_name} = '@PLUGIN_NAME@';
    $self->{plugin_key} = '@PLUGIN_KEY@';
    $self->{last_run_data} = undef;
    my $debug_level = 0;
    my $proxy;

    if ($self->{plugin_key}) {
        eval {
            $debug_level = $self->ec()->getProperty(
                "/plugins/$self->{plugin_key}/project/debugLevel"
            )->findvalue('//value')->string_value();
        };

        eval {
            $proxy = $self->ec->getProperty(
                "/plugins/$self->{plugin_key}/project/proxy"
            )->findvalue('//value')->string_value;
        };
    }
    if ($debug_level) {
        $self->debug_level($debug_level);
        $self->logger->debug("Debug enabled for $self->{plugin_key}");
    }

    else {
        $self->debug_level(0);
    }

    if ($proxy) {
        $self->{proxy} = $proxy;
        $self->logger->info("Proxy enabled: $proxy");
    }

}

#@returns EC::Plugin::Hooks
sub hooks {
    my ($self) = @_;
    unless($self->{hooks}) {
        $self->{hooks} = EC::Plugin::Hooks->new($self);
    }
    return $self->{hooks};
}

#@returns EC::Plugin::BatchCommander
sub batch_commander {
    my ($self) = @_;
    unless($self->{batch_commander}) {
        $self->{batch_commander} = EC::Plugin::BatchCommander->new($self);
    }
    return $self->{batch_commander};
}


sub validators {
    my ($self) = @_;

    unless($self->{validators}) {
        $self->{validators} = EC::Plugin::Validators->new;
    }
    return $self->{validators};
}

sub refiners {
    my ($self) = @_;

    unless($self->{refiners}) {
        $self->{refiners} = EC::Plugin::Refiners->new;
    }
    return $self->{refiners};
}

#@returns EC::Plugin::ContentProcessor
sub content_processor {
    my ($self) = @_;

    unless($self->{content_processor}) {
        $self->{content_processor} = EC::Plugin::ContentProcessor->new(plugin => $self);
    }
    return $self->{content_processor};
}

sub config {
    my ($self) = @_;

    unless($self->{steps_config}) {
        my $value = $self->ec->getProperty('/myProject/properties/pluginConfig')->findvalue('//value')->string_value;
        my $config = decode_json($value);
        $self->{steps_config} = $config;
    }
    return $self->{steps_config};
}

sub current_step_name {
    my ($self, $step_name) = @_;

    if ($step_name) {
        $self->{current_step_name} = $step_name;
    }
    else {
        return $self->{current_step_name};
    }
}

sub generate_step_request {
    my ($self, $step_name, $config, $parameters) = @_;

    my $endpoint = $self->config->{$step_name}->{endpoint};

    my $key = qr/[\w\-.?!]+/;
    # replace placeholders
    my $config_values_replacer = sub {
        my ($value) = @_;
        return $config->{$value} || '';
    };
    $endpoint =~ s/#\{\{($key)\}\}/$config_values_replacer->($1)/ge;

    my $parameters_replacer = sub {
        my ($value) = @_;
        return $parameters->{$value} || '';
    };

    $endpoint =~ s/#\{($key)\}/$parameters_replacer->($1)/ge;

    my $uri = URI->new($endpoint);
    my %query = $uri->query_form;
    my %body = ();
    my %headers = ();

    for my $field ( @{$self->config->{$step_name}->{parameters}}) {
        my $name = $field->{property};
        my $value = $parameters->{$name};
        next unless $field->{in};

        if($field->{noEmptyString} || $self->config->{options}->{noEmptyString}) {
            next unless(defined $value && $value ne '');
        }

        if ($field->{in} eq 'query') {
            $query{$name} = $value;
        }
        elsif ($field->{in} eq 'body') {
            $body{$name} = $value;
        }
        elsif ($field->{in} eq 'header') {
            $headers{$name} = $value;
        }
    }

    $uri->query_form(%query);
    $self->logger->debug(\%body);

    my $method = $self->config->{$step_name}->{method};
    my $payload;
    if (%body || $method =~ /PATCH|PUT|POST/) {
        $payload = $self->content_processor->run_serialize_body($step_name, \%body);
        $self->logger->info("Payload size: " . length($payload));
    }

    $self->logger->debug("Endpoint: $uri");

    my $request = $self->get_new_http_request($method, $uri);

    $config->{auth} ||= '';
    if (($config->{auth} eq 'basic' || $self->config->{$step_name}->{basicAuth})
        && $self->config->{$step_name}->{basicAuth}
        && $self->config->{$step_name}->{basicAuth} eq 'true'
    ) {
        $self->logger->debug('Adding basic auth');

        my $username = $config->{userName};
        my $password = $config->{password};

        unless ($self->config->{$step_name}->{canSkipAuth}) {
            unless ($username){
                return $self->bail_out('No username found in configuration');
            }
            unless($password) {
                return $self->bail_out('No password found in configuration');
            }
        }
        $request->authorization_basic($username, $password);
    }
    else {
        $self->logger->debug('Skipping basic auth');
    }

    if (%headers) {
        for (keys %headers) {
            $request->header($_ => $headers{$_});
        }
    }

    $request->content($payload) if $payload;
    my $content_type = $self->config->{$step_name}->{contentType};

    if ( $self->config->{$step_name}->{bodyContentType} &&
        $self->config->{$step_name}->{bodyContentType} eq 'json') {
        $content_type ||= 'application/json';
    }
    if ($content_type) {
        $request->header('Content-Type' => $content_type);
    }

    return $request;
}

sub request {
    my ($self, $step_name, $request) = @_;

    my $ua = $self->new_lwp();
    $self->hooks->ua_hook($step_name, $ua);
    my $callback = undef;

    $self->hooks->content_callback_hook($step_name, $callback);
    # my @request_parameters = $self->hooks->request_parameters_hook($step_name, $request);

    if ($self->{proxy}) {
        $ua->proxy(['http', 'https'] => $self->{proxy});
        $self->logger->info("Proxy set for request");
        $ua->requests_redirectable([qw/GET POST PUT PATCH GET HEAD OPTIONS DELETE/]);
    }
    $self->logger->info($request->method . ' ' . $request->uri);
    my HTTP::Response $response = $ua->request($request, $callback);

    # # NTLM handling
    # if ($response->code == 401){
    #
    #     # Check if should use NTLM
    #     my $config_name = $self->get_param('config');
    #     my $config = $self->get_config_values($config_name);
    #
    #     return $response unless ($config->{auth} eq 'ntlm');
    #
    #     # Check if have NTLM auth header
    #     # my HTTP::Headers $headers = $response->headers();
    #     # my @supported_schemes = $headers->header('www-authenticate');
    #     #
    #     # return $response unless (grep {$_ =~ /ntlm/i} @supported_schemes );
    #
    #     # Now will try to authenticate
    #     print "Authentication \n";
    #
    #     require LWP::Authen::Ntlm;
    #     my $auth_resp =  LWP::Authen::Ntlm->authenticate($ua, undef, {
    #         realm => '10.200.1.245:8080'
    #     }, $response, $request);
    #
    #     print Dumper $auth_resp;
    #     return $auth_resp;
    # }

    return $response;
}

#running one step for defined procedure
sub run_one_step{
    my ($self, $step_name) = @_;

    $self->hooks->before_hook($step_name);
    my $parameters = $self->parameters($step_name);

    $self->logger->debug('Parameters', $parameters);
    $self->hooks->parameters_hook($step_name, $parameters);

    my $config = {};
    if ($self->config->{$step_name}->{hasConfig}) {
        $config = $self->get_config_values($parameters->{config});
        $self->logger->debug('Config', $config);
    }

    my HTTP::Request $request = $self->generate_step_request($step_name, $config, $parameters);
    $self->hooks->request_hook($step_name, $request); # request can be altered by the hook
    $self->logger->info("Going to run request");
    $self->logger->trace("Request", $request->as_string);
    my $response = $self->request($step_name, $request);
    $self->hooks->response_hook($step_name, $response);

    unless($response->is_success) {
        $self->logger->info("Response", $response->content);
        my $message = 'Request failed: ' . $response->status_line;
        return $self->bail_out($message);
    }
    else {
        $self->logger->info('Request succeeded');
    }
    my $parsed = $self->parse_response($step_name, $response);

    $self->hooks->parsed_hook($step_name, $parsed);

    $self->save_parsed_data($step_name, $parsed);

    $self->hooks->after_hook($step_name, $parsed);

    $self->{last_run_data} = $parsed;
}


sub run_step {
    my ($self, $step_name) = @_;

    eval {
        my $plugin_name = $self->{plugin_name};
        my $summary = qq{
Plugin: $plugin_name
Running step: $step_name
};
        $self->logger->info($summary);
        $self->current_step_name($step_name);
        die 'No step name' unless $step_name;
        $self->logger->debug("Running step named $step_name");
        $self->batch_commander->define_batch_hooks;
        $self->batch_commander->define_iterators;
        $self->hooks->define_hooks;
        $self->content_processor->define_processors;
        my $parameters = $self->parameters($step_name);

        for my $param_name (sort keys %$parameters) {
            my $value = $self->safe_log($param_name, $parameters->{$param_name});
            $self->logger->info(qq{Got parameter "$param_name" with value "$value"});
        }
        $self->logger->debug('Parameters', $parameters);

        $self->batch_commander->before_batch_hook($step_name);

        my $next = $self->batch_commander->iterator($step_name, $parameters);
        while($next->()){
            $self->run_one_step($step_name);
        }

        $self->batch_commander->after_batch_hook($step_name);

        1;
    } or do {
        my $error = $@;
        $self->ec->setProperty('/myCall/summary', $error);
        die $error;
    };
}

sub safe_log {
    my ($self, $param_name, $param_value) = @_;

    if ($self->{hidden}->{$param_name}) {
        return '*******';
    }
    else {
        return $param_value;
    }
}

sub parse_response {
    my ($self, $step_name, $response) = @_;

    return $self->content_processor->run_parse_response($step_name, $response);
}

sub save_parsed_data {
    my ($self, $step_name, $parsed_data) = @_;

    my $config = $self->config->{$step_name}->{resultProperty};
    if ($self->config->{$step_name}->{outputParameter}) {
        my $param_name = $self->config->{$step_name}->{outputParameter}->{name};
        my $json = encode_json($parsed_data);
        $json = decode('utf8', $json);
        eval {
            $self->ec->setOutputParameter($param_name, $json);
            1;
        } or do {
            $self->logger->debug("Cannot save output parameter: $@");
        };
    }
    return unless $config && $config->{show};

    my $property_name = $self->parameters($step_name)->{+RESULT_PROPERTY_SHEET_FIELD};

    my $formats = $config->{format};
    my $selected_format;

    if (scalar @$formats > 0) {
        $selected_format = $self->parameters($step_name)->{resultFormat}; # TODO constant
    }
    else {
        $selected_format = $formats->[0];
    }

    unless($selected_format) {
        return $self->bail_out('No format has beed selected');
    }

    unless($parsed_data) {
        $self->logger->info("Nothing to save");
        return;
    }

    $self->logger->info("Got data", JSON->new->pretty->encode($parsed_data));

    if ($selected_format eq 'propertySheet') {

        my $flat_map = $self->_self_flatten_map($parsed_data, $property_name, 'check_errors!');

        for my $key (sort keys %$flat_map) {
            $self->ec->setProperty($key, $flat_map->{$key});
            $self->logger->info("Saved $key -> $flat_map->{$key}");
        }
    }
    elsif ($selected_format eq 'json') {
        my $json = encode_json($parsed_data);
        $json = decode('utf8', $json);
        $self->logger->trace(Dumper($json));
        $self->ec->setProperty($property_name, $json);
        $self->logger->info("Saved answer under $property_name");
    }
    elsif ($selected_format eq 'file') {
        #saving data implementation is on Hooks side!
    }
    else {
        $self->bail_out("Cannot process format $selected_format: not implemented");
    }
}

sub fix_propertysheet_forbidden_key{
    my ($self, $ref_var, $key) = @_;

    $self->logger->info("\"$key\" is the system property name", "Prefix FORBIDDEN_FIELD_NAME_PREFIX was added to prevent failure.");
    my $new_key = FORBIDDEN_FIELD_NAME_PREFIX . $key;
    if(ref($ref_var) eq 'HASH'){
        $ref_var->{$new_key} = $ref_var->{$key};
        delete $ref_var->{$key};
    }
    elsif(ref($ref_var) eq 'SCALAR'){
        $$ref_var = $new_key;
    }
}

sub parameters {
    my ($self, $step_name) = @_;

    $step_name ||= $self->current_step_name;
    confess 'No step name' unless $step_name;

    unless($self->{parameters}->{$step_name}) {
        $self->{parameters}->{$step_name} = $self->grab_parameters($step_name);
    }
    return $self->{parameters}->{$step_name};
}

sub show_result_property {
    my ($self, $step_name) = @_;

    return $self->config->{$step_name}->{resultProperty} && $self->config->{$step_name}->{resultProperty}->{show};
}

sub result_formats {
    my ($self, $step_name) = @_;

    return $self->config->{$step_name}->{resultProperty}->{format} || [];
}

sub grab_parameters {
    my ($self, $step_name) = @_;

    my $fields = $self->config->{$step_name}->{fields};
    if ($self->config->{$step_name}->{hasConfig}) {
        push @$fields, 'config';
    }
    if ($self->show_result_property($step_name)) {
        push @$fields, RESULT_PROPERTY_SHEET_FIELD;
    }
    if (scalar @{$self->result_formats($step_name)} > 1) {
        push @$fields, 'resultFormat';
    }
    unless ($fields && scalar @$fields) {
        die "No fields defined for step $step_name";
    }

    my $parameters = $self->get_params_as_hashref(@$fields);
    for my $param_name (keys %$parameters) {
        if ($parameters->{$param_name} && $self->get_param_type($step_name, $param_name) eq 'credential') {
            my $cred = $self->get_step_credential($parameters->{$param_name});
            $parameters->{"${param_name}UserName"} = $cred->{userName};
            $parameters->{"${param_name}Password"} = $cred->{password};
            $self->{hidden}->{"${param_name}Password"} = 1;
        }
    }

    $self->validate($step_name, $parameters);
    $parameters = $self->refine($step_name, $parameters);
    return $parameters;
}

sub get_param_type {
    my ($self, $step_name, $param_name) = @_;

    my $step_config = $self->config->{$step_name};
    my $parameters = $step_config->{parameters};
    my ($param) = grep { $_->{property} eq $param_name } @$parameters;
    return $param->{type} || '';
}

sub get_step_credential {
    my ($self, $cred_name) = @_;

    return {} unless $cred_name;

    my $xpath = $self->ec->getFullCredential($cred_name);
    my $user_name = $xpath->findvalue('//userName')->string_value;
    my $password = $xpath->findvalue('//password')->string_value;

    return {userName => $user_name, password => $password};
}

sub refine {
    my ($self, $step_name, $parameters) = @_;

    for my $name (keys %$parameters) {
        my $refiners = $self->get_refiners($step_name, $name);
        for my $refiner_name (@$refiners) {
            $parameters->{$name} = $self->refiners->$refiner_name($parameters->{$name});
        }
    }

    return $parameters;
}


sub _fix_multiple_object_syntax{
    my @params = @_;

    my @objects;
    foreach my $item (@params){
        if (defined $item and $item){
            unless (ref $item eq 'ARRAY'){
                $item = [$item];
            }
            push @objects, @$item;
        }
    }
    return \@objects;
}

sub get_refiners {
    my ($self, $step_name, $param_name) = @_;

    my ($field) = grep  {$_->{property} eq $param_name} @{$self->config->{$step_name}->{parameters}};

    return _fix_multiple_object_syntax($field->{refiner}, $field->{refiners});
}

sub validate {
    my ($self, $step_name, $parameters) = @_;

    my @messages = ();
    for my $name (keys %$parameters) {
        my $value = $parameters->{$name};
        my $validators = $self->get_validators($step_name, $name);
        for my $validator_name (@$validators) {
            my $error  = $self->validators->$validator_name($value);
            if ($error) {
                push @messages, $error;
            }
        }
    }
    if ( scalar @messages ) {
        return $self->bail_out("Validation errors: " . join("\n", @messages));
    }
}

sub get_validators {
    my ($self, $step_name, $param_name) = @_;

    my ($field) = grep  {$_->{property} eq $param_name} @{$self->config->{$step_name}->{parameters}};

    return _fix_multiple_object_syntax($field->{validator}, $field->{validators});
}

sub get_config_values {
    my ($self, $config_name) = @_;

    die 'No config name' unless $config_name;
    my $plugin_project_name = '@PLUGIN_KEY@-@PLUGIN_VERSION@';
    my $config_property_sheet = "/projects/$plugin_project_name/ec_plugin_cfgs/$config_name";
    my $property_sheet_id = $self->ec->getProperty($config_property_sheet)->findvalue('//propertySheetId')->string_value;

    unless($property_sheet_id) {
        $self->bail_out(qq{No config named $config_name found});
    }
    my $properties = $self->ec->getProperties({propertySheetId => $property_sheet_id});

    my $retval = {};
    for my $node ( $properties->findnodes('//property')) {
        my $value = $node->findvalue('value')->string_value;
        my $name = $node->findvalue('propertyName')->string_value;
        $retval->{$name} = $value;

        if ($name =~ /credential/) {
            my $credentials = $self->ec->getFullCredential($config_name);
            my $user_name = $credentials->findvalue('//userName')->string_value;
            my $password = $credentials->findvalue('//password')->string_value;
            $retval->{userName} = $user_name;
            $retval->{password} = $password;
        }
    }

    return $retval;
}

sub _flatten_map {
    my ($map, $prefix) = @_;

    $prefix ||= '';
    my %retval = ();

    for my $key (keys %$map) {

        my $value = $map->{$key};
        if (ref $value eq 'ARRAY') {
            my $counter = 1;
            my %copy = map { my $key = ref $_ ? $counter ++ : $_; $key => $_ } @$value;
            $value = \%copy;
        }
        if (ref $value ne 'HASH') {
            $value ||= '';
            $value = "$value";
        }
        if (ref $value) {
            %retval = (%retval, %{_flatten_map($value, "$prefix/$key")});
        }
        else {
            $retval{"$prefix/$key"} = $value;
        }
    }
    return \%retval;
}


sub _self_flatten_map {
    my ($self, $map, $prefix, $check) = @_;

    if (defined $check and $check){
        $check = 1;
    }
    else{
        $check = 0;
    }
    $prefix ||= '';
    my %retval = ();

    for my $key (keys %$map) {

        my $value = $map->{$key};
        if (ref $value eq 'ARRAY') {
            my $counter = 1;
            my %copy = map { my $key = ref $_ ? $counter ++ : $_; $key => $_ } @$value;
            $value = \%copy;
        }
        if (ref $value ne 'HASH') {
            $value = '' unless defined $value;
            $value = "$value";
        }
        if (ref $value) {
            if ($check){
                foreach my $bad_key(FORBIDDEN_FIELD_NAME_PROPERTY_SHEET){
                    if (exists $value->{$bad_key}){
                        $self->fix_propertysheet_forbidden_key($value, $bad_key);
                    }
                }
            }

            %retval = (%retval, %{$self->_self_flatten_map($value, "$prefix/$key", $check)});
        }
        else {
            if ($check){
                foreach my $bad_key(FORBIDDEN_FIELD_NAME_PROPERTY_SHEET){
                    if ($key eq $bad_key){
                        $self->fix_propertysheet_forbidden_key(\$key, $bad_key);
                    }
                }
            }

            $retval{"$prefix/$key"} = $value;
        }
    }
    return \%retval;
}

sub new_lwp {
    my ( $self ) = @_;

    my LWP::UserAgent $ua = LWP::UserAgent->new;

    my $config_name = $self->get_param('config');
    my $config = $self->get_config_values($config_name);

    my $auth_type = $config->{auth} || '';

    if ($self->{auth_type} && ref $self->{auth_type}){
        $self->{auth_type}{ua}->($ua) if ($self->{auth_type}{ua});
    }
    elsif ($auth_type eq 'basic'){
        $self->logger->debug("Request should be authorized. Nothing to do with the \$ua");
    }
    elsif ($auth_type eq 'ntlm'){

        if (!$ua->conn_cache()) {
            $self->logger->debug("Recreating the LWP::UserAgent to enable keep_alive");
            $ua = LWP::UserAgent->new(keep_alive => 1);
        }

        # Get credential
        my $username = $config->{userName};
        my $password = $config->{password};

        $self->logger->debug("Password is empty") unless $password;

        if ($username !~ /\\/){
            $self->logger->debug("Login does not contain a domain. Prepending '\\'");
            $username = '\\' . $username;
        }

        # Get url
        my $url = URI->new($config->{endpoint});

        # Get host:port
        my ($host, $port) = ($url->host(), $url->port);

        $self->logger->debug("Realm: $host:$port");

        $ua->credentials($host . ":" . $port, '', $username, $password);

        # TFS will return three possible authentication schemes. Bearer (OAuth, Basic and NTLM)
        # LWP::UserAgent will hug itself at Basic, so we should leave only NTLM for processing
        $ua->set_my_handler('response_done', sub {
            my HTTP::Response $response = shift;
            my HTTP::Headers $headers = $response->headers;

            # Get all the headers
            my @auth_headers = $headers->header('WWW-Authenticate');

            # Leave only NTLM header
            $headers->header('WWW-Authenticate', grep { $_ =~ /^ntlm/i } @auth_headers);

            # Apply the changed headers
            $response->headers($headers);
        });
    }
    elsif($auth_type ne '') {
        $self->bail_out("Unknown auth type in UA : '$auth_type'")
    }

    return $ua;
}

sub get_new_http_request {
    my ( $self, $method, $url ) = @_;

    print "[DEBUG] HTTP::Request instantiated for " . join(', ', caller) . "\n";

    my $request = HTTP::Request->new($method, $url);

    my $config_name = $self->get_param('config');
    my $config = $self->get_config_values($config_name);

    my $auth_type = $config->{auth} || '';

    # Get credential
    my $username = $config->{userName};
    my $password = $config->{password};

    $self->logger->debug("Password is empty") unless $password;

    if ($self->{auth_type} && ref $self->{auth_type}) {
        $self->{auth_type}->{request}->($request) if ($self->{auth_type}->{request});
    }
    elsif ($auth_type eq 'basic'){
        $self->logger->debug("Applying HTTP Basic header to the request.");
        $request->authorization_basic($username, $password);
    }
    elsif ($auth_type eq 'ntlm'){
        $self->logger->debug("Auth should be applied to LWP::UserAgent instance");
    }
    elsif ($auth_type ne ''){
        $self->bail_out("Unknown auth type in request : '$auth_type'")
    }

    return $request;
}





1;
