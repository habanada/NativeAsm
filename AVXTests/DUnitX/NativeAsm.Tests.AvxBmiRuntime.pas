unit NativeAsm.Tests.AvxBmiRuntime;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TAvxBmiRuntimeTests = class
  public
    [Test] procedure AvxYmmAddSemantics;
    [Test] procedure AvxGprXmmAndInsertExtractSemantics;
    [Test] procedure AvxScalarMergeSemantics;
    [Test] procedure AvxMaskedMemorySemantics;
    [Test] procedure AvxMxcsrBlendPcmpSemantics;
    [Test] procedure AvxCorrectedVexRestSemantics;
    [Test] procedure Avx2IntegerAndPermuteSemantics;
    [Test] procedure Avx2GatherSemantics;
    [Test] procedure FmaSemantics;
    [Test] procedure Bmi1AndnSemantics;
    [Test] procedure Bmi2DepositExtractSemantics;
    [Test] procedure Bmi2ShiftRotateSemantics;
  end;

implementation

uses
  System.SysUtils,
  NativeAsm.Types,
  NativeAsm.Builder,
  NativeAsm.Extensions,
  NativeAsm.Simd.Types,
  NativeAsm.Avx.Types,
  NativeAsm.Avx.Cpu,
  NativeAsm.Avx,
  NativeAsm.Bmi.Cpu,
  NativeAsm.Bmi;

function PdepRef(Source, Mask: UInt64): UInt64;
var
  SourceBit, MaskBit: UInt64;
begin
  Result := 0;
  SourceBit := 1;
  MaskBit := 1;
  while MaskBit <> 0 do
  begin
    if (Mask and MaskBit) <> 0 then
    begin
      if (Source and SourceBit) <> 0 then Result := Result or MaskBit;
      SourceBit := SourceBit shl 1;
      if SourceBit = 0 then Break;
    end;
    MaskBit := MaskBit shl 1;
  end;
end;

function PextRef(Source, Mask: UInt64): UInt64;
var
  ResultBit, MaskBit: UInt64;
begin
  Result := 0;
  ResultBit := 1;
  MaskBit := 1;
  while MaskBit <> 0 do
  begin
    if (Mask and MaskBit) <> 0 then
    begin
      if (Source and MaskBit) <> 0 then Result := Result or ResultBit;
      ResultBit := ResultBit shl 1;
      if ResultBit = 0 then Break;
    end;
    MaskBit := MaskBit shl 1;
  end;
end;

procedure TAvxBmiRuntimeTests.AvxYmmAddSemantics;
type
  TSingle8 = array[0..7] of Single;
var
  Status: TAvxCpuStatus;
  A, C, Output: TSingle8;
  B: TAsmBuilder;
  Exe: TExecutableCode;
  I: Integer;
begin
  Status := TAvxCpuFeatures.Query;
  if not Status.AvxUsable then
  begin
    Assert.IsTrue(not Status.AvxUsable, 'AVX correctly gated');
    Exit;
  end;
  for I := 0 to 7 do
  begin
    A[I] := I + 1;
    C[I] := (I + 1) * 10;
    Output[I] := 0;
  end;
  B := TAsmBuilder.New;
  try
    B.Vmovdqu(YMM0, YmmWordPtr(ridRCX)).Vaddps(YMM0, YMM0, YmmWordPtr(ridRDX)).Vmovdqu(YmmWordPtr(ridR8), YMM0).Vzeroupper.Ret;
    Exe := TExecutableCode.Create(B.Build);
    try
      Exe.Run(UInt64(NativeUInt(@A[0])), UInt64(NativeUInt(@C[0])), UInt64(NativeUInt(@Output[0])));
    finally
      Exe.Free;
    end;
  finally
    B.Free;
  end;
  for I := 0 to 7 do Assert.IsTrue(Output[I] = A[I] + C[I], 'AVX add lane ' + IntToStr(I));
end;

