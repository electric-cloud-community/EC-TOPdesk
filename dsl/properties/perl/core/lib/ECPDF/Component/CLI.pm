=head1 NAME

=head1 ECPDF::Component::CLI

=head1 AUTHOR

Electric Cloud

=head1 DESCRIPTION

ECPDF::Component::CLI is an ECPDF::Component that is responsible for command-line execution.

=head1 INIT PARAMS

To read more about init params see L<ECPDF::ComponentManager>.

This component support following init params:

=over 4

=item (Required) workingDirectory

A parameter for working directory. CLI executor will chdir to this directory before commands execution.

=item (Optional) resultsDirectory

A parameter for output directory. Logs are being stored at this directory.

If no resultsDirectory parameter, defaults to workingDirectory parameter.

=back

=head1 USAGE

This component should be used in the following sequence:

=over 4

=item ECPDF::Component::CLI creation.

=item ECPDF::Component::CLI command creation.

=item Command execution.

=item Results procession.

=back

=head1 METHODS

=cut

package ECPDF::Component::CLI;
use base qw/ECPDF::BaseClass2/;

ECPDF::Component::CLI->defineClass({
    workingDirectory    => 'str',
    resultsDirectory    => 'str',
    componentInitParams => '*',
});

use strict;
use warnings;
use ECPDF::Helpers qw/isWin genRandomNumbers/;
use ECPDF::Component::CLI::Command;
use ECPDF::Component::CLI::ExecutionResult;
use ECPDF::Log;
use Carp;


sub init {
    my ($class, $params) = @_;

    if (!$params->{workingDirectory}) {
        croak "Working Directory is expected for CLI interface initialization\n";
    }

    if (!$params->{resultsDirectory}) {
        $params->{resultsDirectory} = $params->{workingDirectory};
    }
    return $class->new($params);
}


=head2 newCommand($shell, $args)

=head3 Description

Creates an L<ECPDF::Componen::CLI::Command> object that represents command line and being used by ECPDF::Component::CLI executor.

=head3 Parameters

=over 4

=item (Required)(String) Shell for the command, or full path to the command that should be executed.

=item (Required)(ARRAY ref) An arguments that will be escaped and added to the command.

=back

=head3 Returns

=over 4

=item L<ECPDF::Component::CLI::Command> object

=back

=cut

sub newCommand {
    my ($self, $shell, $args) = @_;

    my $command = ECPDF::Component::CLI::Command->new($shell, @$args);

    return $command;
}


=head2 runCommand()

=head3 Description

Executes provided command and returns an L<ECPDF::Component::CLI::ExecutionResult> object.

=head3 Parameters

=over 4

=item None

=back

=head3 Returns

=over 4

=item L<ECPDF::Component::CLI::ExecutionResult>

=back

=cut

sub runCommand {
    my ($self, $command, $mergeOut) = @_;

    $mergeOut ||= 0;
    logInfo("Running command: " . $command->renderCommand());
    if (my $wd = $self->getWorkingDirectory()) {
        chdir($wd) or croak "Can't chdir to $wd";
    }
    return $self->_syscall($command, $mergeOut);

}

sub _syscall {
    my ($self, $commandObject, $mergeOut) = @_;

    my $command = $commandObject->renderCommand();
    my $result_folder = $self->getResultsDirectory();
    my $stderr_filename = 'command_' . genRandomNumbers(42) . '.stderr';
    my $stdout_filename = 'command_' . genRandomNumbers(42) . '.stdout';
    $command .= qq| 1> "$result_folder/$stdout_filename" 2> "$result_folder/$stderr_filename"|;
    if (isWin) {
        logDebug("MSWin32 detected");
        $ENV{NOPAUSE} = 1;
    }

    my $pid = system($command);
    my $retval = {
        stdout => '',
        stderr => '',
        code => $? >> 8,
    };

    open (my $stderr, "$result_folder/$stderr_filename") or croak "Can't open stderr file ($stderr_filename) : $!";
    open (my $stdout, "$result_folder/$stdout_filename") or croak "Can't open stdout file ($stdout_filename) : $!";
    $retval->{stdout} = join '', <$stdout>;
    $retval->{stderr} = join '', <$stderr>;
    close $stdout;
    close $stderr;

    # Cleaning up
    unlink("$result_folder/$stderr_filename");
    unlink("$result_folder/$stdout_filename");

    my $result = ECPDF::Component::CLI::ExecutionResult->new($retval);
    return $result;
}




1;

