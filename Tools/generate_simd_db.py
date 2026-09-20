#!/usr/bin/env python3
from __future__ import annotations
import argparse, hashlib, json, re
from dataclasses import dataclass, replace
from pathlib import Path
from typing import List, Tuple

EXTS = ('SSE','SSE2','SSE3','SSSE3','SSE4_1','SSE4_2','SSE4A','AESNI','SHA','LZCNT','BMI','PCLMULQDQ')
SCALAR_FILTER = {'LZCNT': {'lzcnt'}, 'BMI': {'tzcnt'}}
SIMD_API_EXTS = {'SSE','SSE2','SSE3','SSSE3','SSE4_1','SSE4_2','SSE4A','AESNI','SHA','PCLMULQDQ'}
EXT_ENUM = {x:'se'+x.replace('_','') for x in EXTS}
TAG_ENUM = {'':'sefNone','OP':'sefOP','RM':'sefRM','MR':'sefMR','M':'sefM','R':'sefR'}
MAP_ENUM = {'primary':'somPrimary','0f':'som0F','0f38':'som0F38','0f3a':'som0F3A'}
REG_ENUM = {'':'srcNone','xmm':'srcXmm','mm':'srcMm','r8':'srcGp8','r16':'srcGp16','r32':'srcGp32','r64':'srcGp64'}
MEM_ENUM = {'':'smcNone','mem':'smcAny','m8':'smc8','m16':'smc16','m32':'smc32','m64':'smc64','m128':'smc128'}
KIND_REG=1; KIND_MEM=2; KIND_IMM=4

@dataclass
class Operand:
    raw:str
    reg:str=''
    mem:str=''
    imm_bytes:int=0
    implicit:bool=False
    fixed_reg:str=''

@dataclass
class Encoding:
    tag:str=''
    prefix1:int=0
    prefix2:int=0
    rexw:bool=False
    opmap:str='primary'
    opcode:int=0
    modrm:str=''
    fixed_modrm:int=-1
    imm_codes:Tuple[int,...]=()

@dataclass
class Form:
    ext:str
    signature:str
    optext:str
    mnemonic:str
    operands:List[Operand]
    enc:Encoding
    width:int=0


def strip_options(sig:str)->str:
    if sig.startswith('['):
        p=sig.find(']')
        if p<0: raise ValueError(sig)
        return sig[p+1:].strip()
    return sig.strip()

def normalize_atom(s:str)->str:
    s=s.strip()
    s=re.sub(r'\[[0-9]+(?::[0-9]+)?\]$','',s)
    s=re.sub(r'\([^)]*\)$','',s)
    return s

def parse_operand(text:str)->Operand:
    raw=text.strip(); s=raw
    m=re.match(r'^[RWXwx](?:\?)?:(.*)$',s)
    if m: s=m.group(1)
    if s.startswith('~'): s=s[1:]
    implicit=s.startswith('<') and s.endswith('>')
    if implicit: s=s[1:-1]
    s=normalize_atom(s)
    if s=='imm8': return Operand(raw,imm_bytes=1,implicit=implicit)
    if '/' in s:
        a,b=s.split('/',1); a=normalize_atom(a); b=normalize_atom(b)
        if a in ('xmm','mm','r8','r16','r32','r64','ry','rv') and b in ('m8','m16','m32','m64','m128','my','mv','mem'):
            return Operand(raw,reg=a,mem=b,implicit=implicit)
        raise ValueError(f'unsupported union {raw!r}')
    if s in ('xmm','mm','r8','r16','r32','r64','ry','rv'):
        return Operand(raw,reg=s,implicit=implicit)
    if s in ('m8','m16','m32','m64','m128','my','mv','mem'):
        return Operand(raw,mem=s,implicit=implicit)
    if s in ('xmm0','eax','ecx','edx'):
        return Operand(raw,implicit=implicit,fixed_reg=s)
    raise ValueError(f'unsupported operand {raw!r} -> {s!r}')

def parse_signature(sig:str):
    body=strip_options(sig)
    if ' ' not in body: return body.lower(),[]
    mnemonic,rest=body.split(None,1)
    return mnemonic.lower(),[parse_operand(x) for x in rest.split(',')]

