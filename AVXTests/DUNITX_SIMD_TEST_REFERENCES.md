# NativeASM AVX/BMI DUnitX test references

This test suite is original Delphi code for NativeASM. No test implementation was copied from the external projects listed below.

## AsmJit

Reference: https://github.com/asmjit/asmjit/tree/master/asmjit-testing/tests

License: zlib.

Ideas used at a design level:

- large encoder matrices instead of a few smoke tests;
- independent expected machine-code bytes;
- validation and rejection tests alongside successful encodings;
- broad instruction database consistency checks;
- separation of encoding correctness from runtime semantics.

No AsmJit source code, tables, or test vectors were copied into the NativeASM DUnitX suite.

## Vector Class Library version 2

References:

- https://github.com/vectorclass/version2
- https://github.com/vectorclass/testbench

License: Apache-2.0-or-later.

Ideas used at a design level:

- lane-oriented SIMD semantic checks;
- integer and floating-point edge-case thinking;
- checking vector operations with several independent lanes instead of a single scalar result;
- deterministic seeded/matrix-style semantic coverage across instruction-set levels.

No Vector Class Library source code or test implementation was copied.

## asm_benchmarks

Reference: https://github.com/Poulpy/asm_benchmarks

License: MIT.

This repository is used only as a benchmark methodology reference. It is not used as an encoding or correctness oracle in the DUnitX suite.

## Independent byte oracle

GNU Binutils 2.44 `as` and `objdump` are used to derive and independently verify fixed x86-64/VEX expected bytes. The additional golden vectors include extended registers, displacement boundaries, SIB addressing, RIP-relative memory, VSIB gather, `/is4` register selectors, scalar/GPR transfers, and BMI1/BMI2 forms.

## NativeASM-owned references

`NativeAsmAvxAudit` and `NativeAsmBmiAudit` are project-owned validation references. The DUnitX suite covers full-database synthesis, independent golden vectors, rejection and atomicity matrices, and CPU-gated runtime semantics.
