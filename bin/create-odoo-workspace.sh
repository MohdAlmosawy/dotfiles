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
    die "Please provide at least one module path\nUsage: create-odoo-workspace.sh <path-to-module1> [<path-to-module2> ...] [odoo-version|config-path]"
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
    if [ ! -d "$MODULE_PATH" ]; then
        die "Directory does not exist: $MODULE_PATH"
    fi
    MODULE_PATHS_ABS+=("$MODULE_PATH")
done

PRIMARY_MODULE_PATH="${MODULE_PATHS_ABS[0]}"
PRIMARY_MODULE_NAME=$(basename "$PRIMARY_MODULE_PATH")
WORKSPACE_FILE="${PRIMARY_MODULE_PATH}/${PRIMARY_MODULE_NAME}.code-workspace"

# --- Determine Odoo version or config path (handle relative) ---
if [ -n "$ODOO_ARG" ]; then
    if [[ "$ODOO_ARG" =~ ^/ ]]; then
        CONFIG_FILE="$ODOO_ARG"
        if [ ! -f "$CONFIG_FILE" ]; then
            die "Specified config file does not exist: $CONFIG_FILE"
        fi
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

# --- Parse addons_path robustly (comma/colon, handle quotes, spaces) ---
if [ -f "$CONFIG_FILE" ]; then
    addons_line=$(grep -E '^\s*addons_path\s*=' "$CONFIG_FILE")
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
    local odoo_source_dir
    odoo_source_dir=""
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
    # Shortcut: if all manifests have empty depends, skip python/jq
    local all_empty=1
    for mf in "${manifest_files[@]}"; do
        if ! grep -q "depends[[:space:]]*=[[:space:]]*\[\]" "$mf"; then
            all_empty=0
            break
        fi
    done
    if [ "$all_empty" -eq 1 ]; then
        # Just ensure main modules are in workspace, skip python/jq
        local workspace_file
        workspace_file="$WORKSPACE_FILE"
        local tmp_file
        tmp_file=$(mktemp)
        TMPFILES+=("$tmp_file")
        jq --argjson folders "$(printf '%s\n' "${MODULE_PATHS_ABS[@]}" | jq -R . | jq -s 'map({path: ., name: "📦 " + (split("/")[-1]) + " (Current)"})')" \
            '.folders = $folders' "$workspace_file" > "$tmp_file" && mv "$tmp_file" "$workspace_file"
        return 0
    fi
    local workspace_file
    workspace_file="$WORKSPACE_FILE"
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
    # Get Odoo source directory from config file dynamically
    local odoo_source_dir
    odoo_source_dir=$(get_odoo_source_dir "$CONFIG_FILE") || return 1
    local odoo_addons_path
    odoo_addons_path="${odoo_source_dir}/addons"
    echo "Debug: Odoo addons path: $odoo_addons_path" >&2
    if python3 - <<EOF
import json
import sys
import os
manifest_files = $manifest_files_pylist
module_names = $module_names_pylist
module_paths = $module_paths_pylist
odoo_addons_path = "$odoo_addons_path"
print(f"Debug: Python received odoo_addons_path: {odoo_addons_path}", file=sys.stderr)
def get_manifest_deps(files):
    deps = set()
    for mf in files:
        try:
            with open(mf, 'r') as f:
                import ast
                content = f.read()
                manifest = ast.literal_eval(content)
                deps.update(manifest.get('depends', []))
        except Exception as e:
            print(f"Error reading manifest {mf}: {e}", file=sys.stderr)
    return deps
def read_workspace():
    try:
        with open("$workspace_file", 'r') as f:
            return json.load(f)
    except Exception as e:
        print(f"Error reading workspace: {e}", file=sys.stderr)
        return None
