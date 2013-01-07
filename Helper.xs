#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"
#include <dtrace.h>

MODULE = Devel::DTrace::Helper               PACKAGE = Devel::DTrace::Helper

PROTOTYPES: DISABLE

void
init_helper(char *path)

        INIT:
        dtrace_hdl_t *dtp;
        dtrace_prog_t *helper;
        int err;
	FILE *fp;

        CODE:
        dtp = dtrace_open(DTRACE_VERSION, DTRACE_O_NODEV, &err);
        if (dtp == NULL) {
                dtrace_close(dtp);
                Perl_croak(aTHX_ "dtrace_open failed: %s", dtrace_errmsg(dtp, err));
        }

        (void) dtrace_setopt(dtp, "linkmode", "dynamic");
        (void) dtrace_setopt(dtp, "unodefs", NULL);

        if ((fp = fopen(path, "r")) == NULL) {
                dtrace_close(dtp);
		Perl_croak(aTHX_ "failed to open %s", path);
        }

        if ((helper = dtrace_program_fcompile(dtp, fp,
                                              DTRACE_C_CPP | DTRACE_C_ZDEFS,
                                              0, NULL)) == NULL) {
                dtrace_close(dtp);
                Perl_croak(aTHX_ "compile failed: %s",
                           dtrace_errmsg(dtp, dtrace_errno(dtp)));
        }
	(void) fclose(fp);

        dtrace_close(dtp);

