#!/usr/bin/env bash
set -euo pipefail

# modules/mcp.sh
#
# PUBLIC:
#   mcp_setup_run
#
# ENV VARS USED:
#   DOTFILES_NONINTERACTIVE
#   SETUP_MCP
#   SETUP_MCP_IDES
#   DOTFILES_DIR
#
# SIDE EFFECTS:
#   May run scripts/setup_mcp.sh with DOTFILES_MCP_IDES set

mcp_setup_run() {
  if [[ "${DOTFILES_NONINTERACTIVE:-0}" == "1" ]]; then
    # Non-interactive: allow specifying IDE targets via SETUP_MCP_IDES (space/comma separated)
    # e.g. SETUP_MCP=1 SETUP_MCP_IDES="vscode antigravity"
    if [[ "${SETUP_MCP:-0}" == "1" ]]; then
      DOTFILES_MCP_IDES="${SETUP_MCP_IDES:-vscode}" "$DOTFILES_DIR/scripts/setup_mcp.sh"
    else
      echo "Skipping MCP config (non-interactive)."
    fi
  else
    read -rp "Do you want to set up MCP config now? [y/N]: " setup_mcp || true
    if [[ "$setup_mcp" =~ ^[Yy]$ ]]; then
      echo "Which IDE(s) should MCP be configured for?"
      echo "  1) VS Code user-level"
      echo "  2) Cursor"
      echo "  3) Antigravity"
      echo "  4) All"
      read -rp "Enter choice [1/2/3/4, default 1]: " mcp_choice || true
      mcp_choice="${mcp_choice:-1}"

      local DOTFILES_MCP_IDES
      case "$mcp_choice" in
        1) DOTFILES_MCP_IDES="vscode" ;;
        2) DOTFILES_MCP_IDES="cursor" ;;
        3) DOTFILES_MCP_IDES="antigravity" ;;
        4) DOTFILES_MCP_IDES="vscode cursor antigravity" ;;
        *) echo "Unrecognized choice '$mcp_choice', defaulting to VS Code user-level only."; DOTFILES_MCP_IDES="vscode" ;;
      esac

      DOTFILES_MCP_IDES="$DOTFILES_MCP_IDES" "$DOTFILES_DIR/scripts/setup_mcp.sh"
    else
      echo "Skipping MCP config setup. You can run scripts/setup_mcp.sh later."
    fi
  fi
}


