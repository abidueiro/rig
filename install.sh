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
    gum confirm "$prompt" && echo true || echo false
  else
    gum confirm --default=false "$prompt" && echo true || echo false
  fi
}


# ── Wizard ────────────────────────────────────────────────────────────────────
main() {
  clear
  gum style \
    --border rounded --border-foreground 212 \
    --padding "1 4" --margin "1 2" \
    --bold "rig — interactive installer"

  # ── Collected values (defaults) ──────────────────────────────────────────
  local nav_files=false nav_dirs=false nav_dirs_zoxide=false nav_text=false
  local dev_docker=false dev_django=false dev_python=false dev_git=false dev_tmux=false
  local sys_logs=false sys_systemd=false sys_procs=true sys_backup=false
  local net_ports=false net_ssh=false net_wg=false use_sshub=false
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
  shell_choice=$(gum choose \
    --header "  Which shell are you using?" \
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
  dotfiles_choice=$(gum choose \
    --header "  How do you manage dotfiles?" \
    "GNU Stow" \
    "Copy directly (no dotfiles manager)")

  if [[ "$dotfiles_choice" == "GNU Stow" ]]; then
    if ! has stow; then
      warn "stow not found in PATH — falling back to direct copy"
    else
      use_stow=true
      dotfiles_dir=$(gum input \
        --value "$HOME/dotfiles" \
        --prompt "  dotfiles dir › " \
        --placeholder "Path to your dotfiles repository")
      [[ -z "$dotfiles_dir" ]] && dotfiles_dir="$HOME/dotfiles"
      dotfiles_dir="${dotfiles_dir/#\~/$HOME}"

      if [[ "$install_zsh" == true ]]; then
        zsh_package=$(gum input \
          --value "zsh" \
          --prompt "  stow package for ~/.config/zsh › " \
          --placeholder "e.g. zsh")
        [[ -z "$zsh_package" ]] && zsh_package="zsh"
      fi

      if [[ "$install_bash" == true ]]; then
        bash_package=$(gum input \
          --value "bin" \
          --prompt "  stow package for ~/.local/bin › " \
          --placeholder "e.g. bin or scripts")
        [[ -z "$bash_package" ]] && bash_package="bin"
      fi
    fi
  fi

  # ══════════════════════════════════════════════════════════════════════════
  # STEP 3 — Sections (single multi-select screen)
  # ══════════════════════════════════════════════════════════════════════════
  hdr "Step 3 — Sections"

  # Helper: short status badge
  _b() { has "$1" && printf "✓" || printf "✗"; }
  # Helper: section line — fixed-width, no emojis (avoids terminal width issues)
  # format: "[cat]  Label                   status"
  _sec() {
    local cat="$1" label="$2"; shift 2
    local status=""
    local ok=true
    for t in "$@"; do
      has "$t" && status+="✓$t " || { status+="✗$t "; ok=false; }
    done
    printf "%-8s %-30s %s" "[$cat]" "$label" "$status"
  }

  local -a _sec_list=(
    "$(_sec nav  "Browse files"            fd bat)"
    "$(_sec nav  "Browse directories (cd)" fd fzf)"
    "$(_sec nav  "Search file contents"    rg fzf)"
    "$(_sec dev  "Docker"                  docker)"
    "$(_sec dev  "Django (current project)" )"
    "$(_sec dev  "Python venvs / uv"       python3)"
    "$(_sec dev  "Git"                     git)"
    "$(_sec dev  "Tmux / Sesh"             sesh tmux)"
    "$(_sec sys  "System logs"             journalctl)"
    "$(_sec sys  "Systemd services"        systemctl)"
    "$(_sec sys  "Backup (rsync)"          rsync)"
    "$(_sec net  "Ports / Connections"     ss)"
    "$(_sec net  "SSH"                     ssh)"
    "$(_sec net  "WireGuard"               wgs)"
    "$(_sec tool "Cheat sheets (cht.sh)"   curl)"
    "$(_sec tool "Weather (wttr.in)"       curl)"
  )

  # Pre-select entries where all required tools present (no ✗ in line)
  local _preselected=""
  for _s in "${_sec_list[@]}"; do
    # Django has no tools (always selectable), others check for ✗
    if [[ "$_s" == *"Django"* ]] || [[ "$_s" != *"✗"* ]]; then
      _preselected+="${_s},"
    fi
  done

  echo ""
  gum style --foreground 245 \
    "  Space to toggle · Enter to confirm · Processes + Env vars always on"
  echo ""

  local _chosen
  _chosen=$(printf '%s\n' "${_sec_list[@]}" \
    | gum choose --no-limit \
        --header "  Select sections to enable" \
        --height 20 \
        --selected="$_preselected")

  # Map selections back to booleans
  echo "$_chosen" | grep -q "Browse files"             && nav_files=true
  echo "$_chosen" | grep -q "Browse directories"       && nav_dirs=true
  echo "$_chosen" | grep -q "Search file contents"     && nav_text=true
  echo "$_chosen" | grep -q "Docker"                   && dev_docker=true
  echo "$_chosen" | grep -q "Django"                   && dev_django=true
  echo "$_chosen" | grep -q "Python venvs"             && dev_python=true
  echo "$_chosen" | grep -qw "Git"                     && dev_git=true
  echo "$_chosen" | grep -q "Tmux"                     && dev_tmux=true
  echo "$_chosen" | grep -q "System logs"              && sys_logs=true
  echo "$_chosen" | grep -q "Systemd"                  && sys_systemd=true
  echo "$_chosen" | grep -q "Backup"                   && sys_backup=true
  echo "$_chosen" | grep -q "Ports"                    && net_ports=true
  echo "$_chosen" | grep -qw "SSH"                     && net_ssh=true
  echo "$_chosen" | grep -q "WireGuard"                && net_wg=true
  echo "$_chosen" | grep -q "Cheat sheets"             && tool_cheat=true
  echo "$_chosen" | grep -q "Weather"                  && tool_weather=true

  # sshub integration (optional SSH host manager)
  if [[ "$net_ssh" == true ]] && has sshub; then
    if gum confirm "Use sshub as the SSH host manager (hosts, tunnels, sftp)?"; then
      use_sshub=true
    fi
  fi

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
      gum style --bold "  Django"
      django_log=$(gum input \
        --value "logs/django.log" \
        --prompt "  log path (relative to \$PWD) › " \
        --placeholder "logs/django.log")
      [[ -z "$django_log" ]] && django_log="logs/django.log"
      ok "Django log: $django_log"
    fi

    # ── SSH config path ───────────────────────────────────────────────────
    if [[ "$net_ssh" == true ]]; then
      echo ""
      gum style --bold "  SSH"
      if [[ "$use_sshub" == true ]]; then
        gum style --foreground 245 "  sshub detected — rig will use sshub for host management."
      fi
      ssh_config=$(gum input \
        --value "$HOME/.ssh/config" \
        --prompt "  SSH config path › " \
        --placeholder "$HOME/.ssh/config")
      [[ -z "$ssh_config" ]] && ssh_config="$HOME/.ssh/config"
      ok "SSH config: $ssh_config"
    fi

    # ── Custom log files ──────────────────────────────────────────────────
    if [[ "$sys_logs" == true ]]; then
      echo ""
      gum style --bold "  System logs — custom log files"
      gum style --foreground 245 "  Add label + path pairs. Leave label empty to finish."
      echo ""
      while true; do
        local _lbl
        _lbl=$(gum input --placeholder "Label (e.g. nginx error) — empty to finish" \
          --prompt "  label › ")
        [[ -z "$_lbl" ]] && break
        local _lpath
        _lpath=$(gum input --placeholder "/var/log/..." --prompt "  path  › ")
        [[ -z "$_lpath" ]] && break
        [[ -z "$log_files" ]] && log_files="${_lbl}:${_lpath}" \
                               || log_files="${log_files}|${_lbl}:${_lpath}"
        ok "Added: $_lbl → $_lpath"
      done
    fi

    # ── Weather cities ────────────────────────────────────────────────────
    if [[ "$tool_weather" == true ]]; then
      echo ""
      gum style --bold "  Weather cities"
      gum style --foreground 245 "  Quick-select cities in rig. Leave empty to always prompt manually."
      echo ""
      while true; do
        local _city
        _city=$(gum input --placeholder "City name — empty to finish" --prompt "  city › ")
        [[ -z "$_city" ]] && break
        [[ -z "$weather_cities" ]] && weather_cities="$_city" \
                                   || weather_cities="${weather_cities}|${_city}"
        ok "Added: $_city"
      done
    fi

    # ── Backup ────────────────────────────────────────────────────────────
    if [[ "$sys_backup" == true ]]; then
      echo ""
      gum style --bold "  Backup (rsync)"

      backup_source=$(gum input \
        --value "$HOME" \
        --prompt "  source dir › " \
        --placeholder "Directory to back up")
      [[ -z "$backup_source" ]] && backup_source="$HOME"
      ok "Source: $backup_source"

      echo ""
      gum style --foreground 245 "  Add destinations — SSH host picker or manual."
      gum style --foreground 245 "  Choose Done when finished."
      echo ""
      while true; do
        local _dest_type
        if [[ -f "${ssh_config:-$HOME/.ssh/config}" ]]; then
          _dest_type=$(gum choose \
            --header "  Add backup destination" \
            "🔌  Pick SSH host from config" \
            "✏️   Type manually" \
            "✅  Done")
        else
          _dest_type=$(gum choose \
            --header "  Add backup destination" \
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
            _rpath=$(gum input --value "/home/$USER" \
              --prompt "  remote path › " --placeholder "Remote directory")
            [[ -z "$_rpath" ]] && continue
            local _dest="${_host}:${_rpath}"
            [[ -z "$backup_destinations" ]] && backup_destinations="$_dest" \
                                            || backup_destinations="${backup_destinations}|${_dest}"
            ok "Added: $_dest" ;;
          "✏️"*)
            local _dest
            _dest=$(gum input \
              --placeholder "user@host:/path  or  /mnt/drive — empty to finish" \
              --prompt "  destination › ")
            [[ -z "$_dest" ]] && break
            [[ -z "$backup_destinations" ]] && backup_destinations="$_dest" \
                                            || backup_destinations="${backup_destinations}|${_dest}"
            ok "Added: $_dest" ;;
          "✅"*|"") break ;;
        esac
      done

      backup_excludes_file="$HOME/rsync_exclude.txt"
      echo ""
      gum style --bold "  Rsync excludes file"

      # Ask where the excludes file should live
      local _excl_choice
      _excl_choice=$(gum choose \
        --header "  Excludes file — what do you want to do?" \
        "Generate at ~/rsync_exclude.txt (recommended)" \
        "Use existing file (enter path)" \
        "Skip — no excludes file")

      case "$_excl_choice" in
        "Generate"*)
          backup_excludes_file="$HOME/rsync_exclude.txt"
          # Copy from script dir if available, otherwise generate inline
          if [[ -f "$SCRIPT_DIR/rsync_exclude.txt" ]]; then
            cp "$SCRIPT_DIR/rsync_exclude.txt" "$backup_excludes_file"
          else
            cat > "$backup_excludes_file" << 'EXCLUDES'
