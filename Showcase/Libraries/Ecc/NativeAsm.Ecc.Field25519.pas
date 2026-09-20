{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
unit NativeAsm.Ecc.Field25519;

interface

uses
  System.SysUtils,
  NativeAsm.BigInt.Types,
  NativeAsm.BigInt.Core,
  NativeAsm.BigInt.Montgomery,
  NativeAsm.Ecc.Types;

type
  TField25519 = class
  private
    FField: TMontgomeryContext;
    FScalar: TMontgomeryContext;
    FP: TUInt256;
    FL: TUInt256;
    FOneMont: TUInt256;
    FA24Mont: TUInt256;
    class procedure Zero256(var R: TUInt256); static;
    class procedure LoadHex256(var R: TUInt256; const Hex: string); static;
    procedure FAdd(var R: TUInt256; const A, B: TUInt256); inline;
    procedure FSub(var R: TUInt256; const A, B: TUInt256); inline;
    procedure FMul(var R: TUInt256; const A, B: TUInt256); inline;
    procedure FSqr(var R: TUInt256; const A: TUInt256); inline;
    procedure FMontInverse(var R: TUInt256; const A: TUInt256);
    procedure NormalizeField255(var R: TUInt256; const A: TUInt256);
    procedure ScalarReduceFixed(var R: TUInt256; const A: TUInt256);
  public
    constructor Create;
    destructor Destroy; override;
    procedure FieldAdd(var R: TUInt256; const A, B: TUInt256);
    procedure FieldSub(var R: TUInt256; const A, B: TUInt256);
    procedure FieldMul(var R: TUInt256; const A, B: TUInt256);
    procedure FieldSquare(var R: TUInt256; const A: TUInt256);
    procedure FieldInverse(var R: TUInt256; const A: TUInt256);
    procedure FieldNegate(var R: TUInt256; const A: TUInt256);
    function FieldIsCanonical(const A: TUInt256): Boolean;
    function TryFieldFromBytesLE(const Data: TX25519Bytes; var R: TUInt256): Boolean;
    procedure FieldReduceBytesLE(const Data: TX25519Bytes; var R: TUInt256);
    procedure FieldToBytesLE(const A: TUInt256; var Data: TX25519Bytes);
    procedure ScalarAdd(var R: TUInt256; const A, B: TUInt256);
    procedure ScalarSub(var R: TUInt256; const A, B: TUInt256);
    procedure ScalarMul(var R: TUInt256; const A, B: TUInt256);
    procedure ScalarSquare(var R: TUInt256; const A: TUInt256);
    procedure ScalarInverse(var R: TUInt256; const A: TUInt256);
    procedure ScalarNegate(var R: TUInt256; const A: TUInt256);
    function ScalarIsCanonical(const A: TUInt256): Boolean;
    function TryScalarFromBytesLE(const Data: TX25519Bytes; var R: TUInt256): Boolean;
    procedure ScalarReduceBytesLE(const Data: TX25519Bytes; var R: TUInt256);
    procedure ScalarReduceWideLE(Data: Pointer; ByteCount: NativeUInt; var R: TUInt256);
    procedure ScalarReduce64LE(const Data: TEccBytes64; var R: TUInt256);
    procedure ScalarToBytesLE(const A: TUInt256; var Data: TX25519Bytes);
    procedure X25519(const Scalar, U: TX25519Bytes; var Output: TX25519Bytes);
    procedure X25519Base(const Scalar: TX25519Bytes; var Output: TX25519Bytes);
    function X25519Checked(const Scalar, U: TX25519Bytes; var Output: TX25519Bytes): Boolean;
    property FieldModulus: TUInt256 read FP;
    property ScalarOrder: TUInt256 read FL;
    property FieldContext: TMontgomeryContext read FField;
    property ScalarContext: TMontgomeryContext read FScalar;
  end;

implementation

{$Q-}
{$R-}

class procedure TField25519.Zero256(var R: TUInt256);
begin
  FillChar(R, SizeOf(R), 0);
end;

class procedure TField25519.LoadHex256(var R: TUInt256; const Hex: string);
var
  V: TBigIntLimbs;
begin
  V := TBigIntCore.FromHex(Hex, 4); Zero256(R); Move(V[0], R.Limbs[0], Length(V) * SizeOf(UInt64));
end;

constructor TField25519.Create;
var
  PArr, LArr, OneMont: TBigIntLimbs;
  A24: TUInt256;
begin
  inherited Create;
  LoadHex256(FP, '7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFED');
  LoadHex256(FL, '1000000000000000000000000000000014DEF9DEA2F79CD65812631A5CF5D3ED');
  SetLength(PArr, 4); SetLength(LArr, 4); Move(FP.Limbs[0], PArr[0], SizeOf(FP)); Move(FL.Limbs[0], LArr[0], SizeOf(FL));
  FField := TMontgomeryContext.Create(PArr); FScalar := TMontgomeryContext.Create(LArr);
  OneMont := FField.OneMont; Move(OneMont[0], FOneMont.Limbs[0], SizeOf(FOneMont));
  Zero256(A24); A24.Limbs[0] := 121665; FField.Encode(@FA24Mont.Limbs[0], @A24.Limbs[0]); FillChar(A24, SizeOf(A24), 0);
end;

destructor TField25519.Destroy;
begin
  if FField <> nil then begin FField.Kernel.Zero(@FOneMont.Limbs[0]); FField.Kernel.Zero(@FA24Mont.Limbs[0]); end;
  FillChar(FP, SizeOf(FP), 0); FillChar(FL, SizeOf(FL), 0); FScalar.Free; FField.Free; inherited;
end;

procedure TField25519.FAdd(var R: TUInt256; const A, B: TUInt256);
var
  S0, S1: TUInt256;
begin
  FField.AddMod(@R.Limbs[0], @A.Limbs[0], @B.Limbs[0], @S0.Limbs[0], @S1.Limbs[0]);
end;

procedure TField25519.FSub(var R: TUInt256; const A, B: TUInt256);
var
  S0, S1: TUInt256;
begin
  FField.SubMod(@R.Limbs[0], @A.Limbs[0], @B.Limbs[0], @S0.Limbs[0], @S1.Limbs[0]);
end;

procedure TField25519.FMul(var R: TUInt256; const A, B: TUInt256);
begin
  FField.MontMul(@R.Limbs[0], @A.Limbs[0], @B.Limbs[0]);
end;

procedure TField25519.FSqr(var R: TUInt256; const A: TUInt256);
begin
  FField.MontSquare(@R.Limbs[0], @A.Limbs[0]);
end;

procedure TField25519.FMontInverse(var R: TUInt256; const A: TUInt256);
var
  N, I: TUInt256;
begin
  FField.Decode(@N.Limbs[0], @A.Limbs[0]); FField.InversePrimeCT(@I.Limbs[0], @N.Limbs[0]); FField.Encode(@R.Limbs[0], @I.Limbs[0]); FillChar(N, SizeOf(N), 0); FillChar(I, SizeOf(I), 0);
end;

procedure TField25519.NormalizeField255(var R: TUInt256; const A: TUInt256);
var
  T: TUInt256;
  Borrow: UInt64;
begin
  Borrow := FField.Kernel.Sub(@T.Limbs[0], @A.Limbs[0], @FP.Limbs[0]); FField.Kernel.SelectCT(@R.Limbs[0], @T.Limbs[0], @A.Limbs[0], Borrow xor 1);
end;

procedure TField25519.ScalarReduceFixed(var R: TUInt256; const A: TUInt256);
var
  T0, T1: TUInt256;
  Borrow: UInt64;
  I: Integer;
begin
  T0 := A;
  for I := 0 to 15 do
  begin
    Borrow := FScalar.Kernel.Sub(@T1.Limbs[0], @T0.Limbs[0], @FL.Limbs[0]); FScalar.Kernel.SelectCT(@T0.Limbs[0], @T1.Limbs[0], @T0.Limbs[0], Borrow xor 1);
  end;
  R := T0; FillChar(T0, SizeOf(T0), 0); FillChar(T1, SizeOf(T1), 0);
end;

procedure TField25519.FieldAdd(var R: TUInt256; const A, B: TUInt256);
var
  S0, S1: TUInt256;
begin
  FField.AddMod(@R.Limbs[0], @A.Limbs[0], @B.Limbs[0], @S0.Limbs[0], @S1.Limbs[0]);
end;

procedure TField25519.FieldSub(var R: TUInt256; const A, B: TUInt256);
var
  S0, S1: TUInt256;
begin
  FField.SubMod(@R.Limbs[0], @A.Limbs[0], @B.Limbs[0], @S0.Limbs[0], @S1.Limbs[0]);
end;

procedure TField25519.FieldMul(var R: TUInt256; const A, B: TUInt256);
var
  AM, BM, RM: TUInt256;
begin
  FField.Encode(@AM.Limbs[0], @A.Limbs[0]); FField.Encode(@BM.Limbs[0], @B.Limbs[0]); FField.MontMul(@RM.Limbs[0], @AM.Limbs[0], @BM.Limbs[0]); FField.Decode(@R.Limbs[0], @RM.Limbs[0]); FillChar(AM, SizeOf(AM), 0); FillChar(BM, SizeOf(BM), 0); FillChar(RM, SizeOf(RM), 0);
end;

procedure TField25519.FieldSquare(var R: TUInt256; const A: TUInt256);
begin
  FieldMul(R, A, A);
end;

procedure TField25519.FieldInverse(var R: TUInt256; const A: TUInt256);
begin
  FField.InversePrimeCT(@R.Limbs[0], @A.Limbs[0]);
end;

procedure TField25519.FieldNegate(var R: TUInt256; const A: TUInt256);
var
  Z, T: TUInt256;
  IsZero: UInt64;
begin
  Zero256(Z); FField.SubMod(@T.Limbs[0], @Z.Limbs[0], @A.Limbs[0]); IsZero := FField.Kernel.IsZeroCT(@A.Limbs[0]); FField.Kernel.SelectCT(@R.Limbs[0], @Z.Limbs[0], @T.Limbs[0], IsZero);
end;

function TField25519.FieldIsCanonical(const A: TUInt256): Boolean;
begin
  Result := FField.Kernel.CompareCT(@A.Limbs[0], @FP.Limbs[0]) < 0;
end;

function TField25519.TryFieldFromBytesLE(const Data: TX25519Bytes; var R: TUInt256): Boolean;
begin
  TBigIntCore.ImportBytes(@R.Limbs[0], 4, @Data[0], 32, bieLittleEndian); Result := FieldIsCanonical(R); if not Result then Zero256(R);
end;

procedure TField25519.FieldReduceBytesLE(const Data: TX25519Bytes; var R: TUInt256);
var
  B: TX25519Bytes;
  T: TUInt256;
begin
  B := Data; B[31] := B[31] and $7F; TBigIntCore.ImportBytes(@T.Limbs[0], 4, @B[0], 32, bieLittleEndian); NormalizeField255(R, T); FillChar(B, SizeOf(B), 0); FillChar(T, SizeOf(T), 0);
end;

procedure TField25519.FieldToBytesLE(const A: TUInt256; var Data: TX25519Bytes);
begin
  if not FieldIsCanonical(A) then raise EArgumentException.Create('Field element is not canonical');
  TBigIntCore.ExportBytes(@A.Limbs[0], 4, @Data[0], 32, bieLittleEndian);
end;

procedure TField25519.ScalarAdd(var R: TUInt256; const A, B: TUInt256);
var
  S0, S1: TUInt256;
begin
  FScalar.AddMod(@R.Limbs[0], @A.Limbs[0], @B.Limbs[0], @S0.Limbs[0], @S1.Limbs[0]);
end;

procedure TField25519.ScalarSub(var R: TUInt256; const A, B: TUInt256);
var
  S0, S1: TUInt256;
begin
  FScalar.SubMod(@R.Limbs[0], @A.Limbs[0], @B.Limbs[0], @S0.Limbs[0], @S1.Limbs[0]);
end;

procedure TField25519.ScalarMul(var R: TUInt256; const A, B: TUInt256);
var
  AM, BM, RM: TUInt256;
begin
  FScalar.Encode(@AM.Limbs[0], @A.Limbs[0]); FScalar.Encode(@BM.Limbs[0], @B.Limbs[0]); FScalar.MontMul(@RM.Limbs[0], @AM.Limbs[0], @BM.Limbs[0]); FScalar.Decode(@R.Limbs[0], @RM.Limbs[0]); FillChar(AM, SizeOf(AM), 0); FillChar(BM, SizeOf(BM), 0); FillChar(RM, SizeOf(RM), 0);
end;

procedure TField25519.ScalarSquare(var R: TUInt256; const A: TUInt256);
begin
  ScalarMul(R, A, A);
end;

procedure TField25519.ScalarInverse(var R: TUInt256; const A: TUInt256);
begin
  FScalar.InversePrimeCT(@R.Limbs[0], @A.Limbs[0]);
end;

procedure TField25519.ScalarNegate(var R: TUInt256; const A: TUInt256);
var
  Z, T: TUInt256;
  IsZero: UInt64;
begin
  Zero256(Z); FScalar.SubMod(@T.Limbs[0], @Z.Limbs[0], @A.Limbs[0]); IsZero := FScalar.Kernel.IsZeroCT(@A.Limbs[0]); FScalar.Kernel.SelectCT(@R.Limbs[0], @Z.Limbs[0], @T.Limbs[0], IsZero);
end;

function TField25519.ScalarIsCanonical(const A: TUInt256): Boolean;
begin
  Result := FScalar.Kernel.CompareCT(@A.Limbs[0], @FL.Limbs[0]) < 0;
end;

function TField25519.TryScalarFromBytesLE(const Data: TX25519Bytes; var R: TUInt256): Boolean;
begin
  TBigIntCore.ImportBytes(@R.Limbs[0], 4, @Data[0], 32, bieLittleEndian); Result := ScalarIsCanonical(R); if not Result then Zero256(R);
end;

procedure TField25519.ScalarReduceBytesLE(const Data: TX25519Bytes; var R: TUInt256);
var
  T: TUInt256;
begin
  TBigIntCore.ImportBytes(@T.Limbs[0], 4, @Data[0], 32, bieLittleEndian); ScalarReduceFixed(R, T); FillChar(T, SizeOf(T), 0);
end;

procedure TField25519.ScalarReduceWideLE(Data: Pointer; ByteCount: NativeUInt; var R: TUInt256);
var
  RM, C256, C256M, BN, BM, S0, S1: TUInt256;
  P: PByte;
  I: Integer;
begin
  if ByteCount > 64 then raise EArgumentOutOfRangeException.Create('ByteCount'); if (Data = nil) and (ByteCount <> 0) then raise EArgumentNilException.Create('Data'); Zero256(RM); Zero256(C256); C256.Limbs[0] := 256; FScalar.Encode(@C256M.Limbs[0], @C256.Limbs[0]); P := PByte(Data);
  try
    if ByteCount <> 0 then for I := Integer(ByteCount) - 1 downto 0 do begin FScalar.MontMul(@RM.Limbs[0], @RM.Limbs[0], @C256M.Limbs[0]); Zero256(BN); BN.Limbs[0] := P[I]; FScalar.Encode(@BM.Limbs[0], @BN.Limbs[0]); FScalar.AddMod(@RM.Limbs[0], @RM.Limbs[0], @BM.Limbs[0], @S0.Limbs[0], @S1.Limbs[0]); end; FScalar.Decode(@R.Limbs[0], @RM.Limbs[0]);
  finally
    FillChar(RM, SizeOf(RM), 0); FillChar(C256, SizeOf(C256), 0); FillChar(C256M, SizeOf(C256M), 0); FillChar(BN, SizeOf(BN), 0); FillChar(BM, SizeOf(BM), 0); FillChar(S0, SizeOf(S0), 0); FillChar(S1, SizeOf(S1), 0);
  end;
end;

procedure TField25519.ScalarReduce64LE(const Data: TEccBytes64; var R: TUInt256);
begin
  ScalarReduceWideLE(@Data[0], 64, R);
end;

procedure TField25519.ScalarToBytesLE(const A: TUInt256; var Data: TX25519Bytes);
begin
  if not ScalarIsCanonical(A) then raise EArgumentException.Create('Scalar is not canonical'); TBigIntCore.ExportBytes(@A.Limbs[0], 4, @Data[0], 32, bieLittleEndian);
end;

procedure TField25519.X25519(const Scalar, U: TX25519Bytes; var Output: TX25519Bytes);
var
  K, UB: TX25519Bytes;
  X1N, X1, X2, Z2, X3, Z3, A, AA, B, BB, E, C, D, DA, CB, T0, T1, ZInv, RM, RN: TUInt256;
  Bit, Swap: UInt64;
  I: Integer;
begin
  K := Scalar; UB := U; K[0] := K[0] and 248; K[31] := (K[31] and 127) or 64; UB[31] := UB[31] and 127;
  TBigIntCore.ImportBytes(@X1N.Limbs[0], 4, @UB[0], 32, bieLittleEndian); NormalizeField255(X1N, X1N); FField.Encode(@X1.Limbs[0], @X1N.Limbs[0]);
  X2 := FOneMont; Zero256(Z2); X3 := X1; Z3 := FOneMont; Swap := 0;
  try
    for I := 254 downto 0 do
    begin
      Bit := (K[I shr 3] shr (I and 7)) and 1; Swap := Swap xor Bit; FField.Kernel.SwapCT(@X2.Limbs[0], @X3.Limbs[0], Swap); FField.Kernel.SwapCT(@Z2.Limbs[0], @Z3.Limbs[0], Swap); Swap := Bit;
      FAdd(A, X2, Z2); FSqr(AA, A); FSub(B, X2, Z2); FSqr(BB, B); FSub(E, AA, BB); FAdd(C, X3, Z3); FSub(D, X3, Z3); FMul(DA, D, A); FMul(CB, C, B);
      FAdd(T0, DA, CB); FSqr(X3, T0); FSub(T0, DA, CB); FSqr(T0, T0); FMul(Z3, X1, T0); FMul(X2, AA, BB); FMul(T0, FA24Mont, E); FAdd(T1, AA, T0); FMul(Z2, E, T1);
    end;
    FField.Kernel.SwapCT(@X2.Limbs[0], @X3.Limbs[0], Swap); FField.Kernel.SwapCT(@Z2.Limbs[0], @Z3.Limbs[0], Swap);
    if FField.Kernel.IsZeroCT(@Z2.Limbs[0]) <> 0 then FillChar(Output, SizeOf(Output), 0)
    else begin FMontInverse(ZInv, Z2); FMul(RM, X2, ZInv); FField.Decode(@RN.Limbs[0], @RM.Limbs[0]); TBigIntCore.ExportBytes(@RN.Limbs[0], 4, @Output[0], 32, bieLittleEndian); end;
  finally
    FillChar(K, SizeOf(K), 0); FillChar(UB, SizeOf(UB), 0); FillChar(X1N, SizeOf(X1N), 0); FillChar(X1, SizeOf(X1), 0); FillChar(X2, SizeOf(X2), 0); FillChar(Z2, SizeOf(Z2), 0); FillChar(X3, SizeOf(X3), 0); FillChar(Z3, SizeOf(Z3), 0); FillChar(A, SizeOf(A), 0); FillChar(AA, SizeOf(AA), 0); FillChar(B, SizeOf(B), 0); FillChar(BB, SizeOf(BB), 0); FillChar(E, SizeOf(E), 0); FillChar(C, SizeOf(C), 0); FillChar(D, SizeOf(D), 0); FillChar(DA, SizeOf(DA), 0); FillChar(CB, SizeOf(CB), 0); FillChar(T0, SizeOf(T0), 0); FillChar(T1, SizeOf(T1), 0); FillChar(ZInv, SizeOf(ZInv), 0); FillChar(RM, SizeOf(RM), 0); FillChar(RN, SizeOf(RN), 0); Bit := 0; Swap := 0;
  end;
end;

procedure TField25519.X25519Base(const Scalar: TX25519Bytes; var Output: TX25519Bytes);
var
  U: TX25519Bytes;
begin
  FillChar(U, SizeOf(U), 0); U[0] := 9; X25519(Scalar, U, Output);
end;

function TField25519.X25519Checked(const Scalar, U: TX25519Bytes; var Output: TX25519Bytes): Boolean;
var
  I: Integer;
  V: Byte;
begin
  X25519(Scalar, U, Output); V := 0; for I := 0 to 31 do V := V or Output[I]; Result := V <> 0;
end;

end.
