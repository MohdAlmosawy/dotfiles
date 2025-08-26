#!/usr/bin/env bash
set -euo pipefail

# -----------------------------
# Helpers
# -----------------------------

die() {
  echo "[ERROR] $*" >&2
  exit 1
}

# Figure out where we live
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "→ dotfiles directory: $DOTFILES_DIR"

# Backup + symlink (idempotent)
link() {
  local src=$1 dst=$2
  mkdir -p "$(dirname "$dst")"
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    echo "  • backing up $dst → $dst.bak"
    mv "$dst" "$dst.bak"
  fi
  ln -sfn "$src" "$dst"
  echo "  → linked $src → $dst"
}

# Create or update ~/.gitconfig.local (interactive or via env)
create_gitconfig_local() {
  local target="$HOME/.gitconfig.local"
  local cur_name="" cur_email="" cur_editor=""

  if command -v git >/dev/null 2>&1; then
    cur_name="$(git config --global user.name || true)"
    cur_email="$(git config --global user.email || true)"
    cur_editor="$(git config --global core.editor || true)"
  fi

  if [[ "${DOTFILES_NONINTERACTIVE:-0}" == "1" ]]; then
    : "${GIT_USER_NAME:?Set GIT_USER_NAME for non-interactive mode}"
    : "${GIT_USER_EMAIL:?Set GIT_USER_EMAIL for non-interactive mode}"
    GIT_EDITOR="${GIT_EDITOR:-${VISUAL:-${EDITOR:-nano}}}"
  else
    echo "→ Let's set your Git identity (saved to ~/.gitconfig.local)"
    read -rp "  Your name  [${cur_name:-Your Name}]: " GIT_USER_NAME || true
    read -rp "  Your email [${cur_email:-you@example.com}]: " GIT_USER_EMAIL || true
    read -rp "  Editor (vim/nano/code --wait) [${cur_editor:-${VISUAL:-${EDITOR:-nano}}}]: " GIT_EDITOR || true
    GIT_USER_NAME="${GIT_USER_NAME:-${cur_name:-Your Name}}"
    GIT_USER_EMAIL="${GIT_USER_EMAIL:-${cur_email:-you@example.com}}"
    GIT_EDITOR="${GIT_EDITOR:-${cur_editor:-${VISUAL:-${EDITOR:-nano}}}}"
  fi

  cat > "$target" <<EOF
[user]
    name = ${GIT_USER_NAME}
    email = ${GIT_USER_EMAIL}

[core]
    editor = ${GIT_EDITOR}

[init]
    defaultBranch = main

[pull]
    ff = only
EOF
  echo "  → wrote $target"

  # Sensible per-OS credential helper (if not already set)
  if command -v git >/dev/null 2>&1; then
    if ! git config --global --get credential.helper >/dev/null 2>&1; then
      case "$(uname -s)" in
        Darwin)  git config --global credential.helper osxkeychain ;;
        Linux)
          if command -v git-credential-libsecret >/dev/null 2>&1; then
            git config --global credential.helper libsecret
          else
            if [[ "${DOTFILES_NONINTERACTIVE:-0}" == "1" ]]; then
              : # skip in CI unless user opts for store explicitly beforehand
            else
              read -rp "Use plaintext credential store (~/.git-credentials)? [y/N]: " ans || true
              [[ "$ans" =~ ^[Yy]$ ]] && git config --global credential.helper store
            fi
          fi
          ;;
      esac
    fi
  fi
}

# Ensure ~/bin on PATH in the user's shell rc
add_to_shell_rc() {
  local rc="$1"
  local line='export PATH="$HOME/bin:$PATH"'
  if [ -f "$HOME/$rc" ] && grep -qxF "$line" "$HOME/$rc"; then
    return
  fi
  echo -e "\n# add ~/bin to PATH\n$line" >> "$HOME/$rc"
  echo "  • added PATH line to ~/$rc"
}

# Source the appropriate RC file for the current shell session
source_shell_rc() {
  local current_shell rc_file
  current_shell="$(basename "${SHELL:-bash}")"
  rc_file=".$current_shell"rc

  if [ -f "$HOME/$rc_file" ]; then
    echo "→ Sourcing $rc_file..."
    if [ "$current_shell" = "zsh" ]; then
      # For zsh, avoid executing the whole profile; just ensure PATH now
      export PATH="$HOME/bin:$PATH"
    else
      # shellcheck source=/dev/null
      source "$HOME/$rc_file"
    fi
  fi
}

# -----------------------------
# Cursor (Linux only, optional)
# -----------------------------
create_cursor_desktop_entry() {
  local desktop_dir="$HOME/.local/share/applications"
  local desktop_file="$desktop_dir/cursor.desktop"

  mkdir -p "$desktop_dir"
  cat > "$desktop_file" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Cursor
Comment=AI-first code editor
Exec=$HOME/.local/bin/Cursor.AppImage
Icon=cursor
Terminal=false
Categories=Development;TextEditor;IDE;
StartupWMClass=Cursor
EOF

  if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$desktop_dir" || true
  fi
  echo "✔ Cursor desktop entry created"
}

