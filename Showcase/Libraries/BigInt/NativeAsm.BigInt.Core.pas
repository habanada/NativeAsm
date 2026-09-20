{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
unit NativeAsm.BigInt.Core;

interface

uses
  System.SysUtils,
  NativeAsm.BigInt.Types;

type
  TBigIntCore = class sealed
  private
    class function RangesOverlap(A: Pointer; ABytes: NativeUInt; B: Pointer; BBytes: NativeUInt): Boolean; static;
  public
    class procedure Zero(Dst: PBigIntLimb; Limbs: NativeUInt); static;
    class procedure Copy(Dst, Src: PBigIntLimb; Limbs: NativeUInt); static;
    class function Add(Dst, A, B: PBigIntLimb; Limbs: NativeUInt): UInt64; static;
    class function Sub(Dst, A, B: PBigIntLimb; Limbs: NativeUInt): UInt64; static;
    class function Compare(A, B: PBigIntLimb; Limbs: NativeUInt): Integer; static;
    class function IsZero(A: PBigIntLimb; Limbs: NativeUInt): Boolean; static;
    class procedure Mul64Wide(A, B: UInt64; out Lo, Hi: UInt64); static;
    class function MulWord(Dst, A: PBigIntLimb; WordValue: UInt64; Limbs: NativeUInt): UInt64; static;
    class function AddMulWord(Dst, A: PBigIntLimb; WordValue: UInt64; Limbs: NativeUInt): UInt64; static;
    class procedure MulWide(Dst, A, B: PBigIntLimb; Limbs: NativeUInt); static;
    class procedure SquareWide(Dst, A: PBigIntLimb; Limbs: NativeUInt); static;
    class procedure ShiftLeft(Dst, Src: PBigIntLimb; Limbs, Bits: NativeUInt); static;
    class procedure ShiftRight(Dst, Src: PBigIntLimb; Limbs, Bits: NativeUInt); static;
    class function BitLength(A: PBigIntLimb; Limbs: NativeUInt): NativeUInt; static;
    class function GetBit(A: PBigIntLimb; Limbs, BitIndex: NativeUInt): UInt64; static;
    class procedure SetBit(A: PBigIntLimb; Limbs, BitIndex: NativeUInt); static;
    class procedure ImportBytes(Dst: PBigIntLimb; Limbs: NativeUInt; Src: Pointer; ByteCount: NativeUInt; Endian: TBigIntEndian); static;
    class procedure ExportBytes(Src: PBigIntLimb; Limbs: NativeUInt; Dst: Pointer; ByteCount: NativeUInt; Endian: TBigIntEndian); static;
    class function FromHex(const Value: string; MinLimbs: NativeUInt = 0): TBigIntLimbs; static;
    class function ToHex(A: PBigIntLimb; Limbs: NativeUInt; TrimLeadingZeroes: Boolean = True): string; static;
  end;

implementation

{$Q-}
{$R-}

function LimbAt(P: PBigIntLimb; Index: NativeUInt): PBigIntLimb; inline;
begin
  Inc(P, Index);
  Result := P;
end;

class function TBigIntCore.RangesOverlap(A: Pointer; ABytes: NativeUInt; B: Pointer; BBytes: NativeUInt): Boolean;
var
  A0, A1, B0, B1: NativeUInt;
begin
  if (ABytes = 0) or (BBytes = 0) then Exit(False);
  A0 := NativeUInt(A); B0 := NativeUInt(B);
  if (A0 > High(NativeUInt) - ABytes) or (B0 > High(NativeUInt) - BBytes) then Exit(True);
  A1 := A0 + ABytes; B1 := B0 + BBytes;
  Result := (A0 < B1) and (B0 < A1);
end;

class procedure TBigIntCore.Zero(Dst: PBigIntLimb; Limbs: NativeUInt);
begin
  if (Dst = nil) and (Limbs <> 0) then raise EArgumentNilException.Create('Dst');
  if Limbs <> 0 then FillChar(Dst^, Limbs * SizeOf(UInt64), 0);
end;

class procedure TBigIntCore.Copy(Dst, Src: PBigIntLimb; Limbs: NativeUInt);
begin
  if Limbs = 0 then Exit;
  if Dst = nil then raise EArgumentNilException.Create('Dst');
  if Src = nil then raise EArgumentNilException.Create('Src');
  Move(Src^, Dst^, Limbs * SizeOf(UInt64));
end;

class function TBigIntCore.Add(Dst, A, B: PBigIntLimb; Limbs: NativeUInt): UInt64;
var
  I: NativeUInt;
  X, Y, S, T, Carry, C1, C2: UInt64;
begin
  if Limbs = 0 then Exit(0);
  if Dst = nil then raise EArgumentNilException.Create('Dst');
  if A = nil then raise EArgumentNilException.Create('A');
  if B = nil then raise EArgumentNilException.Create('B');
  Carry := 0;
  for I := 0 to Limbs - 1 do
  begin
    X := A^; Y := B^;
    S := X + Y;
    C1 := UInt64(Ord(S < X));
    T := S + Carry;
    C2 := UInt64(Ord(T < S));
    Dst^ := T;
    Carry := C1 or C2;
    Inc(Dst); Inc(A); Inc(B);
  end;
  Result := Carry;
end;

class function TBigIntCore.Sub(Dst, A, B: PBigIntLimb; Limbs: NativeUInt): UInt64;
var
  I: NativeUInt;
  X, Y, S, T, Borrow, B1, B2: UInt64;
begin
  if Limbs = 0 then Exit(0);
  if Dst = nil then raise EArgumentNilException.Create('Dst');
  if A = nil then raise EArgumentNilException.Create('A');
  if B = nil then raise EArgumentNilException.Create('B');
  Borrow := 0;
  for I := 0 to Limbs - 1 do
  begin
    X := A^; Y := B^;
    S := X - Y;
    B1 := UInt64(Ord(X < Y));
    T := S - Borrow;
    B2 := UInt64(Ord(S < Borrow));
    Dst^ := T;
    Borrow := B1 or B2;
    Inc(Dst); Inc(A); Inc(B);
  end;
  Result := Borrow;
end;

class function TBigIntCore.Compare(A, B: PBigIntLimb; Limbs: NativeUInt): Integer;
var
  I: NativeInt;
begin
  if Limbs = 0 then Exit(0);
  if A = nil then raise EArgumentNilException.Create('A');
  if B = nil then raise EArgumentNilException.Create('B');
  I := NativeInt(Limbs) - 1;
  while I >= 0 do
  begin
    if LimbAt(A, NativeUInt(I))^ < LimbAt(B, NativeUInt(I))^ then Exit(-1);
    if LimbAt(A, NativeUInt(I))^ > LimbAt(B, NativeUInt(I))^ then Exit(1);
    Dec(I);
  end;
  Result := 0;
end;

class function TBigIntCore.IsZero(A: PBigIntLimb; Limbs: NativeUInt): Boolean;
var
  I: NativeUInt;
  V: UInt64;
begin
  if Limbs = 0 then Exit(True);
  if A = nil then raise EArgumentNilException.Create('A');
  V := 0;
  for I := 0 to Limbs - 1 do V := V or LimbAt(A, I)^;
  Result := V = 0;
end;

class procedure TBigIntCore.Mul64Wide(A, B: UInt64; out Lo, Hi: UInt64);
var
  A0, A1, B0, B1: UInt64;
  P00, P01, P10, P11, Mid: UInt64;
begin
  A0 := Cardinal(A); A1 := A shr 32;
  B0 := Cardinal(B); B1 := B shr 32;
  P00 := A0 * B0;
  P01 := A0 * B1;
  P10 := A1 * B0;
  P11 := A1 * B1;
  Mid := (P00 shr 32) + Cardinal(P01) + Cardinal(P10);
  Lo := (P00 and $FFFFFFFF) or (Mid shl 32);
  Hi := P11 + (P01 shr 32) + (P10 shr 32) + (Mid shr 32);
end;

class function TBigIntCore.MulWord(Dst, A: PBigIntLimb; WordValue: UInt64; Limbs: NativeUInt): UInt64;
var
  I: NativeUInt;
  Lo, Hi, T, Carry, C: UInt64;
begin
  if Limbs = 0 then Exit(0);
  if Dst = nil then raise EArgumentNilException.Create('Dst');
  if A = nil then raise EArgumentNilException.Create('A');
  Carry := 0;
  for I := 0 to Limbs - 1 do
  begin
    Mul64Wide(LimbAt(A, I)^, WordValue, Lo, Hi);
    T := Lo + Carry;
    C := UInt64(Ord(T < Lo));
    LimbAt(Dst, I)^ := T;
    Carry := Hi + C;
  end;
  Result := Carry;
end;

class function TBigIntCore.AddMulWord(Dst, A: PBigIntLimb; WordValue: UInt64; Limbs: NativeUInt): UInt64;
var
  I: NativeUInt;
  Lo, Hi, T, U, Carry, C1, C2: UInt64;
begin
  if Limbs = 0 then Exit(0);
  if Dst = nil then raise EArgumentNilException.Create('Dst');
  if A = nil then raise EArgumentNilException.Create('A');
  Carry := 0;
  for I := 0 to Limbs - 1 do
  begin
    Mul64Wide(LimbAt(A, I)^, WordValue, Lo, Hi);
    T := Lo + LimbAt(Dst, I)^;
    C1 := UInt64(Ord(T < Lo));
    U := T + Carry;
    C2 := UInt64(Ord(U < T));
    LimbAt(Dst, I)^ := U;
    Carry := Hi + C1 + C2;
  end;
  Result := Carry;
end;

class procedure TBigIntCore.MulWide(Dst, A, B: PBigIntLimb; Limbs: NativeUInt);
var
  I, J, K: NativeUInt;
  Lo, Hi, T, U, Carry, C1, C2: UInt64;
begin
  if Limbs = 0 then Exit;
  if Dst = nil then raise EArgumentNilException.Create('Dst');
  if A = nil then raise EArgumentNilException.Create('A');
  if B = nil then raise EArgumentNilException.Create('B');
  if Limbs > High(NativeUInt) div (SizeOf(UInt64) * 2) then raise ERangeError.Create('Limbs');
  if RangesOverlap(Dst, Limbs * SizeOf(UInt64) * 2, A, Limbs * SizeOf(UInt64)) or RangesOverlap(Dst, Limbs * SizeOf(UInt64) * 2, B, Limbs * SizeOf(UInt64)) then raise EArgumentException.Create('MulWide destination overlaps input');
  Zero(Dst, Limbs * 2);
  for I := 0 to Limbs - 1 do
  begin
    Carry := 0;
    for J := 0 to Limbs - 1 do
    begin
      K := I + J;
      Mul64Wide(LimbAt(A, J)^, LimbAt(B, I)^, Lo, Hi);
      T := Lo + LimbAt(Dst, K)^;
      C1 := UInt64(Ord(T < Lo));
      U := T + Carry;
      C2 := UInt64(Ord(U < T));
      LimbAt(Dst, K)^ := U;
      Carry := Hi + C1 + C2;
    end;
    LimbAt(Dst, I + Limbs)^ := Carry;
  end;
end;

class procedure TBigIntCore.SquareWide(Dst, A: PBigIntLimb; Limbs: NativeUInt);
begin
  MulWide(Dst, A, A, Limbs);
end;

class procedure TBigIntCore.ShiftLeft(Dst, Src: PBigIntLimb; Limbs, Bits: NativeUInt);
var
  LimbShift, BitShift, I: NativeUInt;
  V, Carry: UInt64;
begin
  if Limbs = 0 then Exit;
  if Dst = nil then raise EArgumentNilException.Create('Dst');
  if Src = nil then raise EArgumentNilException.Create('Src');
  if Bits >= Limbs * 64 then begin Zero(Dst, Limbs); Exit; end;
  LimbShift := Bits div 64;
  BitShift := Bits and 63;
  I := Limbs;
  while I > 0 do
  begin
    Dec(I);
    V := 0;
    if I >= LimbShift then
    begin
      V := LimbAt(Src, I - LimbShift)^ shl BitShift;
      if (BitShift <> 0) and (I > LimbShift) then
      begin
        Carry := LimbAt(Src, I - LimbShift - 1)^ shr (64 - BitShift);
        V := V or Carry;
      end;
    end;
    LimbAt(Dst, I)^ := V;
  end;
end;

class procedure TBigIntCore.ShiftRight(Dst, Src: PBigIntLimb; Limbs, Bits: NativeUInt);
var
  LimbShift, BitShift, I: NativeUInt;
  V, Carry: UInt64;
begin
  if Limbs = 0 then Exit;
  if Dst = nil then raise EArgumentNilException.Create('Dst');
  if Src = nil then raise EArgumentNilException.Create('Src');
  if Bits >= Limbs * 64 then begin Zero(Dst, Limbs); Exit; end;
  LimbShift := Bits div 64;
  BitShift := Bits and 63;
  for I := 0 to Limbs - 1 do
  begin
    V := 0;
    if I + LimbShift < Limbs then
    begin
      V := LimbAt(Src, I + LimbShift)^ shr BitShift;
      if (BitShift <> 0) and (I + LimbShift + 1 < Limbs) then
      begin
        Carry := LimbAt(Src, I + LimbShift + 1)^ shl (64 - BitShift);
        V := V or Carry;
      end;
    end;
    LimbAt(Dst, I)^ := V;
  end;
end;

class function TBigIntCore.BitLength(A: PBigIntLimb; Limbs: NativeUInt): NativeUInt;
var
  I: NativeInt;
  V: UInt64;
  Bits: NativeUInt;
begin
  if Limbs = 0 then Exit(0);
  if A = nil then raise EArgumentNilException.Create('A');
  I := NativeInt(Limbs) - 1;
  while (I >= 0) and (LimbAt(A, NativeUInt(I))^ = 0) do Dec(I);
  if I < 0 then Exit(0);
  V := LimbAt(A, NativeUInt(I))^; Bits := 0;
  while V <> 0 do begin Inc(Bits); V := V shr 1; end;
  Result := NativeUInt(I) * 64 + Bits;
end;

class function TBigIntCore.GetBit(A: PBigIntLimb; Limbs, BitIndex: NativeUInt): UInt64;
var
  I: NativeUInt;
begin
  I := BitIndex div 64;
  if I >= Limbs then Exit(0);
  if A = nil then raise EArgumentNilException.Create('A');
  Result := (LimbAt(A, I)^ shr (BitIndex and 63)) and 1;
end;

class procedure TBigIntCore.SetBit(A: PBigIntLimb; Limbs, BitIndex: NativeUInt);
var
  I: NativeUInt;
begin
  I := BitIndex div 64;
  if I >= Limbs then raise ERangeError.Create('BitIndex');
  if A = nil then raise EArgumentNilException.Create('A');
  LimbAt(A, I)^ := LimbAt(A, I)^ or (UInt64(1) shl (BitIndex and 63));
end;

class procedure TBigIntCore.ImportBytes(Dst: PBigIntLimb; Limbs: NativeUInt; Src: Pointer; ByteCount: NativeUInt; Endian: TBigIntEndian);
var
  P: PByte;
  I, SrcIndex, LimbIndex, Shift: NativeUInt;
  B: Byte;
begin
  if (Dst = nil) and (Limbs <> 0) then raise EArgumentNilException.Create('Dst');
  if (Src = nil) and (ByteCount <> 0) then raise EArgumentNilException.Create('Src');
  if ByteCount > Limbs * 8 then raise ERangeError.Create('ByteCount');
  Zero(Dst, Limbs);
  if ByteCount = 0 then Exit;
  P := PByte(Src);
  for I := 0 to ByteCount - 1 do
  begin
    if Endian = bieLittleEndian then SrcIndex := I else SrcIndex := ByteCount - 1 - I;
    B := P[SrcIndex];
    LimbIndex := I div 8;
    Shift := (I and 7) * 8;
    LimbAt(Dst, LimbIndex)^ := LimbAt(Dst, LimbIndex)^ or (UInt64(B) shl Shift);
  end;
end;

class procedure TBigIntCore.ExportBytes(Src: PBigIntLimb; Limbs: NativeUInt; Dst: Pointer; ByteCount: NativeUInt; Endian: TBigIntEndian);
var
  P: PByte;
  I, DstIndex, LimbIndex, Shift: NativeUInt;
begin
  if (Src = nil) and (Limbs <> 0) then raise EArgumentNilException.Create('Src');
  if (Dst = nil) and (ByteCount <> 0) then raise EArgumentNilException.Create('Dst');
  if ByteCount > Limbs * 8 then raise ERangeError.Create('ByteCount');
  if ByteCount = 0 then Exit;
  P := PByte(Dst);
  for I := 0 to ByteCount - 1 do
  begin
    LimbIndex := I div 8;
    Shift := (I and 7) * 8;
    if Endian = bieLittleEndian then DstIndex := I else DstIndex := ByteCount - 1 - I;
    P[DstIndex] := Byte(LimbAt(Src, LimbIndex)^ shr Shift);
  end;
end;

class function TBigIntCore.FromHex(const Value: string; MinLimbs: NativeUInt): TBigIntLimbs;
var
  S: string;
  I, Nibbles, LimbCount, NibbleIndex, LimbIndex, Shift: NativeUInt;
  C: Char;
  V: UInt64;
begin
  S := Value.Trim;
  if S.StartsWith('0x', True) then Delete(S, 1, 2);
  if S = '' then S := '0';
  Nibbles := Length(S);
  LimbCount := (Nibbles + 15) div 16;
  if LimbCount < MinLimbs then LimbCount := MinLimbs;
  SetLength(Result, LimbCount);
  if LimbCount <> 0 then FillChar(Result[0], LimbCount * SizeOf(UInt64), 0);
  for I := 1 to Nibbles do
  begin
    C := S[Length(S) - Integer(I) + 1];
    case C of
      '0'..'9': V := Ord(C) - Ord('0');
      'a'..'f': V := Ord(C) - Ord('a') + 10;
      'A'..'F': V := Ord(C) - Ord('A') + 10;
    else
      raise EConvertError.Create('Invalid hex digit');
    end;
    NibbleIndex := I - 1;
    LimbIndex := NibbleIndex div 16;
    Shift := (NibbleIndex and 15) * 4;
    Result[LimbIndex] := Result[LimbIndex] or (V shl Shift);
  end;
end;

class function TBigIntCore.ToHex(A: PBigIntLimb; Limbs: NativeUInt; TrimLeadingZeroes: Boolean): string;
const
  Digits: array[0..15] of Char = ('0','1','2','3','4','5','6','7','8','9','A','B','C','D','E','F');
var
  I: NativeInt;
  J: Integer;
  V: UInt64;
  Started: Boolean;
begin
  if Limbs = 0 then Exit('0');
  if A = nil then raise EArgumentNilException.Create('A');
  Result := '';
  Started := not TrimLeadingZeroes;
  I := NativeInt(Limbs) - 1;
  while I >= 0 do
  begin
    V := LimbAt(A, NativeUInt(I))^;
    for J := 15 downto 0 do
    begin
      if not Started then
      begin
        if ((V shr (J * 4)) and $F) = 0 then Continue;
        Started := True;
      end;
      Result := Result + Digits[Integer((V shr (J * 4)) and $F)];
    end;
    Dec(I);
  end;
  if Result = '' then Result := '0';
end;

end.