def parse_encoding(text:str)->Encoding:
    s=text.strip(); tag=''
    m=re.match(r'^\[([A-Z ]+)\]\s*(.*)$',s)
    if m:
        tag=m.group(1).replace(' ',''); s=m.group(2).strip()
    if tag not in TAG_ENUM: raise ValueError(f'tag {tag!r} in {text!r}')
    prefixes=[]; rexw=False; modrm=''; hexbytes=[]; imms=[]
    for tok in s.split():
        u=tok.upper()
        if u=='NP': continue
        if u=='REX.W': rexw=True; continue
        if tok in ('66','F2','F3') and not hexbytes:
            b=int(tok,16)
            if b not in prefixes: prefixes.append(b)
            continue
        if re.fullmatch(r'/[0-7r]',tok): modrm=tok; continue
        if tok=='ib': imms.append(1); continue
        if re.fullmatch(r'[0-9A-Fa-f]{2}',tok): hexbytes.append(int(tok,16)); continue
        raise ValueError(f'unsupported encoding token {tok!r} in {text!r}')
    if not hexbytes: raise ValueError(f'no opcode in {text!r}')
    if hexbytes[0]==0x0F:
        if len(hexbytes)>=2 and hexbytes[1] in (0x38,0x3A):
            opmap='0f38' if hexbytes[1]==0x38 else '0f3a'; payload=hexbytes[2:]
        else: opmap='0f'; payload=hexbytes[1:]
    else: opmap='primary'; payload=hexbytes
    if not payload: raise ValueError(text)
    opcode=payload[0]; fixed=-1
    if len(payload)>1:
        if len(payload)!=2 or modrm: raise ValueError(f'extra opcode bytes {payload} in {text!r}')
        fixed=payload[1]
    return Encoding(tag,prefixes[0] if prefixes else 0,prefixes[1] if len(prefixes)>1 else 0,rexw,opmap,opcode,modrm,fixed,tuple(imms))

def needs_y(ops): return any(o.reg=='ry' or o.mem=='my' for o in ops)
def needs_v(ops): return any(o.reg=='rv' or o.mem=='mv' for o in ops)
def expand_operand(o:Operand,width:int)->Operand:
    x=replace(o)
    if x.reg=='ry': x.reg='r32' if width==32 else 'r64'
    if x.mem=='my': x.mem='m32' if width==32 else 'm64'
    if x.reg=='rv': x.reg={16:'r16',32:'r32',64:'r64'}[width]
    if x.mem=='mv': x.mem={16:'m16',32:'m32',64:'m64'}[width]
    return x

def add_prefix(e:Encoding,b:int)->Encoding:
    if e.prefix1==b or e.prefix2==b: return e
    if e.prefix1==0: return replace(e,prefix1=b)
    if e.prefix2==0: return replace(e,prefix2=b)
    raise ValueError('too many legacy prefixes')

def source_forms(db)->List[Form]:
    out=[]
    for group in db['instructions']:
        ext=group.get('ext','')
        if ext not in EXTS: continue
        for rec in group.get('instructions',[]):
            sig=rec.get('x64') or rec.get('any')
            if not sig: continue
            mnem,ops=parse_signature(sig)
            if ext in SCALAR_FILTER and mnem not in SCALAR_FILTER[ext]: continue
            enc=parse_encoding(rec.get('op',''))
            if needs_v(ops): widths=(16,32,64)
            elif needs_y(ops): widths=(32,64)
            else: widths=(0,)
            for w in widths:
                e=replace(enc)
                if w==16: e=add_prefix(e,0x66)
                if w==64: e.rexw=True
                out.append(Form(ext,sig,rec.get('op',''),mnem,[expand_operand(o,w) for o in ops],e,w))
    return out

def encoded_candidates(f:Form):
    return [i for i,o in enumerate(f.operands) if not o.implicit and (o.reg or o.mem or o.fixed_reg)]

