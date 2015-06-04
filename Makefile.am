NULL = 
ACLOCAL_AMFLAGS = -I m4

lib_LTLIBRARIES = \
	libtasklet.la \
	$(NULL)

libtasklet_la_SOURCES = \
	use_with_libpth_vapi.vala \
	libwrappth.vala \
	tasklet.vala \
	tasklet_blocking_sockets.vala \
	time.vala \
	microfunc.vala \
	channel.vala \
	config.vapi \
	$(NULL)

libtasklet_la_VALAFLAGS = \
	-H tasklet.h \
	--library tasklet \
	$(LOGTASKLET_FLAG) \
	--pkg gee-0.8 \
	--pkg gio-2.0 \
	--pkg posix \
	--pkg linux \
	--pkg posix_extras \
	--pkg libpth \
	--vapidir . \
	$(NULL)

libtasklet_la_CPPFLAGS = \
	-w \
	$(GOBJECT_CFLAGS) \
	$(PTH_CFLAGS) \
	$(GEE_CFLAGS) \
	$(GIO_CFLAGS) \
	$(NULL)

libtasklet_la_LIBADD = \
	$(PTH_LIBS) \
	$(GIO_LIBS) \
	$(GEE_LIBS) \
	$(GOBJECT_LIBS) \
	$(NULL)

TESTS = \
	testname \
	test_commands \
	$(NULL)

check_PROGRAMS = \
	testname \
	test_commands \
	$(NULL)

testname_SOURCES = \
	testsuites/testname/testname.vala \
	posix_extras.vapi \
	libpth.vapi \
	tasklet.vapi \
	$(NULL)

testname_VALAFLAGS = \
	--main=Tasklets.Test.NameTester.main \
	--pkg glib-2.0 \
	--pkg gio-2.0 \
	--pkg gee-0.8 \
	--pkg posix \
	$(NULL)

testname_CPPFLAGS = \
	$(GOBJECT_CFLAGS) \
	$(GIO_CFLAGS) \
	$(GEE_CFLAGS) \
	-I$(srcdir) \
	$(NULL)

testname_LDADD = \
	$(GOBJECT_LIBS) \
	$(GIO_LIBS) \
	$(GEE_LIBS) \
	$(builddir)/libtasklet.la \
	$(NULL)

test_commands_SOURCES = \
	testsuites/test_commands/test_commands.vala \
	posix_extras.vapi \
	libpth.vapi \
	tasklet.vapi \
	$(NULL)

test_commands_VALAFLAGS = \
	--main=Tasklets.Test.CommandsTester.main \
	--pkg glib-2.0 \
	--pkg gio-2.0 \
	--pkg gee-0.8 \
	--pkg posix \
	$(NULL)

test_commands_CPPFLAGS = \
	$(GOBJECT_CFLAGS) \
	$(GIO_CFLAGS) \
	$(GEE_CFLAGS) \
	-I$(srcdir) \
	$(NULL)

test_commands_LDADD = \
	$(GOBJECT_LIBS) \
	$(GIO_LIBS) \
	$(GEE_LIBS) \
	$(builddir)/libtasklet.la \
	$(NULL)

vapidir = $(datadir)/vala/vapi
dist_vapi_DATA = \
	tasklet.vapi \
	tasklet.deps \
	posix_extras.vapi \
	libpth.vapi \
	$(NULL)
include_HEADERS = tasklet.h
pkgconfigdir = $(libdir)/pkgconfig
pkgconfig_DATA = tasklet.pc
EXTRA_DIST = tasklet.pc.in
CLEANFILES = \
	$(srcdir)/tasklet.vapi \
	$(srcdir)/tasklet.h \
	$(srcdir)/libtasklet_la_vala.stamp \
	$(srcdir)/use_with_libpth_vapi.c \
	$(srcdir)/libwrappth.c \
	$(srcdir)/tasklet.c \
	$(srcdir)/tasklet_blocking_sockets.c \
	$(srcdir)/time.c \
	$(srcdir)/microfunc.c \
	$(srcdir)/channel.c \
	$(srcdir)/testsuites/testname/testname.c \
	$(srcdir)/testsuites/test_commands/test_commands.c \
	$(NULL)
DISTCLEANFILES = tasklet.pc
BUILT_SOURCES = libtasklet_la_vala.stamp

