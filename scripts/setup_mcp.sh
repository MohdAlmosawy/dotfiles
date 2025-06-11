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
CONFIG_FILE="$HOME/.cursor/mcp.json"

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

# Ensure .cursor directory exists
mkdir -p ~/.cursor

# --- Odoo config auto-detection ---
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

PYTHONPATH="$HOME/mcp-odoo:$VIRTUAL_ENV/lib/python3.12/site-packages"
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

if ! pip show mcp &>/dev/null; then
    echo "Installing base mcp package..."
    command pip install mcp
    if [ $? -ne 0 ]; then echo "pip install mcp failed"; exit 1; fi
else
    echo "Base mcp package already installed."
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
odoo-mcp --help || echo "odoo-mcp CLI test failed."

cd - > /dev/null

# --- Prompt for Odoo credentials ---
read -rp "Odoo admin username [admin]: " ODOO_USERNAME
ODOO_USERNAME=${ODOO_USERNAME:-admin}
read -rsp "Odoo admin password [admin]: " ODOO_PASSWORD
ODOO_PASSWORD=${ODOO_PASSWORD:-admin}
echo

# --- prompt_for_value helper ---
prompt_for_value() {
    local key="$1"
    local current_value="$2"
    local prompt_message="$3"
    local value
    if [[ -z "$current_value" || "$current_value" == *"<"* ]]; then
        while true; do
            read -rp "$prompt_message [required]: " value
            if [ -n "$value" ]; then
                echo "$value"
                return
            fi
            echo "  • Value cannot be empty."
        done
    else
        echo "$current_value"
    fi
}

# --- MCP Configuration ---
# Read template
template_config=$(cat "$TEMPLATE_FILE")

# Fill in dynamic values
for pair in \
    "<ODOO_URL>:$ODOO_URL" \
    "<ODOO_DB>:$ODOO_DB" \
    "<VIRTUAL_ENV>:$VIRTUAL_ENV" \
    "<PYTHONPATH>:$PYTHONPATH" \
    "<PATH>:$PATH_VAL" \
    "<ODOO_USERNAME>:$ODOO_USERNAME" \
    "<ODOO_PASSWORD>:$ODOO_PASSWORD" \
    ; do
    placeholder="${pair%%:*}"
    value="${pair#*:}"
    template_config=$(echo "$template_config" | sed "s|$placeholder|$value|g")
done

# Process each server in the config (robust to spaces)
jq -r '.mcpServers | keys[]' <<<"$template_config" | while read -r server; do
    echo "Processing server: $server"
    server_config=$(echo "$template_config" | jq ".mcpServers.\"$server\"")
    jq -r '.env | keys[]' <<<"$server_config" | while read -r env_var; do
        value=$(echo "$server_config" | jq -r ".env.\"$env_var\"")
        if [[ "$value" == *"<"* ]]; then
            new_value=$(prompt_for_value "$env_var" "$value" "Enter value for $server/$env_var")
            template_config=$(echo "$template_config" | jq ".mcpServers.\"$server\".env.\"$env_var\" = \"$new_value\"")
        fi
    done
done

# Prompt user for Taskmaster-AI API keys (allow both)
echo "\nTaskmaster-AI API Key setup:"
read -rp "Do you want to enter an ANTHROPIC_API_KEY? [y/N]: " enter_anthropic
if [[ "$enter_anthropic" =~ ^[Yy]$ ]]; then
    read -rp "Enter ANTHROPIC_API_KEY: " ANTHROPIC_API_KEY
    if [ -n "$ANTHROPIC_API_KEY" ]; then
        template_config=$(echo "$template_config" | jq ".mcpServers.\"taskmaster-ai\".env.ANTHROPIC_API_KEY = \"$ANTHROPIC_API_KEY\"")
    fi
fi
read -rp "Do you want to enter a PERPLEXITY_API_KEY? [y/N]: " enter_perplexity
if [[ "$enter_perplexity" =~ ^[Yy]$ ]]; then
    read -rp "Enter PERPLEXITY_API_KEY: " PERPLEXITY_API_KEY
    if [ -n "$PERPLEXITY_API_KEY" ]; then
        template_config=$(echo "$template_config" | jq ".mcpServers.\"taskmaster-ai\".env.PERPLEXITY_API_KEY = \"$PERPLEXITY_API_KEY\"")
    fi
fi

# Save the final configuration safely
if [ -f "$CONFIG_FILE" ]; then
    backup="$CONFIG_FILE.bak.$(date +%s)"
    cp "$CONFIG_FILE" "$backup"
    echo "Backed up old config to $backup"
fi
TMP_CONFIG=$(mktemp)
echo "$template_config" > "$TMP_CONFIG"
if ! jq empty "$TMP_CONFIG"; then
    echo "ERROR: generated JSON is invalid"
    rm -f "$TMP_CONFIG"
    exit 1
fi
chmod 600 "$TMP_CONFIG"
mv "$TMP_CONFIG" "$CONFIG_FILE"
trap - ERR EXIT

# Explicit exit on success
exit 0