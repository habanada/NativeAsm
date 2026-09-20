{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }program NativeAsmEncodingTests;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  NativeAsm.Types,
  NativeAsm.Builder,
  NativeAsm.InstructionDB;

var
  GPass, GFail: Integer;

procedure CheckEnc(const Desc: string; B: TAsmBuilder;
  const Expected: array of Byte);
var
  Actual: TBytes;
  I: Integer;
  OK: Boolean;
  Got, Exp: string;
begin
  try
    try
      Actual := B.Build;
    finally
      B.Free;
    end;
  except
    on E: Exception do
    begin
      Inc(GFail);
      Writeln(Format('FAIL [exception] %s: %s: %s', [Desc, E.ClassName, E.Message]));
      Exit;
    end;
  end;
  OK := Length(Actual) = Length(Expected);
  if OK then
    for I := 0 to High(Expected) do
      if Actual[I] <> Expected[I] then
      begin
        OK := False;
        Break;
      end;
  if OK then
    Inc(GPass)
  else
  begin
    Inc(GFail);
    Got := '';
    for I := 0 to High(Actual) do
    begin
      if I > 0 then Got := Got + ',';
      Got := Got + Format('$%.2X', [Actual[I]]);
    end;
    Exp := '';
    for I := 0 to High(Expected) do
    begin
      if I > 0 then Exp := Exp + ',';
      Exp := Exp + Format('$%.2X', [Expected[I]]);
    end;
    Writeln(Format('FAIL %s: got [%s] expected [%s]', [Desc, Got, Exp]));
  end;
end;

procedure TestAdd;
begin
  CheckEnc('add cl,dl',
    TAsmBuilder.New.Add(CL, DL),
    [$02, $CA]);
  CheckEnc('add bl,ah',
    TAsmBuilder.New.Add(BL, AH),
    [$02, $DC]);
  CheckEnc('add dl,ch',
    TAsmBuilder.New.Add(DL, CH),
    [$02, $D5]);
  CheckEnc('add cx,dx',
    TAsmBuilder.New.Add(CX, DX),
    [$66, $03, $CA]);
  CheckEnc('add ecx,edx',
    TAsmBuilder.New.Add(ECX, EDX),
    [$03, $CA]);
  CheckEnc('add rcx,rdx',
    TAsmBuilder.New.Add(RCX, RDX),
    [$48, $03, $CA]);
  CheckEnc('add [rcx],dl',
    TAsmBuilder.New.Add(BytePtr(ridRCX), DL),
    [$00, $11]);
  CheckEnc('add [rcx],cl',
    TAsmBuilder.New.Add(BytePtr(ridRCX), CL),
    [$00, $09]);
  CheckEnc('add [rcx],cx',
    TAsmBuilder.New.Add(WordPtr(ridRCX), CX),
    [$66, $01, $09]);
  CheckEnc('add [rcx],ecx',
    TAsmBuilder.New.Add(DWordPtr(ridRCX), ECX),
    [$01, $09]);
  CheckEnc('add [rcx],rcx',
    TAsmBuilder.New.Add(QWordPtr(ridRCX), RCX),
    [$48, $01, $09]);
  CheckEnc('add cl,1',
    TAsmBuilder.New.Add(CL, 1),
    [$80, $C1, $01]);
  CheckEnc('add ecx,1',
    TAsmBuilder.New.Add(ECX, 1),
    [$83, $C1, $01]);
  CheckEnc('add rcx,1',
    TAsmBuilder.New.Add(RCX, 1),
    [$48, $83, $C1, $01]);
  CheckEnc('add rax,imm32',
    TAsmBuilder.New.Add(RAX, $12345678),
    [$48, $05, $78, $56, $34, $12]);
  CheckEnc('add ecx,imm32',
    TAsmBuilder.New.Add(ECX, $12345678),
    [$81, $C1, $78, $56, $34, $12]);
  CheckEnc('add [rcx],byte 1',
    TAsmBuilder.New.Add(BytePtr(ridRCX), 1),
    [$80, $01, $01]);
  CheckEnc('add [rcx],dword 1',
    TAsmBuilder.New.Add(DWordPtr(ridRCX), 1),
    [$83, $01, $01]);
end;

procedure TestOr;
begin
  CheckEnc('or cl,dl',
    TAsmBuilder.New.Or_(CL, DL),
    [$0A, $CA]);
  CheckEnc('or cx,dx',
    TAsmBuilder.New.Or_(CX, DX),
    [$66, $0B, $CA]);
  CheckEnc('or ecx,edx',
    TAsmBuilder.New.Or_(ECX, EDX),
    [$0B, $CA]);
  CheckEnc('or rcx,rdx',
    TAsmBuilder.New.Or_(RCX, RDX),
    [$48, $0B, $CA]);
  CheckEnc('or [rcx],cl',
    TAsmBuilder.New.Or_(BytePtr(ridRCX), CL),
    [$08, $09]);
  CheckEnc('or [rcx],ecx',
    TAsmBuilder.New.Or_(DWordPtr(ridRCX), ECX),
    [$09, $09]);
  CheckEnc('or [rcx],rcx',
    TAsmBuilder.New.Or_(QWordPtr(ridRCX), RCX),
    [$48, $09, $09]);
  CheckEnc('or cl,1',
    TAsmBuilder.New.Or_(CL, 1),
    [$80, $C9, $01]);
  CheckEnc('or ecx,1',
    TAsmBuilder.New.Or_(ECX, 1),
    [$83, $C9, $01]);
  CheckEnc('or rcx,1',
    TAsmBuilder.New.Or_(RCX, 1),
    [$48, $83, $C9, $01]);
  CheckEnc('or ecx,imm32',
    TAsmBuilder.New.Or_(ECX, $12345678),
    [$81, $C9, $78, $56, $34, $12]);
