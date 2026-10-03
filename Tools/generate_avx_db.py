#!/usr/bin/env python3
from __future__ import annotations
import argparse, hashlib, json, re
from dataclasses import dataclass
from pathlib import Path
from typing import List, Tuple

TARGETS = {'vaddpd','vaddps','vaddsubpd','vaddsubps','vandnpd','vandnps','vandpd','vandps','vblendpd','vblendps','vbroadcastf128','vbroadcasti128','vcmppd','vcmpps','vdivpd','vdivps','vdppd','vdpps','vextractf128','vextracti128','vfmadd132pd','vfmadd132ps','vfmadd213pd','vfmadd213ps','vfmadd231pd','vfmadd231ps','vfmaddsub132pd','vfmaddsub132ps','vfmaddsub213pd','vfmaddsub213ps','vfmaddsub231pd','vfmaddsub231ps','vfmsub132pd','vfmsub132ps','vfmsub213pd','vfmsub213ps','vfmsub231pd','vfmsub231ps','vfmsubadd132pd','vfmsubadd132ps','vfmsubadd213pd','vfmsubadd213ps','vfmsubadd231pd','vfmsubadd231ps','vfnmadd132pd','vfnmadd132ps','vfnmadd213pd','vfnmadd213ps','vfnmadd231pd','vfnmadd231ps','vfnmsub132pd','vfnmsub132ps','vfnmsub213pd','vfnmsub213ps','vfnmsub231pd','vfnmsub231ps','vhaddpd','vhaddps','vhsubpd','vhsubps','vinsertf128','vinserti128','vlddqu','vmaxpd','vmaxps','vminpd','vminps','vmovapd','vmovaps','vmovdqa','vmovdqu','vmovntdq','vmovntpd','vmovntps','vmovshdup','vmovsldup','vmpsadbw','vmulpd','vmulps','vorpd','vorps','vpabsb','vpabsw','vpackssdw','vpacksswb','vpackusdw','vpackuswb','vpaddb','vpaddd','vpaddq','vpaddsb','vpaddsw','vpaddusb','vpaddusw','vpaddw','vpalignr','vpand','vpandn','vpavgb','vpavgw','vpblendd','vpblendw','vpcmpeqb','vpcmpeqd','vpcmpeqq','vpcmpeqw','vpcmpgtb','vpcmpgtd','vpcmpgtq','vpcmpgtw','vperm2f128','vperm2i128','vpermd','vpermilpd','vpermilps','vpermpd','vpermps','vpermq','vphaddd','vphaddsw','vphaddw','vphsubd','vphsubsw','vphsubw','vpmaddubsw','vpmaddwd','vpmaxsb','vpmaxsd','vpmaxsw','vpmaxub','vpmaxud','vpmaxuw','vpminsb','vpminsd','vpminsw','vpminub','vpminud','vpminuw','vpmuldq','vpmulhrsw','vpmulhuw','vpmulhw','vpmulld','vpmullw','vpmuludq','vpor','vpsadbw','vpshufb','vpshufd','vpshufhw','vpshuflw','vpsignb','vpsignd','vpsignw','vpslld','vpslldq','vpsllq','vpsllvd','vpsllvq','vpsllw','vpsrad','vpsravd','vpsraw','vpsrld','vpsrldq','vpsrlq','vpsrlvd','vpsrlvq','vpsrlw','vpsubb','vpsubd','vpsubq','vpsubsb','vpsubsw','vpsubusb','vpsubusw','vpsubw','vptest','vpunpckhbw','vpunpckhdq','vpunpckhqdq','vpunpckhwd','vpunpcklbw','vpunpckldq','vpunpcklqdq','vpunpcklwd','vpxor','vrcpps','vroundpd','vroundps','vrsqrtps','vshufpd','vshufps','vsqrtpd','vsqrtps','vsubpd','vsubps','vtestpd','vtestps','vunpckhpd','vunpckhps','vunpcklpd','vunpcklps','vxorpd','vxorps','vzeroall','vzeroupper'}
BASE_TARGETS = set(TARGETS)
MORE_TARGETS = {'vaddsd','vaddss','vbroadcastsd','vbroadcastss','vcmpsd','vcmpss','vcomisd','vcomiss','vcvtdq2pd','vcvtdq2ps','vcvtpd2dq','vcvtpd2ps','vcvtps2dq','vcvtps2pd','vcvtsd2ss','vcvtss2sd','vcvttpd2dq','vcvttps2dq','vdivsd','vdivss','vinsertps','vmaxsd','vmaxss','vminsd','vminss','vmovddup','vmulsd','vmulss','vphminposuw','vpmovsxbd','vpmovsxbq','vpmovsxbw','vpmovsxdq','vpmovsxwd','vpmovsxwq','vpmovzxbd','vpmovzxbq','vpmovzxbw','vpmovzxdq','vpmovzxwd','vpmovzxwq','vrcpss','vroundsd','vroundss','vrsqrtss','vsqrtsd','vsqrtss','vsubsd','vsubss','vucomisd','vucomiss','vpbroadcastb','vpbroadcastd','vpbroadcastq','vpbroadcastw','vfmadd132sd','vfmadd132ss','vfmadd213sd','vfmadd213ss','vfmadd231sd','vfmadd231ss','vfmsub132sd','vfmsub132ss','vfmsub213sd','vfmsub213ss','vfmsub231sd','vfmsub231ss','vfnmadd132sd','vfnmadd132ss','vfnmadd213sd','vfnmadd213ss','vfnmadd231sd','vfnmadd231ss','vfnmsub132sd','vfnmsub132ss','vfnmsub213sd','vfnmsub213ss','vfnmsub231sd','vfnmsub231ss'}
PHASE1_TARGETS = {'vmovd','vmovq'}
PHASE2_TARGETS = {'vpextrb','vpextrd','vpextrq','vpinsrb','vpinsrd','vpinsrq'}
PHASE3_TARGETS = {'vextractps','vmovmskpd','vmovmskps','vpextrw','vpinsrw','vpmovmskb','vcvtsd2si','vcvtsi2sd','vcvtsi2ss','vcvtss2si','vcvttsd2si','vcvttss2si'}
PHASE4_TARGETS = {'vmaskmovpd','vmaskmovps','vpmaskmovd','vpmaskmovq'}
PHASE5_TARGETS = {'vgatherdpd','vgatherdps','vgatherqpd','vgatherqps','vpgatherdd','vpgatherdq','vpgatherqd','vpgatherqq'}
PHASE6_TARGETS = {'vmovhlps','vmovhpd','vmovhps','vmovlhps','vmovlpd','vmovlps','vmovntdqa'}
PHASE7_TARGETS = {'vmovsd','vmovss'}
PHASE8_TARGETS = {'vldmxcsr','vstmxcsr'}
PHASE9_TARGETS = {'vblendvpd','vblendvps','vpblendvb'}
PHASE10_TARGETS = {'vpcmpestri','vpcmpestrm','vpcmpistri','vpcmpistrm'}
PHASE11_TARGETS = {'vmovupd','vmovups','vpabsd','vmaskmovdqu'}
KNOWN_SOURCE_FIXES = {
    ('vmovupd W:xy, xy/mxy', '[RM ] VEX.Lxy.NP.0F.WIG 10 /r'): '[RM ] VEX.Lxy.66.0F.WIG 10 /r',
    ('vmovupd W:xy/mxy, xy', '[MR ] VEX.Lxy.NP.0F.WIG 11 /r'): '[MR ] VEX.Lxy.66.0F.WIG 11 /r',
    ('vmovups W:xy, xy/mxy', '[RM ] VEX.Lxy.66.0F.WIG 10 /r'): '[RM ] VEX.Lxy.NP.0F.WIG 10 /r',
    ('vmovups W:xy/mxy, xy', '[MR ] VEX.Lxy.66.0F.WIG 11 /r'): '[MR ] VEX.Lxy.NP.0F.WIG 11 /r',
    ('vpabsd W:xmm, xmm/m128', '[RM_] VEX.128.66.0F38.WIG 1E /r'): '[RM ] VEX.128.66.0F38.WIG 1E /r',
}
TARGETS.update(MORE_TARGETS)
TARGETS.update(PHASE1_TARGETS)
TARGETS.update(PHASE2_TARGETS)
TARGETS.update(PHASE3_TARGETS)
TARGETS.update(PHASE4_TARGETS)
TARGETS.update(PHASE5_TARGETS)
TARGETS.update(PHASE6_TARGETS)
TARGETS.update(PHASE7_TARGETS)
TARGETS.update(PHASE8_TARGETS)
TARGETS.update(PHASE9_TARGETS)
TARGETS.update(PHASE10_TARGETS)
TARGETS.update(PHASE11_TARGETS)
EXTS = {'AVX':'aeAVX','AVX2':'aeAVX2','FMA':'aeFMA'}
TAG_ENUM = {'OP':'aefOP','RM':'aefRM','MR':'aefMR','RVM':'aefRVM','VM':'aefVM','MVR':'aefMVR','RMV':'aefRMV','M':'aefM','RVMS':'aefRVMS'}
MAP_ENUM = {'0f':'aom0F','0f38':'aom0F38','0f3a':'aom0F3A'}
REG_ENUM = {'xmm':'arcXmm','ymm':'arcYmm','r32':'arcGp32','r64':'arcGp64'}
MEM_ENUM = {'':'amcNone','m8':'amc8','m16':'amc16','m32':'amc32','m64':'amc64','m128':'amc128','m256':'amc256','vm32x':'amcVm32x','vm32y':'amcVm32y','vm64x':'amcVm64x','vm64y':'amcVm64y'}
KIND_REG = 1
KIND_MEM = 2
KIND_IMM = 4

