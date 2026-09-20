{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
unit NativeAsm.Tests.ChaCha20Poly1305;

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  NativeAsm.Crypto.ChaCha20,
  NativeAsm.Crypto.Poly1305,
  NativeAsm.Crypto.ChaCha20Poly1305;

type
  [TestFixture]
  TChaCha20Poly1305Tests = class
  private
    class function HexToBytes(const S: string): TBytes; static;
    class function BytesEqual(const A, B: TBytes): Boolean; static;
    class function TagHex(const Tag: TPoly1305Tag): string; static;
    class procedure LoadKey(const S: string; out Key: TChaCha20Key); static;
    class procedure LoadNonce(const S: string; out Nonce: TChaCha20Nonce); static;
  public
    [Test] procedure RfcAeadVector;
    [Test] procedure RoundTripAcrossBoundaries;
    [Test] procedure TamperedCiphertextIsRejectedWithoutPlaintext;
    [Test] procedure TamperedTagIsRejected;
    [Test] procedure TamperedAadIsRejected;
    [Test] procedure EmptyPlaintextAndAadRoundTrip;
  end;

implementation

class function TChaCha20Poly1305Tests.HexToBytes(const S: string): TBytes;
var
  I: Integer;
begin
  SetLength(Result, Length(S) div 2);
  for I := 0 to High(Result) do Result[I] := Byte(StrToInt('$' + Copy(S, I * 2 + 1, 2)));
end;

class function TChaCha20Poly1305Tests.BytesEqual(const A, B: TBytes): Boolean;
var
  I: Integer;
begin
  if Length(A) <> Length(B) then Exit(False);
  for I := 0 to High(A) do if A[I] <> B[I] then Exit(False);
  Result := True;
end;

class function TChaCha20Poly1305Tests.TagHex(const Tag: TPoly1305Tag): string;
const
  Digits: string = '0123456789abcdef';
var
  I: Integer;
begin
  SetLength(Result, 32);
  for I := 0 to 15 do
  begin
    Result[I * 2 + 1] := Digits[(Tag[I] shr 4) + 1];
    Result[I * 2 + 2] := Digits[(Tag[I] and $F) + 1];
  end;
end;

class procedure TChaCha20Poly1305Tests.LoadKey(const S: string; out Key: TChaCha20Key);
var
  B: TBytes;
begin
  B := HexToBytes(S);
  Assert.IsTrue(Length(B) = SizeOf(Key));
  Move(B[0], Key[0], SizeOf(Key));
end;

class procedure TChaCha20Poly1305Tests.LoadNonce(const S: string; out Nonce: TChaCha20Nonce);
var
  B: TBytes;
begin
  B := HexToBytes(S);
  Assert.IsTrue(Length(B) = SizeOf(Nonce));
  Move(B[0], Nonce[0], SizeOf(Nonce));
end;

procedure TChaCha20Poly1305Tests.RfcAeadVector;
var
  Aead: TChaCha20Poly1305Jit;
  Key: TChaCha20Key;
  Nonce: TChaCha20Nonce;
  Plain, AAD, Cipher, ExpectedCipher, Decrypted: TBytes;
  Tag, ExpectedTag: TPoly1305Tag;
  TagBytes: TBytes;
begin
  LoadKey('808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9f', Key);
  LoadNonce('070000004041424344454647', Nonce);
  AAD := HexToBytes('50515253c0c1c2c3c4c5c6c7');
  Plain := TEncoding.ASCII.GetBytes('Ladies and Gentlemen of the class of ''99: If I could offer you only one tip for the future, sunscreen would be it.');
  ExpectedCipher := HexToBytes('d31a8d34648e60db7b86afbc53ef7ec2a4aded51296e08fea9e2b5a736ee62d63dbea45e8ca9671282fafb69da92728b1a71de0a9e060b2905d6a5b67ecd3b3692ddbd7f2d778b8c9803aee328091b58fab324e4fad675945585808b4831d7bc3ff4def08e4b7a9de576d26586cec64b6116');
  TagBytes := HexToBytes('1ae10b594f09e26a7e902ecbd0600691');
  Move(TagBytes[0], ExpectedTag[0], SizeOf(ExpectedTag));
  Aead := TChaCha20Poly1305Jit.Create;
  try
    Cipher := Aead.Encrypt(Plain, AAD, Key, Nonce, Tag);
    Assert.IsTrue(BytesEqual(Cipher, ExpectedCipher));
    Assert.IsTrue(TagHex(Tag) = TagHex(ExpectedTag));
    Assert.IsTrue(Aead.Decrypt(Cipher, AAD, Key, Nonce, Tag, Decrypted));
    Assert.IsTrue(BytesEqual(Decrypted, Plain));
  finally
    Aead.Free;
  end;
end;

procedure TChaCha20Poly1305Tests.RoundTripAcrossBoundaries;
const
  Lengths: array[0..11] of Integer = (0, 1, 15, 16, 17, 63, 64, 65, 127, 128, 129, 1025);
var
  Aead: TChaCha20Poly1305Jit;
  Key: TChaCha20Key;
  Nonce: TChaCha20Nonce;
  Plain, AAD, Cipher, Decoded: TBytes;
  Tag: TPoly1305Tag;
  I, J: Integer;
begin
  for I := 0 to High(Key) do Key[I] := Byte(I * 5 + 1);
  for I := 0 to High(Nonce) do Nonce[I] := Byte(I * 11 + 7);
  SetLength(AAD, 37);
  for I := 0 to High(AAD) do AAD[I] := Byte(I * 17 + 3);
  Aead := TChaCha20Poly1305Jit.Create;
  try
    for J := Low(Lengths) to High(Lengths) do
    begin
      SetLength(Plain, Lengths[J]);
      for I := 0 to High(Plain) do Plain[I] := Byte((I * 29 + J) and $FF);
      Cipher := Aead.Encrypt(Plain, AAD, Key, Nonce, Tag);
      Assert.IsTrue(Aead.Decrypt(Cipher, AAD, Key, Nonce, Tag, Decoded), 'Length ' + IntToStr(Lengths[J]));
      Assert.IsTrue(BytesEqual(Plain, Decoded), 'Data ' + IntToStr(Lengths[J]));
    end;
  finally
    Aead.Free;
  end;
end;

procedure TChaCha20Poly1305Tests.TamperedCiphertextIsRejectedWithoutPlaintext;
var
  Aead: TChaCha20Poly1305Jit;
  Key: TChaCha20Key;
  Nonce: TChaCha20Nonce;
  Plain, AAD, Cipher, Decoded: TBytes;
  Tag: TPoly1305Tag;
begin
  FillChar(Key, SizeOf(Key), 1);
  FillChar(Nonce, SizeOf(Nonce), 2);
  Plain := TEncoding.ASCII.GetBytes('authenticated plaintext');
  AAD := TEncoding.ASCII.GetBytes('aad');
  Aead := TChaCha20Poly1305Jit.Create;
  try
    Cipher := Aead.Encrypt(Plain, AAD, Key, Nonce, Tag);
    Cipher[3] := Cipher[3] xor $40;
    Assert.IsTrue(not Aead.Decrypt(Cipher, AAD, Key, Nonce, Tag, Decoded));
    Assert.IsTrue(Length(Decoded) = 0);
  finally
    Aead.Free;
  end;
end;

procedure TChaCha20Poly1305Tests.TamperedTagIsRejected;
var
  Aead: TChaCha20Poly1305Jit;
  Key: TChaCha20Key;
  Nonce: TChaCha20Nonce;
  Plain, AAD, Cipher, Decoded: TBytes;
  Tag: TPoly1305Tag;
begin
  FillChar(Key, SizeOf(Key), 3);
  FillChar(Nonce, SizeOf(Nonce), 4);
  Plain := TEncoding.ASCII.GetBytes('message');
  SetLength(AAD, 0);
  Aead := TChaCha20Poly1305Jit.Create;
  try
    Cipher := Aead.Encrypt(Plain, AAD, Key, Nonce, Tag);
    Tag[15] := Tag[15] xor 1;
    Assert.IsTrue(not Aead.Decrypt(Cipher, AAD, Key, Nonce, Tag, Decoded));
  finally
    Aead.Free;
  end;
end;

procedure TChaCha20Poly1305Tests.TamperedAadIsRejected;
var
  Aead: TChaCha20Poly1305Jit;
  Key: TChaCha20Key;
  Nonce: TChaCha20Nonce;
  Plain, AAD, Cipher, Decoded: TBytes;
  Tag: TPoly1305Tag;
begin
  FillChar(Key, SizeOf(Key), 5);
  FillChar(Nonce, SizeOf(Nonce), 6);
  Plain := TEncoding.ASCII.GetBytes('message');
  AAD := TEncoding.ASCII.GetBytes('associated data');
  Aead := TChaCha20Poly1305Jit.Create;
  try
    Cipher := Aead.Encrypt(Plain, AAD, Key, Nonce, Tag);
    AAD[0] := AAD[0] xor 1;
    Assert.IsTrue(not Aead.Decrypt(Cipher, AAD, Key, Nonce, Tag, Decoded));
    Assert.IsTrue(Length(Decoded) = 0);
  finally
    Aead.Free;
  end;
end;

procedure TChaCha20Poly1305Tests.EmptyPlaintextAndAadRoundTrip;
var
  Aead: TChaCha20Poly1305Jit;
  Key: TChaCha20Key;
  Nonce: TChaCha20Nonce;
  Plain, AAD, Cipher, Decoded: TBytes;
  Tag: TPoly1305Tag;
begin
  FillChar(Key, SizeOf(Key), 0);
  FillChar(Nonce, SizeOf(Nonce), 0);
  SetLength(Plain, 0);
  SetLength(AAD, 0);
  Aead := TChaCha20Poly1305Jit.Create;
  try
    Cipher := Aead.Encrypt(Plain, AAD, Key, Nonce, Tag);
    Assert.IsTrue(Length(Cipher) = 0);
    Assert.IsTrue(Aead.Decrypt(Cipher, AAD, Key, Nonce, Tag, Decoded));
    Assert.IsTrue(Length(Decoded) = 0);
  finally
    Aead.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TChaCha20Poly1305Tests);

end.
