#!/usr/bin/env bash

set -eu

usage() {
    cat <<'EOF'
Usage: install-ivre.sh [OPTIONS]

Automated installer and manager for IVRE on Kali Linux and Debian systems.
Installs prerequisites (Docker, Docker Compose, Git), starts services,
and initializes the IVRE database.

Options:
  -d, --directory PATH  Install IVRE in PATH (default: ~/ivre)
      --skip-init       Start containers but skip database initialization
      --update-db       Update IVRE IP intelligence database (runs ipdata download)
      --open            Open the IVRE web GUI in the default browser
  -h, --help            Show this help message
EOF
}

fail() {
    printf 'Error: %s\n' "$1" >&2
    exit 1
}

run_privileged() {
    if [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1; then
        sudo "$@"
    else
        "$@"
    fi
}

USE_SUDO_DOCKER=false
USE_COMPOSE_PLUGIN=true

run_docker() {
    if [ "$USE_SUDO_DOCKER" = true ]; then
        run_privileged docker "$@"
    else
        docker "$@"
    fi
}

run_compose() {
    if [ "$USE_COMPOSE_PLUGIN" = true ]; then
        run_docker compose "$@"
    elif [ "$USE_SUDO_DOCKER" = true ]; then
        run_privileged docker-compose "$@"
    else
        docker-compose "$@"
    fi
}

ensure_dependencies() {
    local missing_pkgs=()

    command -v git >/dev/null 2>&1 || missing_pkgs+=(git)
    command -v docker >/dev/null 2>&1 || missing_pkgs+=(docker.io)

    if ! docker compose version >/dev/null 2>&1 && ! command -v docker-compose >/dev/null 2>&1; then
        if command -v apt-cache >/dev/null 2>&1; then
            if apt-cache show docker-compose-v2 >/dev/null 2>&1; then
                missing_pkgs+=(docker-compose-v2)
            elif apt-cache show docker-compose-plugin >/dev/null 2>&1; then
                missing_pkgs+=(docker-compose-plugin)
            elif apt-cache show docker-compose >/dev/null 2>&1; then
                missing_pkgs+=(docker-compose)
            fi
        fi
    fi

    if [ "${#missing_pkgs[@]}" -gt 0 ]; then
        if command -v apt-get >/dev/null 2>&1; then
            printf 'Missing dependencies detected: %s\n' "${missing_pkgs[*]}"
            printf 'Installing prerequisites via apt...\n'
            run_privileged env DEBIAN_FRONTEND=noninteractive apt-get update
            run_privileged env DEBIAN_FRONTEND=noninteractive apt-get install -y "${missing_pkgs[@]}"
        else
            fail "Missing required dependencies: ${missing_pkgs[*]}. Please install them using your package manager."
        fi
    fi

    command -v git >/dev/null 2>&1 || fail "git is required but could not be found"
    command -v docker >/dev/null 2>&1 || fail "docker is required but could not be found"
}

ensure_docker_daemon() {
    if ! docker info >/dev/null 2>&1; then
        if command -v systemctl >/dev/null 2>&1; then
            if ! systemctl is-active --quiet docker 2>/dev/null; then
                printf 'Starting Docker service...\n'
                run_privileged systemctl enable --now docker >/dev/null 2>&1 || run_privileged systemctl start docker >/dev/null 2>&1 || true
            fi
        elif command -v service >/dev/null 2>&1; then
            printf 'Starting Docker service...\n'
            run_privileged service docker start >/dev/null 2>&1 || true
        fi

        local count=0
        while [ "$count" -lt 15 ]; do
            if docker info >/dev/null 2>&1 || { [ "$(id -u)" -ne 0 ] && run_privileged docker info >/dev/null 2>&1; }; then
                break
            fi
            sleep 1
            count=$((count + 1))
        done
    fi

    if docker info >/dev/null 2>&1; then
        USE_SUDO_DOCKER=false
    elif [ "$(id -u)" -ne 0 ] && run_privileged docker info >/dev/null 2>&1; then
        USE_SUDO_DOCKER=true
        if [ -n "${USER:-}" ]; then
            run_privileged usermod -aG docker "$USER" 2>/dev/null || true
            printf 'Added user %s to the docker group (effective on next login).\n' "$USER"
        fi
    else
        fail "The Docker daemon is unavailable or permission was denied. Try starting it with: sudo systemctl start docker"
    fi

    if run_docker compose version >/dev/null 2>&1; then
        USE_COMPOSE_PLUGIN=true
    elif command -v docker-compose >/dev/null 2>&1; then
        USE_COMPOSE_PLUGIN=false
    else
        fail "Docker Compose v2 is required but could not be found."
    fi
}

wait_for_containers() {
    printf 'Waiting for IVRE containers to start...\n'
    local count=0
    while [ "$count" -lt 30 ]; do
        local client_status db_status
        client_status=$(run_docker inspect -f '{{.State.Status}}' ivreclient 2>/dev/null || true)
        db_status=$(run_docker inspect -f '{{.State.Status}}' ivredb 2>/dev/null || true)
        if [ "$client_status" = "running" ] && [ "$db_status" = "running" ]; then
            break
        fi
        sleep 2
        count=$((count + 2))
    done

    # Allow MongoDB a moment to accept connections
    sleep 3
}

init_database() {
    printf 'Initializing IVRE database (ipinfo, scancli, view, flowcli)...\n'
    printf 'yes\n' | run_docker exec -i ivreclient ivre ipinfo --init
    printf 'yes\n' | run_docker exec -i ivreclient ivre scancli --init
    printf 'yes\n' | run_docker exec -i ivreclient ivre view --init
    printf 'yes\n' | run_docker exec -i ivreclient ivre flowcli --init

    printf 'Downloading IVRE IP intelligence data...\n'
    if run_docker exec -i ivreclient ivre ipdata --download; then
        printf 'IVRE IP data download complete.\n'
    else
        printf 'Warning: IP data download failed (check internet connection).\n' >&2
        if [ "$USE_SUDO_DOCKER" = true ]; then
            printf 'You can update it later by running: sudo docker exec -i ivreclient ivre ipdata --download\n' >&2
        else
            printf 'You can update it later by running: docker exec -i ivreclient ivre ipdata --download\n' >&2
        fi
    fi
}

open_webgui() {
    local url="http://localhost/"
    printf 'Opening IVRE web interface (%s)...\n' "$url"
    if command -v xdg-open >/dev/null 2>&1; then
        xdg-open "$url" >/dev/null 2>&1 &
    elif command -v sensible-browser >/dev/null 2>&1; then
        sensible-browser "$url" >/dev/null 2>&1 &
    elif command -v firefox >/dev/null 2>&1; then
        firefox "$url" >/dev/null 2>&1 &
    elif command -v x-www-browser >/dev/null 2>&1; then
        x-www-browser "$url" >/dev/null 2>&1 &
    elif command -v python3 >/dev/null 2>&1 && python3 -m webbrowser "$url" >/dev/null 2>&1; then
        :
    else
        printf 'No browser launcher found. Please open %s in your browser.\n' "$url"
        return 1
    fi
}

update_database() {
    ensure_docker_daemon
    local client_status
    client_status=$(run_docker inspect -f '{{.State.Status}}' ivreclient 2>/dev/null || true)
    if [ "$client_status" != "running" ]; then
        if [ -f "$compose_file" ]; then
            printf 'IVRE containers are not running. Starting them...\n'
            run_compose -f "$compose_file" up -d
            wait_for_containers
        else
            fail "Container 'ivreclient' is not running and compose file '$compose_file' was not found."
        fi
    fi

    printf 'Updating IVRE IP intelligence database...\n'
    if run_docker exec -i ivreclient ivre ipdata --download; then
        printf 'IVRE database successfully updated.\n'
    else
        fail "Failed to download IVRE IP data. Please check your network connection."
    fi
}

print_instructions() {
    local docker_pfx="docker"
    local compose_pfx="docker compose"
    if [ "$USE_SUDO_DOCKER" = true ]; then
        docker_pfx="sudo docker"
        compose_pfx="sudo docker compose"
    elif [ "$USE_COMPOSE_PLUGIN" = false ]; then
        compose_pfx="docker-compose"
    fi

    cat <<EOF

===================================================================
                  IVRE Setup Complete!
===================================================================

[+] Open the Web GUI:
    In your web browser, navigate to:
        http://localhost/
    Or from the terminal, run:
        xdg-open http://localhost/
    Or:
        $0 --open

[+] Update the IVRE Database:
    Whenever you want to update the IP intelligence data, run:
        $0 --update-db
    Or directly in Docker:
        $docker_pfx exec -i ivreclient ivre ipdata --download

[+] Service Management:
    Stop IVRE services:
        $compose_pfx -f "$compose_file" down
    Start IVRE services:
        $compose_pfx -f "$compose_file" up -d

===================================================================
EOF
}

action="install"
skip_init=false
install_dir="${HOME:?HOME must be set}/ivre"

while [ "$#" -gt 0 ]; do
    case "$1" in
        -d|--directory)
            [ "$#" -ge 2 ] || fail "missing path for $1"
            install_dir=$2
            shift 2
            ;;
        --skip-init)
            skip_init=true
            shift
            ;;
        --update-db)
            action="update-db"
            shift
            ;;
        --open)
            action="open"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            usage >&2
            fail "unknown option: $1"
            ;;
    esac
done

compose_file="$install_dir/docker/docker-compose.yml"

case "$action" in
    open)
        open_webgui
        exit 0
        ;;
    update-db)
        update_database
        exit 0
        ;;
    install)
        ensure_dependencies
        ensure_docker_daemon

        if [ ! -f "$compose_file" ]; then
            if [ -e "$install_dir" ] && [ -n "$(ls -A "$install_dir" 2>/dev/null)" ]; then
                fail "$install_dir exists and is not empty, but is not an IVRE installation"
            fi
            printf 'Cloning official IVRE repository into %s...\n' "$install_dir"
            git clone --depth 1 https://github.com/ivre/ivre.git "$install_dir"
        fi

        printf 'Starting IVRE Docker Compose services...\n'
        run_compose -f "$compose_file" up -d

        if [ "$skip_init" = false ]; then
            wait_for_containers
            init_database
        fi

        print_instructions
        ;;
esac