procedure TAvxBmiRuntimeTests.AvxGprXmmAndInsertExtractSemantics;
var
  Status: TAvxCpuStatus;
  B: TAsmBuilder;
  Exe: TExecutableCode;
  R: UInt64;
begin
  Status := TAvxCpuFeatures.Query;
  if not Status.AvxUsable then
  begin
    Assert.IsTrue(not Status.AvxUsable, 'AVX correctly gated');
    Exit;
  end;
  B := TAsmBuilder.New;
  try
    B.Vmovd(XMM0, ECX).Vmovd(EAX, XMM0).Ret;
    Exe := TExecutableCode.Create(B.Build);
    try R := Exe.Run($FEDCBA9876543210); finally Exe.Free; end;
  finally
    B.Free;
  end;
  Assert.IsTrue(R = $0000000076543210, 'VMOVD GPR/XMM roundtrip');

  B := TAsmBuilder.New;
  try
    B.Vmovq(XMM0, RCX).Vmovq(RAX, XMM0).Ret;
    Exe := TExecutableCode.Create(B.Build);
    try R := Exe.Run($FEDCBA9876543210); finally Exe.Free; end;
  finally
    B.Free;
  end;
  Assert.IsTrue(R = $FEDCBA9876543210, 'VMOVQ GPR/XMM roundtrip');

  B := TAsmBuilder.New;
  try
    B.Vmovd(XMM0, ECX).Vpinsrw(XMM0, XMM0, EDX, 1).Vpextrw(EAX, XMM0, 1).Ret;
    Exe := TExecutableCode.Create(B.Build);
    try R := Exe.Run($11223344, $AABBCCDD); finally Exe.Free; end;
  finally
    B.Free;
  end;
  Assert.IsTrue(R = $CCDD, 'VPINSRW/VPEXTRW roundtrip');

  B := TAsmBuilder.New;
  try
    B.Vmovd(XMM0, ECX).Vextractps(EAX, XMM0, 0).Ret;
    Exe := TExecutableCode.Create(B.Build);
    try R := Exe.Run($89ABCDEF); finally Exe.Free; end;
  finally
    B.Free;
  end;
  Assert.IsTrue(Cardinal(R) = $89ABCDEF, 'VEXTRACTPS roundtrip');
end;

procedure TAvxBmiRuntimeTests.AvxScalarMergeSemantics;
var
  Status: TAvxCpuStatus;
  B: TAsmBuilder;
  Exe: TExecutableCode;
  R: UInt64;
begin
  Status := TAvxCpuFeatures.Query;
  if not Status.AvxUsable then
  begin
    Assert.IsTrue(not Status.AvxUsable, 'AVX correctly gated');
    Exit;
  end;
  B := TAsmBuilder.New;
  try
    B.Vmovq(XMM1, RCX).Vmovq(XMM2, RDX).Vmovss(XMM0, XMM1, XMM2).Vpextrq(RAX, XMM0, 0).Ret;
    Exe := TExecutableCode.Create(B.Build);
    try R := Exe.Run($1122334455667788, $AABBCCDDEEFF0011); finally Exe.Free; end;
  finally
    B.Free;
  end;
  Assert.IsTrue(R = $11223344EEFF0011, 'VMOVSS merge semantics');

  B := TAsmBuilder.New;
  try
    B.Vmovq(XMM1, RCX).Vpinsrq(XMM1, XMM1, RDX, 1).Vmovq(XMM2, R8).Vmovsd(XMM0, XMM1, XMM2).Vpextrq(RAX, XMM0, 1).Ret;
    Exe := TExecutableCode.Create(B.Build);
    try R := Exe.Run($1122334455667788, $AABBCCDDEEFF0011, $0123456789ABCDEF); finally Exe.Free; end;
  finally
    B.Free;
  end;
  Assert.IsTrue(R = $AABBCCDDEEFF0011, 'VMOVSD merge semantics');
end;

procedure TAvxBmiRuntimeTests.AvxMaskedMemorySemantics;
type
  TCardinals = array[0..3] of Cardinal;
