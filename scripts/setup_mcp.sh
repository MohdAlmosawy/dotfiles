#!/usr/bin/env bash

# MCP Configuration Setup Script

set -euo pipefail

# --- Dependency checks ---
for cmd in git python3 pip jq; do
  command -v "$cmd" >/dev/null || { echo "ERROR: $cmd is required"; exit 1; }
done

# --- Robust template path ---
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
TEMPLATE_FILE="$SCRIPT_DIR/../templates/mcp.json.template"

# Determine which IDE configs to write:
# - DOTFILES_MCP_IDES can be a space- or comma-separated list, e.g. "cursor antigravity"
# - Defaults to "cursor" for backward compatibility
RAW_IDES="${DOTFILES_MCP_IDES:-cursor}"
MCP_IDES=()
CONFIG_FILES=()

IFS=', ' read -r -a MCP_IDES <<< "$RAW_IDES"

for ide in "${MCP_IDES[@]}"; do
  case "$ide" in
    cursor)
      CONFIG_FILES+=("$HOME/.cursor/mcp.json")
      ;;
    antigravity)
      # Antigravity expects mcp_config.json under its Gemini config directory
      CONFIG_FILES+=("$HOME/.gemini/antigravity/mcp_config.json")
      ;;
    vscode)
      # VS Code expects mcp.json in the User directory
      CONFIG_FILES+=("$HOME/.vscode/mcp.json")
      ;;
    "" )
      ;;
    * )
      echo "Warning: unknown IDE '$ide' in DOTFILES_MCP_IDES – skipping."
      ;;
  esac
done

