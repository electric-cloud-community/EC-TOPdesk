package FlowPDF::Types::Any;
use strict;
use warnings;

sub new {
    my ($class) = @_;
    my $self = {};
    bless $self, $class;
    return $self;
}


sub match {
    return 1;
}


sub describe {
    return "an any type of data";
}

1;
