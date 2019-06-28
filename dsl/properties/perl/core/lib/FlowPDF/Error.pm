package FlowPDF::Error;
use base qw/FlowPDF::BaseClass2/;
use FlowPDF::Types;

__PACKAGE__->defineClass({
    errorType     => FlowPDF::Types::Scalar(),
    errorGroup    => FlowPDF::Types::Scalar(),
    errorMessage  => FlowPDF::Types::Scalar(),
    erroCode      => FlowPDF::Types::Scalar(),
});

use strict;
use warnings;
use Carp;
use FlowPDF::Log;

# this function could be called:
# 1. FlowPDF::Error->new('Fatal', 'Runtime', "File $file does not exist");
# 2. FlowPDF::Error->new('Error', "File $file does not exist");
# 3. FlowPDF::Error->new("File $file does not exist");
sub newError {
    my ($class, @params) = @_;

    my ($type, $group, $message);

    if (scalar(@params) == 3) {
        $type = $params[0];
        $group = $params[1];
        $message = $params[2];
    }
    elsif (scalar(@params) == 2) {
        $type = $params[0];
        $group = 'Runtime';
        $message = $params[0];
    }
    elsif (scalar(@params) == 1) {
        $type = 'Error';
        $group = 'Runtime';
        $message = $params[0];
    }

    if (!$message) {
        croak "Missing error message.";
    }
    if ($message && $message !~ m/\n$/s) {
        $message .= "\n";
    }

    if ($type !~ m/(:?Fatal|Error|Warning)/s) {
        croak "Wrong error type. Expected one of: Fatal, Error, Warning, got: $type";
    }

    return $class->new({
        errorType    => $type,
        errorGroup   => $group,
        errorMessage => $message
    });
};


sub bailOut {
    my ($error) = @_;

    my $msg = $error->buildErrorMessage();
    logInfo($msg);
    exit 1;
}


sub throw {
    my ($error) = @_;

    my $msg = $error->buildErrorMessage();
    croak $msg;
}

sub buildErrorMessage {
    my ($error) = @_;

    my $message = $error->getErrorMessage();
    my $type = $error->getErrorType();
    my $group = $error->getErrorGroup();
    my $code = $error->getErrorCode();

    my $retval = "";
    if ($code) {
        $retval = "[$code: $type : $group]: $message";
    }
    else {
        $retval = "[$type : $group]: $message";
    }

    return $retval;
}