var
  Status: TAvxCpuStatus;
  Data: TCardinals;
  B: TAsmBuilder;
  Exe: TExecutableCode;
begin
  Status := TAvxCpuFeatures.Query;
  if not Status.AvxUsable then
  begin
    Assert.IsTrue(not Status.AvxUsable, 'AVX correctly gated');
    Exit;
  end;
  FillChar(Data, SizeOf(Data), 0);
  B := TAsmBuilder.New;
  try
    B.Vmovd(XMM0, EDX).Vmovd(XMM1, R8D).Vmaskmovps(XmmWordPtr(ridRCX), XMM1, XMM0).Ret;
    Exe := TExecutableCode.Create(B.Build);
    try Exe.Run(UInt64(NativeUInt(@Data[0])), $11223344, $80000000); finally Exe.Free; end;
  finally
    B.Free;
  end;
  Assert.IsTrue(Data[0] = $11223344, 'VMASKMOVPS selected lane');
  Assert.IsTrue((Data[1] = 0) and (Data[2] = 0) and (Data[3] = 0), 'VMASKMOVPS unselected lanes');

  if not Status.Avx2Usable then
  begin
    Assert.IsTrue(not Status.Avx2Usable, 'AVX2 correctly gated');
    Exit;
  end;
  FillChar(Data, SizeOf(Data), 0);
  B := TAsmBuilder.New;
  try
    B.Vmovd(XMM0, EDX).Vmovd(XMM1, R8D).Vpmaskmovd(XmmWordPtr(ridRCX), XMM1, XMM0).Ret;
    Exe := TExecutableCode.Create(B.Build);
    try Exe.Run(UInt64(NativeUInt(@Data[0])), $55667788, $80000000); finally Exe.Free; end;
  finally
    B.Free;
  end;
  Assert.IsTrue(Data[0] = $55667788, 'VPMASKMOVD selected lane');
  Assert.IsTrue((Data[1] = 0) and (Data[2] = 0) and (Data[3] = 0), 'VPMASKMOVD unselected lanes');
end;

procedure TAvxBmiRuntimeTests.AvxMxcsrBlendPcmpSemantics;
type
  TMxcsrPair = array[0..1] of Cardinal;
  TPcmpData = packed record
    Pattern: array[0..15] of Byte;
    TextData: array[0..15] of Byte;
  end;
var
  Status: TAvxCpuStatus;
  Values: TMxcsrPair;
  Data: TPcmpData;
  B: TAsmBuilder;
  Exe: TExecutableCode;
  R: UInt64;
begin
  Status := TAvxCpuFeatures.Query;
  if not Status.AvxUsable then
  begin
    Assert.IsTrue(not Status.AvxUsable, 'AVX correctly gated');
    Exit;
  end;
  Values[0] := $FFFFFFFF;
  Values[1] := $FFFFFFFF;
  B := TAsmBuilder.New;
  try
    B.Vstmxcsr(DWordPtr(ridRCX)).Vldmxcsr(DWordPtr(ridRCX)).Vstmxcsr(DWordPtr(ridRCX, 4)).Ret;
    Exe := TExecutableCode.Create(B.Build);
    try Exe.Run(UInt64(NativeUInt(@Values[0]))); finally Exe.Free; end;
  finally
    B.Free;
  end;
  Assert.IsTrue(Values[0] = Values[1], 'MXCSR store/load/store stability');
  Assert.IsTrue((Values[0] and $FFFF0000) = 0, 'MXCSR reserved high bits');

  B := TAsmBuilder.New;
  try
    B.Vmovd(XMM1, EDX).Vmovd(XMM2, R8D).Vmovd(XMM3, R9D).Vblendvps(XMM0, XMM1, XMM2, XMM3).Vmovd(EAX, XMM0).Ret;
    Exe := TExecutableCode.Create(B.Build);
    try R := Exe.Run(0, $11223344, $55667788, $80000000); finally Exe.Free; end;
  finally
    B.Free;
  end;
  Assert.IsTrue(Cardinal(R) = $55667788, 'VBLENDVPS /is4 mask selection');

  FillChar(Data, SizeOf(Data), 0);
  Data.Pattern[0] := Ord('c');
  Data.Pattern[1] := Ord('a');
  Data.Pattern[2] := Ord('t');
  Data.TextData[0] := Ord('x');
  Data.TextData[1] := Ord('x');
  Data.TextData[2] := Ord('c');
  Data.TextData[3] := Ord('a');
  Data.TextData[4] := Ord('t');
  Data.TextData[5] := Ord('y');
  Data.TextData[6] := Ord('y');
  B := TAsmBuilder.New;
  try
    B.Vmovdqu(XMM0, XmmWordPtr(ridRCX)).Vmovdqu(XMM1, XmmWordPtr(ridRCX, 16)).Vpcmpistri(XMM0, XMM1, $0C).Vmovd(XMM2, ECX).Vmovd(EAX, XMM2).Ret;
    Exe := TExecutableCode.Create(B.Build);
    try R := Exe.Run(UInt64(NativeUInt(@Data))); finally Exe.Free; end;
  finally
    B.Free;
  end;
  Assert.IsTrue(Cardinal(R) = 2, 'VPCMPISTRI implicit ECX result');
