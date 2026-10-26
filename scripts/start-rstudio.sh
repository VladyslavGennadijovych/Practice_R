#!/usr/bin/env bash
# Optional local RStudio Server used to execute the report and capture screenshots.
set -euo pipefail
scripts_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo_root=$(cd -- "$scripts_dir/.." && pwd)
source "$scripts_dir/activate-r.sh"
studio_root="${PRACTICE_RSTUDIO_ROOT:-/workspace/.practice-r-rstudio}"
case "$studio_root" in /*) ;; *) printf 'PRACTICE_RSTUDIO_ROOT must be absolute.\n' >&2; exit 1 ;; esac
test "$(uname -s)" = Linux && test "$(uname -m)" = x86_64
mkdir -p "$studio_root" "$studio_root/root" "$studio_root/state/db" \
  "$studio_root/config" "$studio_root/data" "$studio_root/cache"
archive="$studio_root/rstudio-server.deb"
checksum=54ff3b4187a1f2b82f004b16e54caea3b81e8a397025111323c6a3d5869bf80e
if [ ! -f "$archive" ]; then
  temporary=$(mktemp "$studio_root/download.XXXXXX")
  trap 'rm -f "$temporary"' EXIT
  curl --fail --silent --show-error --location --retry 2 --output "$temporary" \
    https://dl.dailies.rstudio.com/server/jammy/amd64/rstudio-server-2026.10.0-233-amd64.deb
  printf '%s  %s\n' "$checksum" "$temporary" | sha256sum --check --status
  mv "$temporary" "$archive"
fi
# Official checksum: https://dailies.rstudio.com/rstudio/blue-mistflower/server/jammy-amd64/2026-10-0-233/
printf '%s  %s\n' "$checksum" "$archive" | sha256sum --check --status
studio_install="$studio_root/root/usr/lib/rstudio-server"
if [ ! -x "$studio_install/bin/rserver" ]; then dpkg-deb -x "$archive" "$studio_root/root"; fi
cat > "$studio_root/config/database.conf" <<EOF
provider=sqlite
directory=$studio_root/state/db
EOF
cat > "$studio_root/config/rsession.conf" <<EOF
session-default-working-dir=$repo_root
session-default-new-project-dir=$repo_root
EOF
cat > "$studio_root/config/rserver.conf" <<EOF
server-user=$(id -un)
server-daemonize=0
server-working-dir=$repo_root
server-data-dir=$studio_root/state
server-pid-file=$studio_root/state/rserver.pid
secure-cookie-key-file=$studio_root/state/secure-cookie-key
www-address=127.0.0.1
www-port=8787
auth-none=1
rsession-which-r=$PRACTICE_R_SETUP_ROOT/env/bin/R
rsession-path=$studio_install/bin/rsession
rsession-ld-library-path=$PRACTICE_R_SETUP_ROOT/env/lib/R/lib:$PRACTICE_R_SETUP_ROOT/env/lib
rsession-config-file=$studio_root/config/rsession.conf
database-config-file=$studio_root/config/database.conf
www-local-path=$studio_install/www
EOF
export XDG_CONFIG_HOME="$studio_root/config"
export XDG_DATA_HOME="$studio_root/data"
export XDG_CACHE_HOME="$studio_root/cache"
export RSTUDIO_DATA_HOME="$studio_root/data"
cd "$repo_root"
exec "$studio_install/bin/rserver" --config-file "$studio_root/config/rserver.conf"