def can_reg(o:Operand): return bool(o.reg or o.fixed_reg)
def can_rm(o:Operand): return bool(o.reg or o.mem or o.fixed_reg)

def modrm_binding(f:Form):
    e=f.enc
    if e.fixed_modrm>=0: return 'smkFixedByte',-1,-1,0,e.fixed_modrm
    if not e.modrm: return 'smkNone',-1,-1,0,0
    c=encoded_candidates(f)
    if e.modrm!='/r':
        if not c: raise ValueError(f'no r/m operand: {f.signature}')
        return 'smkFixedReg',-1,c[0],int(e.modrm[1]),0
    if len(c)<2: raise ValueError(f'/r requires two encoded operands: {f.signature}')
    a,b=c[0],c[1]
    preferred=(a,b) if e.tag=='RM' else (b,a) if e.tag=='MR' else (a,b)
    reg,rm=preferred
    if not can_reg(f.operands[reg]) or not can_rm(f.operands[rm]): reg,rm=rm,reg
    if not can_reg(f.operands[reg]) or not can_rm(f.operands[rm]): raise ValueError(f'cannot bind /r: {f.signature}')
    return 'smkOperands',reg,rm,0,0

def explicit_count(f): return sum(1 for o in f.operands if not o.implicit)

def passtr(s): return "'"+s.replace("'","''")+"'"

def render_db(forms,sha):
    mnems=sorted(set(f.mnemonic for f in forms)); mi={m:i for i,m in enumerate(mnems)}
    order=[]; starts=[]; counts=[]
    for m in mnems:
        starts.append(len(order)); ids=[i for i,f in enumerate(forms) if f.mnemonic==m]; counts.append(len(ids)); order.extend(ids)
    ops=[]; opstarts=[]
    for f in forms: opstarts.append(len(ops)); ops.extend(f.operands)
    lines=['unit NativeAsm.Simd.Db.Generated;','','interface','','uses','  NativeAsm.Simd.Types,','  NativeAsm.Simd.Db;','','const',f"  CSimdDbSourceSha256 = '{sha}';",f'  CSimdMnemonicCount = {len(mnems)};',f'  CSimdFormCount = {len(forms)};',f'  CSimdOperandCount = {len(ops)};','']
    def arr(name,typ,vals,fmt=str):
        lines.append(f'  {name}: array[0..{len(vals)-1}] of {typ} = (')
        for i,v in enumerate(vals): lines.append(f'    {fmt(v)}{"," if i+1<len(vals) else ""}')
        lines.append('  );'); lines.append('')
    arr('CSimdMnemonicNames','string',mnems,passtr)
    arr('CSimdMnemonicFormStart','Word',starts)
    arr('CSimdMnemonicFormCount','Word',counts)
    arr('CSimdFormOrder','Word',order)
    arr('CSimdSourceSignatures','string',[f.signature for f in forms],passtr)
    arr('CSimdSourceEncodings','string',[f.optext for f in forms],passtr)
    lines.append(f'  CSimdOperands: array[0..{len(ops)-1}] of TSimdDbOperandSpec = (')
    for i,o in enumerate(ops):
        kinds=0
        if o.reg or o.fixed_reg: kinds|=KIND_REG
        if o.mem: kinds|=KIND_MEM
        if o.imm_bytes: kinds|=KIND_IMM
        reg=o.reg
        fixedkind='sfkNone'; fixedid=0
        if o.fixed_reg:
            if o.fixed_reg=='xmm0': fixedkind='sfkXmm'; fixedid=0
            else: fixedkind='sfkGp'; fixedid={'eax':0,'ecx':1,'edx':2}[o.fixed_reg]
            if not reg: reg='xmm' if o.fixed_reg=='xmm0' else 'r32'
        rec=f'(Kinds:${kinds:02X}; RegClass:{REG_ENUM[reg]}; MemClass:{MEM_ENUM[o.mem]}; ImmBytes:{o.imm_bytes}; Implicit:{str(o.implicit).lower()}; FixedKind:{fixedkind}; FixedID:{fixedid})'
        lines.append(f'    {rec}{"," if i+1<len(ops) else ""}')
    lines.append('  );'); lines.append('')
    lines.append(f'  CSimdForms: array[0..{len(forms)-1}] of TSimdEncodingDescriptor = (')
    for i,f in enumerate(forms):
        mk,regidx,rmidx,freg,fbyte=modrm_binding(f)
        immidx=[j for j,o in enumerate(f.operands) if not o.implicit and o.imm_bytes]
        if len(immidx)>2: raise ValueError(f'too many immediates {f.signature}')
        i0=immidx[0] if immidx else -1; i1=immidx[1] if len(immidx)>1 else -1
        rec=(f'(MnemonicIndex:{mi[f.mnemonic]}; Extension:{EXT_ENUM[f.ext]}; FormTag:{TAG_ENUM[f.enc.tag]}; '
             f'Prefix1:${f.enc.prefix1:02X}; Prefix2:${f.enc.prefix2:02X}; RexW:{str(f.enc.rexw).lower()}; OpcodeMap:{MAP_ENUM[f.enc.opmap]}; Opcode:${f.enc.opcode:02X}; '
             f'ModRMKind:{mk}; ModRegOperandIdx:{regidx}; ModRmOperandIdx:{rmidx}; FixedRegValue:{freg}; FixedModRMByte:${fbyte:02X}; '
             f'Immediate0OperandIdx:{i0}; Immediate1OperandIdx:{i1}; OperandStart:{opstarts[i]}; OperandCount:{len(f.operands)}; ExplicitOperandCount:{explicit_count(f)})')
        lines.append(f'    {rec}{"," if i+1<len(forms) else ""}')
    lines += ['  );','','implementation','','end.','']
    return '\n'.join(lines),mnems