end;

procedure TestAnd;
begin
  CheckEnc('and cl,dl',
    TAsmBuilder.New.And_(CL, DL),
    [$22, $CA]);
  CheckEnc('and cx,dx',
    TAsmBuilder.New.And_(CX, DX),
    [$66, $23, $CA]);
  CheckEnc('and ecx,edx',
    TAsmBuilder.New.And_(ECX, EDX),
    [$23, $CA]);
  CheckEnc('and rcx,rdx',
    TAsmBuilder.New.And_(RCX, RDX),
    [$48, $23, $CA]);
  CheckEnc('and [rcx],cl',
    TAsmBuilder.New.And_(BytePtr(ridRCX), CL),
    [$20, $09]);
  CheckEnc('and [rcx],ecx',
    TAsmBuilder.New.And_(DWordPtr(ridRCX), ECX),
    [$21, $09]);
  CheckEnc('and [rcx],rcx',
    TAsmBuilder.New.And_(QWordPtr(ridRCX), RCX),
    [$48, $21, $09]);
  CheckEnc('and cl,1',
    TAsmBuilder.New.And_(CL, 1),
    [$80, $E1, $01]);
  CheckEnc('and ecx,1',
    TAsmBuilder.New.And_(ECX, 1),
    [$83, $E1, $01]);
  CheckEnc('and rcx,1',
    TAsmBuilder.New.And_(RCX, 1),
    [$48, $83, $E1, $01]);
  CheckEnc('and ecx,imm32',
    TAsmBuilder.New.And_(ECX, $12345678),
    [$81, $E1, $78, $56, $34, $12]);
end;

procedure TestSub;
begin
  CheckEnc('sub cl,dl',
    TAsmBuilder.New.Sub(CL, DL),
    [$2A, $CA]);
  CheckEnc('sub cx,dx',
    TAsmBuilder.New.Sub(CX, DX),
    [$66, $2B, $CA]);
  CheckEnc('sub ecx,edx',
    TAsmBuilder.New.Sub(ECX, EDX),
    [$2B, $CA]);
  CheckEnc('sub rcx,rdx',
    TAsmBuilder.New.Sub(RCX, RDX),
    [$48, $2B, $CA]);
  CheckEnc('sub [rcx],cl',
    TAsmBuilder.New.Sub(BytePtr(ridRCX), CL),
    [$28, $09]);
  CheckEnc('sub [rcx],ecx',
    TAsmBuilder.New.Sub(DWordPtr(ridRCX), ECX),
    [$29, $09]);
  CheckEnc('sub [rcx],rcx',
    TAsmBuilder.New.Sub(QWordPtr(ridRCX), RCX),
    [$48, $29, $09]);
  CheckEnc('sub cl,1',
    TAsmBuilder.New.Sub(CL, 1),
    [$80, $E9, $01]);
  CheckEnc('sub ecx,1',
    TAsmBuilder.New.Sub(ECX, 1),
    [$83, $E9, $01]);
  CheckEnc('sub rcx,1',
    TAsmBuilder.New.Sub(RCX, 1),
    [$48, $83, $E9, $01]);
  CheckEnc('sub ecx,imm32',
    TAsmBuilder.New.Sub(ECX, $12345678),
    [$81, $E9, $78, $56, $34, $12]);
end;

procedure TestXor;
begin
  CheckEnc('xor cl,dl',
    TAsmBuilder.New.Xor_(CL, DL),
    [$32, $CA]);
  CheckEnc('xor cx,dx',
    TAsmBuilder.New.Xor_(CX, DX),
    [$66, $33, $CA]);
  CheckEnc('xor ecx,edx',
    TAsmBuilder.New.Xor_(ECX, EDX),
    [$33, $CA]);
  CheckEnc('xor rcx,rdx',
    TAsmBuilder.New.Xor_(RCX, RDX),
    [$48, $33, $CA]);
  CheckEnc('xor [rcx],cl',
    TAsmBuilder.New.Xor_(BytePtr(ridRCX), CL),
    [$30, $09]);
  CheckEnc('xor [rcx],ecx',
    TAsmBuilder.New.Xor_(DWordPtr(ridRCX), ECX),
    [$31, $09]);
  CheckEnc('xor [rcx],rcx',
    TAsmBuilder.New.Xor_(QWordPtr(ridRCX), RCX),
    [$48, $31, $09]);
  CheckEnc('xor cl,1',
    TAsmBuilder.New.Xor_(CL, 1),
    [$80, $F1, $01]);
  CheckEnc('xor ecx,1',
    TAsmBuilder.New.Xor_(ECX, 1),
    [$83, $F1, $01]);
  CheckEnc('xor rcx,1',
    TAsmBuilder.New.Xor_(RCX, 1),
    [$48, $83, $F1, $01]);
  CheckEnc('xor ecx,imm32',
    TAsmBuilder.New.Xor_(ECX, $12345678),
    [$81, $F1, $78, $56, $34, $12]);
end;

