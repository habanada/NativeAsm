#!/usr/bin/env python3
"""Generate NativeAsm's static x64 instruction descriptor tables from AsmJit isa_x86.json.

Runtime never parses JSON. This generator is a development/build-time tool.
It intentionally supports only the legacy x64 subset used by NativeAsm.
Unknown selected encodings fail closed.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
from dataclasses import dataclass, field, replace
from pathlib import Path
from typing import Iterable, List, Dict, Tuple

CC = ("o", "no", "b", "nb", "z", "nz", "be", "nbe",
      "s", "ns", "p", "np", "l", "nl", "le", "nle")
BASE_MNEMONICS = {
    "mov", "movsx", "movsxd", "movzx", "lea", "xchg",
    "add", "adc", "sub", "sbb", "inc", "dec", "neg", "imul", "mul",
    "shl", "shr", "sar", "rol", "ror", "rcl", "rcr",
    "bsf", "bsr", "popcnt", "bswap", "xor", "and", "or", "not",
    "cmp", "test", "push", "pop", "call", "jmp", "ret",
    "lfence", "mfence", "sfence", "rdtsc", "rdtscp", "nop",
    "int3", "ud2", "syscall",
}
TARGET_MNEMONICS = (BASE_MNEMONICS |
                    {"j" + c for c in CC} |
                    {"cmov" + c for c in CC} |
                    {"set" + c for c in CC})
ALLOWED_EXT = {"CMOV", "POPCNT", "RDTSC", "RDTSCP", "SSE", "SSE2"}
EXCLUDED_SIGNATURE_TOKENS = ("sreg", "creg", "dreg", "moff", "R:fs", "R:gs", "W:fs", "W:gs")

# Pascal enum spellings used by the generated unit.
ARCH = {"any": "saAny", "x64": "saX64"}
TAG = {"": "efNone", "MR": "efMR", "RM": "efRM", "M": "efM", "OP": "efOP"}
MAP = {"primary": "omPrimary", "0f": "om0F", "0f38": "om0F38", "0f3a": "om0F3A"}
PREFIX = {"none": "mpNone", "np": "mpNP", "66": "mp66", "f2": "mpF2", "f3": "mpF3"}
REXW = {"never": "rwNever", "bywidth": "rwByResolvedGpWidth", "force": "rwForce"}
P66 = {"never": "p66Never", "bywidth": "p66ByResolvedGpWidth", "force": "p66ForceOperandSize", "mandatory": "p66MandatoryOpcode"}
MODRM = {"none": "mkNone", "operands": "mkFromOperands", "fixedreg": "mkFixedRegField", "ignored": "mkIgnoredRegCanonicalZero", "fixedbyte": "mkFixedByte"}
FIXUP = {"none": "dfkNone", "rel8": "dfkRelative8", "rel32": "dfkRelative32"}
SUPPORT = {"no": "nsSourceOnly", "partial": "nsPartial", "yes": "nsSupported"}
CANON = {
    "none": "ncNone",
    "lea16": "ncLea16Uses66",
    "setcc0": "ncSetccRegFieldZero",
    "pushimm": "ncPushImmediateShortest",
    "nop": "ncNativeMultiByteNop",
}
RESTRICTION = {
    "none": "nrNone",
    "memory_source_only": "nrMemorySourceOnly",
    "register_source_only": "nrRegisterSourceOnly",
    "register_dest_only": "nrRegisterDestinationOnly",
    "no_memory_immediate": "nrNoMemoryImmediate",
    "signed_imm32_64": "nrSignedImm32For64Bit",
    "bswap64": "nrBswap64Only",
    "conditions10": "nrNativeConditionSubset",
    "no_rel8": "nrNoRelative8Fixup",
    "no_indirect_jmp": "nrNoIndirectJmpApi",
    "no_syscall": "nrNoSyscallBuilderApi",
    "rotate_imm_reg": "nrRotateRegisterImmediateOnly",
    "shift_count": "nrShiftCount0To63",
    "explicit_mem_size": "nrExplicitMemorySizeRequired",
    "stack_mem64": "nrStackMemory64OrUnspecified",
    "not_exposed": "nrNotExposed",
}

ACCESS = {
    "": "oaNone", "R": "oaRead", "W": "oaWrite", "w": "oaWritePartial",
    "X": "oaReadWrite", "x": "oaReadWritePartial",
}
REGCLASS = {
    "": "rcNone", "r8": "rcGp8Any", "r16": "rcGp16", "r32": "rcGp32", "r64": "rcGp64",
    "al": "rcGp8Any", "cl": "rcGp8Any", "ax": "rcGp16", "eax": "rcGp32", "rax": "rcGp64",
    "dx": "rcGp16", "edx": "rcGp32", "rdx": "rcGp64", "ecx": "rcGp32",
}
MEMCLASS = {"": "mcNone", "mem": "mcUnspecified", "m8": "mc8", "m16": "mc16", "m32": "mc32", "m64": "mc64"}
IMMKIND = {
    "": "ikNone", "imm8": "ikRaw8", "imms8": "ikSigned8", "immu8": "ikUnsigned8",
    "imm16": "ikRaw16", "immu16": "ikUnsigned16", "imm32": "ikRaw32",
    "imms32": "ikSigned32", "immu32": "ikUnsigned32", "imm64": "ikRaw64",
}
IMM_BYTES = {"imm8": 1, "imms8": 1, "immu8": 1, "imm16": 2, "immu16": 2,
             "imm32": 4, "imms32": 4, "immu32": 4, "imm64": 8}

OPTION_BITS = {
    "lock": 1 << 0,
    "rep": 1 << 1,
    "repne": 1 << 2,
    "repIgnore": 1 << 3,
    "xacquire": 1 << 4,
    "xrelease": 1 << 5,
    "bnd": 1 << 6,
    "ilock": 1 << 7,
}

@dataclass
class Operand:
    raw: str
    access_raw: str = ""
    access_expanded: str = ""
    commutative: bool = False
    conditional: bool = False
    reg: str = ""
    mem: str = ""
    imm: str = ""
    rel: int = 0
    fixed_reg: str = ""
    fixed_implicit: bool = False
    fixed_imm: int | None = None

@dataclass
class ParsedEncoding:
    tag: str = ""
    opcode_map: str = "primary"
    opcode: int = 0
    opcode_plus_reg: bool = False
    raw66: bool = False
    raw67: bool = False
    mandatory_prefix: str = "none"
    explicit_rexw: bool = False
    modrm_token: str = ""
    fixed_modrm: int | None = None
    imm_code: str = ""
    rel_code: str = ""

@dataclass
class Form:
    source_index: int
    category: str
    group_ext: Tuple[str, ...]
    record_ext: Tuple[str, ...]
    arch: str
    options_raw: Tuple[str, ...]
    mnemonic: str
    source_signature: str
    source_op: str
    io: str
    alt: bool
    operands: List[Operand]
    enc: ParsedEncoding
    expanded_width: int = 0
    native_support: str = "no"
    restriction: str = "not_exposed"
    canonicalization: str = "none"


def tokens(s: str) -> Tuple[str, ...]:
    return tuple(x for x in s.split() if x)


def split_options(sig: str) -> Tuple[Tuple[str, ...], str]:
    if not sig.startswith("["):
        return (), sig
    end = sig.find("]")
    if end < 0:
        raise ValueError(f"unterminated option list: {sig}")
    raw = sig[1:end]
    out: List[str] = []
    for opt in raw.split("|"):
        if opt == "xacqrel":
            out.extend(("xacquire", "xrelease"))
        elif opt:
            out.append(opt)
    return tuple(out), sig[end + 1:].strip()


def mnemonic_of(sig: str) -> str:
    _, body = split_options(sig)
    return body.split(None, 1)[0].lower()


def parse_operand(text: str) -> Operand:
    raw = text.strip()
    s = raw
    access = ""
    m = re.match(r"^([RWXwx])(\?)?:(.*)$", s)
    conditional = False
    if m:
        access, q, s = m.groups()
        conditional = bool(q)
    comm = s.startswith("~")
    if comm:
        s = s[1:]
    implicit = s.startswith("<") and s.endswith(">")
    if implicit:
        s = s[1:-1]

    op = Operand(raw=raw, access_raw=access, access_expanded=access,
                 commutative=comm, conditional=conditional, fixed_implicit=implicit)

    # Fixed immediate count 1.
    if s == "1":
        op.fixed_imm = 1
        op.imm = "imm8"
        return op

    if s in ("rel8", "rel32"):
        op.rel = 1 if s == "rel8" else 4
        return op
    if s.startswith("imm"):
        if s == "immv":
            op.imm = "immv"
        elif s in IMMKIND:
            op.imm = s
        else:
            raise ValueError(f"unsupported immediate operand token {s!r}")
        return op

    # Fixed register tokens.
    fixed = {"al", "cl", "ax", "eax", "rax", "dx", "edx", "rdx", "ecx", "axv", "dxv"}
    if s in fixed:
        op.fixed_reg = s
        return op

    # Register/memory union or pure register/memory.
    if "/" in s:
        a, b = s.split("/", 1)
        if a not in ("r8", "r16", "r32", "r64", "rv", "ry"):
            raise ValueError(f"unsupported register side {a!r} in {raw!r}")
        if b not in ("m8", "m16", "m32", "m64", "mv", "my"):
            raise ValueError(f"unsupported memory side {b!r} in {raw!r}")
        op.reg, op.mem = a, b
        return op
    if s in ("r8", "r16", "r32", "r64", "rv", "ry"):
        op.reg = s
        return op
    if s in ("m8", "m16", "m32", "m64", "mv", "my", "mem"):
        op.mem = s
        return op
    raise ValueError(f"unsupported operand token {s!r} in {raw!r}")


def parse_signature(sig: str) -> Tuple[Tuple[str, ...], str, List[Operand]]:
    opts, body = split_options(sig)
    if " " in body:
        mnemonic, rest = body.split(None, 1)
        ops = [parse_operand(x) for x in rest.split(",")]
    else:
        mnemonic, ops = body, []
    return opts, mnemonic.lower(), ops


def parse_encoding(op: str) -> ParsedEncoding:
    s = op.strip()
    tag = ""
    m = re.match(r"^\[([A-Z ]+)\]\s*(.*)$", s)
    if m:
        tag = m.group(1).replace(" ", "")
        s = m.group(2).strip()
        if tag not in TAG:
            raise ValueError(f"unsupported source encoding tag [{tag}] in {op!r}")

    out = ParsedEncoding(tag=tag)
    hexbytes: List[int] = []
    plus_reg_opcode: int | None = None
    for tok in s.split():
        u = tok.upper()
        if tok == "66":
            out.raw66 = True
        elif tok == "67":
            out.raw67 = True
        elif u == "NP":
            out.mandatory_prefix = "np"
        elif u == "F2":
            out.mandatory_prefix = "f2"
        elif u == "F3":
            out.mandatory_prefix = "f3"
        elif u == "REX.W":
            out.explicit_rexw = True
        elif re.fullmatch(r"/[0-7r]", tok):
            out.modrm_token = tok
        elif tok in ("ib", "iw", "id", "iq", "iv"):
            if out.imm_code:
                raise ValueError(f"multiple immediate codes in {op!r}")
            out.imm_code = tok
        elif tok in ("cb", "cd"):
            out.rel_code = tok
        elif re.fullmatch(r"[0-9A-Fa-f]{2}\+r", tok):
            plus_reg_opcode = int(tok[:2], 16)
        elif re.fullmatch(r"[0-9A-Fa-f]{2}", tok):
            hexbytes.append(int(tok, 16))
        else:
            raise ValueError(f"unsupported encoding token {tok!r} in {op!r}")

    if plus_reg_opcode is not None:
        if hexbytes:
            # 0F C8+r etc: retain 0F as map byte and +r as final opcode.
            hexbytes.append(plus_reg_opcode)
        else:
            hexbytes = [plus_reg_opcode]
        out.opcode_plus_reg = True

    if not hexbytes:
        raise ValueError(f"no opcode bytes in {op!r}")

    if hexbytes[0] == 0x0F:
        if len(hexbytes) >= 2 and hexbytes[1] in (0x38, 0x3A):
            out.opcode_map = "0f38" if hexbytes[1] == 0x38 else "0f3a"
            payload = hexbytes[2:]
        else:
            out.opcode_map = "0f"
            payload = hexbytes[1:]
    else:
        payload = hexbytes

    if not payload:
        raise ValueError(f"missing final opcode in {op!r}")
    out.opcode = payload[0]
    if len(payload) > 1:
        if len(payload) != 2 or out.modrm_token:
            raise ValueError(f"unresolved extra opcode/fixed bytes {payload!r} in {op!r}")
        # For the selected legacy subset this is a fully fixed ModRM byte
        # (LFENCE/MFENCE/SFENCE/RDTSCP).
        out.fixed_modrm = payload[1]
    return out


def uses_v_group(ops: Iterable[Operand]) -> bool:
    for o in ops:
        if o.reg in ("rv",) or o.mem in ("mv",) or o.imm == "immv" or o.fixed_reg in ("axv", "dxv"):
            return True
    return False


def uses_y_group(ops: Iterable[Operand]) -> bool:
    return any(o.reg == "ry" or o.mem == "my" for o in ops)


def expand_operand(op: Operand, width: int) -> Operand:
    x = replace(op)
    sub_r = {16: "r16", 32: "r32", 64: "r64"}
    sub_m = {16: "m16", 32: "m32", 64: "m64"}
    if x.reg == "rv": x.reg = sub_r[width]
    if x.mem == "mv": x.mem = sub_m[width]
    if x.reg == "ry": x.reg = sub_r[width]
    if x.mem == "my": x.mem = sub_m[width]
    if x.imm == "immv": x.imm = {16: "imm16", 32: "imm32", 64: "imms32"}[width]
    if x.fixed_reg == "axv": x.fixed_reg = {16: "ax", 32: "eax", 64: "rax"}[width]
    if x.fixed_reg == "dxv": x.fixed_reg = {16: "dx", 32: "edx", 64: "rdx"}[width]
    # AsmJit grouped-rv access promotion: lower-case write/read-write becomes full
    # write/read-write in the 32/64 concrete variants.
    if width in (32, 64) and x.access_expanded in ("w", "x"):
        x.access_expanded = x.access_expanded.upper()
    return x


def expand_form(f: Form) -> List[Form]:
    if uses_v_group(f.operands) and uses_y_group(f.operands):
        raise ValueError(f"mixed rv/ry groups are not supported: {f.source_signature}")
    if uses_v_group(f.operands):
        widths = (16, 32, 64)
    elif uses_y_group(f.operands):
        widths = (32, 64)
    else:
        widths = (0,)
    out = []
    for w in widths:
        nf = replace(f, operands=[expand_operand(o, w) for o in f.operands], expanded_width=w)
        out.append(nf)
    return out


def options_mask(opts: Iterable[str]) -> int:
    v = 0
    for opt in opts:
        if opt not in OPTION_BITS:
            raise ValueError(f"unknown selected instruction option {opt!r}")
        v |= OPTION_BITS[opt]
    return v


def fixed_reg_fields(name: str) -> Tuple[int, str]:
    if not name:
        return 0, "rt64"
    ids = {"al":0,"ax":0,"eax":0,"rax":0,"cl":1,"ecx":1,"dx":2,"edx":2,"rdx":2}
    typ = {"al":"rt8","cl":"rt8","ax":"rt16","dx":"rt16","eax":"rt32","ecx":"rt32","edx":"rt32","rax":"rt64","rdx":"rt64"}
    if name not in ids:
        raise ValueError(f"unsupported fixed register {name!r}")
    return ids[name], typ[name]


def classify_native(f: Form) -> Tuple[str, str, str]:
    """Conservative current-Builder support classification.

    'yes' means the public API exposes the complete concrete source form.
    'partial' means the source form is broader than the public API/canonicalizer.
    """
    m, e = f.mnemonic, f.enc
    # Simple fixed no-operand instructions exposed exactly.
    if m in {"lfence", "mfence", "sfence", "rdtsc", "rdtscp", "int3", "ud2"}:
        return "yes", "none", "none"
    if m == "nop":
        if not f.operands:
            return "yes", "none", "nop"
        return "no", "not_exposed", "nop"
    if m == "syscall":
        return "no", "no_syscall", "none"
    if m == "ret":
        return "yes", "none", "none"
    if m == "lea":
        if f.operands and f.operands[0].reg in {"r16", "r32", "r64"}:
            return "yes", "none", "lea16" if f.operands[0].reg == "r16" else "none"
    if m == "bswap":
        r = f.operands[0].reg if f.operands else ""
        return ("yes", "bswap64", "none") if r == "r64" else ("no", "bswap64", "none")
    if m in {"rcl", "rcr"}:
        return "no", "not_exposed", "none"
    if m in {"rol", "ror"}:
        # Public Builder is register + Byte immediate only; source also allows mem/CL/1.
        return "partial", "rotate_imm_reg", "none"
    if m in {"shl", "shr", "sar"}:
        return "partial", "shift_count", "none"
    if m in {"bsf", "bsr", "popcnt"}:
        return "partial", "register_source_only", "none"
    if m == "imul":
        # two/three operand APIs use register source; one-operand implicit form absent.
        if f.operands and f.operands[0].fixed_implicit:
            return "no", "not_exposed", "none"
        return "partial", "register_source_only", "none"
    if m == "mul":
        return "partial", "explicit_mem_size", "none"
    if m.startswith("cmov"):
        return "partial", "register_source_only", "none"
    if m.startswith("set"):
        return "partial", "register_dest_only", "setcc0"
    if m.startswith("j") and m != "jmp":
        if e.rel_code == "cb":
            return "no", "no_rel8", "none"
        return "partial", "conditions10", "none"
    if m == "jmp":
        if e.rel_code == "cb": return "no", "no_rel8", "none"
        if e.rel_code == "cd": return "yes", "none", "none"
        return "no", "no_indirect_jmp", "none"
    if m == "call":
        if e.rel_code == "cd": return "yes", "none", "none"
        # x64 r/m64 indirect is exposed; parser filters x86 forms.
        return "yes", "none", "none"
    if m in {"push", "pop"}:
        if m == "push" and any(o.imm for o in f.operands):
            # NativeAsm's numeric PUSH API represents normal x64 stack pushes:
            # signed imm8 (6A) or signed imm32 (68). The source DB's push imm16
            # is valid x86-64 but changes stack width and is intentionally not
            # selected by the existing Push(Int64) API.
            if any(o.imm == "imm16" for o in f.operands):
                return "no", "not_exposed", "none"
            return "partial", "none", "pushimm"
        # memory forms are source-broader than current qword/unspecified policy.
        if any(o.mem for o in f.operands): return "partial", "stack_mem64", "none"
        return "yes", "none", "none"
    if m in {"movsx", "movzx", "movsxd"}:
        # Current source operand path is memory only, never register.
        return "partial", "memory_source_only", "none"
    if m == "mov":
        if any(o.imm for o in f.operands) and any(o.mem for o in f.operands):
            return "partial", "no_memory_immediate", "none"
        return "partial", "none", "none"
    if m == "xchg":
        return "partial", "register_source_only", "none"
    if m in {"inc", "dec", "neg", "not"}:
        return "partial", "explicit_mem_size", "none"
    if m in {"add", "adc", "sub", "sbb", "and", "or", "xor", "cmp", "test"}:
        if any(o.imm for o in f.operands):
            if f.expanded_width == 64 or any(o.reg == "r64" or o.mem == "m64" for o in f.operands):
                return "partial", "signed_imm32_64", "none"
            return "partial", "explicit_mem_size", "none"
        return "partial", "none", "none"
    return "no", "not_exposed", "none"


def source_forms(db: dict) -> List[Form]:
    out: List[Form] = []
    src_index = 0
    for group in db["instructions"]:
        category = group.get("category", "")
        gext = tokens(group.get("ext", ""))
        for rec in group.get("instructions", []):
            rext = tokens(rec.get("ext", ""))
            effective = set(gext) | set(rext)
            if not effective <= ALLOWED_EXT:
                continue
            for arch in ("any", "x64"):
                if arch not in rec:
                    continue
                sig = rec[arch]
                mnem = mnemonic_of(sig)
                if mnem not in TARGET_MNEMONICS:
                    continue
                if any(t in sig for t in EXCLUDED_SIGNATURE_TOKENS):
                    continue
                try:
                    opts, parsed_mnem, ops = parse_signature(sig)
                    enc = parse_encoding(rec.get("op", ""))
                except ValueError as exc:
                    raise ValueError(f"selected form failed closed: {sig!r} / {rec.get('op','')!r}: {exc}") from exc
                f = Form(
                    source_index=src_index, category=category, group_ext=gext, record_ext=rext,
                    arch=arch, options_raw=opts, mnemonic=parsed_mnem,
                    source_signature=sig, source_op=rec.get("op", ""), io=rec.get("io", ""),
                    alt=bool(rec.get("alt", False)), operands=ops, enc=enc,
                )
                out.extend(expand_form(f))
                src_index += 1
    for i, f in enumerate(out):
        f.native_support, f.restriction, f.canonicalization = classify_native(f)
    return out


def pstr(s: str) -> str:
    return "'" + s.replace("'", "''") + "'"


def category_mask(cat: str) -> int:
    # Stable bit mapping for the small selected category set.
    bits = {"GP": 1 << 0, "GP_EXT": 1 << 1}
    v = 0
    for t in cat.split():
        if t not in bits:
            raise ValueError(f"unknown selected category token {t!r}")
        v |= bits[t]
    return v


def ext_mask(g: Iterable[str], r: Iterable[str]) -> int:
    bits = {"CMOV":1<<0,"POPCNT":1<<1,"RDTSC":1<<2,"RDTSCP":1<<3,"SSE":1<<4,"SSE2":1<<5}
    v = 0
    for t in set(g) | set(r):
        if t not in bits:
            raise ValueError(f"unknown selected extension token {t!r}")
        v |= bits[t]
    return v


def operand_pas(op: Operand) -> str:
    reg = op.reg
    mem = op.mem
    # After expansion no grouped tokens may remain.
    if reg not in REGCLASS:
        raise ValueError(f"unexpanded/unknown register class {reg!r}")
    if mem not in MEMCLASS:
        raise ValueError(f"unexpanded/unknown memory class {mem!r}")
    ik = IMMKIND.get(op.imm, "ikNone")
    if op.imm and op.imm not in IMMKIND:
        raise ValueError(f"unexpanded/unknown immediate class {op.imm!r}")
    kinds = 0
    if reg or op.fixed_reg: kinds |= 1
    if mem: kinds |= 2
    if op.imm or op.fixed_imm is not None: kinds |= 4
    if op.rel: kinds |= 8
    fixed_id, fixed_type = fixed_reg_fields(op.fixed_reg)
    fixed_flags = (1 if op.fixed_reg else 0) | (2 if op.fixed_implicit else 0) | (4 if op.fixed_imm is not None else 0)
    fixed_imm = op.fixed_imm or 0
    return (
        f"(Kinds:${kinds:02X}; RegClass:{REGCLASS[reg]}; MemClass:{MEMCLASS[mem]}; "
        f"RawAccess:{ACCESS[op.access_raw]}; ExpandedAccess:{ACCESS[op.access_expanded]}; "
        f"Flags:${(1 if op.commutative else 0) | (2 if op.conditional else 0):02X}; "
        f"FixedFlags:${fixed_flags:02X}; FixedRegID:{fixed_id}; FixedRegType:{fixed_type}; "
        f"FixedImm:{fixed_imm}; ImmKind:{ik}; RelBytes:{op.rel})"
    )


def derive_rexw(f: Form) -> str:
    if f.enc.explicit_rexw:
        return "force"
    # Concrete expanded grouped 64-bit forms acquire REX.W when their source
    # group is operand-size driven. Default-64 stack/control-flow forms are excluded.
    if f.expanded_width == 64 and f.mnemonic not in {"push", "pop", "call", "jmp", "ret"}:
        return "bywidth"
    return "never"


def derive_p66(f: Form) -> str:
    # LEA r16 is a Native canonicalization exception: raw DB has 67, Native uses 66.
    if f.mnemonic == "lea" and f.operands and f.operands[0].reg == "r16":
        return "force"
    if f.enc.raw66:
        return "force"
    if f.expanded_width == 16:
        return "bywidth"
    return "never"


def modrm_fields(f: Form) -> Tuple[str,int,int,int,int]:
    e = f.enc
    if e.fixed_modrm is not None:
        return "fixedbyte", -1, -1, 0, e.fixed_modrm
    if not e.modrm_token:
        return "none", -1, -1, 0, 0
    if e.modrm_token != "/r":
        n = int(e.modrm_token[1])
        # Fixed /n always encodes the first register/memory operand in r/m for our subset.
        rm = next((i for i,o in enumerate(f.operands) if o.reg or o.mem), -1)
        return "fixedreg", -1, rm, n, 0
    if f.mnemonic.startswith("set"):
        return "ignored", -1, 0, 0, 0
    if e.tag == "MR":
        return "operands", 1, 0, 0, 0
    if e.tag == "RM":
        return "operands", 0, 1, 0, 0
    # Rare /r with an M/OP source form must be intentionally understood.
    if e.tag == "M" and len(f.operands) == 1:
        return "ignored", -1, 0, 0, 0
    raise ValueError(f"cannot resolve /r binding for {f.source_signature} => {f.source_op}")


def opcode_reg_idx(f: Form) -> int:
    if not f.enc.opcode_plus_reg:
        return -1
    candidates = []
    for i,o in enumerate(f.operands):
        if o.reg and not o.fixed_reg:
            candidates.append(i)
        elif o.fixed_reg == "":
            # fixed register tokens are represented only in fixed_reg; normal reg in reg.
            pass
    # MOV reg, imm has one normal reg. PUSH/POP/BSWAP same. XCHG has one normal
    # r16/r32/r64 plus one fixed AX/EAX/RAX.
    if len(candidates) != 1:
        raise ValueError(f"cannot resolve opcode+reg operand for {f.source_signature}")
    return candidates[0]


def imm_fields(f: Form) -> Tuple[int,str,int]:
    idx = next((i for i,o in enumerate(f.operands) if o.imm and o.fixed_imm is None), -1)
    if idx < 0:
        return -1, "ikNone", 0
    o = f.operands[idx]
    kind = IMMKIND[o.imm]
    size = IMM_BYTES[o.imm]
    # Cross-check compact encoding code.
    code_size = {"ib":1,"iw":2,"id":4,"iq":8,"iv":size}.get(f.enc.imm_code, 0)
    if code_size != size:
        raise ValueError(f"immediate width mismatch in {f.source_signature}: operand {o.imm}, op {f.source_op}")
    return idx, kind, size


def fixup_fields(f: Form) -> Tuple[bool,str,int]:
    idx = next((i for i,o in enumerate(f.operands) if o.rel), -1)
    if idx < 0:
        if f.enc.rel_code:
            raise ValueError(f"rel encoding without relative operand: {f.source_signature}")
        return False, "none", -1
    kind = "rel8" if f.operands[idx].rel == 1 else "rel32"
    expected = "cb" if kind == "rel8" else "cd"
    if f.enc.rel_code != expected:
        raise ValueError(f"relative width mismatch in {f.source_signature}: {f.source_op}")
    return True, kind, idx


def render(forms: List[Form], source_hash: str) -> str:
    mnems = sorted({f.mnemonic for f in forms})
    mindex = {m:i for i,m in enumerate(mnems)}

    # Keep CInstructionForms in lossless source order, but generate a compact
    # mnemonic -> form-index indirection table so runtime selection never scans
    # all forms or repeatedly compares strings.
    form_order: List[int] = []
    mnemonic_starts: List[int] = []
    mnemonic_counts: List[int] = []
    for m in mnems:
        mnemonic_starts.append(len(form_order))
        ids = [i for i, f in enumerate(forms) if f.mnemonic == m]
        form_order.extend(ids)
        mnemonic_counts.append(len(ids))

    operands: List[Operand] = []
    starts: List[int] = []
    for f in forms:
        starts.append(len(operands))
        operands.extend(f.operands)

    lines: List[str] = []
    lines.append("unit NativeAsm.InstructionDB.Generated;")
    lines.append("")
    lines.append("{ AUTO-GENERATED. DO NOT EDIT BY HAND.")
    lines.append("  Generator : Tools/generate_instruction_db.py")
    lines.append(f"  Source SHA256: {source_hash}")
    lines.append("  Scope     : NativeAsm legacy x64 GP/control-flow/fence/timing/debug subset")
    lines.append("}")
    lines.append("")
    lines.append("interface")
    lines.append("")
    lines.append("uses NativeAsm.Types, NativeAsm.InstructionDB;")
    lines.append("")
    lines.append("const")
    lines.append(f"  CInstructionDbSourceSha256 = '{source_hash}';")
    lines.append(f"  CInstructionMnemonicCount = {len(mnems)};")
    lines.append(f"  CInstructionFormCount = {len(forms)};")
    lines.append(f"  CInstructionOperandCount = {len(operands)};")
    lines.append("")
    lines.append(f"  CInstructionMnemonicNames: array[0..{len(mnems)-1}] of string = (")
    for i,m in enumerate(mnems):
        lines.append(f"    {pstr(m)}{',' if i+1<len(mnems) else ''}")
    lines.append("  );")
    lines.append("")
    lines.append(f"  CInstructionMnemonicFormStart: array[0..{len(mnems)-1}] of Word = (")
    for i, v in enumerate(mnemonic_starts):
        lines.append(f"    {v}{',' if i+1<len(mnemonic_starts) else ''}")
    lines.append("  );")
    lines.append("")
    lines.append(f"  CInstructionMnemonicFormCount: array[0..{len(mnems)-1}] of Word = (")
    for i, v in enumerate(mnemonic_counts):
        lines.append(f"    {v}{',' if i+1<len(mnemonic_counts) else ''}")
    lines.append("  );")
    lines.append("")
    lines.append(f"  CInstructionFormOrder: array[0..{len(forms)-1}] of Word = (")
    for i, v in enumerate(form_order):
        lines.append(f"    {v}{',' if i+1<len(form_order) else ''}")
    lines.append("  );")
    lines.append("")
    lines.append(f"  CInstructionSourceSignatures: array[0..{len(forms)-1}] of string = (")
    for i,f in enumerate(forms):
        suffix = "," if i+1<len(forms) else ""
        lines.append(f"    {pstr(f.source_signature)}{suffix}")
    lines.append("  );")
    lines.append("")
    lines.append(f"  CInstructionSourceOps: array[0..{len(forms)-1}] of string = (")
    for i,f in enumerate(forms):
        suffix = "," if i+1<len(forms) else ""
        lines.append(f"    {pstr(f.source_op)}{suffix}")
    lines.append("  );")
    lines.append("")
    lines.append(f"  CInstructionOperands: array[0..{len(operands)-1}] of TDbOperandSpec = (")
    for i,o in enumerate(operands):
        lines.append(f"    {operand_pas(o)}{',' if i+1<len(operands) else ''}")
    lines.append("  );")
    lines.append("")
    lines.append(f"  CInstructionForms: array[0..{len(forms)-1}] of TEncodingDescriptor = (")
    for i,f in enumerate(forms):
        e=f.enc
        mk, regidx, rmidx, fixedreg, fixedbyte = modrm_fields(f)
        opregidx = opcode_reg_idx(f)
        immidx, immkind, immbytes = imm_fields(f)
        hasfix, fixkind, fixidx = fixup_fields(f)
        prefix = e.mandatory_prefix
        # A raw F2/F3/NP is mandatory metadata; raw 66 remains an operand-size policy in selected GP forms.
        native, restriction, canon = f.native_support, f.restriction, f.canonicalization
        rec = (
            f"(MnemonicIndex:{mindex[f.mnemonic]}; SourceRecordIndex:{f.source_index}; SourceArch:{ARCH[f.arch]}; "
            f"CategoryMask:${category_mask(f.category):04X}; ExtensionMask:${ext_mask(f.group_ext,f.record_ext):04X}; "
            f"AllowedOptionsMask:${options_mask(f.options_raw):04X}; SourceTag:{TAG[e.tag]}; SourceAlt:{str(f.alt).lower()}; ExpandedWidth:{f.expanded_width}; "
            f"OpcodeMap:{MAP[e.opcode_map]}; Opcode:${e.opcode:02X}; OpcodePlusReg:{str(e.opcode_plus_reg).lower()}; "
            f"MandatoryPrefix:{PREFIX[prefix]}; Raw66:{str(e.raw66).lower()}; Raw67:{str(e.raw67).lower()}; "
            f"RexWPolicy:{REXW[derive_rexw(f)]}; Legacy66Policy:{P66[derive_p66(f)]}; "
            f"ModRMKind:{MODRM[mk]}; ModRegOperandIdx:{regidx}; ModRmOperandIdx:{rmidx}; "
            f"FixedRegValue:{fixedreg}; FixedModRMByte:${fixedbyte:02X}; OpcodeRegOperandIdx:{opregidx}; "
            f"ImmediateOperandIdx:{immidx}; ImmKind:{immkind}; ImmediateBytes:{immbytes}; "
            f"HasFixup:{str(hasfix).lower()}; FixupKind:{FIXUP[fixkind]}; FixupOperandIdx:{fixidx}; "
            f"OperandStart:{starts[i]}; OperandCount:{len(f.operands)}; NativeSupport:{SUPPORT[native]}; "
            f"NativeRestriction:{RESTRICTION[restriction]}; NativeCanonicalization:{CANON[canon]})"
        )
        lines.append(f"    {rec}{',' if i+1<len(forms) else ''}")
    lines.append("  );")
    lines.append("")
    lines.append("implementation")
    lines.append("")
    lines.append("end.")
    lines.append("")
    return "\n".join(lines)


def report(forms: List[Form], source_hash: str) -> dict:
    by_support = {k:0 for k in ("yes","partial","no")}
    by_mnemonic: Dict[str,int] = {}
    for f in forms:
        by_support[f.native_support] += 1
        by_mnemonic[f.mnemonic] = by_mnemonic.get(f.mnemonic,0)+1
    return {
        "source_sha256": source_hash,
        "forms": len(forms),
        "mnemonics": len(by_mnemonic),
        "native_support": by_support,
        "forms_by_mnemonic": dict(sorted(by_mnemonic.items())),
    }


def main() -> int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--input", required=True, type=Path)
    ap.add_argument("--output", required=True, type=Path)
    ap.add_argument("--report", type=Path)
    ap.add_argument("--check", action="store_true", help="fail if generated output differs from --output")
    args=ap.parse_args()
    raw=args.input.read_bytes()
    source_hash=hashlib.sha256(raw).hexdigest()
    db=json.loads(raw.decode("utf-8"))
    forms=source_forms(db)
    text=render(forms,source_hash)
    if args.check:
        if not args.output.exists() or args.output.read_text(encoding="utf-8") != text:
            raise SystemExit("generated instruction DB is stale; run generate_instruction_db.py without --check")
    else:
        args.output.parent.mkdir(parents=True,exist_ok=True)
        args.output.write_text(text,encoding="utf-8",newline="\n")
    if args.report:
        args.report.write_text(json.dumps(report(forms,source_hash),indent=2)+"\n",encoding="utf-8")
    print(json.dumps(report(forms,source_hash),indent=2))
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
