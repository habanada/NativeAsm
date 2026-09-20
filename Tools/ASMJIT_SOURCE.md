# AsmJit Source Provenance

NativeASM uses AsmJit x86 instruction database material as development-time input. AsmJit itself is not a runtime dependency of NativeASM.

## Upstream project

- Project: AsmJit
- Repository: https://github.com/asmjit/asmjit
- Author and maintainer: Petr Kobalicek
- License: zlib License
- Local license copy: `ASMJIT_LICENSE.md`

## Exact x86 instruction database snapshot

The NativeASM file:

`Tools/isa_x86.json`

is an exact copy of the AsmJit file:

`db/isa_x86.json`

from this upstream commit:

- Commit: `0bd5787b54b575ed94bf32ac452153b34385c514`
- Date: 2026-03-26
- SHA-256: `0bc3fde0376e3c7db93ce1fa6da35b9d69b868db738e60dba382a2bee54d1f48`

Commit page:

https://github.com/asmjit/asmjit/commit/0bd5787b54b575ed94bf32ac452153b34385c514

The local file and the upstream file from this commit are byte-identical.

## NativeASM transformation

NativeASM does not expose or use the complete AsmJit database directly at runtime.

The checked-in JSON file is used by NativeASM development tools to select and transform supported instruction forms into NativeASM-specific Pascal descriptors. The generated tables are then compiled into NativeASM.

Relevant files include:

- `Source/NativeAsm.InstructionDB.Generated.pas`
- `Source/NativeAsm.InstructionDB.pas`
- `Source/NativeAsm.StaticEncoder.pas`
- `Source/NativeAsm.Simd.Db.Generated.pas`
- `Source/NativeAsm.Simd.Db.pas`

Unsupported or intentionally unexposed source forms can remain source-only metadata instead of becoming public Builder API functionality.

## Test reference

NativeASM test ideas, test organization, and selected encoding vectors were also influenced by the AsmJit test suite.

The test reference snapshot used during NativeASM development is documented separately in:

`../Tests/ASMJIT_TEST_SOURCE.md`

Reference commit:

`dffd8b164f228abbc47246c9881f107d656952b2`

Reference date:

`2026-09-16`

## License

AsmJit is licensed under the zlib License. The original license text is preserved in `Tools/ASMJIT_LICENSE.md` and must not be removed from source distributions containing AsmJit-derived material.

NativeASM is an independent project and is not affiliated with or endorsed by AsmJit.
