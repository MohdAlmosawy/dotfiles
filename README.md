# Dotfiles — concise usage

This is my personal collection of **dotfiles and helper scripts**, used to quickly bootstrap my development machines for **Odoo development** with Cursor (MCP, agent skills) and VS Code-like editors.

It’s intentionally lightweight: a single bootstrap (`setup.sh`), a few small helpers in `bin/`, and some config templates in `templates/`.

---

## ⚡ Quick install

```zsh
git clone --recurse-submodules git@github.com:MohdAlmosawy/dotfiles.git ~/dotfiles
cd ~/dotfiles
chmod +x setup.sh
./setup.sh       # links dotfiles, installs ~/bin helpers, optional Cursor/MCP/skills/Odoo helpers
```

If you already cloned without submodules: `git submodule update --init vendor/skills`

---

## 🧩 Modular setup

Setup is split into focused modules under `modules/`. Use `DOTFILES_NONINTERACTIVE=1` for automation; flags like `SETUP_GIT`, `INSTALL_CURSOR`, `SETUP_MCP`, `SETUP_SKILLS`, and `INSTALL_ANTIGRAVITY` control optional steps.

Example (install everything non-interactively):

```zsh
DOTFILES_NONINTERACTIVE=1 SETUP_MCP=1 SETUP_SKILLS=1 INSTALL_CURSOR=1 ./setup.sh
```

## 🧠 Agent skills (optional)

Cursor agent skills live in a forked submodule at `vendor/skills` ([MohdAlmosawy/skills](https://github.com/MohdAlmosawy/skills), based on [mattpocock/skills](https://github.com/mattpocock/skills)). Skip this section if you don't use Cursor skills.

**Setup** — during `./setup.sh`, answer yes when prompted, or run manually:

```zsh
./scripts/setup_skills.sh          # installs skills listed in templates/skills.list into Cursor
```

Skills are copied to `~/.agents/skills/`. Restart Cursor after installing. Verify with `npx skills list -g`.

**Use in Cursor** — type `/` in chat to invoke user skills (e.g. `/grill-me`, `/to-prd`). Model-invoked skills (e.g. `tdd`, `diagnosing-bugs`) are picked up automatically when relevant. Run `/setup-matt-pocock-skills` once per project repo to configure issue tracker and domain docs.

**Customize** — edit `templates/skills.list` and rerun `./scripts/setup_skills.sh`. Pull upstream changes with `sync-skills-upstream`.

---

## ⚙️ MCP and templates

`scripts/setup_mcp.sh` helps generate `~/.cursor/mcp.json` from `templates/mcp.json.template` and installs `mcp-odoo` into your virtualenv.
Run it only if you use Cursor’s MCP feature — otherwise you can ignore this part.

---


## 🧰 update-manifest

A small CLI helper installed by `./setup.sh` into `~/bin` that updates and normalizes Odoo `__manifest__.py` files with your preferred defaults (author, license, version, application flags, etc.).

Run `update-manifest --help` for available options.

---

## 🚀 create-odoo-workspace

Scaffolds VS Code-like workspace files for Odoo modules. Automatically discovers dependencies from `__manifest__.py`, configures Python paths, debug settings, and Odoo Language Server integration.

Usage: `create-odoo-workspace.sh <path-to-module> [odoo-version|config-path]`

---

## 🗒️ Notes & tips

- Workspaces and `.vscode` settings are **VS Code-like**. Cursor-specific pieces are `~/.cursor/mcp.json` and agent skills under `~/.agents/skills/`.
- Add `~/.cursor/mcp.json` and any local `.vscode/launch.json` to your personal `.gitignore` to avoid committing secrets.
- This repo stays **minimal by design** — no shells, themes, or frameworks; just portable scripts I can trust anywhere.

---

