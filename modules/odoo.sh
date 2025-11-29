#!/usr/bin/env bash
set -euo pipefail

# modules/odoo.sh
#
# PUBLIC:
#   odoo_setup_run
#
# ENV VARS USED:
#   DOTFILES_NONINTERACTIVE
#
# SIDE EFFECTS:
#   May create ~/.config/odoo/odoo_db and export ODOO_DB

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

odoo_setup_run() {
  create_odoo_db_env
}


