NULL = 

bin_PROGRAMS =  \
	bcastlisten

bcastlisten_SOURCES =  \
	bcastlisten.vala \
	config.vapi \
	$(NULL)

bcastlisten_VALAFLAGS = \
	--pkg tasklet --pkg logger \
	--pkg gee-1.0 --pkg gio-2.0 \
	--pkg linux \
	$(NULL)

bcastlisten_LDADD = -lm $(GOBJECT_LIBS) \
	$(TASKLET_LIBS) \
	$(LOGGER_LIBS) \
	$(GEE_LIBS) \
	$(GIO_LIBS)  \
	$(NULL)

AM_CPPFLAGS = $(GOBJECT_CFLAGS) \
	$(TASKLET_CFLAGS) \
	$(LOGGER_CFLAGS) \
	$(GEE_CFLAGS) \
	$(GIO_CFLAGS)  \
	$(NULL)

