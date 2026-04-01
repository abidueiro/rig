#!/usr/bin/env bash
# =============================================================================
# rig — Terminal Resource Interactive Guide (bash version)
# For servers and environments without zsh.
#
# IMPORTANT: for "cd" to work in the parent shell, add one of these to .bashrc:
#   source ~/.local/bin/rig          (source the script as a function)
#   alias rig='. ~/.local/bin/rig'   (alias that forces sourcing)
#
# Running as a plain script also works (except the cd section).
# =============================================================================

rig() {

  # ── Load configuration ────────────────────────────────────────────────────
  local _conf="${XDG_CONFIG_HOME:-$HOME/.config}/rig/rig.conf"
  if [[ -f "$_conf" ]]; then
    # shellcheck source=/dev/null
    source "$_conf"
  else
    # Defaults: everything enabled when no config file is present
    RIG_NAV_FILES=true; RIG_NAV_DIRS=true; RIG_NAV_TEXT=true
    RIG_DEV_DOCKER=true; RIG_DEV_DJANGO=true; RIG_DEV_PYTHON=true; RIG_DEV_GIT=true
    RIG_SYS_LOGS=true; RIG_SYS_SYSTEMD=true; RIG_SYS_PROCS=true
    RIG_NET_PORTS=true; RIG_NET_SSH=true; RIG_NET_WG=true
    RIG_TOOL_CHEAT=true; RIG_TOOL_ENV=true; RIG_TOOL_WEATHER=true
    RIG_DJANGO_LOG="logs/django.log"
  fi

  # ── Helpers ───────────────────────────────────────────────────────────────
  _has() { command -v "$1" &>/dev/null; }
  _ok()  { gum style --foreground 82  "  ✓ $*"; }
  _err() { gum style --foreground 196 "  ✗ $*"; sleep 1; }

  # ── Dynamic main menu ─────────────────────────────────────────────────────
  local -a _menu=()
  [[ "$RIG_NAV_FILES"    == true ]] && _menu+=("[nav]   📁  Browse files")
  [[ "$RIG_NAV_DIRS"     == true ]] && _menu+=("[nav]   📂  Browse directories (cd)")
  [[ "$RIG_NAV_TEXT"     == true ]] && _menu+=("[nav]   🔍  Search file contents")
  [[ "$RIG_DEV_DOCKER"   == true ]] && _menu+=("[dev]   🐋  Docker")
  [[ "$RIG_DEV_DJANGO"   == true ]] && _menu+=("[dev]   🐍  Django (current project)")
  [[ "$RIG_DEV_PYTHON"   == true ]] && _menu+=("[dev]   🐍  Python venvs")
  [[ "$RIG_DEV_GIT"      == true ]] && _menu+=("[dev]   🔀  Git")
  [[ "$RIG_SYS_LOGS"     == true ]] && _menu+=("[sys]   📋  System logs")
  [[ "$RIG_SYS_SYSTEMD"  == true ]] && _menu+=("[sys]   ⚙️   Systemd services")
  [[ "$RIG_SYS_PROCS"    == true ]] && _menu+=("[sys]   🖥️   Processes")
  [[ "$RIG_NET_PORTS"    == true ]] && _menu+=("[net]   🖧   Ports / Connections")
  [[ "$RIG_NET_SSH"      == true ]] && _menu+=("[net]   🔌  SSH")
  [[ "$RIG_NET_WG"       == true ]] && _menu+=("[net]   🔒  WireGuard (wgs)")
  [[ "$RIG_TOOL_CHEAT"   == true ]] && _menu+=("[tool]  📖  Cheat sheets")
  [[ "$RIG_TOOL_ENV"     == true ]] && _menu+=("[tool]  🌿  Environment variables")
  [[ "$RIG_TOOL_WEATHER" == true ]] && _menu+=("[tool]  🌤️   Weather (wttr.in)")

  local section
  section=$(printf '%s\n' "${_menu[@]}" \
    | gum filter \
        --header "  rig — type to filter · [nav] [dev] [sys] [net] [tool]" \
        --placeholder "search..." \
        --height 20)

  [[ -z "$section" ]] && return 0

  case "$section" in

  # ── Files ─────────────────────────────────────────────────────
  *"Browse files")
    local scope
    scope=$(gum choose --header "  Browse files from..." "Current directory" "Home (~)")
    case "$scope" in
      "Current directory")
        fd -t f --exclude .git --exclude node_modules --exclude __pycache__ \
          --exclude .venv --exclude target --exclude .cache . 2>/dev/null \
          | fzf --preview 'bat -n --color=always --line-range :100 {}' \
                --preview-window 'right:60%' --height 80% --border \
                --header 'ctrl-o: open in Zed | Enter: print path' \
                --bind 'ctrl-o:execute(zed {} &)'
        ;;
      "Home (~)")
        fd -t f --exclude .git --exclude node_modules --exclude __pycache__ \
          --exclude .venv ~ 2>/dev/null \
          | fzf --preview 'bat -n --color=always --line-range :100 {}' \
                --preview-window 'right:60%' --height 80% --border
        ;;
    esac
    ;;

  # ── Directories + cd ──────────────────────────────────────────
  *"Browse directories (cd)")
    local scope
    scope=$(gum choose --header "  Navigate directories from..." \
      "Current directory" "Home (~)" "Zoxide (history)")
    local target_dir=""
    case "$scope" in
      "Current directory")
        target_dir=$(fd -t d --exclude .git --exclude node_modules \
          --exclude __pycache__ --exclude .venv . 2>/dev/null \
          | fzf --preview 'ls -la --color=always {}' --height 80% --border)
        [[ -n "$target_dir" ]] && target_dir="${PWD}/${target_dir}"
        ;;
      "Home (~)")
        target_dir=$(fd -t d --exclude .git --exclude node_modules \
          --exclude __pycache__ --exclude .venv ~ 2>/dev/null \
          | fzf --preview 'ls -la --color=always {}' --height 80% --border)
        ;;
      "Zoxide (history)")
        _has zoxide && target_dir=$(zoxide query --interactive 2>/dev/null) \
          || { _err "zoxide is not installed"; return 1; }
        ;;
    esac
    target_dir=$(echo "$target_dir" | tr -d '\n')
    if [[ -n "$target_dir" && -d "$target_dir" ]]; then
      cd "$target_dir" && echo "  → $target_dir"
    fi
    ;;

  # ── File content search ───────────────────────────────────────
  *"Search file contents")
    local scope
    scope=$(gum choose --header "  Search text in..." "Current directory" "Home (~)")
    local _search_dir="."
    [[ "$scope" == "Home (~)" ]] && _search_dir="$HOME"
    local selection
    selection=$(rg --column --line-number --no-heading --color=always --smart-case \
      --hidden --follow \
      -g '!*.git*' -g '!node_modules' -g '!__pycache__' -g '!.venv' \
      "$_search_dir" 2>/dev/null \
      | fzf --ansi \
            --preview 'bat --style=numbers --color=always {1} --highlight-line {2} 2>/dev/null' \
            --preview-window 'right:60%:+{2}+3/3' \
            --delimiter ':' \
            --header 'Recursive search | Enter: select' \
            --height 80% --border)
    if [[ -n "$selection" ]]; then
      local file line
      file=$(echo "$selection" | cut -d':' -f1)
      line=$(echo "$selection" | cut -d':' -f2)
      echo "📄 $file:$line"
    fi
    ;;

  # ── Docker ────────────────────────────────────────────────────
  *"Docker")
    local docker_action
    docker_action=$(gum choose --header "  Docker" \
      "📋  Containers (inspect / logs / shell / restart / stop)" \
      "📦  Images" "🌐  Networks" "💾  Volumes" \
      "📝  docker-compose current project")
    case "$docker_action" in
      "📋  Containers"*)
        _has tv && tv docker-all || {
          docker ps -a --format '{{.Names}}\t{{.Status}}\t{{.Image}}' \
            | fzf --header 'Esc: exit' --height 80% --border \
                  --preview 'docker inspect {1} | bat -l json --color=always --line-range :40'
        }
        ;;
      "📦  Images")
        docker images --format '{{.Repository}}:{{.Tag}}\t{{.Size}}\t{{.ID}}' \
          | fzf --height 80% --border \
                --preview 'docker inspect $(echo {} | cut -f3) | bat -l json --color=always'
        ;;
      "🌐  Networks")
        docker network ls | fzf --height 80% --border \
          --preview 'docker network inspect $(echo {} | awk "{print \$1}") | bat -l json --color=always'
        ;;
      "💾  Volumes")
        docker volume ls | fzf --height 80% --border
        ;;
      "📝  docker-compose"*)
        if [[ -f "docker-compose.yml" || -f "compose.yml" ]]; then
          docker compose ps | fzf --height 80% --border
        else
          _err "No docker-compose.yml found in current directory"
        fi
        ;;
    esac
    ;;

  # ── System logs ───────────────────────────────────────────────
  *"System logs")
    local _log_opts=(
      "journalctl — search services"
      "journalctl — follow service live"
      "systemd — boot log"
      "kernel — dmesg"
    )
    local _log_labels=() _log_paths=()
    if [[ -n "${RIG_LOG_FILES:-}" ]]; then
      local IFS='|'
      for _entry in $RIG_LOG_FILES; do
        local _label="${_entry%%:*}"
        local _path="${_entry#*:}"
        _log_labels+=("$_label")
        _log_paths+=("$_path")
        _log_opts+=("$_label")
      done
      unset IFS
    fi

    local log_choice
    log_choice=$(gum choose --header "  System logs — which one?" "${_log_opts[@]}")
    case "$log_choice" in
      "journalctl — search services")
        local unit
        unit=$(systemctl list-units --type=service --all --no-pager --plain 2>/dev/null \
          | awk 'NR>1 && NF>1 {print $1}' \
          | fzf --preview 'journalctl -u {} --no-pager -n 30 --output=short-precise 2>/dev/null' \
                --preview-window 'right:60%' --height 80% --border \
                --header 'Esc: exit | Enter: select service')
        [[ -n "$unit" ]] && journalctl -u "$unit" -f --output=short-precise
        ;;
      "journalctl — follow service live")
        local unit
        unit=$(systemctl list-units --type=service --all --no-pager --plain 2>/dev/null \
          | awk 'NR>1 && NF>1 {print $1}' \
          | fzf --height 80% --border --header 'Select service | Esc: exit')
        [[ -n "$unit" ]] && journalctl -u "$unit" -f --output=short-precise
        ;;
      "systemd — boot log") _rig_log_menu "journalctl-boot" ;;
      "kernel — dmesg")     _rig_log_menu "dmesg" ;;
      *)
        local _i=0
        for _lbl in "${_log_labels[@]}"; do
          if [[ "$log_choice" == "$_lbl" ]]; then
            _rig_log_menu "${_log_paths[$_i]}"
            break
          fi
          (( _i++ ))
        done
        ;;
    esac
    ;;

  # ── Systemd services ──────────────────────────────────────────
  *"Systemd services")
    while true; do
      local service_action
      service_action=$(gum choose --header "  Systemd (Esc: back)" \
        "🔍  All services" "🟢  Active (running)" "🔴  Failed")
      [[ -z "$service_action" ]] && break
      local list_cmd=""
      case "$service_action" in
        "🔍"*) list_cmd="systemctl list-units --type=service --all --no-pager --plain 2>/dev/null | awk 'NR>1 && NF>1 {print \$1, \$3, \$4}'" ;;
        "🟢"*) list_cmd="systemctl list-units --type=service --state=running --no-pager --plain 2>/dev/null | awk 'NR>1 && NF>1 {print \$1, \$3, \$4}'" ;;
        "🔴"*) list_cmd="systemctl list-units --type=service --state=failed --no-pager --plain 2>/dev/null | awk 'NR>1 && NF>1 {print \$1, \$3, \$4}'" ;;
      esac
      local selected
      selected=$(eval "$list_cmd" | fzf \
        --preview 'systemctl status {1} 2>/dev/null | head -20' \
        --preview-window 'right:60%' --height 80% --border \
        --header 'Esc: exit | Enter: manage service')
      [[ -z "$selected" ]] && continue
      local service svc_status
      service=$(echo "$selected" | awk '{print $1}')
      svc_status=$(echo "$selected" | awk '{print $2}')
      while true; do
        local action
        action=$(gum choose --header "  $service ($svc_status)" \
          "▶️  Start" "⏹️  Stop" "🔄  Restart" "📊  Status" \
          "⚡  Enable" "🚫  Disable" "🔙  Back")
        [[ -z "$action" || "$action" == *"Back"* ]] && break
        case "$action" in
          *"Start"*)   sudo systemctl start   "$service" && _ok "$service started"   || _err "Failed" ;;
          *"Stop"*)    sudo systemctl stop    "$service" && _ok "$service stopped"   || _err "Failed" ;;
          *"Restart"*) sudo systemctl restart "$service" && _ok "$service restarted" || _err "Failed" ;;
          *"Status"*)  systemctl status "$service" | less -R ;;
          *"Enable"*)  sudo systemctl enable  "$service" && _ok "Enabled"  || _err "Failed" ;;
          *"Disable"*) sudo systemctl disable "$service" && _ok "Disabled" || _err "Failed" ;;
        esac
        sleep 1
      done
    done
    ;;

  # ── Django ────────────────────────────────────────────────────
  *"Django (current project)")
    local django_log="${RIG_DJANGO_LOG:-logs/django.log}"
    if [[ ! -f "$django_log" ]]; then
      _err "Log not found: $PWD/$django_log"; return 1
    fi
    local django_action
    django_action=$(gum choose --header "  Django logs — $PWD/$django_log" \
      "Search in logs" "Follow live" "Last 200 lines" \
      "Errors and exceptions only" "Warnings only")
    case "$django_action" in
      "Search in logs")
        cat "$django_log" | fzf --ansi --height 80% --border ;;
      "Follow live"*)
        less +F "$django_log" ;;
      "Last 200 lines"*)
        tail -200 "$django_log" | bat --color=always -l log ;;
      "Errors and exceptions only")
        grep -iE "error|exception|traceback|critical" "$django_log" \
          | fzf --ansi --height 80% --border ;;
      "Warnings only")
        grep -iE "warning|warn" "$django_log" \
          | grep -viE "error|exception|traceback|critical" \
          | fzf --ansi --height 80% --border ;;
    esac
    ;;

  # ── Python venvs ──────────────────────────────────────────────
  *"Python venvs")
    local venv_action
    venv_action=$(gum choose --header "  Python venvs" \
      "List ~/.venvs" "List venvs in project" \
      "Search venvs in ~" "Create new venv")
    [[ -z "$venv_action" ]] && return 0
    local selected=""
    case "$venv_action" in
      "List ~/.venvs")
        [[ -d "$HOME/.venvs" ]] || { _err "~/.venvs does not exist"; return 1; }
        selected=$(ls -1 "$HOME/.venvs" 2>/dev/null \
          | fzf --height 80% --border --header 'Select venv to activate | Esc: exit')
        [[ -n "$selected" ]] && source "$HOME/.venvs/$selected/bin/activate" && _ok "Activated: $selected"
        ;;
      "List venvs in project")
        selected=$(find . -maxdepth 3 -type d \( -name ".venv" -o -name "venv" -o -name "env" \) 2>/dev/null \
          | fzf --preview 'ls -la {}/bin 2>/dev/null | head -10' --height 80% --border)
        [[ -n "$selected" ]] && source "$selected/bin/activate" && _ok "Activated: $selected"
        ;;
      "Search venvs in ~")
        selected=$(find ~ -maxdepth 5 -type d \( -name ".venv" -o -name "venv" \) 2>/dev/null \
          | head -30 | fzf --height 80% --border)
        [[ -n "$selected" ]] && source "$selected/bin/activate" && _ok "Activated: $selected"
        ;;
      "Create new venv")
        local venv_name
        venv_name=$(gum input --placeholder "Venv name (e.g. .venv)")
        [[ -z "$venv_name" ]] && return 0
        if _has uv; then
          uv venv "$venv_name" && _ok "Created with uv: $venv_name"
        else
          python3 -m venv "$venv_name" && _ok "Created: $venv_name"
        fi
        gum confirm "Activate now?" && source "$venv_name/bin/activate" && _ok "Activated"
        ;;
    esac
    ;;

  # ── Git ───────────────────────────────────────────────────────
  *"Git")
    if ! git rev-parse --git-dir &>/dev/null; then
      _err "Not inside a git repository"; return 1
    fi
    local repo_name
    repo_name=$(git rev-parse --show-toplevel | xargs basename)
    local git_action
    git_action=$(gum choose --header "  Git — $repo_name" \
      "Log — search commits" "Branches — checkout" \
      "Stash — view and apply" "Modified files" "Git repos in ~")
    case "$git_action" in
      "Log"*)
        git log --oneline --color=always \
          | fzf --ansi \
                --preview 'git show $(echo {} | awk "{print \$1}") --stat --color=always' \
                --preview-window 'right:60%' --height 80% --border \
                --bind 'ctrl-o:execute(git show $(echo {} | awk "{print \$1}") --color=always | less -R)'
        ;;
      "Branches"*)
        local branch
        branch=$(git branch -a --color=never | sed 's/^[* ]*//' | grep -v HEAD \
          | fzf --preview 'git log --oneline --color=always -15 {}' \
                --preview-window 'right:60%' --height 80% --border)
        [[ -n "$branch" ]] && git checkout "${branch#remotes/origin/}"
        ;;
      "Stash"*)
        local stash
        stash=$(git stash list \
          | fzf --preview 'git stash show -p --color=always $(echo {} | grep -o "stash@{[0-9]*}")' \
                --preview-window 'right:60%' --height 80% --border)
        if [[ -n "$stash" ]]; then
          local stash_ref
          stash_ref=$(echo "$stash" | grep -o 'stash@{[0-9]*}')
          local stash_action
          stash_action=$(gum choose --header "  $stash_ref" "apply (keep stash)" "pop (remove stash)")
          [[ "$stash_action" == "apply"* ]] && git stash apply "$stash_ref"
          [[ "$stash_action" == "pop"*   ]] && git stash pop   "$stash_ref"
        fi
        ;;
      "Modified files")
        git status --short \
          | fzf --preview 'git diff --color=always -- $(echo {} | awk "{print \$2}")' \
                --preview-window 'right:65%' --height 80% --border
        ;;
      "Git repos in ~")
        _has tv && tv git-repos || \
          find ~ -maxdepth 4 -name ".git" -type d 2>/dev/null \
            | sed 's|/.git$||' | fzf --height 80% --border
        ;;
    esac
    ;;

  # ── Processes ─────────────────────────────────────────────────
  *"Processes")
    while true; do
      local proc_action
      proc_action=$(gum choose --header "  Processes (Esc: back)" \
        "Browse and manage" "Top by CPU" "Top by memory")
      [[ -z "$proc_action" ]] && break
      local sort_key="%cpu"
      [[ "$proc_action" == *"memory"* ]] && sort_key="%mem"
      local selected
      selected=$(ps aux --sort=-${sort_key} 2>/dev/null \
        | fzf --header 'Enter: manage | Esc: back' \
              --preview 'echo {} | awk "{print \$2}" | xargs -I% sh -c "ps -f -p % 2>/dev/null"' \
              --preview-window 'right:50%' --height 80% --border)
      [[ -z "$selected" ]] && break
      local pid pname
      pid=$(echo "$selected" | awk '{print $2}')
      pname=$(echo "$selected" | awk '{print $11}')
      [[ "$pid" =~ ^[0-9]+$ ]] && _rig_process_menu "$pid" "$pname"
    done
    ;;

  # ── Ports / Connections ───────────────────────────────────────
  *"Ports / Connections")
    local port_action
    port_action=$(gum choose --header "  Ports" \
      "Listening ports (ss -tulpn)" \
      "Established connections (ss -tunp)" \
      "All connections by state (ss -tunap)")
    [[ -z "$port_action" ]] && return 0
    case "$port_action" in
      *"Listening"*)
        ss -tulpn 2>/dev/null | grep -v "^Netid" \
          | fzf --height 80% --border \
                --preview 'echo {} | grep -oP "pid=\K[0-9]+" | xargs -I% sh -c "ps -f -p % 2>/dev/null || echo No info"' \
                --preview-window 'right:50%' \
                --header 'Esc: exit | Enter: inspect process'
        ;;
      *"Established"*) ss -tunp  2>/dev/null | less -S ;;
      *"state"*)       ss -tunap 2>/dev/null | less -S ;;
    esac
    ;;

  # ── SSH ───────────────────────────────────────────────────────
  *"SSH")
    local ssh_config="${RIG_SSH_CONFIG:-$HOME/.ssh/config}"
    local host
    host=$(grep -E '^Host ' "$ssh_config" 2>/dev/null \
      | grep -v '[*?]' | awk '{print $2}' \
      | fzf --preview "grep -A 10 \"^Host {}$\" $ssh_config" \
            --preview-window 'right:50%' --height 80% --border \
            --header 'Enter: connect | Esc: exit')
    if [[ -n "$host" ]]; then
      local action
      action=$(gum choose --header "  SSH → $host" "Connect" "New tmux window")
      case "$action" in
        "Connect")          ssh "$host" ;;
        "New tmux window")  tmux new-window -n "$host" "ssh $host" ;;
      esac
    fi
    ;;

  # ── WireGuard ─────────────────────────────────────────────────
  *"WireGuard"*)
    if _has wgs; then
      wgs
    else
      sudo wg show all 2>/dev/null | bat -l ini --color=always || sudo wg show
    fi
    ;;

  # ── Cheat sheets ──────────────────────────────────────────────
  *"Cheat sheets")
    gum style --foreground 214 "  Loading cht.sh command list..."
    local cmds
    cmds=$(curl -sL https://cht.sh/:list 2>/dev/null | grep -v '^:' | grep -v '^$' | sort)
    if [[ -z "$cmds" ]]; then
      _err "Could not connect to cheat.sh"; return 1
    fi
    while true; do
      local cmd
      cmd=$(echo "$cmds" | fzf \
        --preview 'bash -c "curl -sL https://cht.sh/{} 2>/dev/null | head -50"' \
        --preview-window 'right:60%' --height 80% --border \
        --header 'Search command | Enter: view cheatsheet | Esc: exit')
      [[ -z "$cmd" ]] && break
      curl -sL "https://cht.sh/$cmd" 2>/dev/null | less -R
    done
    ;;

  # ── Environment variables ─────────────────────────────────────
  *"Environment variables")
    _has tv && tv env || printenv | sort | fzf --height 80% --border
    ;;

  # ── Weather ───────────────────────────────────────────────────
  *"Weather"*)
    local location=""
    if [[ -n "${RIG_WEATHER_CITIES:-}" ]]; then
      local _city_menu=()
      local IFS='|'
      for _city in $RIG_WEATHER_CITIES; do
        _city_menu+=("$_city")
      done
      unset IFS
      _city_menu+=("Enter location manually")
      local weather_action
      weather_action=$(gum choose \
        --header "  Weather — choose location" \
        "${_city_menu[@]}")
      [[ -z "$weather_action" ]] && return 0
      if [[ "$weather_action" == "Enter location manually" ]]; then
        location=$(gum input --placeholder "City (e.g. London, Tokyo, Berlin)...")
      else
        location="$weather_action"
      fi
    else
      location=$(gum input --placeholder "City (e.g. London, Tokyo, Berlin)...")
    fi
    [[ -z "$location" ]] && return 0
    gum style --foreground 214 "  Fetching weather for $location..."
    curl -s "wttr.in/$location" 2>/dev/null | less -R
    ;;

  esac
}

