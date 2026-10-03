unit NativeAsm.Tests.AvxBmiDatabase;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TAvxBmiDatabaseTests = class
  public
    [Test] procedure AvxCountsHashAndDistribution;
    [Test] procedure AvxMnemonicLookupRoundTrips;
    [Test] procedure AvxEveryFormIsOwnedAndStructurallyValid;
    [Test] procedure AvxEveryOperandDescriptorIsConsistent;
    [Test] procedure AvxEveryFormSynthesizesAndEncodesRegisterPreferred;
    [Test] procedure AvxEveryFormSynthesizesAndEncodesMemoryPreferred;
    [Test] procedure AvxDatabaseBoundsAreGuarded;
    [Test] procedure BmiCountsHashAndDistribution;
    [Test] procedure BmiMnemonicLookupRoundTrips;
    [Test] procedure BmiEveryFormIsOwnedAndStructurallyValid;
    [Test] procedure BmiEveryFormSynthesizesAndEncodesBothPreferences;
    [Test] procedure BmiDatabaseBoundsAreGuarded;
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
  NativeAsm.Bmi.Db,
  NativeAsm.Bmi.Encoder,
  NativeAsm.Tests.SimdSupport;

function GprIdForOperand(Index: Integer): Integer;
begin
  case Index of
    0: Result := 1;
    1: Result := 2;
    2: Result := 8;
  else
    Result := 9;
  end;
end;

function AvxMemoryForClass(C: TAvxDbMemClass): TAvxMemory;
begin
  case C of
    amc128: Result := TAvxMemory.Create(ridRAX, 16, ams128);
    amc256: Result := TAvxMemory.Create(ridRAX, 16, ams256);
    amc8: Result := TAvxMemory.Create(ridRAX, 16, ams8);
    amc16: Result := TAvxMemory.Create(ridRAX, 16, ams16);
    amc32: Result := TAvxMemory.Create(ridRAX, 16, ams32);
    amc64: Result := TAvxMemory.Create(ridRAX, 16, ams64);
    amcVm32x: Result := Vm32x(ridRAX, XMM4, s4, 16);
    amcVm32y: Result := Vm32y(ridRAX, YMM4, s4, 16);
    amcVm64x: Result := Vm64x(ridRAX, XMM4, s4, 16);
    amcVm64y: Result := Vm64y(ridRAX, YMM4, s4, 16);
  else
    raise Exception.Create('Unsupported synthesized AVX memory class');
  end;
end;

function AvxOperandForSpec(const Spec: TAvxDbOperandSpec; OperandIndex: Integer; PreferMemory: Boolean): TAvxOperand;
var
  UseMemory: Boolean;
begin
  if (Spec.Kinds and AVX_OK_IMM) <> 0 then Exit(AvxOp(1));
  UseMemory := PreferMemory and ((Spec.Kinds and AVX_OK_MEM) <> 0);
  if not UseMemory and ((Spec.Kinds and AVX_OK_REG) <> 0) then
  begin
    case Spec.RegClass of
      arcXmm: Exit(AvxOp(XmmReg(OperandIndex + 1)));
      arcYmm: Exit(AvxOp(YmmReg(OperandIndex + 1)));
      arcGp32: Exit(AvxOp(Gpr32(GprIdForOperand(OperandIndex))));
      arcGp64: Exit(AvxOp(Gpr64(GprIdForOperand(OperandIndex))));
    else
      raise Exception.Create('Unsupported synthesized AVX register class');
    end;
  end;
  if (Spec.Kinds and AVX_OK_MEM) <> 0 then Exit(AvxOp(AvxMemoryForClass(Spec.MemClass)));
  raise Exception.Create('Unsupported synthesized AVX operand');
end;

function BuildAvxOperands(FormIndex: Integer; PreferMemory: Boolean): TAvxOperandArray;
var
  D: PAvxEncodingDescriptor;
  I: Integer;
