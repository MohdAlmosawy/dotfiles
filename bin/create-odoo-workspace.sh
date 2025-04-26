#!/bin/bash
# create-odoo-workspace.sh

# Check if an argument was provided
if [ -z "$1" ]; then
    echo "Error: Please provide the module path"
    echo "Usage: create-odoo-workspace.sh <path-to-module>"
    echo "Example: create-odoo-workspace.sh ~/Desktop/live/stock_aged_report"
    exit 1
fi

# Define Odoo addon paths
ADDON_PATHS=(
    "/home/sayedmohamed/odoo16/addons"
    "/home/sayedmohamed/odoo16_modules"
    "/home/sayedmohamed/Desktop/live"
    "/home/sayedmohamed/Desktop/odoorepos/local/16"
)

# Get current module path and ensure it exists
MODULE_PATH=$(realpath "$1")
if [ ! -d "$MODULE_PATH" ]; then
    echo "Error: Directory does not exist: $MODULE_PATH"
    exit 1
fi

# Get module name from path
MODULE_NAME=$(basename "$MODULE_PATH")
WORKSPACE_FILE="${MODULE_PATH}/${MODULE_NAME}.code-workspace"
MANIFEST_FILE="${MODULE_PATH}/__manifest__.py"

# Debug output
echo "Debug info:"
echo "Module path: $MODULE_PATH"
echo "Module name: $MODULE_NAME"
echo "Manifest file: $MANIFEST_FILE"
echo "Workspace file: $WORKSPACE_FILE"