# ── Helper: log viewer with two modes — search or follow live ─────────────────
_rig_log_menu() {
  local name="$1"
  local needs_sudo=false
  case "$name" in /var/log*|*nginx*|*apache*|dmesg) needs_sudo=true ;; esac

  local action
  action=$(gum choose --header "  $name" \
    "Search (fzf)" "Follow live (tail -f)")

  local log_content=""
  case "$action" in
    "Search"*)
      case "$name" in
        journalctl-boot) log_content=$(journalctl -b --no-pager 2>/dev/null) ;;
        dmesg) [[ "$needs_sudo" == true ]] && log_content=$(sudo dmesg) || log_content=$(dmesg) ;;
        *) [[ "$needs_sudo" == true ]] && log_content=$(sudo cat "$name") || log_content=$(cat "$name") ;;
      esac
      if [[ -n "$log_content" ]]; then
        echo "$log_content" | fzf --ansi --height 80% --border \
          --header 'Esc: exit'
      else
        gum style --foreground 196 "  Could not read $name (permission denied?)"; sleep 2
      fi
      ;;
    "Follow"*)
      echo "  📡 Following $name (Ctrl+C to stop)..."; sleep 1
      case "$name" in
        journalctl-boot) journalctl -b -f --output=short-precise ;;
        dmesg) [[ "$needs_sudo" == true ]] && sudo dmesg -w || dmesg -w ;;
        *) [[ "$needs_sudo" == true ]] && sudo tail -f "$name" || tail -f "$name" ;;
      esac
      ;;
  esac
}

