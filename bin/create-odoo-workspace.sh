#!/bin/bash
set -euo pipefail

# --- Error helper for consistent fatal errors ---
die() {
  echo "[ERROR] $*" >&2
  exit 1
}

# --- Cleanup trap for temp files ---
TMPFILES=()
trap '
  for __tmp in "${TMPFILES[@]}"; do
    [ -f "$__tmp" ] && rm -f "$__tmp"
  done
' EXIT

# --- OS detection for user settings path ---
get_user_settings_files() {
  local files=()
  local os
  os=$(uname -s)
  if [[ "$os" == "Darwin" ]]; then
    files+=("$HOME/Library/Application Support/Code/User/settings.json")
    files+=("$HOME/Library/Application Support/Cursor/User/settings.json")
  else
    files+=("$HOME/.config/Code/User/settings.json")
    files+=("$HOME/.config/Cursor/User/settings.json")
  fi
  printf '%s\n' "${files[@]}"
}

# --- Dependency checks ---
for dep in jq python3 realpath; do
  if ! command -v "$dep" >/dev/null 2>&1; then
    die "Required dependency '$dep' is not installed."
  fi
done

# --- Argument parsing (handle relative config paths) ---
if [ "$#" -lt 1 ]; then
  die "Please provide at least one module path
Usage: create-odoo-workspace.sh <path-to-module1> [<path-to-module2> ...] [odoo-version|config-path]"
fi

LAST_ARG="${!#}"
if [[ "$LAST_ARG" =~ ^/ || "$LAST_ARG" =~ ^[0-9]+$ ]]; then
  ODOO_ARG="$LAST_ARG"
  MODULE_PATHS=("${@:1:$(($#-1))}")
else
  ODOO_ARG=""
  MODULE_PATHS=("$@")
fi

# --- Validate all module paths ---
MODULE_PATHS_ABS=()
for MODULE_PATH in "${MODULE_PATHS[@]}"; do
  MODULE_PATH=$(realpath "$MODULE_PATH")
  [ -d "$MODULE_PATH" ] || die "Directory does not exist: $MODULE_PATH"
  MODULE_PATHS_ABS+=("$MODULE_PATH")
done

PRIMARY_MODULE_PATH="${MODULE_PATHS_ABS[0]}"
PRIMARY_MODULE_NAME=$(basename "$PRIMARY_MODULE_PATH")
WORKSPACE_FILE="${PRIMARY_MODULE_PATH}/${PRIMARY_MODULE_NAME}.code-workspace"

# --- Determine Odoo version or config path (handle relative) ---
if [ -n "${ODOO_ARG:-}" ]; then
  if [[ "$ODOO_ARG" =~ ^/ ]]; then
    CONFIG_FILE="$ODOO_ARG"
    [[ -f "$CONFIG_FILE" ]] || die "Specified config file does not exist: $CONFIG_FILE"
    ODOO_VERSION=$(basename "$CONFIG_FILE" | grep -oP '\d+')
  else
    ODOO_VERSION="$ODOO_ARG"
    CONFIG_FILE="/etc/odoo${ODOO_VERSION}.conf"
  fi
