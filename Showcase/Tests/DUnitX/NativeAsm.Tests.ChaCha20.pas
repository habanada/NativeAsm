{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
unit NativeAsm.Tests.ChaCha20;

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  NativeAsm.CpuFeatures,
  NativeAsm.Crypto.ChaCha20;

type
  [TestFixture]
  TChaCha20Tests = class
  private
    class function HexToBytes(const S: string): TBytes; static;
    class function BytesEqual(const A, B: TBytes): Boolean; static;
    class function MakeData(Count: Integer): TBytes; static;
    class procedure LoadKey(const S: string; out Key: TChaCha20Key); static;
    class procedure LoadNonce(const S: string; out Nonce: TChaCha20Nonce); static;
  public
    [Test] procedure RfcBlockVectorScalar;
    [Test] procedure RfcEncryptionVector;
    [Test] procedure Sse2MatchesScalarAcrossBoundaries;
    [Test] procedure InPlaceMatchesOutOfPlace;
    [Test] procedure UnalignedInputMatches;
    [Test] procedure CounterOverflowIsRejected;
    [Test] procedure AutoSelectsSse2;
  end;

implementation

class function TChaCha20Tests.HexToBytes(const S: string): TBytes;
var
  I: Integer;
begin
  Assert.IsTrue((Length(S) and 1) = 0);
  SetLength(Result, Length(S) div 2);
  for I := 0 to High(Result) do Result[I] := Byte(StrToInt('$' + Copy(S, I * 2 + 1, 2)));
end;

class function TChaCha20Tests.BytesEqual(const A, B: TBytes): Boolean;
var
  I: Integer;
begin
  if Length(A) <> Length(B) then Exit(False);
  for I := 0 to High(A) do if A[I] <> B[I] then Exit(False);
  Result := True;
end;

class function TChaCha20Tests.MakeData(Count: Integer): TBytes;
var
  I: Integer;
begin
  SetLength(Result, Count);
  for I := 0 to High(Result) do Result[I] := Byte((I * 97 + 31) and $FF);
end;

class procedure TChaCha20Tests.LoadKey(const S: string; out Key: TChaCha20Key);
var
  B: TBytes;
begin
  B := HexToBytes(S);
  Assert.IsTrue(Length(B) = SizeOf(Key));
  Move(B[0], Key[0], SizeOf(Key));
end;

class procedure TChaCha20Tests.LoadNonce(const S: string; out Nonce: TChaCha20Nonce);
var
  B: TBytes;
begin
  B := HexToBytes(S);
  Assert.IsTrue(Length(B) = SizeOf(Nonce));
  Move(B[0], Nonce[0], SizeOf(Nonce));
end;

procedure TChaCha20Tests.RfcBlockVectorScalar;
var
  Jit: TChaCha20Jit;
  Key: TChaCha20Key;
  Nonce: TChaCha20Nonce;
  Actual, Expected: TBytes;
begin
  LoadKey('000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f', Key);
  LoadNonce('000000090000004a00000000', Nonce);
  Expected := HexToBytes('10f1e7e4d13b5915500fdd1fa32071c4c7d1f4c733c068030422aa9ac3d46c4ed2826446079faa0914c2d705d98b02a2b5129cd1de164eb9cbd083e8a2503c4e');
  Jit := TChaCha20Jit.Create(ccmScalar);
  try
    Actual := Jit.Generate(64, Key, Nonce, 1);
    Assert.IsTrue(BytesEqual(Actual, Expected));
  finally
    Jit.Free;
  end;
end;

procedure TChaCha20Tests.RfcEncryptionVector;
var
  Jit: TChaCha20Jit;
  Key: TChaCha20Key;
  Nonce: TChaCha20Nonce;
  Plain, Actual, Expected: TBytes;
begin
  LoadKey('000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f', Key);
  LoadNonce('000000000000004a00000000', Nonce);
  Plain := TEncoding.ASCII.GetBytes('Ladies and Gentlemen of the class of ''99: If I could offer you only one tip for the future, sunscreen would be it.');
  Expected := HexToBytes('6e2e359a2568f98041ba0728dd0d6981e97e7aec1d4360c20a27afccfd9fae0bf91b65c5524733ab8f593dabcd62b3571639d624e65152ab8f530c359f0861d807ca0dbf500d6a6156a38e088a22b65e52bc514d16ccf806818ce91ab77937365af90bbf74a35be6b40b8eedf2785e42874d');
  Jit := TChaCha20Jit.Create(ccmAuto);
  try
    Actual := Jit.XorKeyStream(Plain, Key, Nonce, 1);
    Assert.IsTrue(BytesEqual(Actual, Expected));
  finally
    Jit.Free;
  end;
end;

procedure TChaCha20Tests.Sse2MatchesScalarAcrossBoundaries;
const
  Lengths: array[0..13] of Integer = (0, 1, 15, 16, 17, 63, 64, 65, 127, 128, 129, 1023, 1024, 4097);
var
  Scalar, Simd: TChaCha20Jit;
  Key: TChaCha20Key;
  Nonce: TChaCha20Nonce;
  Data, A, B: TBytes;
  I: Integer;
begin
  if not TCpuFeatures.Supports(cfSSE2) then Exit;
  LoadKey('00112233445566778899aabbccddeeff102132435465768798a9bacbdcedfe0f', Key);
  LoadNonce('102030405060708090a0b0c0', Nonce);
  Scalar := TChaCha20Jit.Create(ccmScalar);
  Simd := TChaCha20Jit.Create(ccmSse2);
  try
    for I := Low(Lengths) to High(Lengths) do
    begin
      Data := MakeData(Lengths[I]);
      A := Scalar.XorKeyStream(Data, Key, Nonce, 7);
      B := Simd.XorKeyStream(Data, Key, Nonce, 7);
      Assert.IsTrue(BytesEqual(A, B), 'Length ' + IntToStr(Lengths[I]));
    end;
  finally
    Simd.Free;
    Scalar.Free;
  end;
end;

procedure TChaCha20Tests.InPlaceMatchesOutOfPlace;
var
  Jit: TChaCha20Jit;
  Key: TChaCha20Key;
  Nonce: TChaCha20Nonce;
  Data, Expected: TBytes;
begin
  FillChar(Key, SizeOf(Key), $5A);
  FillChar(Nonce, SizeOf(Nonce), $A5);
  Data := MakeData(777);
  Jit := TChaCha20Jit.Create;
  try
    Expected := Jit.XorKeyStream(Data, Key, Nonce, 11);
    Jit.XorKeyStream(@Data[0], @Data[0], NativeUInt(Length(Data)), Key, Nonce, 11);
    Assert.IsTrue(BytesEqual(Data, Expected));
  finally
    Jit.Free;
  end;
end;

procedure TChaCha20Tests.UnalignedInputMatches;
var
  Jit: TChaCha20Jit;
  Key: TChaCha20Key;
  Nonce: TChaCha20Nonce;
  Raw, Expected, Actual: TBytes;
  I: Integer;
begin
  FillChar(Key, SizeOf(Key), $3C);
  FillChar(Nonce, SizeOf(Nonce), $C3);
  SetLength(Raw, 514);
  for I := 1 to 512 do Raw[I] := Byte((I * 13) and $FF);
  SetLength(Expected, 512);
  Move(Raw[1], Expected[0], 512);
  Jit := TChaCha20Jit.Create;
  try
    Expected := Jit.XorKeyStream(Expected, Key, Nonce, 2);
    SetLength(Actual, 513);
    Jit.XorKeyStream(@Raw[1], @Actual[1], 512, Key, Nonce, 2);
    Move(Actual[1], Actual[0], 512);
    SetLength(Actual, 512);
    Assert.IsTrue(BytesEqual(Actual, Expected));
  finally
    Jit.Free;
  end;
end;

procedure TChaCha20Tests.CounterOverflowIsRejected;
var
  Jit: TChaCha20Jit;
  Key: TChaCha20Key;
  Nonce: TChaCha20Nonce;
  Data: TBytes;
  Raised: Boolean;
begin
  FillChar(Key, SizeOf(Key), 0);
  FillChar(Nonce, SizeOf(Nonce), 0);
  SetLength(Data, 65);
  Jit := TChaCha20Jit.Create(ccmScalar);
  try
    Raised := False;
    try
      Jit.XorKeyStream(Data, Key, Nonce, High(Cardinal));
    except
      on E: ERangeError do Raised := True;
    end;
    Assert.IsTrue(Raised);
  finally
    Jit.Free;
  end;
end;

procedure TChaCha20Tests.AutoSelectsSse2;
var
  Jit: TChaCha20Jit;
begin
  Jit := TChaCha20Jit.Create;
  try
    if TCpuFeatures.Supports(cfSSE2) then Assert.IsTrue(Jit.Mode = ccmSse2) else Assert.IsTrue(Jit.Mode = ccmScalar);
  finally
    Jit.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TChaCha20Tests);

end.
