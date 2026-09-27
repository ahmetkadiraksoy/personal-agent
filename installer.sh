#!/usr/bin/env bash
set -Eeuo pipefail

APP_NAME="personal-agent"
REPO_URL="${PERSONAL_AGENT_REPO:-https://github.com/ahmetkadiraksoy/personal-agent.git}"
BRANCH="${PERSONAL_AGENT_BRANCH:-main}"

VERBOSE=0
for arg in "$@"; do
  case "$arg" in
    --verbose|-v) VERBOSE=1 ;;
    --help|-h)
      printf 'Usage: %s [--verbose]\n' "$(basename "$0")"
      printf '  --verbose, -v   Show full command output during installation.\n'
      exit 0
      ;;
    *) printf 'Error: unknown option: %s\n' "$arg" >&2; exit 2 ;;
  esac
done

LOG_FILE="$(mktemp "${TMPDIR:-/tmp}/personal-agent-install.XXXXXX.log")"

OS="$(uname -s)"
ARCH="$(uname -m)"

# Homebrew-like colors; automatically disabled for non-interactive output.
if [[ -t 1 ]]; then
  BOLD=$'\033[1m'; DIM=$'\033[2m'; RED=$'\033[31m'; GREEN=$'\033[32m'
  YELLOW=$'\033[33m'; BLUE=$'\033[34m'; RESET=$'\033[0m'
else
  BOLD=""; DIM=""; RED=""; GREEN=""; YELLOW=""; BLUE=""; RESET=""
fi

header(){ printf '\n%s%s==>%s %s%s%s\n' "$BOLD" "$BLUE" "$RESET" "$BOLD" "$*" "$RESET"; }
ok(){ printf '%s%s✓%s %s\n' "$BOLD" "$GREEN" "$RESET" "$*"; }
warn(){ printf '%s%sWarning:%s %s\n' "$BOLD" "$YELLOW" "$RESET" "$*" >&2; }
err(){ printf '%s%sError:%s %s\n' "$BOLD" "$RED" "$RESET" "$*" >&2; }
info(){ printf '%s\n' "$*"; }
die(){ err "$*"; exit 1; }
need(){ command -v "$1" >/dev/null 2>&1; }

tty_read(){
  # Interactive installer prompts must not read from stdin because the
  # supported one-line install method pipes the script into bash.
  [[ -r /dev/tty ]] || die "No interactive terminal is available for this prompt."
  read "$@" </dev/tty
}

run_cmd(){
  local description="$1"
  shift
  if (( VERBOSE )); then
    "$@" 2>&1 | tee -a "$LOG_FILE"
    local status=${PIPESTATUS[0]}
    (( status == 0 )) || { err "$description failed."; info "Installation log: $LOG_FILE"; return "$status"; }
  else
    if ! "$@" >>"$LOG_FILE" 2>&1; then
      err "$description failed."
      printf '\nLast 40 lines of installer output:\n' >&2
      tail -n 40 "$LOG_FILE" >&2 || true
      printf '\nFull installation log: %s\n' "$LOG_FILE" >&2
      return 1
    fi
  fi
}

cleanup(){
  [[ -n "${TMP_DIR:-}" && -d "${TMP_DIR:-}" ]] && rm -rf "$TMP_DIR" || true
  if [[ "${INSTALL_SUCCEEDED:-0}" == 1 && "$VERBOSE" == 0 ]]; then rm -f "$LOG_FILE" || true; fi
}
trap cleanup EXIT
trap 'die "Operation failed on line $LINENO."' ERR

[[ "${EUID:-$(id -u)}" -ne 0 ]] || die "Do not run this script as root. Run it as your normal user."

