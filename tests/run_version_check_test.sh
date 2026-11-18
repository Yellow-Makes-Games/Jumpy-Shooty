#!/usr/bin/env bash
# The version check when joining (see Net: the version check). A host on v0.1.30 and
# four copies joining it:
#  - v0.1.29 (older): not let in, told both versions and to update its game
#  - v0.1.31 (newer): not let in, told both versions and that the host must update
#  - v0.1.30 (the same): joins
#  - a dev build (no version, like the editor): joins
#  - no script errors anywhere
# Usage: tests/run_version_check_test.sh
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
OUT=tests/out
mkdir -p "$OUT"
rm -f "$OUT"/version_*.log
PORT=$((26500 + RANDOM % 100))
COMMON=(--sync-log --scripted-input --map=construction_site)

"$GODOT" --headless --path . -- --host --port="$PORT" --name=Host --fake-version=v0.1.30 --quit-after=14 "${COMMON[@]}" \
  > "$OUT/version_host.log" 2>&1 &
sleep 1
for who in older:v0.1.29 newer:v0.1.31 same:v0.1.30 dev:; do
  name="${who%%:*}" ver="${who#*:}"
  args=(--join="127.0.0.1:$PORT" --name="$name" --quit-after=11)
  if [[ -n "$ver" ]]; then args+=(--fake-version="$ver"); fi
  "$GODOT" --headless --path . -- "${args[@]}" "${COMMON[@]}" > "$OUT/version_$name.log" 2>&1 &
done
wait || true

fail=0
if grep -h "SCRIPT ERROR" "$OUT"/version_*.log; then echo "FAIL: script errors"; fail=1; fi
python3 - "$OUT" <<'PY' || fail=1
import sys
out = sys.argv[1]
ok = True


def check(cond, what):
    global ok
    print(("  ok    " if cond else "  FAIL  ") + what)
    ok = ok and cond


def text(name):
    return open(f"{out}/version_{name}.log", errors="replace").read()


def joined(name):
    return "LOBBY_SETTINGS " in text(name)


def failed(name):
    for line in text(name).splitlines():
        if line.startswith("JOIN_FAILED "):
            return line[len("JOIN_FAILED "):]
    return ""


older, newer = failed("older"), failed("newer")
check(not joined("older") and "host is on v0.1.30" in older and "you are on v0.1.29" in older and "Update your game" in older,
      f"an older copy is kept out, told both versions and to update ({older or 'not told'})")
check(not joined("newer") and "host is on v0.1.30" in newer and "you are on v0.1.31" in newer and "host needs to update" in newer,
      f"a newer copy is kept out and told the host must update ({newer or 'not told'})")
check(joined("same") and failed("same") == "", "a copy on the same version joins")
check(joined("dev") and failed("dev") == "", "a dev build (no version) joins")
check(text("host").count("VERSION_HELLO ") >= 4, "the host heard every copy's version")
print("PASS: version check test" if ok else "FAIL: version check test")
sys.exit(0 if ok else 1)
PY
exit $fail
