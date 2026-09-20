{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
unit NativeAsm.Tests.Ecc.Common;

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  NativeAsm.BigInt.Types,
  NativeAsm.Ecc.Types;

type
  TEccTestUtil = class sealed
  public
    class function UInt256(const S: string): TUInt256; static;
    class function HexBytes(const S: string): TBytes; static;
    class function X25519Bytes(const S: string): TX25519Bytes; static;
    class function ToHex(const V: TUInt256): string; static;
    class function BytesToHex(const V: TBytes): string; static;
    class function X25519ToHex(const V: TX25519Bytes): string; static;
    class procedure AssertUInt256(const Expected: string; const Actual: TUInt256; const Msg: string = ''); static;
    class procedure AssertPoint(const X, Y: string; const Actual: TEccAffinePoint256; const Msg: string = ''); static;
    class procedure AssertBytes(const Expected: string; const Actual: TBytes; const Msg: string = ''); static;
    class procedure AssertX25519(const Expected: string; const Actual: TX25519Bytes; const Msg: string = ''); static;
  end;

implementation

class function TEccTestUtil.UInt256(const S: string): TUInt256;
var
  T: string;
  I, NibbleIndex, LimbIndex, Shift: Integer;
  C: Char;
  V: UInt64;
begin
  FillChar(Result, SizeOf(Result), 0); T := Trim(S);
  if (Length(T) >= 2) and (T[1] = '0') and ((T[2] = 'x') or (T[2] = 'X')) then Delete(T, 1, 2);
  if T = '' then T := '0';
  if Length(T) > 64 then raise ERangeError.Create('UInt256');
  for I := 1 to Length(T) do
  begin
    C := T[Length(T) - I + 1];
    case C of
      '0'..'9': V := Ord(C) - Ord('0');
      'a'..'f': V := Ord(C) - Ord('a') + 10;
      'A'..'F': V := Ord(C) - Ord('A') + 10;
    else
      raise EConvertError.Create('Hex');
    end;
    NibbleIndex := I - 1; LimbIndex := NibbleIndex div 16; Shift := (NibbleIndex and 15) * 4;
    Result.Limbs[LimbIndex] := Result.Limbs[LimbIndex] or (V shl Shift);
  end;
end;

class function TEccTestUtil.HexBytes(const S: string): TBytes;
var
  I: Integer;
begin
  if (Length(S) and 1) <> 0 then raise EConvertError.Create('Hex'); SetLength(Result, Length(S) div 2); for I := 0 to High(Result) do Result[I] := Byte(StrToInt('$' + Copy(S, I * 2 + 1, 2)));
end;

class function TEccTestUtil.X25519Bytes(const S: string): TX25519Bytes;
var
  B: TBytes;
begin
  B := HexBytes(S); if Length(B) <> 32 then raise ERangeError.Create('X25519'); Move(B[0], Result[0], 32);
end;

class function TEccTestUtil.ToHex(const V: TUInt256): string;
var
  I: Integer;
begin
  Result := ''; for I := High(V.Limbs) downto Low(V.Limbs) do Result := Result + IntToHex(V.Limbs[I], 16);
end;

class function TEccTestUtil.BytesToHex(const V: TBytes): string;
var
  I: Integer;
begin
  Result := ''; for I := 0 to High(V) do Result := Result + IntToHex(V[I], 2);
end;

class function TEccTestUtil.X25519ToHex(const V: TX25519Bytes): string;
var
  I: Integer;
begin
  Result := ''; for I := 0 to 31 do Result := Result + IntToHex(V[I], 2);
end;

class procedure TEccTestUtil.AssertUInt256(const Expected: string; const Actual: TUInt256; const Msg: string);
begin
  Assert.AreEqual(UpperCase(Expected), ToHex(Actual), Msg);
end;

class procedure TEccTestUtil.AssertPoint(const X, Y: string; const Actual: TEccAffinePoint256; const Msg: string);
begin
  Assert.IsFalse(Actual.Infinity, Msg + ' infinity'); AssertUInt256(X, Actual.X, Msg + ' x'); AssertUInt256(Y, Actual.Y, Msg + ' y');
end;

class procedure TEccTestUtil.AssertBytes(const Expected: string; const Actual: TBytes; const Msg: string);
begin
  Assert.AreEqual(UpperCase(Expected), BytesToHex(Actual), Msg);
end;

class procedure TEccTestUtil.AssertX25519(const Expected: string; const Actual: TX25519Bytes; const Msg: string);
begin
  Assert.AreEqual(UpperCase(Expected), X25519ToHex(Actual), Msg);
end;

end.
