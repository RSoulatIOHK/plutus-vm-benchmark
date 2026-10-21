#!/usr/bin/env bash
# Facts about the per-VM images (docs/IMAGE_CONTRACT.md), shared by local builds and CI.
#
#   scripts/images.sh list               every VM that has an image, one per line
#   scripts/images.sh dir <vm>           images/<dir> that holds the VM's Dockerfile
#   scripts/images.sh build-args <vm>    KEY=VALUE lines to pass as --build-arg
#   scripts/images.sh tag <vm>           content hash: changes only when the VM's inputs change
#   scripts/images.sh build <vm> [docker build options...]
#                                        build ${IMAGE_PREFIX}<vm>:<tag> and :latest locally
#
# A Dockerfile serves the VM named like its directory, unless its header has a line
# "# pvb-vms: <vm> <vm>..." (one build shared by several VMs, for example scalus-cek and
# scalus-jit). Such a Dockerfile takes the build arg VM, which selects the default command.
#
# Written for bash 3.2 (macOS /bin/bash): no associative arrays, no mapfile.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE_PREFIX="${IMAGE_PREFIX:-ghcr.io/lantr-io/pvb-}"

die() { echo "images.sh: $*" >&2; exit 1; }

# VMs served by images/<dir>/Dockerfile.
vms_of_dir() {
    local dockerfile="$REPO_ROOT/images/$1/Dockerfile"
    local declared
    declared=$(sed -n 's/^# pvb-vms:[[:space:]]*//p' "$dockerfile" | head -1)
    if [[ -n "$declared" ]]; then echo "$declared" | tr ' ' '\n' | grep -v '^$'; else echo "$1"; fi
}

cmd_list() {
    local d
    for d in "$REPO_ROOT"/images/*/Dockerfile; do
        vms_of_dir "$(basename "$(dirname "$d")")"
    done
}

cmd_dir() {
    local vm="$1" d
    for d in "$REPO_ROOT"/images/*/Dockerfile; do
        d=$(basename "$(dirname "$d")")
        if vms_of_dir "$d" | grep -qx "$vm"; then echo "images/$d"; return; fi
    done
    die "no image for VM '$vm'"
}

# Value of KEY in .env, without the inline "# comment" and surrounding blanks.
env_value() {
    sed -n "s/^$1=//p" "$REPO_ROOT/.env" | head -1 | sed 's/[[:space:]]#.*$//; s/[[:space:]]*$//'
}

cmd_build_args() {
    local vm="$1" dir arg value
    dir=$(cmd_dir "$vm")
    for arg in $(sed -n 's/^ARG[[:space:]]\{1,\}\([A-Z0-9_]\{1,\}\).*/\1/p' "$REPO_ROOT/$dir/Dockerfile" | sort -u); do
        if [[ "$arg" == VM ]]; then
            echo "VM=$vm"
            continue
        fi
        value=$(env_value "$arg")
        [[ -n "$value" ]] || die "$dir/Dockerfile declares ARG $arg, but .env has no value for it"
        echo "$arg=$value"
    done
}

# Repo files the image is built from: its images/<dir>/ and every local COPY source.
input_files() {
    local dir="$1" src
    (
        cd "$REPO_ROOT"
        {
            find "$dir" -type f
            # COPY lines without --from=; drop flags and the destination (last word).
            grep -E '^COPY[[:space:]]' "$dir/Dockerfile" | grep -v -- '--from=' \
                | sed 's/^COPY[[:space:]]*//; s/--[a-z]*=[^[:space:]]*//g' \
                | awk '{ for (i = 1; i < NF; i++) print $i }' \
                | while read -r src; do
                    if [[ -d "$src" ]]; then find "$src" -type f; else ls -1 $src; fi
                done
        } | sed 's|^\./||; s|/$||' | grep -v -e '__pycache__' -e '\.pyc$' | LC_ALL=C sort -u
    )
}

cmd_tag() {
    local vm="$1" dir f
    dir=$(cmd_dir "$vm")
    {
        cmd_build_args "$vm"
        for f in $(input_files "$dir"); do
            echo "$f $(git -C "$REPO_ROOT" hash-object "$f")"
        done
    } | git hash-object --stdin | cut -c1-12
}

cmd_build() {
    local vm="$1"; shift
    local dir tag args=() line
    dir=$(cmd_dir "$vm")
    tag=$(cmd_tag "$vm")
    while IFS= read -r line; do args+=(--build-arg "$line"); done < <(cmd_build_args "$vm")
    echo "Building ${IMAGE_PREFIX}${vm}:${tag} from $dir/Dockerfile" >&2
    docker build ${args[@]+"${args[@]}"} "$@" \
        -f "$REPO_ROOT/$dir/Dockerfile" \
        -t "${IMAGE_PREFIX}${vm}:${tag}" -t "${IMAGE_PREFIX}${vm}:latest" \
        "$REPO_ROOT"
}

[[ $# -ge 1 ]] || die "usage: $0 list | dir <vm> | build-args <vm> | tag <vm> | build <vm> [options]"
case "$1" in
    list) cmd_list ;;
    dir) cmd_dir "${2:?vm}" ;;
    build-args) cmd_build_args "${2:?vm}" ;;
    tag) cmd_tag "${2:?vm}" ;;
    build) shift; vm="${1:?vm}"; shift; cmd_build "$vm" "$@" ;;
    *) die "unknown command '$1'" ;;
esac
