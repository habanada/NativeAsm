# Showcase DUnitX Tests

`NativeAsmShowcaseDUnitXTests.dproj` tests the higher-level libraries under `Showcase/Libraries`.

Core encoder/JIT/SIMD tests remain under the repository-level `Tests` directory. Showcase tests reference the core only through `../../Source` and never place Showcase units back into the NativeAsm runtime package.

ECC fixtures cover Field25519/X25519, Ed25519, secp256k1 and P-256 field, scalar, point and encoding behavior.