def find_module_path(module_name):
    addon_paths = $addon_paths_str
    print(f"Debug: Checking addon paths: {addon_paths}", file=sys.stderr)
    for path in addon_paths:
        full_path = os.path.join(path, module_name)
        print(f"Debug: Checking path: {full_path}", file=sys.stderr)
        if os.path.isdir(full_path):
            return full_path, path
    odoo_core_candidates = [
        os.path.expanduser(os.path.join('~', 'odoo', 'odoo', 'addons', module_name)),
        os.path.expanduser(os.path.join('~', 'odoo18', 'odoo', 'addons', module_name)),
        os.path.expanduser(os.path.join('~', 'odoo16', 'odoo', 'addons', module_name)),
        os.path.expanduser(os.path.join('~', 'odoo15', 'odoo', 'addons', module_name)),
        os.path.expanduser(os.path.join('~', 'odoo14', 'odoo', 'addons', module_name)),
    ]
    for candidate in odoo_core_candidates:
        print(f"Debug: Checking Odoo core candidate: {candidate}", file=sys.stderr)
        if os.path.isdir(candidate):
            return candidate, os.path.dirname(candidate)
    full_path = os.path.join(odoo_addons_path, module_name)
    print(f"Debug: Checking Odoo path: {full_path}", file=sys.stderr)
    if os.path.isdir(full_path):
        return full_path, odoo_addons_path
    return None, None
try:
    manifest_deps = get_manifest_deps(manifest_files)
    print(f"Found dependencies: {manifest_deps}", file=sys.stderr)
    manifest_deps = set(manifest_deps) - set(module_names)
    print(f"Dependencies after removing main modules: {manifest_deps}", file=sys.stderr)
    workspace = read_workspace()
    if not workspace:
        print("Error: Could not read workspace file", file=sys.stderr)
        sys.exit(1)
    current_folders = workspace.get('folders', [])
    other_folders = [f for f in current_folders if not (f.get('name', '').endswith('(Current)') or f.get('name', '').startswith('📚') or f.get('name', '').startswith('⚙️') or f.get('name', '').startswith('🏢') or f.get('name', '').startswith('➕'))]
    new_folders = []
    for i, module_path in enumerate(module_paths):
        module_name = module_names[i]
        new_folders.append({
            "path": module_path,
            "name": f"📦 {module_name} (Current)"
        })
    for dep in manifest_deps:
        result = find_module_path(dep)
        if result[0]:
            module_path, source_path = result
            print(f"Looking for dependency {dep}, found path: {module_path}", file=sys.stderr)
            if source_path == odoo_addons_path:
                icon = "⚙️" if dep == "base" else "⚙️"
            elif "/odooenterprise/" in source_path:
                icon = "🏢"
            elif "/odoo18/" in source_path:
                icon = "📚"
            else:
                icon = "➕"
            new_folders.append({
                "path": module_path,
                "name": f"{icon} {dep}"
            })
        else:
            print(f"Warning: Could not find path for dependency {dep}", file=sys.stderr)
    new_folders.extend(other_folders)
    workspace['folders'] = new_folders
    with open("$tmp_file", 'w') as f:
        json.dump(workspace, f, indent=4, ensure_ascii=False)
