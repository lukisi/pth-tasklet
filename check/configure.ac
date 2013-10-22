AC_INIT(bcastlisten, 1.0)

AC_CONFIG_HEADERS([config.h])

AM_INIT_AUTOMAKE([subdir-objects] [1.11])

AM_SILENT_RULES([yes])

dnl This will remove default CFLAGS='-g -O2' that AC_PROG_CC sets.
: ${CFLAGS=""}

AC_PROG_CC



dnl Check for vala
AM_PROG_VALAC([0.10.0])


[]
PKG_CHECK_MODULES(GIO,gio-2.0)

PKG_CHECK_MODULES(GEE,gee-1.0)

PKG_CHECK_MODULES(TASKLET,tasklet)

PKG_CHECK_MODULES(LOGGER,logger)

PKG_CHECK_MODULES(GOBJECT,glib-2.0
gobject-2.0)

AC_OUTPUT([
Makefile

])