@dataclass
class Operand:
    raw: str
    reg: str = ''
    mem: str = ''
    imm: int = 0

@dataclass
class Encoding:
    tag: str
    length: int
    pp: int
    opmap: str
    w: int
    opcode: int
    modrm: str
    imm_bytes: int
    modrm_fixed_reg: int
    is4: bool

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
    if m: s = m.group(1)
    if s.startswith('~'): s = s[1:]
    s = re.sub(r'\s*\{[^}]*\}', '', s)
    s = re.sub(r'\[[^]]+\]', '', s)
    return s.strip()


def parse_operand(text: str, width: int) -> Operand:
    s = normalize_atom(text)
    repl = {'xy':'xmm' if width == 128 else 'ymm', 'mxy':'m128' if width == 128 else 'm256'}
    for a, b in repl.items(): s = re.sub(rf'\b{a}\b', b, s)
    if '/' in s:
        a, b = s.split('/', 1)
        if a in REG_ENUM and b in ('m8','m16','m32','m64','m128','m256'): return Operand(text, a, b)
        raise ValueError(f'unsupported AVX operand {text!r}')
    if s in REG_ENUM: return Operand(text, reg=s)
    if s in ('m8','m16','m32','m64','m128','m256','vm32x','vm32y','vm64x','vm64y'): return Operand(text, mem=s)
    if s == 'imm8': return Operand(text, imm=1)
    raise ValueError(f'unsupported AVX operand {text!r}')