begin
  D := TAvxInstructionDb.Form(FormIndex);
  SetLength(Result, D^.OperandCount);
  for I := 0 to D^.OperandCount - 1 do
    Result[I] := AvxOperandForSpec(TAvxInstructionDb.Operand(FormIndex, I)^, I, PreferMemory);
end;

function BmiMemoryForClass(C: TBmiDbMemClass): TMemory;
begin
  case C of
    bmc32: Result := DWordPtr(ridRAX, 16);
    bmc64: Result := QWordPtr(ridRAX, 16);
  else
    raise Exception.Create('Unsupported synthesized BMI memory class');
  end;
end;

function BmiOperandForSpec(const Spec: TBmiDbOperandSpec; OperandIndex: Integer; PreferMemory: Boolean): TOperand;
var
  UseMemory: Boolean;
begin
  if (Spec.Kinds and BMI_OK_IMM) <> 0 then Exit(BmiOp(1));
  UseMemory := PreferMemory and ((Spec.Kinds and BMI_OK_MEM) <> 0);
  if not UseMemory and ((Spec.Kinds and BMI_OK_REG) <> 0) then
  begin
    case Spec.RegClass of
      brc32: Exit(BmiOp(Gpr32(GprIdForOperand(OperandIndex))));
      brc64: Exit(BmiOp(Gpr64(GprIdForOperand(OperandIndex))));
    else
      raise Exception.Create('Unsupported synthesized BMI register class');
    end;
  end;
  if (Spec.Kinds and BMI_OK_MEM) <> 0 then Exit(BmiOp(BmiMemoryForClass(Spec.MemClass)));
  raise Exception.Create('Unsupported synthesized BMI operand');
end;

function BuildBmiOperands(FormIndex: Integer; PreferMemory: Boolean): TBmiOperandArray;
var
  D: PBmiEncodingDescriptor;
  I: Integer;
begin
  D := TBmiInstructionDb.Form(FormIndex);
  SetLength(Result, D^.OperandCount);
  for I := 0 to D^.OperandCount - 1 do
    Result[I] := BmiOperandForSpec(TBmiInstructionDb.Operand(FormIndex, I)^, I, PreferMemory);
end;

procedure TAvxBmiDatabaseTests.AvxCountsHashAndDistribution;
var
  I, AvxCount, Avx2Count, FmaCount, ImmediateCount: Integer;
  D: PAvxEncodingDescriptor;
begin
  Assert.IsTrue(TAvxInstructionDb.FormCount = 644);
  Assert.IsTrue(TAvxInstructionDb.MnemonicCount = 340);
  Assert.IsTrue(SameText(TAvxInstructionDb.SourceSha256, '0bc3fde0376e3c7db93ce1fa6da35b9d69b868db738e60dba382a2bee54d1f48'));
  AvxCount := 0;
  Avx2Count := 0;
  FmaCount := 0;
  ImmediateCount := 0;
  for I := 0 to TAvxInstructionDb.FormCount - 1 do
  begin
    D := TAvxInstructionDb.Form(I);
    case D^.Extension of
      aeAVX: Inc(AvxCount);
      aeAVX2: Inc(Avx2Count);
      aeFMA: Inc(FmaCount);
    end;
    if (D^.ImmediateOperandIdx >= 0) and
       ((TAvxInstructionDb.Operand(I, D^.ImmediateOperandIdx)^.Kinds and AVX_OK_IMM) <> 0) then
      Inc(ImmediateCount);
  end;
  Assert.IsTrue(AvxCount = 377);
  Assert.IsTrue(Avx2Count = 171);
  Assert.IsTrue(FmaCount = 96);
  Assert.IsTrue(ImmediateCount = 84);
end;

procedure TAvxBmiDatabaseTests.AvxMnemonicLookupRoundTrips;
var
  I, J: Integer;
  Name: string;
