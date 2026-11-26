#!/bin/zsh
# Capture Yanxu screenshots from a booted iOS simulator for the product page.
#
# The app exposes debug environment switches (YANTU_TAB / YANTU_PAGE /
# YANTU_MODE / YANTU_SAMPLE) that put it on a given screen at launch.
# This script also marks onboarding as done and pins the status bar so the
# shots stay consistent.
#
# Usage:
#   scripts/capture-yanxu.sh                 # use the first booted iPhone
#   YANTU_SIM_UDID=... scripts/capture-yanxu.sh
#   YANTU_BUNDLE_ID=com.brianjiang.yantu scripts/capture-yanxu.sh
set -euo pipefail

cd "$(dirname "$0")/.."

BUNDLE_ID="${YANTU_BUNDLE_ID:-com.brianjiang.yantu.public}"
OUT_DIR="${YANTU_OUT_DIR:-assets/yanxu}"

has_app() {
  xcrun simctl listapps "$1" 2>/dev/null | grep -q "\"$BUNDLE_ID\""
}

if [[ -z "${YANTU_SIM_UDID:-}" ]]; then
  for udid in $(xcrun simctl list devices booted | grep -E "iPhone" | sed -E 's/.*\(([0-9A-F-]+)\).*/\1/'); do
    if has_app "$udid"; then YANTU_SIM_UDID=$udid; break; fi
  done
fi

[[ -n "${YANTU_SIM_UDID:-}" ]] || {
  echo "No booted iPhone simulator has $BUNDLE_ID installed." >&2
  echo "Install it first, or set YANTU_SIM_UDID / YANTU_BUNDLE_ID." >&2
  exit 1
}
has_app "$YANTU_SIM_UDID" || {
  echo "$BUNDLE_ID is not installed on $YANTU_SIM_UDID." >&2
  exit 1
}

mkdir -p "$OUT_DIR"

xcrun simctl status_bar "$YANTU_SIM_UDID" override \
  --time "9:41" --batteryState charged --batteryLevel 100 \
  --wifiBars 3 --cellularBars 4 >/dev/null 2>&1 || true

xcrun simctl terminate "$YANTU_SIM_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl spawn "$YANTU_SIM_UDID" defaults write "$BUNDLE_ID" onboarding.done -bool YES

shot() {
  local name=$1
  shift
  xcrun simctl terminate "$YANTU_SIM_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
  env "$@" SIMCTL_CHILD_YANTU_SAMPLE=1 \
    xcrun simctl launch "$YANTU_SIM_UDID" "$BUNDLE_ID" >/dev/null
  sleep 4
  xcrun simctl io "$YANTU_SIM_UDID" screenshot "/tmp/yantu-$name.png" >/dev/null 2>&1
  sips -z 1565 720 "/tmp/yantu-$name.png" --out "$OUT_DIR/$name.png" >/dev/null
  echo "  $name.png"
}

echo "Capturing from $YANTU_SIM_UDID ($BUNDLE_ID)"
shot today    SIMCTL_CHILD_YANTU_TAB=today
shot logs     SIMCTL_CHILD_YANTU_TAB=research SIMCTL_CHILD_YANTU_PAGE=logs
shot digest   SIMCTL_CHILD_YANTU_TAB=research SIMCTL_CHILD_YANTU_PAGE=digest
shot projects SIMCTL_CHILD_YANTU_TAB=research SIMCTL_CHILD_YANTU_PAGE=projects
shot reminders SIMCTL_CHILD_YANTU_TAB=schedule SIMCTL_CHILD_YANTU_MODE=reminders
shot habits   SIMCTL_CHILD_YANTU_TAB=life SIMCTL_CHILD_YANTU_LIFEPAGE=habits
echo "Done. Wrote to $OUT_DIR"