end;

procedure TAvxBmiRuntimeTests.AvxCorrectedVexRestSemantics;
type
  TAbsData = packed record
    Source: array[0..3] of Integer;
    Output: array[0..3] of Integer;
  end;
  TMaskData = packed record
    Output: array[0..15] of Byte;
  end;
  TFloatData = packed record
    Source: array[0..7] of Single;
    Output: array[0..7] of Single;
  end;
  TDoubleData = packed record
    Source: array[0..3] of Double;
    Output: array[0..3] of Double;
  end;
var
  Status: TAvxCpuStatus;
  AbsData: TAbsData;
  MaskData: TMaskData;
  FloatData: TFloatData;
  DoubleData: TDoubleData;
  B: TAsmBuilder;
  Exe: TExecutableCode;
  I: Integer;
begin
  Status := TAvxCpuFeatures.Query;
  if not Status.AvxUsable then
  begin
    Assert.IsTrue(not Status.AvxUsable, 'AVX correctly gated');
    Exit;
  end;
  FillChar(AbsData, SizeOf(AbsData), 0);
  AbsData.Source[0] := -1;
  AbsData.Source[1] := 2;
  AbsData.Source[2] := -3;
  AbsData.Source[3] := 4;
  B := TAsmBuilder.New;
  try
    B.Vmovdqu(XMM0, XmmWordPtr(ridRCX)).Vpabsd(XMM1, XMM0).Vmovdqu(XmmWordPtr(ridRCX, 16), XMM1).Ret;
    Exe := TExecutableCode.Create(B.Build);
    try Exe.Run(UInt64(NativeUInt(@AbsData))); finally Exe.Free; end;
  finally
    B.Free;
  end;
  for I := 0 to 3 do Assert.IsTrue(AbsData.Output[I] = Abs(AbsData.Source[I]), 'VPABSD lane ' + IntToStr(I));

  for I := 0 to 7 do
  begin
    FloatData.Source[I] := I + 0.5;
    FloatData.Output[I] := 0;
  end;
  B := TAsmBuilder.New;
  try
    B.Vmovups(YMM0, YmmWordPtr(ridRCX)).Vmovups(YmmWordPtr(ridRDX), YMM0).Vzeroupper.Ret;
    Exe := TExecutableCode.Create(B.Build);
    try Exe.Run(UInt64(NativeUInt(@FloatData.Source[0])), UInt64(NativeUInt(@FloatData.Output[0]))); finally Exe.Free; end;
  finally
    B.Free;
  end;
  for I := 0 to 7 do Assert.IsTrue(FloatData.Output[I] = FloatData.Source[I], 'VMOVUPS lane ' + IntToStr(I));

  for I := 0 to 3 do
  begin
    DoubleData.Source[I] := I + 0.25;
    DoubleData.Output[I] := 0;
  end;
  B := TAsmBuilder.New;
  try
    B.Vmovupd(YMM0, YmmWordPtr(ridRCX)).Vmovupd(YmmWordPtr(ridRDX), YMM0).Vzeroupper.Ret;
    Exe := TExecutableCode.Create(B.Build);
    try Exe.Run(UInt64(NativeUInt(@DoubleData.Source[0])), UInt64(NativeUInt(@DoubleData.Output[0]))); finally Exe.Free; end;
  finally
    B.Free;
  end;
  for I := 0 to 3 do Assert.IsTrue(DoubleData.Output[I] = DoubleData.Source[I], 'VMOVUPD lane ' + IntToStr(I));

  FillChar(MaskData, SizeOf(MaskData), $CC);
  B := TAsmBuilder.New;
  try
    B.Push(RDI).Mov(RDI, RCX).Vmovd(XMM0, EDX).Vpcmpeqb(XMM1, XMM1, XMM1).Vmaskmovdqu(XMM0, XMM1).Sfence.Pop(RDI).Ret;
    Exe := TExecutableCode.Create(B.Build);
    try Exe.Run(UInt64(NativeUInt(@MaskData)), $11223344); finally Exe.Free; end;
  finally
    B.Free;
  end;
  Assert.IsTrue((MaskData.Output[0] = $44) and (MaskData.Output[1] = $33) and (MaskData.Output[2] = $22) and (MaskData.Output[3] = $11), 'VMASKMOVDQU stored low dword');
  for I := 4 to 15 do Assert.IsTrue(MaskData.Output[I] = 0, 'VMASKMOVDQU zero lane ' + IntToStr(I));
