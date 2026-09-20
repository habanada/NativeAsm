# NativeASM Benchmarks

This page contains a compact benchmark snapshot for NativeASM.

The tables below are intentionally selective. The complete measurements are available as raw CSV files so results can be inspected without relying on hand-picked summary values.

## Test system

| Item | Value |
| --- | --- |
| CPU | `Intel64 Family 6 Model 167 Stepping 1, GenuineIntel (I7 11K)` |
| Logical processors | 16 |
| Delphi compiler version | 36.0 |
| QPC frequency | 10000000 Hz |

## Benchmark methodology

| Suite | Mode | Samples | Target per sample | Warmup |
| --- | --- | ---: | ---: | ---: |
| Core benchmark | full | 15 | 500 ms | 1000 ms |
| Practical benchmark | full | 7 | 250 ms | 100 ms |

Reported summary values use the median where the benchmark provides one. Throughput and latency depend on CPU model, compiler version, build configuration, system load, memory behavior, and power-management settings. Results should not be treated as universal performance guarantees.

## Core benchmark

The core suite measures encoder, builder, allocator, JIT call, generated-loop, and end-to-end overhead.

| Benchmark | Median ns/op | Median ns/unit | Million units/s | RSD |
| --- | ---: | ---: | ---: | ---: |
| `Encode.GprMix16` | 5803.124 | 362.695 | 2.757 | 0.65% |
| `Encode.MemoryMix12` | 3754.616 | 312.885 | 3.196 | 2.34% |
| `Build.LabelFixups7` | 2939.517 | 419.931 | 2.381 | 1.02% |
| `Build.Copy4K` | 147.725 | 0.036 | 27984.401 | 0.54% |
| `Build.LargeMixed256` | 92248.369 | 360.345 | 2.775 | 0.15% |
| `Jit.OwnAllocation` | 2746.099 | 2746.099 | 0.364 | 0.54% |
| `Jit.AllocatorBatch256` | 5002.986 | 19.543 | 51.169 | 0.63% |
| `Execute.DirectCall` | 0.827 | 0.827 | 1208.936 | 0.15% |
| `Execute.RunAPI` | 3.067 | 3.067 | 326.016 | 0.58% |
| `Execute.GeneratedLoop1024` | 221.993 | 0.217 | 4612.748 | 0.22% |
| `EndToEnd.BuildJitRun` | 7542.333 | 7542.333 | 0.133 | 0.69% |

A few useful reference points from this run:

- Direct generated-function call: 0.827 ns median.
- `Run` API call: 3.067 ns median.
- Batched JIT allocator: 19.543 ns per function median.
- End-to-end build, JIT, and run: 7542.333 ns per function median.

## Practical benchmark

The practical suite exercises real NativeASM-generated scalar and SIMD kernels. The following comparison uses 1.0 MiB inputs where available and compares the scalar path with the automatically selected or explicitly specialized path.

| Workload | Scalar MiB/s | Specialized MiB/s | Speedup | Path |
| --- | ---: | ---: | ---: | --- |
| CRC32 IEEE | 580.3 | 8865.0 | 15.28x | PCLMUL/auto |
| CRC32C Castagnoli | 578.2 | 12313.9 | 21.30x | SSE4.2/auto |
| BLAKE3 | 140.0 | 1943.9 | 13.88x | SSSE3/auto |
| ChaCha20 | 494.3 | 721.1 | 1.46x | SSE2/auto |
| Base64 encode | 2305.1 | 6776.7 | 2.94x | SSSE3/auto |
| Base64 decode | 1975.2 | 6027.9 | 3.05x | SSSE3/auto |
| Hex encode | 1975.7 | 17535.0 | 8.88x | SSSE3/auto |
| Hex decode | 1754.3 | 5337.5 | 3.04x | SSSE3/auto |
| xoshiro256++ fill | 9220.9 | 11860.1 | 1.29x | SSE2 2-stream |

The `auto` rows include dispatch overhead and select an implementation based on the CPU features available at runtime.

## Additional practical results

| Benchmark | Median ns | Throughput | Unit | RSD |
| --- | ---: | ---: | --- | ---: |
| Poly1305 1.0 MiB | 720778.528 | 1387.389 | MiB/s | 0.99% |
| AEAD encrypt 1.0 MiB | 2113218.000 | 473.212 | MiB/s | 0.54% |
| AEAD decrypt 1.0 MiB | 2138029.000 | 467.721 | MiB/s | 0.74% |
| BigInt add 256-bit | 3.873 | 258.200 | Mops/s | 0.15% |
| BigInt mulwide 256-bit | 12.476 | 80.155 | Mops/s | 0.22% |
| MontMul secp256k1 | 24.575 | 40.692 | Mops/s | 0.27% |
| MontMul P-256 | 24.322 | 41.115 | Mops/s | 0.31% |
| RSA-size MontMul 2048-bit | 1505.447 | 0.664 | Mops/s | 0.60% |
| RSA public pow e=65537 2048-bit | 42498.859 | 0.024 | Mops/s | 0.13% |

These absolute results are included because several workloads do not have a directly comparable scalar/reference benchmark in the same CSV.

## Raw results

- [`NativeAsmBenchmark.csv`](Benchmarks/Results/NativeAsmBenchmark.csv) - 11 core benchmark rows.
- [`NativeAsmPracticalBenchmark.csv`](Benchmarks/Results/NativeAsmPracticalBenchmark.csv) - 192 practical benchmark rows.

The raw CSV files are the authoritative result snapshot. If a summary table and a CSV value ever disagree, use the CSV.

## Reproducing the run

Build the benchmark executables as Win64 Release and run them on an otherwise idle system.

```text
NativeAsmBenchmark.exe --full --csv=NativeAsmBenchmark.csv
NativeAsmPracticalBenchmark.exe --full --csv=NativeAsmPracticalBenchmark.csv
```

For repeatable comparisons:

- use the same CPU and compiler version
- use the same build configuration
- close unnecessary background workloads
- keep the same benchmark parameters
- compare raw CSV results, not screenshots
- run correctness tests before using benchmark results

## What these numbers mean

The core benchmark focuses on NativeASM framework overhead and code-generation throughput. The practical benchmark focuses on generated code executing real workloads.

A benchmark result demonstrates performance for the measured implementation on the measured machine. It does not by itself demonstrate correctness, security, constant-time behavior, or suitability for production cryptography.


