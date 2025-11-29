# Dotfiles — concise usage

This is my personal collection of **dotfiles and helper scripts**, used to quickly bootstrap my development machines and work with **Cursor’s MCP (multi-code-project)** setup for Odoo development.

It’s intentionally lightweight: a single bootstrap (`setup.sh`), a few small helpers in `bin/`, and some config templates in `templates/`.

> The only special piece here is `create-odoo-workspace.sh` — everything else is standard dotfile linking and MCP templating.

---

## ⚡ Quick install

```zsh
git clone git@github.com:MohdAlmosawy/dotfiles.git ~/dotfiles
cd ~/dotfiles
chmod +x setup.sh
./setup.sh       # links dotfiles, installs ~/bin helpers, optional Cursor/Antigravity/MCP/Odoo helpers
```

---

## 🧩 Modular setup structure

The main entrypoint is still `setup.sh`, but most logic now lives in small, focused modules under `modules/`:

- `modules/common.sh` – shared helpers (safe symlinks, PATH helpers, basic env normalization).
- `modules/git.sh` – Git identity setup and linking global git config/ignore from the repo.
- `modules/path_and_bin.sh` – installs `bin/` scripts into `~/bin` and ensures `~/bin` is on your PATH.
- `modules/editors.sh` – optional editor helpers (Cursor installer, VS Code via apt on Debian/Ubuntu).
- `modules/antigravity.sh` – optional Antigravity install (Debian/Ubuntu via apt).
- `modules/mcp.sh` – MCP config orchestration, still delegating to `scripts/setup_mcp.sh`.
- `modules/odoo.sh` – optional, per-machine `ODOO_DB` convenience config.

A rough repo layout for the core pieces looks like:

```text
dotfiles/
├── setup.sh
├── modules/
│   ├── common.sh
│   ├── git.sh
│   ├── path_and_bin.sh
│   ├── editors.sh
│   ├── antigravity.sh
│   ├── mcp.sh
│   └── odoo.sh
└── bin/
```

`setup.sh` simply detects `DOTFILES_DIR`, loads these modules, and runs them in a fixed sequence so behavior matches the older monolithic script.

### Env vars that influence behavior

All previous environment flags are still honored:

- `DOTFILES_NONINTERACTIVE=1` – run without prompts (for CI/automation).
- `SETUP_GIT` – controls Git identity setup in non-interactive mode.
- `SETUP_MCP`, `SETUP_MCP_IDES` – control MCP configuration in non-interactive mode.
- `INSTALL_CURSOR`, `CURSOR_INSTALL_FORCE` – control Cursor installation on Linux.
- `INSTALL_ANTIGRAVITY` – control Antigravity installation on Debian/Ubuntu.
- `INSTALL_VSCODE` – optional VS Code install on Debian/Ubuntu.

Optionally, `DOTFILES_DRYRUN=1` can be used as a hint for future non-destructive runs; for now it is wired only in shared helpers and does not change existing behavior.

## ⚙️ MCP and templates

`scripts/setup_mcp.sh` helps generate `~/.cursor/mcp.json` from `templates/mcp.json.template` and installs `mcp-odoo` into your virtualenv.
Run it only if you use Cursor’s MCP feature — otherwise you can ignore this part.

---


## 🧰 update-manifest

A small CLI helper installed by `./setup.sh` into `~/bin` that updates and normalizes Odoo `__manifest__.py` files with your preferred defaults (author, license, version, application flags, etc.).

Run `update-manifest --help` for available options.

---

## 🗒️ Notes & tips

- Workspaces and `.vscode` settings are **VS Code–compatible**.  
  Only `mcp.json` is Cursor-specific.
- Add `~/.cursor/mcp.json` and any local `.vscode/launch.json` to your personal `.gitignore` to avoid committing secrets.
- This repo stays **minimal by design** — no shells, themes, or frameworks; just portable scripts I can trust anywhere.
- The only custom helper worth noting is `create-odoo-workspace.sh`, which scaffolds Odoo workspaces for Cursor or VS Code.

---

