# Version: Wed Nov 14 18:29:15 2018
#
#  Copyright 2015 Electric Cloud, Inc.
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#

=head1 NAME

EC::Plugin::Core

=head1 DESCRIPTION

Toolkit for plugin development. Contains subroutines for system calls, OS detection, debug, ETC, and others.

=over

=cut

package EC::Plugin::Core;
use strict;
use warnings;
use subs qw/is_win/;

use Carp;
use IPC::Open3;
use IO::Select;
use Symbol qw/gensym/;
use File::Spec;
use Data::Dumper;

use EC::Bootstrap;

my $DRYRUN = 0;


=item B<new>

Constructor. Parameters:

debug_level => 0 .. 6

=cut

sub new {
    my ($class, %params) = @_;

    my $self = {};
    bless $self, $class;

    before_init_hook(@_);
    if ($params{debug_level}) {
        # $self->{_init}->{debug_level} = $params{debug_level}
        $self->debug_level($params{debug_level});
    }
    if ($params{result_folder}) {
        $self->{_init}->{result_folder} = $params{result_folder};
    }
    if ($params{ec}) {
        $self->{_ec} = $params{ec};
    }

    if ($params{project_name}) {
        $self->{project_name} = $params{project_name};
    }
    if ($params{plugin_name}) {
        $self->{plugin_name} = $params{plugin_name};
    }
    if ($params{plugin_key}) {
        $self->{plugin_key} = $params{plugin_key}
    }
    defined $self->debug_level() or do {
        $self->debug_level(1);
    };

    $self->after_init_hook(%params);
    if ($params{dryrun}) {
        $self->dryrun(1);
    }
    return $self;
}


=item B<dryrun>

Is dryrun flag.

=cut

sub dryrun {
    my ($self, $dryrun) = @_;

    if (!defined $dryrun) {
        return $DRYRUN;
    }
    $DRYRUN = $dryrun;
}


=item B<ec>

Returns ElectricCommander instance.

When called first time executes ElectricCommander->new();
All next times it just returns instance without initialization


=cut

sub ec {
    my ($self) = @_;

    if (!$self->{_ec}) {
        require ElectricCommander;
        import ElectricCommander;
        $self->{_ec} = ElectricCommander->new();
    }
    return $self->{_ec};
}



=item B<check_executable>

Returns {ok => 1, msg => ''} if file can be executed. If not, returns reason in msg field.

    my $check = $core->check_executable('/path/to/file');
    unless ($check->{ok}) {
        die "File is not an executable";
    }

=cut

sub check_executable {
    my ($self, $file_path) = @_;

    my $retval = {
        ok => 0,
        msg => '',
    };

    if ($self->dryrun()) {
        $retval->{ok} = 1;
        return $retval;
    }

    if (!-e $file_path) {
        $retval->{msg} = "File $file_path doesn't exist";
        return $retval;
    }

    if (-d $file_path) {
        $retval->{msg} = "$file_path is a directory";
        return $retval;
    }

    if (!-x $file_path) {
        $retval->{msg} = "$file_path is not an executable";
        return $retval;
    }

    $retval->{ok} = 1;
    return $retval;
}


=item B<set_property>

Sets property of step by property name

    $core->set_property(summary=>'Done with success');

Returns 1.

=cut

sub set_property {
    my ($self, $key, $value) = @_;

    $self->ec()->setProperty("/myCall/$key", $value);
    return 1;
}

sub property_exists {
    my ($self, $prop) = @_;

    my $no_error_transaction = sub {
        my ($code) = @_;
        $self->ec->abortOnError(0);
        eval {
            $code->();
        };
        my $err = $@;
        $self->ec->abortOnError(1);
        if ($err) {
            die $err;
        }
    };

    my $exists = 1;
    my $error_message;
    $no_error_transaction->(
        sub {
            my $xpath = $self->ec->getProperty($prop);
            my $code = $xpath->findvalue('//code')->string_value;
            $self->logger->info(qq{Trying to get "$prop": $code});
            if ($code) {
                $exists = 0;
                $error_message = qq{Cannot get property "$prop": $code};
            }
        }
    );
    return ($exists, $error_message);
}

=item B<success>

