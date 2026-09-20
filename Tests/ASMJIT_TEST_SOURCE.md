# AsmJit Test Reference

Parts of NativeASM's test design, test organization, and selected x86/x64 encoding vectors were inspired by or adapted from the AsmJit test suite.

## Reference snapshot

- Project: AsmJit
- Repository: https://github.com/asmjit/asmjit
- Commit: `dffd8b164f228abbc47246c9881f107d656952b2`
- Reference date: 2026-09-16
- License: zlib License

The original AsmJit zlib license text is preserved in:

`../Tools/ASMJIT_LICENSE.md`

## NativeASM tests

NativeASM's tests are not official AsmJit tests. They target NativeASM's Delphi API, NativeASM's intentionally supported instruction subset, NativeASM's canonical encoding choices, JIT execution, validation rules, fixups, memory addressing, SIMD support, debugging, disassembly, and other NativeASM-specific behavior.

Where an AsmJit test idea, test structure, or encoding vector was used as a reference, it was translated or adapted to NativeASM's API and combined with NativeASM-specific regression and execution checks.

The `NativeAsm.Tests.AsmJit` naming is retained so the source of the original test inspiration remains visible.

NativeASM is an independent project and is not affiliated with or endorsed by AsmJit.