procedure TestCmp;
begin
  CheckEnc('cmp cl,dl',
    TAsmBuilder.New.Cmp(CL, DL),
    [$3A, $CA]);
  CheckEnc('cmp cx,dx',
    TAsmBuilder.New.Cmp(CX, DX),
    [$66, $3B, $CA]);
  CheckEnc('cmp ecx,edx',
    TAsmBuilder.New.Cmp(ECX, EDX),
    [$3B, $CA]);
  CheckEnc('cmp rcx,rdx',
    TAsmBuilder.New.Cmp(RCX, RDX),
    [$48, $3B, $CA]);
  CheckEnc('cmp [rcx],cl',
    TAsmBuilder.New.Cmp(BytePtr(ridRCX), CL),
    [$38, $09]);
  CheckEnc('cmp [rcx],ecx',
    TAsmBuilder.New.Cmp(DWordPtr(ridRCX), ECX),
    [$39, $09]);
  CheckEnc('cmp [rcx],rcx',
    TAsmBuilder.New.Cmp(QWordPtr(ridRCX), RCX),
    [$48, $39, $09]);
  CheckEnc('cmp cl,1',
    TAsmBuilder.New.Cmp(CL, 1),
    [$80, $F9, $01]);
  CheckEnc('cmp ecx,1',
    TAsmBuilder.New.Cmp(ECX, 1),
    [$83, $F9, $01]);
  CheckEnc('cmp rcx,1',
    TAsmBuilder.New.Cmp(RCX, 1),
    [$48, $83, $F9, $01]);
  CheckEnc('cmp ecx,imm32',
    TAsmBuilder.New.Cmp(ECX, $12345678),
    [$81, $F9, $78, $56, $34, $12]);
end;

procedure TestMov;
begin
  CheckEnc('mov cl,dl',
    TAsmBuilder.New.Mov(CL, DL),
    [$8A, $CA]);
  CheckEnc('mov cx,dx',
    TAsmBuilder.New.Mov(CX, DX),
    [$66, $8B, $CA]);
  CheckEnc('mov ecx,edx',
    TAsmBuilder.New.Mov(ECX, EDX),
    [$8B, $CA]);
  CheckEnc('mov rcx,rdx',
    TAsmBuilder.New.Mov(RCX, RDX),
    [$48, $8B, $CA]);
  CheckEnc('mov cl,dh',
    TAsmBuilder.New.Mov(CL, DH),
    [$8A, $CE]);
  CheckEnc('mov ch,dl',
    TAsmBuilder.New.Mov(CH, DL),
    [$8A, $EA]);
  CheckEnc('mov cl,[rcx]',
    TAsmBuilder.New.Mov(CL, BytePtr(ridRCX)),
    [$8A, $09]);
  CheckEnc('mov cx,[rcx]',
    TAsmBuilder.New.Mov(CX, WordPtr(ridRCX)),
    [$66, $8B, $09]);
  CheckEnc('mov ecx,[rcx]',
    TAsmBuilder.New.Mov(ECX, DWordPtr(ridRCX)),
    [$8B, $09]);
  CheckEnc('mov rcx,[rcx]',
    TAsmBuilder.New.Mov(RCX, QWordPtr(ridRCX)),
    [$48, $8B, $09]);
  CheckEnc('mov [rcx],cl',
    TAsmBuilder.New.Mov(BytePtr(ridRCX), CL),
    [$88, $09]);
  CheckEnc('mov [rcx],cx',
    TAsmBuilder.New.Mov(WordPtr(ridRCX), CX),
    [$66, $89, $09]);
  CheckEnc('mov [rcx],ecx',
    TAsmBuilder.New.Mov(DWordPtr(ridRCX), ECX),
    [$89, $09]);
  CheckEnc('mov [rcx],rcx',
    TAsmBuilder.New.Mov(QWordPtr(ridRCX), RCX),
    [$48, $89, $09]);
  CheckEnc('mov cl,1',
    TAsmBuilder.New.Mov(CL, 1),
    [$B1, $01]);
  CheckEnc('mov ch,1',
    TAsmBuilder.New.Mov(CH, 1),
    [$B5, $01]);
  CheckEnc('mov cx,1',
    TAsmBuilder.New.Mov(CX, 1),
    [$66, $B9, $01, $00]);
  CheckEnc('mov ecx,1',
    TAsmBuilder.New.Mov(ECX, 1),
    [$B9, $01, $00, $00, $00]);
  CheckEnc('mov rcx,1',
    TAsmBuilder.New.Mov(RCX, 1),
    [$48, $C7, $C1, $01, $00, $00, $00]);
  CheckEnc('mov cl,[rcx+rdx*1+128]',
    TAsmBuilder.New.Mov(CL, BytePtrSib(ridRCX, ridRDX, s1, 128)),
    [$8A, $8C, $11, $80, $00, $00, $00]);
end;

procedure TestBsfBsr;
begin
  CheckEnc('bsf cx,dx',
    TAsmBuilder.New.Bsf(CX, DX),
    [$66, $0F, $BC, $CA]);
  CheckEnc('bsf ecx,edx',
    TAsmBuilder.New.Bsf(ECX, EDX),
    [$0F, $BC, $CA]);
  CheckEnc('bsf rcx,rdx',
    TAsmBuilder.New.Bsf(RCX, RDX),
    [$48, $0F, $BC, $CA]);
  CheckEnc('bsr cx,dx',
    TAsmBuilder.New.Bsr(CX, DX),
    [$66, $0F, $BD, $CA]);
  CheckEnc('bsr ecx,edx',
    TAsmBuilder.New.Bsr(ECX, EDX),
    [$0F, $BD, $CA]);
  CheckEnc('bsr rcx,rdx',
    TAsmBuilder.New.Bsr(RCX, RDX),
    [$48, $0F, $BD, $CA]);
end;

procedure TestBswap;
begin
  CheckEnc('bswap rcx',
    TAsmBuilder.New.Bswap(RCX),
    [$48, $0F, $C9]);
  CheckEnc('bswap rdx',
    TAsmBuilder.New.Bswap(RDX),
    [$48, $0F, $CA]);
