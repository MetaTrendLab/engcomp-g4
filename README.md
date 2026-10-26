# engcomp-g4 — kernel sources of the REAX engine entry `g4`

Public source of the compiled kernels in the REAX (Bittensor subnet 92) engine-competition entry **engcomp g4**:

| | |
|---|---|
| Image | `ghcr.io/elninolab/g4@sha256:7779a018c9d72b88af504d5b10bd9e751c1f4b19322f7bbea6e41da349e3143b` |
| Commitment | `reax-eng/1:s1-fast:ghcr.io/elninolab/g4@sha256:7779a018c9d72b88af504d5b10bd9e751c1f4b19322f7bbea6e41da349e3143b` (uid 221) |
| Base image | `ghcr.io/johnkell9801-hub/s1q9@sha256:f1422b06f6098ad7b8939c1e05a48b82493d2ccc672912b92e21491256ca0898` (G9XP, uid 220) |

The image ships two cubins of its own; every other cubin is the base image's, byte for byte.

| cubin (in the image) | sources (this repo) | built in | sha256 of the cubin |
|---|---|---|---|
| `/opt/s1eng/s1eng/ecrin.cubin` | `kernels/ecrin.cu` | `/opt/s1eng/s1eng` | `f587ebc84c3550da537f83d292ff0b2ffbaa00e3ed9f0fb17c2ca23a05bf4cd2` |
| `/opt/s1eng/s1eng/onormpv.cubin` | `kernels/onormpv.cu` + `kernels/onorm.cu` (included) | **`/w`** | `cfd1ae2f616c1b3f6f6c4a446183c11678f03652212d41183b7da09896134773` |

The `.cu` files here are the same files the image carries at `/opt/s1eng/s1eng/` (sha256 in `SHA256SUMS`).

## Rebuild

Toolchain: `nvidia/cuda:13.4.3-devel-ubuntu24.04` (nvcc 13.4, `V13.4.92`). No GPU needed.

```bash
./build.sh            # rebuilds both cubins and checks them against SHA256SUMS
```

or by hand:

```bash
# ecrin.cubin
docker run --rm --network none -v "$PWD/kernels:/opt/s1eng/s1eng" -w /opt/s1eng/s1eng \
  nvidia/cuda:13.4.3-devel-ubuntu24.04 \
  nvcc -O3 -arch=sm_120a -cubin -std=c++17 -Xptxas -v -o ecrin.cubin ecrin.cu

# onormpv.cubin  (build in /w, see below)
docker run --rm --network none -v "$PWD/kernels:/w" -w /w \
  nvidia/cuda:13.4.3-devel-ubuntu24.04 \
  nvcc -O3 -arch=sm_120a -cubin -std=c++17 -Xptxas -v -DFFS_SHIP -DONORM_V=5 -DONORM_PF2 -DONORM_SILU_FIN \
  -DONORM_FINROLL -o onormpv.cubin onormpv.cu

sha256sum kernels/*.cubin
```

**Why `/w`:** nvcc names anonymous-namespace device functions after its module id, the CRC32 of the source file's
absolute path, so the bytes of `onormpv.cubin` depend on the directory it is compiled in. The shipped file was compiled
as `/w/onormpv.cu` (its symbols carry module id `473d68c0` = CRC32 of `/w/onormpv.cu`). The build line in the comment of
`onormpv.cu` says `/opt/s1eng/s1eng`: built there it differs (module id `b2624ff1`); built in `/w` it is byte-identical.
`ecrin.cubin` has no such symbols and rebuilds the same in any directory.

## Compare with the image

```bash
docker run --rm --network none --entrypoint sha256sum \
  ghcr.io/elninolab/g4@sha256:7779a018c9d72b88af504d5b10bd9e751c1f4b19322f7bbea6e41da349e3143b \
  /opt/s1eng/s1eng/ecrin.cu /opt/s1eng/s1eng/ecrin.cubin /opt/s1eng/s1eng/onorm.cu \
  /opt/s1eng/s1eng/onormpv.cu /opt/s1eng/s1eng/onormpv.cubin
```

## What the kernels are

- `ecrin.cu` (our own code, engcomp): `ec_addnormr` / `ec_prepr`, the ROTIN prepare — the "in" families' int8 inputs
  rotated per 128-group (randomised Hadamard) before the per-row scale.
- `onormpv.cu` / `onorm.cu`: G9XP's ONORM / PROFUSE-v kernels (authors rgh / ruj) with our changes (`NormArgs` / `PVNArgs`
  gain `xq / xs / xmu / xm / xrot`, unused in g4).

The full list of changes in the image is in `ENGCOMP-NOTICE` (the same file is at `/opt/s1eng/s1eng/ENGCOMP-NOTICE` in
the image).

## Licence

See `LICENSE`.
