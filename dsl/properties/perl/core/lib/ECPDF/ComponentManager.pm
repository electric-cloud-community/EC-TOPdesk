=head1 NAME

ECPDF::ComponentManager

=head1 AUTHOR

Electric Cloud

=head1 DESCRIPTION

ECPDF::ComponentManager is a class that provides you an access to ECPDF Components infrastructure.

This class allows you to load components depending on you needs.

Currently, there are 2 components loading strategies supported.

=over 4

=item B<Local>

Local component is being loaded to current ECPDF::ComponentManager object context.

So, it is only possible to access it from current object.

=item B<Global>

This is default strategy, component is being loaded for whole execution context and could be accessed from any ECDPF::ComponentManager object.

=back

=head1 METHODS

=cut

package ECPDF::ComponentManager;
use strict;
use warnings;

use Data::Dumper;
use Carp;

use ECPDF::Log;

our $COMPONENTS = {};

=head2 new()

=head3 Description

This method creates a new ECPDF::ComponentManager object. It doesn't have parameters.

=head3 Parameters

=over 4

=item None

=back

=head3 Returns

=over 4

=item ECPDF::ComponentManager

=back

=head3 Usage

%%%LANG=perl%%%

    my $componentManager = ECPDF::ComponentManager->new();

%%%LANG%%%

=cut

sub new {
    my ($class) = @_;

    my $self = {
        components_local => {},
    };
    bless $self, $class;
    return $self;
}

=head2 loadComponentLocal($componentName, $initParams)

=head3 Description

Loads, initializes the component and returns its as ECPDF::Component:: object in context of current ECPDF::ComponentManager object.

=head3 Parameters

=over 4

=item (Required)(String) A name of the component to be loaded

=item (Required)(HASH ref) An init parameters for the component.

=back

=head3 Returns

=over 4

=item ECPDF::Component:: object

=back

=head3 Usage

%%%LANG=perl%%%

    $componentManager->loadComponentLocal('ECPDF::Component::YourComponent', {one => two});

%%%LANG%%%

Accepts as parameters component name and initialization values. For details about initialization values see L<ECPDF::Component>

=cut

sub loadComponentLocal {
    my ($self, $component, $params) = @_;

    eval "require $component";
    $component->import();

    my $o = $component->init($params);
    $self->{components_local}->{$component} = $o;
    return $o;
}

=head2 loadComponent($componentName, $initParams)

=head3 Description

Loads, initializes the component and returns its as ECPDF::Component:: object in global context.

=head3 Parameters

=over 4

=item (Required)(String) A name of the component to be loaded

=item (Required)(HASH ref) An init parameters for the component.

=back

=head3 Returns

=over 4

=item ECPDF::Component:: object

=back

=head3 Usage

%%%LANG=perl%%%

    $componentManager->loadComponentLocal('ECPDF::Component::YourComponent', {one => two});

%%%LANG%%%

Accepts as parameters component name and initialization values. For details about initialization values see L<ECPDF::Component>

=cut

sub loadComponent {
    my ($self, $component, $params) = @_;

    logTrace("Loading component $component using params" . Dumper $params);
    eval "require $component" or do {
        croak "Can't load component $component: $@";
    };
    logTrace("Importing component $component...");
    $component->import();
    logTrace("Imported Ok");

    logTrace("Initializing $component...");
    my $o = $component->init($params);
    logTrace("Initialized Ok");
    $COMPONENTS->{$component} = $o;
    return $o;
}


=head2 getComponent($componentName)

=head3 Description

Returns an ECPDF::Component object that was previously loaded globally. For local context see getComponentLocal.

=head3 Parameters

=over 4

=item (Required)(String) Component to get from global context.

=back

=head3 Returns

=over 4

=item ECPDF::Component:: object

=back

=head3 Usage

%%%LANG=perl%%%

    my $component = $componentManager->getComponent('ECPDF::Component::Proxy');

%%%LANG%%%

=cut

sub getComponent {
    my ($self, $component) = @_;

    if (!$COMPONENTS->{$component}) {
        croak "Component $component has not been loaded as local component. Please, load it before you can use it.";
    }
    return $COMPONENTS->{$component};
}

=head2 getComponentLocal($componentName)

=head3 Description

Returns an ECPDF::Component object that was previously loaded in local context.

=head3 Parameters

=over 4

=item (Required)(String) Component to get from local context.

=back

=head3 Returns

=over 4

=item ECPDF::Component:: object

=back

=head3 Usage

%%%LANG=perl%%%

    my $component = $componentManager->getComponent('ECPDF::Component::Proxy');

%%%LANG%%%

=cut

sub getComponentLocal {
    my ($self, $component) = @_;

    if (!$self->{components_local}->{$component}) {
        croak "Component $component has not been loaded. Please, load it before you can use it.";
    }
    return $self->{components_local}->{$component};
}

1;
