#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#define _FILE_OFFSET_BITS 32
#include <dtrace.h>

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

MODULE = Devel::DTrace::Helper               PACKAGE = Devel::DTrace::Helper

PROTOTYPES: DISABLE

void
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

        (void) asprintf(&argv[1], "0x%x", (unsigned int)Perl_runops_standard);

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

