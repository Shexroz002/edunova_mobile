#!/usr/bin/env bash
#
# Runs the app on a USB-connected phone or tablet with the backend reachable.
#
# A physical device cannot reach the backend on its own: this Wi-Fi blocks
# device-to-device traffic, so `http://127.0.0.1:8000` only resolves through an
# `adb reverse` tunnel — and that tunnel is dropped every time the cable is
# unplugged, the phone reboots or the adb server restarts. Forgetting it looks
# exactly like a server outage ("Serverga ulanib bo'lmadi"), which is why it
# lives in a script instead of in someone's memory.
#
#   tool/run.sh                 build, install and attach
#   tool/run.sh --tunnel-only   open the tunnel once, then launch from the IDE
#   tool/run.sh --watch         keep the tunnel open: reopens it whenever the
#                               device reconnects. Leave it running in a tab.
#   tool/run.sh --release       any extra flags are passed through to flutter run
#
# Set ANDROID_SERIAL when more than one device is connected.

set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG="config/device.json"

MODE="run"
case "${1-}" in
  --tunnel-only) MODE="tunnel"; shift ;;
  --watch) MODE="watch"; shift ;;
esac

command -v adb >/dev/null || { echo "adb topilmadi — Android SDK platform-tools kerak." >&2; exit 1; }
[[ -f "$CONFIG" ]] || { echo "$CONFIG topilmadi." >&2; exit 1; }

# One source of truth for the port: whatever API_BASE_URL says.
PORT="$(sed -n 's/.*127\.0\.0\.1:\([0-9]\+\).*/\1/p' "$CONFIG" | head -1)"
if [[ -z "$PORT" ]]; then
  echo "$CONFIG ichida http://127.0.0.1:<port> yo'q — tunnel kerak emas, to'g'ridan-to'g'ri ishga tushiring." >&2
  exit 1
fi

# Echoes the serial to use, or fails when there is nothing to pick.
pick_device() {
  local devices serial
  mapfile -t devices < <(adb devices | awk '$2 == "device" { print $1 }')
  if [[ ${#devices[@]} -eq 0 ]]; then
    echo "Qurilma ulanmagan. USB debugging yoqilganini tekshiring." >&2
    return 1
  fi
  if [[ -n "${ANDROID_SERIAL-}" ]]; then
    serial="$ANDROID_SERIAL"
    if ! printf '%s\n' "${devices[@]}" | grep -qx "$serial"; then
      echo "ANDROID_SERIAL=$serial ulangan qurilmalar orasida yo'q:" >&2
      printf '  %s\n' "${devices[@]}" >&2
      return 1
    fi
  elif [[ ${#devices[@]} -eq 1 ]]; then
    serial="${devices[0]}"
  else
    echo "Bir nechta qurilma ulangan:" >&2
    printf '  %s\n' "${devices[@]}" >&2
    echo "ANDROID_SERIAL=<serial> tool/run.sh deb yurgizing." >&2
    return 1
  fi
  echo "$serial"
}

# True when the device already forwards the port back to this machine.
tunnel_is_open() {
  adb -s "$1" reverse --list 2>/dev/null | grep -q "tcp:$PORT tcp:$PORT"
}

# A dead backend is a different failure with the same symptom, so name it here
# rather than letting the app show a connection error.
warn_if_backend_down() {
  if ! curl -s -o /dev/null --max-time 4 "http://127.0.0.1:$PORT/docs"; then
    echo "Diqqat: backend 127.0.0.1:$PORT da javob bermayapti. Konteynerlarni tekshiring." >&2
  fi
}

SERIAL="$(pick_device)"
adb -s "$SERIAL" reverse "tcp:$PORT" "tcp:$PORT" >/dev/null
echo "Tunnel tayyor: $SERIAL → 127.0.0.1:$PORT"
warn_if_backend_down

case "$MODE" in
  tunnel)
    exit 0
    ;;
  watch)
    echo "Kuzatilmoqda. To'xtatish uchun Ctrl+C."
    while sleep 3; do
      # The serial is resolved again each round: a replugged device can come
      # back under a different one, and adb forgets every reverse it had.
      if ! serial="$(pick_device 2>/dev/null)"; then
        continue
      fi
      if tunnel_is_open "$serial"; then
        continue
      fi
      if adb -s "$serial" reverse "tcp:$PORT" "tcp:$PORT" >/dev/null 2>&1; then
        echo "$(date '+%H:%M:%S')  tunnel qayta ochildi: $serial → 127.0.0.1:$PORT"
      fi
    done
    ;;
esac

exec flutter run -d "$SERIAL" --dart-define-from-file="$CONFIG" "$@"