def parse_signature(sig: str, width: int) -> Tuple[str, List[Operand]]:
    body = sig.strip()
    if ' ' not in body: return body.lower(), []
    mnemonic, rest = body.split(None, 1)
    return mnemonic.lower(), [parse_operand(x, width) for x in rest.split(',') if not re.search(r'<[^>]+>', x)]


def parse_encoding(text: str, width: int) -> Encoding:
    m = re.match(r'^\[([A-Z ]+)\]\s*(VEX\.[^ ]+)\s+([0-9A-Fa-f]{2})(?:\s+(/r|/[0-7]))?(?:\s+(/is4))?(?:\s+(ib))?$', text.strip())
    if not m: raise ValueError(f'unsupported AVX encoding {text!r}')
    tag = m.group(1).replace(' ', '')
    if tag not in TAG_ENUM: raise ValueError(f'unsupported AVX tag {tag!r}')
    fields = m.group(2).split('.')
    if fields[0].upper() != 'VEX': raise ValueError(text)
    ltok, pptok, maptok, wtok = fields[1], fields[2].upper(), fields[3].lower(), fields[4].upper()
    if ltok.lower() == 'lxy': length = 0 if width == 128 else 1
    elif ltok.upper() in ('LIG', 'LZ'): length = 0
    elif ltok == '128': length = 0
    elif ltok == '256': length = 1
    else: raise ValueError(f'unsupported VEX length {ltok!r}')
    pp = {'NP':0,'66':1,'F3':2,'F2':3}[pptok]
    if maptok not in MAP_ENUM: raise ValueError(f'unsupported VEX map {maptok!r}')
    if wtok in ('WIG','W0'): w = 0
    elif wtok == 'W1': w = 1
    else: raise ValueError(f'unsupported VEX W field {wtok!r}')
    modrm = m.group(4) or ''
    fixed = int(modrm[1]) if len(modrm) == 2 and modrm[0] == '/' and modrm[1].isdigit() else -1
    return Encoding(tag, length, pp, maptok, w, int(m.group(3), 16), modrm, 1 if m.group(6) else 0, fixed, m.group(5) is not None)


