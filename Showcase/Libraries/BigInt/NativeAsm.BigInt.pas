{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
unit NativeAsm.BigInt;

interface

uses
  System.SysUtils,
  NativeAsm.BigInt.Types,
  NativeAsm.BigInt.Core;

type
  TBigNat = class
  private
    FLimbs: TBigIntLimbs;
    procedure Normalize;
    function GetLimbCount: Integer;
    function GetLimbs: TBigIntLimbs;
  public
    constructor Create; overload;
    constructor Create(const Limbs: TBigIntLimbs); overload;
    class function FromHex(const Value: string): TBigNat; static;
    class function FromBytesBE(const Value: TBytes): TBigNat; static;
    function Clone: TBigNat;
    function IsZero: Boolean;
    function BitLength: NativeUInt;
    function Compare(const Other: TBigNat): Integer;
    function ToHex: string;
    function ToBytesBE(MinBytes: Integer = 0): TBytes;
    class function Add(const A, B: TBigNat): TBigNat; static;
    class function Subtract(const A, B: TBigNat): TBigNat; static;
    class function Multiply(const A, B: TBigNat): TBigNat; static;
    class procedure DivMod(const Dividend, Divisor: TBigNat; out Quotient, Remainder: TBigNat); static;
    class function Divide(const A, B: TBigNat): TBigNat; static;
    class function Modulo(const A, Modulus: TBigNat): TBigNat; static;
    class function ModPow(const Base, Exponent, Modulus: TBigNat): TBigNat; static;
    class function TryModInverse(const A, Modulus: TBigNat; out Inverse: TBigNat): Boolean; static;
    class function ModInverse(const A, Modulus: TBigNat): TBigNat; static;
    class function Gcd(const A, B: TBigNat): TBigNat; static;
    class function Lcm(const A, B: TBigNat): TBigNat; static;
    property LimbCount: Integer read GetLimbCount;
    property Limbs: TBigIntLimbs read GetLimbs;
  end;

implementation

constructor TBigNat.Create;
begin
  inherited Create;
  SetLength(FLimbs, 1);
end;

constructor TBigNat.Create(const Limbs: TBigIntLimbs);
begin
  inherited Create;
  if Length(Limbs) = 0 then SetLength(FLimbs, 1)
  else begin SetLength(FLimbs, Length(Limbs)); Move(Limbs[0], FLimbs[0], Length(Limbs) * SizeOf(UInt64)); end;
  Normalize;
end;

procedure TBigNat.Normalize;
var
  N: Integer;
begin
  N := Length(FLimbs);
  while (N > 1) and (FLimbs[N - 1] = 0) do Dec(N);
  SetLength(FLimbs, N);
end;

function TBigNat.GetLimbCount: Integer;
begin
  Result := Length(FLimbs);
end;

function TBigNat.GetLimbs: TBigIntLimbs;
begin
  SetLength(Result, Length(FLimbs));
  if Length(Result) <> 0 then Move(FLimbs[0], Result[0], Length(Result) * SizeOf(UInt64));
end;

class function TBigNat.FromHex(const Value: string): TBigNat;
var
  L: TBigIntLimbs;
begin
  L := TBigIntCore.FromHex(Value);
  Result := TBigNat.Create(L);
end;

class function TBigNat.FromBytesBE(const Value: TBytes): TBigNat;
var
  L: TBigIntLimbs;
  N: Integer;
begin
  N := (Length(Value) + 7) div 8;
  if N = 0 then N := 1;
  SetLength(L, N);
  if Length(Value) <> 0 then TBigIntCore.ImportBytes(@L[0], N, @Value[0], Length(Value), bieBigEndian);
  Result := TBigNat.Create(L);
end;

function TBigNat.Clone: TBigNat;
begin
  Result := TBigNat.Create(FLimbs);
end;

function TBigNat.IsZero: Boolean;
begin
  Result := (Length(FLimbs) = 1) and (FLimbs[0] = 0);
end;

function TBigNat.BitLength: NativeUInt;
begin
  Result := TBigIntCore.BitLength(@FLimbs[0], Length(FLimbs));
end;

function TBigNat.Compare(const Other: TBigNat): Integer;
begin
  if Other = nil then raise EArgumentNilException.Create('Other');
  if Length(FLimbs) < Length(Other.FLimbs) then Exit(-1);
  if Length(FLimbs) > Length(Other.FLimbs) then Exit(1);
  Result := TBigIntCore.Compare(@FLimbs[0], @Other.FLimbs[0], Length(FLimbs));
end;

function TBigNat.ToHex: string;
begin
  Result := TBigIntCore.ToHex(@FLimbs[0], Length(FLimbs));
end;

function TBigNat.ToBytesBE(MinBytes: Integer): TBytes;
var
  N, Used: Integer;
begin
  if MinBytes < 0 then raise EArgumentOutOfRangeException.Create('MinBytes');
  N := Integer((BitLength + 7) div 8);
  if N = 0 then N := 1;
  if N < MinBytes then N := MinBytes;
  SetLength(Result, N);
  FillChar(Result[0], N, 0);
  Used := Length(FLimbs) * 8;
  if Used > N then Used := N;
  TBigIntCore.ExportBytes(@FLimbs[0], Length(FLimbs), @Result[N - Used], Used, bieBigEndian);
end;

class function TBigNat.Add(const A, B: TBigNat): TBigNat;
var
  N, I: Integer;
  X, Y, S, T, Carry, C1, C2: UInt64;
  R: TBigIntLimbs;
begin
  if A = nil then raise EArgumentNilException.Create('A');
  if B = nil then raise EArgumentNilException.Create('B');
  N := A.LimbCount; if B.LimbCount > N then N := B.LimbCount;
  SetLength(R, N + 1); Carry := 0;
  for I := 0 to N - 1 do
  begin
    if I < A.LimbCount then X := A.FLimbs[I] else X := 0;
    if I < B.LimbCount then Y := B.FLimbs[I] else Y := 0;
    S := X + Y; C1 := UInt64(Ord(S < X));
    T := S + Carry; C2 := UInt64(Ord(T < S));
    R[I] := T; Carry := C1 or C2;
  end;
  R[N] := Carry;
  Result := TBigNat.Create(R);
end;

class function TBigNat.Subtract(const A, B: TBigNat): TBigNat;
var
  R, BPadded: TBigIntLimbs;
  Borrow: UInt64;
begin
  if A = nil then raise EArgumentNilException.Create('A');
  if B = nil then raise EArgumentNilException.Create('B');
  if A.Compare(B) < 0 then raise ERangeError.Create('Negative result');
  SetLength(R, A.LimbCount); SetLength(BPadded, A.LimbCount);
  Move(B.FLimbs[0], BPadded[0], B.LimbCount * SizeOf(UInt64));
  Borrow := TBigIntCore.Sub(@R[0], @A.FLimbs[0], @BPadded[0], A.LimbCount);
  if Borrow <> 0 then raise EInvalidOp.Create('Subtraction borrow');
  Result := TBigNat.Create(R);
end;

class function TBigNat.Multiply(const A, B: TBigNat): TBigNat;
var
  N, I: Integer;
  APad, BPad, R: TBigIntLimbs;
begin
  if A = nil then raise EArgumentNilException.Create('A');
  if B = nil then raise EArgumentNilException.Create('B');
  N := A.LimbCount; if B.LimbCount > N then N := B.LimbCount;
  SetLength(APad, N); SetLength(BPad, N); SetLength(R, N * 2);
  for I := 0 to A.LimbCount - 1 do APad[I] := A.FLimbs[I];
  for I := 0 to B.LimbCount - 1 do BPad[I] := B.FLimbs[I];
  TBigIntCore.MulWide(@R[0], @APad[0], @BPad[0], N);
  Result := TBigNat.Create(R);
end;

class procedure TBigNat.DivMod(const Dividend, Divisor: TBigNat; out Quotient, Remainder: TBigNat);
var
  N: Integer;
  Q, R, D: TBigIntLimbs;
  BitIndex: NativeInt;
begin
  if Dividend = nil then raise EArgumentNilException.Create('Dividend');
  if Divisor = nil then raise EArgumentNilException.Create('Divisor');
  if Divisor.IsZero then raise EDivByZero.Create('Divisor');
  if Dividend.Compare(Divisor) < 0 then
  begin
    Quotient := TBigNat.Create;
    Remainder := Dividend.Clone;
    Exit;
  end;
  N := Dividend.LimbCount;
  if Divisor.LimbCount > N then N := Divisor.LimbCount;
  Inc(N);
  SetLength(Q, N); SetLength(R, N); SetLength(D, N);
  Move(Divisor.FLimbs[0], D[0], Divisor.LimbCount * SizeOf(UInt64));
  BitIndex := NativeInt(Dividend.BitLength) - 1;
  while BitIndex >= 0 do
  begin
    TBigIntCore.ShiftLeft(@R[0], @R[0], N, 1);
    R[0] := R[0] or TBigIntCore.GetBit(@Dividend.FLimbs[0], Dividend.LimbCount, NativeUInt(BitIndex));
    if TBigIntCore.Compare(@R[0], @D[0], N) >= 0 then
    begin
      TBigIntCore.Sub(@R[0], @R[0], @D[0], N);
      TBigIntCore.SetBit(@Q[0], N, NativeUInt(BitIndex));
    end;
    Dec(BitIndex);
  end;
  Quotient := TBigNat.Create(Q);
  Remainder := TBigNat.Create(R);
end;

class function TBigNat.Divide(const A, B: TBigNat): TBigNat;
var
  R: TBigNat;
begin
  Result := nil; R := nil;
  DivMod(A, B, Result, R);
  R.Free;
end;

class function TBigNat.Modulo(const A, Modulus: TBigNat): TBigNat;
var
  Q: TBigNat;
begin
  Q := nil; Result := nil;
  DivMod(A, Modulus, Q, Result);
  Q.Free;
end;

class function TBigNat.ModPow(const Base, Exponent, Modulus: TBigNat): TBigNat;
var
  Acc, Cur, Temp, Reduced, One: TBigNat;
  BitIndex, Bits: NativeUInt;
begin
  if Base = nil then raise EArgumentNilException.Create('Base');
  if Exponent = nil then raise EArgumentNilException.Create('Exponent');
  if Modulus = nil then raise EArgumentNilException.Create('Modulus');
  if Modulus.IsZero then raise EDivByZero.Create('Modulus');
  One := TBigNat.FromHex('1'); Acc := nil; Cur := nil;
  try
    Acc := Modulo(One, Modulus); Cur := Modulo(Base, Modulus); Bits := Exponent.BitLength;
    if Bits <> 0 then
    for BitIndex := 0 to Bits - 1 do
    begin
      if TBigIntCore.GetBit(@Exponent.FLimbs[0], Exponent.LimbCount, BitIndex) <> 0 then
      begin
        Temp := Multiply(Acc, Cur);
        try Reduced := Modulo(Temp, Modulus); finally Temp.Free; end;
        Acc.Free; Acc := Reduced;
      end;
      Temp := Multiply(Cur, Cur);
      try Reduced := Modulo(Temp, Modulus); finally Temp.Free; end;
      Cur.Free; Cur := Reduced;
    end;
    Result := Acc; Acc := nil;
  finally
    Cur.Free; Acc.Free; One.Free;
  end;
end;

class function TBigNat.TryModInverse(const A, Modulus: TBigNat; out Inverse: TBigNat): Boolean;
var
  R, NewR, T, NewT, Q, Rem, Product, ProductMod, Diff, NextT, One: TBigNat;
begin
  if A = nil then raise EArgumentNilException.Create('A');
  if Modulus = nil then raise EArgumentNilException.Create('Modulus');
  if Modulus.IsZero then raise EDivByZero.Create('Modulus');
  Inverse := nil;
  if (Modulus.LimbCount = 1) and (Modulus.FLimbs[0] = 1) then Exit(False);
  R := Modulus.Clone; NewR := Modulo(A, Modulus); T := TBigNat.Create; NewT := TBigNat.FromHex('1'); One := TBigNat.FromHex('1');
  try
    while not NewR.IsZero do
    begin
      Q := nil; Rem := nil; Product := nil; ProductMod := nil; Diff := nil; NextT := nil;
      try
        DivMod(R, NewR, Q, Rem);
        Product := Multiply(Q, NewT); ProductMod := Modulo(Product, Modulus);
        if T.Compare(ProductMod) >= 0 then NextT := Subtract(T, ProductMod)
        else
        begin
          Diff := Subtract(ProductMod, T); NextT := Subtract(Modulus, Diff);
        end;
        R.Free; R := NewR; NewR := Rem; Rem := nil;
        T.Free; T := NewT; NewT := NextT; NextT := nil;
      finally
        NextT.Free; Diff.Free; ProductMod.Free; Product.Free; Rem.Free; Q.Free;
      end;
    end;
    Result := R.Compare(One) = 0;
    if Result then begin Inverse := T; T := nil; end;
  finally
    One.Free; NewT.Free; T.Free; NewR.Free; R.Free;
  end;
end;

class function TBigNat.ModInverse(const A, Modulus: TBigNat): TBigNat;
begin
  if not TryModInverse(A, Modulus, Result) then raise EInvalidOp.Create('Value has no modular inverse');
end;

class function TBigNat.Gcd(const A, B: TBigNat): TBigNat;
var
  X, Y, Q, R: TBigNat;
begin
  if A = nil then raise EArgumentNilException.Create('A');
  if B = nil then raise EArgumentNilException.Create('B');
  X := A.Clone; Y := B.Clone;
  try
    while not Y.IsZero do
    begin
      Q := nil; R := nil;
      DivMod(X, Y, Q, R);
      Q.Free;
      X.Free;
      X := Y;
      Y := R;
    end;
    Result := X;
    X := nil;
  finally
    X.Free;
    Y.Free;
  end;
end;

class function TBigNat.Lcm(const A, B: TBigNat): TBigNat;
var
  G, Q: TBigNat;
begin
  if A = nil then raise EArgumentNilException.Create('A');
  if B = nil then raise EArgumentNilException.Create('B');
  if A.IsZero or B.IsZero then Exit(TBigNat.Create);
  G := Gcd(A, B); Q := nil;
  try
    Q := Divide(A, G); Result := Multiply(Q, B);
  finally
    Q.Free; G.Free;
  end;
end;

end.
