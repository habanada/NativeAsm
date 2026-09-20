{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
program NativeAsmProTests;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  NativeAsm.Types,
  NativeAsm.Operands,
  NativeAsm.Rules,
  NativeAsm.CpuFeatures,
  NativeAsm.Abi.Win64,
  NativeAsm.Builder,
  NativeAsm.InstructionDB,
  NativeAsm.InstructionDB.Generated,
  NativeAsm.Extensions,
  NativeAsm.JitAlloc;

type
  TTestProc = reference to procedure;
  TBuilderAction = reference to procedure(B: TAsmBuilder);

var
  GGroup: string;
  GTotal: Integer;
  GPassed: Integer;
  GFailed: Integer;

function Bits(Value: Int64): UInt64;
begin
  Move(Value, Result, SizeOf(Result));
end;

function SignedBits(Value: UInt64): Int64;
begin
  Move(Value, Result, SizeOf(Result));
end;

function HexU64(Value: UInt64): string;
var
  S: Int64;
begin
  Move(Value, S, SizeOf(S));
  Result := IntToHex(S, 16);
end;

function HexOf(const Data: TBytes): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(Data) do Result := Result + IntToHex(Data[I], 2);
end;

function NormalizeHex(const Value: string): string;
begin
  Result := UpperCase(StringReplace(StringReplace(StringReplace(Value, ' ', '', [rfReplaceAll]), '-', '', [rfReplaceAll]), ':', '', [rfReplaceAll]));
end;

function FullName(const Name: string): string;
begin
  Result := GGroup + '/' + Name;
end;

procedure PassCase;
begin
  Inc(GPassed);
end;

procedure FailCase(const Name, Msg: string);
begin
  Inc(GFailed);
  Writeln('  FAIL ', FullName(Name), ': ', Msg);
end;

procedure CheckTrue(const Name: string; Value: Boolean; const Msg: string = 'condition is false');
begin
  Inc(GTotal);
  if Value then PassCase else FailCase(Name, Msg);
end;

procedure CheckInt(const Name: string; Actual, Expected: Int64);
begin
  Inc(GTotal);
  if Actual = Expected then PassCase else FailCase(Name, Format('%d <> %d', [Actual, Expected]));
end;

procedure CheckUInt64(const Name: string; Actual, Expected: UInt64);
begin
  Inc(GTotal);
  if Actual = Expected then PassCase else FailCase(Name, Format('$%s <> $%s', [HexU64(Actual), HexU64(Expected)]));
end;

procedure CheckHex(const Name: string; B: TAsmBuilder; const Expected: string);
var
  Actual: TBytes;
  ActualHex, ExpectedHex: string;
begin
  Inc(GTotal);
  try
    try
      Actual := B.Build;
      ActualHex := HexOf(Actual);
      ExpectedHex := NormalizeHex(Expected);
      if SameText(ActualHex, ExpectedHex) then PassCase else FailCase(Name, ActualHex + ' <> ' + ExpectedHex);
    except
      on E: Exception do FailCase(Name, E.ClassName + ': ' + E.Message);
    end;
  finally
    B.Free;
  end;
end;

procedure CheckRun0(const Name: string; Exe: TExecutableCode; Expected: UInt64);
var
  Actual: UInt64;
begin
  Inc(GTotal);
  try
    Actual := Exe.Run;
    if Actual = Expected then PassCase else FailCase(Name, Format('$%s <> $%s', [HexU64(Actual), HexU64(Expected)]));
  except
    on E: Exception do FailCase(Name, E.ClassName + ': ' + E.Message);
  end;
end;

procedure CheckRun1(const Name: string; Exe: TExecutableCode; A1, Expected: UInt64);
var
  Actual: UInt64;
begin
  Inc(GTotal);
  try
    Actual := Exe.Run(A1);
    if Actual = Expected then PassCase else FailCase(Name, Format('$%s <> $%s', [HexU64(Actual), HexU64(Expected)]));
  except
    on E: Exception do FailCase(Name, E.ClassName + ': ' + E.Message);
  end;
end;

procedure CheckRun2(const Name: string; Exe: TExecutableCode; A1, A2, Expected: UInt64);
var
  Actual: UInt64;
begin
  Inc(GTotal);
  try
    Actual := Exe.Run(A1, A2);
    if Actual = Expected then PassCase else FailCase(Name, Format('$%s <> $%s', [HexU64(Actual), HexU64(Expected)]));
  except
    on E: Exception do FailCase(Name, E.ClassName + ': ' + E.Message);
  end;
end;

procedure CheckRun3(const Name: string; Exe: TExecutableCode; A1, A2, A3, Expected: UInt64);
var
  Actual: UInt64;
begin
  Inc(GTotal);
  try
    Actual := Exe.Run(A1, A2, A3);
    if Actual = Expected then PassCase else FailCase(Name, Format('$%s <> $%s', [HexU64(Actual), HexU64(Expected)]));
  except
    on E: Exception do FailCase(Name, E.ClassName + ': ' + E.Message);
  end;
end;

procedure CheckRun4(const Name: string; Exe: TExecutableCode; A1, A2, A3, A4, Expected: UInt64);
var
  Actual: UInt64;
begin
  Inc(GTotal);
  try
    Actual := Exe.Run(A1, A2, A3, A4);
    if Actual = Expected then PassCase else FailCase(Name, Format('$%s <> $%s', [HexU64(Actual), HexU64(Expected)]));
  except
    on E: Exception do FailCase(Name, E.ClassName + ': ' + E.Message);
  end;
end;

procedure ExpectException(const Name: string; Action: TTestProc);
var
  Raised: Boolean;
begin
  Inc(GTotal);
  Raised := False;
  try
    Action;
  except
    on E: Exception do Raised := True;
  end;
  if Raised then PassCase else FailCase(Name, 'exception expected');
end;

procedure ExpectRuleViolation(const Name, ExpectedText: string; Action: TTestProc);
var
  Raised: Boolean;
begin
  Inc(GTotal);
  Raised := False;
  try
    Action;
  except
    on E: ENativeAsmRuleViolation do
    begin
      Raised := True;
      if Pos(ExpectedText, E.Message) = 0 then
      begin
        FailCase(Name, E.Message);
        Exit;
      end;
    end;
    on E: Exception do
    begin
      FailCase(Name, E.ClassName + ': ' + E.Message);
      Exit;
    end;
  end;
  if Raised then PassCase else FailCase(Name, 'ENativeAsmRuleViolation expected');
end;

procedure ExpectAbiViolation(const Name, ExpectedText: string; Action: TTestProc);
var
  Raised: Boolean;
begin
  Inc(GTotal);
  Raised := False;
  try
    Action;
  except
    on E: ENativeAsmAbiViolation do
    begin
      Raised := True;
      if Pos(ExpectedText, E.Message) = 0 then
      begin
        FailCase(Name, E.Message);
        Exit;
      end;
    end;
    on E: Exception do
    begin
      FailCase(Name, E.ClassName + ': ' + E.Message);
      Exit;
    end;
  end;
  if Raised then PassCase else FailCase(Name, 'ENativeAsmAbiViolation expected');
end;

procedure ExpectNoException(const Name: string; Action: TTestProc);
begin
  Inc(GTotal);
  try
    Action;
    PassCase;
  except
    on E: Exception do FailCase(Name, E.ClassName + ': ' + E.Message);
  end;
end;

procedure ExpectBuilderFailure(const Name: string; Action: TBuilderAction);
var
  B: TAsmBuilder;
  Raised: Boolean;
begin
  Inc(GTotal);
  B := TAsmBuilder.New;
  try
    Raised := False;
    try
      Action(B);
    except
      on E: Exception do Raised := True;
    end;
    if not Raised then FailCase(Name, 'exception expected')
    else if B.CodeSize <> 0 then FailCase(Name, Format('partial emission: %d bytes', [B.CodeSize]))
    else PassCase;
  finally
    B.Free;
  end;
end;

procedure ExpectBuildFailure(const Name: string; B: TAsmBuilder);
var
  Raised: Boolean;
begin
  Inc(GTotal);
  try
    Raised := False;
    try
      B.Build;
    except
      on E: Exception do Raised := True;
    end;
    if Raised then PassCase else FailCase(Name, 'Build exception expected');
  finally
    B.Free;
  end;
end;

function CompileBuilder(B: TAsmBuilder): TExecutableCode;
begin
  try
    Result := TExecutableCode.FromBuilder(B);
  finally
    B.Free;
  end;
end;

function CompileBuilderPool(B: TAsmBuilder; Pool: TJitAllocator): TExecutableCode;
begin
  try
    Result := TExecutableCode.FromBuilder(B, False, Pool);
  finally
    B.Free;
  end;
end;

function ConditionName(Cond: TCondition): string;
begin
  case Cond of
    cond_JE: Result := 'JE';
    cond_JNE: Result := 'JNE';
    cond_JG: Result := 'JG';
    cond_JGE: Result := 'JGE';
    cond_JL: Result := 'JL';
    cond_JLE: Result := 'JLE';
    cond_JA: Result := 'JA';
    cond_JAE: Result := 'JAE';
    cond_JB: Result := 'JB';
    cond_JBE: Result := 'JBE';
  else
    Result := 'JMP';
  end;
end;

function ConditionExpected(Cond: TCondition; A, B: UInt64): Boolean;
var
  SA, SB: Int64;
begin
  SA := SignedBits(A);
  SB := SignedBits(B);
  case Cond of
    cond_JE: Result := A = B;
    cond_JNE: Result := A <> B;
    cond_JG: Result := SA > SB;
    cond_JGE: Result := SA >= SB;
    cond_JL: Result := SA < SB;
    cond_JLE: Result := SA <= SB;
    cond_JA: Result := A > B;
    cond_JAE: Result := A >= B;
    cond_JB: Result := A < B;
    cond_JBE: Result := A <= B;
  else
    Result := True;
  end;
end;

function BoolValue(Value: Boolean): UInt64;
begin
  if Value then Result := 1 else Result := 0;
end;

procedure ComparePair(Index: Integer; out A, B: UInt64);
begin
  case Index of
    0: begin A := 0; B := 0; end;
    1: begin A := 1; B := 2; end;
    2: begin A := 2; B := 1; end;
    3: begin A := Bits(-1); B := 1; end;
    4: begin A := 1; B := Bits(-1); end;
    5: begin A := Bits(-5); B := Bits(-2); end;
    6: begin A := Bits(-2); B := Bits(-5); end;
    7: begin A := UInt64(High(Int64)); B := UInt64(High(Int64)); end;
    8: begin A := Bits(Low(Int64)); B := 0; end;
  else
    begin A := 0; B := Bits(Low(Int64)); end;
  end;
end;

function ShiftSar(Value: UInt64; Count: Integer): UInt64;
var
  C: Integer;
begin
  C := Count and 63;
  if C = 0 then Exit(Value);
  Result := Value shr C;
  if (Value and (UInt64(1) shl 63)) <> 0 then Result := Result or ((not UInt64(0)) shl (64 - C));
end;

function RotateLeft(Value: UInt64; Count: Integer): UInt64;
var
  C: Integer;
begin
  C := Count and 63;
  if C = 0 then Exit(Value);
  Result := (Value shl C) or (Value shr (64 - C));
end;

function RotateRight(Value: UInt64; Count: Integer): UInt64;
var
  C: Integer;
begin
  C := Count and 63;
  if C = 0 then Exit(Value);
  Result := (Value shr C) or (Value shl (64 - C));
end;

function Swap64(Value: UInt64): UInt64;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to 7 do Result := Result or (((Value shr (I * 8)) and $FF) shl ((7 - I) * 8));
end;

function FirstBit(Value: UInt64): UInt64;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to 63 do
    if (Value and (UInt64(1) shl I)) <> 0 then Exit(UInt64(I));
end;

function LastBit(Value: UInt64): UInt64;
var
  I: Integer;
begin
  Result := 0;
  for I := 63 downto 0 do
    if (Value and (UInt64(1) shl I)) <> 0 then Exit(UInt64(I));
end;

function CompileBranch(Cond: TCondition): TExecutableCode;
var
  B: TAsmBuilder;
  L: TLabel;
begin
  B := TAsmBuilder.New;
  L := B.NewLabel;
  B.Xor_(EAX, EAX).Cmp(RCX, RDX).J(Cond, L).Ret.Bind(L).Mov(EAX, 1).Ret;
  Result := CompileBuilder(B);
end;

function CompileSetcc(Cond: TCondition): TExecutableCode;
var
  B: TAsmBuilder;
begin
  B := TAsmBuilder.New;
  B.Xor_(EAX, EAX).Cmp(RCX, RDX).Setcc(Cond, AL).Ret;
  Result := CompileBuilder(B);
end;

function CompileCmov(Cond: TCondition): TExecutableCode;
var
  B: TAsmBuilder;
begin
  B := TAsmBuilder.New;
  B.Mov(RAX, 111).Mov(R10, 222).Cmp(RCX, RDX).Cmov(Cond, RAX, R10).Ret;
  Result := CompileBuilder(B);
end;

procedure TestDatabase;
begin
  TInstructionDb.ValidateGeneratedDb;
  CheckInt('form-count', CInstructionFormCount, 470);
  CheckInt('mnemonic-count', CInstructionMnemonicCount, 94);
  CheckInt('operand-count', CInstructionOperandCount, 850);
  CheckTrue('source-sha256', Length(CInstructionDbSourceSha256) = 64);
end;

procedure TestGoldenEncodings;
begin
  CheckHex('mov rax,rbx', TAsmBuilder.New.Mov(RAX, RBX), '48 8B C3');
  CheckHex('mov rax,1', TAsmBuilder.New.Mov(RAX, 1), '48 C7 C0 01 00 00 00');
  CheckHex('mov rax,-1', TAsmBuilder.New.Mov(RAX, -1), '48 C7 C0 FF FF FF FF');
  CheckHex('mov rax,imm64', TAsmBuilder.New.Mov(RAX, Int64($1122334455667788)), '48 B8 88 77 66 55 44 33 22 11');
  CheckHex('mov r8,1', TAsmBuilder.New.Mov(R8, 1), '49 C7 C0 01 00 00 00');
  CheckHex('mov eax,ebx', TAsmBuilder.New.Mov(EAX, EBX), '8B C3');
  CheckHex('mov ax,bx', TAsmBuilder.New.Mov(AX, BX), '66 8B C3');
  CheckHex('mov al,bl', TAsmBuilder.New.Mov(AL, BL), '8A C3');
  CheckHex('mov ah,bl', TAsmBuilder.New.Mov(AH, BL), '8A E3');
  CheckHex('mov bl,ah', TAsmBuilder.New.Mov(BL, AH), '8A DC');
  CheckHex('mov spl,al', TAsmBuilder.New.Mov(SPL, AL), '40 8A E0');
  CheckHex('mov al,spl', TAsmBuilder.New.Mov(AL, SPL), '40 8A C4');
  CheckHex('mov r8b,al', TAsmBuilder.New.Mov(R8B, AL), '44 8A C0');
  CheckHex('mov al,r8b', TAsmBuilder.New.Mov(AL, R8B), '41 8A C0');
  CheckHex('mov r8,r15', TAsmBuilder.New.Mov(R8, R15), '4D 8B C7');
  CheckHex('mov r15,r8', TAsmBuilder.New.Mov(R15, R8), '4D 8B F8');
  CheckHex('mov rax,[rcx]', TAsmBuilder.New.Mov(RAX, QWordPtr(ridRCX)), '48 8B 01');
  CheckHex('mov [rcx],rax', TAsmBuilder.New.Mov(QWordPtr(ridRCX), RAX), '48 89 01');
  CheckHex('mov rax,[rsp]', TAsmBuilder.New.Mov(RAX, QWordPtr(ridRSP)), '48 8B 04 24');
  CheckHex('mov rax,[rbp]', TAsmBuilder.New.Mov(RAX, QWordPtr(ridRBP)), '48 8B 45 00');
  CheckHex('mov rax,[r12]', TAsmBuilder.New.Mov(RAX, QWordPtr(ridR12)), '49 8B 04 24');
  CheckHex('mov rax,[r13]', TAsmBuilder.New.Mov(RAX, QWordPtr(ridR13)), '49 8B 45 00');
  CheckHex('mov rax,[rcx+127]', TAsmBuilder.New.Mov(RAX, QWordPtr(ridRCX, 127)), '48 8B 41 7F');
  CheckHex('mov rax,[rcx-128]', TAsmBuilder.New.Mov(RAX, QWordPtr(ridRCX, -128)), '48 8B 41 80');
  CheckHex('mov rax,[rcx+128]', TAsmBuilder.New.Mov(RAX, QWordPtr(ridRCX, 128)), '48 8B 81 80 00 00 00');
  CheckHex('mov rax,[rcx-129]', TAsmBuilder.New.Mov(RAX, QWordPtr(ridRCX, -129)), '48 8B 81 7F FF FF FF');
  CheckHex('mov rax,[rcx+rdx*4+8]', TAsmBuilder.New.Mov(RAX, QWordPtrSib(ridRCX, ridRDX, s4, 8)), '48 8B 44 91 08');
  CheckHex('mov rax,[rbp+rdx*2]', TAsmBuilder.New.Mov(RAX, QWordPtrSib(ridRBP, ridRDX, s2)), '48 8B 44 55 00');
  CheckHex('mov rax,[r13+rdx*2]', TAsmBuilder.New.Mov(RAX, QWordPtrSib(ridR13, ridRDX, s2)), '49 8B 44 55 00');
  CheckHex('mov rax,[r12+r13*8]', TAsmBuilder.New.Mov(RAX, QWordPtrSib(ridR12, ridR13, s8)), '4B 8B 04 EC');
  CheckHex('mov rax,[rip]', TAsmBuilder.New.Mov(RAX, QWordRip(0)), '48 8B 05 00 00 00 00');
  CheckHex('movsx rax,byte [rcx]', TAsmBuilder.New.Movsx(RAX, BytePtr(ridRCX)), '48 0F BE 01');
  CheckHex('movsx rax,word [rcx]', TAsmBuilder.New.Movsx(RAX, WordPtr(ridRCX)), '48 0F BF 01');
  CheckHex('movsxd rax,dword [rcx]', TAsmBuilder.New.Movsx(RAX, DWordPtr(ridRCX)), '48 63 01');
  CheckHex('movzx rax,byte [rcx]', TAsmBuilder.New.Movzx(RAX, BytePtr(ridRCX)), '48 0F B6 01');
  CheckHex('movzx rax,word [rcx]', TAsmBuilder.New.Movzx(RAX, WordPtr(ridRCX)), '48 0F B7 01');
  CheckHex('lea rax,[rcx]', TAsmBuilder.New.Lea(RAX, TMemory.Create(ridRCX)), '48 8D 01');
  CheckHex('lea ax,[rcx]', TAsmBuilder.New.Lea(AX, TMemory.Create(ridRCX)), '66 8D 01');
  CheckHex('lea rax,[rip]', TAsmBuilder.New.Lea(RAX, TMemory.CreateRip(0)), '48 8D 05 00 00 00 00');
  CheckHex('add rax,1', TAsmBuilder.New.Add(RAX, 1), '48 83 C0 01');
  CheckHex('add rax,imm32', TAsmBuilder.New.Add(RAX, $12345678), '48 05 78 56 34 12');
  CheckHex('adc rax,rdx', TAsmBuilder.New.Adc(RAX, RDX), '48 13 C2');
  CheckHex('sbb r9,r10', TAsmBuilder.New.Sbb(R9, R10), '4D 1B CA');
  CheckHex('mul r8', TAsmBuilder.New.Mul(R8), '49 F7 E0');
  CheckHex('sub rax,1', TAsmBuilder.New.Sub(RAX, 1), '48 83 E8 01');
  CheckHex('sub rax,imm32', TAsmBuilder.New.Sub(RAX, $12345678), '48 2D 78 56 34 12');
  CheckHex('inc rax', TAsmBuilder.New.Inc_(RAX), '48 FF C0');
  CheckHex('dec rax', TAsmBuilder.New.Dec_(RAX), '48 FF C8');
  CheckHex('neg rax', TAsmBuilder.New.Neg(RAX), '48 F7 D8');
  CheckHex('not rax', TAsmBuilder.New.Not_(RAX), '48 F7 D0');
  CheckHex('imul rax,rcx', TAsmBuilder.New.Imul(RAX, RCX), '48 0F AF C1');
  CheckHex('imul rax,rcx,7', TAsmBuilder.New.Imul(RAX, RCX, 7), '48 6B C1 07');
  CheckHex('imul rax,rcx,128', TAsmBuilder.New.Imul(RAX, RCX, 128), '48 69 C1 80 00 00 00');
  CheckHex('shl rax,1', TAsmBuilder.New.Shl_(RAX, 1), '48 D1 E0');
  CheckHex('shl rax,2', TAsmBuilder.New.Shl_(RAX, 2), '48 C1 E0 02');
  CheckHex('shl rax,cl', TAsmBuilder.New.Shl_(RAX, CL), '48 D3 E0');
  CheckHex('shr rax,cl', TAsmBuilder.New.Shr_(RAX, CL), '48 D3 E8');
  CheckHex('sar rax,cl', TAsmBuilder.New.Sar(RAX, CL), '48 D3 F8');
  CheckHex('rol rax,1', TAsmBuilder.New.Rol(RAX, 1), '48 D1 C0');
  CheckHex('ror rax,1', TAsmBuilder.New.Ror(RAX, 1), '48 D1 C8');
  CheckHex('bsf rax,rcx', TAsmBuilder.New.Bsf(RAX, RCX), '48 0F BC C1');
  CheckHex('bsr rax,rcx', TAsmBuilder.New.Bsr(RAX, RCX), '48 0F BD C1');
  CheckHex('popcnt rax,rcx', TAsmBuilder.New.Popcnt(RAX, RCX), 'F3 48 0F B8 C1');
  CheckHex('bswap rax', TAsmBuilder.New.Bswap(RAX), '48 0F C8');
  CheckHex('bswap r8', TAsmBuilder.New.Bswap(R8), '49 0F C8');
  CheckHex('test rax,rcx', TAsmBuilder.New.Test(RAX, RCX), '48 85 C8');
  CheckHex('cmovz rax,rcx', TAsmBuilder.New.Cmov(cond_JE, RAX, RCX), '48 0F 44 C1');
  CheckHex('setz al', TAsmBuilder.New.Setcc(cond_JE, AL), '0F 94 C0');
  CheckHex('setnz al', TAsmBuilder.New.Setcc(cond_JNE, AL), '0F 95 C0');
  CheckHex('setg al', TAsmBuilder.New.Setcc(cond_JG, AL), '0F 9F C0');
  CheckHex('setge al', TAsmBuilder.New.Setcc(cond_JGE, AL), '0F 9D C0');
  CheckHex('setl al', TAsmBuilder.New.Setcc(cond_JL, AL), '0F 9C C0');
  CheckHex('setle al', TAsmBuilder.New.Setcc(cond_JLE, AL), '0F 9E C0');
  CheckHex('seta al', TAsmBuilder.New.Setcc(cond_JA, AL), '0F 97 C0');
  CheckHex('setae al', TAsmBuilder.New.Setcc(cond_JAE, AL), '0F 93 C0');
  CheckHex('setb al', TAsmBuilder.New.Setcc(cond_JB, AL), '0F 92 C0');
  CheckHex('setbe al', TAsmBuilder.New.Setcc(cond_JBE, AL), '0F 96 C0');
  CheckHex('setz spl', TAsmBuilder.New.Setcc(cond_JE, SPL), '40 0F 94 C4');
  CheckHex('setz r8b', TAsmBuilder.New.Setcc(cond_JE, R8B), '41 0F 94 C0');
  CheckHex('setz r15b', TAsmBuilder.New.Setcc(cond_JE, R15B), '41 0F 94 C7');
  CheckHex('push r8', TAsmBuilder.New.Push(R8), '41 50');
  CheckHex('pop r8', TAsmBuilder.New.Pop(R8), '41 58');
  CheckHex('push 127', TAsmBuilder.New.Push(127), '6A 7F');
  CheckHex('push 128', TAsmBuilder.New.Push(128), '68 80 00 00 00');
  CheckHex('push -128', TAsmBuilder.New.Push(-128), '6A 80');
  CheckHex('push -129', TAsmBuilder.New.Push(-129), '68 7F FF FF FF');
  CheckHex('call rax', TAsmBuilder.New.Call(RAX), 'FF D0');
  CheckHex('call r8', TAsmBuilder.New.Call(R8), '41 FF D0');
  CheckHex('ret', TAsmBuilder.New.Ret, 'C3');
  CheckHex('ret 16', TAsmBuilder.New.Ret(16), 'C2 10 00');
  CheckHex('lfence', TAsmBuilder.New.Lfence, '0F AE E8');
  CheckHex('mfence', TAsmBuilder.New.Mfence, '0F AE F0');
  CheckHex('sfence', TAsmBuilder.New.Sfence, '0F AE F8');
  CheckHex('rdtsc', TAsmBuilder.New.Rdtsc, '0F 31');
  CheckHex('rdtscp', TAsmBuilder.New.Rdtscp, '0F 01 F9');
  CheckHex('int3', TAsmBuilder.New.Int3, 'CC');
  CheckHex('ud2', TAsmBuilder.New.Ud2, '0F 0B');
  CheckHex('nop 1', TAsmBuilder.New.Nop(1), '90');
  CheckHex('nop 2', TAsmBuilder.New.Nop(2), '66 90');
  CheckHex('nop 3', TAsmBuilder.New.Nop(3), '0F 1F 00');
  CheckHex('nop 9', TAsmBuilder.New.Nop(9), '66 0F 1F 84 00 00 00 00 00');
  CheckHex('nop 10', TAsmBuilder.New.Nop(10), '66 0F 1F 84 00 00 00 00 00 90');
end;

procedure TestMemoryAlignmentMetadata;
var
  M: TMemory;
begin
  M := TMemory.Create(ridRAX);
  CheckInt('create-unknown', M.Alignment, 0);
  M := TMemory.CreateSib(ridRAX, ridRCX, s2);
  CheckInt('sib-unknown', M.Alignment, 0);
  M := TMemory.CreateRip(0);
  CheckInt('rip-unknown', M.Alignment, 0);
  M := WordPtr(ridRAX);
  CheckInt('wordptr-unknown', M.Alignment, 0);
  M := OWordPtr(ridRAX);
  CheckInt('oword-size', Ord(M.Size), Ord(sz128));
  CheckInt('oword-unknown', M.Alignment, 0);
  M := AlignedWordPtr(ridRAX);
  CheckInt('aligned-word-size', Ord(M.Size), Ord(sz16));
  CheckInt('aligned-word', M.Alignment, 2);
  M := AlignedDWordPtr(ridRAX);
  CheckInt('aligned-dword-size', Ord(M.Size), Ord(sz32));
  CheckInt('aligned-dword', M.Alignment, 4);
  M := AlignedQWordPtr(ridRAX);
  CheckInt('aligned-qword-size', Ord(M.Size), Ord(sz64));
  CheckInt('aligned-qword', M.Alignment, 8);
  M := AlignedOWordPtr(ridRAX);
  CheckInt('aligned-oword-size', Ord(M.Size), Ord(sz128));
  CheckInt('aligned-oword', M.Alignment, 16);
end;

procedure TestRulesInfrastructure;
var
  M: TMemory;
begin
  CheckHex('known-alignment-preserves-mov', TAsmBuilder.New.Mov(RAX, AlignedQWordPtr(ridRCX)), '48 8B 01');
  ExpectRuleViolation('rejects-unknown-movdqa', 'operand alignment is unknown', procedure begin TAsmRuleValidator.Validate('movdqa', [TOperand(OWordPtr(ridRAX))]); end);
  M := OWordPtr(ridRAX);
  M.Alignment := 8;
  ExpectRuleViolation('rejects-insufficient-movdqa', 'operand guarantees only 8-byte alignment', procedure begin TAsmRuleValidator.Validate('movdqa', [TOperand(M)]); end);
  ExpectNoException('accepts-aligned-movdqa', procedure begin TAsmRuleValidator.Validate('movdqa', [TOperand(AlignedOWordPtr(ridRAX))]); end);
  ExpectNoException('allows-unaligned-movdqu', procedure begin TAsmRuleValidator.Validate('movdqu', [TOperand(OWordPtr(ridRAX))]); end);
  ExpectRuleViolation('rejects-unknown-movaps', 'requires 16-byte aligned memory', procedure begin TAsmRuleValidator.Validate('movaps', [TOperand(OWordPtr(ridRAX))]); end);
  ExpectRuleViolation('rejects-unknown-movapd', 'requires 16-byte aligned memory', procedure begin TAsmRuleValidator.Validate('movapd', [TOperand(OWordPtr(ridRAX))]); end);
end;

procedure TestCpuFeatures;
var
  R: System.TCPUIDRec;
  Expected: Boolean;
begin
  CheckTrue('name-aes', TCpuFeatures.Name(cfAES) = 'AES');
  CheckTrue('name-sha', TCpuFeatures.Name(cfSHA) = 'SHA');
  CheckTrue('name-lzcnt', TCpuFeatures.Name(cfLZCNT) = 'LZCNT');
  CheckTrue('name-bmi1', TCpuFeatures.Name(cfBMI1) = 'BMI1');

  R := System.GetCPUID(0);
  Expected := False;
  if R.EAX >= 1 then
  begin
    R := System.GetCPUID(1);
    Expected := (R.ECX and $02000000) <> 0;
  end;
  CheckTrue('detect-aes', TCpuFeatures.Supports(cfAES) = Expected);

  R := System.GetCPUID(0);
  Expected := False;
  if R.EAX >= 7 then
  begin
    R := System.GetCPUID(7, 0);
    Expected := (R.EBX and $20000000) <> 0;
  end;
  CheckTrue('detect-sha', TCpuFeatures.Supports(cfSHA) = Expected);

  R := System.GetCPUID($80000000);
  Expected := False;
  if R.EAX >= $80000001 then
  begin
    R := System.GetCPUID($80000001);
    Expected := (R.ECX and $00000020) <> 0;
  end;
  CheckTrue('detect-lzcnt', TCpuFeatures.Supports(cfLZCNT) = Expected);

  R := System.GetCPUID(0);
  Expected := False;
  if R.EAX >= 7 then
  begin
    R := System.GetCPUID(7, 0);
    Expected := (R.EBX and $00000008) <> 0;
  end;
  CheckTrue('detect-bmi1', TCpuFeatures.Supports(cfBMI1) = Expected);
end;

procedure TestWin64Abi;
var
  Usage: TWin64AbiUsage;
begin
  CheckTrue('gpr-rax-volatile', TWin64AbiValidator.IsVolatileGpr(ridRAX));
  CheckTrue('gpr-r11-volatile', TWin64AbiValidator.IsVolatileGpr(ridR11));
  CheckTrue('gpr-rbx-preserved', TWin64AbiValidator.RequiresPreservationGpr(ridRBX));
  CheckTrue('gpr-r15-preserved', TWin64AbiValidator.RequiresPreservationGpr(ridR15));
  CheckTrue('xmm0-volatile', TWin64AbiValidator.IsVolatileXmm(0));
  CheckTrue('xmm5-volatile', TWin64AbiValidator.IsVolatileXmm(5));
  CheckTrue('xmm6-preserved', TWin64AbiValidator.RequiresPreservationXmm(6));
  CheckTrue('xmm15-preserved', TWin64AbiValidator.RequiresPreservationXmm(15));

  Usage := Default(TWin64AbiUsage);
  Usage.ModifiedGprs := [ridRAX, ridRCX, ridR11];
  ExpectNoException('allows-volatile-gpr', procedure begin TWin64AbiValidator.Validate(Usage); end);

  Usage := Default(TWin64AbiUsage);
  Usage.ModifiedGprs := [ridRBX];
  ExpectAbiViolation('rejects-modified-rbx', 'RBX is nonvolatile', procedure begin TWin64AbiValidator.Validate(Usage); end);

  Usage.SavedGprs := [ridRBX];
  ExpectAbiViolation('rejects-unrestored-rbx', 'RBX is nonvolatile', procedure begin TWin64AbiValidator.Validate(Usage); end);

  Usage.RestoredGprs := [ridRBX];
  ExpectNoException('allows-saved-restored-rbx', procedure begin TWin64AbiValidator.Validate(Usage); end);

  Usage := Default(TWin64AbiUsage);
  Usage.ModifiedXmm := TWin64AbiValidator.Xmm(5);
  ExpectNoException('allows-volatile-xmm5', procedure begin TWin64AbiValidator.Validate(Usage); end);

  Usage := Default(TWin64AbiUsage);
  Usage.ModifiedXmm := TWin64AbiValidator.Xmm(6);
  ExpectAbiViolation('rejects-modified-xmm6', 'XMM6 is nonvolatile', procedure begin TWin64AbiValidator.Validate(Usage); end);

  Usage.SavedXmm := TWin64AbiValidator.Xmm(6);
  ExpectAbiViolation('rejects-unrestored-xmm6', 'XMM6 is nonvolatile', procedure begin TWin64AbiValidator.Validate(Usage); end);

  Usage.RestoredXmm := TWin64AbiValidator.Xmm(6);
  ExpectNoException('allows-saved-restored-xmm6', procedure begin TWin64AbiValidator.Validate(Usage); end);
end;

procedure TestLabelAndAlignment;
var
  B: TAsmBuilder;
  L: TLabel;
begin
  B := TAsmBuilder.New;
  L := B.NewLabel;
  B.J(cond_JMP, L).Nop.Bind(L);
  CheckHex('jmp-forward', B, 'E9 01 00 00 00 90');

  B := TAsmBuilder.New;
  L := B.NewLabel;
  B.Bind(L).Nop.J(cond_JMP, L);
  CheckHex('jmp-backward', B, '90 E9 FA FF FF FF');

  B := TAsmBuilder.New;
  L := B.NewLabel;
  B.J(cond_JE, L).Nop.Bind(L);
  CheckHex('jz-forward', B, '0F 84 01 00 00 00 90');

  B := TAsmBuilder.New;
  L := B.NewLabel;
  B.CallLabel(L).Nop.Bind(L).Ret;
  CheckHex('call-forward', B, 'E8 01 00 00 00 90 C3');

  B := TAsmBuilder.New;
  B.EmitLabelOffset('data').EmitByte($90).Label_('data');
  CheckHex('label-offset', B, '05 00 00 00 90');

  B := TAsmBuilder.New;
  B.EmitLabelOffset('data', $11223344).EmitByte($90).Label_('data');
  CheckHex('label-offset-xor', B, '41 33 22 11 90');

  B := TAsmBuilder.New;
  L := B.NewLabel;
  B.J(cond_JMP, L).Label_('#1').Nop.Bind(L).Ret;
  CheckHex('integer-string-label-isolation', B, 'E9 01 00 00 00 90 C3');

  CheckHex('align-8-nop', TAsmBuilder.New.EmitByte($CC).AlignTo(8), 'CC 0F 1F 80 00 00 00 00');
  CheckHex('align-8-fill', TAsmBuilder.New.EmitByte($11).AlignTo(8, $CC), '11 CC CC CC CC CC CC CC');
  CheckHex('align-already', TAsmBuilder.New.EmitBytes([$11,$22,$33,$44,$55,$66,$77,$88]).AlignTo(8), '11 22 33 44 55 66 77 88');
  CheckHex('raw-emission', TAsmBuilder.New.EmitByte($11).EmitBytes([$22,$33,$44]), '11 22 33 44');

  B := TAsmBuilder.New;
  B.J(cond_JMP, 'missing');
  ExpectBuildFailure('unresolved-label', B);
end;

procedure TestRegisterWidthOutcomes;
const
  Values: array[0..5] of UInt64 = (0, 1, $FF, $1234, $FFFFFFFF, $1122334455667788);
var
  ByteExe, HighByteExe, WordExe, DWordExe, R8ByteExe: TExecutableCode;
  I: Integer;
begin
  ByteExe := CompileBuilder(TAsmBuilder.New.Xor_(EAX, EAX).Mov(AL, CL).Ret);
  HighByteExe := CompileBuilder(TAsmBuilder.New.Xor_(EAX, EAX).Mov(AH, CL).Ret);
  WordExe := CompileBuilder(TAsmBuilder.New.Xor_(EAX, EAX).Mov(AX, CX).Ret);
  DWordExe := CompileBuilder(TAsmBuilder.New.Mov(EAX, ECX).Ret);
  R8ByteExe := CompileBuilder(TAsmBuilder.New.Mov(R8, 0).Mov(R8B, CL).Mov(RAX, R8).Ret);
  try
    for I := 0 to High(Values) do
    begin
      CheckRun1('r8-' + IntToStr(I), ByteExe, Values[I], Values[I] and $FF);
      CheckRun1('r8-high-' + IntToStr(I), HighByteExe, Values[I], (Values[I] and $FF) shl 8);
      CheckRun1('r16-' + IntToStr(I), WordExe, Values[I], Values[I] and $FFFF);
      CheckRun1('r32-' + IntToStr(I), DWordExe, Values[I], Values[I] and $FFFFFFFF);
      CheckRun1('r8-extended-' + IntToStr(I), R8ByteExe, Values[I], Values[I] and $FF);
    end;
  finally
    ByteExe.Free;
    HighByteExe.Free;
    WordExe.Free;
    DWordExe.Free;
    R8ByteExe.Free;
  end;
end;

procedure TestArithmeticOutcomes;
const
  AValues: array[0..11] of UInt64 = (0, 1, 2, 7, 15, 31, 127, 255, 256, 1024, $1234, $12345678);
  BValues: array[0..11] of UInt64 = (0, 1, 3, 2, 7, 16, 5, 17, 255, 3, $321, 7);
var
  AddExe, SubExe, AndExe, OrExe, XorExe, ImulExe, NegExe, IncExe, DecExe, TestExe: TExecutableCode;
  I: Integer;
  A, B, Expected: UInt64;
begin
  AddExe := CompileBuilder(TAsmBuilder.New.Mov(RAX, RCX).Add(RAX, RDX).Ret);
  SubExe := CompileBuilder(TAsmBuilder.New.Mov(RAX, RCX).Sub(RAX, RDX).Ret);
  AndExe := CompileBuilder(TAsmBuilder.New.Mov(RAX, RCX).And_(RAX, RDX).Ret);
  OrExe := CompileBuilder(TAsmBuilder.New.Mov(RAX, RCX).Or_(RAX, RDX).Ret);
  XorExe := CompileBuilder(TAsmBuilder.New.Mov(RAX, RCX).Xor_(RAX, RDX).Ret);
  ImulExe := CompileBuilder(TAsmBuilder.New.Mov(RAX, RCX).Imul(RAX, RDX).Ret);
  NegExe := CompileBuilder(TAsmBuilder.New.Mov(RAX, RCX).Neg(RAX).Ret);
  IncExe := CompileBuilder(TAsmBuilder.New.Mov(RAX, RCX).Inc_(RAX).Ret);
  DecExe := CompileBuilder(TAsmBuilder.New.Mov(RAX, RCX).Dec_(RAX).Ret);
  TestExe := CompileBuilder(TAsmBuilder.New.Xor_(EAX, EAX).Test(RCX, RDX).Setcc(cond_JE, AL).Ret);
  try
    for I := 0 to High(AValues) do
    begin
      A := AValues[I];
      B := BValues[I];
      CheckRun2(Format('add-%d', [I]), AddExe, A, B, A + B);
      CheckRun2(Format('sub-%d', [I]), SubExe, A, B, Bits(Int64(A) - Int64(B)));
      CheckRun2(Format('and-%d', [I]), AndExe, A, B, A and B);
      CheckRun2(Format('or-%d', [I]), OrExe, A, B, A or B);
      CheckRun2(Format('xor-%d', [I]), XorExe, A, B, A xor B);
      CheckRun2(Format('imul-%d', [I]), ImulExe, A, B, UInt64(Int64(A) * Int64(B)));
      CheckRun1(Format('neg-%d', [I]), NegExe, A, Bits(-Int64(A)));
      CheckRun1(Format('inc-%d', [I]), IncExe, A, A + 1);
      if A = 0 then Expected := Bits(-1) else Expected := A - 1;
      CheckRun1(Format('dec-%d', [I]), DecExe, A, Expected);
      CheckRun2(Format('test-z-%d', [I]), TestExe, A, B, BoolValue((A and B) = 0));
    end;
  finally
    AddExe.Free;
    SubExe.Free;
    AndExe.Free;
    OrExe.Free;
    XorExe.Free;
    ImulExe.Free;
    NegExe.Free;
    IncExe.Free;
    DecExe.Free;
    TestExe.Free;
  end;
end;

procedure TestImmediateOutcomes;
const
  Imms: array[0..7] of Integer = (-129, -128, -1, 0, 1, 127, 128, $12345678);
  Inputs: array[0..3] of UInt64 = (0, 1, 17, $12345678);
var
  I, J: Integer;
  Imm: Integer;
  Exe: TExecutableCode;
  Expected: UInt64;
begin
  Exe := CompileBuilder(TAsmBuilder.New.Mov(RAX, 0).Ret);
  try CheckRun0('mov-0', Exe, 0); finally Exe.Free; end;
  Exe := CompileBuilder(TAsmBuilder.New.Mov(RAX, -1).Ret);
  try CheckRun0('mov--1', Exe, Bits(-1)); finally Exe.Free; end;
  Exe := CompileBuilder(TAsmBuilder.New.Mov(RAX, Int64($1122334455667788)).Ret);
  try CheckRun0('mov-imm64', Exe, $1122334455667788); finally Exe.Free; end;

  for I := 0 to High(Imms) do
  begin
    Imm := Imms[I];
    Exe := CompileBuilder(TAsmBuilder.New.Mov(RAX, RCX).Add(RAX, Imm).Ret);
    try
      for J := 0 to High(Inputs) do CheckRun1(Format('add-%d-%d', [Imm, J]), Exe, Inputs[J], Bits(Int64(Inputs[J]) + Imm));
    finally
      Exe.Free;
    end;

    Exe := CompileBuilder(TAsmBuilder.New.Mov(RAX, RCX).Sub(RAX, Imm).Ret);
    try
      for J := 0 to High(Inputs) do CheckRun1(Format('sub-%d-%d', [Imm, J]), Exe, Inputs[J], Bits(Int64(Inputs[J]) - Imm));
    finally
      Exe.Free;
    end;

    Exe := CompileBuilder(TAsmBuilder.New.Imul(RAX, RCX, Imm).Ret);
    try
      for J := 0 to High(Inputs) do CheckRun1(Format('imul-%d-%d', [Imm, J]), Exe, Inputs[J], Bits(Int64(Inputs[J]) * Imm));
    finally
      Exe.Free;
    end;

    Exe := CompileBuilder(TAsmBuilder.New.Push(Imm).Pop(RAX).Ret);
    try
      Expected := Bits(Imm);
      CheckRun0(Format('push-pop-%d', [Imm]), Exe, Expected);
    finally
      Exe.Free;
    end;
  end;
end;

procedure TestShiftRotateOutcomes;
const
  Counts: array[0..9] of UInt64 = (0, 1, 2, 7, 8, 31, 32, 63, 64, 65);
  RotateCounts: array[0..7] of Byte = (0, 1, 2, 7, 8, 31, 32, 63);
  Values: array[0..4] of UInt64 = (0, 1, $FF, $0123456789ABCDEF, $8000000000000001);
var
  ShlExe, ShrExe, SarExe, RolExe, RorExe: TExecutableCode;
  I, J, C: Integer;
  V: UInt64;
begin
  ShlExe := CompileBuilder(TAsmBuilder.New.Mov(RAX, RDX).Shl_(RAX, CL).Ret);
  ShrExe := CompileBuilder(TAsmBuilder.New.Mov(RAX, RDX).Shr_(RAX, CL).Ret);
  SarExe := CompileBuilder(TAsmBuilder.New.Mov(RAX, RDX).Sar(RAX, CL).Ret);
  try
    for I := 0 to High(Counts) do
      for J := 0 to High(Values) do
      begin
        C := Integer(Counts[I] and 63);
        V := Values[J];
        CheckRun2(Format('shl-c%d-v%d', [Integer(Counts[I]), J]), ShlExe, Counts[I], V, V shl C);
        CheckRun2(Format('shr-c%d-v%d', [Integer(Counts[I]), J]), ShrExe, Counts[I], V, V shr C);
        CheckRun2(Format('sar-c%d-v%d', [Integer(Counts[I]), J]), SarExe, Counts[I], V, ShiftSar(V, C));
      end;
  finally
    ShlExe.Free;
    ShrExe.Free;
    SarExe.Free;
  end;

  for I := 0 to High(RotateCounts) do
  begin
    RolExe := CompileBuilder(TAsmBuilder.New.Mov(RAX, RCX).Rol(RAX, RotateCounts[I]).Ret);
    RorExe := CompileBuilder(TAsmBuilder.New.Mov(RAX, RCX).Ror(RAX, RotateCounts[I]).Ret);
    try
      for J := 0 to High(Values) do
      begin
        CheckRun1(Format('rol-c%d-v%d', [Integer(RotateCounts[I]), J]), RolExe, Values[J], RotateLeft(Values[J], RotateCounts[I]));
        CheckRun1(Format('ror-c%d-v%d', [Integer(RotateCounts[I]), J]), RorExe, Values[J], RotateRight(Values[J], RotateCounts[I]));
      end;
    finally
      RolExe.Free;
      RorExe.Free;
    end;
  end;
end;

procedure TestImmediateShiftMatrix;
const
  Values: array[0..4] of UInt64 = (0, 1, $FF, $0123456789ABCDEF, $8000000000000001);
var
  ShlExe, ShrExe, SarExe, RolExe, RorExe: TExecutableCode;
  C, I: Integer;
  V: UInt64;
begin
  for C := 0 to 63 do
  begin
    ShlExe := CompileBuilder(TAsmBuilder.New.Mov(RAX, RCX).Shl_(RAX, C).Ret);
    ShrExe := CompileBuilder(TAsmBuilder.New.Mov(RAX, RCX).Shr_(RAX, C).Ret);
    SarExe := CompileBuilder(TAsmBuilder.New.Mov(RAX, RCX).Sar(RAX, C).Ret);
    RolExe := CompileBuilder(TAsmBuilder.New.Mov(RAX, RCX).Rol(RAX, Byte(C)).Ret);
    RorExe := CompileBuilder(TAsmBuilder.New.Mov(RAX, RCX).Ror(RAX, Byte(C)).Ret);
    try
      for I := 0 to High(Values) do
      begin
        V := Values[I];
        CheckRun1(Format('shl-c%d-v%d', [C, I]), ShlExe, V, V shl C);
        CheckRun1(Format('shr-c%d-v%d', [C, I]), ShrExe, V, V shr C);
        CheckRun1(Format('sar-c%d-v%d', [C, I]), SarExe, V, ShiftSar(V, C));
        CheckRun1(Format('rol-c%d-v%d', [C, I]), RolExe, V, RotateLeft(V, C));
        CheckRun1(Format('ror-c%d-v%d', [C, I]), RorExe, V, RotateRight(V, C));
      end;
    finally
      ShlExe.Free;
      ShrExe.Free;
      SarExe.Free;
      RolExe.Free;
      RorExe.Free;
    end;
  end;
end;

procedure TestConditionOutcomes;
var
  C: TCondition;
  I, J: Integer;
  A, B, Expected: UInt64;
  BranchExe, SetExe, CmovExe: TExecutableCode;
  Prefix: string;
begin
  for I := Ord(cond_JE) to Ord(cond_JBE) do
  begin
    C := TCondition(I);
    Prefix := ConditionName(C);
    BranchExe := CompileBranch(C);
    SetExe := CompileSetcc(C);
    CmovExe := CompileCmov(C);
    try
      for J := 0 to 9 do
      begin
        ComparePair(J, A, B);
        Expected := BoolValue(ConditionExpected(C, A, B));
        CheckRun2(Prefix + '-branch-' + IntToStr(J), BranchExe, A, B, Expected);
        CheckRun2(Prefix + '-setcc-' + IntToStr(J), SetExe, A, B, Expected);
        if Expected <> 0 then Expected := 222 else Expected := 111;
        CheckRun2(Prefix + '-cmov-' + IntToStr(J), CmovExe, A, B, Expected);
      end;
    finally
      BranchExe.Free;
      SetExe.Free;
      CmovExe.Free;
    end;
  end;
end;

procedure TestBitOutcomes;
const
  Values: array[0..8] of UInt64 = (1, 2, 3, $10, $100, $8000, $100000000, $8000000000000000, $0123456789ABCDEF);
var
  BsfExe, BsrExe, BswapExe, XchgExe: TExecutableCode;
  I: Integer;
begin
  BsfExe := CompileBuilder(TAsmBuilder.New.Bsf(RAX, RCX).Ret);
  BsrExe := CompileBuilder(TAsmBuilder.New.Bsr(RAX, RCX).Ret);
  BswapExe := CompileBuilder(TAsmBuilder.New.Mov(RAX, RCX).Bswap(RAX).Ret);
  XchgExe := CompileBuilder(TAsmBuilder.New.Mov(RAX, RCX).Mov(R10, RDX).Xchg(RAX, R10).Ret);
  try
    for I := 0 to High(Values) do
    begin
      CheckRun1('bsf-' + IntToStr(I), BsfExe, Values[I], FirstBit(Values[I]));
      CheckRun1('bsr-' + IntToStr(I), BsrExe, Values[I], LastBit(Values[I]));
      CheckRun1('bswap-' + IntToStr(I), BswapExe, Values[I], Swap64(Values[I]));
    end;
    for I := 0 to 8 do CheckRun2('xchg-' + IntToStr(I), XchgExe, UInt64(I + 10), UInt64(I + 100), UInt64(I + 100));
  finally
    BsfExe.Free;
    BsrExe.Free;
    BswapExe.Free;
    XchgExe.Free;
  end;
end;

procedure TestMemoryOutcomes;
var
  Data: array[0..7] of UInt64;
  I: Integer;
  Exe: TExecutableCode;
  Base: UInt64;
  B8: ShortInt;
  B16: SmallInt;
  B32: Integer;
  U8: Byte;
  U16: Word;
  Store8: Byte;
  Store16: Word;
  Store32: Cardinal;
  Store64: UInt64;
begin
  for I := 0 to High(Data) do Data[I] := UInt64($1111111111111111) * UInt64(I + 1);
  Base := UInt64(NativeUInt(@Data[0]));

  for I := 0 to High(Data) do
  begin
    Exe := CompileBuilder(TAsmBuilder.New.Mov(RAX, QWordPtr(ridRCX, I * 8)).Ret);
    try CheckRun1('load-qword-' + IntToStr(I), Exe, Base, Data[I]); finally Exe.Free; end;
  end;

  Exe := CompileBuilder(TAsmBuilder.New.Mov(RAX, QWordPtrSib(ridRCX, ridRDX, s1)).Ret);
  try
    for I := 0 to High(Data) do CheckRun2('sib-s1-' + IntToStr(I), Exe, Base, UInt64(I * 8), Data[I]);
  finally
    Exe.Free;
  end;

  Exe := CompileBuilder(TAsmBuilder.New.Mov(RAX, QWordPtrSib(ridRCX, ridRDX, s2)).Ret);
  try
    for I := 0 to High(Data) do CheckRun2('sib-s2-' + IntToStr(I), Exe, Base, UInt64(I * 4), Data[I]);
  finally
    Exe.Free;
  end;

  Exe := CompileBuilder(TAsmBuilder.New.Mov(RAX, QWordPtrSib(ridRCX, ridRDX, s4)).Ret);
  try
    for I := 0 to High(Data) do CheckRun2('sib-s4-' + IntToStr(I), Exe, Base, UInt64(I * 2), Data[I]);
  finally
    Exe.Free;
  end;

  Exe := CompileBuilder(TAsmBuilder.New.Mov(RAX, QWordPtrSib(ridRCX, ridRDX, s8)).Ret);
  try
    for I := 0 to High(Data) do CheckRun2('sib-s8-' + IntToStr(I), Exe, Base, UInt64(I), Data[I]);
  finally
    Exe.Free;
  end;

  Exe := CompileBuilder(TAsmBuilder.New.Mov(RAX, QWordPtrSib(ridRCX, ridR8, s8)).Ret);
  try
    for I := 0 to High(Data) do CheckRun3('sib-r8-' + IntToStr(I), Exe, Base, 0, UInt64(I), Data[I]);
  finally
    Exe.Free;
  end;

  Store64 := 0;
  Exe := CompileBuilder(TAsmBuilder.New.Mov(QWordPtr(ridRCX), RDX).Mov(RAX, RDX).Ret);
  try
    CheckRun2('store-qword-return', Exe, UInt64(NativeUInt(@Store64)), $1122334455667788, $1122334455667788);
    CheckUInt64('store-qword-memory', Store64, $1122334455667788);
  finally
    Exe.Free;
  end;

  Store32 := 0;
  Exe := CompileBuilder(TAsmBuilder.New.Mov(DWordPtr(ridRCX), EDX).Mov(EAX, EDX).Ret);
  try
    CheckRun2('store-dword-return', Exe, UInt64(NativeUInt(@Store32)), $89ABCDEF, $89ABCDEF);
    CheckUInt64('store-dword-memory', Store32, $89ABCDEF);
  finally
    Exe.Free;
  end;

  Store16 := 0;
  Exe := CompileBuilder(TAsmBuilder.New.Mov(WordPtr(ridRCX), DX).Movzx(EAX, WordPtr(ridRCX)).Ret);
  try
    CheckRun2('store-word-return', Exe, UInt64(NativeUInt(@Store16)), $BEEF, $BEEF);
    CheckUInt64('store-word-memory', Store16, $BEEF);
  finally
    Exe.Free;
  end;

  Store8 := 0;
  Exe := CompileBuilder(TAsmBuilder.New.Mov(BytePtr(ridRCX), DL).Movzx(EAX, BytePtr(ridRCX)).Ret);
  try
    CheckRun2('store-byte-return', Exe, UInt64(NativeUInt(@Store8)), $AB, $AB);
    CheckUInt64('store-byte-memory', Store8, $AB);
  finally
    Exe.Free;
  end;

  U8 := $FE;
  Exe := CompileBuilder(TAsmBuilder.New.Movzx(RAX, BytePtr(ridRCX)).Ret);
  try CheckRun1('movzx-byte', Exe, UInt64(NativeUInt(@U8)), $FE); finally Exe.Free; end;

  U16 := $FEDC;
  Exe := CompileBuilder(TAsmBuilder.New.Movzx(RAX, WordPtr(ridRCX)).Ret);
  try CheckRun1('movzx-word', Exe, UInt64(NativeUInt(@U16)), $FEDC); finally Exe.Free; end;

  B8 := -2;
  Exe := CompileBuilder(TAsmBuilder.New.Movsx(RAX, BytePtr(ridRCX)).Ret);
  try CheckRun1('movsx-byte-r64', Exe, UInt64(NativeUInt(@B8)), Bits(-2)); finally Exe.Free; end;

  Exe := CompileBuilder(TAsmBuilder.New.Movsx(EAX, BytePtr(ridRCX)).Ret);
  try CheckRun1('movsx-byte-r32', Exe, UInt64(NativeUInt(@B8)), $00000000FFFFFFFE); finally Exe.Free; end;

  B16 := -300;
  Exe := CompileBuilder(TAsmBuilder.New.Movsx(RAX, WordPtr(ridRCX)).Ret);
  try CheckRun1('movsx-word-r64', Exe, UInt64(NativeUInt(@B16)), Bits(-300)); finally Exe.Free; end;

  B32 := -1234567;
  Exe := CompileBuilder(TAsmBuilder.New.Movsx(RAX, DWordPtr(ridRCX)).Ret);
  try CheckRun1('movsxd-dword-r64', Exe, UInt64(NativeUInt(@B32)), Bits(-1234567)); finally Exe.Free; end;

  Exe := CompileBuilder(TAsmBuilder.New.Lea(RAX, TMemory.Create(ridRCX, 37)).Ret);
  try CheckRun1('lea-base-disp', Exe, Base, Base + 37); finally Exe.Free; end;

  Exe := CompileBuilder(TAsmBuilder.New.Lea(RAX, TMemory.CreateSib(ridRCX, ridRDX, s8, 16)).Ret);
  try CheckRun2('lea-sib', Exe, Base, 3, Base + 3 * 8 + 16); finally Exe.Free; end;

  Exe := CompileBuilder(TAsmBuilder.New.Lea(RAX, TMemory.CreateRip(0)).Ret);
  try CheckRun0('lea-rip', Exe, UInt64(NativeUInt(Exe.EntryPoint)) + 7); finally Exe.Free; end;
end;

procedure TestControlFlowOutcomes;
var
  B: TAsmBuilder;
  Exe: TExecutableCode;
  L: TLabel;
  I: Integer;
  Expected: UInt64;
begin
  B := TAsmBuilder.New;
  L := B.NewLabel;
  B.Mov(RAX, 0).Mov(RDX, RCX).Bind(L).Add(RAX, RDX).Dec_(RDX).J(cond_JNE, L).Ret;
  Exe := CompileBuilder(B);
  try
    for I := 1 to 32 do
    begin
      Expected := UInt64(I * (I + 1) div 2);
      CheckRun1('integer-label-loop-' + IntToStr(I), Exe, UInt64(I), Expected);
    end;
  finally
    Exe.Free;
  end;

  B := TAsmBuilder.New;
  B.Mov(RAX, 0).Mov(RDX, RCX).Label_('loop').Add(RAX, RDX).Dec_(RDX).J(cond_JNE, 'loop').Ret;
  Exe := CompileBuilder(B);
  try
    for I := 1 to 16 do
    begin
      Expected := UInt64(I * (I + 1) div 2);
      CheckRun1('string-label-loop-' + IntToStr(I), Exe, UInt64(I), Expected);
    end;
  finally
    Exe.Free;
  end;

  B := TAsmBuilder.New;
  L := B.NewLabel;
  B.Prolog(32).CallLabel(L).Epilog.Ret.Bind(L).Mov(RAX, 42).Ret;
  Exe := CompileBuilder(B);
  try CheckRun0('call-label', Exe, 42); finally Exe.Free; end;

  Exe := CompileBuilder(TAsmBuilder.New.Push(RCX).Pop(RAX).Ret);
  try
    for I := 0 to 15 do CheckRun1('push-pop-reg-' + IntToStr(I), Exe, UInt64(I * 17), UInt64(I * 17));
  finally
    Exe.Free;
  end;

  Exe := CompileBuilder(TAsmBuilder.New.Prolog(32).Mov(RAX, RCX).Epilog.Ret);
  try
    for I := 0 to 15 do CheckRun1('prolog-epilog-' + IntToStr(I), Exe, UInt64(I * 31), UInt64(I * 31));
  finally
    Exe.Free;
  end;
end;

procedure TestDirectRunOverloads;
var
  B: TAsmBuilder;
  Actual: UInt64;
begin
  B := TAsmBuilder.New.Mov(RAX, 42).Ret;
  try Actual := B.Run; CheckUInt64('run0', Actual, 42); finally B.Free; end;

  B := TAsmBuilder.New.Mov(RAX, RCX).Ret;
  try Actual := B.Run(11); CheckUInt64('run1', Actual, 11); finally B.Free; end;

  B := TAsmBuilder.New.Mov(RAX, RCX).Add(RAX, RDX).Ret;
  try Actual := B.Run(11, 22); CheckUInt64('run2', Actual, 33); finally B.Free; end;

  B := TAsmBuilder.New.Mov(RAX, RCX).Add(RAX, RDX).Add(RAX, R8).Ret;
  try Actual := B.Run(11, 22, 33); CheckUInt64('run3', Actual, 66); finally B.Free; end;

  B := TAsmBuilder.New.Mov(RAX, RCX).Add(RAX, RDX).Add(RAX, R8).Add(RAX, R9).Ret;
  try Actual := B.Run(11, 22, 33, 44); CheckUInt64('run4', Actual, 110); finally B.Free; end;
end;

function Sum4(A, B, C, D: UInt64): UInt64; stdcall;
begin
  Result := A + B + C + D;
end;

function Sum6(A, B, C, D, E, F: UInt64): UInt64; stdcall;
begin
  Result := A + B + C + D + E + F;
end;

procedure TestExtensionsOutcomes;
var
  SB: TSmartAsmBuilder;
  Exe, Exe2: TExecutableCode;
  Pool: TJitAllocator;
  B: TAsmBuilder;
begin
  SB := TSmartAsmBuilder.Create;
  SB.Zero(RAX).Ret;
  Exe := SB.CompileToExecutable;
  try CheckRun0('smart-zero', Exe, 0); finally Exe.Free; SB.Free; end;

  SB := TSmartAsmBuilder.Create;
  SB.Zero(RAX).LoopBegin(RDX, 7, 'loop').Inc_(RAX);
  SB.LoopEnd(RDX, 'loop').Ret;
  Exe := SB.CompileToExecutable;
  try CheckRun0('smart-loop', Exe, 7); finally Exe.Free; SB.Free; end;

  SB := TSmartAsmBuilder.Create;
  SB.SaveRegs([RBX, R12]).Mov(RBX, 100).Mov(R12, 23).Mov(RAX, RBX).Add(RAX, R12);
  SB.RestoreRegs([RBX, R12]).Ret;
  Exe := SB.CompileToExecutable;
  try CheckRun0('smart-save-restore', Exe, 123); finally Exe.Free; SB.Free; end;

  SB := TSmartAsmBuilder.Create;
  SB.CallWin64(Pointer(@Sum4), [1, 2, 3, 4]).Ret;
  Exe := SB.CompileToExecutable;
  try CheckRun0('call-win64-4', Exe, 10); finally Exe.Free; SB.Free; end;

  SB := TSmartAsmBuilder.Create;
  SB.CallWin64(Pointer(@Sum6), [1, 2, 3, 4, 5, 6]).Ret;
  Exe := SB.CompileToExecutable;
  try CheckRun0('call-win64-6', Exe, 21); finally Exe.Free; SB.Free; end;

  B := TAsmBuilder.New.Prolog(32).Call(Pointer(@Sum4)).Epilog.Ret;
  Exe := CompileBuilder(B);
  try CheckRun4('call-pointer', Exe, 1, 2, 3, 4, 10); finally Exe.Free; end;

  B := TAsmBuilder.New.EmitBytes([$B8,$00,$00,$00,$00,$C3]);
  Exe := CompileBuilder(B);
  try
    Exe.PatchDWord(1, $12345678);
    CheckRun0('patch-dword', Exe, $12345678);
  finally
    Exe.Free;
  end;

  B := TAsmBuilder.New.EmitBytes([$48,$B8,$00,$00,$00,$00,$00,$00,$00,$00,$C3]);
  Exe := CompileBuilder(B);
  try
    Exe.PatchQWord(2, $1122334455667788);
    CheckRun0('patch-qword', Exe, $1122334455667788);
  finally
    Exe.Free;
  end;

  Pool := TJitAllocator.Create;
  try
    Exe := CompileBuilderPool(TAsmBuilder.New.Mov(RAX, 111).Ret, Pool);
    Exe2 := CompileBuilderPool(TAsmBuilder.New.Mov(RAX, 222).Ret, Pool);
    try
      CheckRun0('jit-pool-1', Exe, 111);
      CheckRun0('jit-pool-2', Exe2, 222);
    finally
      Exe.Free;
      Exe2.Free;
    end;
  finally
    Pool.Free;
  end;
end;

procedure TestValidation;
var
  B: TAsmBuilder;
  L: TLabel;
  E: TExecutableCode;
  SB: TSmartAsmBuilder;
begin
  ExpectBuilderFailure('movzx-reg-source', procedure(X: TAsmBuilder) begin X.Movzx(RAX, RCX); end);
  ExpectBuilderFailure('movzx-unsized-memory', procedure(X: TAsmBuilder) begin X.Movzx(RAX, TMemory.Create(ridRCX)); end);
  ExpectBuilderFailure('movzx-dword-memory', procedure(X: TAsmBuilder) begin X.Movzx(RAX, DWordPtr(ridRCX)); end);
  ExpectBuilderFailure('movzx-r16-rm16-missing', procedure(X: TAsmBuilder) begin X.Movzx(AX, WordPtr(ridRCX)); end);
  ExpectBuilderFailure('movsx-reg-source', procedure(X: TAsmBuilder) begin X.Movsx(RAX, RCX); end);
  ExpectBuilderFailure('movsx-unsized-memory', procedure(X: TAsmBuilder) begin X.Movsx(RAX, TMemory.Create(ridRCX)); end);
  ExpectBuilderFailure('add-unsized-memory', procedure(X: TAsmBuilder) begin X.Add(TMemory.Create(ridRCX), 1); end);
  ExpectBuilderFailure('sub-unsized-memory', procedure(X: TAsmBuilder) begin X.Sub(TMemory.Create(ridRCX), 1); end);
  ExpectBuilderFailure('and-unsized-memory', procedure(X: TAsmBuilder) begin X.And_(TMemory.Create(ridRCX), 1); end);
  ExpectBuilderFailure('or-unsized-memory', procedure(X: TAsmBuilder) begin X.Or_(TMemory.Create(ridRCX), 1); end);
  ExpectBuilderFailure('xor-unsized-memory', procedure(X: TAsmBuilder) begin X.Xor_(TMemory.Create(ridRCX), 1); end);
  ExpectBuilderFailure('cmp-unsized-memory', procedure(X: TAsmBuilder) begin X.Cmp(TMemory.Create(ridRCX), 1); end);
  ExpectBuilderFailure('mov-width-mismatch', procedure(X: TAsmBuilder) begin X.Mov(RAX, ECX); end);
  ExpectBuilderFailure('add-width-mismatch', procedure(X: TAsmBuilder) begin X.Add(RAX, ECX); end);
  ExpectBuilderFailure('xchg-width-mismatch', procedure(X: TAsmBuilder) begin X.Xchg(RAX, ECX); end);
  ExpectBuilderFailure('imul-width-mismatch', procedure(X: TAsmBuilder) begin X.Imul(RAX, ECX); end);
  ExpectBuilderFailure('bsf-width-mismatch', procedure(X: TAsmBuilder) begin X.Bsf(RAX, ECX); end);
  ExpectBuilderFailure('bsr-width-mismatch', procedure(X: TAsmBuilder) begin X.Bsr(RAX, ECX); end);
  ExpectBuilderFailure('popcnt-width-mismatch', procedure(X: TAsmBuilder) begin X.Popcnt(RAX, ECX); end);
  ExpectBuilderFailure('setcc-r32', procedure(X: TAsmBuilder) begin X.Setcc(cond_JE, EAX); end);
  ExpectBuilderFailure('setcc-jmp', procedure(X: TAsmBuilder) begin X.Setcc(cond_JMP, AL); end);
  ExpectBuilderFailure('cmov-jmp', procedure(X: TAsmBuilder) begin X.Cmov(cond_JMP, RAX, RCX); end);
  ExpectBuilderFailure('shift-count-register', procedure(X: TAsmBuilder) begin X.Shl_(RAX, RDX); end);
  ExpectBuilderFailure('shl-negative-count', procedure(X: TAsmBuilder) begin X.Shl_(RAX, -1); end);
  ExpectBuilderFailure('shl-count-64', procedure(X: TAsmBuilder) begin X.Shl_(RAX, 64); end);
  ExpectBuilderFailure('shr-count-64', procedure(X: TAsmBuilder) begin X.Shr_(RAX, 64); end);
  ExpectBuilderFailure('sar-count-64', procedure(X: TAsmBuilder) begin X.Sar(RAX, 64); end);
  ExpectBuilderFailure('rol-count-64', procedure(X: TAsmBuilder) begin X.Rol(RAX, 64); end);
  ExpectBuilderFailure('ror-count-64', procedure(X: TAsmBuilder) begin X.Ror(RAX, 64); end);
  ExpectBuilderFailure('call-immediate', procedure(X: TAsmBuilder) begin X.Call(TOperand(Int64(1))); end);
  ExpectBuilderFailure('pop-immediate', procedure(X: TAsmBuilder) begin X.Pop(TOperand(Int64(1))); end);
  ExpectBuilderFailure('bswap-r16', procedure(X: TAsmBuilder) begin X.Bswap(AX); end);
  ExpectBuilderFailure('bswap-r32', procedure(X: TAsmBuilder) begin X.Bswap(EAX); end);
  ExpectBuilderFailure('high-byte-with-r8b', procedure(X: TAsmBuilder) begin X.Mov(AH, R8B); end);
  ExpectBuilderFailure('spl-with-high-byte', procedure(X: TAsmBuilder) begin X.Mov(SPL, AH); end);

  ExpectBuilderFailure('memory-rip-base', procedure(X: TAsmBuilder) begin X.Mov(RAX, TMemory.Create(ridRIP)); end);
  ExpectBuilderFailure('sib-rsp-index', procedure(X: TAsmBuilder) begin X.Mov(RAX, TMemory.CreateSib(ridRAX, ridRSP, s2)); end);
  ExpectBuilderFailure('sib-rip-index', procedure(X: TAsmBuilder) begin X.Mov(RAX, TMemory.CreateSib(ridRAX, ridRIP, s2)); end);
  ExpectBuilderFailure('sib-rip-base', procedure(X: TAsmBuilder) begin X.Mov(RAX, TMemory.CreateSib(ridRIP, ridRCX, s2)); end);

  ExpectException('align-not-power-of-two', procedure begin B := TAsmBuilder.New; try B.AlignTo(3); finally B.Free; end; end);
  ExpectException('prolog-too-small', procedure begin B := TAsmBuilder.New; try B.Prolog(16); finally B.Free; end; end);
  ExpectException('prolog-not-aligned', procedure begin B := TAsmBuilder.New; try B.Prolog(40); finally B.Free; end; end);
  ExpectException('invalid-label-jump', procedure begin B := TAsmBuilder.New; try B.J(cond_JMP, TLabel.Invalid); finally B.Free; end; end);
  ExpectException('invalid-label-call', procedure begin B := TAsmBuilder.New; try B.CallLabel(TLabel.Invalid); finally B.Free; end; end);

  ExpectException('duplicate-string-label', procedure begin B := TAsmBuilder.New; try B.Label_('x').Label_('x'); finally B.Free; end; end);
  ExpectException('duplicate-integer-label', procedure begin B := TAsmBuilder.New; try L := B.NewLabel; B.Bind(L).Bind(L); finally B.Free; end; end);
  ExpectException('from-builder-nil', procedure begin E := TExecutableCode.FromBuilder(nil); E.Free; end);
  ExpectException('smart-loop-zero', procedure begin SB := TSmartAsmBuilder.Create; try SB.LoopBegin(RDX, 0, 'x'); finally SB.Free; end; end);
  ExpectException('smart-loop-negative', procedure begin SB := TSmartAsmBuilder.Create; try SB.LoopBegin(RDX, -1, 'x'); finally SB.Free; end; end);

  B := TAsmBuilder.New.EmitByte($C3);
  ExpectException('patch-dword-range', procedure begin E := CompileBuilder(B); B := nil; try E.PatchDWord(1, 1); finally E.Free; end; end);
end;

procedure RunGroup(const Name: string; Proc: TTestProc);
begin
  GGroup := Name;
  Writeln('[', Name, ']');
  try
    Proc;
  except
    on E: Exception do
    begin
      Inc(GTotal);
      FailCase('group-exception', E.ClassName + ': ' + E.Message);
    end;
  end;
end;

begin
  GTotal := 0;
  GPassed := 0;
  GFailed := 0;
  Writeln('NativeAsm Pro Tests');
  Writeln;
  RunGroup('database', TestDatabase);
  RunGroup('golden-encodings', TestGoldenEncodings);
  RunGroup('memory-alignment-metadata', TestMemoryAlignmentMetadata);
  RunGroup('rules-infrastructure', TestRulesInfrastructure);
  RunGroup('cpu-features', TestCpuFeatures);
  RunGroup('win64-abi', TestWin64Abi);
  RunGroup('labels-alignment', TestLabelAndAlignment);
  RunGroup('register-width-outcomes', TestRegisterWidthOutcomes);
  RunGroup('arithmetic-outcomes', TestArithmeticOutcomes);
  RunGroup('immediate-outcomes', TestImmediateOutcomes);
  RunGroup('shift-rotate-outcomes', TestShiftRotateOutcomes);
  RunGroup('immediate-shift-matrix', TestImmediateShiftMatrix);
  RunGroup('condition-outcomes', TestConditionOutcomes);
  RunGroup('bit-outcomes', TestBitOutcomes);
  RunGroup('memory-outcomes', TestMemoryOutcomes);
  RunGroup('control-flow-outcomes', TestControlFlowOutcomes);
  RunGroup('direct-run-overloads', TestDirectRunOverloads);
  RunGroup('extensions-outcomes', TestExtensionsOutcomes);
  RunGroup('validation', TestValidation);
  Writeln;
  Writeln(Format('RESULT total=%d passed=%d failed=%d', [GTotal, GPassed, GFailed]));
  if GFailed = 0 then Writeln('NativeAsmProTests: OK') else ExitCode := 1;
end.
