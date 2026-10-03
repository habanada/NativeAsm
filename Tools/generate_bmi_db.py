#!/usr/bin/env python3
from __future__ import annotations
import argparse, hashlib, json, re
from dataclasses import dataclass
from pathlib import Path
from typing import List, Tuple

TARGETS = {'andn','bextr','blsi','blsmsk','blsr','bzhi','mulx','pdep','pext','rorx','sarx','shlx','shrx'}
EXTS = {'BMI':'beBMI1','BMI2':'beBMI2'}
TAG_ENUM = {'RVM':'befRVM','RMV':'befRMV','VM':'befVM','RM':'befRM'}
MAP_ENUM = {'0f38':'bom0F38','0f3a':'bom0F3A'}
REG_ENUM = {32:'brc32',64:'brc64'}
MEM_ENUM = {0:'bmcNone',32:'bmc32',64:'bmc64'}
KIND_REG = 1
KIND_MEM = 2
KIND_IMM = 4

@dataclass
class Operand:
    raw: str
    reg_bits: int = 0
    mem_bits: int = 0
    imm: int = 0

@dataclass
class Encoding:
    tag: str
    pp: int
    opmap: str
    w: int
    opcode: int
    modrm_fixed_reg: int
    imm_bytes: int

@dataclass
class Form:
    ext: str
    signature: str
    optext: str
    mnemonic: str
    operands: List[Operand]
    enc: Encoding


def normalize_atom(s: str) -> str:
    s = s.strip()
    m = re.match(r'^[RWXwx](?:\?)?:(.*)$', s)
    if m:
        s = m.group(1)
    if s.startswith('~'):
        s = s[1:]
    return s.strip()


def parse_operand(text: str, bits: int):
    s = normalize_atom(text)
    if s.startswith('<') and s.endswith('>'):
        return None
    s = re.sub(r'\bry\b', f'r{bits}', s)
    s = re.sub(r'\bmy\b', f'm{bits}', s)
    if '/' in s:
        a, b = s.split('/', 1)
        if a == f'r{bits}' and b == f'm{bits}':
            return Operand(text, bits, bits)
        raise ValueError(f'unsupported BMI operand {text!r}')
    if s == f'r{bits}':
        return Operand(text, reg_bits=bits)
    if s == f'm{bits}':
        return Operand(text, mem_bits=bits)
    if s == 'imm8':
        return Operand(text, imm=1)
    raise ValueError(f'unsupported BMI operand {text!r}')


def parse_signature(sig: str, bits: int) -> Tuple[str, List[Operand]]:
    body = sig.strip()
    mnemonic, rest = body.split(None, 1)
    operands = []
    for text in rest.split(','):
        op = parse_operand(text, bits)
        if op is not None:
            operands.append(op)
    return mnemonic.lower(), operands


def parse_encoding(text: str, bits: int) -> Encoding:
    m = re.match(r'^\[([A-Z ]+)\]\s*(VEX\.[^ ]+)\s+([0-9A-Fa-f]{2})(?:\s+(/r|/[0-7]))?(?:\s+(ib))?$', text.strip())
    if not m:
        raise ValueError(f'unsupported BMI encoding {text!r}')
    tag = m.group(1).replace(' ', '')
    if tag not in TAG_ENUM:
        raise ValueError(f'unsupported BMI tag {tag!r}')
    fields = m.group(2).split('.')
    if fields[0].upper() != 'VEX' or fields[1].upper() != 'LZ':
        raise ValueError(f'unsupported BMI VEX fields {m.group(2)!r}')
    if len(fields) == 4:
        pp = 0
        opmap = fields[2].lower()
        wtok = fields[3].upper()
    elif len(fields) == 5:
        pp = {'NP':0,'66':1,'F3':2,'F2':3}[fields[2].upper()]
        opmap = fields[3].lower()
        wtok = fields[4].upper()
    else:
        raise ValueError(f'unsupported BMI VEX fields {m.group(2)!r}')
    if opmap not in MAP_ENUM:
        raise ValueError(f'unsupported BMI map {opmap!r}')
    if wtok != 'WY':
        raise ValueError(f'unsupported BMI W field {wtok!r}')
    modrm = m.group(4) or ''
    fixed = int(modrm[1]) if len(modrm) == 2 and modrm[0] == '/' and modrm[1].isdigit() else -1
    return Encoding(tag, pp, opmap, 1 if bits == 64 else 0, int(m.group(3), 16), fixed, 1 if m.group(5) else 0)


def source_forms(db) -> List[Form]:
    out = []
    for group in db['instructions']:
        ext = group.get('ext','')
        if ext not in EXTS:
            continue
        for rec in group.get('instructions',[]):
            sig = rec.get('x64') or rec.get('any')
            if not sig:
                continue
            mnemonic = sig.split(None,1)[0].lower()
            if mnemonic not in TARGETS:
                continue
            for bits in (32,64):
                mnem, ops = parse_signature(sig, bits)
                enc = parse_encoding(rec['op'], bits)
                out.append(Form(ext, sig, rec['op'], mnem, ops, enc))
    return out


def binding(f: Form):
    if f.enc.tag == 'RVM':
        return 0, 2, 1
    if f.enc.tag == 'RMV':
        return 0, 1, 2
    if f.enc.tag == 'VM':
        return -1, 1, 0
    if f.enc.tag == 'RM':
        return 0, 1, -1
    raise ValueError(f.enc.tag)


def passtr(s: str) -> str:
    return "'" + s.replace("'", "''") + "'"


