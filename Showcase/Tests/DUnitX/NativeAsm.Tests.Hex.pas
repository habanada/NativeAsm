{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
unit NativeAsm.Tests.Hex;

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  NativeAsm.CpuFeatures,
  NativeAsm.Algorithms.Hex;

type
  [TestFixture]
  THexTests = class
  private
    class function MakeData(Count: Integer): TBytes; static;
    class function BytesEqual(const A, B: TBytes): Boolean; static;
    procedure CheckMode(Mode: THexMode);
  public
    [Test] procedure ScalarMatchesReference;
    [Test] procedure Ssse3MatchesReferenceWhenAvailable;
    [Test] procedure AutoSelectsAvailableKernel;
    [Test] procedure LowercaseDecodeIsAccepted;
    [Test] procedure InvalidCharacterReportsExactIndex;
    [Test] procedure OddLengthIsRejected;
    [Test] procedure EmptyInputRoundTrips;
  end;

implementation

class function THexTests.MakeData(Count: Integer): TBytes;
var
  I: Integer;
begin
  SetLength(Result, Count);
  for I := 0 to High(Result) do Result[I] := Byte((I * 41 + 23) and $FF);
end;

class function THexTests.BytesEqual(const A, B: TBytes): Boolean;
var
  I: Integer;
begin
  if Length(A) <> Length(B) then Exit(False);
  for I := 0 to High(A) do if A[I] <> B[I] then Exit(False);
  Result := True;
end;

procedure THexTests.CheckMode(Mode: THexMode);
const
  Digits: array[0..15] of Byte = (Ord('0'), Ord('1'), Ord('2'), Ord('3'), Ord('4'), Ord('5'), Ord('6'), Ord('7'), Ord('8'), Ord('9'), Ord('A'), Ord('B'), Ord('C'), Ord('D'), Ord('E'), Ord('F'));
var
  Jit: THexJit;
  Data, Encoded, Decoded, Expected: TBytes;
  I, Len: Integer;
  InvalidIndex: NativeInt;
begin
  Jit := THexJit.Create(Mode);
  try
    for Len := 0 to 129 do
    begin
      Data := MakeData(Len);
      Encoded := Jit.Encode(Data);
      SetLength(Expected, Len * 2);
      for I := 0 to Len - 1 do
      begin
        Expected[I * 2] := Digits[Data[I] shr 4];
        Expected[I * 2 + 1] := Digits[Data[I] and $0F];
      end;
      Assert.IsTrue(BytesEqual(Encoded, Expected), 'encode len ' + IntToStr(Len));
      Assert.IsTrue(Jit.TryDecode(Encoded, Decoded, InvalidIndex), 'decode len ' + IntToStr(Len));
      Assert.IsTrue(InvalidIndex = -1, 'invalid index len ' + IntToStr(Len));
      Assert.IsTrue(BytesEqual(Decoded, Data), 'roundtrip len ' + IntToStr(Len));
    end;
  finally
    Jit.Free;
  end;
end;

procedure THexTests.ScalarMatchesReference;
begin
  CheckMode(hmScalar);
end;

procedure THexTests.Ssse3MatchesReferenceWhenAvailable;
begin
  if TCpuFeatures.Supports(cfSSSE3) then CheckMode(hmSsse3) else Assert.IsTrue(True);
end;

procedure THexTests.AutoSelectsAvailableKernel;
var
  Jit: THexJit;
begin
  Jit := THexJit.Create;
  try
    if TCpuFeatures.Supports(cfSSSE3) then Assert.IsTrue(Jit.Mode = hmSsse3) else Assert.IsTrue(Jit.Mode = hmScalar);
  finally
    Jit.Free;
  end;
end;

procedure THexTests.LowercaseDecodeIsAccepted;
var
  Jit: THexJit;
  Hex, Data: TBytes;
  InvalidIndex: NativeInt;
begin
  Hex := TEncoding.ASCII.GetBytes('0012abCDef89');
  Jit := THexJit.Create;
  try
    Assert.IsTrue(Jit.TryDecode(Hex, Data, InvalidIndex));
    Assert.IsTrue(Length(Data) = 6);
    Assert.IsTrue((Data[0] = $00) and (Data[1] = $12) and (Data[2] = $AB) and (Data[3] = $CD) and (Data[4] = $EF) and (Data[5] = $89));
  finally
    Jit.Free;
  end;
end;

procedure THexTests.InvalidCharacterReportsExactIndex;
var
  Jit: THexJit;
  Hex, Data: TBytes;
  I: Integer;
  InvalidIndex: NativeInt;
begin
  Jit := THexJit.Create;
  try
    for I := 0 to 39 do
    begin
      Hex := TEncoding.ASCII.GetBytes('00112233445566778899AABBCCDDEEFF00112233');
      Hex[I] := Ord('Z');
      Assert.IsTrue(not Jit.TryDecode(Hex, Data, InvalidIndex), 'index ' + IntToStr(I));
      Assert.IsTrue(InvalidIndex = I, 'reported index ' + IntToStr(I));
      Assert.IsTrue(Length(Data) = 0);
    end;
  finally
    Jit.Free;
  end;
end;

procedure THexTests.OddLengthIsRejected;
var
  Jit: THexJit;
  Hex, Data: TBytes;
  InvalidIndex: NativeInt;
begin
  Hex := TEncoding.ASCII.GetBytes('ABC');
  Jit := THexJit.Create;
  try
    Assert.IsTrue(not Jit.TryDecode(Hex, Data, InvalidIndex));
    Assert.IsTrue(InvalidIndex = 2);
    Assert.IsTrue(Length(Data) = 0);
  finally
    Jit.Free;
  end;
end;

procedure THexTests.EmptyInputRoundTrips;
var
  Jit: THexJit;
  A, B: TBytes;
  InvalidIndex: NativeInt;
begin
  SetLength(A, 0);
  Jit := THexJit.Create;
  try
    B := Jit.Encode(A);
    Assert.IsTrue(Length(B) = 0);
    Assert.IsTrue(Jit.TryDecode(B, A, InvalidIndex));
    Assert.IsTrue((Length(A) = 0) and (InvalidIndex = -1));
  finally
    Jit.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(THexTests);

end.
