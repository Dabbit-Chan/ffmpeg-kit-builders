# ------------------------------------------------------------------------------
# Source Configuration
# ------------------------------------------------------------------------------

# Static Sources: 
# FFmpegKit.cpp (C++) and dummy.c (C) ensure Automake generates rules for both languages.

# Dynamic Objects:
# Link the object files detected by configure.
# This approach bypasses standard SOURCES listing for dynamic files.

# Dependencies:
# Ensure these objects are compiled before the library is linked.

if BUILD_STATIC_LIB
lib_LIBRARIES = libffmpegkit.a
libffmpegkit_a_SOURCES = FFmpegKit.cpp dummy.c
libffmpegkit_a_CPPFLAGS = $(AM_CPPFLAGS)
libffmpegkit_a_LIBADD = @FFMPEGKIT_OBJECTS@ 
libffmpegkit_a_DEPENDENCIES = @FFMPEGKIT_OBJECTS@
else
lib_LTLIBRARIES = libffmpegkit.la
libffmpegkit_la_SOURCES = FFmpegKit.cpp dummy.c
libffmpegkit_la_LIBADD = @FFMPEGKIT_OBJECTS@ @FFMPEG_LIBS@
endif

# ------------------------------------------------------------------------------
# Compiler Flags & Defines
# ------------------------------------------------------------------------------

FFMPEG_CXX_MACROS = -D__STDC_CONSTANT_MACROS -D__STDC_LIMIT_MACROS -D__STDC_FORMAT_MACROS
BUILD_DATE = -DFFMPEG_KIT_BUILD_DATE=@FFMPEG_KIT_BUILD_DATE@
BASE_FLAGS = $(BUILD_DATE) $(FFMPEG_CFLAGS)

# Standard Flags + FFmpeg Definitions
# We use AM_CFLAGS to ensure these apply to all C compilations (including cmdutils.c)
if WINDOWS
AM_CFLAGS = $(CFLAGS) @WINDOWS_CFLAGS@ -DFFMPEG_KIT_WINDOWS $(BASE_FLAGS)
AM_CXXFLAGS = $(CXXFLAGS) @WINDOWS_CXXFLAGS@ -DFFMPEG_KIT_WINDOWS -std=c++11 $(FFMPEG_CXX_MACROS) $(BASE_FLAGS)
if BUILD_STATIC_LIB
AM_CPPFLAGS = $(CPPFLAGS) -DFFMPEG_KIT_BUILDING_DLL $(BUILD_DATE)
else
AM_CPPFLAGS = $(CPPFLAGS)
endif
else
AM_CFLAGS = $(CFLAGS) $(BASE_FLAGS)
AM_CXXFLAGS = $(CXXFLAGS) -std=c++11 $(FFMPEG_CXX_MACROS) $(BASE_FLAGS)
AM_CPPFLAGS = $(CPPFLAGS) $(BUILD_DATE)
endif

# Linker Flags
# libffmpegkit_la_LDFLAGS = -no-undefined -avoid-version \
#													 -Wl,--export-all-symbols -Wl,--enable-auto-import \
#													 -Wl,--allow-multiple-definition
if BUILD_SHARED_LIB

LINKER_SCRIPT = ffmpeg-linker-script.map

$(LINKER_SCRIPT):
	@echo "Generating $(LINKER_SCRIPT)..."
	@echo "{" > $@
	@echo "    global:" >> $@
	@echo "        av*;" >> $@
	@echo "        postproc_*;" >> $@
	@echo "        pp_*;" >> $@
	@echo "        swr_*;" >> $@
	@echo "        swresample_*;" >> $@
	@echo "        swscale_*;" >> $@
	@echo "        sws_*;" >> $@
	@echo "    local:" >> $@
	@echo "        *;" >> $@
	@echo "};" >> $@

libffmpegkit_la_DEPENDENCIES = @FFMPEGKIT_OBJECTS@ $(LINKER_SCRIPT)

libffmpegkit_la_LDFLAGS = -no-undefined -avoid-version \
													-Wl,--gc-sections \
													-Wl,--version-script=$(LINKER_SCRIPT) \
													-Wl,-Bsymbolic \
													-Wl,--allow-multiple-definition \
													@WINDOWS_LDFLAGS@

CLEANFILES = $(LINKER_SCRIPT)

endif
# ==============================================================================
# Header Installation
# ==============================================================================

DYNAMIC_HEADER_LIST = @FFMPEGKIT_HEADERS@

