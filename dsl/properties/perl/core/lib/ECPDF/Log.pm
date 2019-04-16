=head1 NAME

ECPDF::Log

=head1 AUTHOR

Electric Cloud

=head1 DESCRIPTION

This class provides logging functionality for ECPDF.

=head1 CAVEATS

This package is being loaded at the beginning of ECPDF execution behind the scene.

It is required to set up logging before other components are initialized.

Logger is retrieving through run context current debug level from configuration.

To enable this mechanics you need to add B<debugLevel> property to your configuration.

It will be automatically read and logger would already have this debug level.

Supported debug levels:

=over 4

=item B<INFO>

Provides standard output. This is default level.

debugLevel property should be set to 0.

=item B<DEBUG>

Provides the same output from INFO level + debug output.

debugLevel property should be set to 1.

=item B<TRACE>

Provides the same output from DEBUG level + TRACE output.

debugLevel property should be set to 2.

=back

=head1 SYNOPSIS

To import ECPDF::Log:

%%%LANG=perl%%%

    use ECPDF::Log

%%%LANG%%%

=head1 METHODS

This package imports following functions on load into current scope:


=head2 logInfo(@messages)

=head3 Description

Logs an info message. Output is the same as from print function.

=head3 Parameters

=over 4

=item (List of String) Log messages

=back

=head3 Returns

=over

=item (Boolean) 1

=back

=head3 Usage

%%%LANG=perl%%%

    logInfo("This is an info message");

%%%LANG%%%

=head2 logDebug(@messages)

=head3 Description

Logs a debug message.

=head3 Parameters

=over 4

=item (List of String) Log messages

=back

=head3 Returns

=over

=item (Boolean) 1

=back

=head3 Usage

%%%LANG=perl%%%

    # this will print [DEBUG] This is a debug message.
    # but only if debug level is enough (DEBUG or more).
    logDebug("This is a debug message");

%%%LANG%%%

=head2 logTrace(@messages)

=head3 Description

Logs a trace message

=head3 Parameters

=over 4

=item (List of String) Log messages

=back

=head3 Returns

=over

=item (Boolean) 1

=back

=head3 Usage

%%%LANG=perl%%%

    # this will print [TRACE] This is a trace message.
    # but only if debug level is enough (TRACE or more).
    logTrace("This is a debug message");

%%%LANG%%%

=head2 logWarning(@messages)

=head3 Description

Logs a warning message.

=head3 Parameters

=over 4

=item (List of String) Log messages

=back

=head3 Returns

=over

=item (Boolean) 1

=back

=head3 Usage

%%%LANG=perl%%%
    # this will print [WARNING] This is a warning message for any debug level:
    logWarning("This is a warning message");
%%%LANG%%%

=head2 logError(@messages)

=head3 Description

Logs an error message

=head3 Parameters

=over 4

=item (List of String) Log messages

=back

=head3 Returns

=over

=item (Boolean) 1

=back

=head3 Usage

%%%LANG=perl%%%

    # this will print [ERROR] This is an error message for any debug level:
    logError("This is an error message");

%%%LANG%%%



=cut

package ECPDF::Log;
use base qw/Exporter/;

our @EXPORT = qw/logInfo logDebug logTrace logError logWarning/;
use strict;
use warnings;
use Data::Dumper;

our $LOG_LEVEL = 0;
our $LOG_TO_PROPERTY = '';

use constant {
    ERROR => -1,
    INFO  => 0,
    DEBUG => 1,
    TRACE => 2,
};

sub new {
    my ($class, $opts) = @_;

    my ($level, $log_to_property);

    if (!defined $opts->{level}) {
        $level = $LOG_LEVEL;
    }
    if (!defined $opts->{log_to_property}) {
        $log_to_property = $LOG_TO_PROPERTY;
    }
    my $self = {
        level           => $level,
        log_to_property => $log_to_property
    };
    bless $self, $class;
    return $self;
}

sub logInfo {
    my @params = @_;
    if (!ref $params[0]) {
        unshift @params, __PACKAGE__->new();
    }
    return info(@params);
}
sub info {
    my ($self, @messages) = @_;
    $self->_log(INFO, @messages);
}

sub logDebug {
    my @params = @_;
    if (!ref $params[0]) {
        unshift @params, __PACKAGE__->new();
    }
    return debug(@params);
}
sub debug {
    my ($self, @messages) = @_;
    $self->_log(DEBUG, '[DEBUG]', @messages);
}

sub logError {
    my @params = @_;
    if (!ref $params[0]) {
        unshift @params, __PACKAGE__->new();
    }
    return error(@params);
}
sub error {
    my ($self, @messages) = @_;
    $self->_log(ERROR, '[ERROR]', @messages);
}


sub logWarning {
    my @params = @_;
    if (!ref $params[0]) {
        unshift @params, __PACKAGE__->new();
    }
    return error(@params);
}
sub warning {
    my ($self, @messages) = @_;
    $self->_log(INFO, '[WARNING]', @messages);
}



sub logTrace {
    my @params = @_;
    if (!ref $params[0]) {
        unshift @params, __PACKAGE__->new();
    }
    return trace(@params);
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