case "$OS" in
  Linux)
    PLATFORM="Linux"
    APP_DIR="${PERSONAL_AGENT_HOME:-$HOME/.local/lib/personal-agent}"
    CONFIG_DIR="${PERSONAL_AGENT_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/personal-agent}"
    DATA_DIR="${PERSONAL_AGENT_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/personal-agent}"
    CACHE_DIR="${PERSONAL_AGENT_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/personal-agent}"
    WORKSPACE_DIR="${PERSONAL_AGENT_WORKSPACE:-$HOME/PersonalAgent}"
    BIN_DIR="${XDG_BIN_HOME:-$HOME/.local/bin}"
    LEGACY_APP_DIR="$HOME/.local/lib/personal-agent"
    LEGACY_STATE_BACKUP="${XDG_DATA_HOME:-$HOME/.local/share}/personal-agent-preserved"
    SERVICE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
    SERVICE_FILE="$SERVICE_DIR/personal-agent.service"
    ;;
  Darwin)
    PLATFORM="macOS"
    SUPPORT_DIR="$HOME/Library/Application Support/PersonalAgent"
    APP_DIR="${PERSONAL_AGENT_HOME:-$SUPPORT_DIR/app}"
    CONFIG_DIR="${PERSONAL_AGENT_CONFIG_DIR:-$SUPPORT_DIR/config}"
    DATA_DIR="${PERSONAL_AGENT_DATA_DIR:-$SUPPORT_DIR/data}"
    CACHE_DIR="${PERSONAL_AGENT_CACHE_DIR:-$HOME/Library/Caches/PersonalAgent}"
    WORKSPACE_DIR="${PERSONAL_AGENT_WORKSPACE:-$HOME/PersonalAgent}"
    BIN_DIR="${PERSONAL_AGENT_BIN:-$HOME/.local/bin}"
    LEGACY_APP_DIR="$SUPPORT_DIR"
    LEGACY_STATE_BACKUP="$HOME/Library/Application Support/PersonalAgent-Preserved"
    SERVICE_DIR="$HOME/Library/LaunchAgents"
    SERVICE_FILE="$SERVICE_DIR/com.personalagent.server.plist"
    ;;
  *)
    die "Unsupported operating system: $OS. This installer supports Linux and macOS."
    ;;
esac
LAUNCHER="$BIN_DIR/agent"

printf '\n%sPersonal AI Agent%s\n' "$BOLD" "$RESET"
printf '%smacOS + Linux installer and lifecycle manager%s\n\n' "$DIM" "$RESET"
ok "Detected $PLATFORM ($ARCH)"

# Application code and user state are intentionally separated.
# Reinstall replaces APP_DIR only; config/data/cache/workspace remain in place.
mac_service_label="com.personalagent.server"

stop_service(){
  if [[ "$PLATFORM" == "Linux" ]]; then
    if need systemctl; then
      systemctl --user stop personal-agent.service >/dev/null 2>&1 || true
      systemctl --user disable personal-agent.service >/dev/null 2>&1 || true
    fi
  else
    if need launchctl; then
      launchctl bootout "gui/$(id -u)" "$SERVICE_FILE" >/dev/null 2>&1 || \
      launchctl unload "$SERVICE_FILE" >/dev/null 2>&1 || true
    fi
  fi
}

remove_service(){
  stop_service
  rm -f "$SERVICE_FILE"
  if [[ "$PLATFORM" == "Linux" ]] && need systemctl; then
    systemctl --user daemon-reload >/dev/null 2>&1 || true
    systemctl --user reset-failed >/dev/null 2>&1 || true
  fi
}

copy_if_missing(){
  local source="$1" destination="$2"
  [[ -e "$source" ]] || return 0
  [[ -e "$destination" ]] && return 0
  mkdir -p "$(dirname "$destination")"
  cp -a "$source" "$destination"
}

migrate_legacy_state_from(){
  local old="$1"
  [[ -d "$old" ]] || return 0
  header "Migrating existing personal state"
  mkdir -p "$CONFIG_DIR" "$DATA_DIR" "$CACHE_DIR" "$WORKSPACE_DIR"
  copy_if_missing "$old/.env" "$CONFIG_DIR/.env"
  copy_if_missing "$old/google_token.json" "$CONFIG_DIR/google_token.json"
  copy_if_missing "$old/credentials.json" "$CONFIG_DIR/credentials.json"
  for f in "$old"/client_secret*.json; do
    [[ -e "$f" ]] || continue
    copy_if_missing "$f" "$CONFIG_DIR/$(basename "$f")"
  done
  for name in agent.db notes.db memory.json rules.json; do
    copy_if_missing "$old/$name" "$DATA_DIR/$name"
  done
  for name in memory_embeddings.npz note_embeddings.npz; do
    copy_if_missing "$old/$name" "$CACHE_DIR/$name"
  done
  if [[ -d "$old/workspace" ]]; then
    cp -an "$old/workspace/." "$WORKSPACE_DIR/" 2>/dev/null || true
  fi
  [[ -f "$CONFIG_DIR/.env" ]] && chmod 600 "$CONFIG_DIR/.env" || true
  ok "Personal state migrated to the new separated layout"
}

