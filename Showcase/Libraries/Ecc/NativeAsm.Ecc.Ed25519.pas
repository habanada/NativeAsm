{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
unit NativeAsm.Ecc.Ed25519;

interface

uses
  System.SysUtils,
  NativeAsm.BigInt.Types,
  NativeAsm.BigInt.Core,
  NativeAsm.BigInt.Montgomery,
  NativeAsm.Ecc.Types,
  NativeAsm.Ecc.Field25519;

type
  TEd25519Curve = class
  private type
    TExtendedPoint = record
      X: TUInt256;
      Y: TUInt256;
      Z: TUInt256;
      T: TUInt256;
    end;
  private
    FBaseField: TField25519;
    FContext: TMontgomeryContext;
    FOneMont: TUInt256;
    FDNormal: TUInt256;
    FD2Mont: TUInt256;
    FSqrtM1: TUInt256;
    FSqrtExponentBE: TBytes;
    FGenerator: TEd25519AffinePoint;
    class procedure Zero256(var R: TUInt256); static;
    class procedure LoadHex256(var R: TUInt256; const S: string); static;
    procedure FAdd(var R: TUInt256; const A, B: TUInt256); inline;
    procedure FSub(var R: TUInt256; const A, B: TUInt256); inline;
    procedure FMul(var R: TUInt256; const A, B: TUInt256); inline;
    procedure FSqr(var R: TUInt256; const A: TUInt256); inline;
    procedure FNeg(var R: TUInt256; const A: TUInt256); inline;
    procedure PointIdentityMont(var R: TExtendedPoint); inline;
    procedure PointSwapMont(var A, B: TExtendedPoint; DoSwap: UInt64); inline;
    procedure AffineToMont(const P: TEd25519AffinePoint; var R: TExtendedPoint);
    procedure MontToAffine(const P: TExtendedPoint; var R: TEd25519AffinePoint);
    procedure PointAddMont(const P, Q: TExtendedPoint; var R: TExtendedPoint);
    procedure PointDoubleMont(const P: TExtendedPoint; var R: TExtendedPoint);
  public
    constructor Create;
    destructor Destroy; override;
    function PointIsOnCurve(const P: TEd25519AffinePoint): Boolean;
    procedure PointAdd(const P, Q: TEd25519AffinePoint; var R: TEd25519AffinePoint);
    procedure PointDouble(const P: TEd25519AffinePoint; var R: TEd25519AffinePoint);
    procedure ScalarMultiply(const P: TEd25519AffinePoint; const Scalar: TUInt256; var R: TEd25519AffinePoint);
    procedure ScalarBaseMultiply(const Scalar: TUInt256; var R: TEd25519AffinePoint);
    function DecodePoint(const Data: TX25519Bytes; var P: TEd25519AffinePoint): Boolean;
    procedure EncodePoint(const P: TEd25519AffinePoint; var Data: TX25519Bytes);
    function IsIdentity(const P: TEd25519AffinePoint): Boolean;
    property Generator: TEd25519AffinePoint read FGenerator;
    property Field: TField25519 read FBaseField;
  end;

implementation

{$Q-}
{$R-}

class procedure TEd25519Curve.Zero256(var R: TUInt256);
begin
  FillChar(R, SizeOf(R), 0);
end;

class procedure TEd25519Curve.LoadHex256(var R: TUInt256; const S: string);
var
  V: TBigIntLimbs;
begin
  V := TBigIntCore.FromHex(S, 4); Zero256(R); Move(V[0], R.Limbs[0], Length(V) * SizeOf(UInt64));
end;

constructor TEd25519Curve.Create;
var
  D2, OneMont: TBigIntLimbs;
  D2Normal: TUInt256;
begin
  inherited Create;
  FBaseField := TField25519.Create; FContext := FBaseField.FieldContext;
  OneMont := FContext.OneMont; Move(OneMont[0], FOneMont.Limbs[0], SizeOf(FOneMont));
  LoadHex256(FDNormal, '52036CEE2B6FFE738CC740797779E89800700A4D4141D8AB75EB4DCA135978A3'); LoadHex256(FSqrtM1, '2B8324804FC1DF0B2B4D00993DFBD7A72F431806AD2FE478C4EE1B274A0EA0B');
  FBaseField.FieldAdd(D2Normal, FDNormal, FDNormal); FContext.Encode(@FD2Mont.Limbs[0], @D2Normal.Limbs[0]);
  LoadHex256(FGenerator.X, '216936D3CD6E53FEC0A4E231FDD6DC5C692CC7609525A7B2C9562D608F25D51A'); LoadHex256(FGenerator.Y, '6666666666666666666666666666666666666666666666666666666666666658');
  D2 := TBigIntCore.FromHex('0FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFE', 4); SetLength(FSqrtExponentBE, 32); TBigIntCore.ExportBytes(@D2[0], 4, @FSqrtExponentBE[0], 32, bieBigEndian); FillChar(D2Normal, SizeOf(D2Normal), 0);
end;

destructor TEd25519Curve.Destroy;
begin
  if FContext <> nil then begin FContext.Kernel.Zero(@FOneMont.Limbs[0]); FContext.Kernel.Zero(@FD2Mont.Limbs[0]); end; FillChar(FDNormal, SizeOf(FDNormal), 0); FillChar(FSqrtM1, SizeOf(FSqrtM1), 0); FillChar(FGenerator, SizeOf(FGenerator), 0); if Length(FSqrtExponentBE) <> 0 then FillChar(FSqrtExponentBE[0], Length(FSqrtExponentBE), 0); FBaseField.Free; inherited;
end;

procedure TEd25519Curve.FAdd(var R: TUInt256; const A, B: TUInt256);
var
  S0, S1: TUInt256;
begin
  FContext.AddMod(@R.Limbs[0], @A.Limbs[0], @B.Limbs[0], @S0.Limbs[0], @S1.Limbs[0]);
end;

procedure TEd25519Curve.FSub(var R: TUInt256; const A, B: TUInt256);
var
  S0, S1: TUInt256;
begin
  FContext.SubMod(@R.Limbs[0], @A.Limbs[0], @B.Limbs[0], @S0.Limbs[0], @S1.Limbs[0]);
end;

procedure TEd25519Curve.FMul(var R: TUInt256; const A, B: TUInt256);
begin
  FContext.MontMul(@R.Limbs[0], @A.Limbs[0], @B.Limbs[0]);
end;

procedure TEd25519Curve.FSqr(var R: TUInt256; const A: TUInt256);
begin
  FContext.MontSquare(@R.Limbs[0], @A.Limbs[0]);
end;

procedure TEd25519Curve.FNeg(var R: TUInt256; const A: TUInt256);
var
  Z: TUInt256;
begin
  Zero256(Z); FSub(R, Z, A);
end;

procedure TEd25519Curve.PointIdentityMont(var R: TExtendedPoint);
begin
  FillChar(R, SizeOf(R), 0); R.Y := FOneMont; R.Z := FOneMont;
end;

procedure TEd25519Curve.PointSwapMont(var A, B: TExtendedPoint; DoSwap: UInt64);
begin
  FContext.Kernel.SwapCT(@A.X.Limbs[0], @B.X.Limbs[0], DoSwap); FContext.Kernel.SwapCT(@A.Y.Limbs[0], @B.Y.Limbs[0], DoSwap); FContext.Kernel.SwapCT(@A.Z.Limbs[0], @B.Z.Limbs[0], DoSwap); FContext.Kernel.SwapCT(@A.T.Limbs[0], @B.T.Limbs[0], DoSwap);
end;

procedure TEd25519Curve.AffineToMont(const P: TEd25519AffinePoint; var R: TExtendedPoint);
begin
  FContext.Encode(@R.X.Limbs[0], @P.X.Limbs[0]); FContext.Encode(@R.Y.Limbs[0], @P.Y.Limbs[0]); R.Z := FOneMont; FMul(R.T, R.X, R.Y);
end;

procedure TEd25519Curve.MontToAffine(const P: TExtendedPoint; var R: TEd25519AffinePoint);
var
  ZN, ZInvN, ZInvM, XM, YM: TUInt256;
begin
  FContext.Decode(@ZN.Limbs[0], @P.Z.Limbs[0]); FBaseField.FieldInverse(ZInvN, ZN); FContext.Encode(@ZInvM.Limbs[0], @ZInvN.Limbs[0]); FMul(XM, P.X, ZInvM); FMul(YM, P.Y, ZInvM); FContext.Decode(@R.X.Limbs[0], @XM.Limbs[0]); FContext.Decode(@R.Y.Limbs[0], @YM.Limbs[0]); FillChar(ZN, SizeOf(ZN), 0); FillChar(ZInvN, SizeOf(ZInvN), 0); FillChar(ZInvM, SizeOf(ZInvM), 0); FillChar(XM, SizeOf(XM), 0); FillChar(YM, SizeOf(YM), 0);
end;

procedure TEd25519Curve.PointAddMont(const P, Q: TExtendedPoint; var R: TExtendedPoint);
var
  A, B, C, D, E, F, G, H, T0, T1: TUInt256;
begin
  FSub(T0, P.Y, P.X); FSub(T1, Q.Y, Q.X); FMul(A, T0, T1); FAdd(T0, P.Y, P.X); FAdd(T1, Q.Y, Q.X); FMul(B, T0, T1); FMul(T0, P.T, Q.T); FMul(C, T0, FD2Mont); FMul(T0, P.Z, Q.Z); FAdd(D, T0, T0); FSub(E, B, A); FSub(F, D, C); FAdd(G, D, C); FAdd(H, B, A); FMul(R.X, E, F); FMul(R.Y, G, H); FMul(R.T, E, H); FMul(R.Z, F, G);
end;

procedure TEd25519Curve.PointDoubleMont(const P: TExtendedPoint; var R: TExtendedPoint);
var
  A, B, C, D, E, F, G, H, T0: TUInt256;
begin
  FSqr(A, P.X); FSqr(B, P.Y); FSqr(T0, P.Z); FAdd(C, T0, T0); FNeg(D, A); FAdd(T0, P.X, P.Y); FSqr(E, T0); FSub(E, E, A); FSub(E, E, B); FAdd(G, D, B); FSub(F, G, C); FSub(H, D, B); FMul(R.X, E, F); FMul(R.Y, G, H); FMul(R.T, E, H); FMul(R.Z, F, G);
end;

function TEd25519Curve.PointIsOnCurve(const P: TEd25519AffinePoint): Boolean;
var
  X2, Y2, LHS, XY, DXY, One, RHS: TUInt256;
begin
  if not FBaseField.FieldIsCanonical(P.X) or not FBaseField.FieldIsCanonical(P.Y) then Exit(False); Zero256(One); One.Limbs[0] := 1; FBaseField.FieldSquare(X2, P.X); FBaseField.FieldSquare(Y2, P.Y); FBaseField.FieldSub(LHS, Y2, X2); FBaseField.FieldMul(XY, X2, Y2); FBaseField.FieldMul(DXY, FDNormal, XY); FBaseField.FieldAdd(RHS, One, DXY); Result := FContext.Kernel.EqualCT(@LHS.Limbs[0], @RHS.Limbs[0]) <> 0;
end;

procedure TEd25519Curve.PointAdd(const P, Q: TEd25519AffinePoint; var R: TEd25519AffinePoint);
var
  PM, QM, RM: TExtendedPoint;
begin
  if not PointIsOnCurve(P) or not PointIsOnCurve(Q) then raise EArgumentException.Create('Point is not on curve'); AffineToMont(P, PM); AffineToMont(Q, QM); PointAddMont(PM, QM, RM); MontToAffine(RM, R);
end;

procedure TEd25519Curve.PointDouble(const P: TEd25519AffinePoint; var R: TEd25519AffinePoint);
var
  PM, RM: TExtendedPoint;
begin
  if not PointIsOnCurve(P) then raise EArgumentException.Create('Point is not on curve'); AffineToMont(P, PM); PointDoubleMont(PM, RM); MontToAffine(RM, R);
end;

procedure TEd25519Curve.ScalarMultiply(const P: TEd25519AffinePoint; const Scalar: TUInt256; var R: TEd25519AffinePoint);
var
  R0, R1, A, D: TExtendedPoint;
  Bit, Swap: UInt64;
  I: Integer;
begin
  if not PointIsOnCurve(P) then raise EArgumentException.Create('Point is not on curve'); if not FBaseField.ScalarIsCanonical(Scalar) then raise EArgumentException.Create('Scalar is not canonical'); PointIdentityMont(R0); AffineToMont(P, R1); Swap := 0;
  try
    for I := 255 downto 0 do begin Bit := (Scalar.Limbs[I shr 6] shr (I and 63)) and 1; Swap := Swap xor Bit; PointSwapMont(R0, R1, Swap); Swap := Bit; PointAddMont(R0, R1, A); PointDoubleMont(R0, D); R1 := A; R0 := D; end; PointSwapMont(R0, R1, Swap); MontToAffine(R0, R);
  finally
    FillChar(R0, SizeOf(R0), 0); FillChar(R1, SizeOf(R1), 0); FillChar(A, SizeOf(A), 0); FillChar(D, SizeOf(D), 0); Bit := 0; Swap := 0;
  end;
end;

procedure TEd25519Curve.ScalarBaseMultiply(const Scalar: TUInt256; var R: TEd25519AffinePoint);
begin
  ScalarMultiply(FGenerator, Scalar, R);
end;

function TEd25519Curve.DecodePoint(const Data: TX25519Bytes; var P: TEd25519AffinePoint): Boolean;
var
  B: TX25519Bytes;
  Y, Y2, Num, Den, DenInv, X2, X, Check, T: TUInt256;
  Sign: Byte;
begin
  FillChar(P, SizeOf(P), 0); B := Data; Sign := B[31] shr 7; B[31] := B[31] and $7F; Result := False; if not FBaseField.TryFieldFromBytesLE(B, Y) then Exit; FBaseField.FieldSquare(Y2, Y); Zero256(T); T.Limbs[0] := 1; FBaseField.FieldSub(Num, Y2, T); FBaseField.FieldMul(Den, FDNormal, Y2); FBaseField.FieldAdd(Den, Den, T); if FContext.Kernel.IsZeroCT(@Den.Limbs[0]) <> 0 then Exit; FBaseField.FieldInverse(DenInv, Den); FBaseField.FieldMul(X2, Num, DenInv); FContext.PowCT(@X.Limbs[0], @X2.Limbs[0], @FSqrtExponentBE[0], Length(FSqrtExponentBE)); FBaseField.FieldSquare(Check, X);
  if FContext.Kernel.EqualCT(@Check.Limbs[0], @X2.Limbs[0]) = 0 then begin FBaseField.FieldMul(X, X, FSqrtM1); FBaseField.FieldSquare(Check, X); if FContext.Kernel.EqualCT(@Check.Limbs[0], @X2.Limbs[0]) = 0 then Exit; end;
  if (FContext.Kernel.IsZeroCT(@X.Limbs[0]) <> 0) and (Sign <> 0) then Exit; if (X.Limbs[0] and 1) <> Sign then FBaseField.FieldNegate(X, X); P.X := X; P.Y := Y; Result := PointIsOnCurve(P);
end;

procedure TEd25519Curve.EncodePoint(const P: TEd25519AffinePoint; var Data: TX25519Bytes);
begin
  if not PointIsOnCurve(P) then raise EArgumentException.Create('Point is not on curve'); FBaseField.FieldToBytesLE(P.Y, Data); Data[31] := Data[31] or Byte((P.X.Limbs[0] and 1) shl 7);
end;

function TEd25519Curve.IsIdentity(const P: TEd25519AffinePoint): Boolean;
var
  Z, O: TUInt256;
begin
  Zero256(Z); Zero256(O); O.Limbs[0] := 1; Result := (FContext.Kernel.EqualCT(@P.X.Limbs[0], @Z.Limbs[0]) <> 0) and (FContext.Kernel.EqualCT(@P.Y.Limbs[0], @O.Limbs[0]) <> 0);
end;

end.
