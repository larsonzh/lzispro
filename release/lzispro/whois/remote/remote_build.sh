#!/usr/bin/env bash
set -euo pipefail

# Remote static cross-compile and optional smoke tests
# This script is intended to run on the Ubuntu VM via SSH.
# It expects musl cross toolchains to be installed and available in PATH.

# Configurable env vars (with defaults)
: "${TARGETS:=aarch64 armv7 x86_64 x86 mipsel mips64el loongarch64}"
: "${OUTPUT_DIR:=release/build_out}"
: "${RUN_TESTS:=0}"

# Derive repo root based on this script path
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"  # repo root
SRC_DIR="$REPO_DIR/release/lzispro/whois"
SOURCE_FILE="$SRC_DIR/whois_client.c"

mkdir -p "$REPO_DIR/$OUTPUT_DIR"
ARTIFACTS_DIR="$(cd "$REPO_DIR/$OUTPUT_DIR" && pwd)"

log() { echo "[remote_build] $*"; }
warn() { echo "[remote_build][WARN] $*" >&2; }
err() { echo "[remote_build][ERROR] $*" >&2; }

# Resolve compiler path by target, preferring absolute paths under $HOME
find_cc() {
  local target="$1"
  local cand=()
  case "$target" in
    aarch64)
      cand=("$HOME/.local/aarch64-linux-musl-cross/bin/aarch64-linux-musl-gcc" "aarch64-linux-musl-gcc") ;;
    armv7)
      cand=("$HOME/.local/arm-linux-musleabihf-cross/bin/arm-linux-musleabihf-gcc" "arm-linux-musleabihf-gcc" "armv7l-linux-musleabihf-gcc") ;;
    x86_64)
      cand=("$HOME/.local/x86_64-linux-musl-cross/bin/x86_64-linux-musl-gcc" "x86_64-linux-musl-gcc") ;;
    x86)
      cand=("$HOME/.local/i686-linux-musl-cross/bin/i686-linux-musl-gcc" "i686-linux-musl-gcc") ;;
    mipsel)
      cand=("$HOME/.local/mipsel-linux-musl-cross/bin/mipsel-linux-musl-gcc" "mipsel-linux-musl-gcc") ;;
    mips64el)
      cand=("$HOME/.local/mips64el-linux-musl-cross/bin/mips64el-linux-musl-gcc" "mips64el-linux-musl-gcc") ;;
    loongarch64)
      cand=("$HOME/.local/loongson-gnu-toolchain-8.3-x86_64-loongarch64-linux-gnu-rc1.6/bin/loongarch64-linux-gnu-gcc" "loongarch64-linux-gnu-gcc" "loongarch64-linux-musl-gcc") ;;
    *)
      echo ""
      return 0 ;;
  esac

  local c
  for c in "${cand[@]}"; do
    # Absolute path candidate
    if [[ "$c" = /* ]]; then
      if [[ -x "$c" ]]; then echo "$c"; return 0; fi
      continue
    fi
    # Named binary: use command -v to resolve full path
    local resolved
    resolved="$(command -v "$c" 2>/dev/null || true)"
    if [[ -n "$resolved" ]]; then echo "$resolved"; return 0; fi
  done
  echo ""
}

# Build one target with exact commands provided by user
build_one() {
  local target="$1"
  local out=""
  case "$target" in
    aarch64)
      local cc
      cc="$(find_cc aarch64)"
      if [[ -z "$cc" ]]; then warn "aarch64 toolchain not found"; return 0; fi
      out="$ARTIFACTS_DIR/whois-aarch64"
      log "Building aarch64 => $(basename "$out") (CC: $cc)"
      "$cc" -static -O3 -s -o "$out" "$SOURCE_FILE" -Wall -pthread
      ;;
    armv7)
      local cc
      cc="$(find_cc armv7)"
      if [[ -z "$cc" ]]; then warn "armv7 toolchain not found"; return 0; fi
      out="$ARTIFACTS_DIR/whois-armv7"
      log "Building armv7 => $(basename "$out") (CC: $cc)"
      "$cc" -static -O3 -s -o "$out" "$SOURCE_FILE" -Wall -pthread
      ;;
    x86_64)
      local cc
      cc="$(find_cc x86_64)"
      if [[ -z "$cc" ]]; then warn "x86_64 toolchain not found"; return 0; fi
      out="$ARTIFACTS_DIR/whois-x86_64"
      log "Building x86_64 => $(basename "$out") (CC: $cc)"
      "$cc" -static -O3 -s -o "$out" "$SOURCE_FILE" -Wall -pthread
      ;;
    x86)
      local cc
      cc="$(find_cc x86)"
      if [[ -z "$cc" ]]; then warn "x86 (i686) toolchain not found"; return 0; fi
      out="$ARTIFACTS_DIR/whois-x86"
      log "Building x86 => $(basename "$out") (CC: $cc)"
      "$cc" -static -O3 -s -o "$out" "$SOURCE_FILE" -Wall -pthread
      ;;
    mipsel)
      local cc
      cc="$(find_cc mipsel)"
      if [[ -z "$cc" ]]; then warn "mipsel toolchain not found"; return 0; fi
      out="$ARTIFACTS_DIR/whois-mipsel"
      log "Building mipsel => $(basename "$out") (CC: $cc)"
      "$cc" -static -O3 -s -o "$out" "$SOURCE_FILE" -Wall -pthread
      ;;
    mips64el)
      local cc
      cc="$(find_cc mips64el)"
      if [[ -z "$cc" ]]; then warn "mips64el toolchain not found"; return 0; fi
      out="$ARTIFACTS_DIR/whois-mips64el"
      log "Building mips64el => $(basename "$out") (CC: $cc)"
      "$cc" -static -O3 -s -o "$out" "$SOURCE_FILE" -Wall -pthread
      ;;
    loongarch64)
      local cc
      cc="$(find_cc loongarch64)"
      if [[ -z "$cc" ]]; then warn "loongarch64 toolchain not found"; return 0; fi
      out="$ARTIFACTS_DIR/whois-loongarch64"
      log "Building loongarch64 => $(basename "$out") (CC: $cc)"
      "$cc" -O3 -s -o "$out" "$SOURCE_FILE" -Wall -pthread -static-libgcc -static-libstdc++
      ;;
    *)
      warn "Unknown target: $target"; return 0;;
  esac
  # Binaries are already linked with -s; prefer not to run native strip on foreign arch to avoid noisy errors
  : # no-op; keep size minimized via linker '-s'
}

# Optional smoke test for a built binary
smoke_test() {
  local bin="$1"
  if [[ ! -x "$bin" ]]; then
    warn "Smoke test skipped: $bin not executable"
    return 0
  fi
  local name="$(basename "$bin")"
  log "Smoke test: $name -h whois.apnic.net 8.8.8.8"
  local cmd=""
  case "$name" in
    whois-aarch64) cmd="qemu-aarch64-static \"$bin\" -h whois.apnic.net 8.8.8.8" ;;
    whois-armv7) cmd="qemu-arm-static \"$bin\" -h whois.apnic.net 8.8.8.8" ;;
    whois-x86_64) cmd="qemu-x86_64-static \"$bin\" -h whois.apnic.net 8.8.8.8" ;;
    whois-x86) cmd="qemu-i386-static \"$bin\" -h whois.apnic.net 8.8.8.8" ;;
    whois-mipsel) cmd="qemu-mipsel-static \"$bin\" -h whois.apnic.net 8.8.8.8" ;;
    whois-mips64el) cmd="qemu-mips64el-static \"$bin\" -h whois.apnic.net 8.8.8.8" ;;
    whois-loongarch64) return 0 ;; # No emulator test
    *) return 0 ;;
  esac
  if [[ -z "$cmd" ]]; then return 0; fi
  if command -v timeout >/dev/null 2>&1; then
    bash -lc "timeout 12 $cmd" || warn "Smoke test non-zero exit: $name"
  else
    bash -lc "$cmd" || warn "Smoke test non-zero exit: $name"
  fi
}

if [[ ! -f "$SOURCE_FILE" ]]; then
  err "Source not found: $SOURCE_FILE"
  exit 1
fi

log "Repo dir: $REPO_DIR"
log "Artifacts: $ARTIFACTS_DIR"
log "Targets: $TARGETS"
log "PATH: $PATH"

# Build targets
file_report="$ARTIFACTS_DIR/file_report.txt"
smoke_log="$ARTIFACTS_DIR/smoke_test.log"
: > "$file_report"
: > "$smoke_log"

for t in $TARGETS; do
  build_one "$t"
  # upx compress for specific files (keep name)
  case "$t" in
    aarch64)
      if command -v upx >/dev/null 2>&1; then
        log "UPX compress whois-aarch64"
        if [[ -f "$ARTIFACTS_DIR/whois-aarch64" ]]; then
          upx --best --lzma "$ARTIFACTS_DIR/whois-aarch64" || warn "UPX failed for whois-aarch64"
        else
          warn "Skip UPX: whois-aarch64 not built"
        fi
      fi
      ;;
    x86_64)
      if command -v upx >/dev/null 2>&1; then
        log "UPX compress whois-x86_64"
        if [[ -f "$ARTIFACTS_DIR/whois-x86_64" ]]; then
          upx --best --lzma "$ARTIFACTS_DIR/whois-x86_64" || warn "UPX failed for whois-x86_64"
        else
          warn "Skip UPX: whois-x86_64 not built"
        fi
      fi
      ;;
  esac

  # file report
  for bin in "$ARTIFACTS_DIR"/whois-*; do
    [[ -f "$bin" ]] || continue
    file "$bin" | tee -a "$file_report" >/dev/null || true
  done

  # smoke test per built binary
  if [[ "$RUN_TESTS" == "1" ]]; then
    for bin in "$ARTIFACTS_DIR"/whois-*; do
      [[ -x "$bin" ]] || continue
      # Print progress to console so the user can see QEMU is running, while piping details to log
      echo "[remote_build] QEMU smoke: $(basename "$bin") ..."
      smoke_test "$bin" >> "$smoke_log" 2>&1 || true
    done
  fi
done

log "Done. Artifacts in: $ARTIFACTS_DIR"
