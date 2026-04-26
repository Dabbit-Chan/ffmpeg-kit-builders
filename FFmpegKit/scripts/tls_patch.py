import re
import os
from collections import defaultdict

# 1. Path Configuration
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT_DIR = os.path.dirname(SCRIPT_DIR)
SRC_DIR = os.path.join(ROOT_DIR, "src")
FFTOOLS_LIST = os.path.join(ROOT_DIR, "scripts", "fftools.txt")

def get_whitelisted_files():
    """Reads the whitelist and normalizes paths for cross-platform consistency."""
    if not os.path.exists(FFTOOLS_LIST): 
        print(f"[ERROR] Whitelist not found at {FFTOOLS_LIST}")
        return set()
    with open(FFTOOLS_LIST, 'r') as f:
        return {line.strip().replace('\\', '/') for line in f if line.strip()}

def get_target_c_files(whitelist):
    """Recursively finds .c files, strictly filtering by the whitelist."""
    c_files = []
    for root, _, files in os.walk(SRC_DIR):
        for f in files:
            if not f.endswith('.c'): 
                continue
            rel_path = os.path.relpath(os.path.join(root, f), SRC_DIR).replace('\\', '/')
            if f in whitelist or rel_path in whitelist:
                c_files.append(os.path.join(root, f))
    return c_files

def is_windows_build():
    """Auto-detects if the current CMake configuration is cross-compiling for Windows."""
    cc_json = os.path.join(ROOT_DIR, "build", "compile_commands.json")
    if os.path.exists(cc_json):
        with open(cc_json, 'r', encoding='utf-8') as f:
            content = f.read().lower()
            if 'mingw' in content or 'w64' in content:
                return True
    return False

def run_systemic_audit(c_files):
    """Generates the AST dumps, conditionally applying Windows workarounds."""
    print("[INFO] Generating compiler-accurate AST logs for whitelisted files...")
    
    if not c_files:
        print("[WARNING] No whitelisted .c files found to audit.")
        return

    c_files_str = " ".join(c_files)
    
    # Dynamically apply the god-mode flag only if MinGW/Windows is detected
    win32_flag = ' --extra-arg="-U_WIN32"' if is_windows_build() else ""
    
    BASE_CMD = f"clang-query -p {ROOT_DIR}/build/ {c_files_str}{win32_flag} --extra-arg=\"-Wno-everything\""
    
    commands = [
        f"({BASE_CMD} -c \"set output dump\" -c \"m varDecl(allOf(hasGlobalStorage(), isDefinition(), unless(isStaticStorageClass()), unless(hasType(isConstQualified()))))\" 2>/dev/null | grep \"^VarDecl\") > {SCRIPT_DIR}/audit_vars.log 2>&1",
        f"({BASE_CMD} -c \"set output dump\" -c \"m varDecl(allOf(hasGlobalStorage(), unless(isDefinition()), unless(isStaticStorageClass()), unless(hasType(isConstQualified()))))\" 2>/dev/null | grep \"^VarDecl\") > {SCRIPT_DIR}/audit_extern.log 2>&1",
        f"({BASE_CMD} -c \"set output dump\" -c \"m varDecl(allOf(isStaticStorageClass(), unless(hasType(isConstQualified()))))\" 2>/dev/null | grep \"^VarDecl\") > {SCRIPT_DIR}/audit_static.log 2>&1",
    ]
    
    for cmd in commands:
        os.system(cmd)

def parse_logs_by_line(log_paths):
    """Extracts line-exact coordinates from the AST output."""
    line_patches = defaultdict(lambda: defaultdict(set))
    for log_path in log_paths:
        if not os.path.exists(log_path): 
            continue
        current_file = None
        with open(log_path, 'r', encoding='utf-8') as f:
            for line in f:
                if not line.startswith("VarDecl"): 
                    continue
                
                match_full = re.search(r"<\s*(.*?\.[ch]):(\d+):", line)
                if match_full:
                    current_file = match_full.group(1)
                    line_num = int(match_full.group(2))
                else:
                    match_line = re.search(r"<\s*line:(\d+):", line)
                    if match_line and current_file:
                        line_num = int(match_line.group(1))
                    else:
                        continue
                        
                match_sym = re.search(r"\s(\w+)\s+'", line)
                if match_sym:
                    line_patches[current_file][line_num].add(match_sym.group(1))
    return line_patches

TLS_EXCLUSION_GLOBAL = {
    "received_sigterm",
    "received_nb_signals",
    "ffmpeg_exited",
    "transcode_init_done",
    "frame_data_lock",
    "ffmpeg_kit_assert_triggered",
    "ffmpeg_kit_assert_jmp_ptr",
}

TLS_EXCLUSION_PER_FILE = {
    "ffplay.c": {
        "sdl_supported_color_spaces",
        "options_template",
        "wanted_stream_spec",
        "sws_ctx",
        "tmp_frame",
        "renderer_info",
    },
    "ffmpeg_opt.c": {
        "options_template",
        "wanted_stream_spec",
    },
    "ffmpeg.h": {
        "options_template",
    },
    "ffprobe.c": {
        "real_options",
        "real_options_template",
        "options_template",
    },
}

