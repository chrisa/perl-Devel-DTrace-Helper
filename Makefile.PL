use ExtUtils::MakeMaker;

WriteMakefile(
    NAME          => 'Devel::DTrace::Helper',
    VERSION_FROM  => 'lib/Devel/DTrace/Helper.pm',
    ABSTRACT_FROM => 'lib/Devel/DTrace/Helper.pm',
    AUTHOR        => 'Chris Andrews <chris@nodnol.org>',
    OBJECT        => '$(O_FILES)',
    LIBS          => '-ldtrace',
    PREREQ_PM     => { }
);
