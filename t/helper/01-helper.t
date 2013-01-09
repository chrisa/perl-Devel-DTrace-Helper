use Test::More qw/ no_plan /;
use_ok('Devel::DTrace::Helper');
diag("$$");

sub d {
    -f '/';
    sleep 1;
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
