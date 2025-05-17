#!/bin/bash

# MCP Configuration Setup Script

set -euo pipefail

# Ensure .cursor directory exists
mkdir -p ~/.cursor

# Path to MCP config files
TEMPLATE_FILE="templates/mcp.json.template"
CONFIG_FILE=~/.cursor/mcp.json

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
    ODOO_DB="odoo16"
    read -rp "Press Enter to use default Odoo DB ($ODOO_DB) or type a different DB name: " input_db
    if [ -n "$input_db" ]; then
        ODOO_DB="$input_db"
    fi
else
    echo "  • Detected Odoo DB: $ODOO_DB"
fi

XMLRPC_PORT=$(get_config_value xmlrpc_port)
if [ -z "$XMLRPC_PORT" ]; then
    XMLRPC_PORT=8069
    echo "  • Using default XMLRPC Port: $XMLRPC_PORT"
else
    echo "  • Detected XMLRPC Port: $XMLRPC_PORT"
fi

ODOO_URL="http://localhost:$XMLRPC_PORT/"
VIRTUAL_ENV="$HOME/odoo16-venv"
read -rp "Press Enter to use default VIRTUAL_ENV ($VIRTUAL_ENV) or type a different path: " input_venv
if [ -n "$input_venv" ]; then
    VIRTUAL_ENV="$input_venv"
fi
PYTHONPATH="$HOME/mcp-odoo:$VIRTUAL_ENV/lib/python3.12/site-packages"
PATH_VAL="$VIRTUAL_ENV/bin:$PATH"

# Function to prompt for a value if it's missing or a placeholder
prompt_for_value() {
    local key=$1
    local current_value=$2
    local prompt_message=$3
    
    if [[ -z "$current_value" || "$current_value" == *"<"* ]]; then
        read -p "$prompt_message: " value
        echo "$value"
    else
        echo "$current_value"
    fi
}

# Check if template exists
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "Error: Template file $TEMPLATE_FILE not found!"
    exit 1
fi

# Read template
template_config=$(cat "$TEMPLATE_FILE")

# Fill in dynamic values
for pair in \
    "<ODOO_URL>:$ODOO_URL" \
    "<ODOO_DB>:$ODOO_DB" \
    "<VIRTUAL_ENV>:$VIRTUAL_ENV" \
    "<PYTHONPATH>:$PYTHONPATH" \
    "<PATH>:$PATH_VAL"
    do
    placeholder="${pair%%:*}"
    value="${pair#*:}"
    template_config=$(echo "$template_config" | sed "s|$placeholder|$value|g")
done

# Process each server in the config
for server in $(echo "$template_config" | jq -r '.mcpServers | keys[]'); do
    echo "Processing server: $server"
    
    # Get server config
    server_config=$(echo "$template_config" | jq ".mcpServers.\"$server\"")
    
    # Process environment variables
    for env_var in $(echo "$server_config" | jq -r '.env | keys[]'); do
        value=$(echo "$server_config" | jq -r ".env.\"$env_var\"")
        
        # Check if value is a placeholder
        if [[ "$value" == *"<"* ]]; then
            # Prompt for value
            new_value=$(prompt_for_value "$env_var" "$value" "Enter value for $server/$env_var")
            
            # Update template
            template_config=$(echo "$template_config" | jq ".mcpServers.\"$server\".env.\"$env_var\" = \"$new_value\"")
        fi
    done
done

# Save the final configuration
echo "$template_config" > "$CONFIG_FILE"

echo "MCP configuration has been updated at $CONFIG_FILE" 