begin
  for I := 0 to TAvxInstructionDb.MnemonicCount - 1 do
  begin
    Name := TAvxInstructionDb.MnemonicName(I);
    Assert.IsTrue(Name <> '', 'Empty AVX mnemonic at ' + IntToStr(I));
    Assert.IsTrue(TAvxInstructionDb.MnemonicIndexOf(Name) = I, 'Exact lookup failed for ' + Name);
    Assert.IsTrue(TAvxInstructionDb.MnemonicIndexOf(UpperCase(Name)) = I, 'Uppercase lookup failed for ' + Name);
    Assert.IsTrue(TAvxInstructionDb.MnemonicIndexOf(LowerCase(Name)) = I, 'Lowercase lookup failed for ' + Name);
    Assert.IsTrue(TAvxInstructionDb.MnemonicFormCount(I) > 0, 'No forms for ' + Name);
    for J := I + 1 to TAvxInstructionDb.MnemonicCount - 1 do
      Assert.IsTrue(not SameText(Name, TAvxInstructionDb.MnemonicName(J)), 'Duplicate AVX mnemonic ' + Name);
  end;
  Assert.IsTrue(TAvxInstructionDb.MnemonicIndexOf('not-a-nativeasm-avx-mnemonic') = -1);
end;

procedure TAvxBmiDatabaseTests.AvxEveryFormIsOwnedAndStructurallyValid;
var
  Seen: array of Boolean;
  M, P, F: Integer;
  D: PAvxEncodingDescriptor;
  Name: string;
begin
  SetLength(Seen, TAvxInstructionDb.FormCount);
  for M := 0 to TAvxInstructionDb.MnemonicCount - 1 do
    for P := 0 to TAvxInstructionDb.MnemonicFormCount(M) - 1 do
    begin
      F := TAvxInstructionDb.MnemonicFormIndex(M, P);
      Assert.IsTrue((F >= 0) and (F < TAvxInstructionDb.FormCount));
      D := TAvxInstructionDb.Form(F);
      Assert.IsTrue(D^.MnemonicIndex = M, 'Descriptor owner mismatch at form ' + IntToStr(F));
      Seen[F] := True;
    end;
  for F := 0 to TAvxInstructionDb.FormCount - 1 do
  begin
    Assert.IsTrue(Seen[F], 'Orphan AVX form ' + IntToStr(F));
    D := TAvxInstructionDb.Form(F);
    Assert.IsTrue(D^.MnemonicIndex < TAvxInstructionDb.MnemonicCount);
    Assert.IsTrue(D^.VexL <= 1);
    Assert.IsTrue(D^.VexPP <= 3);
    Assert.IsTrue(D^.VexW <= 1);
    Assert.IsTrue(D^.OperandCount <= 4);
    Assert.IsTrue((D^.ModRegOperandIdx >= -1) and (D^.ModRegOperandIdx < D^.OperandCount));
    Assert.IsTrue((D^.ModRegFixed >= -1) and (D^.ModRegFixed <= 7));
    Assert.IsTrue((D^.ModRmOperandIdx >= -1) and (D^.ModRmOperandIdx < D^.OperandCount));
    Assert.IsTrue((D^.VvvvOperandIdx >= -1) and (D^.VvvvOperandIdx < D^.OperandCount));
    Assert.IsTrue((D^.ImmediateOperandIdx >= -1) and (D^.ImmediateOperandIdx < D^.OperandCount));
    Name := TAvxInstructionDb.MnemonicName(D^.MnemonicIndex);
    Assert.IsTrue(Pos(LowerCase(Name), LowerCase(TAvxInstructionDb.SourceSignature(F))) > 0, 'Signature mismatch at form ' + IntToStr(F));
    Assert.IsTrue(Pos('VEX', UpperCase(TAvxInstructionDb.SourceEncoding(F))) > 0, 'Missing VEX metadata at form ' + IntToStr(F));
  end;
end;

procedure TAvxBmiDatabaseTests.AvxEveryOperandDescriptorIsConsistent;
var
  F, I: Integer;
  D: PAvxEncodingDescriptor;
  S: PAvxDbOperandSpec;
