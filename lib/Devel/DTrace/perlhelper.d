/*
 * In this first clause we initialize all variables.  We must explicitly clear
 * them because they may contain values left over from previous iterations.
 */
dtrace:helper:ustack:
{
	/* input */
	this->fp = arg1;

	/* output/flow control */
	this->buf = (char *)alloca(128);
	this->off = 0;
	this->done = 0;

	/* program state */
	this->ctx = 0;
	this->marker = 0;
	this->func = 0;	
	this->shared = 0;
	this->map = 0;
	this->attrs = 0;
	this->funcnamestr = 0;
	this->funcnamelen = 0;
	this->funcnameattrs = 0;
	this->script = 0;
	this->scriptnamestr = 0;
	this->scriptnamelen = 0;
	this->scriptnameattrs = 0;
	this->position = 0;	
	this->line_ends = 0;	
	this->le_attrs = 0;

	/* binary search fields */
	this->bsearch_min = 0;
	this->bsearch_max = 0;
	this->ii = 0;
}
