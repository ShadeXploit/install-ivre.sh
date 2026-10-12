# install-ivre.sh

A small bootstrap script for running [IVRE](https://ivre.rocks/) with the
official Docker Compose configuration from the
[IVRE project](https://github.com/ivre/ivre).

The script checks that its prerequisites are available, clones the official
IVRE repository (by default into `~/ivre`), and starts its Compose services.
It does not install Docker or modify system packages.

## Requirements

- Git
- Docker Engine with the Docker Compose v2 plugin
- A running Docker daemon and permission to use it
- TCP port 80 available on the host

## Install and start

```sh
git clone https://github.com/ShadeXploit/install-ivre.sh.git
cd install-ivre.sh
./install-ivre.sh
```

To use a different installation directory:

```sh
./install-ivre.sh --directory /path/to/ivre
```

When the services are ready, open <http://localhost/>. IVRE's Compose
configuration stores its database and shared data beneath the cloned
repository's `docker/` directory.

## Initialize IVRE

After the services start, open a shell in the IVRE client container:

```sh
docker exec -it ivreclient sh
```

Run the initialization commands in that shell:

```sh
yes | ivre ipinfo --init
yes | ivre scancli --init
yes | ivre view --init
yes | ivre flowcli --init
ivre ipdata --download
```

For more information on importing scan results and using IVRE, see the
[official documentation](https://ivre.rocks/).

## Manage the services

Use the Compose file in the installation directory to stop the stack:

```sh
docker compose -f ~/ivre/docker/docker-compose.yml down
```

Replace `~/ivre` with the directory passed to `--directory`, if applicable.
Running `down` stops and removes the containers but leaves the data files in
place.

## Safety

IVRE is a network reconnaissance platform. Only scan systems and networks
that you own or are explicitly authorized to assess. The official Compose
configuration publishes the web interface on host port 80; review its
configuration and your network exposure before using it on a shared or
publicly accessible host.
