#!/bin/bash
# create-odoo-workspace.sh

# Update argument check to allow multiple module paths
if [ "$#" -lt 1 ]; then
    echo "Error: Please provide at least one module path"
    echo "Usage: create-odoo-workspace.sh <path-to-module1> [<path-to-module2> ...] [odoo-version|config-path]"
    exit 1
fi

# Extract Odoo version/config argument if present (last argument if not a directory)
LAST_ARG="${!#}"
if [[ "$LAST_ARG" =~ ^/ || "$LAST_ARG" =~ ^[0-9]+$ ]]; then
    ODOO_ARG="$LAST_ARG"
    MODULE_PATHS=("${@:1:$(($#-1))}")
else
    ODOO_ARG=""
    MODULE_PATHS=("$@")
fi

# Validate all module paths
for MODULE_PATH in "${MODULE_PATHS[@]}"; do
    MODULE_PATH=$(realpath "$MODULE_PATH")
    if [ ! -d "$MODULE_PATH" ]; then
        echo "Error: Directory does not exist: $MODULE_PATH"
        exit 1
    fi
    MODULE_PATHS_ABS+=("$MODULE_PATH")
done

# Use first module as primary for workspace/manifest/debug
PRIMARY_MODULE_PATH="${MODULE_PATHS_ABS[0]}"
PRIMARY_MODULE_NAME=$(basename "$PRIMARY_MODULE_PATH")
WORKSPACE_FILE="${PRIMARY_MODULE_PATH}/${PRIMARY_MODULE_NAME}.code-workspace"

# Determine Odoo version or config path
if [ -n "$ODOO_ARG" ]; then
    if [[ "$ODOO_ARG" =~ ^/ ]]; then
        CONFIG_FILE="$ODOO_ARG"
        if [ ! -f "$CONFIG_FILE" ]; then
            echo "Error: Specified config file does not exist: $CONFIG_FILE"
            exit 1
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
        echo "Error: Multiple or no Odoo config files found. Please specify the Odoo version or config path."
        exit 1
    fi
fi

# Dynamically load Odoo addon paths from the config file
if [ -f "$CONFIG_FILE" ]; then
    addons_line=$(grep -E '^\s*addons_path\s*=' "$CONFIG_FILE")
    if [ -n "$addons_line" ]; then
        addon_paths_list=$(echo "$addons_line" | cut -d'=' -f2)
        IFS=',' read -r -a ADDON_PATHS <<< "$addon_paths_list"
        for i in "${!ADDON_PATHS[@]}"; do
            ADDON_PATHS[$i]=$(echo "${ADDON_PATHS[$i]}" | xargs)
        done
    else
        echo "Error: addons_path not found in $CONFIG_FILE" >&2
        exit 1
    fi
else
    echo "Error: config file $CONFIG_FILE not found" >&2
    exit 1
fi

# Collect all module names and manifest files
MODULE_NAMES=()
MANIFEST_FILES=()
for MODULE_PATH in "${MODULE_PATHS_ABS[@]}"; do
    MODULE_NAME=$(basename "$MODULE_PATH")
    MODULE_NAMES+=("$MODULE_NAME")
    MANIFEST_FILES+=("${MODULE_PATH}/__manifest__.py")
done