end;

procedure TestCmov;
begin
  CheckEnc('cmove cx,dx',
    TAsmBuilder.New.Cmov(cond_JE, CX, DX),
    [$66, $0F, $44, $CA]);
  CheckEnc('cmove ecx,edx',
    TAsmBuilder.New.Cmov(cond_JE, ECX, EDX),
    [$0F, $44, $CA]);
  CheckEnc('cmove rcx,rdx',
    TAsmBuilder.New.Cmov(cond_JE, RCX, RDX),
    [$48, $0F, $44, $CA]);
  CheckEnc('cmovne cx,dx',
    TAsmBuilder.New.Cmov(cond_JNE, CX, DX),
    [$66, $0F, $45, $CA]);
  CheckEnc('cmovne ecx,edx',
    TAsmBuilder.New.Cmov(cond_JNE, ECX, EDX),
    [$0F, $45, $CA]);
  CheckEnc('cmovne rcx,rdx',
    TAsmBuilder.New.Cmov(cond_JNE, RCX, RDX),
    [$48, $0F, $45, $CA]);
  CheckEnc('cmovg cx,dx',
    TAsmBuilder.New.Cmov(cond_JG, CX, DX),
    [$66, $0F, $4F, $CA]);
  CheckEnc('cmovg ecx,edx',
    TAsmBuilder.New.Cmov(cond_JG, ECX, EDX),
    [$0F, $4F, $CA]);
  CheckEnc('cmovg rcx,rdx',
    TAsmBuilder.New.Cmov(cond_JG, RCX, RDX),
    [$48, $0F, $4F, $CA]);
  CheckEnc('cmovge cx,dx',
    TAsmBuilder.New.Cmov(cond_JGE, CX, DX),
    [$66, $0F, $4D, $CA]);
  CheckEnc('cmovge ecx,edx',
    TAsmBuilder.New.Cmov(cond_JGE, ECX, EDX),
    [$0F, $4D, $CA]);
  CheckEnc('cmovge rcx,rdx',
    TAsmBuilder.New.Cmov(cond_JGE, RCX, RDX),
    [$48, $0F, $4D, $CA]);
  CheckEnc('cmovl cx,dx',
    TAsmBuilder.New.Cmov(cond_JL, CX, DX),
    [$66, $0F, $4C, $CA]);
  CheckEnc('cmovl ecx,edx',
    TAsmBuilder.New.Cmov(cond_JL, ECX, EDX),
    [$0F, $4C, $CA]);
  CheckEnc('cmovl rcx,rdx',
    TAsmBuilder.New.Cmov(cond_JL, RCX, RDX),
    [$48, $0F, $4C, $CA]);
  CheckEnc('cmovle cx,dx',
    TAsmBuilder.New.Cmov(cond_JLE, CX, DX),
    [$66, $0F, $4E, $CA]);
  CheckEnc('cmovle ecx,edx',
    TAsmBuilder.New.Cmov(cond_JLE, ECX, EDX),
    [$0F, $4E, $CA]);
  CheckEnc('cmovle rcx,rdx',
    TAsmBuilder.New.Cmov(cond_JLE, RCX, RDX),
    [$48, $0F, $4E, $CA]);
  CheckEnc('cmova cx,dx',
    TAsmBuilder.New.Cmov(cond_JA, CX, DX),
    [$66, $0F, $47, $CA]);
  CheckEnc('cmova ecx,edx',
    TAsmBuilder.New.Cmov(cond_JA, ECX, EDX),
    [$0F, $47, $CA]);
  CheckEnc('cmova rcx,rdx',
    TAsmBuilder.New.Cmov(cond_JA, RCX, RDX),
    [$48, $0F, $47, $CA]);
  CheckEnc('cmovae cx,dx',
    TAsmBuilder.New.Cmov(cond_JAE, CX, DX),
    [$66, $0F, $43, $CA]);
  CheckEnc('cmovae ecx,edx',
    TAsmBuilder.New.Cmov(cond_JAE, ECX, EDX),
    [$0F, $43, $CA]);
  CheckEnc('cmovae rcx,rdx',
    TAsmBuilder.New.Cmov(cond_JAE, RCX, RDX),
    [$48, $0F, $43, $CA]);
  CheckEnc('cmovb cx,dx',
    TAsmBuilder.New.Cmov(cond_JB, CX, DX),
    [$66, $0F, $42, $CA]);
  CheckEnc('cmovb ecx,edx',
    TAsmBuilder.New.Cmov(cond_JB, ECX, EDX),
    [$0F, $42, $CA]);
  CheckEnc('cmovb rcx,rdx',
    TAsmBuilder.New.Cmov(cond_JB, RCX, RDX),
    [$48, $0F, $42, $CA]);
  CheckEnc('cmovbe cx,dx',
    TAsmBuilder.New.Cmov(cond_JBE, CX, DX),
    [$66, $0F, $46, $CA]);
  CheckEnc('cmovbe ecx,edx',
    TAsmBuilder.New.Cmov(cond_JBE, ECX, EDX),
    [$0F, $46, $CA]);
  CheckEnc('cmovbe rcx,rdx',
    TAsmBuilder.New.Cmov(cond_JBE, RCX, RDX),
    [$48, $0F, $46, $CA]);
end;

