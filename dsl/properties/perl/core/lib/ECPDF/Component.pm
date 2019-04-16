=head1 NAME

ECPDF::Component

=head1 AUTHOR

Electric Cloud

=head1 DESCRIPTION

This module provides a base class for ECPDF Components.

Each ECPDF Component is a perl module which should have init($initParams) method and be a subclass of ECPDF::Component.

=head1 USAGE

To create a component one should define a class that inherits this class and define an init($class, $params) method to make it working.
Also, components should be loading using L<ECPDF::ComponentManager>, please, avoid direct usage of components modules.

Direct usage of components will be prohibited in the next release.

Example of a simple component:

%%%LANG=perl%%%

    package ECPDF::Component::MyComponent
    use base qw/ECPDF::Component/;
    use strict;
    use warnings;

    sub init {
        my ($class, $initParams) = @_;
            my ($initParams) = @_;
            my $retval = {%$initParams};
            bless $retval, $class;
            return $retval;
    }

    sub action {
        my ($self) = @_;
        print "Doing Action!";
    }

%%%LANG%%%

Then, to load this component using L<ECPDF::ComponentManager> one should use its loadComponent method.

Please, note, that loadComponent loads component globally, that is, you don't need to do loadComponent with parameters again and again.

You need to call getComponent('ECPDF::Component::YourComponent') of L<ECPDF::ComponentManager>.

Please, note, that in that case getComponent() will return exactly the same object that was created during component loading.

To get more details about component loading see L<ECPDF::ComponentManager>

Example:

%%%LANG=perl%%%

    my $component = ECPDF::ComponentManager->loadComponent('ECPDF::Component::MyComponent', $initParams);
    # then you can use your component across your code.
    # to do that, you need to get this component from anywere in current runtime.
    ...;
    sub mySub {
        # the same component object.
        my $component = ECPDF::ComponentManager->getComponent('ECPDF::Component::MyComponent');
    }

%%%LANG%%%

=head1 AVAILABLE COMPONENTS

Currently there are 3 components that are going with L<ECPDF>:

=over 4

=item L<ECPDF::Component::Proxy>

=item L<ECPDF::Component::CLI>

=item L<ECPDF::Component::OAuth>

=back

=cut

package ECPDF::Component;
use base qw/ECPDF::BaseClass/;
use strict;
use warnings;

sub classDefinition {
    return {
        componentInitParams => '*'
    };
}


1;
