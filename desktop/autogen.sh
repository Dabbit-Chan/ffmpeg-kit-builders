#!/bin/sh

rm -rf \
  configure \
  aclocal.m4 \
  Makefile.in \
  src/Makefile.in \
  autom4te.cache/ \
  config.h.in \
  config.guess \
  config.sub \
  install-sh \
  ltmain.sh \
  missing \
  depcomp \
  compile \
  ar-lib \
  m4/libtool.m4 \
  m4/lt*.m4 \
  config.log \
  config.status \
  configure~ \
  libtool \
  Makefile

autoreconf --force --install -I m4
