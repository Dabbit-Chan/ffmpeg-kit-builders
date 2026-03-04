import re
import os
from collections import defaultdict

LOG_FILE = "audit_address.log"

def parse_log():
    if not os.path.exists(LOG_FILE):
        print(f"Error: {LOG_FILE} not found.")
        return

    with open(LOG_FILE, 'r', encoding='utf-8') as f:
        content = f.read()

    # Split the log into individual match blocks
    matches = content.split('Match #')[1:]
    results = defaultdict(list)

    for match in matches:
        # Extract the "root" binding which tells us exactly where the array is taking the address
        # Group 1: Filepath, Group 2: Line Number
        root_loc = re.search(r'(/[^:]+\.[ch]):(\d+):\d+: note: "root" binds here', match)
        
        # Extract the variable name being referenced (e.g., &file_overwrite)
        var_ref = re.search(r'&\s*([a-zA-Z0-9_]+)', match[root_loc.end() if root_loc else 0:])

        if root_loc and var_ref:
            filename = os.path.basename(root_loc.group(1))
            line_num = root_loc.group(2)
            var_name = var_ref.group(1)
            
            results[filename].append((line_num, var_name))

    # Print a clean, human-readable summary
    print(f"--- PARSED AUDIT LOG ---")
    for filename, bindings in sorted(results.items()):
        print(f"\n[{filename}]")
        # Deduplicate and sort by line number
        unique_bindings = sorted(list(set(bindings)), key=lambda x: int(x[0]))
        for line, var in unique_bindings:
            print(f"  Line {line:<5} -> Bound to: &{var}")

if __name__ == "__main__":
    parse_log()