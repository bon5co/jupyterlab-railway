# jupyterlab-railway

Railway wrapper image for JupyterLab (Jupyter Docker Stacks `scipy-notebook`).

Fixes three things a stock deploy on Railway gets wrong:

1. **The whole home directory is the persistent volume.** Upstream's file-browser root is
   `/home/jovyan`, so a volume mounted only at `/home/jovyan/work` loses every notebook saved
   in the default directory. A pristine copy of the image's home skeleton lives at
   `/opt/home-skel` and is restored for any entry the volume does not already have.
2. **`pip install` persists.** `PIP_USER=1` sends packages to
   `/home/jovyan/.local/lib/python3.13/site-packages` (on the volume) instead of the image's
   `/opt/conda` site-packages, which is discarded on every redeploy.
3. **Railway's injected `$PORT` is honoured** (`JUPYTER_PORT=$PORT`), and the volume's
   root-owned mount is repaired to `1000:100` before `start.sh` drops privileges.

The container refuses to boot without `JUPYTER_PASSWORD`; the password is re-applied on every
boot, so a redeploy is a working password reset.

| Variable | Required | Meaning |
|---|---|---|
| `JUPYTER_PASSWORD` | yes | JupyterLab login password. Empty value fails the boot. |
| `PORT` | injected | Listen port. |

Volume mount path: `/home/jovyan`.
