package FlowPDF::Component::EF;
use base qw/FlowPDF::Component/;
use FlowPDF::Types;

__PACKAGE__->defineClass({
    pluginObject => FlowPDF::Types::Any(),
});

use strict;
use warnings;

sub isEFComponent {
    return 1;
}

1;