procedure TestDec;
begin
  CheckEnc('dec cl',
    TAsmBuilder.New.Dec_(CL),
    [$FE, $C9]);
  CheckEnc('dec cx',
    TAsmBuilder.New.Dec_(CX),
    [$66, $FF, $C9]);
  CheckEnc('dec ecx',
    TAsmBuilder.New.Dec_(ECX),
    [$FF, $C9]);
  CheckEnc('dec rcx',
    TAsmBuilder.New.Dec_(RCX),
    [$48, $FF, $C9]);
  CheckEnc('dec [rcx]b',
    TAsmBuilder.New.Dec_(BytePtr(ridRCX)),
    [$FE, $09]);
  CheckEnc('dec [rcx]d',
    TAsmBuilder.New.Dec_(DWordPtr(ridRCX)),
    [$FF, $09]);
  CheckEnc('dec [rcx]q',
    TAsmBuilder.New.Dec_(QWordPtr(ridRCX)),
    [$48, $FF, $09]);
end;

procedure TestInc;
begin
  CheckEnc('inc cl',
    TAsmBuilder.New.Inc_(CL),
    [$FE, $C1]);
  CheckEnc('inc cx',
    TAsmBuilder.New.Inc_(CX),
    [$66, $FF, $C1]);
  CheckEnc('inc ecx',
    TAsmBuilder.New.Inc_(ECX),
    [$FF, $C1]);
  CheckEnc('inc rcx',
    TAsmBuilder.New.Inc_(RCX),
    [$48, $FF, $C1]);
  CheckEnc('inc [rcx]b',
    TAsmBuilder.New.Inc_(BytePtr(ridRCX)),
    [$FE, $01]);
  CheckEnc('inc [rcx]d',
    TAsmBuilder.New.Inc_(DWordPtr(ridRCX)),
    [$FF, $01]);
  CheckEnc('inc [rcx]q',
    TAsmBuilder.New.Inc_(QWordPtr(ridRCX)),
    [$48, $FF, $01]);
end;

procedure TestImul;
begin
  CheckEnc('imul cx,dx',
    TAsmBuilder.New.Imul(CX, DX),
    [$66, $0F, $AF, $CA]);
  CheckEnc('imul ecx,edx',
    TAsmBuilder.New.Imul(ECX, EDX),
    [$0F, $AF, $CA]);
  CheckEnc('imul rcx,rdx',
    TAsmBuilder.New.Imul(RCX, RDX),
    [$48, $0F, $AF, $CA]);
  CheckEnc('imul ecx,edx,1',
    TAsmBuilder.New.Imul(ECX, EDX, 1),
    [$6B, $CA, $01]);
  CheckEnc('imul rcx,rdx,1',
    TAsmBuilder.New.Imul(RCX, RDX, 1),
    [$48, $6B, $CA, $01]);
  CheckEnc('imul ecx,edx,imm32',
    TAsmBuilder.New.Imul(ECX, EDX, $12345678),
    [$69, $CA, $78, $56, $34, $12]);
end;

procedure TestLea;
begin
  CheckEnc('lea ax,[rcx]',
    TAsmBuilder.New.Lea(AX, TMemory.Create(ridRCX)),
    [$66, $8D, $01]);
  CheckEnc('lea eax,[rcx]',
    TAsmBuilder.New.Lea(EAX, TMemory.Create(ridRCX)),
    [$8D, $01]);
  CheckEnc('lea ecx,[rcx]',
    TAsmBuilder.New.Lea(ECX, TMemory.Create(ridRCX)),
    [$8D, $09]);
  CheckEnc('lea ecx,[rdx]',
    TAsmBuilder.New.Lea(ECX, TMemory.Create(ridRDX)),
    [$8D, $0A]);
  CheckEnc('lea rax,[rcx]',
    TAsmBuilder.New.Lea(RAX, TMemory.Create(ridRCX)),
    [$48, $8D, $01]);
  CheckEnc('lea rcx,[rdx]',
    TAsmBuilder.New.Lea(RCX, TMemory.Create(ridRDX)),
    [$48, $8D, $0A]);
  CheckEnc('lea ecx,[rcx+rdx*4+16]',
    TAsmBuilder.New.Lea(ECX, TMemory.CreateSib(ridRCX, ridRDX, s4, 16, sz32)),
    [$8D, $4C, $91, $10]);
end;

procedure TestMovsx;
begin
  CheckEnc('movsx ecx,[rcx]b',
    TAsmBuilder.New.Movsx(ECX, BytePtr(ridRCX)),
    [$0F, $BE, $09]);
  CheckEnc('movsx rcx,[rcx]b',
    TAsmBuilder.New.Movsx(RCX, BytePtr(ridRCX)),
    [$48, $0F, $BE, $09]);
  CheckEnc('movsx ecx,[rcx]w',
    TAsmBuilder.New.Movsx(ECX, WordPtr(ridRCX)),
    [$0F, $BF, $09]);
  CheckEnc('movsx rcx,[rcx]w',
    TAsmBuilder.New.Movsx(RCX, WordPtr(ridRCX)),
    [$48, $0F, $BF, $09]);
end;

procedure TestMovzx;
begin
  CheckEnc('movzx ecx,[rcx]b',
    TAsmBuilder.New.Movzx(ECX, BytePtr(ridRCX)),
    [$0F, $B6, $09]);
  CheckEnc('movzx rcx,[rcx]b',
    TAsmBuilder.New.Movzx(RCX, BytePtr(ridRCX)),
    [$48, $0F, $B6, $09]);
  CheckEnc('movzx ecx,[rcx]w',
    TAsmBuilder.New.Movzx(ECX, WordPtr(ridRCX)),
    [$0F, $B7, $09]);
  CheckEnc('movzx rcx,[rcx]w',
    TAsmBuilder.New.Movzx(RCX, WordPtr(ridRCX)),
    [$48, $0F, $B7, $09]);
  CheckEnc('movzx rax,word [rcx]',
    TAsmBuilder.New.Movzx(RAX, WordPtr(ridRCX)),
    [$48, $0F, $B7, $01]);
