#!/usr/bin/env python3
# ==================================================
#  KoolDots (2026)
#  Project URL: https://github.com/LinuxBeginnings
#  License: GNU GPLv3
#  SPDX-License-Identifier: GPL-3.0-or-later
# ==================================================
import sys
import re
import os

def normalize_combo(combo):
    return combo.replace(" ", "").replace("\t", "")

def extract_combo(line):
    # Remove comments and whitespace
    line = re.sub(r'\s*#.*$', '', line).strip()
    
    if '=' not in line:
        return None
        
    try:
        rhs = line.split('=', 1)[1]
        parts = [p.strip() for p in rhs.split(',')]
        if len(parts) < 2:
            return None
            
        mods = parts[0]
        key = parts[1]
        return f"{mods},{key}"
    except Exception:
        return None

def extract_section(line):
    # Match section comment headers like:  # --- Screenshots --------------
    m = re.match(r'^\s*#\s*-{2,}\s*(.+?)\s*-{2,}\s*$', line)
    if m:
        return m.group(1).strip()
    return None

def parse_files(files):
    # Data structures to match original logic
    binding_map = {}        # combo -> effective line
    source_map = {}         # combo -> source file
    section_map = {}        # combo -> section name (from preceding comment header)
    user_bind_map = {}      # combo -> user bind line
    unbound_user = {}       # combo -> True if explicitly unbound in user file
    seen_any_bind = {}      # combo -> True if seen
    default_seen = {}       # combo -> True if default bind exists
    
    # We assume the last file in the list is the user config (UserKeybinds.conf)
    # This matches the bash script logic where user_keybinds_conf is passed last
    if not files:
        return [], []
        
    user_conf_path = files[-1] if len(files) > 1 else None

    for file_path in files:
        if not os.path.exists(file_path):
            continue
            
        current_section = ""
        try:
            with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                for line in f:
                    line = line.rstrip('\n')
                    if not line or line.strip().startswith('#'):
                        # Track section header comments (e.g. "# --- Screenshots ---")
                        sect = extract_section(line)
                        if sect:
                            current_section = sect
                        continue
                        
                    is_bind = re.match(r'^\s*bind[a-z]*\s*=', line)
                    is_unbind = re.match(r'^\s*unbind\s*=', line)
                    
                    if is_bind:
                        combo_raw = extract_combo(line)
                        if not combo_raw:
                            continue
                        combo = normalize_combo(combo_raw)
                        seen_any_bind[combo] = True
                        
                        is_user_file = (file_path == user_conf_path)
                        
                        if not is_user_file:
                            default_seen[combo] = True
                            
                        # prefer user bind, else first seen
                        if combo not in source_map:
                            binding_map[combo] = line
                            source_map[combo] = file_path
                            section_map[combo] = current_section
                            
                        if is_user_file:
                            user_bind_map[combo] = line
                            binding_map[combo] = line
                            source_map[combo] = file_path
                            section_map[combo] = current_section
                            
                    elif is_unbind:
                        combo_raw = extract_combo(line)
                        if not combo_raw:
                            continue
                        combo = normalize_combo(combo_raw)
                        
                        if file_path == user_conf_path:
                            unbound_user[combo] = True
                            
                        # If unbind is found, we should remove the bind from our map
                        # so it doesn't show up in the menu.
                        if combo in binding_map:
                            del binding_map[combo]
                        if combo in source_map:
                            del source_map[combo]
                            
        except Exception as e:
            # Silently ignore read errors to mimic bash behavior or log to stderr
            sys.stderr.write(f"Error reading {file_path}: {e}\n")
            continue

    # Build results
    raw_keybinds = []
    missing_unbind_suggestions = []
    
    for combo in seen_any_bind:
        eff_line = binding_map.get(combo)
        src = source_map.get(combo)
        
        if not eff_line:
            continue
            
        raw_keybinds.append((eff_line, section_map.get(combo, "")))
        
        # Check for missing unbind suggestions
        # If user overrides a default but didn't unbind in user file
        if (src == user_conf_path and 
            combo in default_seen and 
            combo not in unbound_user):
            
            # Create suggestion: replace 'bind' with 'unbind'
            suggest = re.sub(r'^\s*bind[a-z]*', 'unbind', eff_line)
            missing_unbind_suggestions.append(suggest)
            
    return raw_keybinds, missing_unbind_suggestions

