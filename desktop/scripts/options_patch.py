import re
import os

SRC_DIR = "src"

FILES = {
    "ffmpeg_opt.c": "ffmpeg",
    "ffplay.c": "ffplay",
    "ffprobe.c": "ffprobe"
}

def process_opt_common():
    filepath = os.path.join(SRC_DIR, "opt_common.h")
    if not os.path.exists(filepath): return []
    
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Regex updated to include \[\] for array indices
    pattern = r'\{\s*"([^"]+)"[^{]+?\{\s*&([a-zA-Z_][a-zA-Z0-9_\[\]]*)\s*\}'
    bindings = re.findall(pattern, content)

    content = re.sub(r'\{\s*&([a-zA-Z_][a-zA-Z0-9_\[\]]*)\s*\}', '{ NULL }', content)

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print(f"[PATCHED] opt_common.h decoupled {len(bindings)} options.")
    return bindings

def process_file(filepath, tool_name, common_bindings):
    if not os.path.exists(filepath): return
    
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Regex updated to include \[\] for array indices
    pattern = r'\{\s*"([^"]+)"[^{]+?\{\s*&([a-zA-Z_][a-zA-Z0-9_\[\]]*)\s*\}'
    local_bindings = re.findall(pattern, content)

    content = re.sub(r'\{\s*&([a-zA-Z_][a-zA-Z0-9_\[\]]*)\s*\}', '{ NULL }', content)

    content = re.sub(r'const\s+OptionDef\s+(real_options|options)\[\]', r'FFMPEG_THREAD_LOCAL OptionDef \1[]', content)

    all_bindings = common_bindings + local_bindings

    if all_bindings:
        init_func = f"\nvoid {tool_name}_tls_init_options(void) {{\n"
        if tool_name == "ffprobe":
            init_func += f"    if (!options) options = real_options;\n"
        init_func += f"    for (int i = 0; options[i].name != NULL; i++) {{\n"

        for opt, var in all_bindings:
            init_func += f'        if (strcmp(options[i].name, "{opt}") == 0) options[i].u.dst_ptr = &{var};\n'
        init_func += f"    }}\n}}\n"

        if '#include <string.h>' not in content:
            content = '#include <string.h>\n' + content
        content += init_func

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
        
    print(f"[PATCHED] {os.path.basename(filepath)} decoupled {len(local_bindings)} local options.")

def update_headers():
    for h in ["ffmpeg.h", "ffplay.h", "ffprobe.h"]:
        path = os.path.join(SRC_DIR, h)
        if not os.path.exists(path): continue
        
        with open(path, 'r', encoding='utf-8') as f:
            content = f.read()

        content = re.sub(r'extern\s+(?:FFMPEG_THREAD_LOCAL\s+)?(?:const\s+)?OptionDef\s+options\[\]', 
                         'extern FFMPEG_THREAD_LOCAL OptionDef options[]', content)

        with open(path, 'w', encoding='utf-8') as f:
            f.write(content)
            
    print("[PATCHED] Headers normalized.")

if __name__ == "__main__":
    print("[INFO] Running Multi-line Option Decoupler...")
    common = process_opt_common()
    for f, tool in FILES.items():
        process_file(os.path.join(SRC_DIR, f), tool, common)
    update_headers()
    print("[SUCCESS] All options decoupled and arrays made thread-local.")