migrate_legacy_state(){
  # Linux legacy state lived beside the code. macOS legacy code/state occupied
  # the parent of the new app/config/data directories, so stage it temporarily.
  if [[ "$PLATFORM" == "Darwin" && -f "$LEGACY_APP_DIR/agent-server" && ! -d "$APP_DIR" ]]; then
    local stage
    stage="$(mktemp -d)"
    for item in .env google_token.json credentials.json agent.db notes.db memory.json rules.json memory_embeddings.npz note_embeddings.npz workspace; do
      [[ -e "$LEGACY_APP_DIR/$item" ]] && cp -a "$LEGACY_APP_DIR/$item" "$stage/"
    done
    for f in "$LEGACY_APP_DIR"/client_secret*.json; do [[ -e "$f" ]] && cp -a "$f" "$stage/"; done
    rm -rf "$LEGACY_APP_DIR"
    migrate_legacy_state_from "$stage"
    rm -rf "$stage"
  elif [[ "$PLATFORM" == "Linux" && -d "$LEGACY_APP_DIR" ]]; then
    migrate_legacy_state_from "$LEGACY_APP_DIR"
  fi

  if [[ -d "$LEGACY_STATE_BACKUP" ]]; then
    migrate_legacy_state_from "$LEGACY_STATE_BACKUP"
    rm -rf "$LEGACY_STATE_BACKUP"
    ok "Old preserved-state directory migrated and removed"
  fi
}

remove_installation(){
  header "Remove Personal AI Agent"
  info "Choose what should happen to your personal data:"
  printf '\n  %s1)%s Remove app, %sKEEP%s settings/data/workspace for a future reinstall\n' "$BOLD" "$RESET" "$GREEN" "$RESET"
  printf '  %s2)%s %sCompletely remove everything%s\n' "$BOLD" "$RESET" "$RED" "$RESET"
  printf '  %s3)%s Cancel\n\n' "$BOLD" "$RESET"
  tty_read -r -p "Choice [1-3]: " choice

  case "$choice" in
    1)
      remove_service
      rm -f "$LAUNCHER"
      rm -rf "$APP_DIR"
      ok "Application removed; personal state retained"
      printf '  Config:    %s\n  Data:      %s\n  Cache:     %s\n  Workspace: %s\n' "$CONFIG_DIR" "$DATA_DIR" "$CACHE_DIR" "$WORKSPACE_DIR"
      ;;
    2)
      printf '\n%s%sThis permanently deletes the app, configuration, databases, memory, cache, credentials, and workspace.%s\n' "$BOLD" "$RED" "$RESET"
      tty_read -r -p "Type REMOVE to continue: " confirm
      [[ "$confirm" == "REMOVE" ]] || { warn "Removal cancelled."; exit 0; }
      remove_service
      rm -f "$LAUNCHER"
      rm -rf "$APP_DIR" "$CONFIG_DIR" "$DATA_DIR" "$CACHE_DIR" "$WORKSPACE_DIR" "$LEGACY_STATE_BACKUP"
      ok "Personal AI Agent and all associated local data removed"
      ;;
    *) info "Cancelled." ;;
  esac
  exit 0
}

# Migrate old single-directory installs before deciding whether this is a reinstall.
migrate_legacy_state

if [[ -e "$APP_DIR" ]]; then
  header "Existing installation detected"
  printf '  %s\n\n' "$APP_DIR"
  printf '  %s1)%s Reinstall / update application\n' "$BOLD" "$RESET"
  printf '  %s2)%s Remove application\n' "$BOLD" "$RESET"
  printf '  %s3)%s Cancel\n\n' "$BOLD" "$RESET"
  tty_read -r -p "Choice [1-3]: " choice
  case "$choice" in
    1)
      header "Preparing reinstall"
      stop_service
      rm -rf "$APP_DIR"
      ok "Existing program files removed; personal state left untouched"
      ;;
    2) remove_installation ;;
    *) info "Cancelled."; exit 0 ;;
  esac