def source_forms(db) -> List[Form]:
    out = []
    for selected in (BASE_TARGETS, MORE_TARGETS, PHASE1_TARGETS, PHASE2_TARGETS, PHASE3_TARGETS, PHASE4_TARGETS, PHASE5_TARGETS, PHASE6_TARGETS, PHASE7_TARGETS, PHASE8_TARGETS, PHASE9_TARGETS, PHASE10_TARGETS, PHASE11_TARGETS):
        for group in db['instructions']:
            ext = group.get('ext','')
            if ext not in EXTS: continue
            for rec in group.get('instructions',[]):
                sig = rec.get('x64') or rec.get('any')
                if not sig: continue
                mnemonic = sig.split(None,1)[0].lower()
                if mnemonic not in selected: continue
                source_op = KNOWN_SOURCE_FIXES.get((sig, rec['op']), rec['op'])
                variants = [(sig, source_op)]
                if re.search(r'\b(?:ry|my)\b', sig) or '.Wy ' in source_op:
                    if not (re.search(r'\b(?:ry|my)\b', sig) and '.Wy ' in source_op): raise ValueError(f'incomplete Wy form: {sig} / {source_op}')
                    variants = [(re.sub(r'\bry\b', 'r32', re.sub(r'\bmy\b', 'm32', sig)), source_op.replace('.Wy ', '.W0 ')), (re.sub(r'\bry\b', 'r64', re.sub(r'\bmy\b', 'm64', sig)), source_op.replace('.Wy ', '.W1 '))]
                for vsig, vop in variants:
                    widths = (128,256) if re.search(r'\bxy\b|\bmxy\b', vsig) else (256,) if re.search(r'\bymm\b|\bm256\b', vsig) else (128,)
                    for width in widths:
                        mnem, ops = parse_signature(vsig, width)
                        enc = parse_encoding(vop, width)
                        out.append(Form(ext, vsig, vop, mnem, ops, enc))
    return out


def binding(f: Form):
    if f.enc.tag == 'OP': return -1, -1, -1
    if f.enc.tag == 'RVM': return (0, 1, -1) if len(f.operands) == 2 else (0, 2, 1)
    if f.enc.tag == 'RM': return 0, 1, -1
    if f.enc.tag == 'MR': return 1, 0, -1
    if f.enc.tag == 'VM': return -1, 1, 0
    if f.enc.tag == 'MVR': return 2, 0, 1
    if f.enc.tag == 'RMV': return 0, 1, 2
    if f.enc.tag == 'M': return -1, 0, -1
    if f.enc.tag == 'RVMS': return 0, 2, 1
    raise ValueError(f.enc.tag)


def passtr(s: str) -> str:
    return "'" + s.replace("'", "''") + "'"


