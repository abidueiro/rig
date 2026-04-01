#!/usr/bin/env bash
# =============================================================================
# rig — interactive installer
# Detects available tools, asks section by section, collects custom paths
# and cities, then writes ~/.config/rig/rig.conf.
# =============================================================================

set -euo pipefail

CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/rig"
CONF_FILE="$CONF_DIR/rig.conf"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Colors (fallback if gum not yet available) ────────────────────────────────
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'
BOLD='\033[1m'; RESET='\033[0m'
ok()   { echo -e "  ${GREEN}✓${RESET}  $*"; }
warn() { echo -e "  ${YELLOW}!${RESET}  $*"; }
info() { echo -e "  ${CYAN}→${RESET}  $*"; }
hdr()  { echo -e "\n${BOLD}── $* ──${RESET}"; }

has() { command -v "$1" &>/dev/null; }

# ── Require gum ───────────────────────────────────────────────────────────────
if ! has gum; then
  echo -e "\n  ${YELLOW}gum is required for this installer.${RESET}"
  echo ""
  info "Arch/EndeavourOS:  paru -S gum"
  info "Homebrew:          brew install gum"
  info "Go:                go install github.com/charmbracelet/gum@latest"
  echo ""
  exit 1
fi

# ── Tool check helper ─────────────────────────────────────────────────────────
# Returns a status badge string for display
tool_badge() {
  local tool="$1"
  if has "$tool"; then
    echo "$(gum style --foreground 82 "✓ $tool")"
  else
    echo "$(gum style --foreground 196 "✗ $tool not found")"
  fi
}

# ask_section <header> <description> <tools...>
# Displays a confirm prompt with tool availability badges.
# Defaults to Y if all tools found, N if any missing.
ask_section() {
  local header="$1"
  local desc="$2"
  shift 2
  local tools=("$@")
  local all_found=true
  local badges=""
  for t in "${tools[@]}"; do
    badges+="  $(tool_badge "$t")\n"
    has "$t" || all_found=false
  done
  echo ""
  gum style --bold "  $header"
  gum style --foreground 245 "  $desc"
  printf "$badges"
  if [[ "$all_found" == true ]]; then
    gum confirm "  Enable?" && echo true || echo false
  else
    gum confirm --default=false "  Enable? (missing tools)" && echo true || echo false
  fi
}