Sets outcome step status to success.

    $core->success();

=cut

sub success {
    my ($self, @msg) = @_;

    $self->set_summary(@msg);
    return $self->_set_outcome('success');
}


=item B<error>

Sets outcome step status to error.

    $jboss->error();

=cut

sub error {
    my ($self, @msg) = @_;

    $self->set_summary(@msg);
    return $self->_set_outcome('error');
}


=item B<warning>

Sets outcome step status to warning.

    $jboss->waring();

=cut

sub warning {
    my ($self, @msg) = @_;

    $self->set_summary(@msg);
    return $self->_set_outcome('warning');
}


=item B<_set_outcome>

Sets outcome status to desired status.

    $jboss->_set_outcome('aborted');

=cut

sub _set_outcome {
    my ($self, $status) = @_;

    $self->ec()->setProperty('/myJobStep/outcome', $status);
}

=item B<set_output_parameter>

Sets output parameter safely.

    $plugin->set_output_parameter('aborted', 'true');

=cut

sub set_output_parameter {
    my ($self, $name, $value, $attach_params) = @_;

    if (!defined $value){
        $self->logger->debug("Will not save undefined value for outputParameter '$name'");
        return;
    };

    # Will fall if parameter does not exists
    eval {
        if ($value && (ref $value eq 'HASH' || ref $value eq 'ARRAY')){
            require JSON unless $JSON::VERSION;
            $value = JSON::encode_json($value);
        }

        # 0e0 can be returned by EC::Bootstrap function and means parameter was not really set
        my $is_set = $self->ec->setOutputParameter($name, $value, $attach_params);
        if ($is_set && !$is_set eq '0E0'){
            $self->logger->info("Output parameter '$name' has been set to '$value'"
                . (defined $attach_params ? "and attached to " . Dumper($attach_params) : ''));
        }
    };
    if ($@){
        $self->logger->debug("Output parameter '$name' can't be saved : $@");
        return 0;
    }

    return 1;
}


=item B<bail_out>

Terminating execution immediately with error message.

    $core->bail_out("Something was VERY wrong");

=cut

sub bail_out {
    my ($self, @msg) = @_;

    my $msg = join '', @msg;

    $msg ||= 'Bailed out.';
    $msg .= "\n";

    $self->error();
    $self->logger->info("BAILED_OUT:\n$msg\n");

    return $self->finish_procedure_with_error($msg);
}


=item B<finish_procedure>

Finishing execution with success exit code.

    $plugin->finish_procedure("Some minor issue, but we took care of it");

=cut

sub finish_procedure {
    my ($self, @msg) = @-;

    my $msg = join '', @msg;
    $msg ||= '';

    if ($msg) {
        $self->set_summary($msg);
        $self->logger->message($msg);
    }
    exit 0;
}

=item B<finish_procedure>

Finishing execution with error and exit code. Main goal is to set PipelineStage error summary too.

    $plugin->finish_procedure_with_error("Something bad happened and we cannot proceed");

=cut
sub finish_procedure_with_error {
    my ($self, @msg) = @_;

    my $msg = join(' ', @msg);
    $msg = ($msg || '') . "\n";

    $self->ec()->setProperty("/myCall/summary", $msg);

    if ($self->in_pipeline()){
        $self->ec()->setProperty("/myPipelineStageRuntime/ec_summary/Error", $msg);
    }
    else {
        $self->ec()->setProperty("/myJobStep/summary", $msg);
    }

    exit 1;
}


=item B<set_summary>

Sets job status.

=cut

sub set_summary {
    my ($self, @msg) = @_;

    my $msg = join '', @msg;
    if (!$msg) {
        return 1;
    }

    $self->set_property(summary => $msg);
}


=item B<before_init_hook>

Called BEFORE blessing hash reference in the constructor

This subroutine should be overrided.

    *EC::Plugin::Core::before_init_hook = sub {
        my ($class, constructor_params) = @_;
        return 1;
    }

=cut

sub before_init_hook {
    1;
}

=item B<after_init_hook>

Called AFTER blessing a hash reference and before return object in new.

This subroutine should be overrided.

    *EC::Plugin::Core::after_init_hook = sub {
        my ($self, %constructor_params) = @_;
        # You can add additional actions for constructor
        $self->{my_cool_property} = 'my_custom_property';
    }

