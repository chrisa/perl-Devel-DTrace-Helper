#define APPEND_CHR(c) (this->buf[this->off++] = (c))

#define APPEND_DGT(i, d)        \
        (((i) / (d)) ? APPEND_CHR('0' + ((i)/(d) % 10)) : 0)

#define APPEND_NUM(i)           \
        APPEND_DGT((i), 1000000000000);  \
        APPEND_DGT((i), 100000000000);   \
        APPEND_DGT((i), 10000000000);    \
        APPEND_DGT((i), 1000000000);     \
        APPEND_DGT((i), 100000000);      \
        APPEND_DGT((i), 10000000);       \
        APPEND_DGT((i), 1000000);        \
        APPEND_DGT((i), 100000);         \
        APPEND_DGT((i), 10000);          \
        APPEND_DGT((i), 1000);           \
        APPEND_DGT((i), 100);            \
        APPEND_DGT((i), 10);             \
        APPEND_DGT((i), 1);

#define APPEND_CHR_IF(offset, str) \
dtrace:helper:ustack:                                                      \
/this->go == 2 && !this->strdone/                                          \
{                                                                          \
    copyinto((uintptr_t)((char *)str + offset), 1, this->buf + this->off); \
    this->off++;                                                           \
}                                                                          \
dtrace:helper:ustack:                                                      \
/this->go == 2 && !this->strdone && this->buf[this->off - 1] == '\0'/      \
{                                                                          \
    this->strdone = 1;                                                     \
    this->off--;                                                           \
}

#define APPEND_CSTR(str) \
dtrace:helper:ustack:    \
/this->go == 2/          \
{                        \
    this->strdone = 0;   \
}                        \
APPEND_CHR_IF(0, str) \
APPEND_CHR_IF(1, str) \
APPEND_CHR_IF(2, str) \
APPEND_CHR_IF(3, str) \
APPEND_CHR_IF(4, str) \
APPEND_CHR_IF(5, str) \
APPEND_CHR_IF(6, str) \
APPEND_CHR_IF(7, str) \
APPEND_CHR_IF(8, str) \
APPEND_CHR_IF(9, str) \
APPEND_CHR_IF(10, str) \
APPEND_CHR_IF(11, str) \
APPEND_CHR_IF(12, str) \
APPEND_CHR_IF(13, str) \
APPEND_CHR_IF(14, str) \
APPEND_CHR_IF(15, str) \
APPEND_CHR_IF(16, str) \
APPEND_CHR_IF(17, str) \
APPEND_CHR_IF(18, str) \
APPEND_CHR_IF(19, str) \
APPEND_CHR_IF(20, str) \
APPEND_CHR_IF(21, str) \
APPEND_CHR_IF(22, str) \
APPEND_CHR_IF(23, str) \
APPEND_CHR_IF(24, str) \
APPEND_CHR_IF(25, str) \
APPEND_CHR_IF(26, str) \
APPEND_CHR_IF(27, str) \
APPEND_CHR_IF(28, str) \
APPEND_CHR_IF(29, str) \
APPEND_CHR_IF(30, str) \
APPEND_CHR_IF(31, str) \
APPEND_CHR_IF(32, str) \
APPEND_CHR_IF(33, str) \
APPEND_CHR_IF(34, str) \
APPEND_CHR_IF(35, str) \
APPEND_CHR_IF(36, str) \
APPEND_CHR_IF(37, str) \
APPEND_CHR_IF(38, str) \
APPEND_CHR_IF(39, str) \
APPEND_CHR_IF(40, str) \
APPEND_CHR_IF(41, str) \
APPEND_CHR_IF(42, str) \
APPEND_CHR_IF(43, str) \
APPEND_CHR_IF(44, str) \
APPEND_CHR_IF(45, str) \
APPEND_CHR_IF(46, str) \
APPEND_CHR_IF(47, str) \
APPEND_CHR_IF(48, str) \
APPEND_CHR_IF(49, str) \
APPEND_CHR_IF(50, str) \
APPEND_CHR_IF(51, str) \
APPEND_CHR_IF(52, str) \
APPEND_CHR_IF(53, str) \
APPEND_CHR_IF(54, str) \
APPEND_CHR_IF(55, str) \
APPEND_CHR_IF(56, str) \
APPEND_CHR_IF(57, str) \
APPEND_CHR_IF(58, str) \
APPEND_CHR_IF(59, str)


#define APPEND_STR(str, len) \
    copyinto(str, len, this->buf + this->off); \
    this->off += len;

/* --------------------------------------------------------------- */