end;

procedure TestNeg;
begin
  CheckEnc('neg cl',
    TAsmBuilder.New.Neg(CL),
    [$F6, $D9]);
  CheckEnc('neg cx',
    TAsmBuilder.New.Neg(CX),
    [$66, $F7, $D9]);
  CheckEnc('neg ecx',
    TAsmBuilder.New.Neg(ECX),
    [$F7, $D9]);
  CheckEnc('neg rcx',
    TAsmBuilder.New.Neg(RCX),
    [$48, $F7, $D9]);
  CheckEnc('neg [rcx]b',
    TAsmBuilder.New.Neg(BytePtr(ridRCX)),
    [$F6, $19]);
  CheckEnc('neg [rcx]d',
    TAsmBuilder.New.Neg(DWordPtr(ridRCX)),
    [$F7, $19]);
  CheckEnc('neg [rcx]q',
    TAsmBuilder.New.Neg(QWordPtr(ridRCX)),
    [$48, $F7, $19]);
end;

procedure TestNot;
begin
  CheckEnc('not cl',
    TAsmBuilder.New.Not_(CL),
    [$F6, $D1]);
  CheckEnc('not cx',
    TAsmBuilder.New.Not_(CX),
    [$66, $F7, $D1]);
  CheckEnc('not ecx',
    TAsmBuilder.New.Not_(ECX),
    [$F7, $D1]);
  CheckEnc('not rcx',
    TAsmBuilder.New.Not_(RCX),
    [$48, $F7, $D1]);
  CheckEnc('not [rcx]b',
    TAsmBuilder.New.Not_(BytePtr(ridRCX)),
    [$F6, $11]);
  CheckEnc('not [rcx]d',
    TAsmBuilder.New.Not_(DWordPtr(ridRCX)),
    [$F7, $11]);
  CheckEnc('not [rcx]q',
    TAsmBuilder.New.Not_(QWordPtr(ridRCX)),
    [$48, $F7, $11]);
end;

procedure TestPopcnt;
begin
  CheckEnc('popcnt cx,dx',
    TAsmBuilder.New.Popcnt(CX, DX),
    [$F3, $66, $0F, $B8, $CA]);
  CheckEnc('popcnt ecx,edx',
    TAsmBuilder.New.Popcnt(ECX, EDX),
    [$F3, $0F, $B8, $CA]);
  CheckEnc('popcnt rcx,rdx',
    TAsmBuilder.New.Popcnt(RCX, RDX),
    [$F3, $48, $0F, $B8, $CA]);
end;

procedure TestPush;
begin
  CheckEnc('push rax',
    TAsmBuilder.New.Push(RAX),
    [$50]);
  CheckEnc('push rcx',
    TAsmBuilder.New.Push(RCX),
    [$51]);
  CheckEnc('push rdx',
    TAsmBuilder.New.Push(RDX),
    [$52]);
  CheckEnc('push r8',
    TAsmBuilder.New.Push(R8),
    [$41, $50]);
  CheckEnc('push 1',
    TAsmBuilder.New.Push(1),
    [$6A, $01]);
  CheckEnc('push imm32',
    TAsmBuilder.New.Push($12345678),
    [$68, $78, $56, $34, $12]);
  CheckEnc('push [rcx]',
    TAsmBuilder.New.Push(QWordPtr(ridRCX)),
    [$FF, $31]);
  CheckEnc('push [rcx+rdx*1+128]',
    TAsmBuilder.New.Push(QWordPtrSib(ridRCX, ridRDX, s1, 128)),
    [$FF, $B4, $11, $80, $00, $00, $00]);
end;

procedure TestPop;
begin
  CheckEnc('pop rax',
    TAsmBuilder.New.Pop(RAX),
    [$58]);
  CheckEnc('pop rcx',
    TAsmBuilder.New.Pop(RCX),
    [$59]);
  CheckEnc('pop rdx',
    TAsmBuilder.New.Pop(RDX),
    [$5A]);
  CheckEnc('pop r8',
    TAsmBuilder.New.Pop(R8),
    [$41, $58]);
  CheckEnc('pop [rcx]',
    TAsmBuilder.New.Pop(QWordPtr(ridRCX)),
    [$8F, $01]);
  CheckEnc('pop [rcx+rdx*1+128]',
    TAsmBuilder.New.Pop(QWordPtrSib(ridRCX, ridRDX, s1, 128)),
    [$8F, $84, $11, $80, $00, $00, $00]);
end;

procedure TestRol;
begin
  CheckEnc('rol cl,1',
    TAsmBuilder.New.Rol(CL, 1),
    [$D0, $C1]);
  CheckEnc('rol cl,2',
    TAsmBuilder.New.Rol(CL, 2),
    [$C0, $C1, $02]);
  CheckEnc('rol cx,1',
    TAsmBuilder.New.Rol(CX, 1),
    [$66, $D1, $C1]);
  CheckEnc('rol cx,2',
    TAsmBuilder.New.Rol(CX, 2),
    [$66, $C1, $C1, $02]);
  CheckEnc('rol ecx,1',
    TAsmBuilder.New.Rol(ECX, 1),
    [$D1, $C1]);
  CheckEnc('rol ecx,2',
    TAsmBuilder.New.Rol(ECX, 2),
    [$C1, $C1, $02]);
  CheckEnc('rol rcx,1',
    TAsmBuilder.New.Rol(RCX, 1),
    [$48, $D1, $C1]);
  CheckEnc('rol rcx,2',
    TAsmBuilder.New.Rol(RCX, 2),
    [$48, $C1, $C1, $02]);
