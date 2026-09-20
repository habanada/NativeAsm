# NativeAsm V6 - Static AsmJit-derived Instruction DB

This revision uses an AsmJit-derived `isa_x86.json` working snapshot as a **development-time source of truth** while keeping JSON completely out of the JIT/runtime path. Upstream and checked-in provenance are documented separately in `Tools/ASMJIT_SOURCE.md`.

## Runtime architecture

```text
AsmJit isa_x86.json
        |
        | Tools/Generate-InstructionDb.ps1  (development/build time only)
        v
Source/NativeAsm.InstructionDB.Generated.pas
        |
        +--> InstructionDB.pas      normalized descriptor API + mnemonic index
        |
        +--> StaticEncoder.pas      validation, form selection, byte emission
        |
        +--> Builder.pas            existing fluent API, routed to StaticEncoder
```

The generated unit is checked in. Shipping the runtime does **not** require `isa_x86.json`, a JSON parser, Node.js, Python, or AsmJit itself.

## Generated scope

Checked-in generator-input SHA-256:

`0bc3fde0376e3c7db93ce1fa6da35b9d69b868db738e60dba382a2bee54d1f48`

This hash identifies the exact `Tools/isa_x86.json` consumed by the current NativeASM generators. It is not the SHA-256 of the separately preserved upstream AsmJit reference file.

Current generated subset:

- 470 concrete encoding forms
- 94 mnemonics
- 21 forms fully exposed by the current Builder API
- 393 forms retained with NativeAsm restrictions/canonicalization
- 56 source-only forms retained as metadata but not selectable by the current API

The generator accepts the selected legacy x64 GP/control-flow/fence/timing/debug subset and selected extensions (`CMOV`, `POPCNT`, `RDTSC`, `RDTSCP`, `SSE`, `SSE2`). APX-F, REX2, VEX and EVEX are outside this revision's runtime scope.

## Important design rules

- `r8` remains a source-level 8-bit GPR class; AH/CH/DH/BH legality is resolved together with REX requirements.
- REX.W is a per-form policy, never inferred merely from seeing an `r64` token.
- `66` operand-size policy is separate from mandatory opcode prefixes.
- `/r`, fixed `/0..7`, ignored/canonical SETcc reg field, and complete fixed ModRM bytes are distinct descriptor modes.
- Explicit fixed operands such as `cl`, implicit fixed operands, and literal `1` are retained separately.
- `rv`, `ry`, `mv`, `my`, and `immv` are expanded to concrete widths by the generator.
- Unsupported source capabilities remain source-only/partial instead of silently becoming public NativeAsm functionality.
- Unsized memory is never globally treated as qword. A paired register may provide width; immediate-only/unary memory operations require an explicit size.
- Form selection is length-first. AsmJit `alt:true` is preserved as source metadata and used only as a tie-breaker, not as an unconditional preference.
- Relative-8 source forms are retained but not selected because the current Builder fixup model is rel32-only.

## Builder migration

The normal instruction paths now route through `TStaticInstructionEncoder`, including:

- MOV / MOVSX / MOVSXD / MOVZX / LEA / XCHG
- ADD / ADC / SUB / SBB / INC / DEC / NEG / IMUL / MUL
- SHL / SHR / SAR / ROL / ROR
- BSF / BSR / POPCNT / BSWAP
- XOR / AND / OR / NOT / CMP / TEST
- current CMOVcc / SETcc condition subset
- PUSH / POP / indirect CALL / RET
- label Jcc/JMP and CALL rel32 opcode emission
- LFENCE / MFENCE / SFENCE / RDTSC / RDTSCP / INT3 / UD2

Multi-byte NOP construction and higher-level frame/runtime helpers remain intentionally hand-written policy code.

## Current API restrictions intentionally preserved

Examples of source forms that are retained but not automatically exposed:

- `MOV [mem], imm`
- indirect `JMP r/m64`
- `RCL` / `RCR`
- memory source for current `BSF` / `BSR` / `POPCNT` API
- memory source for current `CMOVcc` API
- memory destination for current `SETcc` API
- the six condition codes not present in the current `TCondition` enum
- `SYSCALL` as a direct Builder method
- rel8 label fixups

## Regeneration

From the project root:

```powershell
.\Tools\Generate-InstructionDb.ps1
```

Then verify:

```powershell
.\Tools\Verify-Project.ps1
```

The PowerShell generator keeps its input/output/report variables at the top of the script and is fail-closed for selected forms: an unknown encoding token causes generation to fail instead of guessing an encoding.

## Tests

`Tools/Verify-InstructionDb.ps1` verifies the generated table byte-for-byte against the included JSON and checks the mapping invariants discovered during the V2/V3 audit.

`Tools/Verify-Project.ps1` additionally verifies the static integration and that the Builder is routed to the generated encoder.

`Tests/StaticDbRegression.dpr` is a Win64 Delphi regression executable with golden byte tests for representative encodings and negative tests for fail-closed validation. Run this with the Delphi compiler used by the NativeAsm project.

`Tests/NativeAsmProTests.dpr` is the extensive Win64 suite: golden encodings, JIT/CPU outcome checks, condition matrices, memory/addressing, labels/fixups, stack/ABI helpers, patching, allocator smoke tests, and fail-closed validation. It is included in `NativeAsm.groupproj` as a separate test project.

## Source provenance

`Tools/isa_x86.json` is the exact working input used for the current NativeASM generation. It is byte-identical to AsmJit's `db/isa_x86.json` from commit `0bd5787b54b575ed94bf32ac452153b34385c514` and has SHA-256 `0bc3fde0376e3c7db93ce1fa6da35b9d69b868db738e60dba382a2bee54d1f48`.

NativeASM does not modify this JSON snapshot in place. The generator reads selected instruction information and transforms it into NativeASM-specific generated Pascal tables.

`Tools/ASMJIT_SOURCE.md` records the exact upstream commit and file provenance. `Tools/ASMJIT_LICENSE.md` preserves the original AsmJit zlib license text. `Tools/MAPPING_V3.md` records the mapping rules used to design the importer and descriptor model.

Test design and selected encoding vectors were also inspired by or adapted from AsmJit's test suite. The test reference snapshot is commit `dffd8b164f228abbc47246c9881f107d656952b2` from 2026-09-16 and is documented in `Tests/ASMJIT_TEST_SOURCE.md`.
