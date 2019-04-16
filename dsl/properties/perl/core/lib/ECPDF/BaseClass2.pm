package ECPDF::BaseClass2;
use strict;
use warnings;
use Data::Dumper;
use Carp;
sub defineClass {
    my ($class, $definitions) = @_;

    my $constructorCode = sprintf q|
        *{%s::new} = sub {
            my ($class, $opts) = @_;
            for my $k (keys %%{$opts}) {
                if (!$definitions->{$k}) {
                    croak "Unknown field $k\n";
                }
            }
            bless $opts, $class;
            return $opts;
        };
    |, $class;
    eval $constructorCode or do {
        croak "Error during constructor code creation: $!\n";
    };
    # print "Constructor code: $constructorCode\n";
    for my $k (keys %$definitions) {
        my $field = ucfirst $k;
        my $getter = "get$field";
        my $setter = "set$field";
        my $code = sprintf q|
        *{%s::%s} = sub {
            my ($self) = @_;
            return __get($self, $k);
        };
        *{%s::%s} = sub {
            my ($self, $value) = @_;
            return __set($self, $k, $value);
        };
|, $class, $getter, $class, $setter;
        # print "Code: $code\n";
        eval $code or do {
            croak "Error during method creation: $!\n";
        };
    }
    return 1;
}


sub __get {
    my ($self, $field) = @_;
    if (defined $self->{$field}) {
        return $self->{$field};
    }
    return undef;
}

sub __set {
    my ($self, $field, $value) = @_;
    $self->{$field} = $value;
    return $self;
}
1;
