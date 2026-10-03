# NativeASM AVX2 Integer Showcase

The AVX2 showcase is intentionally different from the AVX/FMA showcase. It demonstrates a packed-integer workload rather than another floating-point kernel.

## Conway Game of Life

The generated row kernel updates 32 cells in parallel per YMM block. Each output cell is computed from eight neighboring byte cells.

The JIT kernel uses:

- `VMOVDQU`
- `VPADDB`
- `VPCMPEQB`
- `VPAND`
- `VPOR`
- `VPSUBB`
- `VZEROUPPER`

No AVX-512 instructions are used.

The console first runs a 96x64 board for 32 generations through both an independent scalar implementation and the NativeASM AVX2 JIT implementation. The boards must match byte-for-byte.

After verification it runs a 1024x768 board for 160 generations, prints throughput in Mcell/s, and writes:

`NativeAsm-AVX2-Life-1024x768.bmp`

The image is a 24-bit BMP written without VCL, GDI+ or another graphics library.

Build `NativeAsmAvx2Showcase.dproj` as Debug / Win64.

The DUnitX project under `Tests` checks one generation, 32 generations, deterministic AVX2 execution and the 24-bit BMP writer.
