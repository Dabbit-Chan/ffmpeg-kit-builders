#!/bin/bash

FFMPEG_SRC_DIR="${1:-/home/vscode/ffmpeg-kit-builders/prebuilt/src/ffmpeg}"
CURRENT_SOURCE_DIR="${2:-/home/vscode/ffmpeg-kit-builders/desktop}"
PATCH_DIR="${CURRENT_SOURCE_DIR}/patches"

rsync -am --include='*/' \
      --include='*.c' --include='*.h' --include='*.css' --include='*.html' \
      --exclude='*' \
      "$FFMPEG_SRC_DIR/fftools/" "$CURRENT_SOURCE_DIR/src/"

if [ -d "$PATCH_DIR" ]; then
    echo "-- Checking for patches in 'patches' directory..."
    
    # Ensure patch utility is installed
    if ! command -v patch &> /dev/null; then
        echo "patch command could not be found" >&2
        exit 1
    fi

    # Iterate over .patch files in the directory
    for PATCH_FILE in "$PATCH_DIR"/*.patch; do
        # Handle case where no .patch files exist
        [ -e "$PATCH_FILE" ] || continue
        
        PATCH_NAME=$(basename "$PATCH_FILE")
        echo "-- Processing patch: $PATCH_NAME"

        # Check if applied (Reverse dry-run)
        # -p1: strip 1 directory level
        # -R: reverse check
        # --dry-run: do not modify files
        # -s: silent/quiet mode
        patch -p1 -R --dry-run -s -i "$PATCH_FILE" -d "$CURRENT_SOURCE_DIR" &> /dev/null
        PATCH_APPLIED_EXIT_CODE=$?

        if [ $PATCH_APPLIED_EXIT_CODE -eq 0 ]; then
            echo "  - Already applied."
        else
            # Apply Patch
            # -N: ignore patches that seem to be already applied or reversed
            patch -p1 -N -i "$PATCH_FILE" -d "$CURRENT_SOURCE_DIR"
            PATCH_EXIT_CODE=$?

            if [ $PATCH_EXIT_CODE -ne 0 ]; then
                echo "FATAL: Failed to apply patch '$PATCH_NAME'. Check for conflicts." >&2
                exit 1
            else
                echo "  - Applied successfully."
            fi
        fi
    done
fi

# exec $CURRENT_SOURCE_DIR/scripts/audit_cmds.sh

exec python3 $CURRENT_SOURCE_DIR/scripts/tls_patch.py

exec python3 $CURRENT_SOURCE_DIR/scripts/options_patch.py