=cut

sub after_init_hook {
    1;
}


=item B<run_command_with_timeout>

B<WARNING:> Right now this function supports ONLY unix OS because of EC perl for windows
was packed without signals support. And supported signals are weird.

    my $res = $core->run_command_with_timeout(10, 'ls -la');

Returns the same value as run_command.

=cut

sub run_command_with_timeout {
    my ($self, $timeout, @cmd) = @_;

    my $timeout_response = {
        code => -2,
        stdout => 'TIMEOUT',
        stderr => 'TIMEOUT',
    };
    my $res = $self->exec_timelimit(
        limit => $timeout,
        do => sub {
            return $self->run_command(@cmd);
        },
        on_timeout => sub {
            return $timeout_response;
        },
        on_success => sub {
            my $result = shift;
            if ($result->{stderr} =~ m/TIMEOUT\n/s) {
                return $timeout_response;
            }
            return $result;
        }
    );
    return $res;
}


=item B<get_credentials>

Returns credentials data as hash reference.

    $core->get_credentials(
        'plugin_config_name' => {
            userName => 'user',
            password => 'password',
        }, 'plugin_cfgs'
    );

Where 1st parameter is a configuration name, second parameter is a mapper, third parameter
is path for plugin configs. For example, for JBoss it will be jboss_cfgs.

About mapper. Mapper maps credentials data as user specified. With mapper from above example
it will return credentials {user => 'username', password=>'coolpassword'}

=cut

sub get_credentials {
    my ($self, $config_name, $config_rows, $cfgs_path) = @_;

    print "Running it\n";
    if ($self->{_credentials} && ref $self->{_credentials} eq 'HASH' && %{$self->{_credentials}}) {
        return $self->{_credentials};
    }
    if (!$config_name && !$self->{config_name}) {
        croak "Configuration doesn't exist";
    }

    my $ec = $self->ec();
    $config_name ||= $self->{config_name};
    my $project = $self->{project_name};

    my $pattern = sprintf '/projects/%s/' . $cfgs_path, $project;
    my $plugin_configs;
    eval {
        $plugin_configs = ElectricCommander::PropDB->new($ec, $pattern);
        1;
    } or do {
        $self->out(1, "Can't access credentials.");
        # bailing out if can't access credendials.
        $self->bail_out("Can't access credentials.");
    };

    my %config_row;
    eval {
        %config_row = $plugin_configs->getRow($config_name);
        1;
    } or do {
        $self->out(1, "Configuration $config_name doesn't exist.");
        # bailing out if configuration specified doesn't exist.
        $self->bail_out("Configuration $config_name doesn't exist.");
    };

    unless (%config_row) {
        croak "Configuration doesn't exist";
    }

    my $retval = {};

    my $xpath = $ec->getFullCredential($config_row{credential});
    # {userName => 'user'}
    for my $key (keys %$config_rows) {
        my $v = '';
        if ($key eq 'userName' || $key eq 'password') {
            $v = '' . $xpath->findvalue('//' . $key);
        }
        else {
            $v = $config_row{$key};
        }
        $v ||= '';
        $retval->{$config_rows->{$key}} = $v;
    }
    # $retval->{user} = '' . $xpath->findvalue("//userName");
    # $retval->{password} = '' . $xpath->findvalue("//password");
    # $retval->{java_home} = '' . $config_row{java_home};
    # $retval->{weblogic_url} = '' . $config_row{weblogic_url};

    return $retval;

}


