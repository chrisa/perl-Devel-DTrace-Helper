#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#define _FILE_OFFSET_BITS 32
#include <dtrace.h>

/* -------------------------------------------------------------------- */
/* DOF loading */

static const char *helper = "/dev/dtrace/helper";

static int
load_dof_helper(int fd, dof_helper_t *dh)
{
        return ioctl(fd, DTRACEHIOC_ADDDOF, dh);
}

static int
load_dof(dof_hdr_t *dof)
{
        dof_helper_t dh;
        int fd;
        int gen;

        dh.dofhp_dof  = (uintptr_t)dof;
        dh.dofhp_addr = (uintptr_t)dof;
        (void) strncpy(dh.dofhp_mod, "perl", sizeof (dh.dofhp_mod));

        if ((fd = open(helper, O_RDWR)) < 0)
                return (-1);

        gen = load_dof_helper(fd, &dh);

        if ((close(fd)) < 0)
                return (-1);

        if (gen < 0)
                return (-1);

        return (0);
}

/* -------------------------------------------------------------------- */
/* runops hooking */

STATIC OP *
dtrace_call_op(pTHX_ PERL_CONTEXT *stack)
{
        return CALL_FPTR(PL_op->op_ppaddr)(aTHX);
}

STATIC int
dtrace_runops(pTHX)
{
        while ( PL_op ) {
                if ( PL_op = dtrace_call_op(aTHX_ cxstack), PL_op ) {
                        PERL_ASYNC_CHECK(  );
                }
        }

        TAINT_NOT;
        return 0;
}

STATIC void
runops_hook(void)
{
        runops_proc_t runops = dtrace_runops;

        if ( PL_runops != runops ) {
                PL_runops = runops;
        }
}

/* -------------------------------------------------------------------- */
/* XS */

MODULE = Devel::DTrace::Helper               PACKAGE = Devel::DTrace::Helper

PROTOTYPES: DISABLE

        BOOT:
        runops_hook();

int
init_helper(char *path)

        INIT:
        dtrace_hdl_t *dtp;
        dtrace_prog_t *helper;
        int err;
	FILE *fp;
        void *dof;
        int argc = 8;
        char *argv[8] = { "perl" };

        CODE:
        (void) asprintf(&argv[1], "0x%x", (unsigned int)dtrace_call_op);
        (void) asprintf(&argv[2], "0x%x", (unsigned int)load_dof);
        (void) asprintf(&argv[3], "0x%x", sizeof(struct context));
        (void) asprintf(&argv[4], "0x%x", offsetof(struct context, blk_oldcop));
        (void) asprintf(&argv[5], "0x%x", offsetof(struct cop, cop_line));
        (void) asprintf(&argv[6], "0x%x", offsetof(struct cop, cop_stashpv));
        (void) asprintf(&argv[7], "0x%x", offsetof(struct cop, cop_file));

        if ((fp = fopen(path, "r")) == NULL)
		Perl_croak(aTHX_ "failed to open %s", path);

        dtp = dtrace_open(DTRACE_VERSION, DTRACE_O_NODEV, &err);
        if (dtp == NULL) {
                dtrace_close(dtp);
                Perl_croak(aTHX_ "dtrace_open failed: %s",
                           dtrace_errmsg(dtp, err));
        }

        (void) dtrace_setopt(dtp, "linkmode", "dynamic");
        (void) dtrace_setopt(dtp, "unodefs", NULL);

        if ((helper = dtrace_program_fcompile(dtp, fp,
                                              DTRACE_C_CPP | DTRACE_C_ZDEFS,
                                              argc, argv)) == NULL) {
                dtrace_close(dtp);
                Perl_croak(aTHX_ "compile failed: %s",
                           dtrace_errmsg(dtp, dtrace_errno(dtp)));
        }
	(void) fclose(fp);

        if ((dof = dtrace_dof_create(dtp, helper, 0)) == NULL) {
                dtrace_close(dtp);
                Perl_croak(aTHX_ "DOF create failed: %s",
                           dtrace_errmsg(dtp, dtrace_errno(dtp)));
        }

        if (load_dof(dof) != 0) {
                dtrace_close(dtp);
                Perl_croak(aTHX_ "DOF load failed: %s", strerror(errno));
        }

        dtrace_close(dtp);
        RETVAL = 1;

        OUTPUT:
        RETVAL
