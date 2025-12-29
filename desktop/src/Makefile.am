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
AM_CFLAGS = $(CFLAGS) @WINDOWS_CFLAGS@ -DFFMPEG_KIT_WINDOWS -DFFMPEG_KIT_BUILD_DATE=@FFMPEG_KIT_BUILD_DATE@ $(FFMPEG_CFLAGS)
AM_CXXFLAGS = $(CXXFLAGS) @WINDOWS_CXXFLAGS@ -DFFMPEG_KIT_WINDOWS -std=c++11 $(FFMPEG_CXX_MACROS) -DFFMPEG_KIT_BUILD_DATE=@FFMPEG_KIT_BUILD_DATE@ $(FFMPEG_CFLAGS)
AM_CPPFLAGS = $(CPPFLAGS) -DFFMPEG_KIT_BUILDING_DLL -DFFMPEG_KIT_BUILD_DATE=@FFMPEG_KIT_BUILD_DATE@
else
AM_CFLAGS = $(CFLAGS) -DFFMPEG_KIT_BUILD_DATE=@FFMPEG_KIT_BUILD_DATE@ $(FFMPEG_CFLAGS)
AM_CXXFLAGS = $(CXXFLAGS) -std=c++11 $(FFMPEG_CXX_MACROS) -DFFMPEG_KIT_BUILD_DATE=@FFMPEG_KIT_BUILD_DATE@ $(FFMPEG_CFLAGS)
AM_CPPFLAGS = $(CPPFLAGS) -DFFMPEG_KIT_BUILD_DATE=@FFMPEG_KIT_BUILD_DATE@
endif

# Linker Flags
# libffmpegkit_la_LDFLAGS = -no-undefined -avoid-version \
#                           -Wl,--export-all-symbols -Wl,--enable-auto-import \
#                           -Wl,--allow-multiple-definition
libffmpegkit_la_LDFLAGS = -no-undefined -avoid-version \
                          -Wl,--gc-sections \
                          @WINDOWS_LDFLAGS@
                          
# ==============================================================================
# Header Installation
# ==============================================================================

include_HEADERS = 
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
# Monolithic Static Library Generation (Static Builds Only)
# ==============================================================================

if BUILD_STATIC_LIB

# We build this temporary file locally
MONOLITH_LIB_NAME = libffmpegkit_full.a

# Ensure it is built during 'make'
all-local: $(MONOLITH_LIB_NAME)

# Hook: Overwrite the installed 'thin' libffmpegkit.a with our 'monolith'
# We also remove the .la file as it references dependencies we just bundled.
install-exec-hook:
	@echo "Installing Monolithic Library to $(DESTDIR)$(libdir)/libffmpegkit.a"
	$(INSTALL_DATA) $(MONOLITH_LIB_NAME) $(DESTDIR)$(libdir)/libffmpegkit.a
	@rm -f $(DESTDIR)$(libdir)/libffmpegkit.la

# Logic to merge the wrapper + FFmpeg libs + External libs
$(MONOLITH_LIB_NAME): libffmpegkit.la
	@echo "Generating monolithic static library: $@"
	@rm -f lib.mri
	@echo "CREATE $@" > lib.mri
	@echo "ADDLIB .libs/libffmpegkit.a" >> lib.mri
	@#
	@# 1. Get dependencies via pkg-config
	@PKG_CONFIG_PATH="$(ffmpeg_build_dir)/lib/pkgconfig" \
	pkg-config --static --libs libavdevice libavfilter libavformat libavcodec libswresample libswscale libavutil > libs.txt
	@#
	@# 2. Parse libraries
	@# Use '\' to keep shell active
	@raw_libs_to_keep=""; \
	deps=`cat libs.txt`; \
	search_paths=""; \
	for flag in $$deps; do \
	  case "$$flag" in \
	    -L*) \
	      path=$${flag#-L}; \
	      search_paths="$$search_paths $$path"; \
	      ;; \
	  esac; \
	done; \
	for flag in $$deps; do \
	  case "$$flag" in \
	    -l*) \
	      name=$${flag#-l}; \
	      case "$$name" in \
	        # --- Category A: Standard C/C++ & Math Runtimes (Do Not Bundle) --- \
	        m|c|pthread|dl|rt|stdc++|gcc|gcc_s|atomic) \
	          raw_libs_to_keep="$$raw_libs_to_keep -l$$name"; \
	          ;; \
	        # --- Category B: Windows System Libraries (Do Not Bundle) --- \
	        mingw*|moldname|kernel32|user32|gdi32|winmm|ws2_32|iphlpapi|advapi32|shell32|ole32|uuid|bcrypt|psapi|shlwapi|crypt32|secur32) \
	          raw_libs_to_keep="$$raw_libs_to_keep -l$$name"; \
	          ;; \
	        # --- Category C: Linux/System Utilities (Do Not Bundle) --- \
	        blkid|util|mount|selinux|sepol|resolv) \
	          raw_libs_to_keep="$$raw_libs_to_keep -l$$name"; \
	          ;; \
	        # --- Category D: Bundled Libraries (FFmpeg, x264, ssl, etc.) --- \
	        *) \
	          found=no; \
	          for dir in $$search_paths; do \
	            if test -f "$$dir/lib$$name.a"; then \
	              echo "ADDLIB $$dir/lib$$name.a" >> lib.mri; \
	              found=yes; \
	              break; \
	            fi; \
	          done; \
	          if test "$$found" = "no"; then \
	             echo "  [COMBINE LIBRARY] WARNING: Could not find static library for -l$$name. Keeping in PC file."; \
	             raw_libs_to_keep="$$raw_libs_to_keep -l$$name"; \
	          fi; \
	          ;; \
	      esac; \
	      ;; \
	  esac; \
	done; \
	echo "SAVE" >> lib.mri; \
	echo "END" >> lib.mri; \
	$(AR) -M < lib.mri; \
	$(RANLIB) $@; \
	rm -f lib.mri libs.txt; \
	clean_libs=`echo $$raw_libs_to_keep | awk '{for (i=1;i<=NF;i++) if (!seen[$$i]++) printf("%s%s", $$i, OFS)}'`; \
	clean_libs=`echo $$clean_libs | sed 's/ *$$//'`; \
	if test -n "$$clean_libs"; then clean_libs="$$clean_libs"; fi; \
	echo "Created $@"; \
	echo "Updating ffmpeg-kit.pc with external libs:$$clean_libs"; \
	sed -i "s|FFMPEG_KIT_EXT_LIBS|$$clean_libs|g" ffmpeg-kit.pc

endif