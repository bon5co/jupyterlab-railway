# JupyterLab for Railway.
#
# Wraps the official Jupyter Docker Stacks scipy-notebook image, pinned by digest so
# the environment a deploy is built against does not drift, and adds the three things
# a Railway deploy needs: the whole home directory on the volume, pip installs that
# survive a redeploy, and a password that is applied before the port opens.
FROM quay.io/jupyter/scipy-notebook@sha256:41e9176dc64072976c43c037f853ae9a95ca34aeb0170c58a1b304d62fbde486

USER root

# A Railway volume is a bind mount, so mounting it at /home/jovyan hides everything the
# image build wrote there. Keep a pristine copy outside the mount and restore it on boot.
RUN cp -a /home/jovyan /opt/home-skel && chown -R 1000:100 /opt/home-skel

# `pip install` in the stock image lands in /opt/conda, which is part of the image layer
# and is therefore discarded on every redeploy. Send user installs to ~/.local instead,
# which lives on the volume.
ENV PIP_USER=1 \
    PATH=/home/jovyan/.local/bin:/opt/conda/bin:/opt/conda/condabin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    RESTARTABLE=yes

COPY railway-entrypoint.sh /usr/local/bin/railway-entrypoint.sh
RUN chmod +x /usr/local/bin/railway-entrypoint.sh

# Stays root so the entrypoint can repair the uid-0 volume mount; start.sh drops to
# jovyan (NB_UID 1000) before the server starts.
ENTRYPOINT ["/usr/local/bin/railway-entrypoint.sh"]
