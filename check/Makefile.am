NULL = 

bin_PROGRAMS =  \
	bcastlisten \
	testcallbacks \
	$(NULL)

testcallbacks_SOURCES =  \
	testcallbacks.vala \
	$(NULL)

testcallbacks_VALAFLAGS = \
	--pkg tasklet \
	--pkg gee-0.8 \
	--pkg gio-2.0 \
	--pkg linux \
	$(NULL)

testcallbacks_LDADD = \
	-lm \
	$(GOBJECT_LIBS) \
	$(TASKLET_LIBS) \
	$(GEE_LIBS) \
	$(GIO_LIBS)  \
	$(NULL)

bcastlisten_SOURCES =  \
	bcastlisten.vala \
	config.vapi \
	$(NULL)

bcastlisten_VALAFLAGS = \
	--pkg tasklet \
	--pkg gee-0.8 \
	--pkg gio-2.0 \
	--pkg linux \
	$(NULL)

bcastlisten_LDADD = \
	-lm \
	$(GOBJECT_LIBS) \
	$(TASKLET_LIBS) \
	$(GEE_LIBS) \
	$(GIO_LIBS)  \
	$(NULL)

AM_CPPFLAGS = \
	$(GOBJECT_CFLAGS) \
	$(TASKLET_CFLAGS) \
	$(GEE_CFLAGS) \
	$(GIO_CFLAGS)  \
	$(NULL)

