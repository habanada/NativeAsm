{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
unit NativeAsm.Ecc.Weierstrass256;

interface

uses
  System.SysUtils,
  NativeAsm.BigInt.Types,
  NativeAsm.BigInt.Core,
  NativeAsm.BigInt.Montgomery,
  NativeAsm.Ecc.Types;

type
  TWeierstrassAForm = (wafZero, wafMinus3);

  TWeierstrass256Curve = class
  private
    FName: string;
    FAForm: TWeierstrassAForm;
    FField: TMontgomeryContext;
    FScalar: TMontgomeryContext;
    FP: TUInt256;
    FN: TUInt256;
    FAMont: TUInt256;
    FBMont: TUInt256;
    FOneMont: TUInt256;
    FGenerator: TEccAffinePoint256;
    FSqrtExponentBE: TBytes;
    class procedure LoadHex256(var R: TUInt256; const Hex: string); static;
    class procedure Zero256(var R: TUInt256); static;
    procedure BuildSqrtExponent;
    procedure FAdd(var R: TUInt256; const A, B: TUInt256); inline;
    procedure FSub(var R: TUInt256; const A, B: TUInt256); inline;
    procedure FMul(var R: TUInt256; const A, B: TUInt256); inline;
    procedure FSqr(var R: TUInt256; const A: TUInt256); inline;
    procedure FDouble(var R: TUInt256; const A: TUInt256); inline;
    procedure FTriple(var R: TUInt256; const A: TUInt256); inline;
    procedure FTimes8(var R: TUInt256; const A: TUInt256); inline;
    procedure FMontInverse(var R: TUInt256; const A: TUInt256);
    procedure PointInfinityMont(var R: TEccJacobianPoint256); inline;
    procedure PointSelectMont(var R: TEccJacobianPoint256; const A, B: TEccJacobianPoint256; ChooseA: UInt64); inline;
    procedure PointSwapMont(var A, B: TEccJacobianPoint256; DoSwap: UInt64); inline;
    procedure AffineToMont(const P: TEccAffinePoint256; var R: TEccJacobianPoint256);
    procedure MontToAffine(const P: TEccJacobianPoint256; var R: TEccAffinePoint256);
    procedure PointDoubleMont(const P: TEccJacobianPoint256; var R: TEccJacobianPoint256);
    procedure PointAddMontRaw(const P, Q: TEccJacobianPoint256; var R: TEccJacobianPoint256);
    procedure PointAddMontLadder(const P, Q: TEccJacobianPoint256; var R: TEccJacobianPoint256);
    procedure PointAddMont(const P, Q: TEccJacobianPoint256; var R: TEccJacobianPoint256);
    function TryImportCanonicalBE(Data: Pointer; ByteCount: NativeUInt; const Modulus: TUInt256; Context: TMontgomeryContext; var R: TUInt256): Boolean;
    procedure Reduce256(const A, Modulus: TUInt256; Context: TMontgomeryContext; var R: TUInt256);
  protected
    constructor CreateCurve(const AName, PHex, AHex, BHex, NHex, GxHex, GyHex: string; AForm: TWeierstrassAForm);
  public
    destructor Destroy; override;
    procedure FieldAdd(var R: TUInt256; const A, B: TUInt256);
    procedure FieldSub(var R: TUInt256; const A, B: TUInt256);
    procedure FieldMul(var R: TUInt256; const A, B: TUInt256);
    procedure FieldSquare(var R: TUInt256; const A: TUInt256);
    procedure FieldInverse(var R: TUInt256; const A: TUInt256);
    procedure FieldNegate(var R: TUInt256; const A: TUInt256);
    function FieldIsCanonical(const A: TUInt256): Boolean;
    function TryFieldFromBytesBE(Data: Pointer; ByteCount: NativeUInt; var R: TUInt256): Boolean;
    procedure FieldReduceBytesBE(Data: Pointer; ByteCount: NativeUInt; var R: TUInt256);
    procedure FieldToBytesBE(const A: TUInt256; Data: Pointer; ByteCount: NativeUInt);
    procedure ScalarAdd(var R: TUInt256; const A, B: TUInt256);
    procedure ScalarSub(var R: TUInt256; const A, B: TUInt256);
    procedure ScalarMul(var R: TUInt256; const A, B: TUInt256);
    procedure ScalarSquare(var R: TUInt256; const A: TUInt256);
    procedure ScalarInverse(var R: TUInt256; const A: TUInt256);
    procedure ScalarNegate(var R: TUInt256; const A: TUInt256);
    function ScalarIsCanonical(const A: TUInt256): Boolean;
    function ScalarIsZero(const A: TUInt256): Boolean;
    function TryScalarFromBytesBE(Data: Pointer; ByteCount: NativeUInt; var R: TUInt256): Boolean;
    procedure ScalarReduceBytesBE(Data: Pointer; ByteCount: NativeUInt; var R: TUInt256);
    procedure ScalarToBytesBE(const A: TUInt256; Data: Pointer; ByteCount: NativeUInt);
    function PointIsOnCurve(const P: TEccAffinePoint256): Boolean;
    procedure PointAdd(const P, Q: TEccAffinePoint256; var R: TEccAffinePoint256);
    procedure PointDouble(const P: TEccAffinePoint256; var R: TEccAffinePoint256);
    procedure ScalarMultiply(const P: TEccAffinePoint256; const Scalar: TUInt256; var R: TEccAffinePoint256);
    procedure ScalarBaseMultiply(const Scalar: TUInt256; var R: TEccAffinePoint256);
    function DecodePoint(Data: Pointer; ByteCount: NativeUInt; var P: TEccAffinePoint256): Boolean;
    function EncodePointCompressed(const P: TEccAffinePoint256): TBytes;
    function EncodePointUncompressed(const P: TEccAffinePoint256): TBytes;
    property Name: string read FName;
    property Generator: TEccAffinePoint256 read FGenerator;
    property FieldModulus: TUInt256 read FP;
    property ScalarOrder: TUInt256 read FN;
    property FieldContext: TMontgomeryContext read FField;
    property ScalarContext: TMontgomeryContext read FScalar;
  end;

implementation

{$Q-}
{$R-}

class procedure TWeierstrass256Curve.Zero256(var R: TUInt256);
begin
  FillChar(R, SizeOf(R), 0);
end;

class procedure TWeierstrass256Curve.LoadHex256(var R: TUInt256; const Hex: string);
var
  V: TBigIntLimbs;
begin
  V := TBigIntCore.FromHex(Hex, 4);
  if Length(V) > 4 then raise EArgumentOutOfRangeException.Create('Hex');
  Zero256(R);
  if Length(V) <> 0 then Move(V[0], R.Limbs[0], Length(V) * SizeOf(UInt64));
end;

constructor TWeierstrass256Curve.CreateCurve(const AName, PHex, AHex, BHex, NHex, GxHex, GyHex: string; AForm: TWeierstrassAForm);
var
  PArr, NArr, AArr, BArr, OneMont: TBigIntLimbs;
  ANormal, BNormal, ExpectedA, Three: TUInt256;
begin
  inherited Create;
  FName := AName;
  FAForm := AForm;
  LoadHex256(FP, PHex); LoadHex256(FN, NHex); LoadHex256(ANormal, AHex); LoadHex256(BNormal, BHex);
  if ((FP.Limbs[3] shr 63) = 0) or ((FN.Limbs[3] shr 63) = 0) then raise EArgumentException.Create('256-bit modulus/order must have the high bit set');
  if (FP.Limbs[0] and 3) <> 3 then raise EArgumentException.Create('Field modulus must be 3 mod 4');
  if (FP.Limbs[0] and 1) = 0 then raise EArgumentException.Create('Field modulus must be odd');
  if (FN.Limbs[0] and 1) = 0 then raise EArgumentException.Create('Scalar order must be odd');
  if TBigIntCore.Compare(@ANormal.Limbs[0], @FP.Limbs[0], 4) >= 0 then raise EArgumentException.Create('Curve A is not canonical');
  if TBigIntCore.Compare(@BNormal.Limbs[0], @FP.Limbs[0], 4) >= 0 then raise EArgumentException.Create('Curve B is not canonical');
  Zero256(ExpectedA); Zero256(Three); Three.Limbs[0] := 3;
  if AForm = wafZero then begin if not TBigIntCore.IsZero(@ANormal.Limbs[0], 4) then raise EArgumentException.Create('Curve A form mismatch'); end
  else begin TBigIntCore.Sub(@ExpectedA.Limbs[0], @FP.Limbs[0], @Three.Limbs[0], 4); if TBigIntCore.Compare(@ANormal.Limbs[0], @ExpectedA.Limbs[0], 4) <> 0 then raise EArgumentException.Create('Curve A form mismatch'); end;
  LoadHex256(FGenerator.X, GxHex); LoadHex256(FGenerator.Y, GyHex); FGenerator.Infinity := False;
  SetLength(PArr, 4); SetLength(NArr, 4); SetLength(AArr, 4); SetLength(BArr, 4);
  Move(FP.Limbs[0], PArr[0], SizeOf(FP)); Move(FN.Limbs[0], NArr[0], SizeOf(FN)); Move(ANormal.Limbs[0], AArr[0], SizeOf(ANormal)); Move(BNormal.Limbs[0], BArr[0], SizeOf(BNormal));
  FField := TMontgomeryContext.Create(PArr);
  FScalar := TMontgomeryContext.Create(NArr);
  FField.Encode(@FAMont.Limbs[0], @ANormal.Limbs[0]); FField.Encode(@FBMont.Limbs[0], @BNormal.Limbs[0]);
  OneMont := FField.OneMont;
  Move(OneMont[0], FOneMont.Limbs[0], SizeOf(FOneMont));
  BuildSqrtExponent;
  if not PointIsOnCurve(FGenerator) then raise EArgumentException.Create('Generator is not on curve');
  FillChar(ANormal, SizeOf(ANormal), 0); FillChar(BNormal, SizeOf(BNormal), 0); FillChar(ExpectedA, SizeOf(ExpectedA), 0); FillChar(Three, SizeOf(Three), 0);
end;

destructor TWeierstrass256Curve.Destroy;
begin
  if FField <> nil then
  begin
    FField.Kernel.Zero(@FAMont.Limbs[0]); FField.Kernel.Zero(@FBMont.Limbs[0]); FField.Kernel.Zero(@FOneMont.Limbs[0]);
  end;
  FillChar(FP, SizeOf(FP), 0); FillChar(FN, SizeOf(FN), 0); FillChar(FGenerator, SizeOf(FGenerator), 0);
  if Length(FSqrtExponentBE) <> 0 then FillChar(FSqrtExponentBE[0], Length(FSqrtExponentBE), 0);
  FScalar.Free; FField.Free;
  inherited;
end;

procedure TWeierstrass256Curve.BuildSqrtExponent;
var
  T, One: TUInt256;
begin
  T := FP; Zero256(One); One.Limbs[0] := 1;
  TBigIntCore.Add(@T.Limbs[0], @T.Limbs[0], @One.Limbs[0], 4);
  TBigIntCore.ShiftRight(@T.Limbs[0], @T.Limbs[0], 4, 2);
  SetLength(FSqrtExponentBE, 32);
  TBigIntCore.ExportBytes(@T.Limbs[0], 4, @FSqrtExponentBE[0], 32, bieBigEndian);
  FillChar(T, SizeOf(T), 0); FillChar(One, SizeOf(One), 0);
end;

procedure TWeierstrass256Curve.FAdd(var R: TUInt256; const A, B: TUInt256);
var
  S0, S1: TUInt256;
begin
  FField.AddMod(@R.Limbs[0], @A.Limbs[0], @B.Limbs[0], @S0.Limbs[0], @S1.Limbs[0]);
end;

procedure TWeierstrass256Curve.FSub(var R: TUInt256; const A, B: TUInt256);
var
  S0, S1: TUInt256;
begin
  FField.SubMod(@R.Limbs[0], @A.Limbs[0], @B.Limbs[0], @S0.Limbs[0], @S1.Limbs[0]);
end;

procedure TWeierstrass256Curve.FMul(var R: TUInt256; const A, B: TUInt256);
begin
  FField.MontMul(@R.Limbs[0], @A.Limbs[0], @B.Limbs[0]);
end;

procedure TWeierstrass256Curve.FSqr(var R: TUInt256; const A: TUInt256);
begin
  FField.MontSquare(@R.Limbs[0], @A.Limbs[0]);
end;

procedure TWeierstrass256Curve.FDouble(var R: TUInt256; const A: TUInt256);
begin
  FAdd(R, A, A);
end;

procedure TWeierstrass256Curve.FTriple(var R: TUInt256; const A: TUInt256);
var
  T: TUInt256;
begin
  FDouble(T, A); FAdd(R, T, A);
end;

procedure TWeierstrass256Curve.FTimes8(var R: TUInt256; const A: TUInt256);
var
  T: TUInt256;
begin
  FDouble(T, A); FDouble(T, T); FDouble(R, T);
end;

procedure TWeierstrass256Curve.FMontInverse(var R: TUInt256; const A: TUInt256);
var
  N, I: TUInt256;
begin
  FField.Decode(@N.Limbs[0], @A.Limbs[0]);
  FField.InversePrimeCT(@I.Limbs[0], @N.Limbs[0]);
  FField.Encode(@R.Limbs[0], @I.Limbs[0]);
  FillChar(N, SizeOf(N), 0); FillChar(I, SizeOf(I), 0);
end;

procedure TWeierstrass256Curve.PointInfinityMont(var R: TEccJacobianPoint256);
begin
  FillChar(R, SizeOf(R), 0);
end;

procedure TWeierstrass256Curve.PointSelectMont(var R: TEccJacobianPoint256; const A, B: TEccJacobianPoint256; ChooseA: UInt64);
begin
  FField.Kernel.SelectCT(@R.X.Limbs[0], @A.X.Limbs[0], @B.X.Limbs[0], ChooseA);
  FField.Kernel.SelectCT(@R.Y.Limbs[0], @A.Y.Limbs[0], @B.Y.Limbs[0], ChooseA);
  FField.Kernel.SelectCT(@R.Z.Limbs[0], @A.Z.Limbs[0], @B.Z.Limbs[0], ChooseA);
end;

procedure TWeierstrass256Curve.PointSwapMont(var A, B: TEccJacobianPoint256; DoSwap: UInt64);
begin
  FField.Kernel.SwapCT(@A.X.Limbs[0], @B.X.Limbs[0], DoSwap);
  FField.Kernel.SwapCT(@A.Y.Limbs[0], @B.Y.Limbs[0], DoSwap);
  FField.Kernel.SwapCT(@A.Z.Limbs[0], @B.Z.Limbs[0], DoSwap);
end;

procedure TWeierstrass256Curve.AffineToMont(const P: TEccAffinePoint256; var R: TEccJacobianPoint256);
begin
  if P.Infinity then
  begin
    PointInfinityMont(R);
    Exit;
  end;
  FField.Encode(@R.X.Limbs[0], @P.X.Limbs[0]);
  FField.Encode(@R.Y.Limbs[0], @P.Y.Limbs[0]);
  R.Z := FOneMont;
end;

procedure TWeierstrass256Curve.MontToAffine(const P: TEccJacobianPoint256; var R: TEccAffinePoint256);
var
  ZInv, Z2, Z3, XM, YM: TUInt256;
begin
  if FField.Kernel.IsZeroCT(@P.Z.Limbs[0]) <> 0 then
  begin
    FillChar(R, SizeOf(R), 0); R.Infinity := True; Exit;
  end;
  FMontInverse(ZInv, P.Z); FSqr(Z2, ZInv); FMul(Z3, Z2, ZInv); FMul(XM, P.X, Z2); FMul(YM, P.Y, Z3);
  FField.Decode(@R.X.Limbs[0], @XM.Limbs[0]); FField.Decode(@R.Y.Limbs[0], @YM.Limbs[0]); R.Infinity := False;
  FillChar(ZInv, SizeOf(ZInv), 0); FillChar(Z2, SizeOf(Z2), 0); FillChar(Z3, SizeOf(Z3), 0); FillChar(XM, SizeOf(XM), 0); FillChar(YM, SizeOf(YM), 0);
end;

procedure TWeierstrass256Curve.PointDoubleMont(const P: TEccJacobianPoint256; var R: TEccJacobianPoint256);
var
  A, B, C, D, E, F, T0, T1, Z2: TUInt256;
begin
  FSqr(A, P.X); FSqr(B, P.Y); FSqr(C, B); FAdd(T0, P.X, B); FSqr(T0, T0); FSub(T0, T0, A); FSub(T0, T0, C); FDouble(D, T0);
  if FAForm = wafZero then FTriple(E, A)
  else
  begin
    FSqr(Z2, P.Z); FSub(T0, P.X, Z2); FAdd(T1, P.X, Z2); FMul(E, T0, T1); FTriple(E, E);
  end;
  FSqr(F, E); FDouble(T0, D); FSub(R.X, F, T0); FSub(T0, D, R.X); FMul(T0, E, T0); FTimes8(T1, C); FSub(R.Y, T0, T1); FMul(T0, P.Y, P.Z); FDouble(R.Z, T0);
end;

procedure TWeierstrass256Curve.PointAddMontRaw(const P, Q: TEccJacobianPoint256; var R: TEccJacobianPoint256);
var
  Z1Z1, Z2Z2, U1, U2, S1, S2, H, RR, HH, HHH, V, T0, T1: TUInt256;
begin
  FSqr(Z1Z1, P.Z); FSqr(Z2Z2, Q.Z); FMul(U1, P.X, Z2Z2); FMul(U2, Q.X, Z1Z1);
  FMul(T0, Q.Z, Z2Z2); FMul(S1, P.Y, T0); FMul(T0, P.Z, Z1Z1); FMul(S2, Q.Y, T0);
  FSub(H, U2, U1); FSub(RR, S2, S1); FSqr(HH, H); FMul(HHH, H, HH); FMul(V, U1, HH); FSqr(T0, RR); FSub(T0, T0, HHH); FDouble(T1, V); FSub(R.X, T0, T1);
  FSub(T0, V, R.X); FMul(T0, RR, T0); FMul(T1, S1, HHH); FSub(R.Y, T0, T1); FMul(T0, P.Z, Q.Z); FMul(R.Z, T0, H);
end;

procedure TWeierstrass256Curve.PointAddMontLadder(const P, Q: TEccJacobianPoint256; var R: TEccJacobianPoint256);
var
  AddR, TSel: TEccJacobianPoint256;
  PInf, QInf: UInt64;
begin
  PointAddMontRaw(P, Q, AddR); PInf := FField.Kernel.IsZeroCT(@P.Z.Limbs[0]); QInf := FField.Kernel.IsZeroCT(@Q.Z.Limbs[0]);
  PointSelectMont(TSel, Q, AddR, PInf); PointSelectMont(R, P, TSel, QInf);
end;

procedure TWeierstrass256Curve.PointAddMont(const P, Q: TEccJacobianPoint256; var R: TEccJacobianPoint256);
var
  Z1Z1, Z2Z2, U1, U2, S1, S2, H, RR, T0: TUInt256;
  AddR, DblR, InfR, TSel: TEccJacobianPoint256;
  HZero, RZero, PInf, QInf, SamePoint, Opposite: UInt64;
begin
  PointAddMontRaw(P, Q, AddR); FSqr(Z1Z1, P.Z); FSqr(Z2Z2, Q.Z); FMul(U1, P.X, Z2Z2); FMul(U2, Q.X, Z1Z1); FMul(T0, Q.Z, Z2Z2); FMul(S1, P.Y, T0); FMul(T0, P.Z, Z1Z1); FMul(S2, Q.Y, T0); FSub(H, U2, U1); FSub(RR, S2, S1);
  PointDoubleMont(P, DblR); PointInfinityMont(InfR); HZero := FField.Kernel.IsZeroCT(@H.Limbs[0]); RZero := FField.Kernel.IsZeroCT(@RR.Limbs[0]); PInf := FField.Kernel.IsZeroCT(@P.Z.Limbs[0]); QInf := FField.Kernel.IsZeroCT(@Q.Z.Limbs[0]); SamePoint := HZero and RZero; Opposite := HZero and (RZero xor 1);
  PointSelectMont(TSel, DblR, AddR, SamePoint); PointSelectMont(R, InfR, TSel, Opposite); PointSelectMont(TSel, Q, R, PInf); PointSelectMont(R, P, TSel, QInf);
end;

function TWeierstrass256Curve.TryImportCanonicalBE(Data: Pointer; ByteCount: NativeUInt; const Modulus: TUInt256; Context: TMontgomeryContext; var R: TUInt256): Boolean;
begin
  Zero256(R);
  if (Data = nil) and (ByteCount <> 0) then Exit(False);
  if ByteCount > 32 then Exit(False);
  if ByteCount <> 0 then TBigIntCore.ImportBytes(@R.Limbs[0], 4, Data, ByteCount, bieBigEndian);
  Result := Context.Kernel.CompareCT(@R.Limbs[0], @Modulus.Limbs[0]) < 0;
  if not Result then Zero256(R);
end;

procedure TWeierstrass256Curve.Reduce256(const A, Modulus: TUInt256; Context: TMontgomeryContext; var R: TUInt256);
var
  T: TUInt256;
  Borrow: UInt64;
begin
  Borrow := Context.Kernel.Sub(@T.Limbs[0], @A.Limbs[0], @Modulus.Limbs[0]);
  Context.Kernel.SelectCT(@R.Limbs[0], @T.Limbs[0], @A.Limbs[0], Borrow xor 1);
end;

procedure TWeierstrass256Curve.FieldAdd(var R: TUInt256; const A, B: TUInt256);
var
  S0, S1: TUInt256;
begin
  FField.AddMod(@R.Limbs[0], @A.Limbs[0], @B.Limbs[0], @S0.Limbs[0], @S1.Limbs[0]);
end;

procedure TWeierstrass256Curve.FieldSub(var R: TUInt256; const A, B: TUInt256);
var
  S0, S1: TUInt256;
begin
  FField.SubMod(@R.Limbs[0], @A.Limbs[0], @B.Limbs[0], @S0.Limbs[0], @S1.Limbs[0]);
end;

procedure TWeierstrass256Curve.FieldMul(var R: TUInt256; const A, B: TUInt256);
var
  AM, BM, RM: TUInt256;
begin
  FField.Encode(@AM.Limbs[0], @A.Limbs[0]); FField.Encode(@BM.Limbs[0], @B.Limbs[0]); FField.MontMul(@RM.Limbs[0], @AM.Limbs[0], @BM.Limbs[0]); FField.Decode(@R.Limbs[0], @RM.Limbs[0]);
  FillChar(AM, SizeOf(AM), 0); FillChar(BM, SizeOf(BM), 0); FillChar(RM, SizeOf(RM), 0);
end;

procedure TWeierstrass256Curve.FieldSquare(var R: TUInt256; const A: TUInt256);
begin
  FieldMul(R, A, A);
end;

procedure TWeierstrass256Curve.FieldInverse(var R: TUInt256; const A: TUInt256);
begin
  FField.InversePrimeCT(@R.Limbs[0], @A.Limbs[0]);
end;

procedure TWeierstrass256Curve.FieldNegate(var R: TUInt256; const A: TUInt256);
var
  Z, T: TUInt256;
  IsZero: UInt64;
begin
  Zero256(Z); FField.SubMod(@T.Limbs[0], @Z.Limbs[0], @A.Limbs[0]); IsZero := FField.Kernel.IsZeroCT(@A.Limbs[0]); FField.Kernel.SelectCT(@R.Limbs[0], @Z.Limbs[0], @T.Limbs[0], IsZero);
end;

function TWeierstrass256Curve.FieldIsCanonical(const A: TUInt256): Boolean;
begin
  Result := FField.Kernel.CompareCT(@A.Limbs[0], @FP.Limbs[0]) < 0;
end;

function TWeierstrass256Curve.TryFieldFromBytesBE(Data: Pointer; ByteCount: NativeUInt; var R: TUInt256): Boolean;
begin
  Result := TryImportCanonicalBE(Data, ByteCount, FP, FField, R);
end;

procedure TWeierstrass256Curve.FieldReduceBytesBE(Data: Pointer; ByteCount: NativeUInt; var R: TUInt256);
var
  T: TUInt256;
begin
  if ByteCount > 32 then raise EArgumentOutOfRangeException.Create('ByteCount');
  Zero256(T); if ByteCount <> 0 then TBigIntCore.ImportBytes(@T.Limbs[0], 4, Data, ByteCount, bieBigEndian); Reduce256(T, FP, FField, R);
end;

procedure TWeierstrass256Curve.FieldToBytesBE(const A: TUInt256; Data: Pointer; ByteCount: NativeUInt);
begin
  if not FieldIsCanonical(A) then raise EArgumentException.Create('Field element is not canonical');
  if ByteCount <> 32 then raise EArgumentOutOfRangeException.Create('ByteCount');
  TBigIntCore.ExportBytes(@A.Limbs[0], 4, Data, ByteCount, bieBigEndian);
end;

procedure TWeierstrass256Curve.ScalarAdd(var R: TUInt256; const A, B: TUInt256);
var
  S0, S1: TUInt256;
begin
  FScalar.AddMod(@R.Limbs[0], @A.Limbs[0], @B.Limbs[0], @S0.Limbs[0], @S1.Limbs[0]);
end;

procedure TWeierstrass256Curve.ScalarSub(var R: TUInt256; const A, B: TUInt256);
var
  S0, S1: TUInt256;
begin
  FScalar.SubMod(@R.Limbs[0], @A.Limbs[0], @B.Limbs[0], @S0.Limbs[0], @S1.Limbs[0]);
end;

procedure TWeierstrass256Curve.ScalarMul(var R: TUInt256; const A, B: TUInt256);
var
  AM, BM, RM: TUInt256;
begin
  FScalar.Encode(@AM.Limbs[0], @A.Limbs[0]); FScalar.Encode(@BM.Limbs[0], @B.Limbs[0]); FScalar.MontMul(@RM.Limbs[0], @AM.Limbs[0], @BM.Limbs[0]); FScalar.Decode(@R.Limbs[0], @RM.Limbs[0]);
  FillChar(AM, SizeOf(AM), 0); FillChar(BM, SizeOf(BM), 0); FillChar(RM, SizeOf(RM), 0);
end;

procedure TWeierstrass256Curve.ScalarSquare(var R: TUInt256; const A: TUInt256);
begin
  ScalarMul(R, A, A);
end;

procedure TWeierstrass256Curve.ScalarInverse(var R: TUInt256; const A: TUInt256);
begin
  FScalar.InversePrimeCT(@R.Limbs[0], @A.Limbs[0]);
end;

procedure TWeierstrass256Curve.ScalarNegate(var R: TUInt256; const A: TUInt256);
var
  Z, T: TUInt256;
  IsZero: UInt64;
begin
  Zero256(Z); FScalar.SubMod(@T.Limbs[0], @Z.Limbs[0], @A.Limbs[0]); IsZero := FScalar.Kernel.IsZeroCT(@A.Limbs[0]); FScalar.Kernel.SelectCT(@R.Limbs[0], @Z.Limbs[0], @T.Limbs[0], IsZero);
end;

function TWeierstrass256Curve.ScalarIsCanonical(const A: TUInt256): Boolean;
begin
  Result := FScalar.Kernel.CompareCT(@A.Limbs[0], @FN.Limbs[0]) < 0;
end;

function TWeierstrass256Curve.ScalarIsZero(const A: TUInt256): Boolean;
begin
  Result := FScalar.Kernel.IsZeroCT(@A.Limbs[0]) <> 0;
end;

function TWeierstrass256Curve.TryScalarFromBytesBE(Data: Pointer; ByteCount: NativeUInt; var R: TUInt256): Boolean;
begin
  Result := TryImportCanonicalBE(Data, ByteCount, FN, FScalar, R);
end;

procedure TWeierstrass256Curve.ScalarReduceBytesBE(Data: Pointer; ByteCount: NativeUInt; var R: TUInt256);
var
  T: TUInt256;
begin
  if ByteCount > 32 then raise EArgumentOutOfRangeException.Create('ByteCount');
  Zero256(T); if ByteCount <> 0 then TBigIntCore.ImportBytes(@T.Limbs[0], 4, Data, ByteCount, bieBigEndian); Reduce256(T, FN, FScalar, R);
end;

procedure TWeierstrass256Curve.ScalarToBytesBE(const A: TUInt256; Data: Pointer; ByteCount: NativeUInt);
begin
  if not ScalarIsCanonical(A) then raise EArgumentException.Create('Scalar is not canonical');
  if ByteCount <> 32 then raise EArgumentOutOfRangeException.Create('ByteCount');
  TBigIntCore.ExportBytes(@A.Limbs[0], 4, Data, ByteCount, bieBigEndian);
end;

function TWeierstrass256Curve.PointIsOnCurve(const P: TEccAffinePoint256): Boolean;
var
  Y2, X2, X3, AX, RHS, T: TUInt256;
begin
  if P.Infinity then Exit(True);
  if not FieldIsCanonical(P.X) or not FieldIsCanonical(P.Y) then Exit(False);
  FieldSquare(Y2, P.Y); FieldSquare(X2, P.X); FieldMul(X3, X2, P.X);
  if FAForm = wafZero then Zero256(AX)
  else
  begin
    FieldAdd(T, P.X, P.X); FieldAdd(AX, T, P.X); FieldNegate(AX, AX);
  end;
  FieldAdd(RHS, X3, AX);
  FField.Decode(@T.Limbs[0], @FBMont.Limbs[0]); FieldAdd(RHS, RHS, T);
  Result := FField.Kernel.EqualCT(@Y2.Limbs[0], @RHS.Limbs[0]) <> 0;
end;

procedure TWeierstrass256Curve.PointAdd(const P, Q: TEccAffinePoint256; var R: TEccAffinePoint256);
var
  PM, QM, RM: TEccJacobianPoint256;
begin
  if not PointIsOnCurve(P) or not PointIsOnCurve(Q) then raise EArgumentException.Create('Point is not on curve');
  AffineToMont(P, PM); AffineToMont(Q, QM); PointAddMont(PM, QM, RM); MontToAffine(RM, R);
end;

procedure TWeierstrass256Curve.PointDouble(const P: TEccAffinePoint256; var R: TEccAffinePoint256);
var
  PM, RM: TEccJacobianPoint256;
begin
  if not PointIsOnCurve(P) then raise EArgumentException.Create('Point is not on curve');
  AffineToMont(P, PM); PointDoubleMont(PM, RM); MontToAffine(RM, R);
end;

procedure TWeierstrass256Curve.ScalarMultiply(const P: TEccAffinePoint256; const Scalar: TUInt256; var R: TEccAffinePoint256);
var
  R0, R1, AddR, DblR: TEccJacobianPoint256;
  Bit, Swap: UInt64;
  I: Integer;
begin
  if not PointIsOnCurve(P) then raise EArgumentException.Create('Point is not on curve');
  if not ScalarIsCanonical(Scalar) then raise EArgumentException.Create('Scalar is not canonical');
  PointInfinityMont(R0); AffineToMont(P, R1); Swap := 0;
  try
    for I := 255 downto 0 do
    begin
      Bit := (Scalar.Limbs[I shr 6] shr (I and 63)) and 1;
      Swap := Swap xor Bit; PointSwapMont(R0, R1, Swap); Swap := Bit;
      PointAddMontLadder(R0, R1, AddR); PointDoubleMont(R0, DblR); R1 := AddR; R0 := DblR;
    end;
    PointSwapMont(R0, R1, Swap); MontToAffine(R0, R);
  finally
    FillChar(R0, SizeOf(R0), 0); FillChar(R1, SizeOf(R1), 0); FillChar(AddR, SizeOf(AddR), 0); FillChar(DblR, SizeOf(DblR), 0); Bit := 0; Swap := 0;
  end;
end;

procedure TWeierstrass256Curve.ScalarBaseMultiply(const Scalar: TUInt256; var R: TEccAffinePoint256);
begin
  ScalarMultiply(FGenerator, Scalar, R);
end;

function TWeierstrass256Curve.DecodePoint(Data: Pointer; ByteCount: NativeUInt; var P: TEccAffinePoint256): Boolean;
var
  B: PByte;
  X, Y, X2, X3, AX, RHS, Y2, T, BNorm: TUInt256;
  Prefix: Byte;
begin
  FillChar(P, SizeOf(P), 0); Result := False;
  if (Data = nil) or (ByteCount = 0) then Exit;
  B := PByte(Data); Prefix := B[0];
  if (ByteCount = 1) and (Prefix = 0) then begin P.Infinity := True; Exit(True); end;
  if (ByteCount = 65) and (Prefix = 4) then
  begin
    if not TryFieldFromBytesBE(@B[1], 32, X) or not TryFieldFromBytesBE(@B[33], 32, Y) then Exit;
    P.X := X; P.Y := Y; P.Infinity := False; Result := PointIsOnCurve(P); if not Result then FillChar(P, SizeOf(P), 0); Exit;
  end;
  if (ByteCount <> 33) or ((Prefix <> 2) and (Prefix <> 3)) then Exit;
  if not TryFieldFromBytesBE(@B[1], 32, X) then Exit;
  FieldSquare(X2, X); FieldMul(X3, X2, X);
  if FAForm = wafZero then Zero256(AX)
  else begin FieldAdd(T, X, X); FieldAdd(AX, T, X); FieldNegate(AX, AX); end;
  FField.Decode(@BNorm.Limbs[0], @FBMont.Limbs[0]); FieldAdd(RHS, X3, AX); FieldAdd(RHS, RHS, BNorm);
  FField.PowCT(@Y.Limbs[0], @RHS.Limbs[0], @FSqrtExponentBE[0], Length(FSqrtExponentBE)); FieldSquare(Y2, Y);
  if FField.Kernel.EqualCT(@Y2.Limbs[0], @RHS.Limbs[0]) = 0 then Exit;
  if (Y.Limbs[0] and 1) <> UInt64(Prefix and 1) then FieldNegate(Y, Y);
  P.X := X; P.Y := Y; P.Infinity := False; Result := True;
end;

function TWeierstrass256Curve.EncodePointCompressed(const P: TEccAffinePoint256): TBytes;
begin
  if not PointIsOnCurve(P) then raise EArgumentException.Create('Point is not on curve');
  if P.Infinity then begin SetLength(Result, 1); Result[0] := 0; Exit; end;
  SetLength(Result, 33); Result[0] := Byte(2 or (P.Y.Limbs[0] and 1)); TBigIntCore.ExportBytes(@P.X.Limbs[0], 4, @Result[1], 32, bieBigEndian);
end;

function TWeierstrass256Curve.EncodePointUncompressed(const P: TEccAffinePoint256): TBytes;
begin
  if not PointIsOnCurve(P) then raise EArgumentException.Create('Point is not on curve');
  if P.Infinity then begin SetLength(Result, 1); Result[0] := 0; Exit; end;
  SetLength(Result, 65); Result[0] := 4; TBigIntCore.ExportBytes(@P.X.Limbs[0], 4, @Result[1], 32, bieBigEndian); TBigIntCore.ExportBytes(@P.Y.Limbs[0], 4, @Result[33], 32, bieBigEndian);
end;

end.
