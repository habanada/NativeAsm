unit NativeAsm.AvxShowcase.Transpose;

interface

uses
  NativeAsm.Extensions,
  NativeAsm.AvxShowcase.Types;

type
  TNativeAsmTranspose8 = class sealed
  private
    class function Kernel: TExecutableCode; static;
  public
    class function IsSupported: Boolean; static;
    class procedure Execute(const Input: TMatrix8x8; out Output: TMatrix8x8); static;
    class procedure ScalarReference(const Input: TMatrix8x8; out Output: TMatrix8x8); static;
    class function VerifyRoundTrip(const Input: TMatrix8x8): Boolean; static;
    class function VerifyAgainstScalar(const Input: TMatrix8x8): Boolean; static;
  end;

implementation

uses
  System.SysUtils,
  NativeAsm.Types,
  NativeAsm.Builder,
  NativeAsm.Simd.Types,
  NativeAsm.Avx.Types,
  NativeAsm.Avx.Cpu,
  NativeAsm.Avx;

var
  GTransposeKernel: TExecutableCode;

function BuildTransposeKernel: TExecutableCode;
var
  B: TAsmBuilder;
begin
  B := TAsmBuilder.New;
  try
    B.Sub(RSP, 160);
    B.Vmovdqu(XmmWordPtr(ridRSP, 0), XMM6);
    B.Vmovdqu(XmmWordPtr(ridRSP, 16), XMM7);
    B.Vmovdqu(XmmWordPtr(ridRSP, 32), XMM8);
    B.Vmovdqu(XmmWordPtr(ridRSP, 48), XMM9);
    B.Vmovdqu(XmmWordPtr(ridRSP, 64), XMM10);
    B.Vmovdqu(XmmWordPtr(ridRSP, 80), XMM11);
    B.Vmovdqu(XmmWordPtr(ridRSP, 96), XMM12);
    B.Vmovdqu(XmmWordPtr(ridRSP, 112), XMM13);
    B.Vmovdqu(XmmWordPtr(ridRSP, 128), XMM14);
    B.Vmovdqu(XmmWordPtr(ridRSP, 144), XMM15);
    B.Vmovups(YMM0, YmmWordPtr(ridRCX, 0));
    B.Vmovups(YMM1, YmmWordPtr(ridRCX, 32));
    B.Vmovups(YMM2, YmmWordPtr(ridRCX, 64));
    B.Vmovups(YMM3, YmmWordPtr(ridRCX, 96));
    B.Vmovups(YMM4, YmmWordPtr(ridRCX, 128));
    B.Vmovups(YMM5, YmmWordPtr(ridRCX, 160));
    B.Vmovups(YMM6, YmmWordPtr(ridRCX, 192));
    B.Vmovups(YMM7, YmmWordPtr(ridRCX, 224));

    B.Vunpcklps(YMM8, YMM0, YMM1);
    B.Vunpckhps(YMM9, YMM0, YMM1);
    B.Vunpcklps(YMM10, YMM2, YMM3);
    B.Vunpckhps(YMM11, YMM2, YMM3);
    B.Vunpcklps(YMM12, YMM4, YMM5);
    B.Vunpckhps(YMM13, YMM4, YMM5);
    B.Vunpcklps(YMM14, YMM6, YMM7);
    B.Vunpckhps(YMM15, YMM6, YMM7);

    B.Vshufps(YMM0, YMM8, YMM10, $44);
    B.Vshufps(YMM1, YMM8, YMM10, $EE);
    B.Vshufps(YMM2, YMM9, YMM11, $44);
    B.Vshufps(YMM3, YMM9, YMM11, $EE);
    B.Vshufps(YMM4, YMM12, YMM14, $44);
    B.Vshufps(YMM5, YMM12, YMM14, $EE);
    B.Vshufps(YMM6, YMM13, YMM15, $44);
    B.Vshufps(YMM7, YMM13, YMM15, $EE);

    B.Vextractf128(XMM14, YMM4, 0);
    B.Vinsertf128(YMM8, YMM0, XMM14, 1);
    B.Vextractf128(XMM14, YMM5, 0);
    B.Vinsertf128(YMM9, YMM1, XMM14, 1);
    B.Vperm2f128(YMM10, YMM2, YMM6, $20);
    B.Vperm2f128(YMM11, YMM3, YMM7, $20);
    B.Vperm2f128(YMM12, YMM0, YMM4, $31);
    B.Vperm2f128(YMM13, YMM1, YMM5, $31);
    B.Vperm2f128(YMM14, YMM2, YMM6, $31);
    B.Vperm2f128(YMM15, YMM3, YMM7, $31);

    B.Vmovups(YmmWordPtr(ridRDX, 0), YMM8);
    B.Vmovups(YmmWordPtr(ridRDX, 32), YMM9);
    B.Vmovups(YmmWordPtr(ridRDX, 64), YMM10);
    B.Vmovups(YmmWordPtr(ridRDX, 96), YMM11);
    B.Vmovups(YmmWordPtr(ridRDX, 128), YMM12);
    B.Vmovups(YmmWordPtr(ridRDX, 160), YMM13);
    B.Vmovups(YmmWordPtr(ridRDX, 192), YMM14);
    B.Vmovups(YmmWordPtr(ridRDX, 224), YMM15);
    B.Vmovdqu(XMM6, XmmWordPtr(ridRSP, 0));
    B.Vmovdqu(XMM7, XmmWordPtr(ridRSP, 16));
    B.Vmovdqu(XMM8, XmmWordPtr(ridRSP, 32));
    B.Vmovdqu(XMM9, XmmWordPtr(ridRSP, 48));
    B.Vmovdqu(XMM10, XmmWordPtr(ridRSP, 64));
    B.Vmovdqu(XMM11, XmmWordPtr(ridRSP, 80));
    B.Vmovdqu(XMM12, XmmWordPtr(ridRSP, 96));
    B.Vmovdqu(XMM13, XmmWordPtr(ridRSP, 112));
    B.Vmovdqu(XMM14, XmmWordPtr(ridRSP, 128));
    B.Vmovdqu(XMM15, XmmWordPtr(ridRSP, 144));
    B.Add(RSP, 160);
    B.Vzeroupper.Ret;
    Result := TExecutableCode.Create(B.Build);
  finally
    B.Free;
  end;
