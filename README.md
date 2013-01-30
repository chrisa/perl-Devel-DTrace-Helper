Devel::DTrace::Helper
=====================

This is an experiment to see whether it might be possible to build a
ustack helper for Perl.

Following the intended approach it's definitely not possible, so this
code explores some alternatives. 

Here's an example of the output:

  0     20                      write:entry 
              libc.so.1`__write+0x15
              libperl.so`PerlIOUnix_write+0x46
              libperl.so`Perl_PerlIO_write+0x47
              libperl.so`PerlIOBuf_flush+0x50
              libperl.so`Perl_PerlIO_flush+0x45
              libperl.so`PerlIOBuf_write+0x11d
              libperl.so`Perl_PerlIO_write+0x47
              libperl.so`Perl_do_print+0xa7
              libperl.so`Perl_pp_print+0x195
              Helper.so`dtrace_call_op+0x3f
                [ 
                  t/helper/01-helper.t:
                  t/helper/01-helper.t:24
                  t/helper/01-helper.t:25
                  t/helper/01-helper.t:21
                  t/helper/01-helper.t:17
                  t/helper/01-helper.t:13
                ]
              Helper.so`dtrace_runops+0x56
              libperl.so`perl_run+0x380
              perl`main+0x15b
              perl`_start+0x83


Status
------

For anything but the most trivial examples, this code won't provide
useful Perl stacktraces.

It's only known to work on Perl 5.14.2, with threads, on a Solaris or
Illumos-derived system. Specifically, ustack helpers don't work on
OS X.

It doesn't need a recompiled Perl though: the XS part of this module
dynamically loads the helper code.

Source
------

Please see:

  https://github.com/chrisa/perl-Devel-DTrace-Helper

Copyright (C) 2013, Chris Andrews <chris@nodnol.org>

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.
