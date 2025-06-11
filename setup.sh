#!/usr/bin/env bash
set -euo pipefail

# 1. Figure out where we live
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "→ dotfiles directory: $DOTFILES_DIR"

# 2. Helper: backup + symlink
link() {
  local src=$1 dst=$2
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    echo "  • backing up $dst → $dst.bak"
    mv "$dst" "$dst.bak"
  fi
  ln -sfn "$src" "$dst"
  echo "  → linked $src → $dst"
}

# 3. Link global .gitignore
echo "Linking global gitignore…"
link "$DOTFILES_DIR/.gitignore_global" "$HOME/.gitignore_global"

echo "Linking global Git config…"
link "$DOTFILES_DIR/.gitconfig" "$HOME/.gitconfig"

# 4. Install bin/ scripts
echo "Installing bin/ scripts…"
mkdir -p "$HOME/bin"
for f in "$DOTFILES_DIR"/bin/*; do
  fname="$(basename "$f")"
  dst="$HOME/bin/$fname"
  link "$f" "$dst"
  chmod +x "$dst"
done

# 5. Ensure ~/bin is on your PATH in your shell rc
add_to_shell_rc() {
  local rc="$1"
  local line='export PATH="$HOME/bin:$PATH"'
  if [ -f "$HOME/$rc" ] && grep -qxF "$line" "$HOME/$rc"; then
    return
  fi
  echo -e "\n# add ~/bin to PATH\n$line" >> "$HOME/$rc"
  echo "  • added PATH line to ~/$rc"
}

# Try bash and zsh rc files
echo "Checking shell RCs for ~/bin path…"
for rc in .bashrc .zshrc; do
  add_to_shell_rc "$rc"
done

# Source the appropriate RC file
source_shell_rc() {
  local current_shell
  current_shell=$(basename "$SHELL")
  local rc_file=".$current_shell"rc
  
  if [ -f "$HOME/$rc_file" ]; then
    echo "→ Sourcing $rc_file..."
    if [ "$current_shell" = "zsh" ]; then
      # For zsh, we only need to update PATH, not source the entire file
      export PATH="$HOME/bin:$PATH"
    else
      # For bash, we can safely source the file
      # shellcheck source=/dev/null
      source "$HOME/$rc_file"
    fi
  fi
}

# === Install Cursor AppImage to ~/.local/bin ===
install_cursor() {
  local install_dir="$HOME/.local/bin"
  local api_url="https://www.cursor.com/api/download?platform=linux-x64&releaseTrack=stable"
  local appimage="$install_dir/Cursor.AppImage"

  echo "→ Fetching Cursor metadata…"
  mkdir -p "$install_dir"

  # 1) Grab the JSON metadata
  local json
  json=$(curl -fsSL "$api_url")

  # 2) Extract the actual downloadUrl
  local download_url
  download_url=$(printf '%s' "$json" \
    | grep -Po '"downloadUrl"\s*:\s*"\K[^"]+')

  if [[ -z "$download_url" ]]; then
    echo "Error: could not parse downloadUrl from Cursor API." >&2
    exit 1
  fi

  # 3) Download & make executable
  echo "→ Downloading Cursor from $download_url"
  curl -L --fail "$download_url" -o "$appimage"
  chmod +x "$appimage"
  echo "✔ Cursor installed to $appimage"

  # 4) Create desktop entry
  create_cursor_desktop_entry
}

# Create desktop entry for Cursor
create_cursor_desktop_entry() {
  local desktop_dir="$HOME/.local/share/applications"
  local desktop_file="$desktop_dir/cursor.desktop"
  
  echo "→ Creating Cursor desktop entry..."
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

  # Update desktop database
  update-desktop-database "$desktop_dir"
  echo "✔ Cursor desktop entry created"
}

# Only download if we don't already have it
if [[ ! -f "$HOME/.local/bin/Cursor.AppImage" ]]; then
  install_cursor
else
  # If Cursor is already installed, ensure desktop entry exists
  create_cursor_desktop_entry
fi

# === Setup MCP config ===
read -rp "Do you want to set up MCP config now? [y/N]: " setup_mcp
if [[ "$setup_mcp" =~ ^[Yy]$ ]]; then
  "$DOTFILES_DIR/scripts/setup_mcp.sh"
else
  echo "Skipping MCP config setup. You can run scripts/setup_mcp.sh later."
fi

# Source the appropriate RC file to update PATH
source_shell_rc

echo "✅ All done! Your shell has been updated with the new PATH."