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

#define at_runops_frame(addr) \
        ((uintptr_t)addr >= $1) && ((uintptr_t)addr < $1)

dtrace:helper:ustack:
{
        this->go = 0;
}

dtrace:helper:ustack:
/(uintptr_t)arg0 >= $1 && (uintptr_t)arg0 < ($1 + 0x80)/
{
        this->go = 1;
}

dtrace:helper:ustack:
/this->go == 1/
{
        /* output/flow control */
        this->buf = (char *)alloca(128);
        this->off = 0;

        APPEND_CHR('@');

        APPEND_CHR('p');
        APPEND_CHR('c');
        APPEND_CHR(':');
        APPEND_CHR(' ');
        APPEND_NUM((uintptr_t)arg0);
        APPEND_CHR(' ');
        APPEND_CHR('f');
        APPEND_CHR('p');
        APPEND_CHR(':');
        APPEND_CHR(' ');
        APPEND_NUM((uintptr_t)arg1);

        APPEND_CHR('\0');
        stringof(this->buf);
}
