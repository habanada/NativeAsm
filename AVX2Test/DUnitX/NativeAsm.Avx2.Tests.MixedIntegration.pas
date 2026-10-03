unit NativeAsm.Avx2.Tests.MixedIntegration;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TAvx2MixedIntegrationTests = class
  public
    [Test] procedure LegacySseToAvx2;
    [Test] procedure CoreBranchSelectsAvx2Path;
    [Test] procedure CorePointerArithmeticFeedsAvx2;
    [Test] procedure Avx2MaskFeedsBmi1;
    [Test] procedure Avx2MaskFeedsBmi2;
    [Test] procedure SseAvx2ExtractBackToSse;
  end;

implementation

uses
  System.SysUtils,
  NativeAsm.Types,
  NativeAsm.Builder,
  NativeAsm.Extensions,
  NativeAsm.Simd.Types,
  NativeAsm.Simd,
  NativeAsm.Avx.Types,
  NativeAsm.Avx.Cpu,
  NativeAsm.Avx,
  NativeAsm.Bmi.Cpu,
  NativeAsm.Bmi,
  NativeAsm.Avx2.Tests.Support;

procedure TAvx2MixedIntegrationTests.LegacySseToAvx2;
type
  TDwords4 = array[0..3] of Cardinal;
  TQwords4 = array[0..3] of UInt64;
var
  A, BData: TDwords4;
  OutV: TQwords4;
  Builder: TAsmBuilder;
  Exe: TExecutableCode;
  I: Integer;
begin
  if not Avx2Available then begin Assert.IsTrue(True, 'AVX2 unavailable'); Exit; end;
  for I := 0 to 3 do begin A[I] := I + 1; BData[I] := (I + 1) * 10; OutV[I] := 0; end;
  Builder := TAsmBuilder.New;
  try
    Builder.Movdqu(XMM0, OWordPtr(ridRCX)).Paddd(XMM0, OWordPtr(ridRDX)).Vpmovzxdq(YMM1, XMM0).Vmovdqu(YmmWordPtr(ridR8), YMM1).Vzeroupper.Ret;
    Exe := TExecutableCode.Create(Builder.Build);
    try Exe.Run(UInt64(NativeUInt(@A[0])), UInt64(NativeUInt(@BData[0])), UInt64(NativeUInt(@OutV[0]))); finally Exe.Free; end;
  finally
    Builder.Free;
  end;
  for I := 0 to 3 do Assert.IsTrue(OutV[I] = UInt64(A[I] + BData[I]), 'SSE -> AVX2 lane ' + IntToStr(I));
end;

procedure TAvx2MixedIntegrationTests.CoreBranchSelectsAvx2Path;
var
  A, BData, OutV: TUInt32x8;
  Builder: TAsmBuilder;
  Exe: TExecutableCode;
  I: Integer;
begin
  if not Avx2Available then begin Assert.IsTrue(True, 'AVX2 unavailable'); Exit; end;
  for I := 0 to 7 do begin A[I] := 100 + I; BData[I] := 3 + I; end;
  Builder := TAsmBuilder.New;
  try
    Builder.Vmovdqu(YMM0, YmmWordPtr(ridRCX)).Vmovdqu(YMM1, YmmWordPtr(ridRDX)).Test(R9D, R9D).J(cond_JE, 'sub').Vpaddd(YMM2, YMM0, YMM1).J(cond_JMP, 'store').Label_('sub').Vpsubd(YMM2, YMM0, YMM1).Label_('store').Vmovdqu(YmmWordPtr(ridR8), YMM2).Vzeroupper.Ret;
    Exe := TExecutableCode.Create(Builder.Build);
    try
      Exe.Run(UInt64(NativeUInt(@A[0])), UInt64(NativeUInt(@BData[0])), UInt64(NativeUInt(@OutV[0])), 1);
      for I := 0 to 7 do Assert.AreEqual(Cardinal(A[I] + BData[I]), OutV[I], 'branch add');
      Exe.Run(UInt64(NativeUInt(@A[0])), UInt64(NativeUInt(@BData[0])), UInt64(NativeUInt(@OutV[0])), 0);
      for I := 0 to 7 do Assert.AreEqual(Cardinal(A[I] - BData[I]), OutV[I], 'branch sub');
    finally
      Exe.Free;
    end;
  finally
    Builder.Free;
  end;
end;

procedure TAvx2MixedIntegrationTests.CorePointerArithmeticFeedsAvx2;
type
  TBlock16 = array[0..15] of Cardinal;
var
  Data: TBlock16;
  Other, OutV: TUInt32x8;
  Builder: TAsmBuilder;
  Exe: TExecutableCode;
  I: Integer;
begin
  if not Avx2Available then begin Assert.IsTrue(True, 'AVX2 unavailable'); Exit; end;
  for I := 0 to 15 do Data[I] := 1000 + I;
  for I := 0 to 7 do Other[I] := I * 7;
  Builder := TAsmBuilder.New;
  try
    Builder.Mov(RAX, RCX).Add(RAX, 32).Vmovdqu(YMM0, YmmWordPtr(ridRAX)).Vmovdqu(YMM1, YmmWordPtr(ridRDX)).Vpaddd(YMM2, YMM0, YMM1).Vmovdqu(YmmWordPtr(ridR8), YMM2).Vzeroupper.Ret;
    Exe := TExecutableCode.Create(Builder.Build);
    try Exe.Run(UInt64(NativeUInt(@Data[0])), UInt64(NativeUInt(@Other[0])), UInt64(NativeUInt(@OutV[0]))); finally Exe.Free; end;
  finally Builder.Free; end;
  for I := 0 to 7 do Assert.AreEqual(Data[I + 8] + Other[I], OutV[I], 'core pointer arithmetic');
