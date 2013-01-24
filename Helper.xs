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
dtrace_call_op(pTHX_ PERL_CONTEXT *stack)
{
        return CALL_FPTR(PL_op->op_ppaddr)(aTHX);
}

STATIC I32
dopoptosub_at(const PERL_CONTEXT *cxstk, I32 startingblock)
{
        dVAR;
        I32 i;

        for (i = startingblock; i >= 0; i--) {
                const PERL_CONTEXT * const cx = &cxstk[i];
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

STATIC void
dtrace_caller_cx(pTHX_ char *stack)
{
        I32 cxix = dopoptosub_at(cxstack, cxstack_ix);
        const PERL_CONTEXT *ccstack = cxstack;
        const PERL_SI *top_si = PL_curstackinfo;

        for (;;) {
                if (cxix < 0)
                        break;
                if (append_stack(stack, &ccstack[cxix]) == NULL)
                        break;
                cxix = dopoptosub_at(ccstack, cxix - 1);
        }
}

STATIC int
dtrace_runops(pTHX)
{
        const OP *last_op = NULL;
        const OP *next_op = NULL;

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