begin
  for F := 0 to TAvxInstructionDb.FormCount - 1 do
  begin
    D := TAvxInstructionDb.Form(F);
    for I := 0 to D^.OperandCount - 1 do
    begin
      S := TAvxInstructionDb.Operand(F, I);
      Assert.IsTrue((S^.Kinds <> 0) and ((S^.Kinds and not (AVX_OK_REG or AVX_OK_MEM or AVX_OK_IMM)) = 0), 'Invalid AVX operand kind bits');
      if (S^.Kinds and AVX_OK_REG) <> 0 then Assert.IsTrue(S^.RegClass <> arcNone) else Assert.IsTrue(S^.RegClass = arcNone);
      if (S^.Kinds and AVX_OK_MEM) <> 0 then Assert.IsTrue(S^.MemClass <> amcNone) else Assert.IsTrue(S^.MemClass = amcNone);
      if (S^.Kinds and AVX_OK_IMM) <> 0 then Assert.IsTrue(S^.ImmBytes = 1) else Assert.IsTrue(S^.ImmBytes = 0);
    end;
    if D^.ImmediateOperandIdx >= 0 then
      if D^.FormTag = aefRVMS then
        Assert.IsTrue((TAvxInstructionDb.Operand(F, D^.ImmediateOperandIdx)^.Kinds and AVX_OK_REG) <> 0)
      else
        Assert.IsTrue((TAvxInstructionDb.Operand(F, D^.ImmediateOperandIdx)^.Kinds and AVX_OK_IMM) <> 0);
  end;
end;

procedure EncodeEveryAvxForm(PreferMemory: Boolean);
var
  F, Selected: Integer;
  Ops: TAvxOperandArray;
  B: TAsmBuilder;
  Name: string;
begin
  for F := 0 to TAvxInstructionDb.FormCount - 1 do
  begin
    Ops := BuildAvxOperands(F, PreferMemory);
    Name := TAvxInstructionDb.MnemonicName(TAvxInstructionDb.Form(F)^.MnemonicIndex);
    Selected := TAvxInstructionEncoder.SelectForm(Name, Ops);
    Assert.IsTrue((Selected >= 0) and (Selected < TAvxInstructionDb.FormCount), 'No synthesized selection for form ' + IntToStr(F));
    Assert.IsTrue(TAvxInstructionDb.Form(Selected)^.MnemonicIndex = TAvxInstructionDb.Form(F)^.MnemonicIndex, 'Synthesized selection changed mnemonic');
    B := TAsmBuilder.New;
    try
      TAvxInstructionEncoder.Encode(B, Name, Ops);
      Assert.IsTrue(B.CodeSize > 0, 'No bytes emitted for form ' + IntToStr(F));
      Assert.IsTrue(Length(B.Build) = B.CodeSize, 'Build size mismatch for form ' + IntToStr(F));
    finally
      B.Free;
    end;
  end;
end;

procedure TAvxBmiDatabaseTests.AvxEveryFormSynthesizesAndEncodesRegisterPreferred;
begin
  EncodeEveryAvxForm(False);
end;

procedure TAvxBmiDatabaseTests.AvxEveryFormSynthesizesAndEncodesMemoryPreferred;
begin
  EncodeEveryAvxForm(True);
end;

procedure TAvxBmiDatabaseTests.AvxDatabaseBoundsAreGuarded;
var
  Raised: Boolean;
begin
  Raised := False;
  try TAvxInstructionDb.MnemonicName(-1); except on E: EArgumentOutOfRangeException do Raised := True; end;
  Assert.IsTrue(Raised);
  Raised := False;
  try TAvxInstructionDb.MnemonicName(TAvxInstructionDb.MnemonicCount); except on E: EArgumentOutOfRangeException do Raised := True; end;
  Assert.IsTrue(Raised);
  Raised := False;
  try TAvxInstructionDb.Form(-1); except on E: EArgumentOutOfRangeException do Raised := True; end;
  Assert.IsTrue(Raised);
  Raised := False;
  try TAvxInstructionDb.Form(TAvxInstructionDb.FormCount); except on E: EArgumentOutOfRangeException do Raised := True; end;
  Assert.IsTrue(Raised);
  Raised := False;
  try TAvxInstructionDb.MnemonicFormIndex(0, TAvxInstructionDb.MnemonicFormCount(0)); except on E: EArgumentOutOfRangeException do Raised := True; end;
  Assert.IsTrue(Raised);
