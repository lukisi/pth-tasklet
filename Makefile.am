NULL = 
ACLOCAL_AMFLAGS = -I m4

lib_LTLIBRARIES = \
	libpth-tasklet.la \
	$(NULL)

libpth_tasklet_la_SOURCES = \
	libwrappth.vala \
	tasklet.vala \
	tasklet_system_tasklet.vala \
	tasklet_blocking_sockets.vala \
	time.vala \
	microfunc.vala \
	channel.vala \
	posix_extras.vapi \
	libpth.vapi \
	config.vapi \
	$(NULL)

libpth_tasklet_la_VALAFLAGS = \
	-H pth-tasklet.h \
	--library pth-tasklet \
	--vapidir $(GIO_PREFIX)/share/vala-0.36/vapi \
	--vapidir $(GEE_PREFIX)/share/vala/vapi \
	--vapidir $(TASKLETSYSTEM_VAPIDIR) \
	--pkg gee-0.8 \
	--pkg gio-2.0 \
	--pkg tasklet-system \
	--pkg posix \
	--pkg linux \
	$(NULL)

libpth_tasklet_la_CPPFLAGS = \
	-w \
	$(GOBJECT_CFLAGS) \
	$(PTH_CFLAGS) \
	$(GEE_CFLAGS) \
	$(GIO_CFLAGS) \
	$(TASKLETSYSTEM_CFLAGS) \
	$(NULL)

libpth_tasklet_la_LIBADD = \
	$(PTH_LIBS) \
	$(GIO_LIBS) \
	$(GEE_LIBS) \
	$(GOBJECT_LIBS) \
	$(TASKLETSYSTEM_LIBS) \
	$(NULL)

TESTS = \
	test_commands \
	$(NULL)

check_PROGRAMS = \
	test_commands \
	$(NULL)

test_commands_SOURCES = \
	testsuites/test_commands/test_commands.vala \
	posix_extras.vapi \
	libpth.vapi \
	pth-tasklet.vapi \
	$(NULL)

test_commands_VALAFLAGS = \
	--main=PthTasklet.Test.CommandsTester.main \
	--vapidir $(GIO_PREFIX)/share/vala-0.36/vapi \
	--vapidir $(GEE_PREFIX)/share/vala/vapi \
	--vapidir $(TASKLETSYSTEM_VAPIDIR) \
	--pkg glib-2.0 \
	--pkg gio-2.0 \
	--pkg gee-0.8 \
	--pkg posix \
	--pkg tasklet-system \
	$(NULL)

test_commands_CPPFLAGS = \
	$(GOBJECT_CFLAGS) \
	$(GIO_CFLAGS) \
	$(GEE_CFLAGS) \
	$(TASKLETSYSTEM_CFLAGS) \
	-I$(srcdir) \
	$(NULL)

test_commands_LDADD = \
	$(GOBJECT_LIBS) \
	$(GIO_LIBS) \
	$(GEE_LIBS) \
	$(TASKLETSYSTEM_LIBS) \
	$(builddir)/libpth-tasklet.la \
	$(NULL)

vapidir = $(datadir)/vala/vapi
dist_vapi_DATA = \
	pth-tasklet.vapi \
	pth-tasklet.deps \
	$(NULL)
include_HEADERS = pth-tasklet.h
pkgconfigdir = $(libdir)/pkgconfig
pkgconfig_DATA = pth-tasklet.pc

EXTRA_DIST = \
	pth-tasklet.pc.in \
	pth_addendum.h \
	$(NULL)

MAINTAINERCLEANFILES = \
	$(srcdir)/pth-tasklet.vapi \
	$(NULL)

pth-tasklet.vapi: libpth_tasklet_la_vala.stamp