fi

install_linux_prereqs(){
  need apt-get || return 1
  tty_read -r -p "Install required system packages with apt? [Y/n]: " a
  a="${a:-Y}"
  [[ "$a" =~ ^[Yy]$ ]] || die "Prerequisites are required."
  run_cmd "Updating apt package information" sudo apt-get update
  # Python itself is handled separately below so older Raspberry Pi OS
  # releases are not forced to replace or modify their system Python.
  run_cmd "Installing required system packages" sudo apt-get install -y git curl
}

find_linux_python(){
  local candidate=""
  if need python3.12; then
    candidate="$(command -v python3.12)"
  elif [[ -x "$HOME/.local/bin/python3.12" ]]; then
    candidate="$HOME/.local/bin/python3.12"
  fi

  if [[ -n "$candidate" ]] && "$candidate" -c 'import sys; raise SystemExit(0 if sys.version_info[:2] == (3,12) else 1)' >/dev/null 2>&1; then
    printf '%s\n' "$candidate"
    return 0
  fi
  return 1
}

install_linux_python(){
  PYTHON_BIN="$(find_linux_python || true)"
  [[ -n "$PYTHON_BIN" ]] && return 0

  # Use uv for a private Python 3.12 when the distribution does not provide
  # it. This is especially useful on Raspberry Pi OS/Debian releases whose
  # system Python is older. The system Python is left untouched.
  if ! need uv && [[ ! -x "$HOME/.local/bin/uv" ]]; then
    header "Installing Python 3.12 runtime"
    run_cmd "Installing uv" bash -c 'curl -LsSf https://astral.sh/uv/install.sh | sh'
  fi

  local uv_bin
  uv_bin="$(command -v uv 2>/dev/null || true)"
  [[ -n "$uv_bin" ]] || uv_bin="$HOME/.local/bin/uv"
  [[ -x "$uv_bin" ]] || die "Could not install uv, which is required to provide Python 3.12 on this system."

  run_cmd "Installing Python 3.12" "$uv_bin" python install 3.12
  PYTHON_BIN="$($uv_bin python find 3.12 2>/dev/null || true)"
  [[ -n "$PYTHON_BIN" && -x "$PYTHON_BIN" ]] || die "Python 3.12 was installed, but its executable could not be located."
}

find_macos_python(){
  local candidate=""

  # Personal Agent is pinned to Python 3.12 on macOS. Do not fall back to
  # Python 3.13+, because pinned binary dependencies (notably NumPy 2.0.2)
  # may otherwise be built from source and fail.
  if need python3.12; then
    candidate="$(command -v python3.12)"
  elif need brew; then
    local brew_py
    brew_py="$(brew --prefix python@3.12 2>/dev/null || true)"
    if [[ -n "$brew_py" && -x "$brew_py/bin/python3.12" ]]; then
      candidate="$brew_py/bin/python3.12"
    fi
  fi

  if [[ -n "$candidate" ]] && "$candidate" -c 'import sys; raise SystemExit(0 if sys.version_info[:2] == (3,12) else 1)' >/dev/null 2>&1; then
    printf '%s\n' "$candidate"
    return 0
  fi
  return 1
}

install_macos_prereqs(){
  # Xcode Command Line Tools normally provide Git. Homebrew is used for
  # Python 3.12 only when Homebrew is already installed.
  if ! need git; then
    die "Git is required. Run 'xcode-select --install', complete the installation, then rerun this script."
  fi

  PYTHON_BIN="$(find_macos_python || true)"
  if [[ -z "$PYTHON_BIN" ]]; then
    if need brew; then
      header "Installing Python 3.12 with Homebrew"
      run_cmd "Installing Python 3.12" brew install python@3.12
      PYTHON_BIN="$(find_macos_python || true)"
      [[ -n "$PYTHON_BIN" ]] || die "Homebrew installed python@3.12, but the installer could not locate its Python 3.12 executable."
    else
      die "Python 3.12 is required on macOS. Install Python 3.12 or Homebrew, then rerun this script. Python 3.13+ will not be used."
    fi
  fi
}