end;

procedure TAvxBmiRuntimeTests.Avx2IntegerAndPermuteSemantics;
type
  TInt8 = array[0..7] of Integer;
  TUInt64x4 = array[0..3] of UInt64;
var
  Status: TAvxCpuStatus;
  A, C, Output: TInt8;
  QIn, QOut: TUInt64x4;
  B: TAsmBuilder;
  Exe: TExecutableCode;
  I: Integer;
begin
  Status := TAvxCpuFeatures.Query;
  if not Status.Avx2Usable then
  begin
    Assert.IsTrue(not Status.Avx2Usable, 'AVX2 correctly gated');
    Exit;
  end;
  for I := 0 to 7 do
  begin
    A[I] := I + 1;
    C[I] := (I + 1) * 100;
    Output[I] := 0;
  end;
  B := TAsmBuilder.New;
  try
    B.Vmovdqu(YMM0, YmmWordPtr(ridRCX)).Vpaddd(YMM0, YMM0, YmmWordPtr(ridRDX)).Vpslld(YMM0, YMM0, 2).Vmovdqu(YmmWordPtr(ridR8), YMM0).Vzeroupper.Ret;
    Exe := TExecutableCode.Create(B.Build);
    try Exe.Run(UInt64(NativeUInt(@A[0])), UInt64(NativeUInt(@C[0])), UInt64(NativeUInt(@Output[0]))); finally Exe.Free; end;
  finally
    B.Free;
  end;
  for I := 0 to 7 do Assert.IsTrue(Output[I] = (A[I] + C[I]) shl 2, 'AVX2 integer lane ' + IntToStr(I));

  QIn[0] := 10;
  QIn[1] := 20;
  QIn[2] := 30;
  QIn[3] := 40;
  FillChar(QOut, SizeOf(QOut), 0);
  B := TAsmBuilder.New;
  try
    B.Vmovdqu(YMM0, YmmWordPtr(ridRCX)).Vpermq(YMM0, YMM0, $1B).Vmovdqu(YmmWordPtr(ridRDX), YMM0).Vzeroupper.Ret;
    Exe := TExecutableCode.Create(B.Build);
    try Exe.Run(UInt64(NativeUInt(@QIn[0])), UInt64(NativeUInt(@QOut[0]))); finally Exe.Free; end;
  finally
    B.Free;
  end;
  Assert.IsTrue((QOut[0] = 40) and (QOut[1] = 30) and (QOut[2] = 20) and (QOut[3] = 10), 'VPERMQ reverse lanes');