except Exception as e:
    print(f"Error updating workspace: {e}", file=sys.stderr)
    sys.exit(1)
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
    local tmp_file=$(mktemp)
    
    # Create initial workspace with current modules
    echo '{ "folders": [' > "$tmp_file"
    for i in "${!MODULE_PATHS_ABS[@]}"; do
        local comma=","
        [ $i -eq $((${#MODULE_PATHS_ABS[@]}-1)) ] && comma=""
        echo "    { \"path\": \"${MODULE_PATHS_ABS[$i]}\", \"name\": \"📦 ${MODULE_NAMES[$i]} (Current)\" }$comma" >> "$tmp_file"
    done
    echo '], "settings": {} }' >> "$tmp_file"
    mv "$tmp_file" "$workspace_file"
    
    # Immediately process dependencies
    if ! process_workspace_update "${MANIFEST_FILES[@]}"; then
        die "Failed to process dependencies"
    fi
}

create_vscode_launch_config() {
    local module_path="$PRIMARY_MODULE_PATH"
    local module_name="$PRIMARY_MODULE_NAME"
    local config_file="$CONFIG_FILE"

    # Use robust helper to get base directory
    local base_dir
    base_dir=$(get_odoo_source_dir "$config_file")
    local program_path="${base_dir}/odoo-bin"

    # Extract database name and XML-RPC port from the config file
    local db_name="odoo${ODOO_VERSION}demodata"
    local xmlrpc_port=$(grep -E '^\s*xmlrpc_port\s*=' "$config_file" | cut -d'=' -f2 | xargs)

    # Create .vscode directory if it doesn't exist
    mkdir -p "${module_path}/.vscode"

    # Create launch.json
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

    # Compose all extraPaths: odoo_source_dir, odoo_source_dir/odoo, odoo_source_dir/odoo/addons, all ADDON_PATHS
    local extra_paths_json
    extra_paths_json=$(jq -n --arg odoo "$odoo_source_dir" \
        --arg odoo_sub "$odoo_source_dir/odoo" \
        --arg odoo_addons "$odoo_source_dir/odoo/addons" \
        --argjson addons "$(printf '%s\n' "${ADDON_PATHS[@]}" | jq -R . | jq -s .)" \
        '$addons | [$odoo, $odoo_sub, $odoo_addons] + .')

    # Remove Odoo.configurations and Odoo.selectedConfiguration if present
    if [ -f "$settings_file" ]; then
        tmpfile=$(mktemp)
        TMPFILES+=("$tmpfile")
        jq 'del(."Odoo.configurations", ."Odoo.selectedConfiguration") | (."python.analysis.extraPaths" // []) as $old | ."python.analysis.extraPaths" = ($old + $extraPaths | unique)' \
            --argjson extraPaths "$extra_paths_json" \
            "$settings_file" > "$tmpfile" && mv "$tmpfile" "$settings_file"
    else
        cat > "$settings_file" << EOF
{
    "python.analysis.extraPaths": $(echo "$extra_paths_json")
}
EOF
    fi
}

# Also set python.pythonPath in workspace .vscode/settings.json for Odoo LS compatibility
create_python_path_setting() {
    local module_path="$PRIMARY_MODULE_PATH"
    local settings_dir="$module_path/.vscode"
    local settings_file="$settings_dir/settings.json"
    mkdir -p "$settings_dir"
    if [ -f "$settings_file" ]; then
        tmpfile=$(mktemp)
        TMPFILES+=("$tmpfile")
        jq --arg pythonPath "/home/sayedmohd/odoo${ODOO_VERSION}-venv/bin/python" '. + {"python.pythonPath": $pythonPath}' "$settings_file" > "$tmpfile" && mv "$tmpfile" "$settings_file"
    else
        cat > "$settings_file" << EOF
{
    "python.pythonPath": "/home/sayedmohd/odoo${ODOO_VERSION}-venv/bin/python"
}
EOF
    fi
}

# Remove Odoo.configurations from workspace settings (no-op)
create_odoo_ls_settings() {
    local module_path="$PRIMARY_MODULE_PATH"
    local settings_dir="$module_path/.vscode"
    local settings_file="$settings_dir/settings.json"
    local selected_config="Odoo $ODOO_VERSION"

    # Remove Odoo.configurations from workspace/folder settings if present
    if [[ "$WORKSPACE_FILE" == *.code-workspace ]]; then
        tmpfile=$(mktemp)
        TMPFILES+=("$tmpfile")
        if [ ! -f "$WORKSPACE_FILE" ]; then
            echo '{"folders": [], "settings": {"Odoo.selectedConfiguration": "'$selected_config'"}}' > "$WORKSPACE_FILE"
        else
            jq 'if .settings then .settings |= del(."Odoo.configurations") else . end' "$WORKSPACE_FILE" > "$tmpfile" && mv "$tmpfile" "$WORKSPACE_FILE"
            tmpfile2=$(mktemp)
            TMPFILES+=("$tmpfile2")
            jq --arg selected "$selected_config" '.settings = (.settings // {}) + {"Odoo.selectedConfiguration": $selected}' "$WORKSPACE_FILE" > "$tmpfile2" && mv "$tmpfile2" "$WORKSPACE_FILE"
        fi
    else
        mkdir -p "$settings_dir"
        if [ -f "$settings_file" ]; then
            tmpfile=$(mktemp)
            TMPFILES+=("$tmpfile")
            jq 'del(."Odoo.configurations")' "$settings_file" > "$tmpfile" && mv "$tmpfile" "$settings_file"
            tmpfile2=$(mktemp)
            TMPFILES+=("$tmpfile2")
            jq --arg selected "$selected_config" '. + {"Odoo.selectedConfiguration": $selected}' "$settings_file" > "$tmpfile2" && mv "$tmpfile2" "$settings_file"
        else
            cat > "$settings_file" << EOF
{
    "Odoo.selectedConfiguration": "$selected_config"
}
EOF
        fi
    fi
}

# --- Mirror folder-level settings into .code-workspace settings for multi-root ---
mirror_settings_to_workspace() {
    local workspace_file="$WORKSPACE_FILE"
    local settings_file="${PRIMARY_MODULE_PATH}/.vscode/settings.json"
    if [ -f "$settings_file" ]; then
        local tmpfile=$(mktemp)
        TMPFILES+=("$tmpfile")
        jq 'if .["python.analysis.extraPaths"] or .["python.pythonPath"] then {extra: .["python.analysis.extraPaths"], path: .["python.pythonPath"]} else empty end' "$settings_file" > "$tmpfile"
        local extraPaths path
        extraPaths=$(jq -r '.extra' "$tmpfile" 2>/dev/null || echo "null")
        path=$(jq -r '.path' "$tmpfile" 2>/dev/null || echo "null")
        if [ -f "$workspace_file" ]; then
            local tmpfile2=$(mktemp)
            TMPFILES+=("$tmpfile2")
            jq --argjson extraPaths "$extraPaths" --arg pythonPath "$path" '
                .settings = (.settings // {})
                | if $extraPaths != null then .settings["python.analysis.extraPaths"] = $extraPaths else . end
                | if $pythonPath != null then .settings["python.pythonPath"] = $pythonPath else . end
            ' "$workspace_file" > "$tmpfile2" && mv "$tmpfile2" "$workspace_file"
        fi
    fi
}

# --- Idempotency for Odoo LS configs: avoid duplicates ---
# (Already handled in patch_odoo_ls_user_settings, but now also check for config object equality)
patch_odoo_ls_user_settings() {
    local user_settings_files=( $(get_user_settings_files) )
    local odoo_source_dir
    odoo_source_dir=$(get_odoo_source_dir "$CONFIG_FILE")
    python_path="${HOME}/odoo${ODOO_VERSION}-venv/bin/python"
    local config_name="Odoo $ODOO_VERSION"
    for user_settings_file in "${user_settings_files[@]}"; do
        [ ! -f "$user_settings_file" ] && mkdir -p "$(dirname "$user_settings_file")" && echo '{}' > "$user_settings_file"
        if [ -f "$user_settings_file" ]; then
            # Build the config object
            if [ ${#ADDON_PATHS[@]} -eq 0 ]; then
                addons_json='[]'
            else
                addons_json=$(printf '%s\n' "${ADDON_PATHS[@]}" | jq -R . | jq -s .)
            fi
            odoo_config_json=$(jq -n \
                --arg name "$config_name" \
                --arg rawOdooPath "$odoo_source_dir" \
                --arg odooPath "$odoo_source_dir" \
                --argjson addons "$addons_json" \
                --arg pythonPath "$python_path" \
                --arg odooEnv "$odoo_source_dir" \
                '{name: $name, rawOdooPath: $rawOdooPath, odooPath: $odooPath, addons: $addons, pythonPath: $pythonPath, env: {PYTHONPATH: $odooEnv}}' \
                | jq -c .)
            # Check for identical config
            existing_id=$(jq -r --argjson target "$odoo_config_json" '(."Odoo.configurations" // {}) | to_entries[] | select(.value.name == $target.name and .value.rawOdooPath == $target.rawOdooPath and .value.pythonPath == $target.pythonPath and (.value.addons|tostring) == ($target.addons|tostring)) | .key' "$user_settings_file" | head -n1)
            if [[ -n "$existing_id" && "$existing_id" =~ ^[0-9]+$ ]]; then
                # Update selected config only
                tmpfile=$(mktemp)
                TMPFILES+=("$tmpfile")
                jq --arg id "$existing_id" --arg pythonPath "$python_path" '
                    .["Odoo.selectedConfiguration"] = $id
                    | .["pythonPath"] = $pythonPath
                ' "$user_settings_file" > "$tmpfile" && mv "$tmpfile" "$user_settings_file"
            else
                # Find next available numeric key
                next_id=$(jq -r '((."Odoo.configurations" // {}) | keys | map(select(test("^\\d+$"))) | map(tonumber) | (max // -1) + 1)' "$user_settings_file")
                odoo_config_json=$(jq -n \
                    --argjson id "$next_id" \
                    --arg name "$config_name" \
                    --arg rawOdooPath "$odoo_source_dir" \
                    --arg odooPath "$odoo_source_dir" \
                    --argjson addons "$addons_json" \
                    --arg pythonPath "$python_path" \
                    --arg odooEnv "$odoo_source_dir" \
                    '{id: $id, name: $name, rawOdooPath: $rawOdooPath, odooPath: $odooPath, addons: $addons, pythonPath: $pythonPath, env: {PYTHONPATH: $odooEnv}}' \
                    | jq -c .)
                tmpfile=$(mktemp)
                TMPFILES+=("$tmpfile")
                jq --argjson id "$next_id" --argjson new_config "$odoo_config_json" --arg pythonPath "$python_path" '
                    .["Odoo.configurations"] = ((.["Odoo.configurations"] // {}) + {($id|tostring): $new_config})
                    | .["Odoo.selectedConfiguration"] = ($id|tostring)
                    | .["pythonPath"] = $pythonPath
                ' "$user_settings_file" > "$tmpfile" && mv "$tmpfile" "$user_settings_file"
            fi
        fi
    done
}

# Check if manifest exists for all modules
for MANIFEST_FILE in "${MANIFEST_FILES[@]}"; do
    if [ ! -f "$MANIFEST_FILE" ]; then
        echo "Error: __manifest__.py not found in $MODULE_PATH"
        exit 1
    fi
done

# Create or update workspace
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

# Add debug configuration
echo "Creating debug configuration..."
create_vscode_launch_config

# Add python.analysis.extraPaths for Odoo import resolution
echo "Configuring python.analysis.extraPaths for Odoo..."
create_vscode_settings
# Add python.pythonPath for Odoo LS compatibility
echo "Configuring python.pythonPath for Odoo Language Server compatibility..."
create_python_path_setting
# Add Odoo Language Server config
echo "Configuring Odoo Language Server extension..."
create_odoo_ls_settings
# Patch user settings for Odoo Language Server
patch_odoo_ls_user_settings

# Fix the final message
if [ -f "$WORKSPACE_FILE" ]; then
    STATUS="updated"
else
    STATUS="created"
fi

echo "
Workspace $STATUS successfully at: $WORKSPACE_FILE
To use:
1. Open Cursor
2. File -> Open Workspace from File...
3. Select ${PRIMARY_MODULE_NAME}.code-workspace

The workspace includes:
- Your current modules
- All dependencies found in __manifest__.py
- Python path configuration for code intelligence
- Debug configuration for the primary module (${PRIMARY_MODULE_NAME})

Debug configuration has been set up in .vscode/launch.json
You can start debugging by pressing F5 or using the Run and Debug panel.
"