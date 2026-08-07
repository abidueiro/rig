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
RED='\033[0;31m'; BOLD='\033[1m'; RESET='\033[0m'
ok()   { echo -e "  ${GREEN}✓${RESET}  $*"; }
warn() { echo -e "  ${YELLOW}!${RESET}  $*"; }
info() { echo -e "  ${CYAN}→${RESET}  $*"; }
err()  { echo -e "  ${RED}✗${RESET}  $*"; }
hdr()  { echo -e "\n${BOLD}── $* ──${RESET}"; }

has() { command -v "$1" &>/dev/null; }

# ── CLI flags ─────────────────────────────────────────────────────────────────
MINIMAL_MODE=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --minimal) MINIMAL_MODE=true; shift ;;
    --help|-h)
      echo "Usage: ./install.sh [--minimal]"
      echo ""
      echo "  --minimal  Text-only installer (no gum required)."
      echo "             Uses read prompts instead of TUI widgets."
      echo "  --help     Show this message."
      exit 0
      ;;
    *) shift ;;
  esac
done

# ── Gum: try to install if missing (only in non-minimal mode) ────────────────
if ! has gum && [[ "$MINIMAL_MODE" != true ]]; then
  echo -e "\n  ${YELLOW}gum is not installed.${RESET}"
  echo ""
  echo "  gum provides the interactive TUI for this installer."
  echo ""
  echo "  Options:"
  echo "    1) Attempt auto-install (requires Go or pacman/brew)"
  echo "    2) Run in --minimal mode (text-only prompts, no TUI)"
  echo "    3) Install gum manually and re-run"
  echo ""
  read -r -p "  Choice [1/2/3]: " _gum_choice
  case "${_gum_choice:-}" in
    1)
      info "Attempting to install gum..."
      if has pacman; then
        sudo pacman -S --noconfirm gum 2>/dev/null && ok "gum installed via pacman" || \
          { warn "pacman install failed"; }
      elif has paru; then
        paru -S --noconfirm gum 2>/dev/null && ok "gum installed via paru" || \
          { warn "paru install failed"; }
      elif has brew; then
        brew install gum 2>/dev/null && ok "gum installed via brew" || \
          { warn "brew install failed"; }
      elif has go; then
        go install github.com/charmbracelet/gum@latest 2>/dev/null && \
          ok "gum installed via go" || { warn "go install failed"; }
      elif has apt-get; then
        sudo apt-get install -y gum 2>/dev/null && ok "gum installed via apt" || \
          { warn "apt install failed"; }
      else
        warn "No supported package manager found. Falling back to --minimal mode."
        MINIMAL_MODE=true
      fi
      ;;
    2) MINIMAL_MODE=true ;;
    3) info "Install gum manually (https://github.com/charmbracelet/gum) and re-run."; exit 0 ;;
    *) MINIMAL_MODE=true ;;
  esac
  # Re-check after install attempt
  if ! has gum && [[ "$MINIMAL_MODE" != true ]]; then
    warn "gum still not available. Switching to --minimal mode."
    MINIMAL_MODE=true
  fi
fi

