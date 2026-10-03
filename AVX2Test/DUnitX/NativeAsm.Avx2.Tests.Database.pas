unit NativeAsm.Avx2.Tests.Database;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TAvx2DatabaseTests = class
  public
    [Test] procedure Avx2FormAndMnemonicCounts;
    [Test] procedure EveryAvx2FormEncodesRegisterPreferred;
    [Test] procedure EveryAvx2FormEncodesMemoryPreferred;
  end;

implementation

uses
  System.SysUtils,
  NativeAsm.Types,
  NativeAsm.Builder,
  NativeAsm.Simd.Types,
  NativeAsm.Avx.Types,
  NativeAsm.Avx.Db,
  NativeAsm.Avx.Encoder,
  NativeAsm.Avx2.Tests.Support;

type
  TLocalOperands = array of TAvxOperand;

function MakeXmm(ID: Integer): TSimdRegister;
begin
  Result := Default(TSimdRegister);
  Result.ID := Byte(ID);
  Result.Kind := srkXmm;
end;

function MakeYmm(ID: Integer): TAvxYmmRegister;
begin
  Result := Default(TAvxYmmRegister);
  Result.ID := Byte(ID);
end;

function MakeGpr(ID: Integer; Is64: Boolean): TRegister;
begin
  Result := Default(TRegister);
  Result.ID := TRegID(ID);
  if Is64 then Result.RegType := rt64 else Result.RegType := rt32;
end;

function MemoryForClass(C: TAvxDbMemClass): TAvxMemory;
begin
  case C of
    amc128: Result := TAvxMemory.Create(ridRAX, 16, ams128);
    amc256: Result := TAvxMemory.Create(ridRAX, 16, ams256);
    amc8: Result := TAvxMemory.Create(ridRAX, 16, ams8);
    amc16: Result := TAvxMemory.Create(ridRAX, 16, ams16);
    amc32: Result := TAvxMemory.Create(ridRAX, 16, ams32);
    amc64: Result := TAvxMemory.Create(ridRAX, 16, ams64);
    amcVm32x: Result := Vm32x(ridRAX, MakeXmm(4), s4, 16);
    amcVm32y: Result := Vm32y(ridRAX, MakeYmm(4), s4, 16);
    amcVm64x: Result := Vm64x(ridRAX, MakeXmm(4), s4, 16);
    amcVm64y: Result := Vm64y(ridRAX, MakeYmm(4), s4, 16);
  else
    raise Exception.Create('Unsupported AVX2 memory class');
  end;
end;

function OperandForSpec(const Spec: TAvxDbOperandSpec; OperandIndex: Integer; PreferMemory: Boolean): TAvxOperand;
const
  GprIds: array[0..3] of Integer = (1, 2, 8, 9);
begin
  if (Spec.Kinds and AVX_OK_IMM) <> 0 then Exit(AvxOp(1));
  if PreferMemory and ((Spec.Kinds and AVX_OK_MEM) <> 0) then Exit(AvxOp(MemoryForClass(Spec.MemClass)));
  if (Spec.Kinds and AVX_OK_REG) <> 0 then
  begin
    case Spec.RegClass of
      arcXmm: Exit(AvxOp(MakeXmm(OperandIndex + 1)));
      arcYmm: Exit(AvxOp(MakeYmm(OperandIndex + 1)));
      arcGp32: Exit(AvxOp(MakeGpr(GprIds[OperandIndex], False)));
      arcGp64: Exit(AvxOp(MakeGpr(GprIds[OperandIndex], True)));
    else
      raise Exception.Create('Unsupported AVX2 register class');
    end;
  end;
  if (Spec.Kinds and AVX_OK_MEM) <> 0 then Exit(AvxOp(MemoryForClass(Spec.MemClass)));
  raise Exception.Create('Unsupported AVX2 operand');
end;

function BuildOperands(FormIndex: Integer; PreferMemory: Boolean): TLocalOperands;
var
  D: PAvxEncodingDescriptor;
  I: Integer;
begin
  D := TAvxInstructionDb.Form(FormIndex);
  SetLength(Result, D^.OperandCount);
  for I := 0 to D^.OperandCount - 1 do Result[I] := OperandForSpec(TAvxInstructionDb.Operand(FormIndex, I)^, I, PreferMemory);
end;

procedure EncodeEveryAvx2Form(PreferMemory: Boolean);
var
  F: Integer;
  D: PAvxEncodingDescriptor;
  Ops: TLocalOperands;
  Name: string;
  Selected: Integer;
  B: TAsmBuilder;
begin
  for F := 0 to TAvxInstructionDb.FormCount - 1 do
  begin
    D := TAvxInstructionDb.Form(F);
    if D^.Extension <> aeAVX2 then Continue;
    Ops := BuildOperands(F, PreferMemory);
    Name := TAvxInstructionDb.MnemonicName(D^.MnemonicIndex);
    Selected := TAvxInstructionEncoder.SelectForm(Name, Ops);
    Assert.IsTrue(Selected >= 0, 'No form selected for ' + Name + ' source form ' + IntToStr(F));
    Assert.IsTrue(TAvxInstructionDb.Form(Selected)^.Extension = aeAVX2, 'Selection escaped AVX2 for ' + Name);
    B := TAsmBuilder.New;
    try
      TAvxInstructionEncoder.Encode(B, Name, Ops);
      Assert.IsTrue(B.CodeSize > 0, 'No bytes for ' + Name + ' form ' + IntToStr(F));
      Assert.IsTrue(Length(B.Build) = B.CodeSize, 'Build size mismatch for ' + Name);
    finally
      B.Free;
    end;
  end;
end;

procedure TAvx2DatabaseTests.Avx2FormAndMnemonicCounts;
var
  F, M, P: Integer;
  FormCount: Integer;
  SeenMnemonic: array of Boolean;
  MnemonicCount: Integer;
  D: PAvxEncodingDescriptor;
begin
  FormCount := 0;
  SetLength(SeenMnemonic, TAvxInstructionDb.MnemonicCount);
  for F := 0 to TAvxInstructionDb.FormCount - 1 do
  begin
    D := TAvxInstructionDb.Form(F);
    if D^.Extension = aeAVX2 then
    begin
      Inc(FormCount);
      SeenMnemonic[D^.MnemonicIndex] := True;
    end;
  end;
  MnemonicCount := 0;
  for M := 0 to High(SeenMnemonic) do if SeenMnemonic[M] then Inc(MnemonicCount);
  Assert.AreEqual(171, FormCount, 'AVX2 form count');
  Assert.AreEqual(138, MnemonicCount, 'AVX2 mnemonic count');
  for M := 0 to TAvxInstructionDb.MnemonicCount - 1 do
    if SeenMnemonic[M] then
      for P := 0 to TAvxInstructionDb.MnemonicFormCount(M) - 1 do
        Assert.IsTrue(TAvxInstructionDb.MnemonicFormIndex(M, P) >= 0, 'AVX2 mnemonic lookup');
end;

procedure TAvx2DatabaseTests.EveryAvx2FormEncodesRegisterPreferred;
begin
  EncodeEveryAvx2Form(False);
end;

procedure TAvx2DatabaseTests.EveryAvx2FormEncodesMemoryPreferred;
begin
  EncodeEveryAvx2Form(True);
end;

initialization
  TDUnitX.RegisterTestFixture(TAvx2DatabaseTests);

end.
