#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Deploy a fresh NixOS install to a target (via nixos-anywhere).

Usage:
  scripts/deploy.sh --host HOST --target USER@IP [options]

Required:
  --host HOST           Flake host output name (e.g. laptop, serverA)
  --target USER@IP      SSH target (usually nixos@<ip> from installer ISO)

Options:
  --flake PATH          Flake path (default: repo root)
  --extra-files-src DIR Directory to copy into --extra-files (default: ./extra-files/<host>)
  --extra-files DIR     Use this directory directly as --extra-files (no temp copy)
  --luks-key-file PATH  File containing the LUKS passphrase (if omitted, you'll be prompted)
  --target-luks-path P  Path on target referenced by disko passwordFile (default: /tmp/disk-encryption.key)
  --no-disk-keys        Skip --disk-encryption-keys entirely
  --dry-run             Print the nixos-anywhere command without running it

Examples:
  scripts/deploy.sh --host laptop  --target nixos@192.168.1.50
  scripts/deploy.sh --host serverA --target nixos@10.0.0.12 --luks-key-file ./keys/serverA.luks
EOF
}

# ---- defaults ----
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
FLAKE_PATH="$REPO_ROOT"
HOST=""
TARGET=""

TARGET_LUKS_PATH="/tmp/disk-encryption.key"
NO_DISK_KEYS=0
DRY_RUN=0

EXTRA_FILES_SRC=""   # if empty, defaults to $REPO_ROOT/extra-files/$HOST
EXTRA_FILES_DIR=""   # if set, used directly (no temp copy)

LUKS_KEY_FILE=""     # if empty -> prompt -> temp file

# ---- arg parsing ----
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
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ -z "$HOST" || -z "$TARGET" ]]; then
  echo "Error: --host and --target are required." >&2
  usage
  exit 1
fi

HOST_DIR="${FLAKE_PATH}/hosts/${HOST}"
HW_CFG="${HOST_DIR}/hardware-configuration.nix"

if [[ ! -d "$HOST_DIR" ]]; then
  echo "Error: host directory not found: $HOST_DIR" >&2
  exit 1
fi

if [[ ! -f "$HW_CFG" ]]; then
  echo "Error: hardware config not found: $HW_CFG" >&2
  echo "Tip: create a stub file or let nixos-anywhere generate it at that path." >&2
  exit 1
fi

# ---- temp files / cleanup ----
TMP_EXTRA_DIR=""
TMP_LUKS_FILE=""

cleanup() {
  [[ -n "$TMP_EXTRA_DIR" && -d "$TMP_EXTRA_DIR" ]] && rm -rf "$TMP_EXTRA_DIR"
  [[ -n "$TMP_LUKS_FILE" && -f "$TMP_LUKS_FILE" ]] && rm -f "$TMP_LUKS_FILE"
}
trap cleanup EXIT

# ---- extra-files handling ----
if [[ -n "$EXTRA_FILES_DIR" ]]; then
  # Use directly
  if [[ ! -d "$EXTRA_FILES_DIR" ]]; then
    echo "Error: --extra-files directory not found: $EXTRA_FILES_DIR" >&2
    exit 1
  fi
  FINAL_EXTRA_DIR="$EXTRA_FILES_DIR"
else
  # Create temp and optionally populate from repo
  TMP_EXTRA_DIR="$(mktemp -d)"
  FINAL_EXTRA_DIR="$TMP_EXTRA_DIR"

  if [[ -z "$EXTRA_FILES_SRC" ]]; then
    EXTRA_FILES_SRC="${REPO_ROOT}/extra-files/${HOST}"
  fi

  if [[ -d "$EXTRA_FILES_SRC" ]]; then
    # Copy contents into temp dir
    # (rsync preferred; fallback to cp -a)
    if command -v rsync >/dev/null 2>&1; then
      rsync -a "${EXTRA_FILES_SRC}/" "${FINAL_EXTRA_DIR}/"
    else
      cp -a "${EXTRA_FILES_SRC}/." "${FINAL_EXTRA_DIR}/"
    fi
  fi
fi

# ---- LUKS key handling ----
FINAL_LUKS_FILE="$LUKS_KEY_FILE"

if [[ $NO_DISK_KEYS -eq 0 ]]; then
  if [[ -z "$FINAL_LUKS_FILE" ]]; then
    TMP_LUKS_FILE="$(mktemp)"
    chmod 0400 "$TMP_LUKS_FILE"

    # Prompt for passphrase twice
    read -r -s -p "LUKS passphrase: " p1; echo
    read -r -s -p "Confirm passphrase: " p2; echo
    if [[ "$p1" != "$p2" ]]; then
      echo "Error: passphrases do not match." >&2
      exit 1
    fi

    printf '%s\n' "$p1" > "$TMP_LUKS_FILE"
    unset p1 p2
    FINAL_LUKS_FILE="$TMP_LUKS_FILE"
  else
    if [[ ! -f "$FINAL_LUKS_FILE" ]]; then
      echo "Error: --luks-key-file not found: $FINAL_LUKS_FILE" >&2
      exit 1
    fi
  fi
fi

# ---- build command ----
cmd=(
  nix run github:nix-community/nixos-anywhere --
  --flake "${FLAKE_PATH}#${HOST}"
  --extra-files "${FINAL_EXTRA_DIR}"
  --generate-hardware-config nixos-generate-config "${HW_CFG}"
  --target-host "${TARGET}"
)

if [[ $NO_DISK_KEYS -eq 0 ]]; then
  cmd+=(
    --disk-encryption-keys "${TARGET_LUKS_PATH}" "${FINAL_LUKS_FILE}"
  )
fi

# ---- run ----
echo "Running:"
printf '  %q' "${cmd[@]}"; echo

if [[ $DRY_RUN -eq 1 ]]; then
  echo "(dry-run) Not executing."
  exit 0
fi

"${cmd[@]}"