end;

procedure TestRor;
begin
  CheckEnc('ror cl,1',
    TAsmBuilder.New.Ror(CL, 1),
    [$D0, $C9]);
  CheckEnc('ror cl,2',
    TAsmBuilder.New.Ror(CL, 2),
    [$C0, $C9, $02]);
  CheckEnc('ror cx,1',
    TAsmBuilder.New.Ror(CX, 1),
    [$66, $D1, $C9]);
  CheckEnc('ror ecx,1',
    TAsmBuilder.New.Ror(ECX, 1),
    [$D1, $C9]);
  CheckEnc('ror ecx,2',
    TAsmBuilder.New.Ror(ECX, 2),
    [$C1, $C9, $02]);
  CheckEnc('ror rcx,1',
    TAsmBuilder.New.Ror(RCX, 1),
    [$48, $D1, $C9]);
  CheckEnc('ror rcx,2',
    TAsmBuilder.New.Ror(RCX, 2),
    [$48, $C1, $C9, $02]);
end;

procedure TestSar;
begin
  CheckEnc('sar cl,1',
    TAsmBuilder.New.Sar(CL, 1),
    [$D0, $F9]);
  CheckEnc('sar cl,cl',
    TAsmBuilder.New.Sar(CL, CL),
    [$D2, $F9]);
  CheckEnc('sar cl,2',
    TAsmBuilder.New.Sar(CL, 2),
    [$C0, $F9, $02]);
  CheckEnc('sar cx,1',
    TAsmBuilder.New.Sar(CX, 1),
    [$66, $D1, $F9]);
  CheckEnc('sar cx,cl',
    TAsmBuilder.New.Sar(CX, CL),
    [$66, $D3, $F9]);
  CheckEnc('sar ecx,1',
    TAsmBuilder.New.Sar(ECX, 1),
    [$D1, $F9]);
  CheckEnc('sar ecx,cl',
    TAsmBuilder.New.Sar(ECX, CL),
    [$D3, $F9]);
  CheckEnc('sar ecx,2',
    TAsmBuilder.New.Sar(ECX, 2),
    [$C1, $F9, $02]);
  CheckEnc('sar rcx,1',
    TAsmBuilder.New.Sar(RCX, 1),
    [$48, $D1, $F9]);
  CheckEnc('sar rcx,cl',
    TAsmBuilder.New.Sar(RCX, CL),
    [$48, $D3, $F9]);
  CheckEnc('sar rcx,2',
    TAsmBuilder.New.Sar(RCX, 2),
    [$48, $C1, $F9, $02]);
end;

procedure TestShl;
begin
  CheckEnc('shl cl,1',
    TAsmBuilder.New.Shl_(CL, 1),
    [$D0, $E1]);
  CheckEnc('shl cl,cl',
    TAsmBuilder.New.Shl_(CL, CL),
    [$D2, $E1]);
  CheckEnc('shl cl,2',
    TAsmBuilder.New.Shl_(CL, 2),
    [$C0, $E1, $02]);
  CheckEnc('shl cx,1',
    TAsmBuilder.New.Shl_(CX, 1),
    [$66, $D1, $E1]);
  CheckEnc('shl cx,cl',
    TAsmBuilder.New.Shl_(CX, CL),
    [$66, $D3, $E1]);
  CheckEnc('shl ecx,1',
    TAsmBuilder.New.Shl_(ECX, 1),
    [$D1, $E1]);
  CheckEnc('shl ecx,cl',
    TAsmBuilder.New.Shl_(ECX, CL),
    [$D3, $E1]);
  CheckEnc('shl ecx,2',
    TAsmBuilder.New.Shl_(ECX, 2),
    [$C1, $E1, $02]);
  CheckEnc('shl rcx,1',
    TAsmBuilder.New.Shl_(RCX, 1),
    [$48, $D1, $E1]);
  CheckEnc('shl rcx,cl',
    TAsmBuilder.New.Shl_(RCX, CL),
    [$48, $D3, $E1]);
  CheckEnc('shl rcx,2',
    TAsmBuilder.New.Shl_(RCX, 2),
    [$48, $C1, $E1, $02]);
  CheckEnc('shl rax,1',
    TAsmBuilder.New.Shl_(RAX, 1),
    [$48, $D1, $E0]);
  CheckEnc('shl rax,2',
    TAsmBuilder.New.Shl_(RAX, 2),
    [$48, $C1, $E0, $02]);
end;

procedure TestShr;
begin
  CheckEnc('shr cl,1',
    TAsmBuilder.New.Shr_(CL, 1),
    [$D0, $E9]);
  CheckEnc('shr cl,cl',
    TAsmBuilder.New.Shr_(CL, CL),
    [$D2, $E9]);
  CheckEnc('shr cl,2',
    TAsmBuilder.New.Shr_(CL, 2),
    [$C0, $E9, $02]);
  CheckEnc('shr cx,1',
    TAsmBuilder.New.Shr_(CX, 1),
    [$66, $D1, $E9]);
  CheckEnc('shr cx,cl',
    TAsmBuilder.New.Shr_(CX, CL),
    [$66, $D3, $E9]);
  CheckEnc('shr ecx,1',
    TAsmBuilder.New.Shr_(ECX, 1),
    [$D1, $E9]);
  CheckEnc('shr ecx,cl',
    TAsmBuilder.New.Shr_(ECX, CL),
    [$D3, $E9]);
  CheckEnc('shr ecx,2',
    TAsmBuilder.New.Shr_(ECX, 2),
    [$C1, $E9, $02]);
  CheckEnc('shr rcx,1',
    TAsmBuilder.New.Shr_(RCX, 1),
    [$48, $D1, $E9]);
  CheckEnc('shr rcx,cl',
    TAsmBuilder.New.Shr_(RCX, CL),
    [$48, $D3, $E9]);
  CheckEnc('shr rcx,2',
    TAsmBuilder.New.Shr_(RCX, 2),
    [$48, $C1, $E9, $02]);