install_cursor_linux() {
  command -v curl >/dev/null 2>&1 || { echo "curl not found; skipping Cursor install."; return; }

  # Skip by default on WSL unless forced
  if [[ -f /proc/version ]] && grep -qi microsoft /proc/version; then
    if [[ "${CURSOR_INSTALL_FORCE:-0}" != "1" ]]; then
      echo "WSL detected; skipping Cursor install (set CURSOR_INSTALL_FORCE=1 to force)."
      return
    fi
  fi

  local install_dir="$HOME/.local/bin"
  local api_url="https://www.cursor.com/api/download?platform=linux-x64&releaseTrack=stable"
  local appimage="$install_dir/Cursor.AppImage"

  echo "→ Fetching Cursor metadata…"
  mkdir -p "$install_dir"

  local json download_url
  json="$(curl -fsSL "$api_url" || true)"
  download_url="$(printf '%s' "$json" | grep -Po '"downloadUrl"\s*:\s*"\K[^"]+' || true)"
  [[ -n "$download_url" ]] || { echo "Could not parse Cursor download URL; skipping."; return; }

  echo "→ Downloading Cursor from $download_url"
  curl -L --fail "$download_url" -o "$appimage"
  chmod +x "$appimage"
  echo "✔ Cursor installed to $appimage"

  create_cursor_desktop_entry
}

maybe_install_cursor() {
  case "$(uname -s)" in
    Linux)
      if [[ "${DOTFILES_NONINTERACTIVE:-0}" == "1" ]]; then
        [[ "${INSTALL_CURSOR:-0}" == "1" ]] && install_cursor_linux
      else
        if [[ -f "$HOME/.local/bin/Cursor.AppImage" ]]; then
          echo "Cursor already present; ensuring desktop entry…"
          create_cursor_desktop_entry
        else
          read -rp "Install Cursor editor (Linux AppImage) now? [y/N]: " ans || true
          [[ "$ans" =~ ^[Yy]$ ]] && install_cursor_linux
        fi
      fi
      ;;
    *) : ;; # skip on macOS/others
  esac
}

# -----------------------------
# Run setup
# -----------------------------

# 1) Git identity (local, per-user)
create_gitconfig_local

# 2) Link global gitignore and gitconfig from the repo
echo "Linking global gitignore…"
link "$DOTFILES_DIR/.gitignore_global" "$HOME/.gitignore_global"

echo "Linking global Git config…"
link "$DOTFILES_DIR/.gitconfig" "$HOME/.gitconfig"

# 3) Install bin/ scripts into ~/bin
echo "Installing bin/ scripts…"
mkdir -p "$HOME/bin"
shopt -s nullglob
for f in "$DOTFILES_DIR"/bin/*; do
  fname="$(basename "$f")"
  dst="$HOME/bin/$fname"
  link "$f" "$dst"
  chmod +x "$dst"
done
shopt -u nullglob

# 4) Ensure ~/bin on PATH
echo "Checking shell RCs for ~/bin path…"
for rc in .bashrc .zshrc .profile; do
  add_to_shell_rc "$rc"
done

# 5) Optionally install Cursor (Linux)
maybe_install_cursor

# 6) Setup MCP config (optional)
if [[ "${DOTFILES_NONINTERACTIVE:-0}" == "1" ]]; then
  [[ "${SETUP_MCP:-0}" == "1" ]] && "$DOTFILES_DIR/scripts/setup_mcp.sh" || echo "Skipping MCP config (non-interactive)."
else
  read -rp "Do you want to set up MCP config now? [y/N]: " setup_mcp || true
  if [[ "$setup_mcp" =~ ^[Yy]$ ]]; then
    "$DOTFILES_DIR/scripts/setup_mcp.sh"
  else
    echo "Skipping MCP config setup. You can run scripts/setup_mcp.sh later."
  fi
fi

# 7) Refresh current shell PATH
source_shell_rc

# 8) Optionally set a per-machine ODOO_DB environment variable
create_odoo_db_env() {
  # Skip in non-interactive runs
  if [[ "${DOTFILES_NONINTERACTIVE:-0}" == "1" ]]; then
    return
  fi

  local machine_db_file="$HOME/.config/odoo/odoo_db"

  # If machine-wide DB already set, use it (and export for current session)
  if [[ -f "$machine_db_file" ]]; then
    local existing
    existing=$(sed -n '1p' "$machine_db_file" | sed "s/[\"' ]//g" | xargs || true)
    if [[ -n "$existing" ]]; then
      export ODOO_DB="$existing"
      echo "Using persisted ODOO_DB from $machine_db_file: $existing"
      return
    fi
  fi

  read -rp "Set a default Odoo DB name for this machine? [y/N]: " setdb || true
  if [[ "$setdb" =~ ^[Yy]$ ]]; then
    read -rp "Enter DB name (e.g. alsalamlocal): " dbname || true
    dbname="${dbname:-}"
    if [[ -n "$dbname" ]]; then
      mkdir -p "$(dirname "$machine_db_file")"
      echo "$dbname" > "$machine_db_file"
      chmod 600 "$machine_db_file" || true
      export ODOO_DB="$dbname"
      echo "  • Persisted ODOO_DB to $machine_db_file"
    fi
  fi
}

create_odoo_db_env

echo "✅ All done! Your shell has been updated with the new PATH."