sub get_config_values {
    my ($self, $config_name) = @_;

    die 'No config name' unless $config_name;
    my $plugin_project_name = '@PLUGIN_KEY@-@PLUGIN_VERSION@';
    my $config_property_sheet = "/projects/$plugin_project_name/ec_plugin_cfgs/$config_name";
    my $property_sheet_id = eval { $self->ec->getProperty($config_property_sheet)->findvalue('//propertySheetId')->string_value };
    if ($@) {
        $self->bail_out(qq{Configuration "$config_name" does not exist});
    }
    my $properties = $self->ec->getProperties({propertySheetId => $property_sheet_id});

    my $retval = {};
    for my $node ( $properties->findnodes('//property')) {
        my $value = $node->findvalue('value')->string_value;
        my $name = $node->findvalue('propertyName')->string_value;
        $retval->{$name} = $value;


        if ($name =~ /proxy_credential/) {
            # Proxy credential can exist not, and EC will fail. Avoiding
            my $saved_abort_on_error_value = $self->ec->abortOnError();
            eval {
                $self->ec->abortOnError(0);
                my $credentials = $self->ec->getFullCredential($config_name . '_proxy_credential');
                my $user_name = $credentials->findvalue('//userName')->string_value;
                my $password = $credentials->findvalue('//password')->string_value;

                $retval->{proxy_username} = $user_name;
                $retval->{proxy_password} = $password;
            } or do {
                print "Can't get proxy credential: $@ \n";
            };

            # Restore value
            $self->ec->abortOnError($saved_abort_on_error_value);
        }
        elsif ($name =~ /credential/) {
            my $credentials = $self->ec->getFullCredential($config_name);
            my $user_name = $credentials->findvalue('//userName')->string_value;
            my $password = $credentials->findvalue('//password')->string_value;

            $retval->{userName} = $user_name;
            $retval->{password} = $password;
        }

    }

    return $retval;
}



=item B<safe_cmd>

Returns system command as is. For output purification should be extended in the child class.

=cut

sub safe_cmd {
    my ($self, $command) = @_;

    return $command;
}


=item B<run_command>

Running system command. This function is cross-platrorm.
For unix OS it implemented on pipes, without any additional files, for win32 it implemented with system and files for stdout and stderr.

    my $res = $self->run_command('ls -la');
    printf "Exited with code %s, Stdout: %s, Stderr: %s", $res->{code}, $res->{stdout}, $res->{stderr};

=cut

sub run_command {
    my ($self, @cmd) = @_;

    my $retval = {
        code => 0,
        stdout => '',
        stderr => ''
    };

    my $cmd_to_display = join '', @cmd;
    $cmd_to_display = $self->safe_cmd($cmd_to_display);
    $self->out(1, "Running command: " . $cmd_to_display);
    if ($self->dryrun()) {
        $self->dbg("Running command in dryrun mode");
        return {
            code => 0,
            stdout => 'DUMMY_STDOUT',
            stderr => 'DUMMY_STDERR',
        };
    }
    if (is_win) {
        $retval =  $self->_syscall_win32(@cmd);
    }
    else {
        $retval =  $self->_syscall(@cmd);
    }
    return $retval;
}


=item B<_syscall>

System call for unix OS. Implemented over IPC::Open3. Internal function.
You should use run_command insted.


=cut

sub _syscall {
    my ($self, @command) = @_;

    my $command = join '', @command;
    unless ($command) {
        croak  "Missing command";
    }
    my ($infh, $outfh, $errfh, $pid, $exit_code);
    $errfh = gensym();
    eval {
        $pid = open3($infh, $outfh, $errfh, $command);
        waitpid($pid, 0);
        $exit_code = $? >> 8;
        1;
    } or do {
        # croak "Error occured during command execution: $@";
        return {
            code => -1,
            stderr => $@,
            stdout => '',
        };
    };

    my $retval = {
        code => $exit_code,
        stderr => '',
        stdout => '',
    };
    my $sel = IO::Select->new();
    $sel->add($outfh, $errfh);

    while(my @ready = $sel->can_read) { # read ready
        foreach my $fh (@ready) {
            my $line = <$fh>; # read one line from this fh
            if (not defined $line) {
                $sel->remove($fh);
                next;
            }
            if ($fh == $outfh) {
                $retval->{stdout} .= $line;
            }
            elsif ($fh == $errfh) {
                $retval->{stderr} .= $line;
            }

            if (eof $fh) {
                $sel->remove($fh);
            }
        }
    }
    return $retval;
}


=item B<_syscal_win32>

System call for Win OS. Implemented with additional files because of older win OS
haven't pipes support, but both of them have same ID - MSWin32, so, this is the solution.

Internal function. You should use run_command instead.

=cut