else
  CONFIG_FILES=(/etc/odoo*.conf)
  if [ ${#CONFIG_FILES[@]} -eq 1 ]; then
    CONFIG_FILE="${CONFIG_FILES[0]}"
    ODOO_VERSION=$(basename "$CONFIG_FILE" | grep -oP '\d+')
  else
    die "Multiple or no Odoo config files found. Please specify the Odoo version or config path."
  fi
fi

# --- JSONC-safe writer (for VS Code/Cursor settings) ---
jsonc_set_keys() {
  local file="$1"; shift
  python3 - "$file" "$@" <<'PY'
import json, re, sys, os
path = sys.argv[1]
pairs = sys.argv[2:]  # k1 v1 k2 v2 ...
def load_jsonc(p):
    try:
        s = open(p, 'r', encoding='utf-8').read()
    except FileNotFoundError:
        return {}
    s = re.sub(r'/\*.*?\*/', '', s, flags=re.S)
    s = re.sub(r'(^|[^:])//.*', r'\1', s)
    s = re.sub(r',\s*(\}|\])', r'\1', s)
    try:
        return json.loads(s) if s.strip() else {}
    except Exception as e:
        print(f"JSONC parse failed for {p}: {e}", file=sys.stderr)
        return {}
data = load_jsonc(path)
for i in range(0, len(pairs), 2):
    k, v = pairs[i], pairs[i+1]
    data[k] = v
tmp = path + ".tmp"
os.makedirs(os.path.dirname(path), exist_ok=True)
with open(tmp, 'w', encoding='utf-8') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
os.replace(tmp, path)
PY
}

# --- Point the extension to the global odools.toml in user settings (JSONC-safe) ---
set_odoo_server_config_path() {
  local target="$HOME/.config/odoo/odools.toml"
  local files=($(get_user_settings_files))
  for f in "${files[@]}"; do
    mkdir -p "$(dirname "$f")"
    [[ -f "$f" ]] || echo '{}' > "$f"
    jsonc_set_keys "$f" "Odoo.serverConfigPath" "$target" "odoo.server.configPath" "$target"
  done
  echo "Set Odoo.serverConfigPath to $target (User settings)"
}

# --- Keep global ~/.config/odoo/odools.toml in sync with the Odoo conf ---
ensure_global_odoo_toml() {
  local cfg="$CONFIG_FILE"
  local out="$HOME/.config/odoo/odools.toml"
  [[ -n "$cfg" && -f "$cfg" ]] || { echo "Skip TOML sync: CONFIG_FILE not set or file missing"; return; }

  mkdir -p "$(dirname "$out")"

  # Read addons_path (first non-comment), strip quotes, trim
  local raw
  raw=$(awk -F= '/^[[:space:]]*addons_path[[:space:]]*=/ {print $2; exit}' "$cfg" | sed "s/[\"']//g" | xargs)
  [[ -z "$raw" ]] && { echo "Warning: addons_path not found in $cfg"; return; }

  # Normalize separators: allow colon or comma in odoo.conf
  [[ "$raw" == *","* ]] || raw=${raw//:/,}

  # Split and trim paths
  IFS=',' read -r -a A <<<"$raw"
  for i in "${!A[@]}"; do A[$i]=$(echo "${A[$i]}" | xargs); done

  # Infer odoo_path from any entry that ends with /addons
  local ODOO_PATH=""
  for p in "${A[@]}"; do
    [[ "$p" == */addons ]] && { ODOO_PATH="${p%/addons}"; break; }
  done

  # Write TOML (always quote strings)
  {
    echo '[[config]]'
    echo "name = \"Odoo ${ODOO_VERSION:-unknown} (global)\""
    [[ -n "$ODOO_PATH" ]] && echo "odoo_path = \"${ODOO_PATH}\""
    echo 'addons_paths = ['
    for p in "${A[@]}"; do echo "  \"${p}\","; done | sed '$ s/,$//'
    echo ']'
    echo "python_path = \"${HOME}/odoo${ODOO_VERSION:-16}-venv/bin/python\""
  } > "$out"

  echo "Synced OdooLS config → $out (from $cfg)"
}

# Generate TOML and set user setting (functions defined above!)
ensure_global_odoo_toml
set_odoo_server_config_path

# --- Parse addons_path robustly (comma/colon, handle quotes, spaces) ---
if [ -f "$CONFIG_FILE" ]; then
  addons_line=$(grep -E '^\s*addons_path\s*=' "$CONFIG_FILE" || true)
  if [ -n "$addons_line" ]; then
    addon_paths_list=$(echo "$addons_line" | cut -d'=' -f2 | sed "s/[\"']//g")
        # Support both comma and colon as separator
    if [[ "$addon_paths_list" == *","* ]]; then
      IFS=',' read -r -a ADDON_PATHS <<< "$addon_paths_list"
    else
      IFS=':' read -r -a ADDON_PATHS <<< "$addon_paths_list"
    fi
    for i in "${!ADDON_PATHS[@]}"; do
      ADDON_PATHS[$i]=$(echo "${ADDON_PATHS[$i]}" | xargs)
    done
  else
    die "addons_path not found in $CONFIG_FILE"
  fi
else
  die "config file $CONFIG_FILE not found"
fi

# --- Manifest detection: support __manifest__.py and __openerp__.py ---
MODULE_NAMES=()
MANIFEST_FILES=()
for MODULE_PATH in "${MODULE_PATHS_ABS[@]}"; do
  MODULE_NAME=$(basename "$MODULE_PATH")
  MODULE_NAMES+=("$MODULE_NAME")
  if [ -f "$MODULE_PATH/__manifest__.py" ]; then
    MANIFEST_FILES+=("$MODULE_PATH/__manifest__.py")
  elif [ -f "$MODULE_PATH/__openerp__.py" ]; then
    MANIFEST_FILES+=("$MODULE_PATH/__openerp__.py")
  else
    die "No manifest found in $MODULE_PATH"
  fi
done

# --- Helper: robustly extract Odoo source dir from config file ---
get_odoo_source_dir() {
  local config_file="$1"
  local odoo_source_dir=""
  IFS=',' read -ra paths <<< "$(awk -F= '/^[[:space:]]*addons_path[[:space:]]*=/ {print $2}' "$config_file" | sed "s/[\"']//g")"
  for p in "${paths[@]}"; do
    p="${p#"${p%%[![:space:]]*}"}"
    p="${p%"${p##*[![:space:]]}"}"
    if [[ "$p" == */addons ]]; then
      odoo_source_dir="${p%/addons}"
      break
    fi
  done
  if [ -z "$odoo_source_dir" ]; then
    echo "DEBUG: addons_path line: '$(awk -F= '/^[[:space:]]*addons_path[[:space:]]*=/ {print $2}' "$config_file")'" >&2
    echo "DEBUG: parsed paths: ${paths[*]}" >&2
    die "Could not determine Odoo source directory from config file $config_file (no path ending with /addons in addons_path)"
  fi
  realpath "$odoo_source_dir"
}

# --- Function to process workspace update ---
process_workspace_update() {
  local manifest_files=("$@")
  local all_empty=1
  for mf in "${manifest_files[@]}"; do
    if ! grep -q "depends[[:space:]]*=[[:space:]]*\[\]" "$mf"; then
      all_empty=0
      break
    fi
  done
  if [ "$all_empty" -eq 1 ]; then
    local workspace_file="$WORKSPACE_FILE"
    local tmp_file
    tmp_file=$(mktemp)
    TMPFILES+=("$tmp_file")
    jq --argjson folders "$(printf '%s\n' "${MODULE_PATHS_ABS[@]}" | jq -R . | jq -s 'map({path: ., name: "📦 " + (split("/")[-1]) + " (Current)"})')" \
      '.folders = $folders' "$workspace_file" > "$tmp_file" && mv "$tmp_file" "$workspace_file"
    return 0
  fi

  local workspace_file="$WORKSPACE_FILE"
  local tmp_file
  tmp_file=$(mktemp)
  TMPFILES+=("$tmp_file")

  local addon_paths_str="["
  for path in "${ADDON_PATHS[@]}"; do
    addon_paths_str+="\"$path\", "
  done
  addon_paths_str="${addon_paths_str%, }]"
  local manifest_files_pylist
  manifest_files_pylist=$(printf "'%s', " "${manifest_files[@]}")
  manifest_files_pylist="[${manifest_files_pylist%, }]"
  local module_names_pylist
  module_names_pylist=$(printf "'%s', " "${MODULE_NAMES[@]}")
  module_names_pylist="[${module_names_pylist%, }]"
  local module_paths_pylist
  module_paths_pylist=$(printf "'%s', " "${MODULE_PATHS_ABS[@]}")
  module_paths_pylist="[${module_paths_pylist%, }]"
  local odoo_source_dir
  odoo_source_dir=$(get_odoo_source_dir "$CONFIG_FILE") || return 1
  local odoo_addons_path="${odoo_source_dir}/addons"
  echo "Debug: Odoo addons path: $odoo_addons_path" >&2

  if python3 - <<EOF
import json, sys, os
manifest_files = $manifest_files_pylist
module_names = $module_names_pylist
module_paths = $module_paths_pylist
odoo_addons_path = "$odoo_addons_path"
workspace_file = "$workspace_file"
tmp_file = "$tmp_file"
def get_manifest_deps(files):
    deps = set()
    import ast
    for mf in files:
        try:
            with open(mf, 'r') as f:
                content = f.read()
                manifest = ast.literal_eval(content)
                deps.update(manifest.get('depends', []))
        except Exception as e:
            print(f"Error reading manifest {mf}: {e}", file=sys.stderr)
    return deps
def read_workspace():
    try:
        with open(workspace_file, 'r') as f:
            return json.load(f)
    except Exception as e:
        print(f"Error reading workspace: {e}", file=sys.stderr)
        return None
def find_module_path(module_name, addon_paths):
    for path in addon_paths:
        full_path = os.path.join(path, module_name)
        if os.path.isdir(full_path):
            return full_path, path
    full_path = os.path.join(odoo_addons_path, module_name)
    if os.path.isdir(full_path):
        return full_path, odoo_addons_path
    return None, None
addon_paths = $addon_paths_str
deps = get_manifest_deps(manifest_files)
deps = set(deps) - set(module_names)
ws = read_workspace()
if not ws:
    print("Error: Could not read workspace file", file=sys.stderr)
    sys.exit(1)
current_folders = ws.get('folders', [])
other = [f for f in current_folders if not (f.get('name','').endswith('(Current)') or f.get('name','').startswith('📚') or f.get('name','').startswith('⚙️') or f.get('name','').startswith('🏢') or f.get('name','').startswith('➕'))]
new_folders = []
for i, module_path in enumerate(module_paths):
    module_name = module_names[i]
    new_folders.append({"path": module_path, "name": f"📦 {module_name} (Current)"})
for dep in deps:
    res = find_module_path(dep, addon_paths)
    if res[0]:
        module_path, source_path = res
        if source_path == odoo_addons_path:
            icon = "⚙️"
        elif "/odooenterprise/" in source_path:
            icon = "🏢"
        elif "/odoo18/" in source_path:
            icon = "📚"
        else:
            icon = "➕"
        new_folders.append({"path": module_path, "name": f"{icon} {dep}"})
ws['folders'] = new_folders + other
with open(tmp_file, 'w') as f:
    json.dump(ws, f, indent=4, ensure_ascii=False)
EOF
  then
    mv "$tmp_file" "$WORKSPACE_FILE"
    return 0
  else
    rm -f "$tmp_file"
    return 1
  fi
}

# --- Function to create a new workspace file ---
create_new_workspace() {
  local workspace_file="$1"
  shift
  local module_names=("$@")
  local tmp_file
  tmp_file=$(mktemp)

  echo '{ "folders": [' > "$tmp_file"
  for i in "${!MODULE_PATHS_ABS[@]}"; do
    local comma=","
    [ $i -eq $((${#MODULE_PATHS_ABS[@]}-1)) ] && comma=""
    echo "    { \"path\": \"${MODULE_PATHS_ABS[$i]}\", \"name\": \"📦 ${MODULE_NAMES[$i]} (Current)\" }$comma" >> "$tmp_file"
  done
  echo '], "settings": {} }' >> "$tmp_file"
  mv "$tmp_file" "$workspace_file"

  if ! process_workspace_update "${MANIFEST_FILES[@]}"; then
    die "Failed to process dependencies"
  fi
}

create_vscode_launch_config() {
  local module_path="$PRIMARY_MODULE_PATH"
  local module_name="$PRIMARY_MODULE_NAME"
  local config_file="$CONFIG_FILE"

  local base_dir
  base_dir=$(get_odoo_source_dir "$config_file")
  local program_path="${base_dir}/odoo-bin"

  local db_name="odoo${ODOO_VERSION}demodata"
  local xmlrpc_port
  xmlrpc_port=$(grep -E '^\s*xmlrpc_port\s*=' "$config_file" | cut -d'=' -f2 | xargs)

  mkdir -p "${module_path}/.vscode"

  cat > "${module_path}/.vscode/launch.json" << EOF
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Odoo Debug",
      "type": "debugpy",
      "request": "launch",
      "program": "${program_path}",
      "args": [
        "-c", "${config_file}",
        "-d", "${db_name}",
        "-u", "$(IFS=,; echo "${MODULE_NAMES[*]}")",
        "--dev", "all",
        "--log-handler=odoo.addons.${module_name}:DEBUG"
      ],
      "env": {
        "ODOO_ENV": "dev",
        "VIRTUAL_ENV": "${base_dir}-venv",
        "PATH": "${base_dir}-venv/bin:\${env:PATH}"
      },
      "console": "integratedTerminal",
      "justMyCode": false,
      "python": "${base_dir}-venv/bin/python"
    }
  ]
}
EOF
}

create_vscode_settings() {
  local module_path="$PRIMARY_MODULE_PATH"
  local config_file="$CONFIG_FILE"
  local odoo_source_dir
  odoo_source_dir=$(get_odoo_source_dir "$config_file")
  local settings_dir="$module_path/.vscode"
  local settings_file="$settings_dir/settings.json"
  mkdir -p "$settings_dir"

  # Build extraPaths
  local extra_paths_json
  extra_paths_json=$(jq -n --arg odoo "$odoo_source_dir" \
    --arg odoo_sub "$odoo_source_dir/odoo" \
    --arg odoo_addons "$odoo_source_dir/odoo/addons" \
    --argjson addons "$(printf '%s\n' "${ADDON_PATHS[@]}" | jq -R . | jq -s .)" \
    '$addons | [$odoo, $odoo_sub, $odoo_addons] + .')

  # JSONC-safe update for settings.json
  python3 - "$settings_file" "$extra_paths_json" <<'PY'
import json, re, sys, os
path = sys.argv[1]
extra = json.loads(sys.argv[2])
def load_jsonc(p):
    try: s=open(p,'r',encoding='utf-8').read()
    except FileNotFoundError: return {}
    s=re.sub(r'/\*.*?\*/','',s,flags=re.S); s=re.sub(r'(^|[^:])//.*',r'\1',s); s=re.sub(r',\s*([}\]])',r'\1',s)
    try: return json.loads(s) if s.strip() else {}
    except: return {}
data = load_jsonc(path)
old = data.get("python.analysis.extraPaths", [])
seen=set(); merged=[]
for p in (old + extra):
    if p not in seen:
        merged.append(p); seen.add(p)
data["python.analysis.extraPaths"] = merged
tmp = path + ".tmp"; os.makedirs(os.path.dirname(path), exist_ok=True)
with open(tmp,'w',encoding='utf-8') as f: json.dump(data,f,indent=2,ensure_ascii=False)
os.replace(tmp,path)
PY
}

create_python_path_setting() {
  local module_path="$PRIMARY_MODULE_PATH"
  local settings_dir="$module_path/.vscode"
  local settings_file="$settings_dir/settings.json"
  mkdir -p "$settings_dir"
  jsonc_set_keys "$settings_file" "python.pythonPath" "$HOME/odoo${ODOO_VERSION}-venv/bin/python"
}

create_odoo_ls_settings() {
  local module_path="$PRIMARY_MODULE_PATH"
  local settings_dir="$module_path/.vscode"
  local settings_file="$settings_dir/settings.json"
  local selected_config="Odoo $ODOO_VERSION"

  if [[ "$WORKSPACE_FILE" == *.code-workspace ]]; then
    python3 - "$WORKSPACE_FILE" "$selected_config" <<'PY'
import json, sys, os
path, selected = sys.argv[1], sys.argv[2]
try: data=json.load(open(path,'r',encoding='utf-8'))
except Exception: data={"folders":[],"settings":{}}
data.setdefault("settings",{})
data["settings"].pop("Odoo.configurations", None)
data["settings"]["Odoo.selectedConfiguration"] = selected
tmp=path+".tmp"
with open(tmp,'w',encoding='utf-8') as f: json.dump(data,f,indent=2,ensure_ascii=False)
os.replace(tmp,path)
PY
  else
    mkdir -p "$settings_dir"
    python3 - "$settings_file" "$selected_config" <<'PY'
import json, re, sys, os
path, selected = sys.argv[1], sys.argv[2]
def load_jsonc(p):
    try: s=open(p,'r',encoding='utf-8').read()
    except FileNotFoundError: return {}
    s=re.sub(r'/\*.*?\*/','',s,flags=re.S)
    s=re.sub(r'(^|[^:])//.*',r'\1',s)
    s=re.sub(r',\s*([}\]])',r'\1',s)
    try: return json.loads(s) if s.strip() else {}
    except: return {}
data = load_jsonc(path)
data.pop("Odoo.configurations", None)
data["Odoo.selectedConfiguration"] = selected
tmp=path+".tmp"; os.makedirs(os.path.dirname(path), exist_ok=True)
with open(tmp,'w',encoding='utf-8') as f: json.dump(data,f,indent=2,ensure_ascii=False)
os.replace(tmp,path)
PY
  fi
}

mirror_settings_to_workspace() {
  local workspace_file="$WORKSPACE_FILE"
  local settings_file="${PRIMARY_MODULE_PATH}/.vscode/settings.json"
  if [ -f "$settings_file" ]; then
    python3 - "$settings_file" "$workspace_file" <<'PY'
import json, re, sys, os
sf, wf = sys.argv[1], sys.argv[2]
def load_jsonc(p):
    try: s=open(p,'r',encoding='utf-8').read()
    except FileNotFoundError: return {}
    s=re.sub(r'/\*.*?\*/','',s,flags=re.S); s=re.sub(r'(^|[^:])//.*',r'\1',s); s=re.sub(r',\s*([}\]])',r'\1',s)
    try: return json.loads(s) if s.strip() else {}
    except: return {}
sdata = load_jsonc(sf)
try: wdata=json.load(open(wf,'r',encoding='utf-8'))
except: wdata={"folders":[], "settings":{}}
wdata.setdefault("settings",{})
if "python.analysis.extraPaths" in sdata:
    wdata["settings"]["python.analysis.extraPaths"] = sdata["python.analysis.extraPaths"]
if "python.pythonPath" in sdata:
    wdata["settings"]["python.pythonPath"] = sdata["python.pythonPath"]
tmp=wf+".tmp"
with open(tmp,'w',encoding='utf-8') as f: json.dump(wdata,f,indent=2,ensure_ascii=False)
os.replace(tmp,wf)
PY
  fi
}

patch_odoo_ls_user_settings() {
  local user_settings_files=( $(get_user_settings_files) )
  local odoo_source_dir
  odoo_source_dir=$(get_odoo_source_dir "$CONFIG_FILE")
  local python_path="$HOME/odoo${ODOO_VERSION}-venv/bin/python"
  local config_name="Odoo $ODOO_VERSION"

  local addons_json
  if [ ${#ADDON_PATHS[@]} -eq 0 ]; then
    addons_json='[]'
  else
    addons_json=$(printf '%s\n' "${ADDON_PATHS[@]}" | jq -R . | jq -s .)
  fi

  for user_settings_file in "${user_settings_files[@]}"; do
    mkdir -p "$(dirname "$user_settings_file")"
    [[ -f "$user_settings_file" ]] || echo '{}' > "$user_settings_file"
    python3 - "$user_settings_file" "$config_name" "$odoo_source_dir" "$addons_json" "$python_path" <<'PY'
import json, re, sys, os
path, name, odoo_dir, addons_json, python_path = sys.argv[1:6]
addons = json.loads(addons_json)
def load_jsonc(p):
    try: s=open(p,'r',encoding='utf-8').read()
    except FileNotFoundError: return {}
    s=re.sub(r'/\*.*?\*/','',s,flags=re.S); s=re.sub(r'(^|[^:])//.*',r'\1',s); s=re.sub(r',\s*([}\]])',r'\1',s)
    try: return json.loads(s) if s.strip() else {}
    except: return {}
data = load_jsonc(path)
confs = data.get("Odoo.configurations") or {}
target = {
    "name": name,
    "rawOdooPath": odoo_dir,
    "odooPath": odoo_dir,
    "addons": addons,
    "pythonPath": python_path,
    "env": {"PYTHONPATH": odoo_dir}
}
def normalized(d):
    x=dict(d); x["addons"]=sorted(x.get("addons",[]))
    return x
existing_id = None
for k,v in list(confs.items()):
    try:
        if normalized(v)==normalized(target):
            existing_id = k; break
    except Exception:
        continue
if existing_id is None:
    nums=[int(k) for k in confs.keys() if str(k).isdigit()]
    next_id=str((max(nums) if nums else -1)+1)
    confs[next_id]=target
    existing_id=next_id
data["Odoo.configurations"]=confs
data["Odoo.selectedConfiguration"]=existing_id
data["pythonPath"]=python_path
tmp=path+".tmp"
with open(tmp,'w',encoding='utf-8') as f: json.dump(data,f,indent=2,ensure_ascii=False)
os.replace(tmp,path)
PY
  done
}

# --- Create/update workspace, settings, and configs ---
if [ -f "$WORKSPACE_FILE" ]; then
  echo "Existing workspace found. Updating dependencies..."
  if process_workspace_update "${MANIFEST_FILES[@]}"; then
    echo "Workspace updated successfully"
  else
    echo "Error updating workspace"
    exit 1
  fi
else
  echo "Creating new workspace for modules: ${MODULE_NAMES[*]}..."
  create_new_workspace "$WORKSPACE_FILE" "${MODULE_NAMES[@]}"
  if process_workspace_update "${MANIFEST_FILES[@]}"; then
    echo "Workspace created and dependencies added successfully"
  else
    echo "Error adding dependencies to workspace"
    exit 1
  fi
fi

echo "Creating debug configuration..."
create_vscode_launch_config

echo "Configuring python.analysis.extraPaths for Odoo..."
create_vscode_settings

echo "Configuring python.pythonPath for Odoo Language Server compatibility..."
create_python_path_setting

echo "Configuring Odoo Language Server extension..."
create_odoo_ls_settings

patch_odoo_ls_user_settings

STATUS="created"
[ -f "$WORKSPACE_FILE" ] && STATUS="updated"

echo "
Workspace $STATUS successfully at: $WORKSPACE_FILE
To use:
1. Open Cursor/VS Code
2. File -> Open Workspace from File...
3. Select ${PRIMARY_MODULE_NAME}.code-workspace

Includes:
- Your current modules
- All dependencies from __manifest__.py
- python.analysis.extraPaths for Odoo imports
- Debug configuration for ${PRIMARY_MODULE_NAME}
"
