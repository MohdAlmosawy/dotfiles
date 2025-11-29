#!/usr/bin/env bash
set -euo pipefail

# modules/path_and_bin.sh
#
# PUBLIC:
#   path_and_bin_run
#   refresh_path_run
#
# ENV VARS USED:
#   DOTFILES_DIR
#
# SIDE EFFECTS:
#   Symlinks scripts from $DOTFILES_DIR/bin into ~/bin
#   Ensures ~/bin is added to common shell rc files

path_and_bin_run() {
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

  echo "Checking shell RCs for ~/bin path…"
  for rc in .bashrc .zshrc .profile; do
    add_to_shell_rc "$rc"
  done
}

refresh_path_run() {
  # Refresh current shell PATH using the same logic as before.
  source_shell_rc
}


