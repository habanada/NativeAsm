unit NativeAsm.AvxShowcase.Fft;

interface

uses
  NativeAsm.Extensions,
  NativeAsm.AvxShowcase.Types;

type
  TNativeAsmFft8 = class sealed
  private
    class function BitReverseKernel: TExecutableCode; static;
    class function ButterflyKernel: TExecutableCode; static;
  public
    class function IsSupported: Boolean; static;
    class procedure Execute(const Input: TComplex8; out Output: TComplex8); static;
    class procedure ScalarReference(const Input: TComplex8; out Output: TComplex8); static;
    class function VerifyImpulseFlat(Epsilon: Single = 1.0E-4): Boolean; static;
    class function VerifyAgainstScalar(const Input: TComplex8; Epsilon: Single = 2.0E-4): Boolean; static;
  end;

implementation

uses
  System.SysUtils,
  System.Math,
  NativeAsm.Types,
  NativeAsm.Builder,
  NativeAsm.Simd.Types,
  NativeAsm.Avx.Types,
  NativeAsm.Avx.Cpu,
  NativeAsm.Avx;

type
  TFftButterflyBlock = packed record
    ARe: TSingle8;
    AIm: TSingle8;
    BRe: TSingle8;
    BIm: TSingle8;
    WRe: TSingle8;
    WIm: TSingle8;
    TopRe: TSingle8;
    TopIm: TSingle8;
    BottomRe: TSingle8;
    BottomIm: TSingle8;
  end;

const
  OFS_ARE = 0;
  OFS_AIM = 32;
  OFS_BRE = 64;
  OFS_BIM = 96;
  OFS_WRE = 128;
  OFS_WIM = 160;
  OFS_TOPRE = 192;
  OFS_TOPIM = 224;
  OFS_BOTTOMRE = 256;
  OFS_BOTTOMIM = 288;

var
  GBitReverseKernel: TExecutableCode;
  GButterflyKernel: TExecutableCode;

function BuildBitReverseKernel: TExecutableCode;
var
  B: TAsmBuilder;
begin
  B := TAsmBuilder.New;
  try
    B.Vmovups(YMM0, YmmWordPtr(ridRCX));
    B.Vperm2f128(YMM1, YMM0, YMM0, $01);
    B.Vshufps(YMM2, YMM0, YMM1, $88);
    B.Vshufps(YMM2, YMM2, YMM2, $D8);
    B.Vshufps(YMM3, YMM0, YMM1, $DD);
    B.Vshufps(YMM3, YMM3, YMM3, $D8);
    B.Vperm2f128(YMM4, YMM2, YMM3, $20);
    B.Vmovups(YmmWordPtr(ridRDX), YMM4);
    B.Vzeroupper.Ret;
    Result := TExecutableCode.Create(B.Build);
  finally
    B.Free;
  end;
end;

function BuildButterflyKernel: TExecutableCode;
var
  B: TAsmBuilder;
begin
  B := TAsmBuilder.New;
  try
    B.Sub(RSP, 96);
    B.Vmovdqu(XmmWordPtr(ridRSP, 0), XMM6);
    B.Vmovdqu(XmmWordPtr(ridRSP, 16), XMM7);
    B.Vmovdqu(XmmWordPtr(ridRSP, 32), XMM8);
    B.Vmovdqu(XmmWordPtr(ridRSP, 48), XMM9);
    B.Vmovdqu(XmmWordPtr(ridRSP, 64), XMM10);
    B.Vmovdqu(XmmWordPtr(ridRSP, 80), XMM11);
    B.Vmovups(YMM0, YmmWordPtr(ridRCX, OFS_BRE));
    B.Vmovups(YMM1, YmmWordPtr(ridRCX, OFS_WRE));
    B.Vmovups(YMM2, YmmWordPtr(ridRCX, OFS_BIM));
    B.Vmovups(YMM3, YmmWordPtr(ridRCX, OFS_WIM));
    B.Vmulps(YMM4, YMM2, YMM3);
    B.Vfmsub231ps(YMM4, YMM0, YMM1);
    B.Vmulps(YMM5, YMM2, YMM1);
    B.Vfmadd231ps(YMM5, YMM0, YMM3);
    B.Vmovups(YMM6, YmmWordPtr(ridRCX, OFS_ARE));
    B.Vmovups(YMM7, YmmWordPtr(ridRCX, OFS_AIM));
    B.Vaddps(YMM8, YMM6, YMM4);
    B.Vaddps(YMM9, YMM7, YMM5);
    B.Vsubps(YMM10, YMM6, YMM4);
    B.Vsubps(YMM11, YMM7, YMM5);
    B.Vmovups(YmmWordPtr(ridRCX, OFS_TOPRE), YMM8);
    B.Vmovups(YmmWordPtr(ridRCX, OFS_TOPIM), YMM9);
    B.Vmovups(YmmWordPtr(ridRCX, OFS_BOTTOMRE), YMM10);
    B.Vmovups(YmmWordPtr(ridRCX, OFS_BOTTOMIM), YMM11);
    B.Vmovdqu(XMM6, XmmWordPtr(ridRSP, 0));
    B.Vmovdqu(XMM7, XmmWordPtr(ridRSP, 16));
    B.Vmovdqu(XMM8, XmmWordPtr(ridRSP, 32));
    B.Vmovdqu(XMM9, XmmWordPtr(ridRSP, 48));
    B.Vmovdqu(XMM10, XmmWordPtr(ridRSP, 64));
    B.Vmovdqu(XMM11, XmmWordPtr(ridRSP, 80));
    B.Add(RSP, 96);
    B.Vzeroupper.Ret;
    Result := TExecutableCode.Create(B.Build);
  finally
    B.Free;
  end;
