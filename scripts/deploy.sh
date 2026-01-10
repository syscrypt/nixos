#!/usr/bin/env bash
set -euo pipefail
export SOPS_AGE_KEY_FILE="$(pwd)/vault/vault.key"

# ------------------------------------------------------------------------------
# nixos-anywhere deploy helper (multi-host)
#
# Features:
# - Works from any working directory
# - Auto-creates a stub hosts/<host>/hardware-configuration.nix if missing
# - Stages --extra-files from extra-files/<host>/ (or custom dir)
# - Supports LUKS passphrase via file or interactive prompt
# - Always enables nix-command + flakes for the *local* nix invocation
# - Nice logging helpers: info/warn/error
# ------------------------------------------------------------------------------

# --- colors (auto-disable if not a TTY or NO_COLOR is set) ---------------------
if [[ -t 2 && -z "${NO_COLOR:-}" ]]; then
  C_RESET=$'\033[0m'
  C_BOLD=$'\033[1m'
  C_DIM=$'\033[2m'
  C_BLUE=$'\033[1;34m'
  C_YELLOW=$'\033[1;33m'
  C_RED=$'\033[1;31m'
else
  C_RESET="" C_BOLD="" C_DIM="" C_BLUE="" C_YELLOW="" C_RED=""
fi

ts() { date +"%Y-%m-%d %H:%M:%S"; }
info()  { printf '%s%s[INFO]%s %s\n'  "$C_BLUE"   "$(ts) " "$C_RESET" "$*" >&2; }
warn()  { printf '%s%s[WARN]%s %s\n'  "$C_YELLOW" "$(ts) " "$C_RESET" "$*" >&2; }
error() { printf '%s%s[ERR ]%s %s\n'  "$C_RED"    "$(ts) " "$C_RESET" "$*" >&2; }
die()   { error "$*"; exit 1; }