# ── Wizard ────────────────────────────────────────────────────────────────────
main() {
  clear
  gum style \
    --border rounded --border-foreground 212 \
    --padding "1 4" --margin "1 2" \
    --bold "rig — interactive installer"

  gum style --foreground 245 \
    "  Configure which sections appear in rig.\n  Tools marked ✗ can still be enabled if you plan to install them."

  # ── Collected values ─────────────────────────────────────────────────────
  local nav_files nav_dirs nav_dirs_zoxide nav_text
  local dev_docker dev_django dev_python dev_git
  local sys_logs sys_systemd sys_procs
  local net_ports net_ssh net_wg
  local tool_cheat tool_env tool_weather

  local django_log ssh_config weather_cities log_files

  # ── [nav] Navigation ─────────────────────────────────────────────────────
  hdr "[nav] Navigation"

  nav_files=$(ask_section \
    "Browse files" \
    "fd + bat preview. ctrl-o opens in editor, ctrl-t opens terminal." \
    "fd" "bat")

  nav_dirs=$(ask_section \
    "Browse directories (cd)" \
    "fd + fzf with ls preview. cd works in parent shell." \
    "fd" "fzf")

  nav_dirs_zoxide=false
  if [[ "$nav_dirs" == true ]]; then
    nav_dirs_zoxide=$(ask_section \
      "  └─ Zoxide history" \
      "Directory history navigation inside Browse directories." \
      "zoxide")
  fi

  nav_text=$(ask_section \
    "Search file contents" \
    "ripgrep + fzf with bat preview and highlighted line." \
    "rg" "fzf" "bat")

  # ── [dev] Development ────────────────────────────────────────────────────
  hdr "[dev] Development"

  dev_docker=$(ask_section \
    "Docker" \
    "Containers, images, networks, volumes, docker-compose." \
    "docker")

  dev_git=$(ask_section \
    "Git" \
    "Log, branches, stash, modified files. gitui for full TUI." \
    "git")

  dev_python=$(ask_section \
    "Python venvs / uv" \
    "List, activate and create virtual environments." \
    "python3")

  # Django always asks for log path
  echo ""
  gum style --bold "  Django (current project)"
  gum style --foreground 245 "  Searches for a log file relative to \$PWD."
  echo ""
  if gum confirm "  Enable Django logs?"; then
    dev_django=true
    django_log=$(gum input \
      --placeholder "Log path relative to project root" \
      --value "logs/django.log" \
      --prompt "  log path › ")
    [[ -z "$django_log" ]] && django_log="logs/django.log"
  else
    dev_django=false
    django_log="logs/django.log"
  fi

  # ── [sys] System ─────────────────────────────────────────────────────────
  hdr "[sys] System"

  sys_procs=true   # ps aux always available, no prompt needed
  gum style --foreground 245 "  Processes — always enabled (ps aux)"

  sys_systemd=$(ask_section \
    "Systemd services" \
    "List, start, stop, restart, enable/disable services." \
    "systemctl")

  # System logs — ask + collect custom log files
  echo ""
  gum style --bold "  System logs"
  gum style --foreground 245 "  journalctl, dmesg, boot log + any custom log files you add."
  echo ""
  if gum confirm "  Enable system logs?"; then
    sys_logs=true
    # Collect custom log files
    log_files=""
    echo ""
    gum style --foreground 245 "  Add custom log files (e.g. /var/log/nginx/error.log)."
    gum style --foreground 245 "  Leave label empty to stop adding."
    echo ""
    while true; do
      local _lbl
      _lbl=$(gum input --placeholder "Label (e.g. nginx error) — empty to finish" --prompt "  label › ")
      [[ -z "$_lbl" ]] && break
      local _path
      _path=$(gum input --placeholder "/var/log/..." --prompt "  path  › ")
      [[ -z "$_path" ]] && break
      if [[ -z "$log_files" ]]; then
        log_files="${_lbl}:${_path}"
      else
        log_files="${log_files}|${_lbl}:${_path}"
      fi
      gum style --foreground 82 "  ✓ Added: $_lbl → $_path"
    done
    [[ -n "$log_files" ]] && gum style --foreground 245 "  Log files saved." \
      || gum style --foreground 245 "  No custom log files added (journalctl/dmesg still available)."
  else
    sys_logs=false
    log_files=""
  fi

  # ── [net] Network ─────────────────────────────────────────────────────────
  hdr "[net] Network"

  net_ports=$(ask_section \
    "Ports / Connections" \
    "ss -tulpn with process preview. Click through to process manager." \
    "ss")

  # SSH — ask + collect config path
  echo ""
  gum style --bold "  SSH"
  gum style --foreground 245 "  Hosts from SSH config with preview and connect/tmux actions."
  echo ""
  if gum confirm "  Enable SSH?"; then
    net_ssh=true
    ssh_config=$(gum input \
      --placeholder "SSH config path" \
      --value "$HOME/.ssh/config" \
      --prompt "  config path › ")
    [[ -z "$ssh_config" ]] && ssh_config="$HOME/.ssh/config"
  else
    net_ssh=false
    ssh_config="$HOME/.ssh/config"
  fi

  net_wg=$(ask_section \
    "WireGuard" \
    "Launches wgs helper or falls back to sudo wg show." \
    "wgs")

  # ── [tool] Tools ─────────────────────────────────────────────────────────
  hdr "[tool] Tools"

  tool_env=true
  gum style --foreground 245 "  Environment variables — always enabled"

  tool_cheat=$(ask_section \
    "Cheat sheets (cht.sh)" \
    "Fuzzy search cht.sh with inline preview." \
    "curl")

  # Weather — ask + collect cities
  echo ""
  gum style --bold "  Weather (wttr.in)"
  gum style --foreground 245 "  Fetches weather for configured cities or any manual input."
  echo ""
  if gum confirm "  Enable weather?"; then
    tool_weather=true
    weather_cities=""
    echo ""
    gum style --foreground 245 "  Add cities to the quick-select menu."
    gum style --foreground 245 "  Leave empty to stop. You can always type a city manually."
    echo ""
    while true; do
      local _city
      _city=$(gum input --placeholder "City name — empty to finish" --prompt "  city › ")
      [[ -z "$_city" ]] && break
      if [[ -z "$weather_cities" ]]; then
        weather_cities="$_city"
      else
        weather_cities="${weather_cities}|${_city}"
      fi
      gum style --foreground 82 "  ✓ Added: $_city"
    done
    [[ -n "$weather_cities" ]] \
      && gum style --foreground 245 "  Cities saved." \
      || gum style --foreground 245 "  No cities added — will always prompt for manual input."
  else
    tool_weather=false
    weather_cities=""
  fi

  # ── Write rig.conf ────────────────────────────────────────────────────────
  echo ""
  hdr "Writing configuration"
  mkdir -p "$CONF_DIR"

  cat > "$CONF_FILE" << EOF
# rig.conf — generated by install.sh on $(date '+%Y-%m-%d %H:%M')
# Edit manually or re-run install.sh to reconfigure.

# ── [nav] Navigation ─────────────────────────────────────────────────────────
RIG_NAV_FILES=${nav_files}
RIG_NAV_DIRS=${nav_dirs}
RIG_NAV_DIRS_ZOXIDE=${nav_dirs_zoxide}
RIG_NAV_TEXT=${nav_text}

# ── [dev] Development ─────────────────────────────────────────────────────────
RIG_DEV_DOCKER=${dev_docker}
RIG_DEV_DJANGO=${dev_django}
RIG_DEV_PYTHON=${dev_python}
RIG_DEV_GIT=${dev_git}

# ── [sys] System ──────────────────────────────────────────────────────────────
RIG_SYS_LOGS=${sys_logs}
RIG_SYS_SYSTEMD=${sys_systemd}
RIG_SYS_PROCS=${sys_procs}

# ── [net] Network ─────────────────────────────────────────────────────────────
RIG_NET_PORTS=${net_ports}
RIG_NET_SSH=${net_ssh}
RIG_NET_WG=${net_wg}

# ── [tool] Tools ──────────────────────────────────────────────────────────────
RIG_TOOL_CHEAT=${tool_cheat}
RIG_TOOL_ENV=${tool_env}
RIG_TOOL_WEATHER=${tool_weather}

# ── Paths ─────────────────────────────────────────────────────────────────────
# Django log path (relative to \$PWD when rig is launched)
RIG_DJANGO_LOG="${django_log}"

# SSH config file
RIG_SSH_CONFIG="${ssh_config}"

# ── Custom log files ──────────────────────────────────────────────────────────
# Format: "label:path|label:path"  (pipe-separated, no spaces around |)
# Example: RIG_LOG_FILES="nginx error:/var/log/nginx/error.log|app:/var/log/myapp/app.log"
RIG_LOG_FILES="${log_files}"

# ── Weather cities ────────────────────────────────────────────────────────────
# Format: "City1|City2|City3"  (pipe-separated)
# Leave empty to always prompt for manual input
RIG_WEATHER_CITIES="${weather_cities}"
EOF

  ok "Configuration written to $CONF_FILE"

  # ── Install files ─────────────────────────────────────────────────────────
  echo ""
  hdr "Installing files"

  local zsh_dir="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"
  local cable_dir="${XDG_CONFIG_HOME:-$HOME/.config}/television/cable"

  if [[ -f "$SCRIPT_DIR/rig.zsh" ]]; then
    mkdir -p "$zsh_dir"
    cp "$SCRIPT_DIR/rig.zsh" "$zsh_dir/rig.zsh"
    ok "rig.zsh → $zsh_dir/rig.zsh"
  fi

  if [[ -f "$SCRIPT_DIR/rig.sh" ]]; then
    mkdir -p "$HOME/.local/bin"
    cp "$SCRIPT_DIR/rig.sh" "$HOME/.local/bin/rig"
    chmod +x "$HOME/.local/bin/rig"
    ok "rig.sh → ~/.local/bin/rig"
  fi

  if has tv && [[ -d "$SCRIPT_DIR/cable" ]]; then
    mkdir -p "$cable_dir"
    cp "$SCRIPT_DIR/cable/"*.toml "$cable_dir/" 2>/dev/null \
      && ok "Cable channels → $cable_dir" \
      || warn "No .toml channels found in $SCRIPT_DIR/cable/"
    tv update-channels 2>/dev/null && ok "tv update-channels" || true
  fi

  # ── .zshrc check ─────────────────────────────────────────────────────────
  if [[ -f "$HOME/.zshrc" ]]; then
    if grep -q "rig.zsh" "$HOME/.zshrc"; then
      ok ".zshrc already sources rig.zsh"
    else
      echo ""
      gum style --foreground 245 "  Add to ~/.zshrc:"
      gum style --foreground 212 "  source ~/.config/zsh/rig.zsh"
      echo ""
      if gum confirm "  Add automatically?"; then
        echo 'source ~/.config/zsh/rig.zsh' >> "$HOME/.zshrc"
        ok "Added to ~/.zshrc"
      fi
    fi
  fi

  # ── Done ─────────────────────────────────────────────────────────────────
  echo ""
  gum style \
    --border rounded --border-foreground 82 \
    --padding "1 4" --margin "1 2" \
    --bold "✓ rig installed"

  info "Launch:     rig"
  info "Keybinding: Ctrl+Space (from any zsh prompt)"
  info "Reconfigure: ./install.sh"
  echo ""
}

main "$@"
