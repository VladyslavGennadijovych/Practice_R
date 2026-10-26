#!/usr/bin/env bash
set -euo pipefail

scripts_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$scripts_dir/.." && pwd)
export PRACTICE_R_SETUP_ROOT="${PRACTICE_R_SETUP_ROOT:-/workspace/.practice-r-setup}"
setup_root="$PRACTICE_R_SETUP_ROOT"
lock_file="$repo_root/environment/conda-linux-64.lock"
case "$setup_root" in
  /*) ;;
  *) printf 'PRACTICE_R_SETUP_ROOT must be an absolute path.\n' >&2; exit 1 ;;
esac
if [ "$(uname -s)" != Linux ] || [ "$(uname -m)" != x86_64 ]; then
  printf 'This locked environment supports Linux x86_64 only.\n' >&2
  exit 1
fi
test -s "$lock_file"
mkdir -p "$setup_root/bin" "$setup_root/mamba/pkgs" "$setup_root/cache" \
  "$setup_root/library" "$setup_root/renv"
# Micromamba uses its standard per-user registry in addition to the prefix.
mkdir -p "$HOME/.conda"
export MAMBA_ROOT_PREFIX="$setup_root/mamba"
export CONDA_PKGS_DIRS="$setup_root/mamba/pkgs"
export XDG_CACHE_HOME="$setup_root/cache"
mamba_bin="$setup_root/bin/micromamba"
mamba_sha=366cd9cd8be14df1ab8ed50352a82111082a36686b2d389fdb79a92c3fafb3e3
mamba_download=""
current_lock=""
cleanup() {
  if [ -n "$mamba_download" ]; then rm -f "$mamba_download"; fi
  if [ -n "$current_lock" ]; then rm -f "$current_lock"; fi
}
trap cleanup EXIT
if [ ! -f "$mamba_bin" ]; then
  mamba_download=$(mktemp "$setup_root/bin/micromamba-download.XXXXXX")
  curl --fail --silent --show-error --location --retry 2 \
    --output "$mamba_download" \
    https://github.com/mamba-org/micromamba-releases/releases/download/2.9.0-0/micromamba-linux-64
  printf '%s  %s\n' "$mamba_sha" "$mamba_download" | sha256sum --check --status
  mv "$mamba_download" "$mamba_bin"
  mamba_download=""
fi
printf '%s  %s\n' "$mamba_sha" "$mamba_bin" | sha256sum --check --status
chmod u+x "$mamba_bin"

if [ -f "$setup_root/env/conda-meta/history" ]; then
  action=install
else
  action=create
fi
matches_lock=false
if [ "$action" = install ]; then
  current_lock=$(mktemp "$setup_root/current-lock.XXXXXX")
  "$mamba_bin" --no-rc env export --prefix "$setup_root/env" --explicit > "$current_lock"
  if cmp -s "$current_lock" "$lock_file"; then
    matches_lock=true
  fi
fi
if [ "$matches_lock" = true ]; then
  printf 'Installed environment matches the repository package lock.\n'
else
  "$mamba_bin" --no-rc "$action" --yes --prefix "$setup_root/env" --file "$lock_file"
fi

source "$scripts_dir/activate-r.sh"
cd "$repo_root"
Rscript --vanilla -e 'stopifnot(getRversion() == "4.5.3"); cat(R.version.string, "\n")'
Rscript --vanilla "$scripts_dir/check-r.R"
bash "$scripts_dir/check-native.sh"