end;

procedure TAvxBmiDatabaseTests.BmiCountsHashAndDistribution;
var
  I, Bmi1Count, Bmi2Count, ImmediateCount: Integer;
  D: PBmiEncodingDescriptor;
begin
  Assert.IsTrue(TBmiInstructionDb.FormCount = 26);
  Assert.IsTrue(TBmiInstructionDb.MnemonicCount = 13);
  Assert.IsTrue(SameText(TBmiInstructionDb.SourceSha256, '0bc3fde0376e3c7db93ce1fa6da35b9d69b868db738e60dba382a2bee54d1f48'));
  Bmi1Count := 0;
  Bmi2Count := 0;
  ImmediateCount := 0;
  for I := 0 to TBmiInstructionDb.FormCount - 1 do
  begin
    D := TBmiInstructionDb.Form(I);
    case D^.Extension of
      beBMI1: Inc(Bmi1Count);
      beBMI2: Inc(Bmi2Count);
    end;
    if (D^.ImmediateOperandIdx >= 0) and
       ((TBmiInstructionDb.Operand(I, D^.ImmediateOperandIdx)^.Kinds and BMI_OK_IMM) <> 0) then
      Inc(ImmediateCount);
  end;
  Assert.IsTrue(Bmi1Count = 10);
  Assert.IsTrue(Bmi2Count = 16);
  Assert.IsTrue(ImmediateCount = 2);
end;

procedure TAvxBmiDatabaseTests.BmiMnemonicLookupRoundTrips;
var
  I, J: Integer;
  Name: string;
begin
  for I := 0 to TBmiInstructionDb.MnemonicCount - 1 do
  begin
    Name := TBmiInstructionDb.MnemonicName(I);
    Assert.IsTrue(TBmiInstructionDb.MnemonicIndexOf(Name) = I);
    Assert.IsTrue(TBmiInstructionDb.MnemonicIndexOf(UpperCase(Name)) = I);
    Assert.IsTrue(TBmiInstructionDb.MnemonicFormCount(I) > 0);
    for J := I + 1 to TBmiInstructionDb.MnemonicCount - 1 do
      Assert.IsTrue(not SameText(Name, TBmiInstructionDb.MnemonicName(J)), 'Duplicate BMI mnemonic ' + Name);
  end;
  Assert.IsTrue(TBmiInstructionDb.MnemonicIndexOf('tzcnt') = -1);
  Assert.IsTrue(TBmiInstructionDb.MnemonicIndexOf('not-a-nativeasm-bmi-mnemonic') = -1);
end;

procedure TAvxBmiDatabaseTests.BmiEveryFormIsOwnedAndStructurallyValid;
var
  Seen: array of Boolean;
  M, P, F, I: Integer;
  D: PBmiEncodingDescriptor;
  S: PBmiDbOperandSpec;
