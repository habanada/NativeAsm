unit NativeAsm.AvxShowcase.Types;

interface

uses
  System.SysUtils,
  System.Math;

type
  TComplex32 = record
    Re: Single;
    Im: Single;
    class function Create(ARe, AIm: Single): TComplex32; static;
  end;

  TComplex8 = array[0..7] of TComplex32;
  TSingle8 = array[0..7] of Single;
  TCardinal8 = array[0..7] of Cardinal;
  TMatrix8x8 = array[0..7, 0..7] of Single;
  TMandelbrotPixels = array of Cardinal;

  TMandelbrotView = record
    MinX: Single;
    MaxX: Single;
    MinY: Single;
    MaxY: Single;
    Width: Integer;
    Height: Integer;
    MaxIterations: Cardinal;
    class function Create(AMinX, AMaxX, AMinY, AMaxY: Single; AWidth, AHeight: Integer; AMaxIterations: Cardinal): TMandelbrotView; static;
  end;

function NearlyEqual(A, B: Single; Epsilon: Single = 1.0E-4): Boolean;
function ComplexNearlyEqual(const A, B: TComplex32; Epsilon: Single = 1.0E-4): Boolean;

implementation

class function TComplex32.Create(ARe, AIm: Single): TComplex32;
begin
  Result.Re := ARe;
  Result.Im := AIm;
end;

class function TMandelbrotView.Create(AMinX, AMaxX, AMinY, AMaxY: Single; AWidth, AHeight: Integer; AMaxIterations: Cardinal): TMandelbrotView;
begin
  if AWidth <= 0 then raise EArgumentOutOfRangeException.Create('width must be positive');
  if AHeight <= 0 then raise EArgumentOutOfRangeException.Create('height must be positive');
  if AMaxIterations = 0 then raise EArgumentOutOfRangeException.Create('max iterations must be positive');
  if not (AMinX < AMaxX) then raise EArgumentException.Create('min x must be smaller than max x');
  if not (AMinY < AMaxY) then raise EArgumentException.Create('min y must be smaller than max y');
  Result.MinX := AMinX;
  Result.MaxX := AMaxX;
  Result.MinY := AMinY;
  Result.MaxY := AMaxY;
  Result.Width := AWidth;
  Result.Height := AHeight;
  Result.MaxIterations := AMaxIterations;
end;

function NearlyEqual(A, B, Epsilon: Single): Boolean;
var
  Scale: Single;
begin
  Scale := Max(1.0, Max(Abs(A), Abs(B)));
  Result := Abs(A - B) <= Epsilon * Scale;
end;

function ComplexNearlyEqual(const A, B: TComplex32; Epsilon: Single): Boolean;
begin
  Result := NearlyEqual(A.Re, B.Re, Epsilon) and NearlyEqual(A.Im, B.Im, Epsilon);
end;

end.