# Prerequisites and Python selection.
if [[ "$PLATFORM" == "Linux" ]]; then
  missing=()
  for c in git curl; do need "$c" || missing+=("$c"); done
  if ((${#missing[@]})); then
    warn "Missing prerequisites: ${missing[*]}"
    install_linux_prereqs || die "Install Git and curl, then rerun."
  fi
  install_linux_python
else
  install_macos_prereqs
fi

ok "Python $("$PYTHON_BIN" -c 'import sys; print(".".join(map(str,sys.version_info[:3])))')"

TMP_DIR="$(mktemp -d)"
header "Downloading Personal AI Agent"
run_cmd "Downloading Personal AI Agent" git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$TMP_DIR/repo"
for f in agent agent-server requirements.txt; do
  [[ -e "$TMP_DIR/repo/$f" ]] || die "Repository is missing required file: $f"
done
mkdir -p "$(dirname "$APP_DIR")"
mv "$TMP_DIR/repo" "$APP_DIR"
chmod +x "$APP_DIR/agent" "$APP_DIR/agent-server" 2>/dev/null || true
ok "Application installed to $APP_DIR"

header "Setting up Python environment"
run_cmd "Creating Python virtual environment" "$PYTHON_BIN" -m venv "$APP_DIR/.venv"
ok "Virtual environment created"
run_cmd "Updating pip" "$APP_DIR/.venv/bin/python" -m pip install --upgrade pip
ok "pip ready"

# Linux ARM64/Raspberry Pi: force CPU-only PyTorch before sentence-transformers
# to avoid pip pulling NVIDIA CUDA packages. Apple Silicon uses native PyTorch.
if [[ "$PLATFORM" == "Linux" && ( "$ARCH" == "aarch64" || "$ARCH" == "arm64" ) ]]; then
  header "Installing CPU-only PyTorch for ARM64 Linux"
  run_cmd "Installing CPU-only PyTorch" "$APP_DIR/.venv/bin/python" -m pip install torch --index-url https://download.pytorch.org/whl/cpu
  ok "CPU-only PyTorch installed"
fi

header "Installing dependencies"
run_cmd "Installing Python dependencies" "$APP_DIR/.venv/bin/python" -m pip install -r "$APP_DIR/requirements.txt"
ok "Dependencies installed"

mkdir -p "$CONFIG_DIR" "$DATA_DIR" "$CACHE_DIR" "$WORKSPACE_DIR"
if [[ ! -f "$CONFIG_DIR/.env" && -f "$APP_DIR/.env.example" ]]; then
  cp "$APP_DIR/.env.example" "$CONFIG_DIR/.env"
  chmod 600 "$CONFIG_DIR/.env"
  warn "Created a new .env in the configuration directory."
fi

api_key_configured(){
  [[ -f "$CONFIG_DIR/.env" ]] && grep -Eq '^[[:space:]]*OPENAI_API_KEY=[^[:space:]]+' "$CONFIG_DIR/.env"
}

configure_api_key(){
  api_key_configured && {
    ok "OpenAI API key already configured"
    return 0
  }

  header "OpenAI configuration"
  info "An OpenAI API key is required to use Personal Agent."
  tty_read -r -p "Configure your API key now? [Y/n]: " answer
  answer="${answer:-Y}"

  if [[ ! "$answer" =~ ^[Yy]$ ]]; then
    warn "OpenAI API key not configured."
    info "You can configure it later in:"
    printf '  "%s/.env"\n' "$CONFIG_DIR"
    return 0
  fi

  local api_key=""
  while [[ -z "$api_key" ]]; do
    printf 'OpenAI API key: '
    IFS= tty_read -r -s api_key
    printf '\n'
    if [[ -z "$api_key" ]]; then
      warn "API key cannot be empty. Try again, or press Ctrl+C to cancel."
    fi
  done

  # Replace an existing OPENAI_API_KEY assignment, or append one if absent.
  # The value is written directly and is never echoed back to the terminal.
  if [[ -f "$CONFIG_DIR/.env" ]] && grep -Eq '^[[:space:]]*OPENAI_API_KEY=' "$CONFIG_DIR/.env"; then
    ENV_FILE="$CONFIG_DIR/.env" API_KEY_VALUE="$api_key" "$APP_DIR/.venv/bin/python" - <<'PY'
import os
from pathlib import Path

path = Path(os.environ["ENV_FILE"])
value = os.environ["API_KEY_VALUE"]
lines = path.read_text().splitlines()
out = []
replaced = False
for line in lines:
    if line.lstrip().startswith("OPENAI_API_KEY=") and not replaced:
        out.append("OPENAI_API_KEY=" + value)
        replaced = True
    else:
        out.append(line)
if not replaced:
    out.append("OPENAI_API_KEY=" + value)
path.write_text("\n".join(out) + "\n")
PY
  else
    printf '\nOPENAI_API_KEY=%s\n' "$api_key" >> "$CONFIG_DIR/.env"
  fi

  unset api_key
  chmod 600 "$CONFIG_DIR/.env"
  ok "OpenAI API key saved securely"
}

configure_api_key

header "Installing command"
mkdir -p "$BIN_DIR"
# The command in ~/.local/bin is intentionally only a launcher. Never copy or
# symlink the Python client here: doing so can bypass the app virtualenv and
# accidentally invoke the system Python. Recreate it on every install/update.
rm -f "$LAUNCHER"
cat >"$LAUNCHER" <<EOF
#!/usr/bin/env bash
set -e
APP_DIR="$APP_DIR"
PYTHON="\$APP_DIR/.venv/bin/python"
CLIENT="\$APP_DIR/agent"

if [[ ! -x "\$PYTHON" ]]; then
  printf 'Personal Agent virtual environment is missing or not executable: %s\n' "\$PYTHON" >&2
  exit 1
fi
if [[ ! -f "\$CLIENT" ]]; then
  printf 'Personal Agent client is missing: %s\n' "\$CLIENT" >&2
  exit 1
fi

exec "\$PYTHON" "\$CLIENT" "\$@"
EOF
chmod 755 "$LAUNCHER"
ok "Installed launcher $LAUNCHER"

install_linux_service(){
  mkdir -p "$SERVICE_DIR"
  cat >"$SERVICE_FILE" <<EOF
[Unit]
Description=Personal AI Agent Server
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=$APP_DIR
ExecStart=$APP_DIR/.venv/bin/python $APP_DIR/agent-server
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF
  run_cmd "Reloading systemd user configuration" systemctl --user daemon-reload
  run_cmd "Enabling Personal Agent service" systemctl --user enable personal-agent.service
  if api_key_configured; then
    run_cmd "Starting Personal Agent service" systemctl --user start personal-agent.service
    ok "personal-agent.service enabled and started"
  else
    warn "Service enabled but not started because OPENAI_API_KEY is not configured."
    info "After editing:"
    printf '  "%s/.env"\n' "$CONFIG_DIR"
    info "Start the service with:"
    printf '  systemctl --user start personal-agent\n'
  fi

  tty_read -r -p "Start the server at boot even before login (enable linger)? [y/N]: " a
  if [[ "${a:-N}" =~ ^[Yy]$ ]]; then
    if need loginctl && loginctl enable-linger "$USER" 2>/dev/null; then
      ok "Linger enabled for $USER"
    else
      warn "Could not enable linger automatically."
      info "You can enable it later with: sudo loginctl enable-linger \"$USER\""
    fi
  fi
}

install_macos_service(){
  mkdir -p "$SERVICE_DIR"
  # launchd requires XML escaping. HOME paths cannot contain '&' normally, but
  # handle XML-sensitive characters anyway.
  local app_xml python_xml stdout_xml stderr_xml
  app_xml="$(printf '%s' "$APP_DIR" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')"
  python_xml="$(printf '%s' "$APP_DIR/.venv/bin/python" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')"
  stdout_xml="$(printf '%s' "$HOME/Library/Logs/PersonalAgent.log" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')"
  stderr_xml="$(printf '%s' "$HOME/Library/Logs/PersonalAgent-error.log" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')"
  mkdir -p "$HOME/Library/Logs"

  cat >"$SERVICE_FILE" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$mac_service_label</string>
  <key>ProgramArguments</key>
  <array>
    <string>$python_xml</string>
    <string>$app_xml/agent-server</string>
  </array>
  <key>WorkingDirectory</key>
  <string>$app_xml</string>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <dict>
    <key>SuccessfulExit</key>
    <false/>
  </dict>
  <key>StandardOutPath</key>
  <string>$stdout_xml</string>
  <key>StandardErrorPath</key>
  <string>$stderr_xml</string>
</dict>
</plist>
EOF
  chmod 600 "$SERVICE_FILE"

  if api_key_configured; then
    launchctl bootout "gui/$(id -u)" "$SERVICE_FILE" >/dev/null 2>&1 || true
    launchctl bootstrap "gui/$(id -u)" "$SERVICE_FILE"
    launchctl enable "gui/$(id -u)/$mac_service_label" >/dev/null 2>&1 || true
    ok "LaunchAgent installed and started"
  else
    warn "LaunchAgent installed but not started because OPENAI_API_KEY is not configured."
    info "After editing:"
    printf '  "%s/.env"\n' "$CONFIG_DIR"
    info "Start the service with:"
    printf '  launchctl bootstrap gui/%s "%s"\n' "$(id -u)" "$SERVICE_FILE"
  fi
}

SERVICE_INSTALLED=N
if [[ "$PLATFORM" == "Linux" ]]; then
  if need systemctl; then
    tty_read -r -p "Install/start the systemd user service? [Y/n]: " a; a="${a:-Y}"
    if [[ "$a" =~ ^[Yy]$ ]]; then
      install_linux_service
      SERVICE_INSTALLED=Y
    fi
  else
    warn "systemd not detected; background service skipped."
  fi
else
  tty_read -r -p "Install/start the macOS LaunchAgent? [Y/n]: " a; a="${a:-Y}"
  if [[ "$a" =~ ^[Yy]$ ]]; then
    install_macos_service
    SERVICE_INSTALLED=Y
  fi
fi

INSTALL_SUCCEEDED=1

if (( VERBOSE )); then
  header "Installation details"
  printf '%sPlatform:%s    %s\n' "$BOLD" "$RESET" "$PLATFORM"
  printf '%sApplication:%s %s\n' "$BOLD" "$RESET" "$APP_DIR"
  printf '%sConfig:%s      %s\n' "$BOLD" "$RESET" "$CONFIG_DIR"
  printf '%sData:%s        %s\n' "$BOLD" "$RESET" "$DATA_DIR"
  printf '%sCache:%s       %s\n' "$BOLD" "$RESET" "$CACHE_DIR"
  printf '%sCommand:%s     %s\n' "$BOLD" "$RESET" "$LAUNCHER"
fi

printf '\n%s────────────────────────────────────────%s\n' "$DIM" "$RESET"
printf '%s%s✓ Personal Agent is ready%s\n' "$BOLD" "$GREEN" "$RESET"
printf '%s────────────────────────────────────────%s\n' "$DIM" "$RESET"

case ":$PATH:" in
  *":$BIN_DIR:"*) printf '\nRun:\n\n    %sagent%s\n' "$BOLD" "$RESET" ;;
  *)
    printf '\nRun:\n\n    "%s"\n' "$LAUNCHER"
    printf '\n%sNote:%s %s is not currently in PATH.\n' "$YELLOW" "$RESET" "$BIN_DIR"
    printf 'Add this to your shell profile if you want to use the shorter %sagent%s command:\n\n' "$BOLD" "$RESET"
    printf '    export PATH="$HOME/.local/bin:$PATH"\n'
    ;;
esac

printf '\nWorkspace:\n\n    %s\n' "$WORKSPACE_DIR"
printf '\nConfiguration:\n\n    %s/.env\n' "$CONFIG_DIR"

if [[ "$SERVICE_INSTALLED" == Y ]]; then
  printf '\nUseful commands:\n\n'
  if [[ "$PLATFORM" == "Linux" ]]; then
    printf '    systemctl --user status personal-agent\n'
    printf '    journalctl --user -u personal-agent -f\n'
  else
    printf '    launchctl print gui/%s/%s\n' "$(id -u)" "$mac_service_label"
    printf '    tail -f "$HOME/Library/Logs/PersonalAgent-error.log"\n'
  fi
fi
