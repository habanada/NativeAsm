# NativeASM AVX2 Closure / Certification

This directory is an AVX2-specific closure suite for the v15.10 VEX database.

The current generated database contains 171 AVX2 forms across 138 AVX2 mnemonics. The closure suite does not add instructions or modify production encoding code. It verifies the existing AVX2 implementation at four levels:

1. Database coverage
   - exact 171-form / 138-mnemonic count
   - every AVX2 form synthesized and encoded register-preferred
   - every AVX2 form synthesized and encoded memory-preferred

2. GNU golden matrix
   - 85 fixed encodings generated with GNU Binutils 2.44
   - arithmetic, saturation, min/max, multiply/MADD, variable shifts
   - permutes, shuffles, pack/unpack, sign/zero extend, broadcasts
   - masked memory, gather/VSIB, high registers and addressing boundaries

3. Runtime semantics
   - deterministic multi-case tests on real AVX2 hardware
   - wrap arithmetic
   - signed and unsigned saturation
   - signed and unsigned min/max
   - multiply and multiply-add
   - per-lane variable shifts
   - permute and byte shuffle
   - sign/zero extension and broadcast
   - masked load/store
   - all four integer gather families
   - all four floating gather families

4. Mixed integration
   - legacy SSE -> AVX2
   - core x64 branch -> AVX2
   - core pointer arithmetic -> AVX2 memory
   - AVX2 mask -> BMI1
   - AVX2 mask -> BMI2
   - SSE -> AVX2 -> SSE in one TAsmBuilder stream

Build `NativeAsmAvx2ClosureDUnitXTests.dproj` as Debug / Win64.

The runtime methods gate AVX2 execution. BMI mixed tests additionally gate BMI1/BMI2.

`GNU/verify_golden.py` regenerates and verifies the 85-entry independent oracle when GNU `as` and `objdump` are available.
