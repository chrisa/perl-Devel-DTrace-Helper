package Devel::DTrace::Helper;

use 5.008;
use strict;
use warnings;
use File::Spec;

BEGIN {
	our $VERSION = '0.01';
	require XSLoader;
	eval {
            XSLoader::load('Devel::DTrace::Helper', $VERSION);
	};

	my (undef, $path) = File::Spec->splitpath(__FILE__);
	my $helper_path = File::Spec->catfile($path, 'perlhelper.d');
        init_helper($helper_path);
}

1;