end;

procedure TAvxBmiRuntimeTests.Avx2GatherSemantics;
type
  TGatherData = packed record
    Source: array[0..15] of Cardinal;
    Indices: array[0..7] of Integer;
    Output: array[0..7] of Cardinal;
  end;
var
  Status: TAvxCpuStatus;
  Data: TGatherData;
  B: TAsmBuilder;
  Exe: TExecutableCode;
  I: Integer;
begin
  Status := TAvxCpuFeatures.Query;
  if not Status.Avx2Usable then
  begin
    Assert.IsTrue(not Status.Avx2Usable, 'AVX2 correctly gated');
    Exit;
  end;
  FillChar(Data, SizeOf(Data), 0);
  for I := 0 to 15 do Data.Source[I] := 1000 + Cardinal(I * 10);
  Data.Indices[0] := 7;
  Data.Indices[1] := 0;
  Data.Indices[2] := 14;
  Data.Indices[3] := 3;
  Data.Indices[4] := 9;
  Data.Indices[5] := 2;
  Data.Indices[6] := 15;
  Data.Indices[7] := 5;
  B := TAsmBuilder.New;
  try
    B.Vmovdqu(YMM1, YmmWordPtr(ridRCX, 64)).Vpcmpeqd(YMM2, YMM2, YMM2).Vpgatherdd(YMM0, Vm32y(ridRCX, YMM1, s4), YMM2).Vmovdqu(YmmWordPtr(ridRCX, 96), YMM0).Vzeroupper.Ret;
    Exe := TExecutableCode.Create(B.Build);
    try Exe.Run(UInt64(NativeUInt(@Data))); finally Exe.Free; end;
  finally
    B.Free;
  end;
  for I := 0 to 7 do Assert.IsTrue(Data.Output[I] = Data.Source[Data.Indices[I]], 'Gather lane ' + IntToStr(I));
end;

procedure TAvxBmiRuntimeTests.FmaSemantics;
type
  TSingle8 = array[0..7] of Single;
var
  Status: TAvxCpuStatus;
  A, C, D, Output: TSingle8;
  B: TAsmBuilder;
  Exe: TExecutableCode;
  I: Integer;
begin
  Status := TAvxCpuFeatures.Query;
  if not Status.FmaUsable then
  begin
    Assert.IsTrue(not Status.FmaUsable, 'FMA correctly gated');
    Exit;
  end;
  for I := 0 to 7 do
  begin
    A[I] := I + 1;
    C[I] := (I + 1) * 2;
    D[I] := (I + 1) * 10;
    Output[I] := 0;
  end;
  B := TAsmBuilder.New;
  try
    B.Vmovdqu(YMM0, YmmWordPtr(ridRCX)).Vmovdqu(YMM1, YmmWordPtr(ridRDX)).Vmovdqu(YMM2, YmmWordPtr(ridR8)).Vfmadd231ps(YMM2, YMM0, YMM1).Vmovdqu(YmmWordPtr(ridR9), YMM2).Vzeroupper.Ret;
    Exe := TExecutableCode.Create(B.Build);
    try Exe.Run(UInt64(NativeUInt(@A[0])), UInt64(NativeUInt(@C[0])), UInt64(NativeUInt(@D[0])), UInt64(NativeUInt(@Output[0]))); finally Exe.Free; end;
  finally
    B.Free;
  end;
  for I := 0 to 7 do Assert.IsTrue(Output[I] = D[I] + A[I] * C[I], 'FMA lane ' + IntToStr(I));
end;

procedure TAvxBmiRuntimeTests.Bmi1AndnSemantics;
var
  Status: TBmiCpuStatus;
  A, C, R, Expected: UInt64;
  B: TAsmBuilder;
  Exe: TExecutableCode;