# Function to process workspace update
process_workspace_update() {
    local manifest_files=("$@")
    local workspace_file="$WORKSPACE_FILE"
    local tmp_file=$(mktemp)
    local addon_paths_str="["
    for path in "${ADDON_PATHS[@]}"; do
        addon_paths_str+="\"$path\", "
    done
    addon_paths_str="${addon_paths_str%, }]"
    local manifest_files_pylist=$(printf "'%s', " "${manifest_files[@]}")
    manifest_files_pylist="[${manifest_files_pylist%, }]"
    local module_names_pylist=$(printf "'%s', " "${MODULE_NAMES[@]}")
    module_names_pylist="[${module_names_pylist%, }]"
    local module_paths_pylist=$(printf "'%s', " "${MODULE_PATHS_ABS[@]}")
    module_paths_pylist="[${module_paths_pylist%, }]"
    python3 - <<EOF
import json
import sys
import os

manifest_files = $manifest_files_pylist
module_names = $module_names_pylist
module_paths = $module_paths_pylist

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
    for path in addon_paths:
        if os.path.isdir(os.path.join(path, module_name)):
            return os.path.join(path, module_name)
    return None

try:
    manifest_deps = get_manifest_deps(manifest_files)
    # Remove main modules from deps
    manifest_deps = set(manifest_deps) - set(module_names)
    workspace = read_workspace()
    if not workspace:
        print("Error: Could not read workspace file", file=sys.stderr)
        sys.exit(1)
    current_folders = workspace.get('folders', [])
    # Remove all existing 📦 and 📚 folders
    other_folders = [f for f in current_folders if not (f.get('name', '').endswith('(Current)') or f.get('name', '').startswith('📚'))]
    # Add all main modules as (Current)
    new_folders = []
    for i, module_path in enumerate(module_paths):
        module_name = module_names[i]
        new_folders.append({
            "path": module_path,
            "name": f"📦 {module_name} (Current)"
        })
    # Add dependencies
    for dep in manifest_deps:
        module_path = find_module_path(dep)
        if module_path:
            new_folders.append({
                "path": module_path,
                "name": f"📚 {dep}"
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
    if [ $? -eq 0 ]; then
        mv "$tmp_file" "$WORKSPACE_FILE"
        return 0
    else
        rm -f "$tmp_file"
        return 1
    fi
}

# Function to create a new workspace file
create_new_workspace() {
    local workspace_file="$1"
    shift
    local module_names=("$@")
    local tmp_file=$(mktemp)
    echo '{ "folders": [' > "$tmp_file"
    for i in "${!MODULE_PATHS_ABS[@]}"; do
        local comma=","
        [ $i -eq $((${#MODULE_PATHS_ABS[@]}-1)) ] && comma=""
        echo "    { \"path\": \"${MODULE_PATHS_ABS[$i]}\", \"name\": \"📦 ${MODULE_NAMES[$i]} (Current)\" }$comma" >> "$tmp_file"
    done
    echo '], "settings": {} }' >> "$tmp_file"
    mv "$tmp_file" "$workspace_file"
}

create_vscode_launch_config() {
    local module_path="$PRIMARY_MODULE_PATH"
    local module_name="$PRIMARY_MODULE_NAME"
    local config_file="$CONFIG_FILE"

    # Extract base directory from the first addons_path entry
    local base_dir=$(grep -E '^\s*addons_path\s*=' "$config_file" | cut -d'=' -f2 | cut -d',' -f1 | xargs | sed 's|/addons||')
    local program_path="${base_dir}/odoo-bin"

    # Extract database name and XML-RPC port from the config file
    local db_name="odoo${ODOO_VERSION}demodata"
    local xmlrpc_port=$(grep -E '^\s*xmlrpc_port\s*=' "$config_file" | cut -d'=' -f2 | xargs)

    # Create .vscode directory if it doesn't exist
    mkdir -p "${module_path}/.vscode"

    # Build log-handler argument using Python for robust parsing
    local main_modules_pylist=$(printf "%s\\n" "${MODULE_NAMES[@]}" | python3 -c "import sys; print(list(sys.stdin.read().splitlines()))")
    local manifest_files_pylist=$(printf "%s\\n" "${MANIFEST_FILES[@]}" | python3 -c "import sys; print(list(sys.stdin.read().splitlines()))")
    local log_handler_arg=$(python3 - <<EOF
import ast
import sys
import os
main_modules = $main_modules_pylist
manifest_files = $manifest_files_pylist

def get_deps(files, main_modules):
    deps = set()
    for mf in files:
        try:
            with open(mf, 'r') as f:
                manifest = ast.literal_eval(f.read())
                for dep in manifest.get('depends', []):
                    if dep not in main_modules:
                        deps.add(dep)
        except Exception as e:
            print(f"Error reading {mf}: {e}", file=sys.stderr)
    return deps

deps = get_deps(manifest_files, main_modules)
parts = [f"odoo.addons.{m}:DEBUG" for m in main_modules]
parts += [f"odoo.addons.{d}:INFO" for d in sorted(deps)]
parts += ["odoo.service.server:DEBUG", "odoo:INFO"]
print(f"--log-handler={','.join(parts)}")
EOF
)

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
                "${log_handler_arg}"
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