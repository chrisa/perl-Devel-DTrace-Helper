use Test::More qw/ no_plan /;
use Devel::DTrace::Helper;
use Carp qw/ cluck /;

diag("$$");

sub d {
    sleep 1;
    print STDERR "foo\n";
}

sub c {
    d();
}

sub b {
    c();
}

sub a {
    b();
}

for my $i (0..100) {
    a();
}
