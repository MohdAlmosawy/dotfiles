#!/usr/bin/env bash
set -euo pipefail

# Figure out where we live
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "→ dotfiles directory: $DOTFILES_DIR"

load_module() {
  local name="$1"
  # shellcheck source=/dev/null
  source "$DOTFILES_DIR/modules/${name}.sh"
}

# Load common utilities first, then feature-specific modules.
load_module common
load_module git
load_module path_and_bin
load_module editors
load_module antigravity
load_module mcp
load_module skills
load_module odoo

# Explicit orchestration order, mirroring the original setup steps.
SETUP_SEQUENCE=(
  git_setup_run
  git_global_link_run
  path_and_bin_run
  cursor_maybe_install_run
  antigravity_maybe_install_run
  mcp_setup_run
  skills_setup_run
  refresh_path_run
  odoo_setup_run
)

current_step=""
trap 'echo "✖ setup failed during: ${current_step:-unknown step}" >&2' ERR

for step in "${SETUP_SEQUENCE[@]}"; do
  current_step="$step"
  "$step"
done

echo "${GREEN}✔ setup completed successfully.${RESET}"


