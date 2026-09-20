{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
{ Test design and vectors adapted from AsmJit. See Tests/ASMJIT_TEST_SOURCE.md. }unit NativeAsm.Tests.AsmJit;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TNativeAsmAsmJitTests = class
  public
    [Test]
    procedure Database;
    [Test]
    procedure GoldenEncodings;
    [Test]
    procedure LabelsAndAlignment;
    [Test]
    procedure RegisterWidthOutcomes;
    [Test]
    procedure ArithmeticOutcomes;
    [Test]
    procedure ImmediateOutcomes;
    [Test]
    procedure ShiftRotateOutcomes;
    [Test]
    procedure ImmediateShiftMatrix;
    [Test]
    procedure ConditionOutcomes;
    [Test]
    procedure BitOutcomes;
    [Test]
    procedure MemoryOutcomes;
    [Test]
    procedure ControlFlowOutcomes;
    [Test]
    procedure DirectRunOverloads;
    [Test]
    procedure ExtensionsOutcomes;
    [Test]
    procedure Validation;
    [Test]
    procedure AdditionalArithmeticEncodings;
    [Test]
    procedure AdditionalMoveEncodings;
    [Test]
    procedure AdditionalConditionEncodings;
    [Test]
    procedure AdditionalUnaryEncodings;
    [Test]
    procedure AdditionalBitAndAddressEncodings;
    [Test]
    procedure AdditionalStackEncodings;
    [Test]
    procedure AdditionalShiftRotateEncodings;
    [Test]
    procedure AdditionalXchgEncodings;
    [Test]
    procedure DebugLabelSnapshot;
    [Test]
    procedure DebugAddressResolution;
    [Test]
    procedure DebugMapRoundTrip;
    [Test]
    procedure DebugRegistryValidation;
    [Test]
    procedure InstructionMapDecode;
    [Test]
    procedure InstructionMapResolve;
    [Test]
    procedure InstructionMapUnknownByte;
    [Test]
    procedure InstructionMapPrefixesAndMemory;
    [Test]
    procedure BreakpointPatchLifecycle;
    [Test]
    procedure BreakpointRuntimeContinue;
    [Test]
    procedure BreakpointValidation;
    [Test]
    procedure BreakpointCallbackIsolation;
    [Test]
    procedure DisassemblerSupportedCode;
    [Test]
    procedure DisassemblerSourceOnlyForm;
    [Test]
    procedure DisassemblerMetadata;
    [Test]
    procedure DisassemblerUnknownFallback;
    [Test]
    procedure SimdDatabase;
    [Test]
    procedure SimdSseFamilyEncodings;
    [Test]
    procedure SimdMemoryAndExtendedRegisterEncodings;
    [Test]
    procedure SimdValidation;
    [Test]
    procedure AesNiEncodings;
    [Test]
    procedure AesNiMemoryAndExtended;
    [Test]
    procedure ShaEncodings;
    [Test]
    procedure ShaMemoryAndValidation;
    [Test]
    procedure BitCountEncodings;
    [Test]
    procedure BitCountValidation;
    [Test]
    procedure AsmJitEncodingMatrix;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  NativeAsm.Types,
  NativeAsm.Builder,
  NativeAsm.InstructionDB,
  NativeAsm.InstructionDB.Generated,
  NativeAsm.Extensions,
  NativeAsm.JitAlloc,
  NativeAsm.Debug,
  NativeAsm.Disassembler,
  NativeAsm.Simd.Types,
  NativeAsm.Simd.Db,
  NativeAsm.Simd,
  NativeAsm.BitManip;

type
  TTestProc = reference to procedure;
  TBuilderAction = reference to procedure(B: TAsmBuilder);

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

procedure CheckTrue(const Name: string; Value: Boolean; const Msg: string = 'condition is false');
begin
  Assert.IsTrue(Value, Name + ': ' + Msg);
end;

procedure CheckInt(const Name: string; Actual, Expected: Int64);
begin
  Assert.IsTrue(Actual = Expected, Name + ': ' + Format('%d <> %d', [Actual, Expected]));
end;

procedure CheckUInt64(const Name: string; Actual, Expected: UInt64);
begin
  Assert.IsTrue(Actual = Expected, Name + ': ' + Format('$%s <> $%s', [HexU64(Actual), HexU64(Expected)]));
end;

procedure CheckHex(const Name: string; B: TAsmBuilder; const Expected: string);
var
  Actual: TBytes;
  ActualHex, ExpectedHex: string;
begin
  try
    Actual := B.Build;
    ActualHex := HexOf(Actual);
    ExpectedHex := NormalizeHex(Expected);
    Assert.IsTrue(SameText(ActualHex, ExpectedHex), Name + ': ' + ActualHex + ' <> ' + ExpectedHex);
  finally
    B.Free;
  end;
end;

procedure CheckRun0(const Name: string; Exe: TExecutableCode; Expected: UInt64);
var
  Actual: UInt64;
begin
  Actual := Exe.Run;
  CheckUInt64(Name, Actual, Expected);
end;

procedure CheckRun1(const Name: string; Exe: TExecutableCode; A1, Expected: UInt64);
var
  Actual: UInt64;
begin
  Actual := Exe.Run(A1);
  CheckUInt64(Name, Actual, Expected);
end;

procedure CheckRun2(const Name: string; Exe: TExecutableCode; A1, A2, Expected: UInt64);
var
  Actual: UInt64;
begin
  Actual := Exe.Run(A1, A2);
  CheckUInt64(Name, Actual, Expected);
end;

procedure CheckRun3(const Name: string; Exe: TExecutableCode; A1, A2, A3, Expected: UInt64);
var
  Actual: UInt64;
begin
  Actual := Exe.Run(A1, A2, A3);
  CheckUInt64(Name, Actual, Expected);
end;

procedure CheckRun4(const Name: string; Exe: TExecutableCode; A1, A2, A3, A4, Expected: UInt64);
var
  Actual: UInt64;
begin
  Actual := Exe.Run(A1, A2, A3, A4);
  CheckUInt64(Name, Actual, Expected);
end;

procedure ExpectException(const Name: string; Action: TTestProc);
var
  Raised: Boolean;
begin
  Raised := False;
  try
    Action;
  except
    on E: Exception do Raised := True;
  end;
  Assert.IsTrue(Raised, Name + ': exception expected');
end;

procedure ExpectBuilderFailure(const Name: string; Action: TBuilderAction);
var
  B: TAsmBuilder;
  Raised: Boolean;
begin
  B := TAsmBuilder.New;
  try
    Raised := False;
    try
      Action(B);
    except
      on E: Exception do Raised := True;
    end;
    Assert.IsTrue(Raised, Name + ': exception expected');
    Assert.IsTrue(B.CodeSize = 0, Name + ': partial emission: ' + IntToStr(B.CodeSize) + ' bytes');
  finally
    B.Free;
  end;
end;

procedure ExpectBuildFailure(const Name: string; B: TAsmBuilder);
var
  Raised: Boolean;
begin
  try
    Raised := False;
    try
      B.Build;
    except
      on E: Exception do Raised := True;
    end;
    Assert.IsTrue(Raised, Name + ': Build exception expected');
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

procedure TNativeAsmAsmJitTests.Database;
begin
  TInstructionDb.ValidateGeneratedDb;
  CheckInt('form-count', CInstructionFormCount, 470);
  CheckInt('mnemonic-count', CInstructionMnemonicCount, 94);
  CheckInt('operand-count', CInstructionOperandCount, 850);
  CheckTrue('source-sha256', Length(CInstructionDbSourceSha256) = 64);
end;

procedure TNativeAsmAsmJitTests.GoldenEncodings;
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

procedure TNativeAsmAsmJitTests.LabelsAndAlignment;
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

procedure TNativeAsmAsmJitTests.RegisterWidthOutcomes;
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

procedure TNativeAsmAsmJitTests.ArithmeticOutcomes;
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

procedure TNativeAsmAsmJitTests.ImmediateOutcomes;
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

procedure TNativeAsmAsmJitTests.ShiftRotateOutcomes;
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

procedure TNativeAsmAsmJitTests.ImmediateShiftMatrix;
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

procedure TNativeAsmAsmJitTests.ConditionOutcomes;
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

procedure TNativeAsmAsmJitTests.BitOutcomes;
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

procedure TNativeAsmAsmJitTests.MemoryOutcomes;
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

procedure TNativeAsmAsmJitTests.ControlFlowOutcomes;
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

procedure TNativeAsmAsmJitTests.DirectRunOverloads;
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

procedure TNativeAsmAsmJitTests.ExtensionsOutcomes;
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

procedure TNativeAsmAsmJitTests.Validation;
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

procedure TNativeAsmAsmJitTests.AdditionalArithmeticEncodings;
begin
  CheckHex('add bl,ah', TAsmBuilder.New.Add(BL, AH), '02 DC');
  CheckHex('add dl,ch', TAsmBuilder.New.Add(DL, CH), '02 D5');
  CheckHex('add [rcx],dl', TAsmBuilder.New.Add(BytePtr(ridRCX), DL), '00 11');
  CheckHex('add [rcx],cl', TAsmBuilder.New.Add(BytePtr(ridRCX), CL), '00 09');
  CheckHex('add [rcx],cx', TAsmBuilder.New.Add(WordPtr(ridRCX), CX), '66 01 09');
  CheckHex('add [rcx],ecx', TAsmBuilder.New.Add(DWordPtr(ridRCX), ECX), '01 09');
  CheckHex('add [rcx],rcx', TAsmBuilder.New.Add(QWordPtr(ridRCX), RCX), '48 01 09');
  CheckHex('add cl,1', TAsmBuilder.New.Add(CL, 1), '80 C1 01');
  CheckHex('add ecx,1', TAsmBuilder.New.Add(ECX, 1), '83 C1 01');
  CheckHex('add rcx,1', TAsmBuilder.New.Add(RCX, 1), '48 83 C1 01');
  CheckHex('add ecx,imm32', TAsmBuilder.New.Add(ECX, $12345678), '81 C1 78 56 34 12');
  CheckHex('add [rcx],byte 1', TAsmBuilder.New.Add(BytePtr(ridRCX), 1), '80 01 01');
  CheckHex('add [rcx],dword 1', TAsmBuilder.New.Add(DWordPtr(ridRCX), 1), '83 01 01');
  CheckHex('or cx,dx', TAsmBuilder.New.Or_(CX, DX), '66 0B CA');
  CheckHex('or ecx,edx', TAsmBuilder.New.Or_(ECX, EDX), '0B CA');
  CheckHex('or rcx,rdx', TAsmBuilder.New.Or_(RCX, RDX), '48 0B CA');
  CheckHex('or [rcx],cl', TAsmBuilder.New.Or_(BytePtr(ridRCX), CL), '08 09');
  CheckHex('or [rcx],ecx', TAsmBuilder.New.Or_(DWordPtr(ridRCX), ECX), '09 09');
  CheckHex('or [rcx],rcx', TAsmBuilder.New.Or_(QWordPtr(ridRCX), RCX), '48 09 09');
  CheckHex('or cl,1', TAsmBuilder.New.Or_(CL, 1), '80 C9 01');
  CheckHex('or ecx,imm32', TAsmBuilder.New.Or_(ECX, $12345678), '81 C9 78 56 34 12');
  CheckHex('and cx,dx', TAsmBuilder.New.And_(CX, DX), '66 23 CA');
  CheckHex('and ecx,edx', TAsmBuilder.New.And_(ECX, EDX), '23 CA');
  CheckHex('and rcx,rdx', TAsmBuilder.New.And_(RCX, RDX), '48 23 CA');
  CheckHex('and [rcx],cl', TAsmBuilder.New.And_(BytePtr(ridRCX), CL), '20 09');
  CheckHex('and [rcx],ecx', TAsmBuilder.New.And_(DWordPtr(ridRCX), ECX), '21 09');
  CheckHex('and [rcx],rcx', TAsmBuilder.New.And_(QWordPtr(ridRCX), RCX), '48 21 09');
  CheckHex('and cl,1', TAsmBuilder.New.And_(CL, 1), '80 E1 01');
  CheckHex('and ecx,imm32', TAsmBuilder.New.And_(ECX, $12345678), '81 E1 78 56 34 12');
  CheckHex('sub cl,dl', TAsmBuilder.New.Sub(CL, DL), '2A CA');
  CheckHex('sub cx,dx', TAsmBuilder.New.Sub(CX, DX), '66 2B CA');
  CheckHex('sub ecx,edx', TAsmBuilder.New.Sub(ECX, EDX), '2B CA');
  CheckHex('sub rcx,rdx', TAsmBuilder.New.Sub(RCX, RDX), '48 2B CA');
  CheckHex('sub [rcx],cl', TAsmBuilder.New.Sub(BytePtr(ridRCX), CL), '28 09');
  CheckHex('sub [rcx],ecx', TAsmBuilder.New.Sub(DWordPtr(ridRCX), ECX), '29 09');
  CheckHex('sub [rcx],rcx', TAsmBuilder.New.Sub(QWordPtr(ridRCX), RCX), '48 29 09');
  CheckHex('sub cl,1', TAsmBuilder.New.Sub(CL, 1), '80 E9 01');
  CheckHex('sub ecx,1', TAsmBuilder.New.Sub(ECX, 1), '83 E9 01');
  CheckHex('sub rcx,1', TAsmBuilder.New.Sub(RCX, 1), '48 83 E9 01');
  CheckHex('sub ecx,imm32', TAsmBuilder.New.Sub(ECX, $12345678), '81 E9 78 56 34 12');
  CheckHex('xor cx,dx', TAsmBuilder.New.Xor_(CX, DX), '66 33 CA');
  CheckHex('xor ecx,edx', TAsmBuilder.New.Xor_(ECX, EDX), '33 CA');
  CheckHex('xor rcx,rdx', TAsmBuilder.New.Xor_(RCX, RDX), '48 33 CA');
  CheckHex('xor [rcx],cl', TAsmBuilder.New.Xor_(BytePtr(ridRCX), CL), '30 09');
  CheckHex('xor [rcx],ecx', TAsmBuilder.New.Xor_(DWordPtr(ridRCX), ECX), '31 09');
  CheckHex('xor [rcx],rcx', TAsmBuilder.New.Xor_(QWordPtr(ridRCX), RCX), '48 31 09');
  CheckHex('xor cl,1', TAsmBuilder.New.Xor_(CL, 1), '80 F1 01');
  CheckHex('xor ecx,imm32', TAsmBuilder.New.Xor_(ECX, $12345678), '81 F1 78 56 34 12');
  CheckHex('cmp cx,dx', TAsmBuilder.New.Cmp(CX, DX), '66 3B CA');
  CheckHex('cmp ecx,edx', TAsmBuilder.New.Cmp(ECX, EDX), '3B CA');
  CheckHex('cmp rcx,rdx', TAsmBuilder.New.Cmp(RCX, RDX), '48 3B CA');
  CheckHex('cmp [rcx],cl', TAsmBuilder.New.Cmp(BytePtr(ridRCX), CL), '38 09');
  CheckHex('cmp [rcx],ecx', TAsmBuilder.New.Cmp(DWordPtr(ridRCX), ECX), '39 09');
  CheckHex('cmp [rcx],rcx', TAsmBuilder.New.Cmp(QWordPtr(ridRCX), RCX), '48 39 09');
  CheckHex('cmp cl,1', TAsmBuilder.New.Cmp(CL, 1), '80 F9 01');
  CheckHex('cmp ecx,imm32', TAsmBuilder.New.Cmp(ECX, $12345678), '81 F9 78 56 34 12');
  CheckHex('test cx,dx', TAsmBuilder.New.Test(CX, DX), '66 85 D1');
  CheckHex('test ecx,edx', TAsmBuilder.New.Test(ECX, EDX), '85 D1');
  CheckHex('test rcx,rdx', TAsmBuilder.New.Test(RCX, RDX), '48 85 D1');
  CheckHex('test [rcx],cl', TAsmBuilder.New.Test(BytePtr(ridRCX), CL), '84 09');
  CheckHex('test [rcx],ecx', TAsmBuilder.New.Test(DWordPtr(ridRCX), ECX), '85 09');
  CheckHex('test [rcx],rcx', TAsmBuilder.New.Test(QWordPtr(ridRCX), RCX), '48 85 09');
  CheckHex('test cl,1', TAsmBuilder.New.Test(CL, 1), 'F6 C1 01');
end;

procedure TNativeAsmAsmJitTests.AdditionalMoveEncodings;
begin
  CheckHex('mov cl,dl', TAsmBuilder.New.Mov(CL, DL), '8A CA');
  CheckHex('mov cx,dx', TAsmBuilder.New.Mov(CX, DX), '66 8B CA');
  CheckHex('mov ecx,edx', TAsmBuilder.New.Mov(ECX, EDX), '8B CA');
  CheckHex('mov rcx,rdx', TAsmBuilder.New.Mov(RCX, RDX), '48 8B CA');
  CheckHex('mov cl,dh', TAsmBuilder.New.Mov(CL, DH), '8A CE');
  CheckHex('mov ch,dl', TAsmBuilder.New.Mov(CH, DL), '8A EA');
  CheckHex('mov cl,[rcx]', TAsmBuilder.New.Mov(CL, BytePtr(ridRCX)), '8A 09');
  CheckHex('mov cx,[rcx]', TAsmBuilder.New.Mov(CX, WordPtr(ridRCX)), '66 8B 09');
  CheckHex('mov ecx,[rcx]', TAsmBuilder.New.Mov(ECX, DWordPtr(ridRCX)), '8B 09');
  CheckHex('mov rcx,[rcx]', TAsmBuilder.New.Mov(RCX, QWordPtr(ridRCX)), '48 8B 09');
  CheckHex('mov [rcx],cl', TAsmBuilder.New.Mov(BytePtr(ridRCX), CL), '88 09');
  CheckHex('mov [rcx],cx', TAsmBuilder.New.Mov(WordPtr(ridRCX), CX), '66 89 09');
  CheckHex('mov [rcx],ecx', TAsmBuilder.New.Mov(DWordPtr(ridRCX), ECX), '89 09');
  CheckHex('mov [rcx],rcx', TAsmBuilder.New.Mov(QWordPtr(ridRCX), RCX), '48 89 09');
  CheckHex('mov cl,1', TAsmBuilder.New.Mov(CL, 1), 'B1 01');
  CheckHex('mov ch,1', TAsmBuilder.New.Mov(CH, 1), 'B5 01');
  CheckHex('mov cx,1', TAsmBuilder.New.Mov(CX, 1), '66 B9 01 00');
  CheckHex('mov ecx,1', TAsmBuilder.New.Mov(ECX, 1), 'B9 01 00 00 00');
  CheckHex('mov rcx,1', TAsmBuilder.New.Mov(RCX, 1), '48 C7 C1 01 00 00 00');
  CheckHex('mov cl,[rcx+rdx*1+128]', TAsmBuilder.New.Mov(CL, BytePtrSib(ridRCX, ridRDX, s1, 128)), '8A 8C 11 80 00 00 00');
end;

procedure TNativeAsmAsmJitTests.AdditionalConditionEncodings;
begin
  CheckHex('cmove cx,dx', TAsmBuilder.New.Cmov(cond_JE, CX, DX), '66 0F 44 CA');
  CheckHex('cmove ecx,edx', TAsmBuilder.New.Cmov(cond_JE, ECX, EDX), '0F 44 CA');
  CheckHex('cmove rcx,rdx', TAsmBuilder.New.Cmov(cond_JE, RCX, RDX), '48 0F 44 CA');
  CheckHex('cmovne cx,dx', TAsmBuilder.New.Cmov(cond_JNE, CX, DX), '66 0F 45 CA');
  CheckHex('cmovne ecx,edx', TAsmBuilder.New.Cmov(cond_JNE, ECX, EDX), '0F 45 CA');
  CheckHex('cmovne rcx,rdx', TAsmBuilder.New.Cmov(cond_JNE, RCX, RDX), '48 0F 45 CA');
  CheckHex('cmovg cx,dx', TAsmBuilder.New.Cmov(cond_JG, CX, DX), '66 0F 4F CA');
  CheckHex('cmovg ecx,edx', TAsmBuilder.New.Cmov(cond_JG, ECX, EDX), '0F 4F CA');
  CheckHex('cmovg rcx,rdx', TAsmBuilder.New.Cmov(cond_JG, RCX, RDX), '48 0F 4F CA');
  CheckHex('cmovge cx,dx', TAsmBuilder.New.Cmov(cond_JGE, CX, DX), '66 0F 4D CA');
  CheckHex('cmovge ecx,edx', TAsmBuilder.New.Cmov(cond_JGE, ECX, EDX), '0F 4D CA');
  CheckHex('cmovge rcx,rdx', TAsmBuilder.New.Cmov(cond_JGE, RCX, RDX), '48 0F 4D CA');
  CheckHex('cmovl cx,dx', TAsmBuilder.New.Cmov(cond_JL, CX, DX), '66 0F 4C CA');
  CheckHex('cmovl ecx,edx', TAsmBuilder.New.Cmov(cond_JL, ECX, EDX), '0F 4C CA');
  CheckHex('cmovl rcx,rdx', TAsmBuilder.New.Cmov(cond_JL, RCX, RDX), '48 0F 4C CA');
  CheckHex('cmovle cx,dx', TAsmBuilder.New.Cmov(cond_JLE, CX, DX), '66 0F 4E CA');
  CheckHex('cmovle ecx,edx', TAsmBuilder.New.Cmov(cond_JLE, ECX, EDX), '0F 4E CA');
  CheckHex('cmovle rcx,rdx', TAsmBuilder.New.Cmov(cond_JLE, RCX, RDX), '48 0F 4E CA');
  CheckHex('cmova cx,dx', TAsmBuilder.New.Cmov(cond_JA, CX, DX), '66 0F 47 CA');
  CheckHex('cmova ecx,edx', TAsmBuilder.New.Cmov(cond_JA, ECX, EDX), '0F 47 CA');
  CheckHex('cmova rcx,rdx', TAsmBuilder.New.Cmov(cond_JA, RCX, RDX), '48 0F 47 CA');
  CheckHex('cmovae cx,dx', TAsmBuilder.New.Cmov(cond_JAE, CX, DX), '66 0F 43 CA');
  CheckHex('cmovae ecx,edx', TAsmBuilder.New.Cmov(cond_JAE, ECX, EDX), '0F 43 CA');
  CheckHex('cmovae rcx,rdx', TAsmBuilder.New.Cmov(cond_JAE, RCX, RDX), '48 0F 43 CA');
  CheckHex('cmovb cx,dx', TAsmBuilder.New.Cmov(cond_JB, CX, DX), '66 0F 42 CA');
  CheckHex('cmovb ecx,edx', TAsmBuilder.New.Cmov(cond_JB, ECX, EDX), '0F 42 CA');
  CheckHex('cmovb rcx,rdx', TAsmBuilder.New.Cmov(cond_JB, RCX, RDX), '48 0F 42 CA');
  CheckHex('cmovbe cx,dx', TAsmBuilder.New.Cmov(cond_JBE, CX, DX), '66 0F 46 CA');
  CheckHex('cmovbe ecx,edx', TAsmBuilder.New.Cmov(cond_JBE, ECX, EDX), '0F 46 CA');
  CheckHex('cmovbe rcx,rdx', TAsmBuilder.New.Cmov(cond_JBE, RCX, RDX), '48 0F 46 CA');
  CheckHex('sete cl', TAsmBuilder.New.Setcc(cond_JE, CL), '0F 94 C1');
  CheckHex('setne cl', TAsmBuilder.New.Setcc(cond_JNE, CL), '0F 95 C1');
  CheckHex('setg cl', TAsmBuilder.New.Setcc(cond_JG, CL), '0F 9F C1');
  CheckHex('setge cl', TAsmBuilder.New.Setcc(cond_JGE, CL), '0F 9D C1');
  CheckHex('setl cl', TAsmBuilder.New.Setcc(cond_JL, CL), '0F 9C C1');
  CheckHex('setle cl', TAsmBuilder.New.Setcc(cond_JLE, CL), '0F 9E C1');
  CheckHex('seta cl', TAsmBuilder.New.Setcc(cond_JA, CL), '0F 97 C1');
  CheckHex('setae cl', TAsmBuilder.New.Setcc(cond_JAE, CL), '0F 93 C1');
  CheckHex('setb cl', TAsmBuilder.New.Setcc(cond_JB, CL), '0F 92 C1');
  CheckHex('setbe cl', TAsmBuilder.New.Setcc(cond_JBE, CL), '0F 96 C1');
end;

procedure TNativeAsmAsmJitTests.AdditionalUnaryEncodings;
begin
  CheckHex('dec [rcx]b', TAsmBuilder.New.Dec_(BytePtr(ridRCX)), 'FE 09');
  CheckHex('dec [rcx]d', TAsmBuilder.New.Dec_(DWordPtr(ridRCX)), 'FF 09');
  CheckHex('dec [rcx]q', TAsmBuilder.New.Dec_(QWordPtr(ridRCX)), '48 FF 09');
  CheckHex('inc [rcx]b', TAsmBuilder.New.Inc_(BytePtr(ridRCX)), 'FE 01');
  CheckHex('inc [rcx]d', TAsmBuilder.New.Inc_(DWordPtr(ridRCX)), 'FF 01');
  CheckHex('inc [rcx]q', TAsmBuilder.New.Inc_(QWordPtr(ridRCX)), '48 FF 01');
  CheckHex('neg [rcx]b', TAsmBuilder.New.Neg(BytePtr(ridRCX)), 'F6 19');
  CheckHex('neg [rcx]d', TAsmBuilder.New.Neg(DWordPtr(ridRCX)), 'F7 19');
  CheckHex('neg [rcx]q', TAsmBuilder.New.Neg(QWordPtr(ridRCX)), '48 F7 19');
  CheckHex('not [rcx]b', TAsmBuilder.New.Not_(BytePtr(ridRCX)), 'F6 11');
  CheckHex('not [rcx]d', TAsmBuilder.New.Not_(DWordPtr(ridRCX)), 'F7 11');
  CheckHex('not [rcx]q', TAsmBuilder.New.Not_(QWordPtr(ridRCX)), '48 F7 11');
end;

procedure TNativeAsmAsmJitTests.AdditionalBitAndAddressEncodings;
begin
  CheckHex('bswap rcx', TAsmBuilder.New.Bswap(RCX), '48 0F C9');
  CheckHex('bswap rdx', TAsmBuilder.New.Bswap(RDX), '48 0F CA');
  CheckHex('imul cx,dx', TAsmBuilder.New.Imul(CX, DX), '66 0F AF CA');
  CheckHex('imul ecx,edx', TAsmBuilder.New.Imul(ECX, EDX), '0F AF CA');
  CheckHex('imul rcx,rdx', TAsmBuilder.New.Imul(RCX, RDX), '48 0F AF CA');
  CheckHex('imul ecx,edx,1', TAsmBuilder.New.Imul(ECX, EDX, 1), '6B CA 01');
  CheckHex('imul rcx,rdx,1', TAsmBuilder.New.Imul(RCX, RDX, 1), '48 6B CA 01');
  CheckHex('imul ecx,edx,imm32', TAsmBuilder.New.Imul(ECX, EDX, $12345678), '69 CA 78 56 34 12');
  CheckHex('lea eax,[rcx]', TAsmBuilder.New.Lea(EAX, TMemory.Create(ridRCX)), '8D 01');
  CheckHex('lea ecx,[rcx]', TAsmBuilder.New.Lea(ECX, TMemory.Create(ridRCX)), '8D 09');
  CheckHex('lea ecx,[rdx]', TAsmBuilder.New.Lea(ECX, TMemory.Create(ridRDX)), '8D 0A');
  CheckHex('lea rcx,[rdx]', TAsmBuilder.New.Lea(RCX, TMemory.Create(ridRDX)), '48 8D 0A');
  CheckHex('lea ecx,[rcx+rdx*4+16]', TAsmBuilder.New.Lea(ECX, TMemory.CreateSib(ridRCX, ridRDX, s4, 16, sz32)), '8D 4C 91 10');
  CheckHex('movsx ecx,[rcx]b', TAsmBuilder.New.Movsx(ECX, BytePtr(ridRCX)), '0F BE 09');
  CheckHex('movsx rcx,[rcx]b', TAsmBuilder.New.Movsx(RCX, BytePtr(ridRCX)), '48 0F BE 09');
  CheckHex('movsx ecx,[rcx]w', TAsmBuilder.New.Movsx(ECX, WordPtr(ridRCX)), '0F BF 09');
  CheckHex('movsx rcx,[rcx]w', TAsmBuilder.New.Movsx(RCX, WordPtr(ridRCX)), '48 0F BF 09');
  CheckHex('movzx ecx,[rcx]b', TAsmBuilder.New.Movzx(ECX, BytePtr(ridRCX)), '0F B6 09');
  CheckHex('movzx rcx,[rcx]b', TAsmBuilder.New.Movzx(RCX, BytePtr(ridRCX)), '48 0F B6 09');
  CheckHex('movzx ecx,[rcx]w', TAsmBuilder.New.Movzx(ECX, WordPtr(ridRCX)), '0F B7 09');
  CheckHex('movzx rcx,[rcx]w', TAsmBuilder.New.Movzx(RCX, WordPtr(ridRCX)), '48 0F B7 09');
end;

procedure TNativeAsmAsmJitTests.AdditionalStackEncodings;
begin
  CheckHex('push rax', TAsmBuilder.New.Push(RAX), '50');
  CheckHex('push rcx', TAsmBuilder.New.Push(RCX), '51');
  CheckHex('push rdx', TAsmBuilder.New.Push(RDX), '52');
  CheckHex('push 1', TAsmBuilder.New.Push(1), '6A 01');
  CheckHex('push imm32', TAsmBuilder.New.Push($12345678), '68 78 56 34 12');
  CheckHex('push [rcx]', TAsmBuilder.New.Push(QWordPtr(ridRCX)), 'FF 31');
  CheckHex('push [rcx+rdx*1+128]', TAsmBuilder.New.Push(QWordPtrSib(ridRCX, ridRDX, s1, 128)), 'FF B4 11 80 00 00 00');
  CheckHex('pop rax', TAsmBuilder.New.Pop(RAX), '58');
  CheckHex('pop rcx', TAsmBuilder.New.Pop(RCX), '59');
  CheckHex('pop rdx', TAsmBuilder.New.Pop(RDX), '5A');
  CheckHex('pop [rcx]', TAsmBuilder.New.Pop(QWordPtr(ridRCX)), '8F 01');
  CheckHex('pop [rcx+rdx*1+128]', TAsmBuilder.New.Pop(QWordPtrSib(ridRCX, ridRDX, s1, 128)), '8F 84 11 80 00 00 00');
end;

procedure TNativeAsmAsmJitTests.AdditionalShiftRotateEncodings;
begin
  CheckHex('rol cl,1', TAsmBuilder.New.Rol(CL, 1), 'D0 C1');
  CheckHex('rol cl,2', TAsmBuilder.New.Rol(CL, 2), 'C0 C1 02');
  CheckHex('rol cx,1', TAsmBuilder.New.Rol(CX, 1), '66 D1 C1');
  CheckHex('rol cx,2', TAsmBuilder.New.Rol(CX, 2), '66 C1 C1 02');
  CheckHex('rol ecx,1', TAsmBuilder.New.Rol(ECX, 1), 'D1 C1');
  CheckHex('rol ecx,2', TAsmBuilder.New.Rol(ECX, 2), 'C1 C1 02');
  CheckHex('rol rcx,1', TAsmBuilder.New.Rol(RCX, 1), '48 D1 C1');
  CheckHex('rol rcx,2', TAsmBuilder.New.Rol(RCX, 2), '48 C1 C1 02');
  CheckHex('ror cl,1', TAsmBuilder.New.Ror(CL, 1), 'D0 C9');
  CheckHex('ror cl,2', TAsmBuilder.New.Ror(CL, 2), 'C0 C9 02');
  CheckHex('ror cx,1', TAsmBuilder.New.Ror(CX, 1), '66 D1 C9');
  CheckHex('ror ecx,1', TAsmBuilder.New.Ror(ECX, 1), 'D1 C9');
  CheckHex('ror ecx,2', TAsmBuilder.New.Ror(ECX, 2), 'C1 C9 02');
  CheckHex('ror rcx,1', TAsmBuilder.New.Ror(RCX, 1), '48 D1 C9');
  CheckHex('ror rcx,2', TAsmBuilder.New.Ror(RCX, 2), '48 C1 C9 02');
  CheckHex('sar cl,1', TAsmBuilder.New.Sar(CL, 1), 'D0 F9');
  CheckHex('sar cl,cl', TAsmBuilder.New.Sar(CL, CL), 'D2 F9');
  CheckHex('sar cl,2', TAsmBuilder.New.Sar(CL, 2), 'C0 F9 02');
  CheckHex('sar cx,1', TAsmBuilder.New.Sar(CX, 1), '66 D1 F9');
  CheckHex('sar cx,cl', TAsmBuilder.New.Sar(CX, CL), '66 D3 F9');
  CheckHex('sar ecx,1', TAsmBuilder.New.Sar(ECX, 1), 'D1 F9');
  CheckHex('sar ecx,cl', TAsmBuilder.New.Sar(ECX, CL), 'D3 F9');
  CheckHex('sar ecx,2', TAsmBuilder.New.Sar(ECX, 2), 'C1 F9 02');
  CheckHex('sar rcx,1', TAsmBuilder.New.Sar(RCX, 1), '48 D1 F9');
  CheckHex('sar rcx,cl', TAsmBuilder.New.Sar(RCX, CL), '48 D3 F9');
  CheckHex('sar rcx,2', TAsmBuilder.New.Sar(RCX, 2), '48 C1 F9 02');
  CheckHex('shl cl,1', TAsmBuilder.New.Shl_(CL, 1), 'D0 E1');
  CheckHex('shl cl,cl', TAsmBuilder.New.Shl_(CL, CL), 'D2 E1');
  CheckHex('shl cl,2', TAsmBuilder.New.Shl_(CL, 2), 'C0 E1 02');
  CheckHex('shl cx,1', TAsmBuilder.New.Shl_(CX, 1), '66 D1 E1');
  CheckHex('shl cx,cl', TAsmBuilder.New.Shl_(CX, CL), '66 D3 E1');
  CheckHex('shl ecx,1', TAsmBuilder.New.Shl_(ECX, 1), 'D1 E1');
  CheckHex('shl ecx,cl', TAsmBuilder.New.Shl_(ECX, CL), 'D3 E1');
  CheckHex('shl ecx,2', TAsmBuilder.New.Shl_(ECX, 2), 'C1 E1 02');
  CheckHex('shl rcx,1', TAsmBuilder.New.Shl_(RCX, 1), '48 D1 E1');
  CheckHex('shl rcx,cl', TAsmBuilder.New.Shl_(RCX, CL), '48 D3 E1');
  CheckHex('shl rcx,2', TAsmBuilder.New.Shl_(RCX, 2), '48 C1 E1 02');
  CheckHex('shr cl,1', TAsmBuilder.New.Shr_(CL, 1), 'D0 E9');
  CheckHex('shr cl,cl', TAsmBuilder.New.Shr_(CL, CL), 'D2 E9');
  CheckHex('shr cl,2', TAsmBuilder.New.Shr_(CL, 2), 'C0 E9 02');
  CheckHex('shr cx,1', TAsmBuilder.New.Shr_(CX, 1), '66 D1 E9');
  CheckHex('shr cx,cl', TAsmBuilder.New.Shr_(CX, CL), '66 D3 E9');
  CheckHex('shr ecx,1', TAsmBuilder.New.Shr_(ECX, 1), 'D1 E9');
  CheckHex('shr ecx,cl', TAsmBuilder.New.Shr_(ECX, CL), 'D3 E9');
  CheckHex('shr ecx,2', TAsmBuilder.New.Shr_(ECX, 2), 'C1 E9 02');
  CheckHex('shr rcx,1', TAsmBuilder.New.Shr_(RCX, 1), '48 D1 E9');
  CheckHex('shr rcx,cl', TAsmBuilder.New.Shr_(RCX, CL), '48 D3 E9');
  CheckHex('shr rcx,2', TAsmBuilder.New.Shr_(RCX, 2), '48 C1 E9 02');
end;

procedure TNativeAsmAsmJitTests.AdditionalXchgEncodings;
begin
  CheckHex('xchg rax,rcx', TAsmBuilder.New.Xchg(RAX, RCX), '48 91');
  CheckHex('xchg rax,rdx', TAsmBuilder.New.Xchg(RAX, RDX), '48 92');
  CheckHex('xchg rax,rbx', TAsmBuilder.New.Xchg(RAX, RBX), '48 93');
  CheckHex('xchg eax,ecx', TAsmBuilder.New.Xchg(EAX, ECX), '91');
end;

procedure TNativeAsmAsmJitTests.DebugLabelSnapshot;
var
  B: TAsmBuilder;
  Map: TAsmLabelMap;
begin
  B := TAsmBuilder.New;
  try
    B.Label_('entry').Nop(2).Label_('work').Ret;
    Map := TAsmLabelMap.FromBuilder(B);
    try
      CheckInt('debug-label-entry', Map.OffsetOf('entry'), 0);
      CheckInt('debug-label-work', Map.OffsetOf('work'), 2);
      CheckTrue('debug-label-missing', Map.OffsetOf('missing') = -1);
    finally
      Map.Free;
    end;
  finally
    B.Free;
  end;
end;

procedure TNativeAsmAsmJitTests.DebugAddressResolution;
var
  B: TAsmBuilder;
  E: TExecutableCode;
  Registry: TAsmDebugRegistry;
  Location: TAsmDebugLocation;
  Block: TAsmDebugBlock;
  BinFilename: string;
  Saved: TBytes;
begin
  B := nil;
  E := nil;
  Registry := nil;
  BinFilename := TPath.GetTempFileName;
  try
    B := TAsmBuilder.New;
    Registry := TAsmDebugRegistry.Create;
    B.Label_('entry').Nop(2).Label_('work').Mov(RAX, RCX).Ret;
    E := TExecutableCode.FromBuilder(B);
    Block := Registry.RegisterBuilderBlock('DebugBlock', E.EntryPoint, E.Size, B);
    Block.AddSymbol('inside_mov', 3);
    Block.SaveBinary(BinFilename);
    Saved := TFile.ReadAllBytes(BinFilename);
    CheckInt('debug-save-binary-size', Length(Saved), E.Size);
    CheckInt('debug-registry-count', Registry.Count, 1);
    Location := ResolveAddress(Registry, Pointer(NativeUInt(E.EntryPoint) + 4), 8);
    CheckTrue('debug-resolve-found', Location.Found);
    CheckTrue('debug-resolve-block', Location.BlockName = 'DebugBlock');
    CheckInt('debug-resolve-offset', Location.Offset, 4);
    CheckTrue('debug-resolve-symbol', Location.SymbolName = 'inside_mov');
    CheckInt('debug-resolve-delta', Location.SymbolDelta, 1);
    CheckTrue('debug-resolve-bytes', Length(Location.Bytes) > 0);
    CheckTrue('debug-format-text', Pos('DebugBlock', Location.FormatText) > 0);
    CheckTrue('debug-unregister', Registry.UnregisterBlock(E.EntryPoint));
    Location := Registry.Resolve(E.EntryPoint);
    CheckTrue('debug-resolve-unregistered', not Location.Found);
  finally
    Registry.Free;
    E.Free;
    B.Free;
    if TFile.Exists(BinFilename) then TFile.Delete(BinFilename);
  end;
end;

procedure TNativeAsmAsmJitTests.DebugMapRoundTrip;
var
  Filename: string;
  Block, Loaded: TAsmDebugBlock;
  Symbol: TAsmDebugSymbol;
begin
  Filename := TPath.GetTempFileName;
  Block := nil;
  Loaded := nil;
  try
    Block := TAsmDebugBlock.Create('Map|Block', $12345000, $80, False);
    Block.AddSymbol('entry', 0);
    Block.AddSymbol('button|click', $20);
    Block.SaveMap(Filename);
    Loaded := TAsmDebugBlock.LoadMap(Filename);
    CheckTrue('debug-map-name', Loaded.Name = 'Map|Block');
    CheckUInt64('debug-map-base', Loaded.BaseAddress, $12345000);
    CheckInt('debug-map-size', Loaded.Size, $80);
    CheckTrue('debug-map-symbol', Loaded.FindNearestSymbol($24, Symbol));
    CheckTrue('debug-map-symbol-name', Symbol.Name = 'button|click');
    CheckInt('debug-map-symbol-offset', Symbol.Offset, $20);
  finally
    Loaded.Free;
    Block.Free;
    if TFile.Exists(Filename) then TFile.Delete(Filename);
  end;
end;

procedure TNativeAsmAsmJitTests.DebugRegistryValidation;
var
  Registry: TAsmDebugRegistry;
  Data: TBytes;
  Block: TAsmDebugBlock;
  Location: TAsmDebugLocation;
begin
  SetLength(Data, 32);
  Registry := TAsmDebugRegistry.Create;
  try
    Block := Registry.RegisterBlock('A', @Data[0], Length(Data), nil, False);
    ExpectException('debug-symbol-range', procedure begin Block.AddSymbol('bad', Length(Data) + 1); end);
    ExpectException('debug-overlap', procedure begin Registry.RegisterBlock('B', @Data[1], 4, nil, False); end);
    CheckInt('debug-overlap-count', Registry.Count, 1);
    Location := Registry.Resolve(Pointer(NativeUInt(@Data[0]) + NativeUInt(Length(Data))));
    CheckTrue('debug-resolve-outside', not Location.Found);
  finally
    Registry.Free;
  end;
end;

procedure TNativeAsmAsmJitTests.InstructionMapDecode;
var
  B: TAsmBuilder;
  Code: TBytes;
  Labels: TAsmLabelMap;
  Symbols: TArray<TAsmDebugSymbol>;
  Map: TAsmInstructionMap;
  Info: TAsmInstructionInfo;
begin
  B := TAsmBuilder.New;
  Labels := nil;
  Map := nil;
  try
    B.Label_('entry').Mov(RAX, RCX).Add(RAX, 5).Cmp(RAX, RDX).J(cond_JE, 'done').Xor_(RAX, RAX).Label_('done').Ret;
    Code := B.Build;
    Labels := TAsmLabelMap.FromBuilder(B);
    SetLength(Symbols, 2);
    Symbols[0].Name := 'entry';
    Symbols[0].Offset := Labels.OffsetOf('entry');
    Symbols[1].Name := 'done';
    Symbols[1].Offset := Labels.OffsetOf('done');
    Map := TAsmInstructionMap.Create(Code, $10000000, Symbols);
    CheckInt('instruction-map-count', Map.Count, 6);
    Info := Map.Item(0);
    CheckInt('instruction-map-mov-offset', Info.Offset, 0);
    CheckInt('instruction-map-mov-size', Info.Size, 3);
    CheckTrue('instruction-map-mov-text', Info.Text = 'mov rax, rcx');
    Info := Map.Item(1);
    CheckTrue('instruction-map-add-text', Info.Text = 'add rax, $5');
    Info := Map.Item(3);
    CheckTrue('instruction-map-jz', Info.Mnemonic = 'jz');
    CheckTrue('instruction-map-target-symbol', Info.TargetSymbol = 'done');
    CheckTrue('instruction-map-target-text', Pos('done', Info.Text) > 0);
    Info := Map.Item(5);
    CheckTrue('instruction-map-done-symbol', Info.SymbolName = 'done');
    CheckInt('instruction-map-done-delta', Info.SymbolDelta, 0);
    CheckTrue('instruction-map-format', Pos('mov rax, rcx', Map.FormatText) > 0);
  finally
    Map.Free;
    Labels.Free;
    B.Free;
  end;
end;

procedure TNativeAsmAsmJitTests.InstructionMapResolve;
var
  B: TAsmBuilder;
  E: TExecutableCode;
  Registry: TAsmDebugRegistry;
  Location: TAsmDebugLocation;
begin
  B := nil;
  E := nil;
  Registry := nil;
  try
    B := TAsmBuilder.New;
    B.Label_('entry').Mov(RAX, RCX).Add(RAX, RDX).Ret;
    E := TExecutableCode.FromBuilder(B);
    Registry := TAsmDebugRegistry.Create;
    Registry.RegisterBuilderBlock('InstructionResolve', E.EntryPoint, E.Size, B);
    Location := Registry.Resolve(Pointer(NativeUInt(E.EntryPoint) + 1));
    CheckTrue('instruction-resolve-found', Location.Found);
    CheckInt('instruction-resolve-start', Location.InstructionOffset, 0);
    CheckInt('instruction-resolve-size', Location.InstructionSize, 3);
    CheckInt('instruction-resolve-delta', Location.InstructionDelta, 1);
    CheckTrue('instruction-resolve-text', Location.InstructionText = 'mov rax, rcx');
    CheckTrue('instruction-resolve-bytes', Length(Location.InstructionBytes) = 3);
    CheckTrue('instruction-resolve-format', Pos('Instruction +$0 +$1', Location.FormatText) > 0);
  finally
    Registry.Free;
    E.Free;
    B.Free;
  end;
end;

procedure TNativeAsmAsmJitTests.InstructionMapUnknownByte;
var
  Code: TBytes;
  Symbols: TArray<TAsmDebugSymbol>;
  Map: TAsmInstructionMap;
  Info: TAsmInstructionInfo;
begin
  SetLength(Code, 2);
  Code[0] := $62;
  Code[1] := $C3;
  SetLength(Symbols, 0);
  Map := TAsmInstructionMap.Create(Code, $20000000, Symbols);
  try
    CheckInt('instruction-unknown-count', Map.Count, 2);
    Info := Map.Item(0);
    CheckTrue('instruction-unknown-db', Info.Text = 'db $62');
    CheckInt('instruction-unknown-size', Info.Size, 1);
    Info := Map.Item(1);
    CheckTrue('instruction-after-unknown', Info.Text = 'ret');
  finally
    Map.Free;
  end;
end;

procedure TNativeAsmAsmJitTests.InstructionMapPrefixesAndMemory;
var
  B: TAsmBuilder;
  Code: TBytes;
  Symbols: TArray<TAsmDebugSymbol>;
  Map: TAsmInstructionMap;
begin
  B := TAsmBuilder.New;
  Map := nil;
  try
    B.Mov(RAX, QWordPtrSib(ridRCX, ridRDX, s4, 8)).Popcnt(CX, DX).Mov(AH, CL).Ret;
    Code := B.Build;
    SetLength(Symbols, 0);
    Map := TAsmInstructionMap.Create(Code, $30000000, Symbols);
    CheckInt('instruction-complex-count', Map.Count, 4);
    CheckTrue('instruction-complex-memory', Map.Item(0).Text = 'mov rax, qword ptr [rcx+rdx*4+$8]');
    CheckTrue('instruction-complex-prefix', Map.Item(1).Text = 'popcnt cx, dx');
    CheckTrue('instruction-complex-high8', Map.Item(2).Text = 'mov ah, cl');
    CheckTrue('instruction-complex-ret', Map.Item(3).Text = 'ret');
  finally
    Map.Free;
    B.Free;
  end;
end;

procedure TNativeAsmAsmJitTests.BreakpointPatchLifecycle;
var
  B: TAsmBuilder;
  E: TExecutableCode;
  Registry: TAsmDebugRegistry;
  Manager: TAsmBreakpointManager;
  Block: TAsmDebugBlock;
  Breakpoint: TAsmSoftwareBreakpoint;
  Original: Byte;
begin
  B := nil;
  E := nil;
  Registry := nil;
  Manager := nil;
  try
    B := TAsmBuilder.New;
    B.Label_('entry').Mov(RAX, RCX).Label_('step').Add(RAX, 1).Ret;
    E := TExecutableCode.FromBuilder(B);
    Registry := TAsmDebugRegistry.Create;
    Block := Registry.RegisterBuilderBlock('BreakpointPatch', E.EntryPoint, E.Size, B);
    Manager := TAsmBreakpointManager.Create(Registry);
    Breakpoint := Manager.SetBreakpoint(Block, 'step');
    Original := Breakpoint.OriginalByte;
    CheckInt('breakpoint-patch-count', Manager.Count, 1);
    CheckInt('breakpoint-patch-int3', PByte(Pointer(Breakpoint.Address))^, $CC);
    Manager.DisableBreakpoint(Breakpoint);
    CheckTrue('breakpoint-patch-disabled', not Breakpoint.Enabled);
    CheckInt('breakpoint-patch-original', PByte(Pointer(Breakpoint.Address))^, Original);
    Manager.EnableBreakpoint(Breakpoint);
    CheckTrue('breakpoint-patch-enabled', Breakpoint.Enabled);
    CheckInt('breakpoint-patch-reenabled', PByte(Pointer(Breakpoint.Address))^, $CC);
    CheckTrue('breakpoint-patch-remove', Manager.RemoveBreakpoint(Breakpoint));
    CheckInt('breakpoint-patch-removed-byte', PByte(Pointer(NativeUInt(E.EntryPoint) + 3))^, Original);
    CheckInt('breakpoint-patch-empty', Manager.Count, 0);
  finally
    Manager.Free;
    Registry.Free;
    E.Free;
    B.Free;
  end;
end;

procedure TNativeAsmAsmJitTests.BreakpointRuntimeContinue;
var
  B: TAsmBuilder;
  E: TExecutableCode;
  Registry: TAsmDebugRegistry;
  Manager: TAsmBreakpointManager;
  Block: TAsmDebugBlock;
  Breakpoint: TAsmSoftwareBreakpoint;
  Hits: Integer;
  RunResult: UInt64;
  SeenRax, SeenRcx, SeenRip: UInt64;
  SeenInstruction, SeenSymbol: string;
begin
  B := nil;
  E := nil;
  Registry := nil;
  Manager := nil;
  Hits := 0;
  SeenRax := 0;
  SeenRcx := 0;
  SeenRip := 0;
  SeenInstruction := '';
  SeenSymbol := '';
  try
    B := TAsmBuilder.New;
    B.Label_('entry').Mov(RAX, RCX).Label_('increment').Add(RAX, 1).Ret;
    E := TExecutableCode.FromBuilder(B);
    Registry := TAsmDebugRegistry.Create;
    Block := Registry.RegisterBuilderBlock('BreakpointRuntime', E.EntryPoint, E.Size, B);
    Manager := TAsmBreakpointManager.Create(Registry);
    Manager.OnHit := procedure(const Hit: TAsmBreakpointHit)
      begin
        Inc(Hits);
        SeenRax := Hit.Registers.Rax;
        SeenRcx := Hit.Registers.Rcx;
        SeenRip := Hit.Registers.Rip;
        SeenInstruction := Hit.Location.InstructionText;
        SeenSymbol := Hit.Location.SymbolName;
      end;
    Breakpoint := Manager.SetBreakpoint(Block, 'increment');
    RunResult := E.Run(41);
    Manager.DispatchPendingHits;
    CheckUInt64('breakpoint-runtime-result', RunResult, 42);
    CheckInt('breakpoint-runtime-hits', Hits, 1);
    CheckUInt64('breakpoint-runtime-rax', SeenRax, 41);
    CheckUInt64('breakpoint-runtime-rcx', SeenRcx, 41);
    CheckUInt64('breakpoint-runtime-rip', SeenRip, Breakpoint.Address);
    CheckTrue('breakpoint-runtime-symbol', SeenSymbol = 'increment');
    CheckTrue('breakpoint-runtime-instruction', SeenInstruction = 'add rax, $1');
    CheckUInt64('breakpoint-runtime-hitcount', Breakpoint.HitCount, 1);
    CheckInt('breakpoint-runtime-rearmed', PByte(Pointer(Breakpoint.Address))^, $CC);
    RunResult := E.Run(9);
    Manager.DispatchPendingHits;
    CheckUInt64('breakpoint-runtime-second-result', RunResult, 10);
    CheckInt('breakpoint-runtime-second-hits', Hits, 2);
    CheckUInt64('breakpoint-runtime-second-hitcount', Breakpoint.HitCount, 2);
    Manager.DisableBreakpoint(Breakpoint);
    RunResult := E.Run(2);
    Manager.DispatchPendingHits;
    CheckUInt64('breakpoint-runtime-disabled-result', RunResult, 3);
    CheckInt('breakpoint-runtime-disabled-hits', Hits, 2);
    Manager.EnableBreakpoint(Breakpoint);
    RunResult := E.Run(2);
    Manager.DispatchPendingHits;
    CheckUInt64('breakpoint-runtime-reenabled-result', RunResult, 3);
    CheckInt('breakpoint-runtime-reenabled-hits', Hits, 3);
  finally
    Manager.Free;
    Registry.Free;
    E.Free;
    B.Free;
  end;
end;

procedure TNativeAsmAsmJitTests.BreakpointValidation;
var
  B: TAsmBuilder;
  E: TExecutableCode;
  Registry: TAsmDebugRegistry;
  Manager: TAsmBreakpointManager;
  Block: TAsmDebugBlock;
  Breakpoint: TAsmSoftwareBreakpoint;
begin
  B := nil;
  E := nil;
  Registry := nil;
  Manager := nil;
  try
    B := TAsmBuilder.New;
    B.Label_('entry').Mov(RAX, RCX).Add(RAX, 1).Ret;
    E := TExecutableCode.FromBuilder(B);
    Registry := TAsmDebugRegistry.Create;
    Block := Registry.RegisterBuilderBlock('BreakpointValidation', E.EntryPoint, E.Size, B);
    Manager := TAsmBreakpointManager.Create(Registry);
    ExpectException('breakpoint-validation-middle', procedure begin Manager.SetBreakpoint(Block, 1); end);
    ExpectException('breakpoint-validation-symbol', procedure begin Manager.SetBreakpoint(Block, 'missing'); end);
    Breakpoint := Manager.SetBreakpoint(Block, 0);
    ExpectException('breakpoint-validation-duplicate', procedure begin Manager.SetBreakpoint(Block, 0); end);
    CheckTrue('breakpoint-validation-remove', Manager.RemoveBreakpoint(Breakpoint));
  finally
    Manager.Free;
    Registry.Free;
    E.Free;
    B.Free;
  end;
end;

procedure TNativeAsmAsmJitTests.BreakpointCallbackIsolation;
var
  B: TAsmBuilder;
  E: TExecutableCode;
  Registry: TAsmDebugRegistry;
  Manager: TAsmBreakpointManager;
  Block: TAsmDebugBlock;
begin
  B := nil;
  E := nil;
  Registry := nil;
  Manager := nil;
  try
    B := TAsmBuilder.New;
    B.Label_('entry').Mov(RAX, RCX).Label_('increment').Add(RAX, 1).Ret;
    E := TExecutableCode.FromBuilder(B);
    Registry := TAsmDebugRegistry.Create;
    Block := Registry.RegisterBuilderBlock('BreakpointCallback', E.EntryPoint, E.Size, B);
    Manager := TAsmBreakpointManager.Create(Registry);
    Manager.OnHit := procedure(const Hit: TAsmBreakpointHit)
      begin
        raise Exception.Create('callback-test');
      end;
    Manager.SetBreakpoint(Block, 'increment');
    CheckUInt64('breakpoint-callback-result', E.Run(4), 5);
    CheckInt('breakpoint-callback-pending', Manager.PendingHitCount, 1);
    Manager.DispatchPendingHits;
    CheckTrue('breakpoint-callback-error', Pos('callback-test', Manager.LastCallbackError) > 0);
    CheckInt('breakpoint-callback-drained', Manager.PendingHitCount, 0);
  finally
    Manager.Free;
    Registry.Free;
    E.Free;
    B.Free;
  end;
end;


procedure TNativeAsmAsmJitTests.DisassemblerSupportedCode;
var
  B: TAsmBuilder;
  Code: TBytes;
  Items: TArray<TNativeAsmDisasmInstruction>;
begin
  B := TAsmBuilder.New;
  try
    B.Mov(RAX, RCX).Cmp(RAX, RDX).J(cond_JGE, 'done').Mov(RAX, RDX).Label_('done').Add(RAX, 1).Ret;
    Code := B.Build;
  finally
    B.Free;
  end;
  Items := TNativeAsmDisassembler.DecodeAll(Code, $10000000);
  CheckInt('disasm-supported-count', Length(Items), 6);
  CheckTrue('disasm-supported-0', SameText(Items[0].Text, 'mov rax, rcx'));
  CheckTrue('disasm-supported-1', SameText(Items[1].Text, 'cmp rax, rdx'));
  CheckTrue('disasm-supported-2', SameText(Items[2].Mnemonic, 'jnl'));
  CheckTrue('disasm-supported-3', SameText(Items[3].Text, 'mov rax, rdx'));
  CheckTrue('disasm-supported-4', SameText(Items[4].Text, 'add rax, $1'));
  CheckTrue('disasm-supported-5', SameText(Items[5].Text, 'ret'));
  CheckTrue('disasm-supported-target', Items[2].HasTarget and (Items[2].TargetAddress = $1000000F));
end;

procedure TNativeAsmAsmJitTests.DisassemblerSourceOnlyForm;
var
  Code: TBytes;
  Info: TNativeAsmDisasmInstruction;
begin
  SetLength(Code, 2);
  Code[0] := $0F;
  Code[1] := $C8;
  CheckTrue('disasm-source-only-decode', TNativeAsmDisassembler.DecodeOne(Code, 0, 0, Info));
  CheckTrue('disasm-source-only-text', SameText(Info.Text, 'bswap eax'));
  CheckTrue('disasm-source-only-support', Info.NativeSupport = nsSourceOnly);
  CheckTrue('disasm-source-only-form', Info.FormIndex >= 0);
end;

procedure TNativeAsmAsmJitTests.DisassemblerMetadata;
var
  B: TAsmBuilder;
  Code: TBytes;
  Info: TNativeAsmDisasmInstruction;
begin
  B := TAsmBuilder.New;
  try
    B.Popcnt(RCX, RDX);
    Code := B.Build;
  finally
    B.Free;
  end;
  CheckTrue('disasm-meta-decode', TNativeAsmDisassembler.DecodeOne(Code, $20000000, 0, Info));
  CheckTrue('disasm-meta-form', Info.FormIndex >= 0);
  CheckTrue('disasm-meta-signature', Info.SourceSignature <> '');
  CheckTrue('disasm-meta-encoding', Info.SourceEncoding <> '');
  CheckTrue('disasm-meta-candidates', Info.CandidateCount > 0);
  CheckTrue('disasm-meta-text', SameText(Info.Text, 'popcnt rcx, rdx'));
end;

procedure TNativeAsmAsmJitTests.DisassemblerUnknownFallback;
var
  Code: TBytes;
  Info: TNativeAsmDisasmInstruction;
begin
  SetLength(Code, 1);
  Code[0] := $F1;
  CheckTrue('disasm-db-decode', TNativeAsmDisassembler.DecodeOne(Code, 0, 0, Info));
  CheckTrue('disasm-db-data', Info.IsData);
  CheckTrue('disasm-db-text', SameText(Info.Text, 'db $F1'));
  CheckInt('disasm-db-size', Info.Size, 1);
end;


procedure TNativeAsmAsmJitTests.SimdDatabase;
begin
  CheckInt('simd-form-count', TSimdInstructionDb.FormCount, 338);
  CheckInt('simd-mnemonic-count', TSimdInstructionDb.MnemonicCount, 275);
  CheckTrue('simd-sha256', TSimdInstructionDb.SourceSha256 = '0bc3fde0376e3c7db93ce1fa6da35b9d69b868db738e60dba382a2bee54d1f48');
  CheckTrue('simd-addps-index', TSimdInstructionDb.MnemonicIndexOf('addps') >= 0);
  CheckTrue('simd-movdqa-index', TSimdInstructionDb.MnemonicIndexOf('movdqa') >= 0);
  CheckTrue('simd-haddps-index', TSimdInstructionDb.MnemonicIndexOf('haddps') >= 0);
  CheckTrue('simd-pshufb-index', TSimdInstructionDb.MnemonicIndexOf('pshufb') >= 0);
  CheckTrue('simd-blendvps-index', TSimdInstructionDb.MnemonicIndexOf('blendvps') >= 0);
  CheckTrue('simd-crc32-index', TSimdInstructionDb.MnemonicIndexOf('crc32') >= 0);
  CheckTrue('simd-pclmulqdq-index', TSimdInstructionDb.MnemonicIndexOf('pclmulqdq') >= 0);
  CheckTrue('simd-extrq-index', TSimdInstructionDb.MnemonicIndexOf('extrq') >= 0);
  CheckTrue('simd-aesenc-index', TSimdInstructionDb.MnemonicIndexOf('aesenc') >= 0);
  CheckTrue('simd-sha1msg1-index', TSimdInstructionDb.MnemonicIndexOf('sha1msg1') >= 0);
  CheckTrue('simd-sha256rnds2-index', TSimdInstructionDb.MnemonicIndexOf('sha256rnds2') >= 0);
  CheckTrue('simd-lzcnt-index', TSimdInstructionDb.MnemonicIndexOf('lzcnt') >= 0);
  CheckTrue('simd-tzcnt-index', TSimdInstructionDb.MnemonicIndexOf('tzcnt') >= 0);
end;

procedure TNativeAsmAsmJitTests.SimdSseFamilyEncodings;
begin
  CheckHex('simd-sse-addps', TAsmBuilder.New.Addps(XMM1, XMM2), '0F 58 CA');
  CheckHex('simd-sse-movups', TAsmBuilder.New.Movups(XMM1, XMM2), '0F 10 CA');
  CheckHex('simd-sse-shufps', TAsmBuilder.New.Shufps(XMM1, XMM2, $1B), '0F C6 CA 1B');
  CheckHex('simd-sse2-addpd', TAsmBuilder.New.Addpd(XMM1, XMM2), '66 0F 58 CA');
  CheckHex('simd-sse2-movdqa', TAsmBuilder.New.Movdqa(XMM1, XMM2), '66 0F 6F CA');
  CheckHex('simd-sse2-por', TAsmBuilder.New.Por(XMM1, XMM2), '66 0F EB CA');
  CheckHex('simd-sse3-haddps', TAsmBuilder.New.Haddps(XMM1, XMM2), 'F2 0F 7C CA');
  CheckHex('simd-sse3-addsubpd', TAsmBuilder.New.Addsubpd(XMM1, XMM2), '66 0F D0 CA');
  CheckHex('simd-ssse3-pshufb', TAsmBuilder.New.Pshufb(XMM1, XMM2), '66 0F 38 00 CA');
  CheckHex('simd-ssse3-pabsb', TAsmBuilder.New.Pabsb(XMM1, XMM2), '66 0F 38 1C CA');
  CheckHex('simd-sse41-blendvps', TAsmBuilder.New.Blendvps(XMM1, XMM2), '66 0F 38 14 CA');
  CheckHex('simd-sse41-dpps', TAsmBuilder.New.Dpps(XMM1, XMM2, $7F), '66 0F 3A 40 CA 7F');
  CheckHex('simd-sse41-pmovsxbq', TAsmBuilder.New.Pmovsxbq(XMM1, XMM2), '66 0F 38 22 CA');
  CheckHex('simd-sse42-pcmpestri', TAsmBuilder.New.Pcmpestri(XMM1, XMM2, $08), '66 0F 3A 61 CA 08');
  CheckHex('simd-sse42-crc32-r32-r8', TAsmBuilder.New.Crc32(ECX, DL), 'F2 0F 38 F0 CA');
  CheckHex('simd-pclmulqdq', TAsmBuilder.New.Pclmulqdq(XMM1, XMM2, $11), '66 0F 3A 44 CA 11');
  CheckHex('simd-sse4a-extrq-imm', TAsmBuilder.New.Extrq(XMM1, 2, 3), '66 0F 78 C1 02 03');
  CheckHex('simd-sse4a-insertq-reg', TAsmBuilder.New.Insertq(XMM1, XMM2), 'F2 0F 79 CA');
end;

procedure TNativeAsmAsmJitTests.SimdMemoryAndExtendedRegisterEncodings;
begin
  CheckHex('simd-movups-xmm1-m128', TAsmBuilder.New.Movups(XMM1, OWordPtr(ridRCX)), '0F 10 09');
  CheckHex('simd-movups-m128-xmm1', TAsmBuilder.New.Movups(OWordPtr(ridRCX), XMM1), '0F 11 09');
  CheckHex('simd-addps-xmm9-xmm10', TAsmBuilder.New.Addps(XMM9, XMM10), '45 0F 58 CA');
  CheckHex('simd-addps-xmm9-m128-r12-r13', TAsmBuilder.New.Addps(XMM9, OWordPtrSib(ridR12, ridR13, s4, 64)), '47 0F 58 4C AC 40');
  CheckHex('simd-movdqa-xmm9-rip', TAsmBuilder.New.Movdqa(XMM9, OWordPtrRip(16)), '66 44 0F 6F 0D 10 00 00 00');
  CheckHex('simd-crc32-r64-m64', TAsmBuilder.New.Crc32(RCX, QWordPtr(ridRDX)), 'F2 48 0F 38 F1 0A');
  CheckHex('simd-pclmulqdq-xmm9-sib', TAsmBuilder.New.Pclmulqdq(XMM9, OWordPtrSib(ridR12, ridR13, s4, 64), 0), '66 47 0F 3A 44 4C AC 40 00');
  CheckHex('simd-sfence', TAsmBuilder.New.Simd('sfence', []), '0F AE F8');
  CheckHex('simd-lfence', TAsmBuilder.New.Simd('lfence', []), '0F AE E8');
  CheckHex('simd-mfence', TAsmBuilder.New.Simd('mfence', []), '0F AE F0');
end;

procedure TNativeAsmAsmJitTests.SimdValidation;
var
  B: TAsmBuilder;
begin
  ExpectException('simd-unknown-mnemonic', procedure begin B := TAsmBuilder.New; try B.Simd('not_an_instruction', []); finally B.Free; end; end);
  ExpectException('simd-addps-gpr', procedure begin B := TAsmBuilder.New; try B.Addps(RAX, XMM1); finally B.Free; end; end);
  ExpectException('simd-addps-imm', procedure begin B := TAsmBuilder.New; try B.Addps(XMM1, 1); finally B.Free; end; end);
  ExpectException('simd-shufps-missing-imm', procedure begin B := TAsmBuilder.New; try B.Simd('shufps', [XMM1, XMM2]); finally B.Free; end; end);
  ExpectException('simd-extrq-missing-imm', procedure begin B := TAsmBuilder.New; try B.Extrq(XMM1, 1); finally B.Free; end; end);
  ExpectException('simd-pclmulqdq-gpr', procedure begin B := TAsmBuilder.New; try B.Pclmulqdq(RAX, XMM1, 0); finally B.Free; end; end);
end;

procedure TNativeAsmAsmJitTests.AesNiEncodings;
begin
  CheckHex('aesni-aesenc', TAsmBuilder.New.Aesenc(XMM1, XMM2), '66 0F 38 DC CA');
  CheckHex('aesni-aesdec', TAsmBuilder.New.Aesdec(XMM1, XMM2), '66 0F 38 DE CA');
  CheckHex('aesni-aesdeclast', TAsmBuilder.New.Aesdeclast(XMM1, XMM2), '66 0F 38 DF CA');
  CheckHex('aesni-aesenclast', TAsmBuilder.New.Aesenclast(XMM1, XMM2), '66 0F 38 DD CA');
  CheckHex('aesni-aesimc', TAsmBuilder.New.Aesimc(XMM1, XMM2), '66 0F 38 DB CA');
  CheckHex('aesni-aeskeygenassist', TAsmBuilder.New.Aeskeygenassist(XMM1, XMM2, $1B), '66 0F 3A DF CA 1B');
end;

procedure TNativeAsmAsmJitTests.AesNiMemoryAndExtended;
begin
  CheckHex('aesni-aesenc-xmm9-xmm10', TAsmBuilder.New.Aesenc(XMM9, XMM10), '66 45 0F 38 DC CA');
  CheckHex('aesni-aesenc-m128', TAsmBuilder.New.Aesenc(XMM1, OWordPtr(ridRDX)), '66 0F 38 DC 0A');
  CheckHex('aesni-keygen-xmm9-sib', TAsmBuilder.New.Aeskeygenassist(XMM9, OWordPtrSib(ridR12, ridR13, s4, 64), $55), '66 47 0F 3A DF 4C AC 40 55');
end;

procedure TNativeAsmAsmJitTests.ShaEncodings;
begin
  CheckHex('sha-sha1msg1', TAsmBuilder.New.Sha1msg1(XMM1, XMM2), '0F 38 C9 CA');
  CheckHex('sha-sha1msg2', TAsmBuilder.New.Sha1msg2(XMM1, XMM2), '0F 38 CA CA');
  CheckHex('sha-sha1nexte', TAsmBuilder.New.Sha1nexte(XMM1, XMM2), '0F 38 C8 CA');
  CheckHex('sha-sha1rnds4', TAsmBuilder.New.Sha1rnds4(XMM1, XMM2, 2), '0F 3A CC CA 02');
  CheckHex('sha-sha256msg1', TAsmBuilder.New.Sha256msg1(XMM1, XMM2), '0F 38 CC CA');
  CheckHex('sha-sha256msg2', TAsmBuilder.New.Sha256msg2(XMM1, XMM2), '0F 38 CD CA');
  CheckHex('sha-sha256rnds2', TAsmBuilder.New.Sha256rnds2(XMM1, XMM2), '0F 38 CB CA');
end;

procedure TNativeAsmAsmJitTests.ShaMemoryAndValidation;
var
  B: TAsmBuilder;
begin
  CheckHex('sha-sha256rnds2-xmm9-xmm10', TAsmBuilder.New.Sha256rnds2(XMM9, XMM10), '45 0F 38 CB CA');
  CheckHex('sha-sha1msg1-sib', TAsmBuilder.New.Sha1msg1(XMM9, OWordPtrSib(ridR12, ridR13, s4, 64)), '47 0F 38 C9 4C AC 40');
  CheckHex('sha-sha256msg1-m128', TAsmBuilder.New.Sha256msg1(XMM1, OWordPtr(ridRDX)), '0F 38 CC 0A');
  ExpectException('sha-sha1msg1-gpr', procedure begin B := TAsmBuilder.New; try B.Sha1msg1(RAX, XMM1); finally B.Free; end; end);
  ExpectException('sha-sha1rnds4-missing-imm', procedure begin B := TAsmBuilder.New; try B.Simd('sha1rnds4', [XMM1, XMM2]); finally B.Free; end; end);
  ExpectException('sha-sha256rnds2-explicit-xmm0', procedure begin B := TAsmBuilder.New; try B.Simd('sha256rnds2', [XMM1, XMM2, XMM0]); finally B.Free; end; end);
end;

procedure TNativeAsmAsmJitTests.BitCountEncodings;
begin
  CheckHex('lzcnt-r16', TAsmBuilder.New.Lzcnt(CX, DX), 'F3 66 0F BD CA');
  CheckHex('lzcnt-r32', TAsmBuilder.New.Lzcnt(ECX, EDX), 'F3 0F BD CA');
  CheckHex('lzcnt-r64', TAsmBuilder.New.Lzcnt(RCX, RDX), 'F3 48 0F BD CA');
  CheckHex('lzcnt-r64-ext', TAsmBuilder.New.Lzcnt(R9, R10), 'F3 4D 0F BD CA');
  CheckHex('lzcnt-m64', TAsmBuilder.New.Lzcnt(RCX, QWordPtr(ridRDX)), 'F3 48 0F BD 0A');
  CheckHex('tzcnt-r16', TAsmBuilder.New.Tzcnt(CX, DX), 'F3 66 0F BC CA');
  CheckHex('tzcnt-r32', TAsmBuilder.New.Tzcnt(ECX, EDX), 'F3 0F BC CA');
  CheckHex('tzcnt-r64', TAsmBuilder.New.Tzcnt(RCX, RDX), 'F3 48 0F BC CA');
  CheckHex('tzcnt-r64-ext', TAsmBuilder.New.Tzcnt(R9, R10), 'F3 4D 0F BC CA');
  CheckHex('tzcnt-m64', TAsmBuilder.New.Tzcnt(RCX, QWordPtr(ridRDX)), 'F3 48 0F BC 0A');
end;

procedure TNativeAsmAsmJitTests.BitCountValidation;
var
  B: TAsmBuilder;
begin
  ExpectException('lzcnt-r8', procedure begin B := TAsmBuilder.New; try B.Lzcnt(CL, DL); finally B.Free; end; end);
  ExpectException('tzcnt-r8', procedure begin B := TAsmBuilder.New; try B.Tzcnt(CL, DL); finally B.Free; end; end);
  ExpectException('lzcnt-imm', procedure begin B := TAsmBuilder.New; try B.Lzcnt(RCX, 1); finally B.Free; end; end);
  ExpectException('tzcnt-size-mismatch', procedure begin B := TAsmBuilder.New; try B.Tzcnt(RCX, DWordPtr(ridRDX)); finally B.Free; end; end);
  ExpectException('aesni-gpr', procedure begin B := TAsmBuilder.New; try B.Aesenc(RAX, XMM1); finally B.Free; end; end);
  ExpectException('aesni-keygen-missing-imm', procedure begin B := TAsmBuilder.New; try B.Simd('aeskeygenassist', [XMM1, XMM2]); finally B.Free; end; end);
end;

procedure TNativeAsmAsmJitTests.AsmJitEncodingMatrix;
begin
  CheckHex('asmjit-add-cl-dl', TAsmBuilder.New.Add(CL, DL), '02 CA');
  CheckHex('asmjit-add-ch-dh', TAsmBuilder.New.Add(CH, DH), '02 EE');
  CheckHex('asmjit-add-cx-dx', TAsmBuilder.New.Add(CX, DX), '66 03 CA');
  CheckHex('asmjit-add-ecx-edx', TAsmBuilder.New.Add(ECX, EDX), '03 CA');
  CheckHex('asmjit-add-rcx-rdx', TAsmBuilder.New.Add(RCX, RDX), '48 03 CA');
  CheckHex('asmjit-add-m8-1', TAsmBuilder.New.Add(BytePtrSib(ridRCX, ridRDX, s1, 128), 1), '80 84 11 80 00 00 00 01');
  CheckHex('asmjit-add-m16-1', TAsmBuilder.New.Add(TMemory.CreateSib(ridRCX, ridRDX, s1, 128, sz16), 1), '66 83 84 11 80 00 00 00 01');
  CheckHex('asmjit-add-m32-1', TAsmBuilder.New.Add(TMemory.CreateSib(ridRCX, ridRDX, s1, 128, sz32), 1), '83 84 11 80 00 00 00 01');
  CheckHex('asmjit-add-m64-1', TAsmBuilder.New.Add(TMemory.CreateSib(ridRCX, ridRDX, s1, 128, sz64), 1), '48 83 84 11 80 00 00 00 01');
  CheckHex('asmjit-and-cl-dl', TAsmBuilder.New.And_(CL, DL), '22 CA');
  CheckHex('asmjit-and-ch-dh', TAsmBuilder.New.And_(CH, DH), '22 EE');
  CheckHex('asmjit-and-cx-1', TAsmBuilder.New.And_(CX, 1), '66 83 E1 01');
  CheckHex('asmjit-and-ecx-1', TAsmBuilder.New.And_(ECX, 1), '83 E1 01');
  CheckHex('asmjit-and-rcx-1', TAsmBuilder.New.And_(RCX, 1), '48 83 E1 01');
  CheckHex('asmjit-or-cl-dl', TAsmBuilder.New.Or_(CL, DL), '0A CA');
  CheckHex('asmjit-or-ch-dh', TAsmBuilder.New.Or_(CH, DH), '0A EE');
  CheckHex('asmjit-or-cx-1', TAsmBuilder.New.Or_(CX, 1), '66 83 C9 01');
  CheckHex('asmjit-or-ecx-1', TAsmBuilder.New.Or_(ECX, 1), '83 C9 01');
  CheckHex('asmjit-or-rcx-1', TAsmBuilder.New.Or_(RCX, 1), '48 83 C9 01');
  CheckHex('asmjit-xor-cl-dl', TAsmBuilder.New.Xor_(CL, DL), '32 CA');
  CheckHex('asmjit-xor-ch-dh', TAsmBuilder.New.Xor_(CH, DH), '32 EE');
  CheckHex('asmjit-xor-cx-1', TAsmBuilder.New.Xor_(CX, 1), '66 83 F1 01');
  CheckHex('asmjit-xor-ecx-1', TAsmBuilder.New.Xor_(ECX, 1), '83 F1 01');
  CheckHex('asmjit-xor-rcx-1', TAsmBuilder.New.Xor_(RCX, 1), '48 83 F1 01');
  CheckHex('asmjit-cmp-cl-dl', TAsmBuilder.New.Cmp(CL, DL), '3A CA');
  CheckHex('asmjit-cmp-ch-dh', TAsmBuilder.New.Cmp(CH, DH), '3A EE');
  CheckHex('asmjit-cmp-cx-1', TAsmBuilder.New.Cmp(CX, 1), '66 83 F9 01');
  CheckHex('asmjit-cmp-ecx-1', TAsmBuilder.New.Cmp(ECX, 1), '83 F9 01');
  CheckHex('asmjit-cmp-rcx-1', TAsmBuilder.New.Cmp(RCX, 1), '48 83 F9 01');
  CheckHex('asmjit-test-cl-dl', TAsmBuilder.New.Test(CL, DL), '84 D1');
  CheckHex('asmjit-test-ch-dh', TAsmBuilder.New.Test(CH, DH), '84 F5');
  CheckHex('asmjit-test-cx-1', TAsmBuilder.New.Test(CX, 1), '66 F7 C1 01 00');
  CheckHex('asmjit-test-ecx-1', TAsmBuilder.New.Test(ECX, 1), 'F7 C1 01 00 00 00');
  CheckHex('asmjit-test-rcx-1', TAsmBuilder.New.Test(RCX, 1), '48 F7 C1 01 00 00 00');
  CheckHex('asmjit-inc-cl', TAsmBuilder.New.Inc_(CL), 'FE C1');
  CheckHex('asmjit-inc-ch', TAsmBuilder.New.Inc_(CH), 'FE C5');
  CheckHex('asmjit-inc-cx', TAsmBuilder.New.Inc_(CX), '66 FF C1');
  CheckHex('asmjit-inc-ecx', TAsmBuilder.New.Inc_(ECX), 'FF C1');
  CheckHex('asmjit-inc-rcx', TAsmBuilder.New.Inc_(RCX), '48 FF C1');
  CheckHex('asmjit-dec-cl', TAsmBuilder.New.Dec_(CL), 'FE C9');
  CheckHex('asmjit-dec-ch', TAsmBuilder.New.Dec_(CH), 'FE CD');
  CheckHex('asmjit-dec-cx', TAsmBuilder.New.Dec_(CX), '66 FF C9');
  CheckHex('asmjit-dec-ecx', TAsmBuilder.New.Dec_(ECX), 'FF C9');
  CheckHex('asmjit-dec-rcx', TAsmBuilder.New.Dec_(RCX), '48 FF C9');
  CheckHex('asmjit-neg-cl', TAsmBuilder.New.Neg(CL), 'F6 D9');
  CheckHex('asmjit-neg-ch', TAsmBuilder.New.Neg(CH), 'F6 DD');
  CheckHex('asmjit-neg-cx', TAsmBuilder.New.Neg(CX), '66 F7 D9');
  CheckHex('asmjit-neg-ecx', TAsmBuilder.New.Neg(ECX), 'F7 D9');
  CheckHex('asmjit-neg-rcx', TAsmBuilder.New.Neg(RCX), '48 F7 D9');
  CheckHex('asmjit-not-cl', TAsmBuilder.New.Not_(CL), 'F6 D1');
  CheckHex('asmjit-not-ch', TAsmBuilder.New.Not_(CH), 'F6 D5');
  CheckHex('asmjit-not-cx', TAsmBuilder.New.Not_(CX), '66 F7 D1');
  CheckHex('asmjit-not-ecx', TAsmBuilder.New.Not_(ECX), 'F7 D1');
  CheckHex('asmjit-not-rcx', TAsmBuilder.New.Not_(RCX), '48 F7 D1');
  CheckHex('asmjit-bsf-cx-dx', TAsmBuilder.New.Bsf(CX, DX), '66 0F BC CA');
  CheckHex('asmjit-bsf-ecx-edx', TAsmBuilder.New.Bsf(ECX, EDX), '0F BC CA');
  CheckHex('asmjit-bsf-rcx-rdx', TAsmBuilder.New.Bsf(RCX, RDX), '48 0F BC CA');
  CheckHex('asmjit-bsr-cx-dx', TAsmBuilder.New.Bsr(CX, DX), '66 0F BD CA');
  CheckHex('asmjit-bsr-ecx-edx', TAsmBuilder.New.Bsr(ECX, EDX), '0F BD CA');
  CheckHex('asmjit-bsr-rcx-rdx', TAsmBuilder.New.Bsr(RCX, RDX), '48 0F BD CA');
  CheckHex('asmjit-popcnt-cx-dx', TAsmBuilder.New.Popcnt(CX, DX), 'F3 66 0F B8 CA');
  CheckHex('asmjit-popcnt-ecx-edx', TAsmBuilder.New.Popcnt(ECX, EDX), 'F3 0F B8 CA');
  CheckHex('asmjit-popcnt-rcx-rdx', TAsmBuilder.New.Popcnt(RCX, RDX), 'F3 48 0F B8 CA');
  CheckHex('asmjit-xchg-cl-dl', TAsmBuilder.New.Xchg(CL, DL), '86 CA');
  CheckHex('asmjit-xchg-ch-dh', TAsmBuilder.New.Xchg(CH, DH), '86 EE');
  CheckHex('asmjit-xchg-cx-dx', TAsmBuilder.New.Xchg(CX, DX), '66 87 CA');
  CheckHex('asmjit-xchg-ecx-edx', TAsmBuilder.New.Xchg(ECX, EDX), '87 CA');
  CheckHex('asmjit-xchg-rcx-rdx', TAsmBuilder.New.Xchg(RCX, RDX), '48 87 CA');
  CheckHex('asmjit-movsx-ecx-m8', TAsmBuilder.New.Movsx(ECX, TMemory.CreateSib(ridRDX, ridRBX, s1, 128, sz8)), '0F BE 8C 1A 80 00 00 00');
  CheckHex('asmjit-movsx-rcx-m16', TAsmBuilder.New.Movsx(RCX, TMemory.CreateSib(ridRDX, ridRBX, s1, 128, sz16)), '48 0F BF 8C 1A 80 00 00 00');
  CheckHex('asmjit-movzx-ecx-m8', TAsmBuilder.New.Movzx(ECX, TMemory.CreateSib(ridRDX, ridRBX, s1, 128, sz8)), '0F B6 8C 1A 80 00 00 00');
  CheckHex('asmjit-movzx-rcx-m16', TAsmBuilder.New.Movzx(RCX, TMemory.CreateSib(ridRDX, ridRBX, s1, 128, sz16)), '48 0F B7 8C 1A 80 00 00 00');
end;

initialization
  TDUnitX.RegisterTestFixture(TNativeAsmAsmJitTests);

end.
