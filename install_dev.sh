#!/bin/bash
set -euo pipefail

DRY_RUN=false
AUTO_APPROVE=false
CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
DEV_ROOT="$CACHE_HOME/tmux-anchor-window-name/dev"
BIN_DIR="$DEV_ROOT/bin"
MANIFEST="$DEV_ROOT/tools.toml"

usage() {
    echo "Usage: $0 [--dry-run] [--yes]"
    echo "  --dry-run  Show which development tools would be installed"
    echo "  --yes      Install without prompting"
    echo "  --help     Show this help"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            ;;
        --yes|-y)
            AUTO_APPROVE=true
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
    shift
done

for command_name in apt-get apt-cache dpkg-deb; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "install_dev.sh currently requires an apt-based system ($command_name is missing)" >&2
        exit 1
    fi
done

packages=(bats shellcheck)
executables=(bats shellcheck)
versions=()
changes=()

for package in "${packages[@]}"; do
    # Do not exit awk early: with pipefail, apt-cache can otherwise receive
    # SIGPIPE and abort the installer on systems with verbose package policy.
    version="$(apt-cache policy "$package" | awk '/Candidate:/ && !found { print $2; found=1 }')"
    if [[ -z "$version" || "$version" == "(none)" ]]; then
        echo "No installable apt candidate found for $package" >&2
        exit 1
    fi
    versions+=("$version")
done

for index in "${!packages[@]}"; do
    package="${packages[$index]}"
    executable="${executables[$index]}"
    version="${versions[$index]}"
    safe_version="${version//:/_}"
    safe_version="${safe_version//\//_}"
    executable_path="$DEV_ROOT/packages/$package/$safe_version/root/usr/bin/$executable"
    if [[ ! -x "$executable_path" || ! -L "$BIN_DIR/$executable" || "$(readlink "$BIN_DIR/$executable" 2>/dev/null || true)" != "$executable_path" ]]; then
        changes+=("$package $version")
    fi
done

if [[ "${#changes[@]}" -eq 0 ]]; then
    echo "Development tools are already current"
    exit 0
fi

echo "Development tools to install in $DEV_ROOT:"
printf '  %s\n' "${changes[@]}"

if [[ "$DRY_RUN" == true ]]; then
    exit 0
fi

if [[ "$AUTO_APPROVE" == false ]]; then
    if [[ ! -t 0 ]]; then
        echo "Confirmation requires a terminal; rerun with --yes" >&2
        exit 1
    fi
    read -r -p "Install development tools [Y/n] " reply
    case "$reply" in
        ""|y|Y|yes|Yes|YES) ;;
        *) echo "Development tool installation cancelled"; exit 0 ;;
    esac
fi

mkdir -p "$BIN_DIR"
for index in "${!packages[@]}"; do
    package="${packages[$index]}"
    executable="${executables[$index]}"
    version="${versions[$index]}"
    safe_version="${version//:/_}"
    safe_version="${safe_version//\//_}"
    package_dir="$DEV_ROOT/packages/$package/$safe_version"
    download_dir="$package_dir/download"
    package_root="$package_dir/root"
    executable_path="$package_root/usr/bin/$executable"

    if [[ ! -x "$executable_path" ]]; then
        mkdir -p "$download_dir" "$package_root"
        deb_files=("$download_dir"/"${package}"_*.deb)
        if [[ ! -e "${deb_files[0]}" ]]; then
            echo "[RUN] Downloading $package $version"
            (cd "$download_dir" && apt-get download "$package")
            deb_files=("$download_dir"/"${package}"_*.deb)
        fi
        if [[ ! -e "${deb_files[0]}" ]]; then
            echo "apt-get did not download a package for $package" >&2
            exit 1
        fi
        echo "[RUN] Extracting $package $version"
        dpkg-deb -x "${deb_files[0]}" "$package_root"
    fi

    if [[ ! -x "$executable_path" ]]; then
        echo "$package did not provide the expected executable: $executable_path" >&2
        exit 1
    fi
    ln -sfn "$executable_path" "$BIN_DIR/$executable"
    echo "[OK] Installed $package $version"
done

{
    printf 'bats = "%s"\n' "${versions[0]}"
    printf 'shellcheck = "%s"\n' "${versions[1]}"
} >"$MANIFEST"

echo
echo "Development tools installed. Add this directory to PATH if desired:"
echo "  $BIN_DIR"