end;

procedure TAvx2MixedIntegrationTests.Avx2MaskFeedsBmi1;
var
  Data: TInt8x32;
  Builder: TAsmBuilder;
  Exe: TExecutableCode;
  Bmi: TBmiCpuStatus;
  R, Expected, Mask: Cardinal;
  I: Integer;
begin
  if not Avx2Available then begin Assert.IsTrue(True, 'AVX2 unavailable'); Exit; end;
  Bmi := TBmiCpuFeatures.Query;
  if not Bmi.CpuBmi1 then begin Assert.IsTrue(True, 'BMI1 unavailable'); Exit; end;
  for I := 0 to 31 do if (I mod 3) = 0 then Data[I] := -1 else Data[I] := 1;
  Mask := $0F0F0F0F;
  Builder := TAsmBuilder.New;
  try
    Builder.Vmovdqu(YMM0, YmmWordPtr(ridRCX)).Vpxor(YMM1, YMM1, YMM1).Vpcmpgtb(YMM2, YMM1, YMM0).Vpmovmskb(EAX, YMM2).Andn(EAX, EAX, EDX).Vzeroupper.Ret;
    Exe := TExecutableCode.Create(Builder.Build);
    try R := Cardinal(Exe.Run(UInt64(NativeUInt(@Data[0])), Mask)); finally Exe.Free; end;
  finally Builder.Free; end;
  Expected := 0;
  for I := 0 to 31 do if Data[I] < 0 then Expected := Expected or (Cardinal(1) shl Byte(I));
  Expected := (not Expected) and Mask;
  Assert.AreEqual(Expected, R, 'AVX2 mask -> BMI1 ANDN');
end;

procedure TAvx2MixedIntegrationTests.Avx2MaskFeedsBmi2;
var
  Data: TInt8x32;
  Builder: TAsmBuilder;
  Exe: TExecutableCode;
  Bmi: TBmiCpuStatus;
  R, PackedValue, SourceMask, SelectMask: Cardinal;
  I, BitPos: Integer;
begin
  if not Avx2Available then begin Assert.IsTrue(True, 'AVX2 unavailable'); Exit; end;
  Bmi := TBmiCpuFeatures.Query;
  if not Bmi.CpuBmi2 then begin Assert.IsTrue(True, 'BMI2 unavailable'); Exit; end;
  for I := 0 to 31 do if (I and 1) = 0 then Data[I] := -1 else Data[I] := 1;
  SelectMask := $55555555;
  Builder := TAsmBuilder.New;
  try
    Builder.Vmovdqu(YMM0, YmmWordPtr(ridRCX)).Vpxor(YMM1, YMM1, YMM1).Vpcmpgtb(YMM2, YMM1, YMM0).Vpmovmskb(EAX, YMM2).Pext(EAX, EAX, EDX).Vzeroupper.Ret;
    Exe := TExecutableCode.Create(Builder.Build);
    try R := Cardinal(Exe.Run(UInt64(NativeUInt(@Data[0])), SelectMask)); finally Exe.Free; end;
  finally Builder.Free; end;
  SourceMask := 0;
  for I := 0 to 31 do if Data[I] < 0 then SourceMask := SourceMask or (Cardinal(1) shl Byte(I));
  PackedValue := 0;
  BitPos := 0;
  for I := 0 to 31 do if (SelectMask and (Cardinal(1) shl Byte(I))) <> 0 then begin if (SourceMask and (Cardinal(1) shl Byte(I))) <> 0 then PackedValue := PackedValue or (Cardinal(1) shl Byte(BitPos)); Inc(BitPos); end;
  Assert.AreEqual(PackedValue, R, 'AVX2 mask -> BMI2 PEXT');
end;

procedure TAvx2MixedIntegrationTests.SseAvx2ExtractBackToSse;
type
  TDwords4 = array[0..3] of Cardinal;
var
  A, OutV: TDwords4;
  BData: TUInt32x8;
  Builder: TAsmBuilder;
  Exe: TExecutableCode;
  I: Integer;
begin
  if not Avx2Available then begin Assert.IsTrue(True, 'AVX2 unavailable'); Exit; end;
  for I := 0 to 3 do A[I] := I + 5;
  for I := 0 to 7 do BData[I] := I + 50;
  Builder := TAsmBuilder.New;
  try
    Builder.Movdqu(XMM0, OWordPtr(ridRCX)).Vpxor(YMM1, YMM1, YMM1).Vinserti128(YMM1, YMM1, XMM0, 0).Vmovdqu(YMM2, YmmWordPtr(ridRDX)).Vpaddd(YMM3, YMM1, YMM2).Vextracti128(XMM4, YMM3, 0).Pxor(XMM5, XMM5).Paddd(XMM4, XMM5).Movdqu(OWordPtr(ridR8), XMM4).Vzeroupper.Ret;
    Exe := TExecutableCode.Create(Builder.Build);
    try Exe.Run(UInt64(NativeUInt(@A[0])), UInt64(NativeUInt(@BData[0])), UInt64(NativeUInt(@OutV[0]))); finally Exe.Free; end;
  finally Builder.Free; end;
  for I := 0 to 3 do Assert.AreEqual(A[I] + BData[I], OutV[I], 'SSE -> AVX2 -> SSE');
end;

initialization
  TDUnitX.RegisterTestFixture(TAvx2MixedIntegrationTests);

end.