def render_api(forms,mnems):
    arities={m:set() for m in mnems}
    api_mnems=set()
    for f in forms:
        arities[f.mnemonic].add(explicit_count(f))
        if f.ext in SIMD_API_EXTS: api_mnems.add(f.mnemonic)
    skip={'lfence','mfence','sfence'}
    decl=[]; impl=[]
    for m in mnems:
        if m in skip or m not in api_mnems: continue
        name=m[0].upper()+m[1:]
        for arity in sorted(arities[m]):
            args='; '.join(f'A{i}: TSimdOperand' for i in range(arity))
            ov='overload' if len(arities[m])>1 else ''
            decl.append((f'    function {name}({args}): TAsmBuilder;' if arity else f'    function {name}: TAsmBuilder;') + (f' {ov};' if ov else ''))
            sig=f'function TAsmSimdHelper.{name}({args}): TAsmBuilder;' if arity else f'function TAsmSimdHelper.{name}: TAsmBuilder;'
            vals=', '.join(f'A{i}' for i in range(arity))
            impl += [sig,'begin',f"  Result := Simd('{m}', [{vals}]);" if arity else f"  Result := Simd('{m}', []);",'end;','']
    return '\n'.join(decl), '\n'.join(impl)

def main():
    ap=argparse.ArgumentParser(); ap.add_argument('--input',required=True); ap.add_argument('--output',required=True); ap.add_argument('--decl-output',required=True); ap.add_argument('--impl-output',required=True); ap.add_argument('--report',required=True)
    a=ap.parse_args(); raw=Path(a.input).read_bytes(); db=json.loads(raw.decode()); forms=source_forms(db); text,mnems=render_db(forms,hashlib.sha256(raw).hexdigest()); decl,impl=render_api(forms,mnems)
    Path(a.output).write_text(text,encoding='utf-8',newline='\n'); Path(a.decl_output).write_text(decl+'\n',encoding='utf-8',newline='\n'); Path(a.impl_output).write_text(impl,encoding='utf-8',newline='\n')
    rep={'source_sha256':hashlib.sha256(raw).hexdigest(),'expanded_forms':len(forms),'mnemonics':len(mnems),'extensions':{e:sum(1 for f in forms if f.ext==e) for e in EXTS}}
    Path(a.report).write_text(json.dumps(rep,indent=2)+'\n'); print(json.dumps(rep,indent=2))
if __name__=='__main__': main()
