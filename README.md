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
./setup.sh       # links dotfiles, installs ~/bin helpers, optional Cursor install
```

---

## ⚙️ MCP and templates

`scripts/setup_mcp.sh` helps generate `~/.cursor/mcp.json` from `templates/mcp.json.template` and installs `mcp-odoo` into your virtualenv.
Run it only if you use Cursor’s MCP feature — otherwise you can ignore this part.

---

## 🗒️ Notes & tips

- Workspaces and `.vscode` settings are **VS Code–compatible**.  
  Only `mcp.json` is Cursor-specific.
- Add `~/.cursor/mcp.json` and any local `.vscode/launch.json` to your personal `.gitignore` to avoid committing secrets.
- This repo stays **minimal by design** — no shells, themes, or frameworks; just portable scripts I can trust anywhere.
- The only custom helper worth noting is `create-odoo-workspace.sh`, which scaffolds Odoo workspaces for Cursor or VS Code.

---

