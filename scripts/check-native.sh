#!/usr/bin/env bash
set -eo pipefail
scripts_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$scripts_dir/activate-r.sh"
set -u

native_tmp=$(mktemp -d /tmp/practice-r-native.XXXXXX)
trap 'rm -rf "$native_tmp"' EXIT
cd "$native_tmp"

cat > ccheck.c <<'C'
void twice_c(double *x, int *n) {
  for (int i = 0; i < *n; ++i) x[i] *= 2.0;
}
C

cat > cppcheck.cpp <<'CPP'
#include <numeric>
#include <vector>
extern "C" void sumsq_cpp(double *x, int *n, double *answer) {
  std::vector<double> values(x, x + *n);
  *answer = std::inner_product(values.begin(), values.end(),
                              values.begin(), 0.0);
}
CPP

cat > fcheck.f90 <<'FORTRAN'
subroutine increment_f(x, n)
  implicit none
  integer, intent(in) :: n
  double precision, intent(inout) :: x(n)
  x = x + 3.0d0
end subroutine increment_f
FORTRAN

for source_file in ccheck.c cppcheck.cpp fcheck.f90; do
  module=${source_file%.*}
  if ! R CMD SHLIB -o "$module.so" "$source_file" > "$module.log" 2>&1; then
    cat "$module.log" >&2
    exit 1
  fi
done

Rscript --vanilla - <<'R'
x <- c(1.5, -2, 0, 3)
dyn.load("ccheck.so")
stopifnot(identical(.C("twice_c", x = x, n = as.integer(length(x)))$x,
                    c(3, -4, 0, 6)))
cat("PASS 1: C extension compiles, loads, and doubles a vector\n")
dyn.load("cppcheck.so")
stopifnot(identical(.C("sumsq_cpp", x = x, n = as.integer(length(x)),
                       answer = double(1))$answer, 15.25))
cat("PASS 2: C++ extension compiles, loads, and computes a sum of squares\n")
dyn.load("fcheck.so")
stopifnot(identical(.Fortran("increment_f", x = x,
                            n = as.integer(length(x)))$x, c(4.5, 1, 3, 6)))
cat("PASS 3: Fortran extension compiles, loads, and increments a vector\n")
cat("RESULT: 3/3 native extension checks passed\n")
R