end;

class function TNativeAsmFft8.BitReverseKernel: TExecutableCode;
begin
  if GBitReverseKernel = nil then GBitReverseKernel := BuildBitReverseKernel;
  Result := GBitReverseKernel;
end;

class function TNativeAsmFft8.ButterflyKernel: TExecutableCode;
begin
  if GButterflyKernel = nil then GButterflyKernel := BuildButterflyKernel;
  Result := GButterflyKernel;
end;

class function TNativeAsmFft8.IsSupported: Boolean;
var
  S: TAvxCpuStatus;
begin
  S := TAvxCpuFeatures.Query;
  Result := S.FmaUsable;
end;

class procedure TNativeAsmFft8.Execute(const Input: TComplex8; out Output: TComplex8);
var
  S: TAvxCpuStatus;
  SourceRe, SourceIm: TSingle8;
  WorkRe, WorkIm: TSingle8;
  Block: TFftButterflyBlock;
  BR, BF: TExecutableCode;
  I, StageSize, HalfSize, GroupStart, J, P: Integer;
  Angle: Double;
begin
  S := TAvxCpuFeatures.Query;
  if not S.FmaUsable then raise ENotSupportedException.Create('FFT showcase requires AVX and FMA');

  for I := 0 to 7 do
  begin
    SourceRe[I] := Input[I].Re;
    SourceIm[I] := Input[I].Im;
  end;

  BR := BitReverseKernel;
  BR.Run(UInt64(NativeUInt(@SourceRe[0])), UInt64(NativeUInt(@WorkRe[0])));
  BR.Run(UInt64(NativeUInt(@SourceIm[0])), UInt64(NativeUInt(@WorkIm[0])));

  BF := ButterflyKernel;
  StageSize := 2;
  while StageSize <= 8 do
  begin
    FillChar(Block, SizeOf(Block), 0);
    HalfSize := StageSize div 2;
    P := 0;
    GroupStart := 0;
    while GroupStart < 8 do
    begin
      for J := 0 to HalfSize - 1 do
      begin
        Block.ARe[P] := WorkRe[GroupStart + J];
        Block.AIm[P] := WorkIm[GroupStart + J];
        Block.BRe[P] := WorkRe[GroupStart + J + HalfSize];
        Block.BIm[P] := WorkIm[GroupStart + J + HalfSize];
        Angle := -2.0 * Pi * J / StageSize;
        Block.WRe[P] := Cos(Angle);
        Block.WIm[P] := Sin(Angle);
        Inc(P);
      end;
      Inc(GroupStart, StageSize);
    end;

    BF.Run(UInt64(NativeUInt(@Block)));

    P := 0;
    GroupStart := 0;
    while GroupStart < 8 do
    begin
      for J := 0 to HalfSize - 1 do
      begin
        WorkRe[GroupStart + J] := Block.TopRe[P];
        WorkIm[GroupStart + J] := Block.TopIm[P];
        WorkRe[GroupStart + J + HalfSize] := Block.BottomRe[P];
        WorkIm[GroupStart + J + HalfSize] := Block.BottomIm[P];
        Inc(P);
      end;
      Inc(GroupStart, StageSize);
    end;

    StageSize := StageSize * 2;
  end;

  for I := 0 to 7 do
  begin
    Output[I].Re := WorkRe[I];
    Output[I].Im := WorkIm[I];
  end;
end;

class procedure TNativeAsmFft8.ScalarReference(const Input: TComplex8; out Output: TComplex8);
var
  K, N: Integer;
  Angle, C, S: Double;
  ReAcc, ImAcc: Double;
begin
  for K := 0 to 7 do
  begin
    ReAcc := 0;
    ImAcc := 0;
    for N := 0 to 7 do
    begin
      Angle := -2.0 * Pi * K * N / 8.0;
      C := Cos(Angle);
      S := Sin(Angle);
      ReAcc := ReAcc + Input[N].Re * C - Input[N].Im * S;
      ImAcc := ImAcc + Input[N].Re * S + Input[N].Im * C;
    end;
    Output[K].Re := ReAcc;
    Output[K].Im := ImAcc;
  end;
end;

class function TNativeAsmFft8.VerifyImpulseFlat(Epsilon: Single): Boolean;
var
  Input, Output: TComplex8;
  I: Integer;
begin
  FillChar(Input, SizeOf(Input), 0);
  Input[0].Re := 1.0;
  Execute(Input, Output);
  Result := True;
  for I := 0 to 7 do
    if not ComplexNearlyEqual(Output[I], TComplex32.Create(1.0, 0.0), Epsilon) then Exit(False);
end;

class function TNativeAsmFft8.VerifyAgainstScalar(const Input: TComplex8; Epsilon: Single): Boolean;
var
  Actual, Expected: TComplex8;
  I: Integer;
begin
  Execute(Input, Actual);
  ScalarReference(Input, Expected);
  Result := True;
  for I := 0 to 7 do
    if not ComplexNearlyEqual(Actual[I], Expected[I], Epsilon) then Exit(False);
end;

initialization
  GBitReverseKernel := nil;
  GButterflyKernel := nil;

finalization
  GBitReverseKernel.Free;
  GButterflyKernel.Free;

end.
