# install-ivre.sh

An automated bootstrap script for running [IVRE](https://ivre.rocks/) with the
official Docker Compose configuration from the
[IVRE project](https://github.com/ivre/ivre) on Kali Linux and Debian-based systems.

The script automates the entire setup from a fresh Kali Linux installation to a
fully initialized IVRE environment:
- Checks and installs missing prerequisites (`git`, `docker.io`, `docker-compose-v2`) using `apt`
- Enables and starts the Docker daemon service
- Clones the official IVRE repository (by default into `~/ivre`)
- Starts the Docker Compose stack
- Automatically initializes IVRE databases (`ipinfo`, `scancli`, `view`, `flowcli`)
- Downloads and updates the IP intelligence database (`ivre ipdata --download`)
- Provides instructions and shortcuts to open the web GUI and update the database

## Requirements

- Kali Linux, Debian, or Ubuntu (or any Linux distribution with Docker and Git installed)
- Sudo/root privileges (if installing packages or starting Docker service)
- TCP port 80 available on the host

## Install and start

On a fresh Kali Linux installation:

```sh
git clone https://github.com/ShadeXploit/install-ivre.sh.git
cd install-ivre.sh
./install-ivre.sh
```

To install into a custom directory:

```sh
./install-ivre.sh --directory /path/to/ivre
```

To start the containers without running database initialization:

```sh
./install-ivre.sh --skip-init
```

## Access the Web GUI

Once installation finishes, access the IVRE web interface:

- In your browser: <http://localhost/>
- From the terminal:
  ```sh
  xdg-open http://localhost/
  ```
  Or using the script shortcut:
  ```sh
  ./install-ivre.sh --open
  ```

If accessing from a remote machine, replace `localhost` with the host's IP address.

## Update the IVRE Database

Whenever you want to refresh or update the IVRE IP intelligence database (GeoIP, AS numbers, etc.):

Using the script shortcut:

```sh
./install-ivre.sh --update-db
```

Or directly via Docker:

```sh
docker exec -i ivreclient ivre ipdata --download
```

*(Use `sudo docker ...` if your user is not yet in the `docker` group).*

## Command-line Options

| Option | Description |
|---|---|
| `-d, --directory PATH` | Install IVRE into `PATH` (default: `~/ivre`) |
| `--skip-init` | Start containers without initializing databases |
| `--update-db` | Update IVRE IP intelligence database (`ipdata --download`) |
| `--open` | Open the IVRE web GUI in the default browser |
| `-h, --help` | Display usage and help message |

## Manage the Services

Use Docker Compose in the installation directory to manage the stack:

Stop the services:
```sh
docker compose -f ~/ivre/docker/docker-compose.yml down
```

Start the services:
```sh
docker compose -f ~/ivre/docker/docker-compose.yml up -d
```

Replace `~/ivre` with your custom path if `--directory` was used.
Running `down` stops and removes the containers while preserving your database and data files.

## Manual Initialization (Optional)

If you ever need to manually reinitialize the IVRE database from inside the client container:

```sh
docker exec -it ivreclient sh
```

Then run:

```sh
yes | ivre ipinfo --init
yes | ivre scancli --init
yes | ivre view --init
yes | ivre flowcli --init
ivre ipdata --download
```

## Safety

IVRE is a network reconnaissance platform. Only scan systems and networks
that you own or are explicitly authorized to assess. The official Compose
configuration publishes the web interface on host port 80; review its
configuration and your network exposure before using it on a shared or
publicly accessible host.