# Function to process workspace update
process_workspace_update() {
    local manifest_file="$1"
    local workspace_file="$2"
    
    # Create a temporary file
    local tmp_file=$(mktemp)
    
    # Convert ADDON_PATHS array to Python list string
    local addon_paths_str="["
    for path in "${ADDON_PATHS[@]}"; do
        addon_paths_str+="\"$path\", "
    done
    addon_paths_str="${addon_paths_str%, }]"  # Remove trailing comma and space
    
    # Use Python to handle the JSON manipulation
    python3 - <<EOF
import json
import sys
import os

# Read current dependencies from manifest
def get_manifest_deps():
    try:
        with open("$manifest_file", 'r') as f:
            import ast
            content = f.read()
            manifest = ast.literal_eval(content)
            return set(manifest.get('depends', []))
    except Exception as e:
        print(f"Error reading manifest: {e}", file=sys.stderr)
        return set()

# Read current workspace
def read_workspace():
    try:
        with open("$workspace_file", 'r') as f:
            return json.load(f)
    except Exception as e:
        print(f"Error reading workspace: {e}", file=sys.stderr)
        return None

# Find module path
def find_module_path(module_name):
    addon_paths = $addon_paths_str
    for path in addon_paths:
        if os.path.isdir(os.path.join(path, module_name)):
            return os.path.join(path, module_name)
    return None

# Main process
try:
    # Get current dependencies from manifest
    manifest_deps = get_manifest_deps()
    
    # Read current workspace
    workspace = read_workspace()
    if not workspace:
        print("Error: Could not read workspace file", file=sys.stderr)
        sys.exit(1)
    
    # Get current folders
    current_folders = workspace.get('folders', [])
    
    # Keep track of current module and non-dependency folders
    main_module = None
    other_folders = []
    existing_deps = set()
    
    # Separate current module, existing deps, and other folders
    for folder in current_folders:
        if folder.get('name', '').endswith('(Current)'):
            main_module = folder
        elif folder.get('name', '').startswith('📚'):
            # Extract module name from folder name
            dep_name = folder.get('name', '').replace('📚 ', '').strip()
            existing_deps.add(dep_name)
        else:
            other_folders.append(folder)
    
    # Initialize new folders list with main module
    new_folders = [main_module] if main_module else []
    
    # Add current dependencies
    deps_added = set()
    for dep in manifest_deps:
        module_path = find_module_path(dep)
        if module_path:
            new_folders.append({
                "path": module_path,
                "name": f"📚 {dep}"
            })
            deps_added.add(dep)
        else:
            print(f"Warning: Could not find path for dependency {dep}", file=sys.stderr)
    
    # Add other non-dependency folders back
    new_folders.extend(other_folders)
    
    # Update workspace with new folders
    workspace['folders'] = new_folders
    
    # Write updated workspace with proper formatting
    with open("$tmp_file", 'w') as f:
        json.dump(workspace, f, indent=4, ensure_ascii=False)
    
    # Print summary
    removed_deps = existing_deps - deps_added
    new_deps = deps_added - existing_deps
    
    if removed_deps:
        print("Removed dependencies:", ', '.join(removed_deps))
    if new_deps:
        print("Added dependencies:", ', '.join(new_deps))
    if not (removed_deps or new_deps):
        print("No changes in dependencies")
        
except Exception as e:
    print(f"Error updating workspace: {e}", file=sys.stderr)
    sys.exit(1)
EOF

    # If Python script succeeded, move temporary file to workspace file
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
    local module_name="$2"
    
    # Create a temporary file
    local tmp_file=$(mktemp)
    
    # Create the base workspace structure
    cat > "$tmp_file" << EOF
{
    "folders": [
        {
            "path": ".",
            "name": "📦 $module_name (Current)"
        }
    ],
    "settings": {
        "files.exclude": {
            "**/__pycache__": true,
            "**/*.pyc": true,
            "**/*.pyo": true,
            "**/*.pyd": true,
            "**/.Python": true,
            "**/.env": true,
            "**/.venv": true
        },
        "python.analysis.extraPaths": [
EOF

    # Add addon paths to Python path without trailing comma
    local last_index=$(( ${#ADDON_PATHS[@]} - 1 ))
    for i in "${!ADDON_PATHS[@]}"; do
        if [ $i -eq $last_index ]; then
            echo "            \"${ADDON_PATHS[$i]}\"" >> "$tmp_file"
        else
            echo "            \"${ADDON_PATHS[$i]}\"," >> "$tmp_file"
        fi
    done

    # Close the settings
    cat >> "$tmp_file" << EOF
        ],
        "python.analysis.diagnosticSeverityOverrides": {
            "reportMissingImports": "none"
        }
    }
}
EOF

    # Move the temporary file to the final workspace file
    mv "$tmp_file" "$workspace_file"
}

# Add this function after the create_new_workspace function and before the main script logic

create_vscode_launch_config() {
    local module_path="$1"
    local module_name="$2"
    
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
            "program": "/home/sayedmohamed/odoo16/odoo-bin",
            "args": [
                "-c", "/etc/odoo16.conf",
                "-d", "alsalamlocal",
                "-u", "${module_name}",
                "--dev", "xml"
            ],
            "env": {
                "ODOO_ENV": "dev",
                "VIRTUAL_ENV": "/home/sayedmohamed/odoo16-venv",
                "PATH": "/home/sayedmohamed/odoo16-venv/bin:\${env:PATH}"
            },
            "console": "integratedTerminal",
            "justMyCode": false,
            "python": "/home/sayedmohamed/odoo16-venv/bin/python"
        }
    ]
}
EOF
}

# Check if manifest exists
if [ ! -f "$MANIFEST_FILE" ]; then
    echo "Error: __manifest__.py not found in $MODULE_PATH"
    exit 1
fi

# Create or update workspace
if [ -f "$WORKSPACE_FILE" ]; then
    echo "Existing workspace found. Updating dependencies..."
    if process_workspace_update "$MANIFEST_FILE" "$WORKSPACE_FILE"; then
        echo "Workspace updated successfully"
    else
        echo "Error updating workspace"
        exit 1
    fi
else
    echo "Creating new workspace for $MODULE_NAME..."
    create_new_workspace "$WORKSPACE_FILE" "$MODULE_NAME"
    
    # Now update the workspace to add dependencies
    if process_workspace_update "$MANIFEST_FILE" "$WORKSPACE_FILE"; then
        echo "Workspace created and dependencies added successfully"
    else
        echo "Error adding dependencies to workspace"
        exit 1
    fi
fi

# Add this line to create the debug configuration
echo "Creating debug configuration..."
create_vscode_launch_config "$MODULE_PATH" "$MODULE_NAME"

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
3. Select ${MODULE_NAME}.code-workspace

The workspace includes:
- Your current module
- All dependencies found in __manifest__.py
- Python path configuration for code intelligence
- Debug configuration for the current module (${MODULE_NAME})

Debug configuration has been set up in .vscode/launch.json
You can start debugging by pressing F5 or using the Run and Debug panel.
"