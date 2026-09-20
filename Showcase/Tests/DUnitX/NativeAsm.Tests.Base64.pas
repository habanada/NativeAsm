{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
unit NativeAsm.Tests.Base64;

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  NativeAsm.CpuFeatures,
  NativeAsm.Algorithms.Base64;

type
  [TestFixture]
  TBase64Tests = class
  private
    class function MakeData(Count: Integer): TBytes; static;
    class function ReferenceEncode(const Data: TBytes): TBytes; static;
    class function BytesEqual(const A, B: TBytes): Boolean; static;
    procedure CheckMode(Mode: TBase64Mode);
    procedure CheckInvalidIndices(Mode: TBase64Mode);
  public
    [Test] procedure ScalarMatchesReference;
    [Test] procedure Ssse3MatchesReferenceWhenAvailable;
    [Test] procedure AutoSelectsAvailableKernel;
    [Test] procedure RfcVectors;
    [Test] procedure InvalidCharacterReportsExactIndex;
    [Test] procedure InvalidPaddingAndCanonicalBitsAreRejected;
    [Test] procedure InvalidLengthIsRejected;
    [Test] procedure EmptyInputRoundTrips;
  end;

implementation

class function TBase64Tests.MakeData(Count: Integer): TBytes;
var
  I: Integer;
begin
  SetLength(Result, Count);
  for I := 0 to High(Result) do Result[I] := Byte((I * 73 + 29) and $FF);
end;

class function TBase64Tests.ReferenceEncode(const Data: TBytes): TBytes;
const
  Alphabet: AnsiString = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
var
  I, O, Count, Groups: Integer;
  B0, B1, B2: Byte;
begin
  Count := Length(Data);
  Groups := Count div 3;
  if (Count mod 3) <> 0 then Inc(Groups);
  SetLength(Result, Groups * 4);
  I := 0;
  O := 0;
  while I + 2 < Count do
  begin
    B0 := Data[I]; B1 := Data[I + 1]; B2 := Data[I + 2];
    Result[O] := Ord(Alphabet[(B0 shr 2) + 1]);
    Result[O + 1] := Ord(Alphabet[(((B0 and 3) shl 4) or (B1 shr 4)) + 1]);
    Result[O + 2] := Ord(Alphabet[(((B1 and $0F) shl 2) or (B2 shr 6)) + 1]);
    Result[O + 3] := Ord(Alphabet[(B2 and $3F) + 1]);
    Inc(I, 3); Inc(O, 4);
  end;
  if I < Count then
  begin
    B0 := Data[I];
    Result[O] := Ord(Alphabet[(B0 shr 2) + 1]);
    if I + 1 < Count then
    begin
      B1 := Data[I + 1];
      Result[O + 1] := Ord(Alphabet[(((B0 and 3) shl 4) or (B1 shr 4)) + 1]);
      Result[O + 2] := Ord(Alphabet[((B1 and $0F) shl 2) + 1]);
      Result[O + 3] := Ord('=');
    end
    else
    begin
      Result[O + 1] := Ord(Alphabet[((B0 and 3) shl 4) + 1]);
      Result[O + 2] := Ord('=');
      Result[O + 3] := Ord('=');
    end;
  end;
end;

class function TBase64Tests.BytesEqual(const A, B: TBytes): Boolean;
var
  I: Integer;
begin
  if Length(A) <> Length(B) then Exit(False);
  for I := 0 to High(A) do if A[I] <> B[I] then Exit(False);
  Result := True;
end;

procedure TBase64Tests.CheckMode(Mode: TBase64Mode);
var
  Jit: TBase64Jit;
  Data, Encoded, Expected, Decoded: TBytes;
  Len: Integer;
  InvalidIndex: NativeInt;
begin
  Jit := TBase64Jit.Create(Mode);
  try
    for Len := 0 to 257 do
    begin
      Data := MakeData(Len);
      Expected := ReferenceEncode(Data);
      Encoded := Jit.Encode(Data);
      Assert.IsTrue(BytesEqual(Encoded, Expected), 'encode len ' + IntToStr(Len));
      Assert.IsTrue(Jit.TryDecode(Encoded, Decoded, InvalidIndex), 'decode len ' + IntToStr(Len));
      Assert.IsTrue(InvalidIndex = -1, 'invalid index len ' + IntToStr(Len));
      Assert.IsTrue(BytesEqual(Decoded, Data), 'roundtrip len ' + IntToStr(Len));
    end;
  finally
    Jit.Free;
  end;
end;

procedure TBase64Tests.CheckInvalidIndices(Mode: TBase64Mode);
var
  Jit: TBase64Jit;
  Data, Encoded, Decoded: TBytes;
  I: Integer;
  InvalidIndex: NativeInt;
begin
  Data := MakeData(96);
  Jit := TBase64Jit.Create(Mode);
  try
    Encoded := Jit.Encode(Data);
    for I := 0 to High(Encoded) do
    begin
      Encoded[I] := Ord('!');
      Assert.IsTrue(not Jit.TryDecode(Encoded, Decoded, InvalidIndex), 'index ' + IntToStr(I));
      Assert.IsTrue(InvalidIndex = I, 'reported index ' + IntToStr(I));
      Encoded := Jit.Encode(Data);
    end;
  finally
    Jit.Free;
  end;
end;

procedure TBase64Tests.ScalarMatchesReference;
begin
  CheckMode(b64mScalar);
end;

procedure TBase64Tests.Ssse3MatchesReferenceWhenAvailable;
begin
  if TCpuFeatures.Supports(cfSSSE3) then CheckMode(b64mSsse3) else Assert.IsTrue(True);
end;

procedure TBase64Tests.AutoSelectsAvailableKernel;
var
  Jit: TBase64Jit;
begin
  Jit := TBase64Jit.Create;
  try
    if TCpuFeatures.Supports(cfSSSE3) then Assert.IsTrue(Jit.Mode = b64mSsse3) else Assert.IsTrue(Jit.Mode = b64mScalar);
  finally
    Jit.Free;
  end;
end;

procedure TBase64Tests.RfcVectors;
const
  Plain: array[0..6] of string = ('', 'f', 'fo', 'foo', 'foob', 'fooba', 'foobar');
  EncodedText: array[0..6] of string = ('', 'Zg==', 'Zm8=', 'Zm9v', 'Zm9vYg==', 'Zm9vYmE=', 'Zm9vYmFy');
var
  Jit: TBase64Jit;
  Data, Encoded, Decoded: TBytes;
  I: Integer;
  InvalidIndex: NativeInt;
begin
  Jit := TBase64Jit.Create(b64mScalar);
  try
    for I := 0 to High(Plain) do
    begin
      Data := TEncoding.ASCII.GetBytes(Plain[I]);
      Encoded := Jit.Encode(Data);
      Assert.IsTrue(BytesEqual(Encoded, TEncoding.ASCII.GetBytes(EncodedText[I])), Plain[I]);
      Assert.IsTrue(Jit.TryDecode(Encoded, Decoded, InvalidIndex));
      Assert.IsTrue(BytesEqual(Decoded, Data));
    end;
  finally
    Jit.Free;
  end;
end;

procedure TBase64Tests.InvalidCharacterReportsExactIndex;
begin
  CheckInvalidIndices(b64mScalar);
  if TCpuFeatures.Supports(cfSSSE3) then CheckInvalidIndices(b64mSsse3);
end;

procedure TBase64Tests.InvalidPaddingAndCanonicalBitsAreRejected;
var
  Jit: TBase64Jit;
  Text, Data: TBytes;
  InvalidIndex: NativeInt;

  procedure Check(const S: string; ExpectedIndex: NativeInt);
  begin
    Text := TEncoding.ASCII.GetBytes(S);
    Assert.IsTrue(not Jit.TryDecode(Text, Data, InvalidIndex), S);
    Assert.IsTrue(InvalidIndex = ExpectedIndex, S + ' index');
  end;

begin
  Jit := TBase64Jit.Create;
  try
    Check('AB==', 1);
    Check('AAF=', 2);
    Check('AA=A', 2);
    Check('A===', 1);
    Check('AAAA=AAA', 4);
    Check('AAAAAA=A', 6);
  finally
    Jit.Free;
  end;
end;

procedure TBase64Tests.InvalidLengthIsRejected;
var
  Jit: TBase64Jit;
  Text, Data: TBytes;
  InvalidIndex: NativeInt;
begin
  Text := TEncoding.ASCII.GetBytes('AAA');
  Jit := TBase64Jit.Create;
  try
    Assert.IsTrue(not Jit.TryDecode(Text, Data, InvalidIndex));
    Assert.IsTrue(InvalidIndex = 3);
  finally
    Jit.Free;
  end;
end;

procedure TBase64Tests.EmptyInputRoundTrips;
var
  Jit: TBase64Jit;
  A, B: TBytes;
  InvalidIndex: NativeInt;
begin
  SetLength(A, 0);
  Jit := TBase64Jit.Create;
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
  TDUnitX.RegisterTestFixture(TBase64Tests);

end.
