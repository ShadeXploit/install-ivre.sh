#!/usr/bin/env bash

set -eu

usage() {
    cat <<'EOF'
Usage: install-ivre.sh [--directory PATH]

Clone IVRE and start its official Docker Compose stack.

Options:
  -d, --directory PATH  Install IVRE in PATH (default: ~/ivre)
  -h, --help            Show this help
EOF
}

fail() {
    printf 'Error: %s\n' "$1" >&2
    exit 1
}

install_dir="${HOME:?HOME must be set}/ivre"
while [ "$#" -gt 0 ]; do
    case "$1" in
        -d|--directory)
            [ "$#" -ge 2 ] || fail "missing path for $1"
            install_dir=$2
            shift 2
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

command -v git >/dev/null 2>&1 || fail "git is required"
command -v docker >/dev/null 2>&1 || fail "docker is required"
docker compose version >/dev/null 2>&1 || fail "Docker Compose v2 is required"
docker info >/dev/null 2>&1 || fail "the Docker daemon is unavailable or permission was denied"

compose_file="$install_dir/docker/docker-compose.yml"
if [ ! -f "$compose_file" ]; then
    [ ! -e "$install_dir" ] || fail "$install_dir exists but is not an IVRE installation"
    git clone --depth 1 https://github.com/ivre/ivre.git "$install_dir"
fi

docker compose -f "$compose_file" up -d
printf 'IVRE services started. Open http://localhost/ to access the web interface.\n'
