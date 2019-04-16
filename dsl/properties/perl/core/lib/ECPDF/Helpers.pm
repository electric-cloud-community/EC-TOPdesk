package ECPDF::Helpers;
use base qw/Exporter/;

use strict;
use warnings;

our @EXPORT_OK = qw/
    trim
    isWin
    genRandomNumbers
    bailOut
/;


sub trim {
    my (@params) = @_;

    @params = map {
        s/^\s+//gs;
        s/\s+$//gs;
        $_;
    } @params;

    return @params;
}

sub isWin {
    if ($^O eq 'MSWin32') {
        return 1;
    }
    return 0;
}

sub genRandomNumbers {
    my ($mod) = @_;

    my $rand = rand($mod);
    $rand =~ s/\.//s;
    return $rand;
}

sub bailOut {
    my (@messages) = @_;

    my $message = join '', @messages;
    if ($message !~ m/\n$/) {
        $message .= "\n";
    }
    $message = "[BAILED OUT]: $message";
    print $message;
    exit 1;
}
1;
