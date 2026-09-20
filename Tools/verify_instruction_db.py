#!/usr/bin/env python3
"""Verify the checked-in generated Pascal instruction database.

This does not require Delphi. It regenerates in-memory from isa_x86.json and
checks important mapping invariants discovered during the V2/V3 audit.
"""
from __future__ import annotations

import hashlib
import json
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
sys.path.insert(0, str(HERE))
import generate_instruction_db as gen  # noqa: E402

SRC = HERE / "isa_x86.json"
OUT = ROOT / "Source" / "NativeAsm.InstructionDB.Generated.pas"
REPORT = HERE / "instruction_db_report.json"


def require(cond: bool, msg: str) -> None:
    if not cond:
        raise AssertionError(msg)


def first(forms, pred, desc):
    for f in forms:
        if pred(f):
            return f
    raise AssertionError(f"missing expected form: {desc}")


def main() -> int:
    raw = SRC.read_bytes()
    db = json.loads(raw.decode("utf-8"))
    forms = gen.source_forms(db)
    source_hash = hashlib.sha256(raw).hexdigest()

    # Generated Pascal must be byte-for-byte current.
    expected = gen.render(forms, source_hash)
    require(OUT.read_text(encoding="utf-8") == expected,
            "generated Pascal DB is stale; rerun generate_instruction_db.py")

    # No APX/VEX/EVEX source extension/tokens may survive the selected scope.
    for f in forms:
        exts = set(f.group_ext) | set(f.record_ext)
        require("APX_F" not in exts, f"APX_F leaked into {f.source_signature}")
        upper_op = f.source_op.upper()
        for bad in ("EVEX", "VEX", "REX2", "NO67"):
            require(bad not in upper_op, f"{bad} leaked into {f.source_signature}")

    # r8 source constraints must remain high/low capable at descriptor level.
    r8_add = first(forms,
        lambda f: f.mnemonic == "add" and any(o.reg == "r8" for o in f.operands),
        "ADD r8 form")
    require(any(o.reg == "r8" for o in r8_add.operands), "r8 source constraint was rewritten")

    adc64 = first(forms, lambda f: f.mnemonic == "adc" and len(f.operands) == 2 and f.operands[0].reg == "r64", "adc r64 form")
    sbb64 = first(forms, lambda f: f.mnemonic == "sbb" and len(f.operands) == 2 and f.operands[0].reg == "r64", "sbb r64 form")
    mul64 = first(forms, lambda f: f.mnemonic == "mul" and any(o.reg == "r64" or o.mem == "m64" for o in f.operands), "mul r64/m64 form")
    require(adc64.native_support in ("partial", "yes"), "ADC r64 Native support metadata missing")
    require(sbb64.native_support in ("partial", "yes"), "SBB r64 Native support metadata missing")
    require(mul64.native_support in ("partial", "yes"), "MUL r64/m64 Native support metadata missing")

    # MOVZX r16/m16 split: r32 has no forced REX.W, r64 does.
    mz32 = first(forms,
        lambda f: f.mnemonic == "movzx" and len(f.operands) == 2 and
                  f.operands[0].reg == "r32" and f.operands[1].mem == "m16",
        "movzx r32, r16/m16")
    mz64 = first(forms,
        lambda f: f.mnemonic == "movzx" and len(f.operands) == 2 and
                  f.operands[0].reg == "r64" and f.operands[1].mem == "m16",
        "movzx r64, r16/m16")
    require(not mz32.enc.explicit_rexw, "MOVZX r32,m16 unexpectedly forces REX.W")
    require(mz64.enc.explicit_rexw, "MOVZX r64,m16 lost explicit REX.W")

    # BSF/BSR raw destination access is partial write (lower-case w).
    for mnemonic in ("bsf", "bsr"):
        f = first(forms, lambda x, m=mnemonic: x.mnemonic == m and x.expanded_width == 16,
                  f"{mnemonic} rv")
        require(f.operands[0].access_raw == "w", f"{mnemonic} raw access must be w")

    # Shift CL is explicit fixed CL, never implicit <cl>.
    shl_cl = first(forms,
        lambda f: f.mnemonic == "shl" and len(f.operands) == 2 and f.operands[1].fixed_reg == "cl",
        "shl ..., cl")
    require(not shl_cl.operands[1].fixed_implicit, "CL was incorrectly made implicit")

    # SETcc uses /r source syntax but Native canonicalizes ignored reg field to zero.
    setz = first(forms, lambda f: f.mnemonic == "setz", "setz")
    mk, regidx, rmidx, fixedreg, fixedbyte = gen.modrm_fields(setz)
    require(mk == "ignored" and rmidx == 0, "SETcc ModRM policy is not canonical ignored-reg")
    require(setz.canonicalization == "setcc0", "SETcc canonicalization metadata missing")

    # Fixed ModRM byte coverage: fences and RDTSCP.
    lfence = first(forms, lambda f: f.mnemonic == "lfence", "lfence")
    rdtscp = first(forms, lambda f: f.mnemonic == "rdtscp", "rdtscp")
    require(lfence.enc.fixed_modrm == 0xE8, "LFENCE fixed ModRM must be E8")
    require(rdtscp.enc.fixed_modrm == 0xF9, "RDTSCP fixed ModRM must be F9")

    # LEA16 preserves raw DB 67 but carries Native canonicalization to 66.
    lea16 = first(forms,
        lambda f: f.mnemonic == "lea" and f.operands and f.operands[0].reg == "r16",
        "lea r16, mem")
    require(lea16.enc.raw67, "LEA16 raw AsmJit 67 fact was lost")
    require(lea16.canonicalization == "lea16", "LEA16 Native canonicalization missing")

    # PUSH immediate forms are all represented, including imm16 and x64 imms32.
    push_imms = {o.imm for f in forms if f.mnemonic == "push" for o in f.operands if o.imm}
    require({"imm8", "imm16", "imms32"} <= push_imms,
            f"PUSH immediate source forms incomplete: {sorted(push_imms)}")

    # rel8 remains source-only; rel32 is kept separately.
    jz8 = first(forms, lambda f: f.mnemonic == "jz" and f.enc.rel_code == "cb", "jz rel8")
    jz32 = first(forms, lambda f: f.mnemonic == "jz" and f.enc.rel_code == "cd", "jz rel32")
    require(jz8.native_support == "no", "rel8 Jcc must not claim current Builder support")
    require(jz32.native_support in ("partial", "yes"), "rel32 Jcc support metadata missing")

    # Generator report must agree with regenerated forms.
    report = json.loads(REPORT.read_text(encoding="utf-8"))
    require(report["source_sha256"] == source_hash, "report source hash mismatch")
    require(report["forms"] == len(forms), "report form count mismatch")

    print(f"OK: {len(forms)} forms / {len(set(f.mnemonic for f in forms))} mnemonics")
    print(f"Source SHA256: {source_hash}")
    print("Critical mapping invariants: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
