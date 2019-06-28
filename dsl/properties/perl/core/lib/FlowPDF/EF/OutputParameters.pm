package FlowPDF::EF::OutputParameters;
use base qw/FlowPDF::BaseClass2/;
use FlowPDF::Types;
__PACKAGE__->defineClass({
    ec => FlowPDF::Types::Reference('ElectricCommander')
});

use strict;
use warnings;
use FlowPDF::Log;
use JSON;
use ElectricCommander;
use Data::Dumper;


sub setOutputParameter {
    my ($self, $name, $value, $attach_params) = @_;

    if (!defined $value){
        logDebug("Will not save undefined value for outputParameter '$name'");
        return;
    };

    # Will fall if parameter does not exists
    eval {
        if ($value && (ref $value eq 'HASH' || ref $value eq 'ARRAY')){
            require JSON unless $JSON::VERSION;
            $value = JSON::encode_json($value);
        }

        my $is_set = $self->getEc->setOutputParameter($name, $value, $attach_params);

        # 0E0 can be returned by EC::Bootstrap function and means parameter was not really set
        if ($is_set && $is_set ne '0E0'){
            logDebug("Output parameter '$name' has been set to '$value'" . (defined $attach_params ? " and attached to " . Dumper($attach_params) : ''));
        }
        elsif (!$is_set){
            logWarning("Cannot set output parameter '$name' to '$value'" . (defined $attach_params ? " with the following attached params: " . Dumper($attach_params) : ''));
        }
        elsif ($is_set eq '0E0') {
            logWarning("Cannot set output parameter '$name'. This agent version don't supports this API");
        }

        1;
    } or do {
        logDebug("Output parameter '$name' can't be saved : $@");
        return 0;
    };

    return 1;
}


1;
