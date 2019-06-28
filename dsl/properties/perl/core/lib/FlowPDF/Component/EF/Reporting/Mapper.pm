package FlowPDF::Component::EF::Reporting::Mapper;

use strict;
use warnings;
use Carp;
use Data::Dumper;


sub new {
    my ($class, $params) = @_;

    my $self = {};
    bless $self, $class;
    if ($params->{transform}) {
        $self->{_transform} = $params->{transform};
        my $error = $self->_load_transform();
        if ($error) {
            croak "Can't load transform script:\n$error";
        }
    }
    if ($params->{mappings}) {
        $self->{_mappings} = $params->{mappings};
    }

    return $self;
}


sub _load_transform {
    my ($self) = @_;
    no warnings 'redefine';
    $self->{_transform} = "package EC::Mapper::Transformer;\n" .
        q|sub transform {my ($payload) = @_; return $payload}| . "\n" .
        q|no warnings 'redefine';| .
        $self->{_transform} .
        "1;\n";


    eval $self->{_transform};
    if ($@) {
        return $@;
    }
    my $transformer = {};
    $self->{transformer} = bless $transformer, "EC::Mapper::Transformer";
    return '';
}

sub transform {
    my ($self, $payload) = @_;

    return $self->{transformer}->transform($payload);
}
sub parse_mapping {
    my ($self, $struct) = @_;

    # remove last comma to make it working.
    $struct =~ s/,\s*$//s;
    my $map = $self->{_mappings};
    return {} unless $map;
    my $retval;

    # remove comments
    $map =~ s/^\s*#.*?$//gms;
    my @map = map {s/\s+$//gs;s/^\s+//gs;$_} split ',', $map;

    # remove empty records
    @map = grep {$_} @map;

    for my $m (@map) {
        my ($request, $response) = split ':', $m;

        # trim records to allow records with spaces around colon (one : two)
        $request =~ s/^\s+//gs;
        $request =~ s/\s+$//gs;
        $response =~ s/^\s+//gs;
        $response =~ s/\s+$//gs;

        my @response = split '\.', $response;

        if ($request =~ m/"(.*?)"/) {
            if (scalar @response > 1) {
                $retval->{$response[0]}->{$response[1]} = $1;
            }
            else {
                $retval->{$response} = $1;
            }
            next;
        }
        my $accessor = [];
        my @path = split '\.', $request;
        for my $p (@path) {
            if ($p !~ m/\[/s) {
                push @$accessor, {'HASH', $p};
            }
            else {
                $p =~ m/(.*?)\[(.*?)\]/s;
                push @$accessor, {'HASH', $1};
                push @$accessor, {'ARRAY', $2};
            }
        }
        my $value = '';

        my $t = $struct;
        for my $acc (@$accessor) {
            if (!$t) {
                $t = undef;
                last;
            }
            if ($acc->{HASH}) {
                $t = $t->{$acc->{HASH}};
            }
            else {
                $t = $t->[$acc->{ARRAY}];
            }
        }
        if (defined $t) {
            if (scalar @response > 1) {
                $retval->{$response[0]}->{$response[1]} = $t;
            }
            else {
                $retval->{$response} = $t;
            }
        }
    }
    return $retval;
}

1;

