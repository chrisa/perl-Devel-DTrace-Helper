#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#define _FILE_OFFSET_BITS 32
#include <dtrace.h>

/* -------------------------------------------------------------------- */
/* DOF loading */

#ifdef __APPLE__
static const char *helper = "/dev/dtracehelper";

static int
load_dof_helper(int fd, dof_helper_t *dh)
{
        int ret;
        uint8_t buffer[sizeof(dof_ioctl_data_t) + sizeof(dof_helper_t)];
        dof_ioctl_data_t* ioctlData = (dof_ioctl_data_t*)buffer;
        user_addr_t val;

        ioctlData->dofiod_count = 1;
        memcpy(&ioctlData->dofiod_helpers[0], dh, sizeof(dof_helper_t));

        val = (user_addr_t)(unsigned long)ioctlData;
        ret = ioctl(fd, DTRACEHIOC_ADDDOF, &val);

        if (ret < 0)
                return ret;

        return (int)(ioctlData->dofiod_helpers[0].dofhp_dof);
}

#else /* Solaris */

/* ignore Sol10 GA ... */
static const char *helper = "/dev/dtrace/helper";

static int
load_dof_helper(int fd, dof_helper_t *dh)
{
        return ioctl(fd, DTRACEHIOC_ADDDOF, dh);
}

#endif

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
dtrace_call_op(char *stack)
{
        return CALL_FPTR(PL_op->op_ppaddr)(aTHX);
}

STATIC I32
dopoptosub_at(pTHX_ const PERL_CONTEXT *cxstk, I32 startingblock)
{
    dVAR;
    I32 i;

    for (i = startingblock; i >= 0; i--) {
	register const PERL_CONTEXT * const cx = &cxstk[i];
	switch (CxTYPE(cx)) {
	default:
	    continue;
	case CXt_EVAL:
	case CXt_SUB:
	case CXt_FORMAT:
                return i;
	}
    }
    return i;
}

STATIC char *
append_stack(char *stack, const PERL_CONTEXT *cx)
{
        char *line;

        if (cx != NULL) {

                char * subname = "";
                CV* cv = cx->blk_sub.cv;
                if (cv) {
                        const GV *const gv = CvGV(cv);
                        if (gv > 0x8000000) { /* what? */
                                subname = GvENAME(gv);
                        }
                }
                else {
                        return NULL;
                }

                (void) asprintf(&line, "\n                  %s::%s() called at %s line %d",
                                CopSTASHPV(cx->blk_oldcop),
                                subname,
                                CopFILE(cx->blk_oldcop),
                                CopLINE(cx->blk_oldcop));
        }
        else {
                (void) asprintf(&line, "<< unknown >>");
        }

        if (strlen(stack) + strlen(line) < (PATH_MAX * 2))
              strcat(stack, line);

        return line;
}

STATIC int
dtrace_runops(pTHX)
{
        const OP *last_op = NULL;
        const OP *next_op = NULL;
        const PERL_CONTEXT *cx;
        char stack[PATH_MAX * 2];

        while ( PL_op ) {
                sprintf(stack, "@");

                int i = 0;
                while ((cx = caller_cx(i++, NULL)) != NULL)
                        if (append_stack(stack, cx) == NULL)
                                break;
                strcat(stack, "\n               ");

                /* I32 cxix = dopoptosub_at(aTHX_ cxstack, cxstack_ix); */
                /* const PERL_CONTEXT *cx = NULL; */
                /* const PERL_CONTEXT *ccstack = cxstack; */
                /* const PERL_SI *top_si = PL_curstackinfo; */

                /* while (cxix < 0 && top_si->si_type != PERLSI_MAIN) { */
                /*         top_si = top_si->si_prev; */
                /*         ccstack = top_si->si_cxstack; */
                /*         cxix = dopoptosub_at(aTHX_ ccstack, top_si->si_cxix); */
                /* } */
                /* if (cxix >= 0) */
                /*         cx = &ccstack[cxix]; */

                /* sprintf(stack, "@len: %d", strlen(stack)); */

                if ( PL_op = dtrace_call_op(stack), PL_op ) {
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
        int argc = 2;
        char *argv[2] = { "perl", NULL };

        CODE:
        (void) asprintf(&argv[1], "0x%x", (unsigned int)dtrace_call_op);

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
