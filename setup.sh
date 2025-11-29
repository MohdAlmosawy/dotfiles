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
# VS Code (Debian/Ubuntu, optional)
# -----------------------------

install_vscode_deb() {
  if ! command -v curl >/dev/null 2>&1; then
    echo "curl not found; skipping VS Code install."
    return
  fi

  if ! command -v sudo >/dev/null 2>&1; then
    echo "sudo not available; skipping VS Code install."
    return
  fi

  if ! command -v apt >/dev/null 2>&1 && ! command -v apt-get >/dev/null 2>&1; then
    echo "apt not found; VS Code install only supported on Debian/Ubuntu-like systems. Skipping."
    return
  fi

  echo "→ Adding Microsoft VS Code APT repository…"
  sudo mkdir -p /etc/apt/keyrings
  curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | \
    sudo gpg --dearmor -o /etc/apt/keyrings/packages.microsoft.gpg
  echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | \
    sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null

  echo "→ Updating APT package cache…"
  sudo apt update

  echo "→ Installing VS Code…"
  sudo apt install -y code

  echo "✔ VS Code installed (code)"
}

maybe_install_vscode() {
  case "$(uname -s)" in
    Linux)
      if ! command -v apt >/dev/null 2>&1 && ! command -v apt-get >/dev/null 2>&1; then
        echo "Non-Debian-based Linux detected; skipping VS Code."
        return
      fi

      if [[ "${DOTFILES_NONINTERACTIVE:-0}" == "1" ]]; then
        [[ "${INSTALL_VSCODE:-0}" == "1" ]] && install_vscode_deb
      else
        if command -v code >/dev/null 2>&1; then
          echo "VS Code (code) already installed; skipping."
        else
          read -rp "Install VS Code (code) via apt now? [y/N]: " ans || true
          [[ "$ans" =~ ^[Yy]$ ]] && install_vscode_deb
        fi
      fi
      ;;
    *)
      echo "Non-Linux system detected; skipping VS Code."
      ;;
  esac
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
# Antigravity (Debian/Ubuntu, optional)
# -----------------------------

install_antigravity_deb() {
  if ! command -v curl >/dev/null 2>&1; then
    echo "curl not found; skipping Antigravity install."
    return
  fi

  if ! command -v sudo >/dev/null 2>&1; then
    echo "sudo not available; skipping Antigravity install."
    return
  fi

  if ! command -v apt >/dev/null 2>&1 && ! command -v apt-get >/dev/null 2>&1; then
    echo "apt not found; Antigravity install only supported on Debian/Ubuntu-like systems. Skipping."
    return
  fi

  echo "→ Configuring Antigravity APT repository…"
  sudo mkdir -p /etc/apt/keyrings
  curl -fsSL https://us-central1-apt.pkg.dev/doc/repo-signing-key.gpg | \
    sudo gpg --dearmor -o /etc/apt/keyrings/antigravity-repo-key.gpg
  echo "deb [signed-by=/etc/apt/keyrings/antigravity-repo-key.gpg] https://us-central1-apt.pkg.dev/projects/antigravity-auto-updater-dev/ antigravity-debian main" | \
    sudo tee /etc/apt/sources.list.d/antigravity.list > /dev/null

  echo "→ Updating APT package cache…"
  sudo apt update

  echo "→ Installing Antigravity…"
  sudo apt install -y antigravity

  # Ensure Antigravity zsh completion file has correct ownership
  local ag_completion="/usr/share/zsh/vendor-completions/_antigravity"
  if [ -f "$ag_completion" ]; then
    echo "→ Fixing Antigravity zsh completion ownership…"
    sudo chown root:root "$ag_completion" || true
  fi

  echo "✔ Antigravity installed via APT"
}

maybe_install_antigravity() {
  case "$(uname -s)" in
    Linux)
      if ! command -v apt >/dev/null 2>&1 && ! command -v apt-get >/dev/null 2>&1; then
        echo "Non-Debian-based Linux detected; skipping Antigravity."
        return
      fi

      if [[ "${DOTFILES_NONINTERACTIVE:-0}" == "1" ]]; then
        [[ "${INSTALL_ANTIGRAVITY:-0}" == "1" ]] && install_antigravity_deb
      else
        if command -v antigravity >/dev/null 2>&1; then
          echo "Antigravity already installed; skipping."
        else
          read -rp "Install Antigravity (via apt, Debian/Ubuntu only)? [y/N]: " ans || true
          [[ "$ans" =~ ^[Yy]$ ]] && install_antigravity_deb
        fi
      fi
      ;;
    *)
      echo "Non-Linux system detected; skipping Antigravity."
      ;;
  esac
}