def format_for_rofi(raw_binds):
    # Returns a list of (display_text, section) tuples.
    formatted_lines = []
    
    for entry in raw_binds:
        # Each entry is a (line, section) tuple.
        if isinstance(entry, tuple):
            line, section = entry
        else:
            line, section = entry, ""
        # line is like "bind = MODS, KEY, DISPATCHER, PARAMS" or "bindd = ..."
        # Parsing logic from awk script:
        
        # 1. Cleaner binder
        match = re.match(r'^\s*(bind[a-z]*)\s*=(.*)', line)
        if not match:
            continue
            
        binder = match.group(1).replace(" ", "").replace("\t", "")
        rhs = match.group(2).strip()
        
        # "bind" ends in d, but doesn't have a description. "bindd" does.
        # Original script logic `index(binder, "d")>0` was likely buggy for "bind".
        # We'll assume strict check for bindd or similar if needed, 
        # but avoiding "bind" having a description is crucial for correct output.
        has_desc = 'd' in binder and binder != 'bind'

        # Split by comma regex (handling spaces)
        parts = [p.strip() for p in rhs.split(',')]
        
        if len(parts) < 2:
            continue
            
        mods = parts[0]
        key = parts[1]
        
        desc = ""
        dispatcher = ""
        params = ""
        
        start_idx = 0
        
        if has_desc:
            desc = parts[2] if len(parts) >= 3 else ""
            dispatcher = parts[3] if len(parts) >= 4 else ""
            start_idx = 4
        else:
            dispatcher = parts[2] if len(parts) >= 3 else ""
            start_idx = 3
            
        # Collect params
        remaining_parts = []
        if start_idx < len(parts):
            for i in range(start_idx, len(parts)):
                if parts[i]:
                    remaining_parts.append(parts[i])
        
        if remaining_parts:
            params = ", ".join(remaining_parts)
            
        # Formatting mods
        mods = mods.replace("$mainMod", "SUPER")
        mods = re.sub(r'[ \t]+', '+', mods)
        
        # Build combo string
        if mods and key:
            combo_str = f"{mods}+{key}"
        elif key:
            combo_str = key
        else:
            combo_str = mods
            
        # Final Print Format
        if has_desc and desc:
            display = f"{combo_str} — {desc}"
        elif dispatcher:
            if params:
                display = f"{combo_str} — {dispatcher} {params}"
            else:
                display = f"{combo_str} — {dispatcher}"
        else:
            display = combo_str

        formatted_lines.append((display, section))
            
    return formatted_lines

def main():
    if len(sys.argv) < 2:
        # No files provided
        sys.exit(0)
        
    config_files = sys.argv[1:]
    
    binds, suggestions = parse_files(config_files)
    
    if not binds:
        print("no keybinds found.")
        sys.exit(1)
        
    formatted = format_for_rofi(binds)
    
    # Emit NUL-delimited rofi dmenu rows. Each row may carry an invisible
    # "meta" keyword (the section name) so typing a category name surfaces
    # every binding in that section, even though the section word isn't shown.
    out = sys.stdout.buffer
    for display, section in formatted:
        if section:
            row = f"{display}\x00meta\x1f{section}\n"
        else:
            row = f"{display}\n"
        out.write(row.encode("utf-8"))
    out.flush()
        
    # Handle suggestions (print to stderr or a specific file if needed, 
    # but the original script assigns it to a variable 'msg'.
    # To pass this back to bash, we might need a separate mechanism or just print to a known file.)
    if suggestions:
        import tempfile
        try:
            with tempfile.NamedTemporaryFile(mode='w', delete=False, prefix='hypr-unbind-suggestions-', suffix='.conf') as tf:
                tf.write('\n'.join(suggestions) + '\n')
                # We print a special marker line to stdout that the bash script can capture?
                # Or better, just print to stderr and let the user ignore it, 
                # OR, since the original script specifically puts it in the Rofi message,
                # we can print a special string at the END of stdout or to a side channel.
                
                # Let's decide to print the valid keybinds to stdout (for rofi).
                # And print the suggestion file path to a known location or specific fd if possible.
                # Simplest: Write to a fixed temp file location that the bash script checks.
                with open("/tmp/hypr_keybind_suggestions_file", "w") as sf:
                    sf.write(tf.name)
        except Exception:
            pass

if __name__ == "__main__":
    main()
