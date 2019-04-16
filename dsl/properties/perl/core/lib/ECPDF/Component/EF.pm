package ECPDF::Component::EF;
use base qw/ECPDF::BaseClass/;
use strict;
use warnings;

sub classDefinition {
    return {
        %{$_[0]->SUPER::classDefinition()},
        pluginObject => '*',
    };
}

1;