sub _syscall_win32 {
    my ($self, @command) = @_;

    my $command = join ' ', @command;

    my $result_folder = $ENV{COMMANDER_WORKSPACE};
    if (!$result_folder) {
        $self->out(1, "Missing ENV for result folder. Result folder set to .");
        $result_folder = '.';
    }
    my $stderr_filename = 'command_' . gen_random_numbers(42) . '.stderr';
    my $stdout_filename = 'command_' . gen_random_numbers(42) . '.stdout';
    $command .= qq| 1> "$result_folder/$stdout_filename" 2> "$result_folder/$stderr_filename"|;
    if (is_win) {
        $self->dbg("MSWin32 detected");
        $ENV{NOPAUSE} = 1;
    }

    my $pid = system($command);
    my $retval = {
        stdout => '',
        stderr => '',
        code => $? >> 8,
    };

    open my $stderr, "$result_folder/$stderr_filename" or croak "Can't open stderr file ($stderr_filename) : $!";
    open my $stdout, "$result_folder/$stdout_filename" or croak "Can't open stdout file ($stdout_filename) : $!";
    $retval->{stdout} = join '', <$stdout>;
    $retval->{stderr} = join '', <$stderr>;
    close $stdout;
    close $stderr;

    # Cleaning up
    unlink("$result_folder/$stderr_filename");
    unlink("$result_folder/$stdout_filename");

    return $retval;
}

sub gen_random_numbers {
    my ($mod) = @_;

    my $rand = rand($mod);
    $rand =~ s/\.//s;
    return $rand;
}

=item B<set_pipeline_summary>

Sets pipeline summary (only if the job step runs in a pipeline)

=cut

sub set_pipeline_summary {
    my ($self, $name, $message) = @_;

    unless($self->in_pipeline) {
        return;
    }
    eval {
        $self->ec->setProperty("/myPipelineStageRuntime/ec_summary/$name", $message);
        1;
    };
}

sub in_pipeline {
    my ($self) = @_;

    my $retval;
    eval {
        $self->ec->getProperty('/myPipelineStageRuntime/id');
        $retval = 1;
        1;
    } or do {
        $retval = 0;
    };
    return $retval;
}


=item B<is_win>

Returns true if OS is Win.

    if ($core->is_win()) {
        print "Windows detected";
    }

=cut

sub is_win {
    if ($^O eq 'MSWin32') {
        return 1
    }
    return 0;
}


sub debug_level {
    my ($self, $debug_level) = @_;

    if (defined $debug_level) {
        $self->{_init}->{debug_level} = $debug_level;
        return $self->{_init}->{debug_level};
    }

    if (defined $self->{_init}->{debug_level}) {
        return $self->{_init}->{debug_level};
    }
    return 0;
}

=item B<dbg>

Right now just wrapper for out(1, ...);

=cut

sub dbg {
    my ($self, @params) = @_;
    return $self->out(1, @params);
}


=item B<out>

Prints result if core debug level >= specified debug level

    $core->out(1, "Debug level one");

=cut

sub out {
    my ($self, $debug_level, @msg) = @_;

    # protection from dumb typos
    $debug_level =~ m/^\d+$/s or do {
        $debug_level = 1;
        unshift @msg, $debug_level;
    };
    if (!$self->debug_level()) {
        return 1;
    }
    if ($self->debug_level() < $debug_level) {
        return 1;
    }
    my $msg = join '', @msg;

    $msg =~ s/\s+$//gs;
    $msg .= "\n";
    print $msg;
    return 1;
}

sub render_template {
    my ($self, @params) = @_;

    return EC::MicroTemplate::render(@params);
}


sub get_param {
    my ($self, $param) = @_;

    my $ec = $self->ec();
    my $retval;
    eval {
        $retval = $ec->getProperty($param)->findvalue('//value') . '';
        1;
    } or do {
        $self->dbg("Error '$@' was occured while getting property: $param");
        $retval = undef;
    };

    return $retval;
}


sub esc_args {
    my ($self, @args) = @_;

    @args = map {
        if (is_win) {
            $_ =~ s/"/\\"/gs;
            $_ = qq|"$_"|;
        }
        else {
            $_ =~ s/'/\\'/gs;
            $_ = qq|'$_'|;
        }
    } @args;

    if (wantarray) {
        return @args;
    }
    my $str =  join ' ', @args;
    trim($str);
    return $str;
}

