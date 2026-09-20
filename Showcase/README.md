# NativeASM Showcase

`Showcase` contains higher-level libraries, demonstrations, self-tests, and practical benchmarks built on top of the NativeASM core.

## Purpose

The Showcase is primarily a demonstration layer. It exists to show that NativeASM can express and execute non-trivial real-world code, including scalar code, SIMD kernels, multi-precision arithmetic, cryptographic primitives, pattern matching, and CPU-specific dispatch.

Some Showcase implementations are deliberately pragmatic or specialized instead of being maximally general. They should be read as working examples of what can be built with NativeASM, not as a claim that every implementation is the final or optimal way to solve its problem.

Cryptographic and ECC examples demonstrate code-generation capability and are tested against reference or official vectors where covered. The Showcase is not presented as an audited cryptographic library.

## Layout

- `Libraries/Algorithms`: CRC, Base64, Hex, Bloom and hash utilities, memory and string helpers, Aho-Corasick, and Levenshtein.
- `Libraries/Crypto`: ChaCha20, Poly1305, ChaCha20-Poly1305, and BLAKE3.
- `Libraries/Random`: Xoshiro256++.
- `Libraries/BigInt`: multi-precision integers, JIT arithmetic, Montgomery arithmetic, and named prime fields.
- `Libraries/Ecc`: Field25519, X25519, Ed25519, secp256k1, and P-256 field, scalar, and point arithmetic.
- `Benchmarks/Practical`: practical benchmark and self-test suite for Showcase libraries.
- `Tests`: DUnitX tests for Showcase libraries.
- `Docs`: package-specific documentation for the Showcase libraries.

The core under `../Source` does not depend on any Showcase unit. Showcase units depend only on the NativeASM core and on other Showcase units in their own layer.
