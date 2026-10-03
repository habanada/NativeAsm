unit NativeAsm.AvxShowcase.Polynomial;

interface

uses
  NativeAsm.Extensions,
  NativeAsm.AvxShowcase.Types;

type
  TPolynomial8 = array[0..7] of Single;

  TNativeAsmPolynomial = class sealed
  private
    class function Kernel: TExecutableCode; static;
  public
    class function IsSupported: Boolean; static;
    class procedure Evaluate(const X: TSingle8; const Coefficients: TPolynomial8; out Y: TSingle8); static;
    class procedure ScalarReference(const X: TSingle8; const Coefficients: TPolynomial8; out Y: TSingle8); static;
    class function Verify(const X: TSingle8; const Coefficients: TPolynomial8; Epsilon: Single = 2.0E-5): Boolean; static;
    class function MaxRelativeError(const X: TSingle8; const Coefficients: TPolynomial8): Double; static;
  end;

implementation

uses
  System.SysUtils,
  System.Math,
  NativeAsm.Types,
  NativeAsm.Builder,
  NativeAsm.Avx.Types,
  NativeAsm.Avx.Cpu,
  NativeAsm.Avx;

type
  TPolynomialBlock = packed record
    X: TSingle8;
    Coefficients: TPolynomial8;
    Y: TSingle8;
  end;

const
  OFS_X = 0;
  OFS_COEFFICIENTS = 32;
  OFS_Y = 64;

var
  GPolynomialKernel: TExecutableCode;

function BuildPolynomialKernel: TExecutableCode;
var
  B: TAsmBuilder;
  I: Integer;
begin
  B := TAsmBuilder.New;
  try
    B.Vmovups(YMM0, YmmWordPtr(ridRCX, OFS_X));
    B.Vbroadcastss(YMM1, DWordPtr(ridRCX, OFS_COEFFICIENTS + 7 * SizeOf(Single)));
    for I := 6 downto 0 do
    begin
      B.Vbroadcastss(YMM2, DWordPtr(ridRCX, OFS_COEFFICIENTS + I * SizeOf(Single)));
      B.Vfmadd213ps(YMM1, YMM0, YMM2);
    end;
    B.Vmovups(YmmWordPtr(ridRCX, OFS_Y), YMM1);
    B.Vzeroupper.Ret;
    Result := TExecutableCode.Create(B.Build);
  finally
    B.Free;
  end;
end;

class function TNativeAsmPolynomial.Kernel: TExecutableCode;
begin
  if GPolynomialKernel = nil then GPolynomialKernel := BuildPolynomialKernel;
  Result := GPolynomialKernel;
end;

class function TNativeAsmPolynomial.IsSupported: Boolean;
begin
  Result := TAvxCpuFeatures.SupportsFma;
end;

class procedure TNativeAsmPolynomial.Evaluate(const X: TSingle8; const Coefficients: TPolynomial8; out Y: TSingle8);
var
  Block: TPolynomialBlock;
begin
  if not IsSupported then raise ENotSupportedException.Create('polynomial showcase requires AVX+FMA');
  Block.X := X;
  Block.Coefficients := Coefficients;
  FillChar(Block.Y, SizeOf(Block.Y), 0);
  Kernel.Run(UInt64(NativeUInt(@Block)));
  Y := Block.Y;
end;

class procedure TNativeAsmPolynomial.ScalarReference(const X: TSingle8; const Coefficients: TPolynomial8; out Y: TSingle8);
var
  Lane, I: Integer;
  V: Double;
begin
  for Lane := 0 to 7 do
  begin
    V := Coefficients[7];
    for I := 6 downto 0 do
      V := V * Double(X[Lane]) + Double(Coefficients[I]);
    Y[Lane] := Single(V);
  end;
end;

class function TNativeAsmPolynomial.Verify(const X: TSingle8; const Coefficients: TPolynomial8; Epsilon: Single): Boolean;
var
  Actual, Expected: TSingle8;
  I: Integer;
begin
  Evaluate(X, Coefficients, Actual);
  ScalarReference(X, Coefficients, Expected);
  Result := True;
  for I := 0 to 7 do
    if not NearlyEqual(Actual[I], Expected[I], Epsilon) then Exit(False);
end;

class function TNativeAsmPolynomial.MaxRelativeError(const X: TSingle8; const Coefficients: TPolynomial8): Double;
var
  Actual, Expected: TSingle8;
  I: Integer;
  Scale, E: Double;
begin
  Evaluate(X, Coefficients, Actual);
  ScalarReference(X, Coefficients, Expected);
  Result := 0.0;
  for I := 0 to 7 do
  begin
    Scale := Max(1.0, Abs(Double(Expected[I])));
    E := Abs(Double(Actual[I]) - Double(Expected[I])) / Scale;
    if E > Result then Result := E;
  end;
end;

initialization
  GPolynomialKernel := nil;

finalization
  GPolynomialKernel.Free;

end.