# ── Minimal-mode helpers (text-only, no gum) ──────────────────────────────────
if [[ "$MINIMAL_MODE" == true ]]; then
  _min_choose() {
    local header="$1"; shift
    local -a opts=("$@")
    echo ""
    echo -e "${BOLD}  $header${RESET}"
    for _i in "${!opts[@]}"; do
      echo "    $((_i+1))) ${opts[$_i]}"
    done
    local _choice
    read -r -p "  Choice [1-${#opts[@]}]: " _choice
    _choice="${_choice:-1}"
    if [[ "$_choice" =~ ^[0-9]+$ ]] && (( _choice >= 1 && _choice <= ${#opts[@]} )); then
      echo "${opts[$((_choice-1))]}"
    fi
  }
  _min_confirm() {
    local prompt="$1"; local default="${2:-true}"
    local _yn="Y/n"
    [[ "$default" != true ]] && _yn="y/N"
    read -r -p "  $prompt [$_yn]: " _resp
    if [[ "$default" == true ]]; then
      [[ "$_resp" != "n" && "$_resp" != "N" ]] && echo true || echo false
    else
      [[ "$_resp" == "y" || "$_resp" == "Y" ]] && echo true || echo false
    fi
  }
  _min_input() {
    local prompt="$1"; local default="${2:-}"; local placeholder="${3:-}"
    local _disp="$prompt"
    [[ -n "$default" ]] && _disp="$_disp [$default]"
    [[ -n "$placeholder" ]] && _disp="$_disp ($placeholder)"
    read -r -p "  $_disp: " _val
    echo "${_val:-$default}"
  }
  _min_multiselect() {
    local header="$1"; shift
    local -a items=("$@")
    echo ""
    echo -e "${BOLD}  $header${RESET}"
    echo "  Enter numbers separated by spaces (e.g. 1 3 5), or 'all':"
    for _j in "${!items[@]}"; do
      echo "    $((_j+1))) ${items[$_j]}"
    done
    local _sel
    read -r -p "  Selection: " _sel
    if [[ "$_sel" == "all" ]]; then
      printf '%s\n' "${items[@]}"
    else
      for _num in $_sel; do
        if [[ "$_num" =~ ^[0-9]+$ ]] && (( _num >= 1 && _num <= ${#items[@]} )); then
          echo "${items[$((_num-1))]}"
        fi
      done
    fi
  }
fi

# ask_section <header> <description> <tools...>
# Uses gum confirm (exit code) so it works correctly inside $() subshells.
# All context shown inside the confirm prompt — no floating text above.
ask_section() {
  local header="$1"
  local desc="$2"
  shift 2
  local tools=("$@")
  local all_found=true
  local tool_line=""
  for t in "${tools[@]}"; do
    if has "$t"; then
      tool_line+="✓ $t  "
    else
      tool_line+="✗ $t  "
      all_found=false
    fi
  done

  local prompt
  prompt=$(printf "%s\n  %s\n  %s" "$header" "$desc" "$tool_line")

  if [[ "$all_found" == true ]]; then
    _confirm "$prompt" && echo true || echo false
  else
    _confirm_def "$prompt" false && echo true || echo false
  fi
}

# ── Wrappers: use gum if available, else fall back to minimal helpers ──────────
if has gum; then
  _choose()      { gum choose --header "$1" "${@:2}"; }
  _confirm()     { gum confirm "$1" && echo true || echo false; }
  _confirm_def() { gum confirm ${2:+--default="$2"} "$1" && echo true || echo false; }
  _input()       { gum input --value "${2:-}" --prompt "$1" --placeholder "${3:-}"; }
  _multi()       { gum choose --header "$1" --no-limit "${@:2}"; }
  _style()       { gum style "$@"; }
  _filter()      { gum filter --header "$1" --placeholder "${2:-filter...}"; }
else
  _choose()      { _min_choose "$@"; }
  _confirm()     { _min_confirm "$1" true; }
  _confirm_def() { _min_confirm "$1" "${2:-true}"; }
  _input()       { _min_input "$1" "${2:-}" "${3:-}"; }
  _multi()       { _min_multiselect "$@"; }
  _style()       { shift; echo -e "${BOLD}$*${RESET}"; }
  _filter()      { _min_choose "$1" "${@:3}"; }
fi


# ── Wizard ────────────────────────────────────────────────────────────────────
main() {
  clear
  _style \
    --border rounded --border-foreground 212 \
    --padding "1 4" --margin "1 2" \
    --bold "rig — interactive installer"

  # ── Collected values (defaults) ──────────────────────────────────────────
  local nav_files=false nav_dirs=false nav_dirs_zoxide=false nav_text=false
  local dev_docker=false dev_django=false dev_python=false dev_git=false
  local sys_logs=false sys_systemd=false sys_procs=true sys_backup=false
  local net_ports=false net_ssh=false net_wg=false
  local tool_cheat=false tool_env=true tool_weather=false

  local django_log="logs/django.log"
  local ssh_config="$HOME/.ssh/config"
  local weather_cities="" log_files=""
  local backup_source="$HOME" backup_destinations=""
  local backup_excludes_file="$CONF_DIR/rsync-excludes.txt"

  local install_zsh=false install_bash=false
  local use_stow=false dotfiles_dir="" zsh_package="zsh" bash_package="bin"

  # ══════════════════════════════════════════════════════════════════════════
  # STEP 1 — Shell
  # ══════════════════════════════════════════════════════════════════════════
  hdr "Step 1 — Shell"
  local shell_choice
  shell_choice=$(_choose \
    "  Which shell are you using?" \
    "Zsh" "Bash" "Both")
  case "$shell_choice" in
    "Zsh")  install_zsh=true ;;
    "Bash") install_bash=true ;;
    "Both") install_zsh=true; install_bash=true ;;
  esac

  # ══════════════════════════════════════════════════════════════════════════
  # STEP 2 — Dotfiles manager
  # ══════════════════════════════════════════════════════════════════════════
  hdr "Step 2 — Dotfiles manager"
  local dotfiles_choice
  dotfiles_choice=$(_choose \
    "  How do you manage dotfiles?" \
    "GNU Stow" \
    "Copy directly (no dotfiles manager)")

  if [[ "$dotfiles_choice" == "GNU Stow" ]]; then
    if ! has stow; then
      warn "stow not found in PATH — falling back to direct copy"
    else
      use_stow=true
      dotfiles_dir=$(_input \
        "  dotfiles dir › " \
        "$HOME/dotfiles" \
        "Path to your dotfiles repository")
      [[ -z "$dotfiles_dir" ]] && dotfiles_dir="$HOME/dotfiles"
      dotfiles_dir="${dotfiles_dir/#\~/$HOME}"

      if [[ "$install_zsh" == true ]]; then
        zsh_package=$(_input \
          "  stow package for ~/.config/zsh › " \
          "zsh" \
          "e.g. zsh")
        [[ -z "$zsh_package" ]] && zsh_package="zsh"
      fi

      if [[ "$install_bash" == true ]]; then
        bash_package=$(_input \
          "  stow package for ~/.local/bin › " \
          "bin" \
          "e.g. bin or scripts")
        [[ -z "$bash_package" ]] && bash_package="bin"
      fi
    fi
  fi

  # ══════════════════════════════════════════════════════════════════════════
  # STEP 3 — Sections (single multi-select screen)
  # ══════════════════════════════════════════════════════════════════════════
  hdr "Step 3 — Sections"

  # Helper: inline tool badge
  _b() { has "$1" && printf "✓ %s" "$1" || printf "✗ %s" "$1"; }

  local -a _sec_list=(
    "[nav]   📁  Browse files                  · $(_b fd) $(_b bat)"
    "[nav]   📂  Browse directories (cd)       · $(_b fd) $(_b fzf)"
    "[nav]   🔍  Search file contents           · $(_b rg) $(_b fzf)"
    "[dev]   🐋  Docker                         · $(_b docker)"
    "[dev]   🐍  Django (current project)       · log path configurable"
    "[dev]   🐍  Python venvs / uv              · $(_b python3)"
    "[dev]   🔀  Git                            · $(_b git)"
    "[sys]   📋  System logs                    · $(_b journalctl)"
    "[sys]   ⚙️   Systemd services               · $(_b systemctl)"
    "[sys]   💾  Backup (rsync)                 · $(_b rsync)"
    "[net]   🖧   Ports / Connections             · $(_b ss)"
    "[net]   🔌  SSH                             · $(_b ssh)"
    "[net]   🔒  WireGuard                      · $(_b wgs)"
    "[tool]  📖  Cheat sheets (cht.sh)          · $(_b curl)"
    "[tool]  🌤️   Weather (wttr.in)              · $(_b curl)"
  )

  # Pre-select entries where all required tools are present (no ✗)
  local _preselected=""
  for _s in "${_sec_list[@]}"; do
    [[ "$_s" != *"✗"* ]] && _preselected+="${_s},"
  done

  echo ""
  _style --foreground 245 \
    "  Space to toggle · Enter to confirm · Processes + Env vars always on"
  echo ""

  local _chosen
  _chosen=$(printf '%s\n' "${_sec_list[@]}" \
    | _multi \
        "  Select sections to enable" \
        "${_sec_list[@]}")

  # Map selections back to booleans
  echo "$_chosen" | grep -q "Browse files"             && nav_files=true
  echo "$_chosen" | grep -q "Browse directories"       && nav_dirs=true
  echo "$_chosen" | grep -q "Search file contents"     && nav_text=true
  echo "$_chosen" | grep -q "Docker"                   && dev_docker=true
  echo "$_chosen" | grep -q "Django"                   && dev_django=true
  echo "$_chosen" | grep -q "Python venvs"             && dev_python=true
  echo "$_chosen" | grep -q "Git"                      && dev_git=true
  echo "$_chosen" | grep -q "System logs"              && sys_logs=true
  echo "$_chosen" | grep -q "Systemd services"         && sys_systemd=true
  echo "$_chosen" | grep -q "Backup"                   && sys_backup=true
  echo "$_chosen" | grep -q "Ports"                    && net_ports=true
  echo "$_chosen" | grep -q "SSH"                      && net_ssh=true
  echo "$_chosen" | grep -q "WireGuard"                && net_wg=true
  echo "$_chosen" | grep -q "Cheat sheets"             && tool_cheat=true
  echo "$_chosen" | grep -q "Weather"                  && tool_weather=true

  # zoxide sub-option only if dirs enabled
  if [[ "$nav_dirs" == true ]] && has zoxide; then
    nav_dirs_zoxide=true
  fi

  # ══════════════════════════════════════════════════════════════════════════
  # STEP 4 — Configure selected sections that need input
  # ══════════════════════════════════════════════════════════════════════════
  local _need_config=false
  [[ "$dev_django" == true || "$net_ssh" == true || "$sys_logs" == true || \
     "$tool_weather" == true || "$sys_backup" == true ]] && _need_config=true

  if [[ "$_need_config" == true ]]; then
    hdr "Step 4 — Configuration"

    # ── Django log path ───────────────────────────────────────────────────
    if [[ "$dev_django" == true ]]; then
      echo ""
      _style --bold "  Django"
      django_log=$(_input \
        "  log path (relative to \$PWD) › " \
        "logs/django.log" \
        "logs/django.log")
      [[ -z "$django_log" ]] && django_log="logs/django.log"
      ok "Django log: $django_log"
    fi

    # ── SSH config path ───────────────────────────────────────────────────
    if [[ "$net_ssh" == true ]]; then
      echo ""
      _style --bold "  SSH"
      ssh_config=$(_input \
        "  SSH config path › " \
        "$HOME/.ssh/config" \
        "$HOME/.ssh/config")
      [[ -z "$ssh_config" ]] && ssh_config="$HOME/.ssh/config"
      ok "SSH config: $ssh_config"
    fi

    # ── Custom log files ──────────────────────────────────────────────────
    if [[ "$sys_logs" == true ]]; then
      echo ""
      _style --bold "  System logs — custom log files"
      _style --foreground 245 "  Add label + path pairs. Leave label empty to finish."
      echo ""
      while true; do
        local _lbl
        _lbl=$(_input "  label › " "" "Label (e.g. nginx error) — empty to finish")
        [[ -z "$_lbl" ]] && break
        local _lpath
        _lpath=$(_input "  path  › " "" "/var/log/...")
        [[ -z "$_lpath" ]] && break
        [[ -z "$log_files" ]] && log_files="${_lbl}:${_lpath}" \
                               || log_files="${log_files}|${_lbl}:${_lpath}"
        ok "Added: $_lbl → $_lpath"
      done
    fi

    # ── Weather cities ────────────────────────────────────────────────────
    if [[ "$tool_weather" == true ]]; then
      echo ""
      _style --bold "  Weather cities"
      _style --foreground 245 "  Quick-select cities in rig. Leave empty to always prompt manually."
      echo ""
      while true; do
        local _city
        _city=$(_input "  city › " "" "City name — empty to finish")
        [[ -z "$_city" ]] && break
        [[ -z "$weather_cities" ]] && weather_cities="$_city" \
                                   || weather_cities="${weather_cities}|${_city}"
        ok "Added: $_city"
      done
    fi

    # ── Backup ────────────────────────────────────────────────────────────
    if [[ "$sys_backup" == true ]]; then
      echo ""
      _style --bold "  Backup (rsync)"

      backup_source=$(_input \
        "  source dir › " \
        "$HOME" \
        "Directory to back up")
      [[ -z "$backup_source" ]] && backup_source="$HOME"
      ok "Source: $backup_source"

      echo ""
      _style --foreground 245 "  Add destinations — SSH host picker or manual."
      _style --foreground 245 "  Choose Done when finished."
      echo ""
      while true; do
        local _dest_type
        if [[ -f "${ssh_config:-$HOME/.ssh/config}" ]]; then
          _dest_type=$(_choose \
            "  Add backup destination" \
            "🔌  Pick SSH host from config" \
            "✏️   Type manually" \
            "✅  Done")
        else
          _dest_type=$(_choose \
            "  Add backup destination" \
            "✏️   Type manually" \
            "✅  Done")
        fi
        case "$_dest_type" in
          "🔌"*)
            local _host
            _host=$(grep -E '^Host ' "${ssh_config:-$HOME/.ssh/config}" \
              | grep -v '[*?]' | awk '{print $2}' \
              | fzf --header 'Select SSH host | Esc: cancel' --height 80% --border)
            [[ -z "$_host" ]] && continue
            local _rpath
            _rpath=$(_input "  remote path › " "/home/$USER" "Remote directory")
            [[ -z "$_rpath" ]] && continue
            local _dest="${_host}:${_rpath}"
            [[ -z "$backup_destinations" ]] && backup_destinations="$_dest" \
                                            || backup_destinations="${backup_destinations}|${_dest}"
            ok "Added: $_dest" ;;
          "✏️"*)
            local _dest
            _dest=$(_input \
              "  destination › " "" "user@host:/path  or  /mnt/drive — empty to finish")
            [[ -z "$_dest" ]] && break
            [[ -z "$backup_destinations" ]] && backup_destinations="$_dest" \
                                            || backup_destinations="${backup_destinations}|${_dest}"
            ok "Added: $_dest" ;;
          "✅"*|"") break ;;
        esac
      done

      backup_excludes_file="$CONF_DIR/rsync-excludes.txt"
      mkdir -p "$CONF_DIR"
      cat > "$backup_excludes_file" << 'EXCLUDES'
.cache
.local/share/Trash
.local/share/flatpak
.local/share/containers
.local/share/virtualenv
.local/share/virtualenvs
.local/share/man
.local/share/gvfs-metadata
.local/share/vulkan
.local/share/gstreamer-1.0
.local/share/uv
.local/share/pipx
.mozilla/firefox/*/Cache
.config/chromium/Default/Cache
node_modules
.npm
.gradle
__pycache__
.mypy_cache
.venv
.pytest_cache
.cargo
.rustup
.m2
.pyenv
.bun
.android
.vcpkg
/go
.docker
.zcompdump*
*.zwc
.steam
.local/share/Steam
EXCLUDES
      ok "Excludes file: $backup_excludes_file"
      _style --foreground 245 "  Edit it to customise what gets excluded."
    fi
  fi

  # ══════════════════════════════════════════════════════════════════════════
  # STEP 5 — Write rig.conf
  # ══════════════════════════════════════════════════════════════════════════
  echo ""
  hdr "Step 5 — Writing configuration"
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
RIG_SYS_BACKUP=${sys_backup}

# ── [net] Network ─────────────────────────────────────────────────────────────
RIG_NET_PORTS=${net_ports}
RIG_NET_SSH=${net_ssh}
RIG_NET_WG=${net_wg}

# ── [tool] Tools ──────────────────────────────────────────────────────────────
RIG_TOOL_CHEAT=${tool_cheat}
RIG_TOOL_ENV=${tool_env}
RIG_TOOL_WEATHER=${tool_weather}

# ── Paths ─────────────────────────────────────────────────────────────────────
RIG_DJANGO_LOG="${django_log}"
RIG_SSH_CONFIG="${ssh_config}"

# ── Custom log files ──────────────────────────────────────────────────────────
# Format: "label:path|label:path"
RIG_LOG_FILES="${log_files}"

# ── Weather cities ────────────────────────────────────────────────────────────
# Format: "City1|City2|City3"  — empty = always prompt manually
RIG_WEATHER_CITIES="${weather_cities}"

# ── Backup ────────────────────────────────────────────────────────────────────
RIG_BACKUP_SOURCE="${backup_source}"
RIG_BACKUP_DESTINATIONS="${backup_destinations}"
RIG_BACKUP_EXCLUDES_FILE="${backup_excludes_file}"
EOF

  ok "rig.conf written to $CONF_FILE"

  # ══════════════════════════════════════════════════════════════════════════
  # STEP 6 — Install files
  # ══════════════════════════════════════════════════════════════════════════
  echo ""
  hdr "Step 6 — Installing files"

  local cable_dir="${XDG_CONFIG_HOME:-$HOME/.config}/television/cable"

  # ── zsh ──────────────────────────────────────────────────────────────────
  if [[ "$install_zsh" == true && -f "$SCRIPT_DIR/rig.zsh" ]]; then
    if [[ "$use_stow" == true ]]; then
      local zsh_stow_path="$dotfiles_dir/$zsh_package/.config/zsh"
      mkdir -p "$zsh_stow_path"
      cp "$SCRIPT_DIR/rig.zsh" "$zsh_stow_path/rig.zsh"
      ok "Copied rig.zsh → $zsh_stow_path/rig.zsh"
      if ( cd "$dotfiles_dir" && stow "$zsh_package" 2>/dev/null ); then
        ok "stow $zsh_package → ~/.config/zsh/rig.zsh linked"
      elif ( cd "$dotfiles_dir" && stow --restow "$zsh_package" 2>/dev/null ); then
        ok "stow --restow $zsh_package"
      else
        warn "stow conflict — run manually:"
        info "cd $dotfiles_dir && stow $zsh_package"
      fi
    else
      local zsh_dir="${XDG_CONFIG_HOME:-$HOME/.config}/zsh"
      mkdir -p "$zsh_dir"
      cp "$SCRIPT_DIR/rig.zsh" "$zsh_dir/rig.zsh"
      ok "rig.zsh → $zsh_dir/rig.zsh"
    fi

    # .zshrc source line
    local zsh_src='source "${XDG_CONFIG_HOME:-$HOME/.config}/zsh/rig.zsh"'
    if [[ -f "$HOME/.zshrc" ]] && grep -q "rig.zsh" "$HOME/.zshrc"; then
      ok ".zshrc already sources rig.zsh"
    else
      echo ""
      _style --foreground 245 "  Add to ~/.zshrc:"
      _style --foreground 212 "  $zsh_src"
      echo ""
      if _confirm "Add source line to ~/.zshrc?"; then
        echo "$zsh_src" >> "$HOME/.zshrc"
        ok "Added to ~/.zshrc"
      fi
    fi
  fi

  # ── bash ─────────────────────────────────────────────────────────────────
  if [[ "$install_bash" == true && -f "$SCRIPT_DIR/rig.sh" ]]; then
    if [[ "$use_stow" == true ]]; then
      local bash_stow_path="$dotfiles_dir/$bash_package/.local/bin"
      mkdir -p "$bash_stow_path"
      cp "$SCRIPT_DIR/rig.sh" "$bash_stow_path/rig"
      chmod +x "$bash_stow_path/rig"
      ok "Copied rig.sh → $bash_stow_path/rig"
      if ( cd "$dotfiles_dir" && stow "$bash_package" 2>/dev/null ); then
        ok "stow $bash_package → ~/.local/bin/rig linked"
      elif ( cd "$dotfiles_dir" && stow --restow "$bash_package" 2>/dev/null ); then
        ok "stow --restow $bash_package"
      else
        warn "stow conflict — run manually:"
        info "cd $dotfiles_dir && stow $bash_package"
      fi
    else
      mkdir -p "$HOME/.local/bin"
      cp "$SCRIPT_DIR/rig.sh" "$HOME/.local/bin/rig"
      chmod +x "$HOME/.local/bin/rig"
      ok "rig.sh → ~/.local/bin/rig"
    fi

    # .bashrc source line
    local bash_src='source "$HOME/.local/bin/rig"'
    if [[ -f "$HOME/.bashrc" ]] && grep -q "/.local/bin/rig" "$HOME/.bashrc"; then
      ok ".bashrc already sources rig"
    else
      echo ""
      _style --foreground 245 "  For cd to work in bash, add to ~/.bashrc:"
      _style --foreground 212 "  $bash_src"
      echo ""
      if _confirm "Add source line to ~/.bashrc?"; then
        echo "$bash_src" >> "$HOME/.bashrc"
        ok "Added to ~/.bashrc"
      fi
    fi
  fi

  # ── television cable channels ─────────────────────────────────────────────
  if has tv && [[ -d "$SCRIPT_DIR/cable" ]]; then
    mkdir -p "$cable_dir"
    cp "$SCRIPT_DIR/cable/"*.toml "$cable_dir/" 2>/dev/null \
      && ok "Cable channels → $cable_dir" \
      || warn "No .toml channels found in $SCRIPT_DIR/cable/"
    tv update-channels 2>/dev/null && ok "tv update-channels" || true
  fi

  # ── Done ─────────────────────────────────────────────────────────────────
  echo ""
  _style \
    --border rounded --border-foreground 82 \
    --padding "1 4" --margin "1 2" \
    --bold "✓ rig installed"

  info "Launch:      rig"
  [[ "$install_zsh"  == true ]] && info "Keybinding:  Ctrl+Space (from any zsh prompt)"
  [[ "$install_bash" == true ]] && info "Bash cd:     source ~/.local/bin/rig"
  info "Reconfigure: ./install.sh"
  echo ""
}

main "$@"
