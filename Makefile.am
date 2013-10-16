NULL = 
ACLOCAL_AMFLAGS = -I m4
lib_LTLIBRARIES = libtasklet.la
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
AM_VALAFLAGS = -g -H tasklet.h --library tasklet \
	$(LOGTASKLET_VALAFLAGS) \
	--pkg gee-1.0 --pkg gio-2.0 \
	--pkg posix --pkg linux --pkg posix_extras \
	--pkg libpth --pkg logger --vapidir . \
	$(NULL)
AM_CPPFLAGS = \
	$(GOBJECT_CFLAGS) \
	$(PTH_CFLAGS) \
	$(GEE_CFLAGS) \
	$(GIO_CFLAGS) \
	$(LOGGER_CFLAGS) \
	$(NULL)
libtasklet_la_LIBADD = \
	$(PTH_LIBS) \
	$(GIO_LIBS) \
	$(GEE_LIBS) \
	$(GOBJECT_LIBS) \
	$(LOGGER_LIBS) \
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
	tasklet.vapi \
	tasklet.h \
	libtasklet_la_vala.stamp \
	$(NULL)
DISTCLEANFILES = tasklet.pc
BUILT_SOURCES = libtasklet_la_vala.stamp

