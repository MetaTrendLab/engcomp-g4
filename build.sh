#!/bin/bash
# Rebuild the two cubins shipped in ghcr.io/elninolab/g4@sha256:7779a018... from the sources in kernels/ and compare
# them byte for byte with the shipped ones (SHA256SUMS). Needs docker; no GPU, no network inside the container.
set -euo pipefail
cd "$(dirname "$0")"
CUDA=${CUDA_IMAGE:-nvidia/cuda:13.4.3-devel-ubuntu24.04}
out=$(mktemp -d); trap 'rm -rf "$out"' EXIT
cp kernels/*.cu "$out/"
build() {  # <build dir inside the container> <nvcc arguments...>
  local dir=$1; shift
  docker run --rm --network none --user "$(id -u):$(id -g)" -v "$out:$dir" -w "$dir" "$CUDA" nvcc "$@" >/dev/null
}
# ecrin.cubin: no anonymous-namespace symbols, the directory does not change the output
build /opt/s1eng/s1eng -O3 -arch=sm_120a -cubin -std=c++17 -Xptxas -v -o ecrin.cubin ecrin.cu
# onormpv.cubin: nvcc's module id (CRC32 of the source's absolute path) is in the output; it was built as /w/onormpv.cu
build /w -O3 -arch=sm_120a -cubin -std=c++17 -Xptxas -v -DFFS_SHIP -DONORM_V=5 -DONORM_PF2 -DONORM_SILU_FIN \
  -DONORM_FINROLL -o onormpv.cubin onormpv.cu
sha256sum kernels/*.cu
(cd "$out" && sha256sum ecrin.cubin onormpv.cubin)
grep -E 'cubin$' SHA256SUMS | (cd "$out" && sha256sum -c -)
echo "both cubins rebuilt byte for byte"