if [ ${#CONFIG_FILES[@]} -eq 0 ]; then
  echo "No valid IDE targets specified in DOTFILES_MCP_IDES ('$RAW_IDES')."
  echo "Supported values: cursor, antigravity, vscode"
  exit 1
fi

# --- Atomic template existence check ---
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "Error: Template file $TEMPLATE_FILE not found!"
    echo "Expected templates/ directory to be one level up from this script."
    exit 1
fi

# --- Help/usage switch ---
if (( $# > 0 )) && [[ ${1:-} == "-h" || ${1:-} == "--help" ]]; then
  echo "\nUsage: $0\n\nThis script sets up MCP-Odoo and generates a config file.\n- Detects Odoo config and Python venv\n- Clones mcp-odoo repo\n- Installs dependencies\n- Prompts for all required config values\n- Writes ~/.cursor/mcp.json\n\nRun from any directory. Requires git, python3, pip, jq.\nTemplate directory is expected to be one level up from this script.\nOdoo config must be a standard .conf file.\n\nWARNING: Default Odoo credentials are 'admin'/'admin'. For security, use strong credentials!\n"
  exit 0
fi

# --- Error trapping for cleanup ---
TMP_CONFIG=""
trap 'echo "Aborting."; [[ -n "$TMP_CONFIG" && -f "$TMP_CONFIG" ]] && rm -f "$TMP_CONFIG"' ERR EXIT

# Ensure target config directories exist
for cfg in "${CONFIG_FILES[@]}"; do
  mkdir -p "$(dirname "$cfg")"
done

# --- Prompt user for which MCP tools to set up ---
SETUP_ODOO=false
SETUP_TASKMASTER=false

echo ""
echo "Which MCP tools would you like to set up?"
echo ""
read -rp "Set up Odoo MCP tool? [y/N]: " setup_odoo_choice
if [[ "$setup_odoo_choice" =~ ^[Yy]$ ]]; then
    SETUP_ODOO=true
fi

read -rp "Set up Taskmaster-AI MCP tool? [y/N]: " setup_taskmaster_choice
if [[ "$setup_taskmaster_choice" =~ ^[Yy]$ ]]; then
    SETUP_TASKMASTER=true
fi

if [ "$SETUP_ODOO" = false ] && [ "$SETUP_TASKMASTER" = false ]; then
    echo "No tools selected. Exiting."
    exit 1
fi

# --- Odoo config auto-detection and setup (only if Odoo is selected) ---
if [ "$SETUP_ODOO" = true ]; then
    echo ""
    echo "=== Setting up Odoo MCP tool ==="
    
    ODOO_CONFIG=""
    ODOO_CONFIGS=(/etc/odoo*.conf)
    if [ ${#ODOO_CONFIGS[@]} -eq 1 ] && [ -f "${ODOO_CONFIGS[0]}" ]; then
        ODOO_CONFIG="${ODOO_CONFIGS[0]}"
        echo "  • Using detected Odoo config: $ODOO_CONFIG"
    else
        echo "Multiple or no Odoo config files found."
        read -rp "Enter path to your Odoo config file (e.g. /etc/odoo16.conf): " ODOO_CONFIG
        while [ ! -f "$ODOO_CONFIG" ]; do
            echo "  • File not found: $ODOO_CONFIG"
            read -rp "Enter a valid Odoo config file path: " ODOO_CONFIG
        done
    fi

    # --- Parse Odoo config ---
    get_config_value() {
        local key="$1"
        grep -E "^\s*$key\s*=" "$ODOO_CONFIG" | grep -v '^\s*#' | head -n1 | cut -d'=' -f2- | xargs || true
    }

    ODOO_DB=$(get_config_value db_name)
    if [ -z "$ODOO_DB" ]; then
        read -rp "Enter Odoo database name: " input_db
        while [ -z "$input_db" ]; do
            echo "  • Database name cannot be empty."
            read -rp "Enter Odoo database name: " input_db
        done
        ODOO_DB="$input_db"
    else
        echo "  • Detected Odoo DB: $ODOO_DB"
    fi

    XMLRPC_PORT=$(get_config_value xmlrpc_port)
    if [ -z "$XMLRPC_PORT" ]; then
        read -rp "Enter Odoo XMLRPC Port (default 8069): " input_port
        if [ -z "$input_port" ]; then
            XMLRPC_PORT=8069
        else
            XMLRPC_PORT="$input_port"
        fi
        echo "  • Using XMLRPC Port: $XMLRPC_PORT"
    else
        echo "  • Detected XMLRPC Port: $XMLRPC_PORT"
    fi

    # --- Odoo URL setup (allow override) ---
    ODOO_URL="http://localhost:$XMLRPC_PORT/"
    if [ -z "$ODOO_URL" ]; then
        read -rp "Enter Odoo URL (e.g. http://localhost:8069/) [http://localhost:$XMLRPC_PORT/]: " input_url
        if [ -z "$input_url" ]; then
            ODOO_URL="http://localhost:$XMLRPC_PORT/"
        else
            ODOO_URL="$input_url"
        fi
    else
        echo "  • Using Odoo URL: $ODOO_URL"
    fi

    # --- Python virtualenv auto-detection ---
    VENV_CANDIDATES=(~/odoo*-venv)
    VENV_FOUND=()
    for v in "${VENV_CANDIDATES[@]}"; do
        if [ -d "${v/#\~/$HOME}" ]; then
            VENV_FOUND+=("${v/#\~/$HOME}")
        fi
    done

    if [ ${#VENV_FOUND[@]} -eq 1 ]; then
        VIRTUAL_ENV="${VENV_FOUND[0]}"
        echo "  • Using detected virtualenv: $VIRTUAL_ENV"
    else
        if [ ${#VENV_FOUND[@]} -gt 1 ]; then
            echo "Multiple virtualenvs found:"
            for v in "${VENV_FOUND[@]}"; do
                echo "   - $v"
            done
        else
            echo "No Odoo virtualenv found."
        fi
        read -rp "Enter path to your Odoo virtualenv (e.g. ~/odoo16-venv): " input_venv
        while [ ! -d "${input_venv/#\~/$HOME}" ]; do
            echo "  • Directory not found: $input_venv"
            read -rp "Enter a valid Odoo virtualenv path: " input_venv
        done
        VIRTUAL_ENV="${input_venv/#\~/$HOME}"
    fi
    if [ -z "$VIRTUAL_ENV" ]; then
        read -rp "Enter path to your Odoo virtualenv: " input_venv2
        while [ -z "$input_venv2" ]; do
            echo "  • Virtualenv path cannot be empty."
            read -rp "Enter path to your Odoo virtualenv: " input_venv2
        done
        VIRTUAL_ENV="$input_venv2"
    fi

    # mcp-odoo uses a src/ layout, so include src explicitly.
    PY_SITE_PACKAGES=$("$VIRTUAL_ENV/bin/python3" -c "import sysconfig; print(sysconfig.get_paths().get('purelib', ''))" 2>/dev/null || true)
    if [ -z "$PY_SITE_PACKAGES" ]; then
        echo "Error: could not detect site-packages path for $VIRTUAL_ENV"
        exit 1
    fi
    PYTHONPATH="$HOME/mcp-odoo/src:$PY_SITE_PACKAGES"
    PATH_VAL="$VIRTUAL_ENV/bin:$PATH"

    # --- MCP-Odoo setup ---
    if [ -n "$VIRTUAL_ENV" ]; then
        echo "Activating Odoo virtual environment: $VIRTUAL_ENV"
        # shellcheck disable=SC1090
        source "$VIRTUAL_ENV/bin/activate"
    else
        echo "Error: VIRTUAL_ENV is not set. Cannot activate virtual environment."
        exit 1
    fi

    MCP_ODOO_DIR="$HOME/mcp-odoo"
    if [ ! -d "$MCP_ODOO_DIR" ]; then
        echo "Cloning mcp-odoo repository into $MCP_ODOO_DIR"
        git clone https://github.com/tuanle96/mcp-odoo.git "$MCP_ODOO_DIR"
        if [ $? -ne 0 ]; then echo "git clone failed"; exit 1; fi
    else
        echo "mcp-odoo repository already exists at $MCP_ODOO_DIR"
    fi

    # Ensure modern MCP package that provides mcp.server.fastmcp.
    MCP_PIP_SPEC="${MCP_PIP_SPEC:-mcp>=1.24.0}"
    NEED_MCP_PIN_INSTALL=0
    if ! pip show mcp &>/dev/null; then
        NEED_MCP_PIN_INSTALL=1
    else
        MCP_MAJOR_VERSION=$(python3 -c "import importlib.metadata as md; print(md.version('mcp').split('.')[0])" 2>/dev/null || echo "0")
        if [ "$MCP_MAJOR_VERSION" -lt 1 ]; then
            echo "Installed mcp major version is $MCP_MAJOR_VERSION; enforcing $MCP_PIP_SPEC for compatibility."
            NEED_MCP_PIN_INSTALL=1
        else
            echo "Base mcp package already installed and compatible."
        fi
    fi
    if [ "$NEED_MCP_PIN_INSTALL" -eq 1 ]; then
        echo "Installing base mcp package ($MCP_PIP_SPEC)..."
        command pip install --upgrade --force-reinstall "$MCP_PIP_SPEC"
        if [ $? -ne 0 ]; then echo "pip install mcp failed"; exit 1; fi
    fi

    cd "$MCP_ODOO_DIR"
    echo "Installing odoo-mcp in editable mode..."
    command pip install -e .
    if [ $? -ne 0 ]; then echo "pip install -e . failed"; exit 1; fi

    ODOO_MCP_PATH=$(command -v odoo-mcp || true)
    if [ -n "$ODOO_MCP_PATH" ]; then
        echo "odoo-mcp script found at: $ODOO_MCP_PATH"
    else
        echo "Warning: odoo-mcp script not found in PATH."
    fi

    echo "Inspecting odoo-mcp pip metadata:"
    command pip show odoo-mcp || echo "odoo-mcp package not found."

    echo "Testing odoo-mcp CLI:"
    # Suppress stderr since odoo-mcp will fail without config (expected at this stage)
    odoo-mcp --help 2>/dev/null || echo "odoo-mcp CLI test failed (expected - config not set yet)."

    cd - > /dev/null

    # --- Prompt for Odoo credentials ---
    read -rp "Odoo admin username [admin]: " ODOO_USERNAME
    ODOO_USERNAME=${ODOO_USERNAME:-admin}
    read -rsp "Odoo admin password [admin]: " ODOO_PASSWORD
    ODOO_PASSWORD=${ODOO_PASSWORD:-admin}
    echo
fi

# --- MCP Configuration ---
# Start with empty config structure
template_config='{"mcpServers":{}}'

# --- Process Odoo configuration (if selected) ---
if [ "$SETUP_ODOO" = true ]; then
    echo ""
    echo "=== Configuring Odoo MCP ==="
    
    # Read Odoo server config from template
    odoo_template=$(cat "$TEMPLATE_FILE" | jq '.mcpServers.odoo')
    
    # Fill in dynamic values for Odoo
    odoo_config=$(echo "$odoo_template" | jq --arg url "$ODOO_URL" \
        --arg db "$ODOO_DB" \
        --arg username "$ODOO_USERNAME" \
        --arg password "$ODOO_PASSWORD" \
        --arg venv "$VIRTUAL_ENV" \
        --arg pythonpath "$PYTHONPATH" \
        --arg path "$PATH_VAL" \
        '.env.ODOO_URL = $url |
         .env.ODOO_DB = $db |
         .env.ODOO_USERNAME = $username |
         .env.ODOO_PASSWORD = $password |
         .env.VIRTUAL_ENV = $venv |
         .env.PYTHONPATH = $pythonpath |
         .env.PATH = $path |
         .command = ($venv + "/bin/python3")')
    
    # Add Odoo server to config
    template_config=$(echo "$template_config" | jq ".mcpServers.odoo = $odoo_config")
fi

# --- Process Taskmaster-AI configuration (if selected) ---
if [ "$SETUP_TASKMASTER" = true ]; then
    echo ""
    echo "=== Configuring Taskmaster-AI MCP ==="
    
    # Read Taskmaster-AI server config from template
    taskmaster_template=$(cat "$TEMPLATE_FILE" | jq '.mcpServers."taskmaster-ai"')
    
    # Prompt user for Taskmaster-AI API keys (allow both)
    echo "Taskmaster-AI API Key setup:"
    read -rp "Do you want to enter an ANTHROPIC_API_KEY? [y/N]: " enter_anthropic
    ANTHROPIC_API_KEY=""
    if [[ "$enter_anthropic" =~ ^[Yy]$ ]]; then
        read -rp "Enter ANTHROPIC_API_KEY: " ANTHROPIC_API_KEY
    fi
    
    read -rp "Do you want to enter a PERPLEXITY_API_KEY? [y/N]: " enter_perplexity
    PERPLEXITY_API_KEY=""
    if [[ "$enter_perplexity" =~ ^[Yy]$ ]]; then
        read -rp "Enter PERPLEXITY_API_KEY: " PERPLEXITY_API_KEY
    fi
    
    # Fill in API keys (keep placeholder if not provided)
    taskmaster_config=$(echo "$taskmaster_template" | jq --arg anthropic "$ANTHROPIC_API_KEY" \
        --arg perplexity "$PERPLEXITY_API_KEY" \
        'if $anthropic != "" then .env.ANTHROPIC_API_KEY = $anthropic else . end |
         if $perplexity != "" then .env.PERPLEXITY_API_KEY = $perplexity else . end')
    
    # Add Taskmaster-AI server to config
    template_config=$(echo "$template_config" | jq '.mcpServers."taskmaster-ai" = $taskmaster_config' --argjson taskmaster_config "$taskmaster_config")
fi

# Save the final configuration safely to all selected IDE config files
TMP_CONFIG=$(mktemp)
echo "$template_config" > "$TMP_CONFIG"
if ! jq empty "$TMP_CONFIG"; then
    echo "ERROR: generated JSON is invalid"
    rm -f "$TMP_CONFIG"
    exit 1
fi
chmod 600 "$TMP_CONFIG"

for CONFIG_FILE in "${CONFIG_FILES[@]}"; do
    if [ -f "$CONFIG_FILE" ]; then
        backup="$CONFIG_FILE.bak.$(date +%s)"
        cp "$CONFIG_FILE" "$backup"
        echo "Backed up old config for $CONFIG_FILE to $backup"
    fi
    cp "$TMP_CONFIG" "$CONFIG_FILE"
    echo "Wrote MCP config to $CONFIG_FILE"
done

rm -f "$TMP_CONFIG"
trap - ERR EXIT

# Explicit exit on success
exit 0