usage() {
  cat >&2 <<'EOF'
Deploy a fresh NixOS installation via nixos-anywhere.

Usage:
  scripts/deploy.sh --host HOST --target USER@IP [options]

Required:
  --host HOST            Flake host output name (e.g. laptop, serverA)
  --target USER@IP       SSH target (usually nixos@<ip> from NixOS installer ISO)

Options:
  --flake PATH           Flake path (default: repo root)
  --extra-files-src DIR  Directory to stage into --extra-files (default: ./extra-files/<host>)
  --extra-files DIR      Use this directory directly as --extra-files (no temp copy)
  --luks-key-file PATH   File containing the LUKS passphrase (if omitted, prompt)
  --target-luks-path P   Target path referenced by disko passwordFile (default: /tmp/disk-encryption.key)
  --no-disk-keys         Skip --disk-encryption-keys entirely
  --no-stub-hwcfg        Do not create a stub hardware-configuration.nix if missing
  --dry-run              Print the nixos-anywhere command without running it
  -h, --help             Show help

Examples:
  scripts/deploy.sh --host laptop  --target nixos@192.168.1.50
  scripts/deploy.sh --host serverA --target nixos@10.0.0.12 --no-disk-keys
  scripts/deploy.sh --host laptop  --target nixos@192.168.1.50 --luks-key-file ./keys/laptop.key
EOF
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

quote_cmd() {
  local -a a=("$@")
  printf '  %q' "${a[@]}"; echo
}

# Resolve a user-provided path robustly:
# - strip CR
# - expand ~/
# - if relative, try:
#    1) relative to current working directory
#    2) relative to repo root
#    3) relative to flake path (if different)
resolve_path() {
  local p="$1"
  p="${p//$'\r'/}"

  if [[ "$p" == "~/"* ]]; then
    p="${HOME}/${p#~/}"
  fi

  # If absolute and exists, done
  if [[ "$p" == /* ]]; then
    printf '%s' "$p"
    return 0
  fi

  # Try as-is (relative to CWD)
  if [[ -f "$p" ]]; then
    printf '%s' "$(cd "$(dirname "$p")" && pwd)/$(basename "$p")"
    return 0
  fi

  # Try relative to repo root
  local alt1="${REPO_ROOT}/${p#./}"
  if [[ -f "$alt1" ]]; then
    printf '%s' "$alt1"
    return 0
  fi

  # Try relative to flake path
  local alt2="${FLAKE_PATH}/${p#./}"
  if [[ -f "$alt2" ]]; then
    printf '%s' "$alt2"
    return 0
  fi

  # Return original (non-existent) for diagnostics
  printf '%s' "$p"
  return 0
}

# --- defaults -----------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

HOST=""
TARGET=""
FLAKE_PATH="$REPO_ROOT"

TARGET_LUKS_PATH="/tmp/disk-encryption.key"
NO_DISK_KEYS=0
NO_STUB_HWCFG=0
DRY_RUN=0

EXTRA_FILES_SRC=""   # if empty -> $REPO_ROOT/extra-files/$HOST
EXTRA_FILES_DIR=""   # if set -> used directly (no temp copy)

LUKS_KEY_FILE=""     # if empty -> prompt -> temp file

# --- parse args ----------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --host) HOST="${2:-}"; shift 2 ;;
    --target) TARGET="${2:-}"; shift 2 ;;
    --flake) FLAKE_PATH="${2:-}"; shift 2 ;;
    --extra-files-src) EXTRA_FILES_SRC="${2:-}"; shift 2 ;;
    --extra-files) EXTRA_FILES_DIR="${2:-}"; shift 2 ;;
    --luks-key-file) LUKS_KEY_FILE="${2:-}"; shift 2 ;;
    --target-luks-path) TARGET_LUKS_PATH="${2:-}"; shift 2 ;;
    --no-disk-keys) NO_DISK_KEYS=1; shift ;;
    --no-stub-hwcfg) NO_STUB_HWCFG=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown argument: $1 (try --help)" ;;
  esac
done

[[ -n "$HOST" ]]   || die "Missing --host (try --help)"
[[ -n "$TARGET" ]] || die "Missing --target (try --help)"

need_cmd nix
need_cmd mktemp

if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
  warn "You are running this script as root."
  warn "If your LUKS key lives under your user home, root may not be able to read it depending on permissions/mounts."
fi

# --- paths --------------------------------------------------------------------
HOST_DIR="${FLAKE_PATH}/hosts/${HOST}"
HW_CFG="${HOST_DIR}/hardware-configuration.nix"

[[ -d "$HOST_DIR" ]] || die "Host directory not found: ${HOST_DIR}"

# --- temp management -----------------------------------------------------------
TMP_EXTRA_DIR=""
TMP_LUKS_FILE=""

cleanup() {
  [[ -n "$TMP_EXTRA_DIR" && -d "$TMP_EXTRA_DIR" ]] && rm -rf "$TMP_EXTRA_DIR"
  [[ -n "$TMP_LUKS_FILE" && -f "$TMP_LUKS_FILE" ]] && rm -f "$TMP_LUKS_FILE"
}
trap cleanup EXIT

info "Repo root : $REPO_ROOT"
info "Flake path: $FLAKE_PATH"
info "Host      : $HOST"
info "Target    : $TARGET"

# --- ensure hardware-configuration.nix exists (stub if needed) ----------------
if [[ ! -f "$HW_CFG" ]]; then
  if [[ $NO_STUB_HWCFG -eq 1 ]]; then
    die "Missing ${HW_CFG} and --no-stub-hwcfg was set."
  fi
  info "hardware-configuration.nix missing; creating stub at: ${HW_CFG}"
  mkdir -p "$(dirname "$HW_CFG")"
  cat > "$HW_CFG" <<'EOF'
{ ... }: { }
EOF
fi

# --- extra-files handling ------------------------------------------------------
if [[ -n "$EXTRA_FILES_DIR" ]]; then
  [[ -d "$EXTRA_FILES_DIR" ]] || die "--extra-files dir not found: $EXTRA_FILES_DIR"
  FINAL_EXTRA_DIR="$EXTRA_FILES_DIR"
  info "Using --extra-files directory as-is: ${FINAL_EXTRA_DIR}"
else
  TMP_EXTRA_DIR="$(mktemp -d)"
  FINAL_EXTRA_DIR="$TMP_EXTRA_DIR"

  if [[ -z "$EXTRA_FILES_SRC" ]]; then
    EXTRA_FILES_SRC="${REPO_ROOT}/extra-files/${HOST}"
  fi

  if [[ -d "$EXTRA_FILES_SRC" ]]; then
    info "Staging extra files from: ${EXTRA_FILES_SRC}"
    if command -v rsync >/dev/null 2>&1; then
      rsync -a "${EXTRA_FILES_SRC}/" "${FINAL_EXTRA_DIR}/"
    else
      warn "rsync not found; falling back to cp -a"
      cp -a "${EXTRA_FILES_SRC}/." "${FINAL_EXTRA_DIR}/"
    fi
  else
    info "No extra-files source found (ok): ${EXTRA_FILES_SRC}"
  fi
fi

# --- LUKS key handling ---------------------------------------------------------
FINAL_LUKS_FILE="$LUKS_KEY_FILE"

if [[ $NO_DISK_KEYS -eq 0 ]]; then
  if [[ -z "$FINAL_LUKS_FILE" ]]; then
    TMP_LUKS_FILE="$(mktemp)"
    chmod 0400 "$TMP_LUKS_FILE"

    read -r -s -p "LUKS passphrase: " p1; echo >&2
    read -r -s -p "Confirm passphrase: " p2; echo >&2
    [[ "$p1" == "$p2" ]] || die "Passphrases do not match."

    printf '%s\n' "$p1" > "$TMP_LUKS_FILE"
    unset p1 p2
    FINAL_LUKS_FILE="$TMP_LUKS_FILE"
    info "Using prompted LUKS passphrase via temp file."
  else
    # Resolve path robustly (CWD/repo/flake)
    resolved="$(resolve_path "$FINAL_LUKS_FILE")"
    if [[ "$resolved" != "$FINAL_LUKS_FILE" ]]; then
      warn "Resolved --luks-key-file to: $resolved"
    fi
    FINAL_LUKS_FILE="$resolved"

    if [[ ! -f "$FINAL_LUKS_FILE" ]]; then
      error "LUKS key file not found (or not accessible)."
      error "  path: $(printf '%q' "$FINAL_LUKS_FILE")"
      error "  cwd : $(pwd)"
      error "  user: $(id -un) (uid=$(id -u))"
      parent="$(dirname "$FINAL_LUKS_FILE")"
      error "  parent dir:"
      ls -ld "$parent" 2>&1 | sed 's/^/    /' >&2 || true
      error "  file:"
      ls -l "$FINAL_LUKS_FILE" 2>&1 | sed 's/^/    /' >&2 || true
      die "Fix: run from repo root, pass a correct absolute path, or ensure permissions allow this user to read it."
    fi

    if [[ ! -r "$FINAL_LUKS_FILE" ]]; then
      die "LUKS key file exists but is not readable: $(printf '%q' "$FINAL_LUKS_FILE")"
    fi

    info "Using LUKS passphrase file: ${FINAL_LUKS_FILE}"
  fi
else
  info "--no-disk-keys enabled; skipping disk encryption key passing."
fi

# --- nix invocation: always enable required experimental features --------------
NIX_FEATURE_ARGS=(
  --extra-experimental-features nix-command
  --extra-experimental-features flakes
)

# --- build nixos-anywhere command ----------------------------------------------
cmd=(
  nix "${NIX_FEATURE_ARGS[@]}" run github:nix-community/nixos-anywhere --
  --flake "${FLAKE_PATH}#${HOST}"
  --extra-files "${FINAL_EXTRA_DIR}"
  --generate-hardware-config nixos-generate-config "${HW_CFG}"
  --target-host "${TARGET}"
)

if [[ $NO_DISK_KEYS -eq 0 ]]; then
  cmd+=(
    --disk-encryption-keys "${TARGET_LUKS_PATH}" "${FINAL_LUKS_FILE}"
  )
  info "Target LUKS key path (remote): ${TARGET_LUKS_PATH}"
fi

info "About to run nixos-anywhere:"
quote_cmd "${cmd[@]}"

if [[ $DRY_RUN -eq 1 ]]; then
  warn "Dry run: not executing."
  exit 0
fi

"${cmd[@]}"
info "Deployment finished."