install-data-local:
	@$(NORMAL_INSTALL)
	$(MKDIR_P) "$(DESTDIR)$(includedir)"
	@list='$(DYNAMIC_HEADER_LIST)'; for p in $$list; do \
		if test -f "$$p"; then \
			d=`dirname "$$p"`; \
			if test "$$d" != "."; then \
				 $(MKDIR_P) "$(DESTDIR)$(includedir)/$$d"; \
			fi; \
			echo " $(INSTALL_DATA) '$$p' '$(DESTDIR)$(includedir)/$$p'"; \
			$(INSTALL_DATA) "$$p" "$(DESTDIR)$(includedir)/$$p"; \
		else :; fi; \
	done

uninstall-local:
	@list='$(DYNAMIC_HEADER_LIST)'; for p in $$list; do \
		rm -f "$(DESTDIR)$(includedir)/$$p"; \
	done
	@# Attempt to remove the specific subdirectories we created (e.g., include/graph/)
	@# We loop through the headers again, get their directory, and try to remove it.
	@# 'rmdir' automatically fails if the dir is not empty, which is exactly what we want.
	@# '|| true' ensures the build doesn't stop on those harmless failures.
	@list='$(DYNAMIC_HEADER_LIST)'; for p in $$list; do \
		d=`dirname "$$p"`; \
		if test "$$d" != "."; then \
			rmdir "$(DESTDIR)$(includedir)/$$d" 2>/dev/null || true; \
		fi; \
	done

# ==============================================================================
# Pkg-Config File Installation
# ==============================================================================

# This installs src/ffmpeg-kit.pc into ${libdir}/pkgconfig/
pkgconfigdir = $(libdir)/pkgconfig
pkgconfig_DATA = ffmpeg-kit.pc

# ==============================================================================
# Shared library installation
# ==============================================================================

if BUILD_SHARED_LIB
# 1. Ensure 'bundle_manifest.txt' is generated when running 'make'
all-local: bundle_manifest.txt

# 2. Run the helper script to analyze the built .la file and generate the manifest
bundle_manifest.txt: libffmpegkit.la
	@echo "Generating shared library bundle manifest..."
	@chmod +x $(top_srcdir)/scripts/shared-library.sh
	@$(top_srcdir)/scripts/shared-library.sh "$(ffmpeg_build_dir)"

# 3. Install Hook: Copy external shared dependencies listed in the manifest
install-exec-hook:
	@if test -f bundle_manifest.txt; then \
		echo "Installing bundled shared libraries..."; \
		cat bundle_manifest.txt | while read shared_lib; do \
			echo "	[BUNDLE] $$shared_lib -> $(DESTDIR)$(libdir)/"; \
			cp -fv "$$shared_lib"* "$(DESTDIR)$(libdir)/"; \
		done; \
	fi

clean-local:
	rm -f bundle_manifest.txt
endif


# ==============================================================================
# Monolithic Static Library Generation (Static Builds Only)
# ==============================================================================

if BUILD_STATIC_LIB

# We build this temporary file locally
MONOLITH_LIB_NAME = libffmpegkit_full.a

# Ensure it is built during 'make'
all-local: $(MONOLITH_LIB_NAME)

$(MONOLITH_LIB_NAME): libffmpegkit.a
	@chmod +x $(top_srcdir)/scripts/static-library.sh
	@$(top_srcdir)/scripts/static-library.sh "$@" "$(AR)" "$(RANLIB)" "$(ffmpeg_build_dir)"

# Hook: Overwrite the installed 'thin' libffmpegkit.a with our 'monolith'
# We also remove the .la file as it references dependencies we just bundled.
install-exec-hook:
	@echo "Installing Monolithic Library to $(DESTDIR)$(libdir)/libffmpegkit.a"
	$(INSTALL_DATA) $(MONOLITH_LIB_NAME) $(DESTDIR)$(libdir)/libffmpegkit.a
	@rm -f $(DESTDIR)$(libdir)/libffmpegkit.la
	@#
	@# Install Shared Libraries identified during build
	@if test -f bundle_manifest.txt; then \
		echo "Installing bundled shared libraries..."; \
		cat bundle_manifest.txt | while read shared_lib; do \
			echo "	[BUNDLE] $$shared_lib -> $(DESTDIR)$(libdir)/"; \
			cp -fv "$$shared_lib"* "$(DESTDIR)$(libdir)/"; \
		done; \
	fi

# Clean up the manifest on make clean
clean-local:
	rm -f $(MONOLITH_LIB_NAME) lib.mri bundle_manifest.txt

endif