# Third-Party Notices

## AsmJit

NativeASM uses x86 instruction database material from the AsmJit project and was influenced by AsmJit design and test ideas in several low-level areas.

Upstream project:

- Project: AsmJit
- Repository: https://github.com/asmjit/asmjit
- Author and maintainer: Petr Kobalicek
- License: zlib License

The original AsmJit license text is preserved without modification in:

`Tools/ASMJIT_LICENSE.md`

## Instruction database provenance

The `Tools/isa_x86.json` file used by NativeASM is an exact copy of the AsmJit x86 instruction database file from this upstream commit:

- Commit: `0bd5787b54b575ed94bf32ac452153b34385c514`
- Commit date: 2026-03-26
- Upstream path: `db/isa_x86.json`
- NativeASM path: `Tools/isa_x86.json`
- SHA-256: `0bc3fde0376e3c7db93ce1fa6da35b9d69b868db738e60dba382a2bee54d1f48`

The JSON snapshot itself is preserved as the upstream source file. NativeASM build-time tools read selected information from this database and transform it into NativeASM-specific generated Pascal tables. NativeASM supports only a selected subset of the available x86/x64 instruction forms.

See `Tools/ASMJIT_SOURCE.md` for details.

## Test provenance

NativeASM test design, test organization, and selected encoding vectors were inspired by or adapted from the AsmJit test suite using this reference snapshot:

- Commit: `dffd8b164f228abbc47246c9881f107d656952b2`
- Reference date: 2026-09-16

The NativeASM tests are Delphi-specific tests for NativeASM's own API and behavior. They have been translated, adapted, extended, and combined with NativeASM-specific regression and execution tests. They are not official AsmJit tests.

See `Tests/ASMJIT_TEST_SOURCE.md` for details.

## Relationship

NativeASM is an independent project. It is not an official AsmJit port and is not affiliated with or endorsed by the AsmJit project.