def render_db(forms: List[Form], sha: str):
    base_mnems = sorted(set(f.mnemonic for f in forms if f.mnemonic in BASE_TARGETS))
    more_mnems = sorted(set(f.mnemonic for f in forms if f.mnemonic in MORE_TARGETS and f.mnemonic not in BASE_TARGETS))
    phase1_mnems = sorted(set(f.mnemonic for f in forms if f.mnemonic in PHASE1_TARGETS and f.mnemonic not in BASE_TARGETS and f.mnemonic not in MORE_TARGETS))
    phase2_mnems = sorted(set(f.mnemonic for f in forms if f.mnemonic in PHASE2_TARGETS and f.mnemonic not in BASE_TARGETS and f.mnemonic not in MORE_TARGETS and f.mnemonic not in PHASE1_TARGETS))
    phase3_mnems = sorted(set(f.mnemonic for f in forms if f.mnemonic in PHASE3_TARGETS and f.mnemonic not in BASE_TARGETS and f.mnemonic not in MORE_TARGETS and f.mnemonic not in PHASE1_TARGETS and f.mnemonic not in PHASE2_TARGETS))
    phase4_mnems = sorted(set(f.mnemonic for f in forms if f.mnemonic in PHASE4_TARGETS and f.mnemonic not in BASE_TARGETS and f.mnemonic not in MORE_TARGETS and f.mnemonic not in PHASE1_TARGETS and f.mnemonic not in PHASE2_TARGETS and f.mnemonic not in PHASE3_TARGETS))
    phase5_mnems = sorted(set(f.mnemonic for f in forms if f.mnemonic in PHASE5_TARGETS and f.mnemonic not in BASE_TARGETS and f.mnemonic not in MORE_TARGETS and f.mnemonic not in PHASE1_TARGETS and f.mnemonic not in PHASE2_TARGETS and f.mnemonic not in PHASE3_TARGETS and f.mnemonic not in PHASE4_TARGETS))
    phase6_mnems = sorted(set(f.mnemonic for f in forms if f.mnemonic in PHASE6_TARGETS and f.mnemonic not in BASE_TARGETS and f.mnemonic not in MORE_TARGETS and f.mnemonic not in PHASE1_TARGETS and f.mnemonic not in PHASE2_TARGETS and f.mnemonic not in PHASE3_TARGETS and f.mnemonic not in PHASE4_TARGETS and f.mnemonic not in PHASE5_TARGETS))
    phase7_mnems = sorted(set(f.mnemonic for f in forms if f.mnemonic in PHASE7_TARGETS and f.mnemonic not in BASE_TARGETS and f.mnemonic not in MORE_TARGETS and f.mnemonic not in PHASE1_TARGETS and f.mnemonic not in PHASE2_TARGETS and f.mnemonic not in PHASE3_TARGETS and f.mnemonic not in PHASE4_TARGETS and f.mnemonic not in PHASE5_TARGETS and f.mnemonic not in PHASE6_TARGETS))
    phase8_mnems = sorted(set(f.mnemonic for f in forms if f.mnemonic in PHASE8_TARGETS and f.mnemonic not in BASE_TARGETS and f.mnemonic not in MORE_TARGETS and f.mnemonic not in PHASE1_TARGETS and f.mnemonic not in PHASE2_TARGETS and f.mnemonic not in PHASE3_TARGETS and f.mnemonic not in PHASE4_TARGETS and f.mnemonic not in PHASE5_TARGETS and f.mnemonic not in PHASE6_TARGETS and f.mnemonic not in PHASE7_TARGETS))
    phase9_mnems = sorted(set(f.mnemonic for f in forms if f.mnemonic in PHASE9_TARGETS))
    phase10_mnems = sorted(set(f.mnemonic for f in forms if f.mnemonic in PHASE10_TARGETS))
    phase11_mnems = sorted(set(f.mnemonic for f in forms if f.mnemonic in PHASE11_TARGETS))
    mnems = base_mnems + more_mnems + phase1_mnems + phase2_mnems + phase3_mnems + phase4_mnems + phase5_mnems + phase6_mnems + phase7_mnems + phase8_mnems + phase9_mnems + phase10_mnems + phase11_mnems
    mi = {m:i for i,m in enumerate(mnems)}
    lookup_order = sorted(range(len(mnems)), key=lambda i: mnems[i])
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
    lines = ['unit NativeAsm.Avx.Db.Generated;','','interface','','uses','  NativeAsm.Avx.Db;','','const',f"  CAvxDbSourceSha256 = '{sha}';",f'  CAvxMnemonicCount = {len(mnems)};',f'  CAvxFormCount = {len(forms)};',f'  CAvxOperandCount = {len(ops)};','']
    def arr(name, typ, vals, fmt=str):
        lines.append(f'  {name}: array[0..{len(vals)-1}] of {typ} = (')
        for i,v in enumerate(vals): lines.append(f'    {fmt(v)}{"," if i+1 < len(vals) else ""}')
        lines.append('  );')
        lines.append('')
    arr('CAvxMnemonicNames','string',mnems,passtr)
    arr('CAvxMnemonicLookupOrder','Word',lookup_order)
    arr('CAvxMnemonicFormStart','Word',starts)
    arr('CAvxMnemonicFormCount','Word',counts)
    arr('CAvxFormOrder','Word',order)
    arr('CAvxSourceSignatures','string',[f.signature for f in forms],passtr)
    arr('CAvxSourceEncodings','string',[f.optext for f in forms],passtr)
    lines.append(f'  CAvxOperands: array[0..{len(ops)-1}] of TAvxDbOperandSpec = (')
    for i,o in enumerate(ops):
        kinds = (KIND_REG if o.reg else 0) | (KIND_MEM if o.mem else 0)
        kinds |= KIND_IMM if o.imm else 0
        rec = f'(Kinds:${kinds:02X}; RegClass:{REG_ENUM.get(o.reg,"arcNone")}; MemClass:{MEM_ENUM[o.mem]}; ImmBytes:{o.imm})'
        lines.append(f'    {rec}{"," if i+1 < len(ops) else ""}')
    lines.append('  );')
    lines.append('')
    lines.append(f'  CAvxForms: array[0..{len(forms)-1}] of TAvxEncodingDescriptor = (')
    for i,f in enumerate(forms):
        regidx, rmidx, vvidx = binding(f)
        immidx = next((j for j,o in enumerate(f.operands) if o.imm), -1)
        if f.enc.is4:
            if (f.enc.tag != 'RVMS') or (len(f.operands) != 4) or (immidx >= 0): raise ValueError(f'invalid /is4 form: {f.signature} / {f.optext}')
            immidx = 3
        elif f.enc.imm_bytes != (1 if immidx >= 0 else 0): raise ValueError(f'immediate encoding mismatch: {f.signature} / {f.optext}')
        rec = f'(MnemonicIndex:{mi[f.mnemonic]}; Extension:{EXTS[f.ext]}; FormTag:{TAG_ENUM[f.enc.tag]}; VexL:{f.enc.length}; VexPP:{f.enc.pp}; VexW:{f.enc.w}; OpcodeMap:{MAP_ENUM[f.enc.opmap]}; Opcode:${f.enc.opcode:02X}; ModRegOperandIdx:{regidx}; ModRegFixed:{f.enc.modrm_fixed_reg}; ModRmOperandIdx:{rmidx}; VvvvOperandIdx:{vvidx}; ImmediateOperandIdx:{immidx}; OperandStart:{opstarts[i]}; OperandCount:{len(f.operands)})'
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
            args = '; '.join(f'A{i}: TAvxOperand' for i in range(arity))
            overload = '; overload;' if len(arities[m]) > 1 else ';'
            decl.append((f'    function {name}({args}): TAsmBuilder' if arity else f'    function {name}: TAsmBuilder') + overload)
            impl.append(f'function TAsmAvxHelper.{name}({args}): TAsmBuilder;' if arity else f'function TAsmAvxHelper.{name}: TAsmBuilder;')
            impl.append('begin')
            vals = ', '.join(f'A{i}' for i in range(arity))
            impl.append(f"  Result := Avx('{m}', [{vals}]);" if arity else f"  Result := Avx('{m}', []);")
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
    report = {'source_sha256':hashlib.sha256(raw).hexdigest(),'forms':len(forms),'mnemonics':len(mnems),'extensions':{e:sum(1 for f in forms if f.ext == e) for e in EXTS},'immediate_forms':sum(1 for f in forms if f.enc.imm_bytes),'selected_mnemonics':mnems}
    Path(a.report).write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(report, indent=2))

if __name__ == '__main__': main()
