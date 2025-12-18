lib_LTLIBRARIES = libffmpegkit.la

# ------------------------------------------------------------------------------
# Source Configuration
# ------------------------------------------------------------------------------

# Static Sources: 
# FFmpegKit.cpp (C++) and dummy.c (C) ensure Automake generates rules for both languages.
libffmpegkit_la_SOURCES = FFmpegKit.cpp dummy.c

# Dynamic Objects:
# Link the object files detected by configure.
# This approach bypasses standard SOURCES listing for dynamic files.
libffmpegkit_la_LIBADD = @FFMPEGKIT_OBJECTS@ @FFMPEG_LIBS@

# Dependencies:
# Ensure these objects are compiled before the library is linked.
libffmpegkit_la_DEPENDENCIES = @FFMPEGKIT_OBJECTS@

# ------------------------------------------------------------------------------
# Compiler Flags & Defines
# ------------------------------------------------------------------------------

FFMPEG_CXX_MACROS = -D__STDC_CONSTANT_MACROS -D__STDC_LIMIT_MACROS -D__STDC_FORMAT_MACROS

# Standard Flags + FFmpeg Definitions
# We use AM_CFLAGS to ensure these apply to all C compilations (including cmdutils.c)
if WINDOWS
AM_CFLAGS = $(CFLAGS) @WINDOWS_CFLAGS@ -DFFMPEG_KIT_WINDOWS
AM_CXXFLAGS = $(CXXFLAGS) @WINDOWS_CXXFLAGS@ -DFFMPEG_KIT_WINDOWS -std=c++11 $(FFMPEG_CXX_MACROS)
AM_CPPFLAGS = $(CPPFLAGS) -DFFMPEG_KIT_BUILDING_DLL
else
AM_CFLAGS = $(CFLAGS)
AM_CXXFLAGS = $(CXXFLAGS) -std=c++11 $(FFMPEG_CXX_MACROS)
endif

# Linker Flags
libffmpegkit_la_LDFLAGS = -no-undefined -avoid-version \
                          -Wl,--export-all-symbols -Wl,--enable-auto-import \
                          -Wl,--allow-multiple-definition

# ------------------------------------------------------------------------------
# Header Installation
# ------------------------------------------------------------------------------

include_HEADERS = 
DYNAMIC_HEADER_LIST = @FFMPEGKIT_HEADERS@

install-data-local:
	@$(NORMAL_INSTALL)
	$(MKDIR_P) "$(DESTDIR)$(includedir)"
	@list='$(DYNAMIC_HEADER_LIST)'; for p in $$list; do \
	  if test -f "$$p"; then \
	    echo " $(INSTALL_DATA) '$$p' '$(DESTDIR)$(includedir)/$$p'"; \
	    $(INSTALL_DATA) "$$p" "$(DESTDIR)$(includedir)/$$p"; \
	  else :; fi; \
	done

uninstall-local:
	@list='$(DYNAMIC_HEADER_LIST)'; for p in $$list; do \
	  rm -f "$(DESTDIR)$(includedir)/$$p"; \
	done