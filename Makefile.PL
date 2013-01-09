use ExtUtils::MakeMaker;

# sub MY::postamble {
#     return <<"MAKE_FRAG";
# \$(MYEXTLIB): lib/Devel/DTrace/perlhelper.d
# 	/usr/sbin/dtrace -C -G -s lib/Devel/DTrace/perlhelper.d

# MAKE_FRAG
# }

WriteMakefile(
    NAME          => 'Devel::DTrace::Helper',
    VERSION_FROM  => 'lib/Devel/DTrace/Helper.pm',
    ABSTRACT_FROM => 'lib/Devel/DTrace/Helper.pm',
    AUTHOR        => 'Chris Andrews <chris@nodnol.org>',
    #MYEXTLIB      => 'perlhelper.o',
    OBJECT        => '$(O_FILES)',
    LIBS          => '-ldtrace',
    PREREQ_PM     => { }
);

