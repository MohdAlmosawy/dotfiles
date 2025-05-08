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

echo "✅ All done! Restart your shell or run 'source ~/.bashrc' (or zsh)."