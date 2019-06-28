=head1 NAME

FlowPDF::Config

=head1 AUTHOR

CloudBees

=head1 DESCRIPTION

This class represents a configuration of ElectricFlow plugin.

You may want to think of plugin configuration as a global variables for the plugin, when Step Parameters are local variables.
They're working in the same way.

Plugin configuration has a regular parameters and procedure step has a regular parameters. Plugin configuration has a credentials,
procedure step has a credentials.

FlowPDF::Config object has the same methods as L<FlowPDF::StepParameters>.

See L<FlowPDF::StepParameters> for a reference for how to handle parameters and credentials.

=cut

package FlowPDF::Config;
use ElectricCommander;

use base qw/FlowPDF::StepParameters/;
use strict;
use warnings;


1;