# ── Helper: contextual process management menu ────────────────────────────────
_rig_process_menu() {
  local pid="$1" pname="$2"
  while true; do
    local action
    action=$(gum choose --header "  PID $pid ($pname)" \
      "Kill (SIGTERM)" "Kill (SIGKILL)" "View details" \
      "Process tree (pstree)" "Open files (lsof)" "Change priority" "Back")
    [[ -z "$action" || "$action" == "Back" ]] && return 0
    case "$action" in
      *"SIGTERM"*) kill    "$pid" 2>/dev/null && gum style --foreground 82 "  ✓ SIGTERM → $pid" || gum style --foreground 196 "  ✗ Failed"; sleep 1 ;;
      *"SIGKILL"*) kill -9 "$pid" 2>/dev/null && gum style --foreground 82 "  ✓ SIGKILL → $pid" || gum style --foreground 196 "  ✗ Failed"; sleep 1 ;;
      *"details"*) ps -f -p "$pid" 2>/dev/null | less -R ;;
      *"pstree"*)  pstree -p "$pid" 2>/dev/null | less -R ;;
      *"lsof"*)    lsof -p "$pid" 2>/dev/null | head -100 | less -R ;;
      *"priority"*)
        local nv
        nv=$(gum input --placeholder "Nice value (-20 to 19)")
        if [[ "$nv" =~ ^-?[0-9]+$ ]] && (( nv >= -20 && nv <= 19 )); then
          renice "$nv" -p "$pid" && gum style --foreground 82 "  ✓ Nice=$nv" \
            || gum style --foreground 196 "  ✗ Failed (permission denied?)"
        fi; sleep 1 ;;
    esac
  done
}

# ── Entry point ───────────────────────────────────────────────────────────────
# When executed as a script: call rig()
# When sourced: function is available in the current shell (cd works)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  rig "$@"
fi