=item B<get_params_as_hashref>

Returns request params as hashref by list of param names.

    my $params = $core->get_params_as_hashref('param1', 'param2', 'param3');
    # $params = {
    #     param1  =>  'value1',
    #     param2  =>  'value2',
    #     param3  =>  'value3'
    # }

=cut

sub get_params_as_hashref {
    my ($self, @params_list) = @_;

    my $retval = {};
    my $ec = $self->ec();
    for my $param_name (@params_list) {
        my $param = $self->get_param($param_name);
        next unless defined $param;
        $retval->{$param_name} = trim_input($param);
    }
    for my $param_name (keys %$retval) {
        my $value = $retval->{$param_name};
        $self->logger->info(qq{Got parameter "$param_name" with value "$value"});
    }
    return $retval;
}

sub  trim_input {
    my $s = shift;

    #remove leading and trailing spaces
    $s =~ s/^\s+|\s+$//g;
    return $s
}

=item B<render_template_from_property>

$template_name - property name to take template from
If it is not an absolute property path, the template is taken from current plugin properties/resources/templates/<template name>

$params - params for rendering
%options
    mt - use Text::MicroTemplate engine instead of EC::MicroTemplate

=cut

sub render_template_from_property {
    my ($self, $template_name, $params, %options) = @_;

    if (!$template_name) {
        croak "No template";
    }
    my $template;
    $self->logger->debug("Processing template $template_name");
    if ($template_name !~ /^\//) {
        my $plugin_name = $self->{plugin_name};
        $template_name = "/projects/$plugin_name/resources/templates/$template_name";
    }
    $template = $self->get_param($template_name);
    unless ($template) {
        croak "Template $template_name wasn't found";
    }

    if ($options{mt}) {
        return $self->_render_mt(text => $template, render_params => $params);
    }
    else {
        return $self->render_template(text => $template, render_params => $params);
    }
}


sub deprecated_procedure_warning {
    my ($self) = @_;

    $self->logger->info('Deprecation warning: This procedure is deprecated and will be removed in the next release.');
}

sub _render_mt {
    my ($self, %params) = @_;

    my $template = $params{text};
    my $render_params = $params{render_params};

    require Text::MicroTemplate;
    my $renderer = Text::MicroTemplate::build_mt($template);
    # $self->logger->trace($render_params);
    my $result = eval { $renderer->($render_params)->as_string };
    if ($@) {
        my $message = "Render failed: $@";
        $message .= Dumper(\%params);
        die $message;
    }
    return $result;
}

# TODO: add simple version of exec_timelimit
sub exec_timelimit_simple {
    1;
};


sub do_while {
    my ($self, $do, $while, $timeout) = @_;

    my $do_while = time() + $timeout;
    my $result;
    my $done = 0;
    my $timed_out = 0;
    while(!$done) {
        $result = $do->();
        if ($result eq $while) {
            $done = 1;
            last;
        }
        if (time() > $do_while) {
            $timed_out = 1;
            $done = 1;
        }
    }

    if ($timed_out) {
        return 0;
    };
    return $result;
}


sub exec_timelimit {
    my ($self, %params) = @_;

    if (!$params{limit}) {
        croak "Missing limit parameter";
    }
    if ($params{limit} !~ m/^\d+$/s) {
        croak "Limit param must be numeric"
    }
    for (qw/do on_success on_timeout/) {
        $params{$_} or croak "Missing param: $_";
        if (ref $params{$_} ne 'CODE') {
            croak "$_ param must be a subroutine";
        }
    }

    my $result = undef;
    eval {
        # timeout handler
        local $SIG{ALRM} = sub {
            die "TIMEOUT\n"; # \n is required
        };
        # Timeout set
        alarm($params{limit});
        # Starting user sub

        $result = $params{do}->();
        alarm 0;
        1;
    } or do {
        return $params{on_timeout}->($result, $@);
    };

    return $params{on_success}->($result);
};


