#!/bin/bash

set -eu

# FIXME: This should be replace by a mount of devtmpfs when
# it is supported in user namespaces
bind_dev() {
    dev="${1}/dev"

    for device in null zero full random urandom tty; do
        touch "${dev}/${device}"
        mount --bind "/dev/${device}" "${dev}/${device}"
    done
}

if [ $# -lt 3 ]; then
    echo "Expected at least 3 arguments" 1>&2
    exit 1
fi

command="${1}"
sysroot="${2}"
shift 2

case "${command}" in
    spawn)
        cleanup() {
            umount "${sysroot}/dev" || true
            umount "${sysroot}/tmp" || true
        }
        mount -t tmpfs -o mode=0755 tmpfs "${sysroot}/dev"
        mount -t tmpfs -o mode=1777 tmpfs "${sysroot}/tmp"
        trap cleanup EXIT
        unshare --pid --fork --mount -- "${0}" init "${sysroot}" "${@}"
        ;;
    init)
        mount -t proc proc "${sysroot}/proc"
        bind_dev "${sysroot}"
        mount --bind -o ro /etc/resolv.conf "${sysroot}"/etc/resolv.conf
        while [ $# -gt 1 ]; do
            case "${1}" in
                --)
                    shift
                    break
                    ;;
                --bind|--robind)
                    if [ -d "$2" ]; then
                        if ! [ -d "${sysroot}/$3" ]; then
                            mkdir -p "${sysroot}/$3"
                        fi
                    else
                        if ! [ -e "${sysroot}/$3" ]; then
                            touch "${sysroot}/$3"
                        fi
                    fi
                    extra_args=()
                    case "$1" in
                        --robind)
                            extra_args=("-o" "ro")
                            ;;
                    esac
                    mount --bind "${extra_args[@]}" "$2" "${sysroot}/$3"
                    shift 3
                    ;;
                *)
                    break
                    ;;
            esac
        done
        exec unshare --mount --root="${sysroot}" -- "${@}"
        ;;
    *)
        echo "Unknown command" 1>&2
        exit 1
        ;;
esac