dtrace:helper:ustack:
{
        this->buf = (char *)alloca(512);
        this->off = 0;

        this->start = $1;
        this->end = $2;
        this->pc = (uintptr_t)arg0;
        this->go = 0;

        this->cop = 0;
        this->cxp = 0;
        this->stack = 0;

        this->strdone = 0;

        this->cxsize = $3;

        APPEND_CHR('@');
        APPEND_CHR('P');
        APPEND_CHR('e');
        APPEND_CHR('r');
        APPEND_CHR('l');
        APPEND_CHR(' ');
        APPEND_CHR('s');
        APPEND_CHR('t');
        APPEND_CHR('a');
        APPEND_CHR('c');
        APPEND_CHR('k');
        APPEND_CHR(':');
        APPEND_CHR('\n');
}

dtrace:helper:ustack:
/this->pc >= this->start/
{
        this->go++;
}

dtrace:helper:ustack:
/this->pc < this->end/
{
        this->go++;
}

#define frame_ptr_addr ((uintptr_t)arg1 + sizeof(uintptr_t) * 3)

dtrace:helper:ustack:
/this->go == 2/
{
        this->stack = *(uintptr_t *)copyin(frame_ptr_addr, sizeof(uintptr_t));
}

#define BLOCK_OLDCOP_OFFSET $4
#define COP_LINE_OFFSET $5
#define COP_STASHPV_OFFSET $6
#define COP_FILE_OFFSET $7

#define CXTYPE(cx) ((uint8_t)(copyin(cx, sizeof(uint8_t))) & 0xf)
#define COP(cx) *(uintptr_t *)copyin(cx + BLOCK_OLDCOP_OFFSET, sizeof(uintptr_t))

#define COPLINE(cop) *(uint32_t *)copyin((cop + COP_LINE_OFFSET), sizeof(uint32_t))
#define COPSTASHPV(cop) *(uintptr_t *)copyin(cop + COP_STASHPV_OFFSET, sizeof(uintptr_t))
#define COPFILE(cop) *(uintptr_t *)copyin(cop + COP_FILE_OFFSET, sizeof(uintptr_t))

#define STACKWALK(frame) \
dtrace:helper:ustack:                                               \
/this->go == 2/                                                     \
{                                                                   \
        this->cxp = this->stack + (this->cxsize * frame);           \
        this->cxtype = CXTYPE(this->cxp);                           \
}                                                                   \
dtrace:helper:ustack:                                               \
/this->go == 2/                                                     \
{                                                                   \
        this->cop = COP(this->cxp);                                 \
        APPEND_CHR(' ');                                            \
        APPEND_CHR(' ');                                            \
        APPEND_CHR(' ');                                            \
        APPEND_CHR(' ');                                            \
        APPEND_CHR(' ');                                            \
        APPEND_CHR(' ');                                            \
        APPEND_CHR(' ');                                            \
        APPEND_CHR(' ');                                            \
        APPEND_CHR(' ');                                            \
        APPEND_CHR(' ');                                            \
        APPEND_CHR(' ');                                            \
        APPEND_CHR(' ');                                            \
        APPEND_CHR(' ');                                            \
        APPEND_CHR(' ');                                            \
        APPEND_CHR(' ');                                            \
        APPEND_CHR(' ');                                            \
        APPEND_CHR(' ');                                            \
        APPEND_CHR(' ');                                            \
}                                                                   \
APPEND_CSTR(COPFILE(this->cop))                                     \
dtrace:helper:ustack:                                               \
/this->go == 2/                                                     \
{                                                                   \
        APPEND_CHR(':');                                            \
        APPEND_NUM(COPLINE(this->cop));                             \
        APPEND_CHR('\n');                                           \
}

STACKWALK(0)
STACKWALK(1)
STACKWALK(2)
STACKWALK(3)
STACKWALK(4)
STACKWALK(5)
STACKWALK(6)
STACKWALK(7)

dtrace:helper:ustack:
/this->go == 2/
{
        APPEND_CHR(' ');
        APPEND_CHR(' ');
        APPEND_CHR(' ');
        APPEND_CHR(' ');
        APPEND_CHR(' ');
        APPEND_CHR(' ');
        APPEND_CHR(' ');
        APPEND_CHR(' ');
        APPEND_CHR(' ');
        APPEND_CHR(' ');
        APPEND_CHR(' ');
        APPEND_CHR(' ');
        APPEND_CHR(' ');
        APPEND_CHR(' ');
        APPEND_CHR(' ');
	APPEND_CHR('\0');
        stringof(this->buf);
}