sub parse_tagsmap {
    my ($self, $map) = @_;
    $map =~ s/\n//gis;
    my $result = {};
    my @t = split /,/, $map;

    for my $row (@t) {
        # negative lookbehind
        my @arr = split(/(?<!\\)=>/, $row);
        if (scalar @arr > 2) {
            die "Error occured";
        }
        trim($arr[0]);
        trim($arr[1]);
        $result->{$arr[0]} = $arr[1];
    }
    return $result;
}


# removes leading and trailing whitespaces
# STATIC
sub trim {
    $_[0] or return;
    $_[0] =~ s/^\s+//s;
    $_[0] =~ s/\s+$//s;
}


sub canon_path {
    my ($path) = @_;
    return File::Spec->canonpath($path);
}


sub logger {
    my ($self) = @_;
    unless($self->{logger}) {
        $self->{logger} = EC::Plugin::Logger->new($self->debug_level);
    }
    return $self->{logger};
}


sub build_metadata_location {
    my ($self, $filter, $reportingType) = @_;

    my $context = $self->get_run_context();
    print "Context found: $context\n";
    my $location = '';
    my $projectName = $self->get_project_name();

    if ($context eq 'schedule') {
        # '/projects/<projectName>/schedules/<scheduleName>/ecreport_data_tracker/<jobName>
        my $scheduleName = $self->get_schedule_name();
        $location = "/projects/$projectName/schedules/$scheduleName/ecreport_data_tracker";
    }
    else {
        # '/projects/<projectName>/ecreport_data_tracker/<jobName>'.
        $location = "/projects/$projectName/ecreport_data_tracker";
    }

    my $propertyName = '@PLUGIN_KEY@' . '-' . $filter . '-' . $reportingType;
    $location .= '/' . $propertyName;
    return $location;
}


# this function returns current context of call. could return: schedule, pipeline, procedure
sub get_run_context {
    my ($self) = @_;

    my $ec = $self->ec;
    my $context = 'pipeline';

    eval {
        my $flowRuntimeId = $ec->getProperty('/flowRuntime/id')->findvalue('/value')->string_value();
        return $context if $flowRuntimeId;
    };

    $context = 'schedule';
    my $scheduleName = '';
    eval {
        $scheduleName = $self->get_schedule_name();
        1;
    } or do {
        $self->bail_out("error occured: $@\n");
    };

    if ($scheduleName) {
        return $context;
    }
    $context = 'procedure';
    return $context;
}

sub get_project_name {
    my ($self, $jobId) = @_;

    $jobId ||= $ENV{COMMANDER_JOBID};

    my $projectName = '';
    eval {
        my $result = $self->ec->getJobDetails($jobId);
        $projectName = $result->findvalue('//job/projectName')->string_value();
        1;
    } or do {
        $self->bail_out($@);
    };

    return $projectName;
}

sub get_schedule_name {
    my ($self, $jobId) = @_;

    $jobId ||= $ENV{COMMANDER_JOBID};

    my $scheduleName = '';
    eval {
        my $result = $self->ec->getJobDetails($jobId);
        $scheduleName = $result->findvalue('//scheduleName')->string_value();
        if ($scheduleName) {
            $self->logger->info("Schedule found: $scheduleName");
        }
        1;
    } or do {
        $self->bail_out("error occured: $@");
    };

    return $scheduleName;
}


sub get_metadaa {
    my ($self, $location) = @_;

    my $meta;
    my $json;
    eval {
        $json = $self->ec->getProperty($location)->findvalue('//value')->value;
        1;
    } or do {
        $self->logger->info("No metadata found by path $location");
        return {};
    };

    eval {
        $meta = decode_json($json);
        1;
    } or do {
        $self->bail_out("Corrupted metadata: $json");
    };
    return $meta;
}

sub set_metadata {
    my ($self, $location, $meta) = @_;

    my $json = encode_json($meta);
    $self->ec->setProperty($location, $json);
    $self->logger->info("Saved metadata under property $location");
}



=back

=cut

1;

package EC::MicroTemplate;

use strict;
use warnings;

use Carp;

our $ANCHOR = ['\[%', '%\]'];
our $ESCAPE = 0;

=over

=item B<render>

Returns rendered template. Accepts as parameters file or handle
and variables hashref(key=>value).

=back

=cut