# rsync exclude file for rig backup
# Edit this file to customise what gets excluded.

# System caches
.cache
.local/share/Trash
.local/share/gvfs-metadata

# Desktop / Graphics
.local/share/vulkan
.local/share/gstreamer-1.0

# Flatpak & containers
.local/share/flatpak
.local/share/containers
.docker

# Browser caches
.mozilla/firefox/*/Cache
.config/chromium/Default/Cache

# Gaming
.steam
.local/share/Steam

# Python
.local/share/virtualenv
.local/share/virtualenvs
.local/share/uv
.local/share/pipx
__pycache__
.mypy_cache
.venv
.pytest_cache
.pyenv

# Node / JS
node_modules
.npm
.bun

# Rust
.cargo
.rustup

# Go
/go

# Java / Android
.gradle
.m2
.android

# C/C++
.vcpkg

# Zsh compiled files
.zcompdump*
*.zwc

# Docs (regeneratable)
.local/share/man
EXCLUDES
          fi
          ok "Generated: $backup_excludes_file"
          gum style --foreground 245 "  Edit ~/rsync_exclude.txt to customise exclusions."
          ;;
        "Use existing"*)
          backup_excludes_file=$(gum input \
            --value "$HOME/rsync_exclude.txt" \
            --prompt "  excludes file path › " \
            --placeholder "Absolute path to excludes file")
          [[ -z "$backup_excludes_file" ]] && backup_excludes_file="$HOME/rsync_exclude.txt"
          backup_excludes_file="${backup_excludes_file/#\~/$HOME}"
          if [[ -f "$backup_excludes_file" ]]; then
            ok "Using: $backup_excludes_file"
          else
            warn "File not found: $backup_excludes_file — will be skipped at runtime"
          fi
          ;;
        "Skip"*)
          backup_excludes_file=""
          warn "No excludes file — all files in source will be backed up"
          ;;
      esac
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
RIG_DEV_TMUX=${dev_tmux}
RIG_TEMPLATES_DIR="${XDG_CONFIG_HOME:-\$HOME/.config}/rig/templates"

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

# ── SSH host manager ─────────────────────────────────────────────────────────
RIG_USE_SSHUB=${use_sshub}

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

# ── Hosts ─────────────────────────────────────────────────────────────────────
# Saved rig hosts file (name|user|host|port|description)
RIG_HOSTS_FILE="${XDG_CONFIG_HOME:-\$HOME/.config}/rig/hosts.conf"
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
      gum style --foreground 245 "  Add to ~/.zshrc:"
      gum style --foreground 212 "  $zsh_src"
      echo ""
      if gum confirm "Add source line to ~/.zshrc?
  $zsh_src"; then
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
      gum style --foreground 245 "  For cd to work in bash, add to ~/.bashrc:"
      gum style --foreground 212 "  $bash_src"
      echo ""
      if gum confirm "Add source line to ~/.bashrc?
  $bash_src"; then
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

  # ── workflow templates ────────────────────────────────────────────────────
  local tpl_dir="${XDG_CONFIG_HOME:-$HOME/.config}/rig/templates"
  mkdir -p "$tpl_dir"
  local _tpl_copied=0
  # Look for templates in $SCRIPT_DIR/templates/ subdirectory
  if [[ -d "$SCRIPT_DIR/templates" ]]; then
    cp "$SCRIPT_DIR/templates/"*.sh "$tpl_dir/" 2>/dev/null && _tpl_copied=1
  fi
  # Also check root of script dir (in case templates are not in a subdir)
  for _f in "$SCRIPT_DIR/django-dev.sh" "$SCRIPT_DIR/generic-dev.sh"; do
    [[ -f "$_f" ]] && { cp "$_f" "$tpl_dir/"; _tpl_copied=1; }
  done
  if [[ "$_tpl_copied" -eq 1 ]]; then
    chmod +x "$tpl_dir/"*.sh 2>/dev/null
    ok "Templates → $tpl_dir"
  else
    warn "No templates found in $SCRIPT_DIR — copy .sh files to $tpl_dir/ manually"
  fi
  gum style --foreground 245 "  Add custom templates as .sh files in $tpl_dir/"
  gum style --foreground 245 "  Or place them in .rig/ inside any project directory."

  # ── Source shell rc files ─────────────────────────────────────────────────
  echo ""
  hdr "Reloading shell"
  if [[ "$install_zsh" == true && -f "$HOME/.zshrc" ]]; then
    if gum confirm "Reload ~/.zshrc now? (runs: source ~/.zshrc)"; then
      # We can't source from inside a script (different process), so write a
      # helper that the user can run, and print the command clearly
      gum style --foreground 212 "  Run this in your current terminal:"
      gum style --foreground 82  "    source ~/.zshrc"
      gum style --foreground 245 "  (install.sh runs in a subshell — it cannot reload your shell for you)"
    fi
  fi
  if [[ "$install_bash" == true && -f "$HOME/.bashrc" ]]; then
    if gum confirm "Reload ~/.bashrc now? (runs: source ~/.bashrc)"; then
      gum style --foreground 212 "  Run this in your current terminal:"
      gum style --foreground 82  "    source ~/.bashrc"
    fi
  fi

  # ── Done ─────────────────────────────────────────────────────────────────
  echo ""
  gum style \
    --border rounded --border-foreground 82 \
    --padding "1 4" --margin "1 2" \
    --bold "✓ rig installed"

  info "Launch:      rig"
  [[ "$install_zsh"  == true ]] && info "Keybinding:  Ctrl+Space (from any zsh prompt)"
  [[ "$install_bash" == true ]] && info "Bash cd:     source ~/.local/bin/rig"
  info "Reconfigure: ./install.sh"
  echo ""
  echo ""
  gum style --foreground 214 --bold "  → Don't forget to reload your shell:"
  [[ "$install_zsh"  == true ]] && gum style --foreground 82 "    source ~/.zshrc"
  [[ "$install_bash" == true ]] && gum style --foreground 82 "    source ~/.bashrc"
  echo ""
}

main "$@"
