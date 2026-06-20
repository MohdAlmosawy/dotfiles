#!/usr/bin/env bash
set -euo pipefail

# modules/common.sh
#
# PUBLIC:
#   die
#   safe_backup
#   safe_symlink
#   link
#   add_to_shell_rc
#   source_shell_rc
#   ensure_linux
#   ensure_debian
#   ensure_sudo
#   ensure_curl
#   is_dryrun
#
# ENV VARS USED:
#   DOTFILES_DIR
#   DOTFILES_NONINTERACTIVE
#   SETUP_GIT
#   SETUP_MCP
#   SETUP_MCP_IDES
#   SETUP_SKILLS
#   INSTALL_VSCODE
#   INSTALL_CURSOR
#   INSTALL_ANTIGRAVITY
#   CURSOR_INSTALL_FORCE
#   DOTFILES_DRYRUN
#
# SIDE EFFECTS:
#   May append PATH exports to shell rc files when add_to_shell_rc is used.

# Color codes for better UX
GREEN=$'\033[32m'
RED=$'\033[31m'
RESET=$'\033[0m'

die() {
  echo "[ERROR] $*" >&2
  exit 1
}

# Idempotent backup: only backs up regular files (not symlinks), with timestamp suffix.
safe_backup() {
  local file=$1
  if [ -f "$file" ] && [ ! -L "$file" ]; then
    local ts
    ts=$(date +%s)
    echo "  • backing up $file → $file.bak.$ts"
    mv "$file" "$file.bak.$ts"
  fi
}

# Safer symlink helper built on top of safe_backup.
safe_symlink() {
  local src=$1 dst=$2
  mkdir -p "$(dirname "$dst")"
  safe_backup "$dst"
  ln -sfn "$src" "$dst"
  echo "  → linked $src → $dst"
}

# Backwards-compatible wrapper for legacy link() calls.
link() {
  safe_symlink "$1" "$2"
}

# Ensure ~/bin is on PATH in the given shell rc file.
add_to_shell_rc() {
  local rc="$1"
  local line='export PATH="$HOME/bin:$PATH"'
  if [ -f "$HOME/$rc" ] && grep -qxF "$line" "$HOME/$rc"; then
    return
  fi
  {
    echo
    echo "# add ~/bin to PATH"
    echo "$line"
  } >> "$HOME/$rc"
  echo "  • added PATH line to ~/$rc"
}

# Source the appropriate RC file for the current shell session.
source_shell_rc() {
  local current_shell rc_file
  current_shell="$(basename "${SHELL:-bash}")"
  rc_file=".$current_shell"rc

  if [ -f "$HOME/$rc_file" ]; then
    echo "→ Sourcing $rc_file..."
    if [ "$current_shell" = "zsh" ]; then
      # For zsh, extract PATH changes without executing the whole profile.
      # Source in a subshell, capture PATH, then export it to current shell.
      local new_path
      new_path=$(zsh -c "source '$HOME/$rc_file' >/dev/null 2>&1; echo -n \"\$PATH\"" 2>/dev/null)
      if [ -n "$new_path" ]; then
        export PATH="$new_path"
      else
        # Fallback: ensure ~/bin is at least added if not already present
        if [[ ":$PATH:" != *":$HOME/bin:"* ]]; then
          export PATH="$HOME/bin:$PATH"
        fi
      fi
    else
      # shellcheck source=/dev/null
      # We intentionally source here to refresh PATH for the current shell.
      source "$HOME/$rc_file"
    fi
  fi
}

# OS / tool helpers
ensure_linux() {
  [[ "$(uname -s)" == "Linux" ]]
}

ensure_debian() {
  command -v apt >/dev/null 2>&1 || command -v apt-get >/dev/null 2>&1
}

ensure_sudo() {
  command -v sudo >/dev/null 2>&1
}

ensure_curl() {
  command -v curl >/dev/null 2>&1
}

# Dry-run support (optional)
is_dryrun() {
  [[ "${DOTFILES_DRYRUN:-0}" == "1" ]]
}

# Normalize key env vars without changing their semantics (default to empty).
DOTFILES_NONINTERACTIVE="${DOTFILES_NONINTERACTIVE:-0}"
: "${SETUP_GIT:=}"
: "${SETUP_MCP:=}"
: "${SETUP_MCP_IDES:=}"
: "${SETUP_SKILLS:=}"
: "${INSTALL_VSCODE:=}"
: "${INSTALL_CURSOR:=}"
: "${INSTALL_ANTIGRAVITY:=}"
: "${CURSOR_INSTALL_FORCE:=}"

export DOTFILES_NONINTERACTIVE \
  SETUP_GIT SETUP_MCP SETUP_MCP_IDES SETUP_SKILLS \
  INSTALL_VSCODE INSTALL_CURSOR INSTALL_ANTIGRAVITY \
  CURSOR_INSTALL_FORCE \
  GREEN RED RESET


