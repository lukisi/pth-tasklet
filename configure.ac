AC_PREREQ([2.68])
AC_INIT([pth-tasklet],[1.0])
AC_CONFIG_MACRO_DIR([m4])

AM_INIT_AUTOMAKE([subdir-objects] [1.11])
AM_SILENT_RULES([yes])

dnl This avoids dumb '-g -O2' autoconf's default, but won't 
dnl prevent user from setting a specific value for CFLAGS
: ${CFLAGS=""}

LT_INIT
AM_PROG_CC_C_O

dnl Check for vala
AM_PROG_VALAC([0.24])

AM_MAINTAINER_MODE([enable])

PKG_CHECK_MODULES([GOBJECT], [gobject-2.0 glib-2.0])
PKG_CHECK_MODULES([GIO], [gio-2.0 gio-unix-2.0])
PKG_CHECK_VAR([GIO_PREFIX], [gio-2.0], [prefix])
PKG_CHECK_MODULES([GEE], [gee-0.8])
PKG_CHECK_VAR([GEE_PREFIX], [gee-0.8], [prefix])
PKG_CHECK_MODULES([TASKLETSYSTEM], [tasklet-system])
PKG_CHECK_VAR([TASKLETSYSTEM_VAPIDIR], [tasklet-system], [vapidir])

#
# Check for GNU Pth library.
#
AC_PATH_PROG([PTH_CONFIG], [pth-config], [no])
if test "$PTH_CONFIG" = "no"; then
  AC_MSG_ERROR([[
***
*** We need the support of the GNU Portable Threads Library.
*** Download it from ftp://ftp.gnu.org/gnu/pth/
*** On a Debian GNU/Linux system you might want to try
***   apt-get install libpth-dev
***]])
else
  PTH_CFLAGS=`$PTH_CONFIG --cflags`
  PTH_LIBS=`$PTH_CONFIG --ldflags`
  PTH_LIBS="$PTH_LIBS `$PTH_CONFIG --libs --all`"
fi
AC_SUBST([PTH_CFLAGS])
AC_SUBST([PTH_LIBS])

AC_CONFIG_HEADERS([config.h])
AC_CONFIG_FILES([Makefile pth-tasklet.pc])
AC_OUTPUT

