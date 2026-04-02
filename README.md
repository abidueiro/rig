# rig — Terminal Resource Interactive Guide

A TUI launcher for the terminal. Combines [television (tv)](https://github.com/alexpasmantier/television), [fzf](https://github.com/junegunn/fzf) and [gum](https://github.com/charmbracelet/gum) into a unified fuzzy menu with categories, previews and contextual actions.

```
rig — type to filter · [nav] [dev] [sys] [net] [tool]
> search...
  [nav]   📁  Browse files
  [nav]   📂  Browse directories (cd)
  [nav]   🔍  Search file contents
  [dev]   🐋  Docker
  [dev]   🐍  Django (current project)
  ...
```

---

## Features

### [nav] Navigation
| Option | Description |
|--------|-------------|
| Browse files | `fd` + preview with `bat`. `ctrl-o` opens in Zed, `ctrl-t` opens Ghostty in the file directory |
| Browse directories (cd) | `fd` with `ls` preview. Supports current dir, home or zoxide history. **cd works in the parent shell** |
| Search file contents | `rg` + `fzf` with file preview and highlighted line |

### [dev] Development
| Option | Description |
|--------|-------------|
| Docker | lazydocker, containers (inspect/logs/shell/restart/stop), images, networks, volumes, docker-compose |
| Django | Search django log (path configured at install), follow live, filter errors/warnings |
| Python venvs / uv | List, activate and create venvs (supports uv and python -m venv) |
| Git | gitui, log with diff, branches + checkout, stash, modified files |

### [sys] System
| Option | Description |
|--------|-------------|
| System logs | journalctl, boot log, dmesg + custom log files configured at install. Search or follow live |
| Systemd services | List (all/active/failed), start/stop/restart/enable/disable with status preview |
| Processes | ps aux with management: SIGTERM/SIGKILL/SIGINT, renice, pstree, lsof |
| Backup (rsync) | rsync to pre-configured destinations or pick SSH host on the fly. Dry run, live run, log viewer |

### [net] Network
| Option | Description |
|--------|-------------|
| Ports / Connections | `ss -tulpn` with preview of the listening process |
| SSH → Connect | Hosts from `~/.ssh/config` with config preview and connect/tmux actions |
| SSH → Mount filesystem | sshfs — pick host from SSH config, set remote dir, local mount point auto-created |
| SSH → SOCKS proxy | Dynamic proxy on a local port. Configure browser to use `SOCKS5 localhost:<port>` |
| SSH → Port forward | Local→Remote or Remote→Local tunnel with configurable ports |
| SSH → Run remote app | Launch a remote GUI app locally via X11 forwarding |
| WireGuard | Launches `wgs` or falls back to `sudo wg show` |

### [tool] Tools
| Option | Description |
|--------|-------------|
| Cheat sheets | cht.sh fuzzy search — inline preview, opens in `less` |
| Environment variables | `tv env` |
| Weather | wttr.in — cities configured during install, plus manual input at any time |

---

## Dependencies

### Core (required)
| Tool | Purpose | Install |
|------|---------|---------|
| `gum` | TUI menus, inputs, confirmations | `paru -S gum` / `brew install gum` |
| `fzf` | Fuzzy finder with preview | `paru -S fzf` / `apt install fzf` |
| `bat` | File preview with syntax highlighting | `paru -S bat` / `apt install bat` |

### Highly recommended
| Tool | Purpose |
|------|---------|
| `tv` (television) | ssh-hosts, git-log, git-branches, docker-all, env vars channels |
| `fd` | Fast file/dir search (alternative to find) |
| `rg` (ripgrep) | Fast recursive content search |

### Optional (enable specific features)
| Tool | Feature |
|------|---------|
| `zoxide` | Directory history navigation |
| `lazydocker` | Full Docker TUI |
| `gitui` | Full Git TUI |
| `uv` | Faster venv creation |
| `lsof` | Files opened by process |
| `pstree` | Process tree view |
| `ss` | Ports and connections |
| `curl` | Weather (wttr.in) + cheat sheets (cht.sh) |
| `tmux` | Open SSH in a new window |
| `sshfs` | Mount remote filesystems |
| `rsync` | Backup section |
| `wgs` | WireGuard helper |

### Television cable channels
`.toml` files that go in `~/.config/television/cable/`:
- `files-open.toml` — files with Zed / Ghostty actions
- `docker-all.toml` — containers with contextual actions
- `ssh-hosts.toml` — SSH hosts with config preview
- `git-log.toml` — commits with diff preview
- `git-branches.toml` — branches with checkout
- `git-stash.toml` — stash with diff preview
- `git-modified.toml` — modified files with diff preview

---

## Installation

### Option A — Interactive installer (recommended)

```bash
git clone https://github.com/your-user/rig   # or copy the files
cd rig
chmod +x install.sh
./install.sh
```

The installer is a step-by-step wizard powered by `gum`. For each section it shows which tools are available (✓/✗) and asks whether to enable it. Sections with missing tools default to disabled but can still be turned on if you plan to install them later.

The wizard also collects:

| Prompt | What it configures |
|--------|--------------------|
| Weather cities | Quick-select cities in the weather menu (e.g. London, Tokyo). Leave empty to always prompt manually. |
| Log files | Custom log files to add to System logs (label + path pairs, e.g. `nginx error` → `/var/log/nginx/error.log`). |
| Django log path | Path to the Django log file relative to `$PWD` (default: `logs/django.log`). |
| SSH config path | Path to the SSH config file (default: `~/.ssh/config`). |
| Backup source | Directory to back up (default: `$HOME`). |
| Backup destinations | One or more rsync destinations. If `~/.ssh/config` exists, an fzf host picker builds `host:/remote/path` automatically. |

The installer also generates `~/.config/rig/rsync-excludes.txt` with sensible defaults (caches, node_modules, build artifacts, etc.). Edit it to customise what gets excluded.

Everything is saved to `~/.config/rig/rig.conf`. Run `./install.sh` again at any time to reconfigure.

### Option B — Manual with GNU Stow (dotfiles)

Expected structure inside the dotfiles repository:

```
dotfiles/
├── zsh/
│   ├── .zshrc
│   └── .config/
│       └── zsh/
│           └── rig.zsh              ← zsh function
├── television/
│   └── .config/
│       └── television/
│           └── cable/
│               ├── files-open.toml
│               ├── docker-all.toml
│               ├── ssh-hosts.toml
│               ├── git-log.toml
│               ├── git-branches.toml
│               ├── git-stash.toml
│               └── git-modified.toml
└── rig/
    └── .config/
        └── rig/
            └── rig.conf             ← generated by install.sh
```

```bash
cd ~/dotfiles
stow zsh
stow television
stow rig
```

### Option C — Server (bash, no zsh or stow)

```bash
cp rig.sh ~/.local/bin/rig
chmod +x ~/.local/bin/rig
./install.sh   # generates rig.conf based on available tools
```

For **cd to work** in bash, add one of these to `~/.bashrc`:

```bash
# Option 1: source directly
source ~/.local/bin/rig

# Option 2: alias
alias rig='. ~/.local/bin/rig'
```

---

## Configuration

All configuration lives in `~/.config/rig/rig.conf`, generated by `install.sh`. You can also edit it manually at any time.

### Enable / disable sections

```bash
RIG_DEV_DJANGO=false
RIG_TOOL_WEATHER=false
RIG_NET_WG=false
```

### Paths

```bash
# Django log path (relative to $PWD when rig is launched)
RIG_DJANGO_LOG="app/logs/django.log"

# SSH config file
RIG_SSH_CONFIG="$HOME/.ssh/work_config"
```

### Weather cities

Pipe-separated list of cities shown as quick-select options. Leave empty to always prompt for manual input.

```bash
RIG_WEATHER_CITIES="London|Tokyo|Berlin"
```

### Custom log files

Pipe-separated list of `label:path` pairs added to the System logs menu. sudo is applied automatically for paths under `/var/log`.

```bash
RIG_LOG_FILES="nginx error:/var/log/nginx/error.log|nginx access:/var/log/nginx/access.log|app:/var/log/myapp/app.log"
```

### Backup

```bash
# Source directory
RIG_BACKUP_SOURCE="/home/user"

# Destinations: pipe-separated, local or SSH
RIG_BACKUP_DESTINATIONS="user@192.168.1.10:/backup|/mnt/external/backup"

# Excludes file (generated by install.sh — edit to customise)
RIG_BACKUP_EXCLUDES_FILE="$HOME/.config/rig/rsync-excludes.txt"
```

At runtime, if `~/.ssh/config` exists, the backup destination picker always offers "Pick SSH host from config" as an option alongside any pre-configured destinations — no need to type `user@host:/path` manually.

The excludes file is a plain text file, one pattern per line, passed to rsync via `--exclude-from`. The default covers caches, build artifacts, container data, and heavyweight tool directories (node_modules, .cargo, .venv, Steam, etc.).

### Reconfigure interactively

```bash
./install.sh   # reruns the full wizard and overwrites rig.conf
```

---

## Usage

```
rig              # open the menu
Ctrl+Space       # open from any prompt (zsh keybinding)
```

In the main menu, **type to filter**:
- `nav` → navigation options only
- `dev` → Docker, Django, Python, Git
- `sys` → logs, systemd, processes
- `net` → ports, SSH, WireGuard
- `tool` → cheat sheets, env vars, weather
- `docker` → goes straight to Docker
- `git` → goes straight to Git

---

## Ctrl+Space keybinding (zsh)

Included in `rig.zsh`:

```zsh
function _rig_widget() {
  rig
  zle reset-prompt
}
zle -N _rig_widget
bindkey '^ ' _rig_widget
```

If Ctrl+Space is already taken (e.g. tmux prefix), change it:

```zsh
bindkey '^o' _rig_widget    # Ctrl+O
bindkey '^[r' _rig_widget   # Alt+R
```

---

## Repository structure

```
rig/
├── rig.zsh          # zsh version (function, cd works in parent shell)
├── rig.sh           # bash version (for servers)
├── install.sh       # installer — detects tools, generates rig.conf
├── README.md
└── cable/           # television cable channels
    ├── files-open.toml
    ├── docker-all.toml
    ├── ssh-hosts.toml
    ├── git-log.toml
    ├── git-branches.toml
    ├── git-stash.toml
    └── git-modified.toml
```