end;

class function TNativeAsmTranspose8.Kernel: TExecutableCode;
begin
  if GTransposeKernel = nil then GTransposeKernel := BuildTransposeKernel;
  Result := GTransposeKernel;
end;

class function TNativeAsmTranspose8.IsSupported: Boolean;
begin
  Result := TAvxCpuFeatures.SupportsAvx;
end;

class procedure TNativeAsmTranspose8.Execute(const Input: TMatrix8x8; out Output: TMatrix8x8);
var
  Exe: TExecutableCode;
begin
  if not IsSupported then raise ENotSupportedException.Create('8x8 transpose showcase requires AVX');
  Exe := Kernel;
  Exe.Run(UInt64(NativeUInt(@Input[0, 0])), UInt64(NativeUInt(@Output[0, 0])));
end;

class procedure TNativeAsmTranspose8.ScalarReference(const Input: TMatrix8x8; out Output: TMatrix8x8);
var
  Row, Col: Integer;
begin
  for Row := 0 to 7 do
    for Col := 0 to 7 do
      Output[Col, Row] := Input[Row, Col];
end;

class function TNativeAsmTranspose8.VerifyRoundTrip(const Input: TMatrix8x8): Boolean;
var
  Temp, Actual: TMatrix8x8;
  Row, Col: Integer;
begin
  Execute(Input, Temp);
  Execute(Temp, Actual);
  Result := True;
  for Row := 0 to 7 do
    for Col := 0 to 7 do
      if Actual[Row, Col] <> Input[Row, Col] then Exit(False);
end;

class function TNativeAsmTranspose8.VerifyAgainstScalar(const Input: TMatrix8x8): Boolean;
var
  Actual, Expected: TMatrix8x8;
  Row, Col: Integer;
begin
  Execute(Input, Actual);
  ScalarReference(Input, Expected);
  Result := True;
  for Row := 0 to 7 do
    for Col := 0 to 7 do
      if Actual[Row, Col] <> Expected[Row, Col] then Exit(False);
end;

initialization
  GTransposeKernel := nil;

finalization
  GTransposeKernel.Free;

end.
