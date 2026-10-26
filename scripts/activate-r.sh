#!/usr/bin/env bash
# Source this file in each Bash shell that needs R or its compilers.
export PRACTICE_R_SETUP_ROOT="${PRACTICE_R_SETUP_ROOT:-/workspace/.practice-r-setup}"
case "$PRACTICE_R_SETUP_ROOT" in
  /*) ;;
  *) printf 'PRACTICE_R_SETUP_ROOT must be an absolute path.\n' >&2; return 1 ;;
esac
if [ ! -x "$PRACTICE_R_SETUP_ROOT/bin/micromamba" ] || \
   [ ! -x "$PRACTICE_R_SETUP_ROOT/env/bin/Rscript" ]; then
  printf 'Run bash scripts/setup-r.sh before activating R.\n' >&2
  return 1
fi
export MAMBA_ROOT_PREFIX="$PRACTICE_R_SETUP_ROOT/mamba"
export CONDA_PKGS_DIRS="$PRACTICE_R_SETUP_ROOT/mamba/pkgs"
export XDG_CACHE_HOME="$PRACTICE_R_SETUP_ROOT/cache"
practice_r_hook=$("$PRACTICE_R_SETUP_ROOT/bin/micromamba" --no-rc shell hook --shell bash --root-prefix "$MAMBA_ROOT_PREFIX") || return $?
eval "$practice_r_hook" || return $?
unset practice_r_hook
micromamba activate "$PRACTICE_R_SETUP_ROOT/env" || return $?
export R_LIBS_USER="$PRACTICE_R_SETUP_ROOT/library"
export RENV_PATHS_ROOT="$PRACTICE_R_SETUP_ROOT/renv"
export MAKEFLAGS=-j2
export OPENBLAS_NUM_THREADS=2
