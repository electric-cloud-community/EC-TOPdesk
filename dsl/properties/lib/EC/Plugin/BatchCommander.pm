package EC::Plugin::BatchCommander;

use strict;
use warnings;

use base qw(EC::Plugin::BatchCommanderCore);


=head1 SYNOPSYS

User-defined Batch functionality

Available batch-level functionality types:

    before
    iterator
    after

    sub define_batch_hooks {
        my ($self) = @_;

        $self->define_hook('my step', 'before', sub { ( my ($self) = @_; print "I'm before step my step" }, {run_before_shared => 1});
    }


    "before" and "after" are normal hooks that are run before and after all operations.
    
    "iterator" is a special way to manipulate amount of requests that are needed to be done.
    If iterator is not defined via "define_batch_hooks" function, then only one request will be done defined by config file and normal hooks(Hooks.pm / define_hooks sub) assigned for this step.
    Initial step parameters are avaiblable via $self->{main_parameters}.
    Iterator index is always available via $self->{'iter_num'}.

    step name - the name of the step. If value "*" is specified, the hook will be "shared" - it will be executed for every step
    hook name - the name of the hook, see Available hook types
    hook code - CODEREF with the hook code
    options - hook options
        run_before_shared - this hook ("own" step hook) will be executed before shared hook (the one marked with "*")




=head1 SAMPLE


    sub define_iterators {
        my ($self) = @_;

        $self->define_hook('my step name', \&process_files_list);
    }

    sub process_files_list{
        my ($self, $parameters) = @_;
        my $iter = $self->{'iter_num'};
        my @file_ids = split /,/, $self->{main_parameters}->{files};
        $parameters->{file} = $file_ids[int($iter)];
        if ($#file_ids <= $iter){
            return undef;
        }
        else{
            return 1;
        }
    }



=cut

# autogen end

sub define_batch_hooks {
    my ($self) = @_;
}

sub define_iterators {
    my ($self) = @_;
}



1;