begin
  SetLength(Seen, TBmiInstructionDb.FormCount);
  for M := 0 to TBmiInstructionDb.MnemonicCount - 1 do
    for P := 0 to TBmiInstructionDb.MnemonicFormCount(M) - 1 do
    begin
      F := TBmiInstructionDb.MnemonicFormIndex(M, P);
      Assert.IsTrue((F >= 0) and (F < TBmiInstructionDb.FormCount));
      D := TBmiInstructionDb.Form(F);
      Assert.IsTrue(D^.MnemonicIndex = M);
      Seen[F] := True;
    end;
  for F := 0 to TBmiInstructionDb.FormCount - 1 do
  begin
    Assert.IsTrue(Seen[F], 'Orphan BMI form ' + IntToStr(F));
    D := TBmiInstructionDb.Form(F);
    Assert.IsTrue(D^.VexPP <= 3);
    Assert.IsTrue(D^.VexW <= 1);
    Assert.IsTrue(D^.OperandCount <= 3);
    Assert.IsTrue((D^.ModRegOperandIdx >= -1) and (D^.ModRegOperandIdx < D^.OperandCount));
    Assert.IsTrue((D^.ModRegFixed >= -1) and (D^.ModRegFixed <= 7));
    Assert.IsTrue((D^.ModRmOperandIdx >= -1) and (D^.ModRmOperandIdx < D^.OperandCount));
    Assert.IsTrue((D^.VvvvOperandIdx >= -1) and (D^.VvvvOperandIdx < D^.OperandCount));
    Assert.IsTrue((D^.ImmediateOperandIdx >= -1) and (D^.ImmediateOperandIdx < D^.OperandCount));
    Assert.IsTrue(Pos('VEX', UpperCase(TBmiInstructionDb.SourceEncoding(F))) > 0);
    for I := 0 to D^.OperandCount - 1 do
    begin
      S := TBmiInstructionDb.Operand(F, I);
      Assert.IsTrue((S^.Kinds <> 0) and ((S^.Kinds and not (BMI_OK_REG or BMI_OK_MEM or BMI_OK_IMM)) = 0));
      if (S^.Kinds and BMI_OK_REG) <> 0 then Assert.IsTrue(S^.RegClass <> brcNone) else Assert.IsTrue(S^.RegClass = brcNone);
      if (S^.Kinds and BMI_OK_MEM) <> 0 then Assert.IsTrue(S^.MemClass <> bmcNone) else Assert.IsTrue(S^.MemClass = bmcNone);
      if (S^.Kinds and BMI_OK_IMM) <> 0 then Assert.IsTrue(S^.ImmBytes = 1) else Assert.IsTrue(S^.ImmBytes = 0);
    end;
  end;
end;

procedure EncodeEveryBmiForm(PreferMemory: Boolean);
var
  F, Selected: Integer;
  Ops: TBmiOperandArray;
  B: TAsmBuilder;
  Name: string;
begin
  for F := 0 to TBmiInstructionDb.FormCount - 1 do
  begin
    Ops := BuildBmiOperands(F, PreferMemory);
    Name := TBmiInstructionDb.MnemonicName(TBmiInstructionDb.Form(F)^.MnemonicIndex);
    Selected := TBmiInstructionEncoder.SelectForm(Name, Ops);
    Assert.IsTrue((Selected >= 0) and (Selected < TBmiInstructionDb.FormCount), 'No synthesized BMI selection for form ' + IntToStr(F));
    B := TAsmBuilder.New;
    try
      TBmiInstructionEncoder.Encode(B, Name, Ops);
      Assert.IsTrue(B.CodeSize > 0, 'No BMI bytes emitted for form ' + IntToStr(F));
    finally
      B.Free;
    end;
  end;
end;

procedure TAvxBmiDatabaseTests.BmiEveryFormSynthesizesAndEncodesBothPreferences;
begin
  EncodeEveryBmiForm(False);
  EncodeEveryBmiForm(True);
end;

procedure TAvxBmiDatabaseTests.BmiDatabaseBoundsAreGuarded;
var
  Raised: Boolean;
begin
  Raised := False;
  try TBmiInstructionDb.MnemonicName(-1); except on E: EArgumentOutOfRangeException do Raised := True; end;
  Assert.IsTrue(Raised);
  Raised := False;
  try TBmiInstructionDb.Form(TBmiInstructionDb.FormCount); except on E: EArgumentOutOfRangeException do Raised := True; end;
  Assert.IsTrue(Raised);
  Raised := False;
  try TBmiInstructionDb.MnemonicFormIndex(0, TBmiInstructionDb.MnemonicFormCount(0)); except on E: EArgumentOutOfRangeException do Raised := True; end;
  Assert.IsTrue(Raised);
end;

initialization
  TDUnitX.RegisterTestFixture(TAvxBmiDatabaseTests);

end.