begin
  Status := TBmiCpuFeatures.Query;
  if not Status.CpuBmi1 then
  begin
    Assert.IsTrue(not Status.CpuBmi1, 'BMI1 correctly gated');
    Exit;
  end;
  A := $0123456789ABCDEF;
  C := $0F0F0F0F0F0F0F0F;
  Expected := (not A) and C;
  B := TAsmBuilder.New;
  try
    B.Andn(RAX, RCX, RDX).Ret;
    Exe := TExecutableCode.Create(B.Build);
    try R := Exe.Run(A, C); finally Exe.Free; end;
  finally
    B.Free;
  end;
  Assert.IsTrue(R = Expected, 'ANDN semantics');
end;

procedure TAvxBmiRuntimeTests.Bmi2DepositExtractSemantics;
var
  Status: TBmiCpuStatus;
  Source, Mask, R: UInt64;
  B: TAsmBuilder;
  Exe: TExecutableCode;
begin
  Status := TBmiCpuFeatures.Query;
  if not Status.CpuBmi2 then
  begin
    Assert.IsTrue(not Status.CpuBmi2, 'BMI2 correctly gated');
    Exit;
  end;
  Source := $00000000000000B5;
  Mask := $0000000000005555;
  B := TAsmBuilder.New;
  try
    B.Pdep(RAX, RCX, RDX).Ret;
    Exe := TExecutableCode.Create(B.Build);
    try R := Exe.Run(Source, Mask); finally Exe.Free; end;
  finally
    B.Free;
  end;
  Assert.IsTrue(R = PdepRef(Source, Mask), 'PDEP semantics');

  Source := $FEDCBA9876543210;
  Mask := $00FF00FF00FF00FF;
  B := TAsmBuilder.New;
  try
    B.Pext(RAX, RCX, RDX).Ret;
    Exe := TExecutableCode.Create(B.Build);
    try R := Exe.Run(Source, Mask); finally Exe.Free; end;
  finally
    B.Free;
  end;
  Assert.IsTrue(R = PextRef(Source, Mask), 'PEXT semantics');
end;

procedure TAvxBmiRuntimeTests.Bmi2ShiftRotateSemantics;
var
  Status: TBmiCpuStatus;
  Source, R, Expected: UInt64;
  Count: Integer;
  B: TAsmBuilder;
  Exe: TExecutableCode;
begin
  Status := TBmiCpuFeatures.Query;
  if not Status.CpuBmi2 then
  begin
    Assert.IsTrue(not Status.CpuBmi2, 'BMI2 correctly gated');
    Exit;
  end;
  Source := $0123456789ABCDEF;
  Count := 9;
  B := TAsmBuilder.New;
  try
    B.Shlx(RAX, RCX, RDX).Ret;
    Exe := TExecutableCode.Create(B.Build);
    try R := Exe.Run(Source, UInt64(Count)); finally Exe.Free; end;
  finally
    B.Free;
  end;
  Assert.IsTrue(R = Source shl Count, 'SHLX semantics');

  B := TAsmBuilder.New;
  try
    B.Shrx(RAX, RCX, RDX).Ret;
    Exe := TExecutableCode.Create(B.Build);
    try R := Exe.Run(Source, UInt64(Count)); finally Exe.Free; end;
  finally
    B.Free;
  end;
  Assert.IsTrue(R = Source shr Count, 'SHRX semantics');

  Expected := (Source shr 13) or (Source shl (64 - 13));
  B := TAsmBuilder.New;
  try
    B.Rorx(RAX, RCX, 13).Ret;
    Exe := TExecutableCode.Create(B.Build);
    try R := Exe.Run(Source); finally Exe.Free; end;
  finally
    B.Free;
  end;
  Assert.IsTrue(R = Expected, 'RORX semantics');
end;

initialization
  TDUnitX.RegisterTestFixture(TAvxBmiRuntimeTests);

end.
