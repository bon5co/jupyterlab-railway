#!/bin/bash
# Boot sequence for JupyterLab on Railway. Runs as root; hands over to the image's own
# start.sh, which drops to jovyan.
set -euo pipefail

HOME_DIR=/home/jovyan
SKEL=/opt/home-skel

if [ -z "${JUPYTER_PASSWORD:-}" ]; then
    echo "[railway] JUPYTER_PASSWORD is empty. JupyterLab runs arbitrary code, so this" >&2
    echo "[railway] image refuses to start without a password. Set JUPYTER_PASSWORD." >&2
    exit 1
fi

# Railway mounts volumes owned by uid 0 and the notebook runs as 1000:100.
echo "[railway] $HOME_DIR owned by $(stat -c %u:%g "$HOME_DIR"), repairing to 1000:100"
rm -rf "$HOME_DIR/lost+found"
chown -R 1000:100 "$HOME_DIR"

# Restore anything the volume mount hid.
for entry in "$SKEL"/* "$SKEL"/.[!.]*; do
    [ -e "$entry" ] || continue
    name=$(basename "$entry")
    if [ ! -e "$HOME_DIR/$name" ]; then
        cp -a "$entry" "$HOME_DIR/$name"
        echo "[railway] restored $name"
    fi
done
mkdir -p "$HOME_DIR/.jupyter" "$HOME_DIR/.local/bin" "$HOME_DIR/.local/share" "$HOME_DIR/work"
chown -R 1000:100 "$HOME_DIR/.jupyter" "$HOME_DIR/.local" "$HOME_DIR/work"

# Apply the password on every boot, so a redeploy is a working password reset.
JUPYTER_CONFIG="$HOME_DIR/.jupyter/jupyter_server_config.json" \
    /opt/conda/bin/python - <<'PY'
import json, os
from jupyter_server.auth import passwd
path = os.environ["JUPYTER_CONFIG"]
config = {}
if os.path.exists(path):
    try:
        with open(path) as handle:
            config = json.load(handle)
    except ValueError:
        config = {}
config.setdefault("IdentityProvider", {})["hashed_password"] = passwd(
    os.environ["JUPYTER_PASSWORD"]
)
with open(path, "w") as handle:
    json.dump(config, handle, indent=1)
PY
chown 1000:100 "$HOME_DIR/.jupyter/jupyter_server_config.json"
echo "[railway] password applied"

# Railway's healthcheck dials the port it injected, not the domain's target port.
export JUPYTER_PORT="${PORT:-8888}"
echo "[railway] serving on ${JUPYTER_PORT}"

exec tini -g -- start.sh start-notebook.py "$@"
