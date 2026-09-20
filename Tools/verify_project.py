#!/usr/bin/env python3
"""Cross-platform verification for the static NativeAsm instruction DB integration.

This intentionally does not replace the Delphi regression program in Tests/.
It verifies generator reproducibility and architectural integration without a
Delphi compiler.
"""
from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "Source"
BUILDER = SRC / "NativeAsm.Builder.pas"
STATIC = SRC / "NativeAsm.StaticEncoder.pas"
DB = SRC / "NativeAsm.InstructionDB.pas"
GEN = SRC / "NativeAsm.InstructionDB.Generated.pas"
TYPES = SRC / "NativeAsm.Types.pas"
SIMD_DB = SRC / "NativeAsm.Simd.Db.pas"
SIMD_GEN = SRC / "NativeAsm.Simd.Db.Generated.pas"
CPU = SRC / "NativeAsm.CpuFeatures.pas"


def require(cond: bool, msg: str) -> None:
    if not cond:
        raise AssertionError(msg)


def main() -> int:
    subprocess.run([sys.executable, str(ROOT / "Tools" / "verify_instruction_db.py")],
                   check=True, cwd=ROOT)

    source_text = "\n".join(p.read_text(encoding="utf-8", errors="replace")
                            for p in SRC.glob("*.pas"))
    # Comments document the JSON provenance, but runtime units must not import a
    # JSON library or open/read the source database.
    require("System.JSON" not in source_text,
            "runtime Source units unexpectedly depend on System.JSON")

    b = BUILDER.read_text(encoding="utf-8")
    s = STATIC.read_text(encoding="utf-8")
    d = DB.read_text(encoding="utf-8")
    g = GEN.read_text(encoding="utf-8")
    t = TYPES.read_text(encoding="utf-8")
    sd = SIMD_DB.read_text(encoding="utf-8")
    sg = SIMD_GEN.read_text(encoding="utf-8")
    cpu = CPU.read_text(encoding="utf-8")

    require("NativeAsm.StaticEncoder" in b,
            "Builder is not wired to StaticEncoder")
    routed = len(re.findall(r"TStaticInstructionEncoder\.(?:Encode|EmitRelative32Placeholder)", b))
    require(routed >= 40, f"too few Builder paths routed through static DB: {routed}")

    for dead in ("procedure TAsmBuilder.EmitArith(",
                 "procedure TAsmBuilder.EmitArithImm(",
                 "procedure TAsmBuilder.EmitShift("):
        require(dead not in b, f"dead manual encoding helper remains: {dead}")

    require("nrNoRelative8Fixup" in d and "nrNoIndirectJmpApi" in d,
            "fail-closed Native restrictions are missing")
    require("mkFixedByte" in d and "mkIgnoredRegCanonicalZero" in d,
            "required ModRM descriptor modes are missing")
    require("length-first" in s.lower(),
            "canonical static selector length-first policy is missing")
    require("CInstructionFormCount = 470;" in g,
            "unexpected generated form count")
    require("CInstructionMnemonicCount = 94;" in g,
            "unexpected generated mnemonic count")
    require("CInstructionOperandCount = 850;" in g,
            "unexpected generated operand count")
    require("sz128" in t and "Alignment     : Byte;" in t,
            "base 128-bit/alignment memory metadata was lost")
    require("NativeAsm.Rules" in s and "TAsmRuleValidator.Validate(Result, Operands);" in s,
            "base rule validation was lost from StaticEncoder")
    require("sePCLMULQDQ" in sd and "CSimdMnemonicCount = 275;" in sg and
            "CSimdFormCount = 338;" in sg and "CSimdOperandCount = 719;" in sg and
            "'pclmulqdq'" in sg, "PCLMULQDQ SIMD integration is incomplete")
    require("cfSSE2" in cpu and "cfSSSE3" in cpu and "cfSSE42" in cpu and
            "cfPOPCNT" in cpu and "cfPCLMULQDQ" in cpu,
            "extended CPU feature detection is incomplete")

    test = (ROOT / "Tests" / "StaticDbRegression.dpr").read_text(encoding="utf-8")
    for case in ("mov rax,rbx", "add rax,1", "adc rax,rdx", "sbb r9,r10", "mul r8",
                 "xchg rax,rcx", "setz r8b", "movzx rax,word [rcx]", "jz rel32 fixup"):
        require(case in test, f"Delphi regression case missing: {case}")

    print(f"Project integration: OK ({routed} static Builder routes)")
    print("Runtime JSON/parser dependency: none")
    print("Delphi regression source: present")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