# -----------------------------
# Run setup
# -----------------------------

# 1) Git identity (local, per-user) — make optional if already configured
# If DOTFILES_NONINTERACTIVE=1 then SETUP_GIT controls behavior:
#   SETUP_GIT=1  -> run setup
#   SETUP_GIT=0  -> skip setup
#   unset        -> skip by default in non-interactive
# In interactive mode, prompt only if git user.name or user.email are missing.
should_setup_git() {
  # If git isn't installed, nothing to do
  if ! command -v git >/dev/null 2>&1; then
    return 1
  fi

  local existing_name existing_email
  # Check for a configured identity at any level (local, global, system)
  existing_name=$(git config --get user.name || true)
  existing_email=$(git config --get user.email || true)

  if [[ "${DOTFILES_NONINTERACTIVE:-0}" == "1" ]]; then
    # Non-interactive: allow explicit skip, otherwise default to running setup
    case "${SETUP_GIT:-}" in
      0) return 1 ;; # explicitly skip
      1) return 0 ;; # force setup
      *) ;;           # unset -> continue to detection below
    esac
  fi

  # If both name and email exist, print summary and skip
  if [[ -n "$existing_name" && -n "$existing_email" ]]; then
    echo "Found Git identity: name='$existing_name' email='$existing_email' — skipping setup."
    return 1
  fi

  # Interactive: if either name or email is missing, prompt to run setup
  if [[ "${DOTFILES_NONINTERACTIVE:-0}" != "1" ]]; then
    read -rp "No Git identity found. Create one now? [y/N]: " ans || true
    [[ "$ans" =~ ^[Yy]$ ]]
    return
  fi

  # Non-interactive and no identity -> run setup by default
  return 0
}

if should_setup_git; then
  create_gitconfig_local
else
  echo "Skipping Git identity setup. To force it, set SETUP_GIT=1 or run create_gitconfig_local manually."
fi

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

# 6) Optionally install Antigravity (Debian/Ubuntu via apt)
maybe_install_antigravity

# 7) Setup MCP config (optional)
if [[ "${DOTFILES_NONINTERACTIVE:-0}" == "1" ]]; then
  # Non-interactive: allow specifying IDE targets via SETUP_MCP_IDES (space/comma separated)
  # e.g. SETUP_MCP=1 SETUP_MCP_IDES="cursor antigravity"
  if [[ "${SETUP_MCP:-0}" == "1" ]]; then
    DOTFILES_MCP_IDES="${SETUP_MCP_IDES:-cursor}" "$DOTFILES_DIR/scripts/setup_mcp.sh"
  else
    echo "Skipping MCP config (non-interactive)."
  fi
else
  read -rp "Do you want to set up MCP config now? [y/N]: " setup_mcp || true
  if [[ "$setup_mcp" =~ ^[Yy]$ ]]; then
    echo "Which IDE(s) should MCP be configured for?"
    echo "  1) Cursor"
    echo "  2) Antigravity"
    echo "  3) Both"
    read -rp "Enter choice [1/2/3, default 1]: " mcp_choice || true
    mcp_choice="${mcp_choice:-1}"

    case "$mcp_choice" in
      1) DOTFILES_MCP_IDES="cursor" ;;
      2) DOTFILES_MCP_IDES="antigravity" ;;
      3) DOTFILES_MCP_IDES="cursor antigravity" ;;
      *) echo "Unrecognized choice '$mcp_choice', defaulting to Cursor only."; DOTFILES_MCP_IDES="cursor" ;;
    esac

    DOTFILES_MCP_IDES="$DOTFILES_MCP_IDES" "$DOTFILES_DIR/scripts/setup_mcp.sh"
  else
    echo "Skipping MCP config setup. You can run scripts/setup_mcp.sh later."
  fi
fi

# 8) Refresh current shell PATH
source_shell_rc

# 9) Optionally set a per-machine ODOO_DB environment variable
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