def render_db(forms: List[Form], sha: str):
    mnems = sorted(set(f.mnemonic for f in forms))
    mi = {m:i for i,m in enumerate(mnems)}
    order = []
    starts = []
    counts = []
    for m in mnems:
        starts.append(len(order))
        ids = [i for i,f in enumerate(forms) if f.mnemonic == m]
        counts.append(len(ids))
        order.extend(ids)
    ops = []
    opstarts = []
    for f in forms:
        opstarts.append(len(ops))
        ops.extend(f.operands)
    lines = ['unit NativeAsm.Bmi.Db.Generated;','','interface','','uses','  NativeAsm.Bmi.Db;','','const',f"  CBmiDbSourceSha256 = '{sha}';",f'  CBmiMnemonicCount = {len(mnems)};',f'  CBmiFormCount = {len(forms)};',f'  CBmiOperandCount = {len(ops)};','']
    def arr(name, typ, vals, fmt=str):
        lines.append(f'  {name}: array[0..{len(vals)-1}] of {typ} = (')
        for i,v in enumerate(vals):
            lines.append(f'    {fmt(v)}{"," if i+1 < len(vals) else ""}')
        lines.append('  );')
        lines.append('')
    arr('CBmiMnemonicNames','string',mnems,passtr)
    arr('CBmiMnemonicFormStart','Word',starts)
    arr('CBmiMnemonicFormCount','Word',counts)
    arr('CBmiFormOrder','Word',order)
    arr('CBmiSourceSignatures','string',[f.signature for f in forms],passtr)
    arr('CBmiSourceEncodings','string',[f.optext for f in forms],passtr)
    lines.append(f'  CBmiOperands: array[0..{len(ops)-1}] of TBmiDbOperandSpec = (')
    for i,o in enumerate(ops):
        kinds = (KIND_REG if o.reg_bits else 0) | (KIND_MEM if o.mem_bits else 0) | (KIND_IMM if o.imm else 0)
        reg = REG_ENUM.get(o.reg_bits, 'brcNone')
        mem = MEM_ENUM[o.mem_bits]
        rec = f'(Kinds:${kinds:02X}; RegClass:{reg}; MemClass:{mem}; ImmBytes:{o.imm})'
        lines.append(f'    {rec}{"," if i+1 < len(ops) else ""}')
    lines.append('  );')
    lines.append('')
    lines.append(f'  CBmiForms: array[0..{len(forms)-1}] of TBmiEncodingDescriptor = (')
    for i,f in enumerate(forms):
        regidx, rmidx, vvidx = binding(f)
        immidx = next((j for j,o in enumerate(f.operands) if o.imm), -1)
        if f.enc.imm_bytes != (1 if immidx >= 0 else 0):
            raise ValueError(f'immediate mismatch {f.signature}')
        rec = f'(MnemonicIndex:{mi[f.mnemonic]}; Extension:{EXTS[f.ext]}; FormTag:{TAG_ENUM[f.enc.tag]}; VexPP:{f.enc.pp}; VexW:{f.enc.w}; OpcodeMap:{MAP_ENUM[f.enc.opmap]}; Opcode:${f.enc.opcode:02X}; ModRegOperandIdx:{regidx}; ModRegFixed:{f.enc.modrm_fixed_reg}; ModRmOperandIdx:{rmidx}; VvvvOperandIdx:{vvidx}; ImmediateOperandIdx:{immidx}; OperandStart:{opstarts[i]}; OperandCount:{len(f.operands)})'
        lines.append(f'    {rec}{"," if i+1 < len(forms) else ""}')
    lines += ['  );','','implementation','','end.','']
    return '\r\n'.join(lines), mnems


def render_api(forms: List[Form], mnems: List[str]):
    arities = {m:sorted(set(len(f.operands) for f in forms if f.mnemonic == m)) for m in mnems}
    decl = []
    impl = []
    for m in mnems:
        name = m[0].upper() + m[1:]
        for arity in arities[m]:
            args = '; '.join(f'A{i}: TOperand' for i in range(arity))
            decl.append(f'    function {name}({args}): TAsmBuilder;')
            impl.append(f'function TAsmBmiHelper.{name}({args}): TAsmBuilder;')
            impl.append('begin')
            vals = ', '.join(f'A{i}' for i in range(arity))
            impl.append(f"  Result := Bmi('{m}', [{vals}]);")
            impl.append('end;')
            impl.append('')
    return '\r\n'.join(decl) + '\r\n', '\r\n'.join(impl) + '\r\n'


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--input', required=True)
    ap.add_argument('--output', required=True)
    ap.add_argument('--decl-output', required=True)
    ap.add_argument('--impl-output', required=True)
    ap.add_argument('--report', required=True)
    a = ap.parse_args()
    raw = Path(a.input).read_bytes()
    db = json.loads(raw.decode())
    forms = source_forms(db)
    text, mnems = render_db(forms, hashlib.sha256(raw).hexdigest())
    decl, impl = render_api(forms, mnems)
    Path(a.output).write_bytes(text.encode('utf-8'))
    Path(a.decl_output).write_bytes(decl.encode('utf-8'))
    Path(a.impl_output).write_bytes(impl.encode('utf-8'))
    report = {
        'source_sha256': hashlib.sha256(raw).hexdigest(),
        'forms': len(forms),
        'mnemonics': len(mnems),
        'extensions': {e:sum(1 for f in forms if f.ext == e) for e in EXTS},
        'immediate_forms': sum(1 for f in forms if f.enc.imm_bytes),
        'selected_mnemonics': mnems,
        'existing_bmi1_mnemonic_not_duplicated': 'tzcnt'
    }
    Path(a.report).write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(report, indent=2))

if __name__ == '__main__':
    main()
