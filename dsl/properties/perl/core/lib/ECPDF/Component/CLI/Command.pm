=head1 NAME

ECPDF::Component::CLI::Command

=head1 AUTHOR

Electric Cloud

=head1 DESCRIPTION

This class represents a system command that is being used by L<ECPDF::Component::CLI>.

=head1 METHODS

=cut

package ECPDF::Component::CLI::Command;
use base qw/ECPDF::BaseClass/;
# ECPDF::Component::CLI::Command->defineClass({
#     shell => 'str',
#     args => 'str'
# });

use strict;
use warnings;

use ECPDF::Helpers qw/isWin/;
use ECPDF::Log;
use Carp;

sub classDefinition {
    return {
        shell => 'str',
        args => 'str'
    };
}


=head2 new($shell, @args)

=head3 Description

This method returns an ECPDF::Component::CLI::Command object.

=head3 Parameters

=over 4

=item (Required)(String) Command to be executed

=item (Optional)(list of Strings) Arguments to be added to the command.

=back

=head3 Returns

=head3 Usage

%%%LANG=perl%%%

    my $command = ECPDF::Component::CLI::Command->new('ls', '-la');

%%%LANG%%%

=head3 Note

It is much better to use newCommand metod from L<ECPDF::Component::CLI>

=cut

sub new {
    my ($class, $shell, @args) = @_;

    logDebug("Creating $class ...\n");
    # TODO: Improve validation here.
    # if (!-f $shell) {
    #     croak "File $shell that is provided to be used as shell does not exist.";
    # }

    @args = escapeArgs(@args);
    $shell = escapeArgs($shell);

    my $self = {
        args => \@args,
        shell => $shell
    };
    bless $self, $class;
    return $self;
    # return $class->SUPER::new({
    #     shell => $shell,
    #     args  => \@args
    # });
}

sub escapeArgs {
    my (@args) = @_;

    # TODO: Add croak if 1st argument is a reference, to be sure that this method is being used as static one.;
    @args = map {
        my $escapeCharacter = isWin() ? q|"| : q|'|;
        s/$escapeCharacter/\\$escapeCharacter/gs;
        $_ = sprintf('%s%s%s', $escapeCharacter, $_, $escapeCharacter);
        $_;
    } @args;
    return $args[0] unless wantarray();
    return @args;
}


=head2 addArguments(@args)

=head3 Description

Adds a new arguments to the command.

=head3 Parameters

=over 4

=item (Required)(list of String) arguments to be added

=back

=head3 Returns

=over 4

=item ECPDF::Component::CLI::Command self

=back

=head3 Usage

%%%LANG=perl%%%

    my $command = ECPDF::Component::CLI->newCommand('ls');
    $command->addArguments('-l', '-a');
%%%LANG%%%

=cut

sub addArguments {
    my ($self, @args) = @_;

    logDebug("Adding arguments: ". join(', ', @args));
    my $cmdArgs = $self->getArgs();
    for my $arg (escapeArgs(@args)) {
        push @$cmdArgs, $arg;
    }

    return $self;
}

=head2 renderCommand()

=head3 Description

Returns a rendered command with its arguments.

=head3 Parameters

=over 4

=item None

=back

=head3 Returns

=over 4

=item (String) Rendered command.

=back

=cut

sub renderCommand {
    my ($self, $opts) = @_;

    my $shell = $self->getShell();
    my $args = $self->getArgs();

    my $command = "$shell ";

    my $joinedArgs = join ' ', @$args;

    return $command . $joinedArgs;
}


1;