end;

procedure TestSetcc;
begin
  CheckEnc('sete cl',
    TAsmBuilder.New.Setcc(cond_JE, CL),
    [$0F, $94, $C1]);
  CheckEnc('setne cl',
    TAsmBuilder.New.Setcc(cond_JNE, CL),
    [$0F, $95, $C1]);
  CheckEnc('setg cl',
    TAsmBuilder.New.Setcc(cond_JG, CL),
    [$0F, $9F, $C1]);
  CheckEnc('setge cl',
    TAsmBuilder.New.Setcc(cond_JGE, CL),
    [$0F, $9D, $C1]);
  CheckEnc('setl cl',
    TAsmBuilder.New.Setcc(cond_JL, CL),
    [$0F, $9C, $C1]);
  CheckEnc('setle cl',
    TAsmBuilder.New.Setcc(cond_JLE, CL),
    [$0F, $9E, $C1]);
  CheckEnc('seta cl',
    TAsmBuilder.New.Setcc(cond_JA, CL),
    [$0F, $97, $C1]);
  CheckEnc('setae cl',
    TAsmBuilder.New.Setcc(cond_JAE, CL),
    [$0F, $93, $C1]);
  CheckEnc('setb cl',
    TAsmBuilder.New.Setcc(cond_JB, CL),
    [$0F, $92, $C1]);
  CheckEnc('setbe cl',
    TAsmBuilder.New.Setcc(cond_JBE, CL),
    [$0F, $96, $C1]);
  CheckEnc('setz r8b',
    TAsmBuilder.New.Setcc(cond_JE, R8B),
    [$41, $0F, $94, $C0]);
end;

procedure TestTest;
begin
  CheckEnc('test cl,dl',
    TAsmBuilder.New.Test(CL, DL),
    [$84, $D1]);
  CheckEnc('test cx,dx',
    TAsmBuilder.New.Test(CX, DX),
    [$66, $85, $D1]);
  CheckEnc('test ecx,edx',
    TAsmBuilder.New.Test(ECX, EDX),
    [$85, $D1]);
  CheckEnc('test rcx,rdx',
    TAsmBuilder.New.Test(RCX, RDX),
    [$48, $85, $D1]);
  CheckEnc('test [rcx],cl',
    TAsmBuilder.New.Test(BytePtr(ridRCX), CL),
    [$84, $09]);
  CheckEnc('test [rcx],ecx',
    TAsmBuilder.New.Test(DWordPtr(ridRCX), ECX),
    [$85, $09]);
  CheckEnc('test [rcx],rcx',
    TAsmBuilder.New.Test(QWordPtr(ridRCX), RCX),
    [$48, $85, $09]);
  CheckEnc('test cl,1',
    TAsmBuilder.New.Test(CL, 1),
    [$F6, $C1, $01]);
  CheckEnc('test ecx,1',
    TAsmBuilder.New.Test(ECX, 1),
    [$F7, $C1, $01, $00, $00, $00]);
  CheckEnc('test rcx,1',
    TAsmBuilder.New.Test(RCX, 1),
    [$48, $F7, $C1, $01, $00, $00, $00]);
end;

procedure TestXchg;
begin
  CheckEnc('xchg cl,dl',
    TAsmBuilder.New.Xchg(CL, DL),
    [$86, $CA]);
  CheckEnc('xchg cx,dx',
    TAsmBuilder.New.Xchg(CX, DX),
    [$66, $87, $CA]);
  CheckEnc('xchg ecx,edx',
    TAsmBuilder.New.Xchg(ECX, EDX),
    [$87, $CA]);
  CheckEnc('xchg rcx,rdx',
    TAsmBuilder.New.Xchg(RCX, RDX),
    [$48, $87, $CA]);
  CheckEnc('xchg rax,rcx',
    TAsmBuilder.New.Xchg(RAX, RCX),
    [$48, $91]);
  CheckEnc('xchg rax,rdx',
    TAsmBuilder.New.Xchg(RAX, RDX),
    [$48, $92]);
  CheckEnc('xchg rax,rbx',
    TAsmBuilder.New.Xchg(RAX, RBX),
    [$48, $93]);
  CheckEnc('xchg eax,ecx',
    TAsmBuilder.New.Xchg(EAX, ECX),
    [$91]);
end;

begin
  GPass := 0;
  GFail := 0;
  try
    TestAdd;
    TestOr;
    TestAnd;
    TestSub;
    TestXor;
    TestCmp;
    TestMov;
    TestBsfBsr;
    TestBswap;
    TestCmov;
    TestDec;
    TestInc;
    TestImul;
    TestLea;
    TestMovsx;
    TestMovzx;
    TestNeg;
    TestNot;
    TestPopcnt;
    TestPush;
    TestPop;
    TestRol;
    TestRor;
    TestSar;
    TestShl;
    TestShr;
    TestSetcc;
    TestTest;
    TestXchg;
    Writeln(Format('NativeAsmEncodingTests: %d passed, %d failed', [GPass, GFail]));
    if GFail > 0 then
      ExitCode := 1;
  except
    on E: Exception do
    begin
      Writeln(E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