sub render {
    my (%params) = @_;

    if (!$params{file} && !$params{handle} && !$params{text}) {
        croak "Can't render nothing";
    }

    if ($params{render_params} && ref $params{render_params} ne 'HASH') {
        croak "render_params must be a hashref";
    }

    my $render_params = $params{render_params};

    $render_params->{PERL} = $^X;
    my @template;

    if ($params{file}) {
        @template = _tff($params{file});
    }
    elsif($params{handle}) {
        @template = _tfd($params{handle});
    }
    else {
        @template = split "\n", $params{text};
    }

    my $escape = 0;
    if ($ENV{MICROTEMPLATE_ESCAPE_PARAMS} ||  $params{escape} || $ESCAPE) {
        $escape = 1;
    }
    if ($params{noescape}) {
        $escape = 0;
    }
    local *{EC::MicroTemplate::parse} = sub {
        my $string = shift;
        for my $key (keys %$render_params) {
            next unless defined $render_params->{$key};
            if ($escape) {
                $render_params->{$key} =~ s|\\|\\\\|gs;
            }
            $string =~ s/$ANCHOR->[0]\s*?$key\s*?$ANCHOR->[1]/$render_params->{$key}/gs;
        }
        my $template = "$ANCHOR->[0].*?$ANCHOR->[1]";
        # print $template;
        $string =~ s/$template//gs;

        return $string;
    };

    @template = map {
        parse($_);
    } @template;
    return join "\n", @template;
}


# template from file
sub _tff {
    my $file = shift;

    unless (-e $file) {
        croak "File $file does not exists.";
    }

    my $fh;

    open $fh, $file or croak "Can't open file $file: $!";
    return _tfd($fh);
}


#template from descriptor
sub _tfd {
    my $glob = shift;

    my @content = <$glob>;
    close $glob;
    return @content;
}


1;

package EC::Plugin::Logger;

use strict;
use warnings;
use Data::Dumper;

use constant {
    ERROR => -1,
    INFO => 0,
    DEBUG => 1,
    TRACE => 2,
};

sub new {
    my ($class, $level, %param) = @_;
    $level ||= 0;
    my $self = {%param, level => $level};
    return bless $self,$class;
}

sub info {
    my ($self, @messages) = @_;
    $self->_log(INFO, @messages);
}

sub debug {
    my ($self, @messages) = @_;
    $self->_log(DEBUG, '[DEBUG]', @messages);
}

sub error {
    my ($self, @messages) = @_;
    $self->_log(ERROR, '[ERROR]', @messages);
}

sub trace {
    my ($self, @messages) = @_;
    $self->_log(TRACE, '[TRACE]', @messages);
}

sub level {
    my ($self, $level) = @_;

    if (defined $level) {
        $self->{level} = $level;
    }
    else {
        return $self->{level};
    }
}

sub log_to_property {
    my ($self, $prop) = @_;

    if (defined $prop) {
        $self->{log_to_property} = $prop;
    }
    else {
        return $self->{log_to_property};
    }
}


my $length = 40;

sub divider {
    my ($self, $thick) = @_;

    if ($thick) {
        $self->info('=' x $length);
    }
    else {
        $self->info('-' x $length);
    }
}

sub header {
    my ($self, $header, $thick) = @_;

    my $symb = $thick ? '=' : '-';
    $self->info($header);
    $self->info($symb x $length);
}

sub _log {
    my ($self, $level, @messages) = @_;

    return if $level > $self->level;
    my @lines = ();
    for my $message (@messages) {
        if (ref $message) {
            print Dumper($message);
            push @lines, Dumper($message);
        }
        else {
            print "$message\n";
            push @lines, $message;
        }
    }

    if ($self->{log_to_property}) {
        my $prop = $self->{log_to_property};
        my $value = "";
        eval {
            $value = $self->ec->getProperty($prop)->findvalue('//value')->string_value;
            1;
        };
        unshift @lines, split("\n", $value);
        $self->ec->setProperty($prop, join("\n", @lines));
    }
}


sub ec {
    my ($self) = @_;
    unless($self->{ec}) {
        require ElectricCommander;
        my $ec = ElectricCommander->new;
        $self->{ec} = $ec;
    }
    return $self->{ec};
}



1;