def apply_line_patches(line_patches, whitelist):
    """Applies the TLS macro exclusively to files explicitly listed in the whitelist and within SRC_DIR."""
    include_line = '#include "ffmpeg_tls.h"\n'
    abs_src_dir = os.path.abspath(SRC_DIR)
    
    for file_path, patches in line_patches.items():
        abs_file_path = os.path.abspath(file_path)
        if not os.path.exists(abs_file_path): 
            continue
        
        # Limit changes to source strictly under SRC_DIR
        try:
            rel_path_to_src = os.path.relpath(abs_file_path, abs_src_dir)
            if rel_path_to_src.startswith("..") or os.path.isabs(rel_path_to_src):
                continue
        except ValueError:
            continue # Different drives on Windows
            
        # Strict Whitelist Enforcement Barrier
        file_name = os.path.basename(abs_file_path)
        rel_path = rel_path_to_src.replace('\\', '/')
        if file_name not in whitelist and rel_path not in whitelist:
            continue
            
        with open(abs_file_path, 'r', encoding='utf-8') as f:
            lines = f.readlines()
            
        new_lines = []
        if not any('ffmpeg_tls.h' in l for l in lines):
            new_lines.append(include_line)
            
        for i, line in enumerate(lines):
            line_num = i + 1 
            if line_num in patches:
                # Check for exclusions by checking if any excluded symbol is in the patches for this line
                symbols_on_line = patches[line_num]
                file_exclusions = TLS_EXCLUSION_PER_FILE.get(file_name, set())
                effective_exclusions = TLS_EXCLUSION_GLOBAL | file_exclusions
                if any(sym in effective_exclusions for sym in symbols_on_line):
                    print(f"[SKIPPED] {file_path}:{line_num}: Excluded symbols: {symbols_on_line}")
                    new_lines.append(line)
                    continue

                if "FFMPEG_THREAD_LOCAL" not in line:
                    match = re.match(r"^(\s*)", line)
                    indent = match.group(1) if match else ""
                    stripped = line.lstrip()
                    
                    if stripped.startswith("extern "):
                        line = indent + "extern FFMPEG_THREAD_LOCAL " + stripped[7:]
                    elif stripped.startswith("static "):
                        line = indent + "static FFMPEG_THREAD_LOCAL " + stripped[7:]
                    else:
                        line = indent + "FFMPEG_THREAD_LOCAL " + stripped
            new_lines.append(line)
            
        with open(abs_file_path, 'w', encoding='utf-8') as f:
            f.writelines(new_lines)
            
        print(f"[PATCHED] {abs_file_path}: Applied {len(patches)} coordinate patches.")

def create_tls_header():
    header_path = os.path.join(SRC_DIR, "ffmpeg_tls.h")
    content = (
        "#ifndef FFMPEG_TLS_H\n#define FFMPEG_TLS_H\n\n"
        "#if defined(_MSC_VER) || defined(__MINGW32__) || defined(__MINGW64__)\n"
        "    #define FFMPEG_WEAK_SYMBOL __declspec(selectany)\n"
        "#elif defined(__GNUC__) || defined(__clang__)\n"
        "    #define FFMPEG_WEAK_SYMBOL __attribute__((weak))\n"
        "#else\n"
        "    #define FFMPEG_WEAK_SYMBOL\n"
        "#endif\n\n"
        "#if defined(_MSC_VER) || defined(__MINGW32__) || defined(__MINGW64__)\n"
        "    #define FFMPEG_THREAD_LOCAL __declspec(thread)\n"
        "#elif defined(__APPLE__)\n"
        "    #define FFMPEG_THREAD_LOCAL __attribute__((visibility(\"hidden\"))) _Thread_local\n"
        "#elif defined(__STDC_VERSION__) && __STDC_VERSION__ >= 201112L\n"
        "    #define FFMPEG_THREAD_LOCAL _Thread_local\n"
        "#else\n"
        "    #define FFMPEG_THREAD_LOCAL __thread\n"
        "#endif\n\n#endif\n"
    )
    with open(header_path, 'w', encoding='utf-8') as f:
        f.write(content)

if __name__ == "__main__":
    create_tls_header()
    whitelist = get_whitelisted_files()
    
    if not whitelist:
        print("[ERROR] Whitelist is empty. Aborting.")
        exit(1)
        
    c_files = get_target_c_files(whitelist)
    run_systemic_audit(c_files)
    
    LOG_FILES = [
        os.path.join(SCRIPT_DIR, "audit_vars.log"),
        os.path.join(SCRIPT_DIR, "audit_extern.log"),
        os.path.join(SCRIPT_DIR, "audit_static.log")
    ]
    
    line_patches = parse_logs_by_line(LOG_FILES)
    
    if line_patches:
        apply_line_patches(line_patches, whitelist)
        print("\n[SUCCESS] Project-wide recursive audit and whitelist patch complete.")
    else:
        print("[ERROR] No coordinates mapped.")