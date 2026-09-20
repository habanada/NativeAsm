{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
unit NativeAsm.Benchmark.SelfTest;

interface

procedure RunNativeAsmSelfTests;

implementation

uses
  System.SysUtils,
  NativeAsm.CpuFeatures,
  NativeAsm.Algorithms.Crc32,
  NativeAsm.Algorithms.Crc32C,
  NativeAsm.Algorithms.Hash64,
  NativeAsm.Algorithms.Base64,
  NativeAsm.Algorithms.Hex,
  NativeAsm.Algorithms.BloomFilter,
  NativeAsm.Crypto.ChaCha20,
  NativeAsm.Crypto.Poly1305,
  NativeAsm.Crypto.ChaCha20Poly1305,
  NativeAsm.Crypto.Blake3,
  NativeAsm.Random.Xoshiro256pp,
  NativeAsm.BigInt.Types,
  NativeAsm.BigInt.Core,
  NativeAsm.BigInt.Jit,
  NativeAsm.BigInt.Montgomery,
  NativeAsm.BigInt.Fields;

type
  TSelfTestProc = reference to procedure;

var
  GPassed: Integer;
  GFailed: Integer;

procedure Require(Value: Boolean; const MessageText: string);
begin
  if not Value then raise Exception.Create(MessageText);
end;

function HexToBytes(const S: string): TBytes;
var
  I: Integer;
begin
  Require((Length(S) and 1) = 0, 'odd hex length');
  SetLength(Result, Length(S) div 2);
  for I := 0 to High(Result) do Result[I] := Byte(StrToInt('$' + Copy(S, I * 2 + 1, 2)));
end;

function BytesEqual(const A, B: TBytes): Boolean;
var
  I: Integer;
begin
  if Length(A) <> Length(B) then Exit(False);
  for I := 0 to High(A) do if A[I] <> B[I] then Exit(False);
  Result := True;
end;

function MakeData(Count: Integer; Seed: Cardinal): TBytes;
var
  I: Integer;
  X: Cardinal;
begin
  SetLength(Result, Count);
  X := Seed;
  for I := 0 to High(Result) do
  begin
    X := X * 1664525 + 1013904223;
    Result[I] := Byte(X shr 24);
  end;
end;

function DigestHex(const D: TBlake3Digest): string;
const
  Digits: string = '0123456789abcdef';
var
  I: Integer;
begin
  SetLength(Result, 64);
  for I := 0 to 31 do
  begin
    Result[I * 2 + 1] := Digits[(D[I] shr 4) + 1];
    Result[I * 2 + 2] := Digits[(D[I] and $F) + 1];
  end;
end;

function TagHex(const Tag: TPoly1305Tag): string;
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

procedure LoadChaChaKey(const S: string; out Key: TChaCha20Key);
var
  B: TBytes;
begin
  B := HexToBytes(S);
  Require(Length(B) = SizeOf(Key), 'ChaCha20 key length');
  Move(B[0], Key[0], SizeOf(Key));
end;

procedure LoadChaChaNonce(const S: string; out Nonce: TChaCha20Nonce);
var
  B: TBytes;
begin
  B := HexToBytes(S);
  Require(Length(B) = SizeOf(Nonce), 'ChaCha20 nonce length');
  Move(B[0], Nonce[0], SizeOf(Nonce));
end;

procedure LoadPolyKey(const S: string; out Key: TPoly1305Key);
var
  B: TBytes;
begin
  B := HexToBytes(S);
  Require(Length(B) = SizeOf(Key), 'Poly1305 key length');
  Move(B[0], Key[0], SizeOf(Key));
end;

procedure RunCase(const Name: string; const Proc: TSelfTestProc);
begin
  try
    Proc;
    Inc(GPassed);
    Writeln('[OK]   ', Name);
  except
    on E: Exception do
    begin
      Inc(GFailed);
      Writeln('[FAIL] ', Name, ': ', E.Message);
    end;
  end;
end;

procedure TestCrcVectors;
var
  Data: TBytes;
  C32: TCrc32Jit;
  C32C: TCrc32CJit;
begin
  Data := TEncoding.ASCII.GetBytes('123456789');
  C32 := TCrc32Jit.Create(crc32mScalar);
  try
    Require(C32.Compute(Data) = Cardinal($CBF43926), 'CRC32 IEEE vector');
  finally
    C32.Free;
  end;
  C32 := TCrc32Jit.Create(crc32mAuto);
  try
    Require(C32.Compute(Data) = Cardinal($CBF43926), 'CRC32 auto vector');
  finally
    C32.Free;
  end;
  if TCrc32Jit.IsPclmulAvailable then
  begin
    C32 := TCrc32Jit.Create(crc32mPclmul);
    try
      Require(C32.Compute(Data) = Cardinal($CBF43926), 'CRC32 PCLMUL vector');
    finally
      C32.Free;
    end;
  end;
  C32C := TCrc32CJit.Create(cmScalar);
  try
    Require(C32C.Compute(Data) = Cardinal($E3069283), 'CRC32C Castagnoli vector');
  finally
    C32C.Free;
  end;
  C32C := TCrc32CJit.Create(cmAuto);
  try
    Require(C32C.Compute(Data) = Cardinal($E3069283), 'CRC32C auto vector');
  finally
    C32C.Free;
  end;
  if TCrc32CJit.IsSse42Available then
  begin
    C32C := TCrc32CJit.Create(cmSse42);
    try
      Require(C32C.Compute(Data) = Cardinal($E3069283), 'CRC32C SSE4.2 vector');
    finally
      C32C.Free;
    end;
  end;
end;

procedure TestCrcStreamingAndUnaligned;
const
  Splits: array[0..7] of Integer = (1, 15, 16, 17, 63, 64, 1024, 2048);
var
  Data, Raw: TBytes;
  C32: TCrc32Jit;
  C32C: TCrc32CJit;
  Expected32, Actual32, Expected32C, Actual32C: Cardinal;
  I, Split: Integer;
begin
  Data := MakeData(4097, 111);
  SetLength(Raw, Length(Data) + 3);
  Move(Data[0], Raw[1], Length(Data));
  C32 := TCrc32Jit.Create(crc32mAuto);
  C32C := TCrc32CJit.Create(cmAuto);
  try
    Expected32 := C32.Compute(Data);
    Expected32C := C32C.Compute(Data);
    Require(C32.Compute(@Raw[1], Length(Data)) = Expected32, 'CRC32 unaligned');
    Require(C32C.Compute(@Raw[1], Length(Data)) = Expected32C, 'CRC32C unaligned');
    for I := Low(Splits) to High(Splits) do
    begin
      Split := Splits[I];
      Actual32 := C32.Compute(@Data[0], Split);
      Actual32 := C32.Compute(@Data[Split], Length(Data) - Split, Actual32);
      Require(Actual32 = Expected32, 'CRC32 streaming split ' + IntToStr(Split));
      Actual32C := C32C.Compute(@Data[0], Split);
      Actual32C := C32C.Compute(@Data[Split], Length(Data) - Split, Actual32C);
      Require(Actual32C = Expected32C, 'CRC32C streaming split ' + IntToStr(Split));
    end;
  finally
    C32C.Free;
    C32.Free;
  end;
end;

procedure TestFnv1a;
var
  Jit: THash64Jit;
  Data: TBytes;
  A, B: UInt64;
begin
  Jit := THash64Jit.Create;
  try
    Require(Jit.Hash(nil, 0) = UInt64($CBF29CE484222325), 'FNV-1a empty');
    Require(Jit.Hash(TEncoding.ASCII.GetBytes('a')) = UInt64($AF63DC4C8601EC8C), 'FNV-1a a');
    Require(Jit.Hash(TEncoding.ASCII.GetBytes('foobar')) = UInt64($85944171F73967E8), 'FNV-1a foobar');
    Data := MakeData(4097, 123);
    A := Jit.Hash(Data);
    B := Jit.Hash(@Data[0], 1024);
    B := Jit.Hash(@Data[1024], Length(Data) - 1024, B);
    Require(A = B, 'FNV-1a streaming');
  finally
    Jit.Free;
  end;
end;

procedure TestBase64;
const
  Plain: array[0..6] of string = ('', 'f', 'fo', 'foo', 'foob', 'fooba', 'foobar');
  EncodedText: array[0..6] of string = ('', 'Zg==', 'Zm8=', 'Zm9v', 'Zm9vYg==', 'Zm9vYmE=', 'Zm9vYmFy');
var
  Jit: TBase64Jit;
  Data, Encoded, Decoded: TBytes;
  InvalidIndex: NativeInt;

  procedure CheckMode(Mode: TBase64Mode);
  var
    I: Integer;
  begin
    Jit := TBase64Jit.Create(Mode);
    try
      for I := 0 to High(Plain) do
      begin
        Data := TEncoding.ASCII.GetBytes(Plain[I]);
        Encoded := Jit.Encode(Data);
        Require(BytesEqual(Encoded, TEncoding.ASCII.GetBytes(EncodedText[I])), 'Base64 encode ' + Plain[I]);
        Require(Jit.TryDecode(Encoded, Decoded, InvalidIndex), 'Base64 decode ' + Plain[I]);
        Require((InvalidIndex = -1) and BytesEqual(Data, Decoded), 'Base64 roundtrip ' + Plain[I]);
      end;
      Require(not Jit.TryDecode(TEncoding.ASCII.GetBytes('A#=='), Decoded, InvalidIndex), 'Base64 invalid alphabet');
      Require(not Jit.TryDecode(TEncoding.ASCII.GetBytes('ABC'), Decoded, InvalidIndex), 'Base64 invalid length');
      Require(not Jit.TryDecode(TEncoding.ASCII.GetBytes('AB=='), Decoded, InvalidIndex), 'Base64 noncanonical two-pad bits');
      Require(not Jit.TryDecode(TEncoding.ASCII.GetBytes('AAF='), Decoded, InvalidIndex), 'Base64 noncanonical one-pad bits');
    finally
      Jit.Free;
    end;
  end;

begin
  CheckMode(b64mScalar);
  if TCpuFeatures.Supports(cfSSSE3) then CheckMode(b64mSsse3);
  CheckMode(b64mAuto);
end;

procedure TestBase64CrossMode;
const
  Lengths: array[0..10] of Integer = (0, 1, 2, 3, 15, 16, 17, 31, 32, 33, 4097);
var
  Scalar, Simd: TBase64Jit;
  Data, A, B, Decoded: TBytes;
  InvalidIndex: NativeInt;
  I: Integer;
begin
  if not TCpuFeatures.Supports(cfSSSE3) then Exit;
  Scalar := TBase64Jit.Create(b64mScalar);
  Simd := TBase64Jit.Create(b64mSsse3);
  try
    for I := Low(Lengths) to High(Lengths) do
    begin
      Data := MakeData(Lengths[I], Cardinal(200 + I));
      A := Scalar.Encode(Data);
      B := Simd.Encode(Data);
      Require(BytesEqual(A, B), 'Base64 SIMD encode length ' + IntToStr(Lengths[I]));
      Require(Simd.TryDecode(B, Decoded, InvalidIndex), 'Base64 SIMD decode length ' + IntToStr(Lengths[I]));
      Require(BytesEqual(Data, Decoded), 'Base64 SIMD roundtrip length ' + IntToStr(Lengths[I]));
    end;
  finally
    Simd.Free;
    Scalar.Free;
  end;
end;

procedure TestHex;
var
  Data, Encoded, Decoded: TBytes;
  Jit: THexJit;
  InvalidIndex: NativeInt;

  procedure CheckMode(Mode: THexMode);
  begin
    Jit := THexJit.Create(Mode);
    try
      Data := HexToBytes('0012abcdef89');
      Encoded := Jit.Encode(Data);
      Require(BytesEqual(Encoded, TEncoding.ASCII.GetBytes('0012ABCDEF89')), 'Hex encode');
      Require(Jit.TryDecode(TEncoding.ASCII.GetBytes('0012abCDef89'), Decoded, InvalidIndex), 'Hex decode');
      Require((InvalidIndex = -1) and BytesEqual(Decoded, Data), 'Hex roundtrip');
      Require(not Jit.TryDecode(TEncoding.ASCII.GetBytes('0G'), Decoded, InvalidIndex), 'Hex invalid alphabet');
      Require(InvalidIndex = 1, 'Hex invalid index');
      Require(not Jit.TryDecode(TEncoding.ASCII.GetBytes('ABC'), Decoded, InvalidIndex), 'Hex odd length');
    finally
      Jit.Free;
    end;
  end;

begin
  CheckMode(hmScalar);
  if TCpuFeatures.Supports(cfSSSE3) then CheckMode(hmSsse3);
  CheckMode(hmAuto);
end;

procedure TestBloom;
const
  ItemCount = 4096;
  ItemSize = 16;
var
  Filter: TBloomFilter;
  Data: TBytes;
  I: Integer;
begin
  Data := MakeData(ItemCount * ItemSize, 611);
  Filter := TBloomFilter.Create(1 shl 20, 7);
  try
    for I := 0 to ItemCount - 1 do Filter.Add(@Data[I * ItemSize], ItemSize);
    for I := 0 to ItemCount - 1 do Require(Filter.Contains(@Data[I * ItemSize], ItemSize), 'Bloom false negative ' + IntToStr(I));
    Filter.Clear;
    Require(not Filter.Contains(@Data[0], ItemSize), 'Bloom clear');
  finally
    Filter.Free;
  end;
end;

procedure TestChaCha20Rfc;
var
  Jit: TChaCha20Jit;
  Key: TChaCha20Key;
  Nonce: TChaCha20Nonce;
  Plain, Actual, Expected: TBytes;

  procedure CheckMode(Mode: TChaCha20Mode);
  begin
    Jit := TChaCha20Jit.Create(Mode);
    try
      LoadChaChaNonce('000000090000004a00000000', Nonce);
      Expected := HexToBytes('10f1e7e4d13b5915500fdd1fa32071c4c7d1f4c733c068030422aa9ac3d46c4ed2826446079faa0914c2d705d98b02a2b5129cd1de164eb9cbd083e8a2503c4e');
      Actual := Jit.Generate(64, Key, Nonce, 1);
      Require(BytesEqual(Actual, Expected), 'ChaCha20 block vector');
      LoadChaChaNonce('000000000000004a00000000', Nonce);
      Plain := TEncoding.ASCII.GetBytes('Ladies and Gentlemen of the class of ''99: If I could offer you only one tip for the future, sunscreen would be it.');
      Expected := HexToBytes('6e2e359a2568f98041ba0728dd0d6981e97e7aec1d4360c20a27afccfd9fae0bf91b65c5524733ab8f593dabcd62b3571639d624e65152ab8f530c359f0861d807ca0dbf500d6a6156a38e088a22b65e52bc514d16ccf806818ce91ab77937365af90bbf74a35be6b40b8eedf2785e42874d');
      Actual := Jit.XorKeyStream(Plain, Key, Nonce, 1);
      Require(BytesEqual(Actual, Expected), 'ChaCha20 cipher vector');
    finally
      Jit.Free;
    end;
  end;

begin
  LoadChaChaKey('000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f', Key);
  CheckMode(ccmScalar);
  if TCpuFeatures.Supports(cfSSE2) then CheckMode(ccmSse2);
  CheckMode(ccmAuto);
end;

procedure TestChaCha20Boundaries;
const
  Lengths: array[0..13] of Integer = (0, 1, 15, 16, 17, 63, 64, 65, 127, 128, 129, 1023, 1024, 4097);
var
  Scalar, Fast: TChaCha20Jit;
  Key: TChaCha20Key;
  Nonce: TChaCha20Nonce;
  Data, A, B, InPlace, Raw, Unaligned: TBytes;
  I, J: Integer;
  Raised: Boolean;
begin
  for I := 0 to High(Key) do Key[I] := Byte(I * 5 + 3);
  for I := 0 to High(Nonce) do Nonce[I] := Byte(I * 7 + 9);
  Scalar := TChaCha20Jit.Create(ccmScalar);
  if TCpuFeatures.Supports(cfSSE2) then Fast := TChaCha20Jit.Create(ccmSse2) else Fast := TChaCha20Jit.Create(ccmAuto);
  try
    for J := Low(Lengths) to High(Lengths) do
    begin
      Data := MakeData(Lengths[J], Cardinal(300 + J));
      A := Scalar.XorKeyStream(Data, Key, Nonce, 7);
      B := Fast.XorKeyStream(Data, Key, Nonce, 7);
      Require(BytesEqual(A, B), 'ChaCha20 mode match length ' + IntToStr(Lengths[J]));
    end;
    Data := MakeData(777, 333);
    A := Fast.XorKeyStream(Data, Key, Nonce, 11);
    SetLength(InPlace, Length(Data));
    Move(Data[0], InPlace[0], Length(Data));
    Fast.XorKeyStream(@InPlace[0], @InPlace[0], Length(InPlace), Key, Nonce, 11);
    Require(BytesEqual(A, InPlace), 'ChaCha20 in-place');
    Data := MakeData(512, 334);
    A := Fast.XorKeyStream(Data, Key, Nonce, 2);
    SetLength(Raw, Length(Data) + 2);
    SetLength(Unaligned, Length(Data) + 2);
    Move(Data[0], Raw[1], Length(Data));
    Fast.XorKeyStream(@Raw[1], @Unaligned[1], Length(Data), Key, Nonce, 2);
    for I := 0 to High(Data) do Require(Unaligned[I + 1] = A[I], 'ChaCha20 unaligned index ' + IntToStr(I));
    SetLength(Data, 65);
    Raised := False;
    try
      Fast.XorKeyStream(Data, Key, Nonce, High(Cardinal));
    except
      on E: ERangeError do Raised := True;
    end;
    Require(Raised, 'ChaCha20 counter overflow');
  finally
    Fast.Free;
    Scalar.Free;
  end;
end;

procedure TestPoly1305;
var
  Jit: TPoly1305Jit;
  Key: TPoly1305Key;
  Data: TBytes;
  A, B: TPoly1305Tag;
  State: TPoly1305State;
begin
  LoadPolyKey('85d6be7857556d337f4452fe42d506a80103808afb0db2fd4abff6af4149f51b', Key);
  Data := TEncoding.ASCII.GetBytes('Cryptographic Forum Research Group');
  Jit := TPoly1305Jit.Create;
  try
    A := Jit.Compute(Data, Key);
    Require(TagHex(A) = 'a8061dc1305136c6c22b8baf0c0127a9', 'Poly1305 RFC vector');
    Data := MakeData(4097, 444);
    FillChar(State, SizeOf(State), 0);
    Jit.Init(State, Key);
    Jit.Update(State, @Data[0], 1);
    Jit.Update(State, @Data[1], 15);
    Jit.Update(State, @Data[16], 17);
    Jit.Update(State, @Data[33], 1024);
    Jit.Update(State, @Data[1057], Length(Data) - 1057);
    Jit.Final(State, B);
    A := Jit.Compute(Data, Key);
    Require(TPoly1305Jit.EqualTags(A, B), 'Poly1305 streaming');
    B[9] := B[9] xor $80;
    Require(not TPoly1305Jit.EqualTags(A, B), 'Poly1305 tag mismatch');
  finally
    FillChar(State, SizeOf(State), 0);
    Jit.Free;
  end;
end;

procedure TestAead;
var
  Aead: TChaCha20Poly1305Jit;
  Key: TChaCha20Key;
  Nonce: TChaCha20Nonce;
  Plain, AAD, Cipher, ExpectedCipher, Decrypted: TBytes;
  Tag: TPoly1305Tag;
begin
  LoadChaChaKey('808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9f', Key);
  LoadChaChaNonce('070000004041424344454647', Nonce);
  AAD := HexToBytes('50515253c0c1c2c3c4c5c6c7');
  Plain := TEncoding.ASCII.GetBytes('Ladies and Gentlemen of the class of ''99: If I could offer you only one tip for the future, sunscreen would be it.');
  ExpectedCipher := HexToBytes('d31a8d34648e60db7b86afbc53ef7ec2a4aded51296e08fea9e2b5a736ee62d63dbea45e8ca9671282fafb69da92728b1a71de0a9e060b2905d6a5b67ecd3b3692ddbd7f2d778b8c9803aee328091b58fab324e4fad675945585808b4831d7bc3ff4def08e4b7a9de576d26586cec64b6116');
  Aead := TChaCha20Poly1305Jit.Create;
  try
    Cipher := Aead.Encrypt(Plain, AAD, Key, Nonce, Tag);
    Require(BytesEqual(Cipher, ExpectedCipher), 'AEAD ciphertext');
    Require(TagHex(Tag) = '1ae10b594f09e26a7e902ecbd0600691', 'AEAD tag');
    Require(Aead.Decrypt(Cipher, AAD, Key, Nonce, Tag, Decrypted), 'AEAD decrypt');
    Require(BytesEqual(Plain, Decrypted), 'AEAD plaintext');
    Cipher[3] := Cipher[3] xor $40;
    Require(not Aead.Decrypt(Cipher, AAD, Key, Nonce, Tag, Decrypted), 'AEAD ciphertext tamper');
    Require(Length(Decrypted) = 0, 'AEAD plaintext on ciphertext failure');
    Cipher[3] := Cipher[3] xor $40;
    AAD[0] := AAD[0] xor 1;
    Require(not Aead.Decrypt(Cipher, AAD, Key, Nonce, Tag, Decrypted), 'AEAD AAD tamper');
    Require(Length(Decrypted) = 0, 'AEAD plaintext on AAD failure');
    AAD[0] := AAD[0] xor 1;
    Tag[0] := Tag[0] xor 1;
    Require(not Aead.Decrypt(Cipher, AAD, Key, Nonce, Tag, Decrypted), 'AEAD tag tamper');
    Require(Length(Decrypted) = 0, 'AEAD plaintext on tag failure');
  finally
    Aead.Free;
  end;
end;

procedure TestBlake3Official;
type
  TVector = record
    Len: Integer;
    Hash: string;
  end;
const
  Vectors: array[0..13] of TVector = (
    (Len: 0; Hash: 'af1349b9f5f9a1a6a0404dea36dcc9499bcb25c9adc112b7cc9a93cae41f3262'),
    (Len: 1; Hash: '2d3adedff11b61f14c886e35afa036736dcd87a74d27b5c1510225d0f592e213'),
    (Len: 63; Hash: 'e9bc37a594daad83be9470df7f7b3798297c3d834ce80ba85d6e207627b7db7b'),
    (Len: 64; Hash: '4eed7141ea4a5cd4b788606bd23f46e212af9cacebacdc7d1f4c6dc7f2511b98'),
    (Len: 65; Hash: 'de1e5fa0be70df6d2be8fffd0e99ceaa8eb6e8c93a63f2d8d1c30ecb6b263dee'),
    (Len: 1023; Hash: '10108970eeda3eb932baac1428c7a2163b0e924c9a9e25b35bba72b28f70bd11'),
    (Len: 1024; Hash: '42214739f095a406f3fc83deb889744ac00df831c10daa55189b5d121c855af7'),
    (Len: 1025; Hash: 'd00278ae47eb27b34faecf67b4fe263f82d5412916c1ffd97c8cb7fb814b8444'),
    (Len: 2048; Hash: 'e776b6028c7cd22a4d0ba182a8bf62205d2ef576467e838ed6f2529b85fba24a'),
    (Len: 4096; Hash: '015094013f57a5277b59d8475c0501042c0b642e531b0a1c8f58d2163229e969'),
    (Len: 4097; Hash: '9b4052b38f1c5fc8b1f9ff7ac7b27cd242487b3d890d15c96a1c25b8aa0fb995'),
    (Len: 8192; Hash: 'aae792484c8efe4f19e2ca7d371d8c467ffb10748d8a5a1ae579948f718a2a63'),
    (Len: 8193; Hash: 'bab6c09cb8ce8cf459261398d2e7aef35700bf488116ceb94a36d0f5f1b7bc3b'),
    (Len: 16384; Hash: 'f875d6646de28985646f34ee13be9a576fd515f76b5b0a26bb324735041ddde4')
  );
var
  Data: TBytes;
  Jit: TBlake3Jit;
  D: TBlake3Digest;

  procedure CheckMode(Mode: TBlake3Mode);
  var
    I, J: Integer;
  begin
    Jit := TBlake3Jit.Create(Mode);
    try
      for I := Low(Vectors) to High(Vectors) do
      begin
        SetLength(Data, Vectors[I].Len);
        for J := 0 to High(Data) do Data[J] := Byte(J mod 251);
        if Length(Data) = 0 then D := Jit.Compute(nil, 0) else D := Jit.Compute(@Data[0], NativeUInt(Length(Data)));
        Require(DigestHex(D) = Vectors[I].Hash, 'BLAKE3 len ' + IntToStr(Vectors[I].Len));
      end;
    finally
      Jit.Free;
    end;
  end;

begin
  CheckMode(b3mScalar);
  if TBlake3Jit.IsSse2Available then CheckMode(b3mSse2);
  if TBlake3Jit.IsSsse3Available then CheckMode(b3mSsse3);
  CheckMode(b3mAuto);
end;

procedure TestBlake3CrossMode;
const
  Lengths: array[0..20] of Integer = (0, 1, 31, 63, 64, 65, 1023, 1024, 1025, 2047, 2048, 2049, 4095, 4096, 4097, 5119, 5120, 5121, 8193, 16385, 32769);
var
  Scalar, Fast: TBlake3Jit;
  Data, Raw: TBytes;
  A, B: TBlake3Digest;
  I: Integer;
begin
  Scalar := TBlake3Jit.Create(b3mScalar);
  if TBlake3Jit.IsSsse3Available then Fast := TBlake3Jit.Create(b3mSsse3)
  else if TBlake3Jit.IsSse2Available then Fast := TBlake3Jit.Create(b3mSse2)
  else Fast := TBlake3Jit.Create(b3mScalar);
  try
    for I := Low(Lengths) to High(Lengths) do
    begin
      Data := MakeData(Lengths[I], Cardinal(500 + I));
      A := Scalar.Compute(Data);
      B := Fast.Compute(Data);
      Require(DigestHex(A) = DigestHex(B), 'BLAKE3 mode match length ' + IntToStr(Lengths[I]));
    end;
    Data := MakeData(16385, 599);
    SetLength(Raw, Length(Data) + 3);
    Move(Data[0], Raw[3], Length(Data));
    A := Scalar.Compute(Data);
    B := Fast.Compute(@Raw[3], Length(Data));
    Require(DigestHex(A) = DigestHex(B), 'BLAKE3 unaligned four-way input');
  finally
    Fast.Free;
    Scalar.Free;
  end;
end;

procedure TestXoshiro;
const
  Expected: array[0..7] of UInt64 = ($0000000002800001, $0000000003800067, $000CC00003800067, $000CC201994400B2, $8012A2019AC433CD, $8A69978ACDEE33BA, $C271134733154ABD, $AC2BA09179169E97);
  JumpExpected: array[0..3] of UInt64 = ($8C7A153956B5F3D1, $701F1A713401D85E, $6527F66A65469085, $8386B786C4408050);
var
  Jit: TXoshiro256ppJit;
  State: TXoshiro256ppState;
  I: Integer;
begin
  State[0] := 1; State[1] := 2; State[2] := 3; State[3] := 4;
  Jit := TXoshiro256ppJit.Create;
  try
    for I := 0 to High(Expected) do Require(Jit.NextUInt64(State) = Expected[I], 'xoshiro output ' + IntToStr(I));
  finally
    Jit.Free;
  end;
  State[0] := 1; State[1] := 2; State[2] := 3; State[3] := 4;
  TXoshiro256ppJit.Jump(State);
  for I := 0 to 3 do Require(State[I] = JumpExpected[I], 'xoshiro jump state ' + IntToStr(I));
end;

procedure TestXoshiroBulkAndParallel;
var
  Scalar: TXoshiro256ppJit;
  Parallel: TXoshiro256ppParallelJit;
  A, B, SingleState: TXoshiro256ppState;
  PState: TXoshiro256ppParallelState;
  Bulk, Single, PA, PB: array[0..127] of UInt64;
  Interleaved: array[0..255] of UInt64;
  I: Integer;
begin
  Scalar := TXoshiro256ppJit.Create;
  try
    TXoshiro256ppJit.SeedState(A, $123456789ABCDEF0);
    SingleState := A;
    Scalar.Fill(A, @Bulk[0], Length(Bulk));
    for I := 0 to High(Single) do Single[I] := Scalar.NextUInt64(SingleState);
    for I := 0 to High(Bulk) do Require(Bulk[I] = Single[I], 'xoshiro bulk index ' + IntToStr(I));
    for I := 0 to 3 do Require(A[I] = SingleState[I], 'xoshiro bulk state ' + IntToStr(I));
    if not TCpuFeatures.Supports(cfSSE2) then Exit;
    TXoshiro256ppJit.SeedState(A, $CAFEBABE12345678);
    B := A;
    TXoshiro256ppJit.Jump(B);
    TXoshiro256ppParallelJit.SeedState(PState, $CAFEBABE12345678);
    Scalar.Fill(A, @PA[0], Length(PA));
    Scalar.Fill(B, @PB[0], Length(PB));
    Parallel := TXoshiro256ppParallelJit.Create;
    try
      Parallel.FillInterleaved(PState, @Interleaved[0], Length(PA));
      for I := 0 to High(PA) do
      begin
        Require(Interleaved[I * 2] = PA[I], 'xoshiro parallel lane 0 index ' + IntToStr(I));
        Require(Interleaved[I * 2 + 1] = PB[I], 'xoshiro parallel lane 1 index ' + IntToStr(I));
      end;
    finally
      Parallel.Free;
    end;
  finally
    Scalar.Free;
  end;
end;


function BigHex(const S: string; Limbs: NativeUInt): TBigIntLimbs;
begin
  Result := TBigIntCore.FromHex(S, Limbs);
  Require(NativeUInt(Length(Result)) <= Limbs, 'BigInt hex overflow');
  SetLength(Result, Limbs);
end;

function LimbsEqual(const A, B: TBigIntLimbs): Boolean;
var
  I: Integer;
begin
  if Length(A) <> Length(B) then Exit(False);
  for I := 0 to High(A) do if A[I] <> B[I] then Exit(False);
  Result := True;
end;

procedure TestBigIntCore;
const
  AHex = 'AD238EB15729ED8F42A940D54669C8BD4FCD9E3CF64BA7EC0C0532C46503C151';
  BHex = '96DC3FE14FBF429FB669F3455344557827D02EBEAD9D9375BC039C3F029A5B8D';
  SumHex = '43FFCE92A6E9302EF913341A99AE1E35779DCCFBA3E93B61C808CF03679E1CDE';
  MulHex = '6607CB5EABC6DB2A64F0C286900C81E4A0CCEDCF1E66A330BFDC795692925AFAEB86027C20BA207E79DA8E1DEC084E8521353287F98CA4B9708480C7E583449D';
var
  A, B, R, E, W: TBigIntLimbs;
  J: TBigIntJit;
begin
  A := BigHex(AHex, 4); B := BigHex(BHex, 4); SetLength(R, 4); SetLength(W, 8);
  J := TBigIntJit.Create(4);
  try
    Require(J.Add(@R[0], @A[0], @B[0]) = 1, 'BigInt add carry');
    E := BigHex(SumHex, 4); Require(LimbsEqual(R, E), 'BigInt add vector');
    J.MulWide(@W[0], @A[0], @B[0]); E := BigHex(MulHex, 8); Require(LimbsEqual(W, E), 'BigInt mul vector');
    Require(J.CompareCT(@A[0], @B[0]) = 1, 'BigInt compare');
    Require(J.EqualCT(@A[0], @A[0]) = 1, 'BigInt equal');
  finally
    J.Free;
  end;
end;

procedure TestBigIntCtAndWide;
var
  A, B, R, W1, W2: TBigIntLimbs;
  J4, J32: TBigIntJit;
  I: Integer;
begin
  A := BigHex('123456789ABCDEF00112233445566778899AABBCCDDEEFF00123456789ABCDEF', 4);
  B := BigHex('223456789ABCDEF00112233445566778899AABBCCDDEEFF00123456789ABCDEF', 4);
  SetLength(R, 4);
  J4 := TBigIntJit.Create(4);
  try
    J4.SelectCT(@R[0], @A[0], @B[0], 0); Require(LimbsEqual(R, B), 'BigInt select zero');
    J4.SelectCT(@R[0], @A[0], @B[0], 7); Require(LimbsEqual(R, A), 'BigInt select nonzero');
    J4.SwapCT(@A[0], @B[0], 0); Require(J4.CompareCT(@A[0], @B[0]) = -1, 'BigInt swap zero');
    J4.SwapCT(@A[0], @B[0], 5); Require(J4.CompareCT(@A[0], @B[0]) = 1, 'BigInt swap nonzero');
  finally
    J4.Free;
  end;
  SetLength(A, 32); SetLength(B, 32); SetLength(W1, 64); SetLength(W2, 64);
  for I := 0 to 31 do begin A[I] := UInt64(I + 1) * $0102030405060709; B[I] := not (UInt64(I + 3) * $1020304050607081); end;
  J32 := TBigIntJit.Create(32);
  try
    TBigIntCore.MulWide(@W1[0], @A[0], @B[0], 32); J32.MulWide(@W2[0], @A[0], @B[0]);
    Require(LimbsEqual(W1, W2), 'BigInt 2048-bit loop mul');
  finally
    J32.Free;
  end;
end;

procedure TestBigIntFields;
  procedure Check(Id: TPrimeFieldId; const AHex, BHex, DirectHex, ProductHex: string);
  var
    C: TMontgomeryContext;
    A, B, AM, BM, PM, R, E: TBigIntLimbs;
  begin
    C := TPrimeFieldFactory.CreateContext(Id);
    try
      A := BigHex(AHex, C.Limbs); B := BigHex(BHex, C.Limbs); SetLength(AM, C.Limbs); SetLength(BM, C.Limbs); SetLength(PM, C.Limbs); SetLength(R, C.Limbs);
      C.MontMul(@R[0], @A[0], @B[0]); E := BigHex(DirectHex, C.Limbs); Require(LimbsEqual(R, E), 'BigInt field direct Montgomery');
      C.Encode(@AM[0], @A[0]); C.Encode(@BM[0], @B[0]); C.MontMul(@PM[0], @AM[0], @BM[0]); C.Decode(@R[0], @PM[0]); E := BigHex(ProductHex, C.Limbs); Require(LimbsEqual(R, E), 'BigInt field product');
    finally
      C.Free;
    end;
  end;
begin
  Check(pfCurve448,
    'DCD4563F700B1889C2D69C91ACCEF6A43D76553570621F11581DCE38DD5BE77AD29D37C46067AA4DF730225CB2EBC37823D22D6DF2445E14',
    'F6A809A89C75CB507339168DD0F3795005347003A536DA6F94E480C4CF4F89241B138E87102B74080C40A5D146EC9F1BF2D96AC8541B3D81',
    '203E4B8C6AC3392CF4BFC8896C06BA3CCB4EF47287762B54B73C904E4BD6BF91F31931E18BDBBE1E507B4B305543910FED8FA785E8B0ED31',
    '8C5356AAC89FA43B755B4F312888BFA9EBE179F4FC7BFE2F572A0DCD6C150B1E5DDC6B0E809B86A7BC82056D209285827505D2DA9FED7D7F');
  Check(pfP521,
    'D426357434D5D6CC3B50BE9F69E3B768BC1D9F2A9B56D0604E6EF7612839A9762BB1FB88DE6EEE3BFD822EF7DC78B87AAFAB4D6AFC2E20B9BA4BC754416D4F843B',
    'EB1C65B11EF74DB6FFCE35FF785B981F376C8EA362F7323DF3998224577270EDA7B6554C3304AB2F1E36686877312475B2F72277C565C54B6BAB18BBDBF9EBF21A',
    '1FD1EC7AE460F30B8167FE8CAB0B4C7C55C0072BEAE8AAFF6C71809AF3464BC95D28F25A21F7E6792A1DBA270F9B760A1AE45EE7CDA6B233C9136E47712C6DCD18D',
    '5C0B3FF465585A63E2AE00395F574557FB638C04D79A325E4AE94792D10FBF33C950EDD1387CDBB050D722F73E6D35919E489B723B89636E68C6FF47B1EB9183CC');
end;

procedure TestBigIntMontgomery;
const
  AHex = 'AD238EB15729ED8F42A940D54669C8BD4FCD9E3CF64BA7EC0C0532C46503C151';
  BHex = '96DC3FE14FBF429FB669F3455344557827D02EBEAD9D9375BC039C3F029A5B8D';
  MontHex = '831F5C7F905BFF1E287CADB7C0EA79470DB81DB2920A12AC66ACA72845806C78';
  ProductHex = 'FB0C01F417954FD044BD738E4C90F5DDEDB3692BBF1DEB1CA189BD90A9D56ADB';
var
  N, A, B, AM, BM, PM, R, E: TBigIntLimbs;
  C: TMontgomeryContext;
begin
  N := TPrimeFieldFactory.Modulus(pfSecp256k1); A := BigHex(AHex, 4); B := BigHex(BHex, 4);
  SetLength(AM, 4); SetLength(BM, 4); SetLength(PM, 4); SetLength(R, 4);
  C := TMontgomeryContext.Create(N);
  try
    C.MontMul(@R[0], @A[0], @B[0]); E := BigHex(MontHex, 4); Require(LimbsEqual(R, E), 'Montgomery direct vector');
    C.Encode(@AM[0], @A[0]); C.Encode(@BM[0], @B[0]); C.MontMul(@PM[0], @AM[0], @BM[0]); C.Decode(@R[0], @PM[0]);
    E := BigHex(ProductHex, 4); Require(LimbsEqual(R, E), 'Montgomery normal product');
  finally
    C.Free;
  end;
end;

procedure RunNativeAsmSelfTests;
begin
  GPassed := 0;
  GFailed := 0;
  Writeln('=== Self-Test ===');
  RunCase('CRC32 / CRC32C check vectors', TestCrcVectors);
  RunCase('CRC streaming + unaligned', TestCrcStreamingAndUnaligned);
  RunCase('FNV-1a 64 published vectors + streaming', TestFnv1a);
  RunCase('Base64 RFC 4648 + strict decoder', TestBase64);
  RunCase('Base64 scalar / SSSE3 cross-check', TestBase64CrossMode);
  RunCase('Hex scalar / SSSE3 + validation', TestHex);
  RunCase('Bloom filter no false negatives', TestBloom);
  RunCase('ChaCha20 RFC 8439 vectors', TestChaCha20Rfc);
  RunCase('ChaCha20 boundaries + in-place + unaligned', TestChaCha20Boundaries);
  RunCase('Poly1305 RFC 8439 + streaming', TestPoly1305);
  RunCase('ChaCha20-Poly1305 RFC 8439 + tamper', TestAead);
  RunCase('BLAKE3 official test-vector subset', TestBlake3Official);
  RunCase('BLAKE3 SIMD/tree-boundary cross-check', TestBlake3CrossMode);
  RunCase('xoshiro256++ reference sequence + jump', TestXoshiro);
  RunCase('xoshiro256++ bulk + SSE2 parallel streams', TestXoshiroBulkAndParallel);
  RunCase('BigInt fixed-width JIT core', TestBigIntCore);
  RunCase('BigInt CT helpers + 2048-bit loop kernel', TestBigIntCtAndWide);
  RunCase('BigInt Curve448 / P-521 field paths', TestBigIntFields);
  RunCase('BigInt Montgomery secp256k1', TestBigIntMontgomery);
  Writeln;
  if GFailed = 0 then Writeln(Format('Self-Test: PASS (%d groups)', [GPassed]))
  else
  begin
    Writeln(Format('Self-Test: FAIL (%d passed, %d failed)', [GPassed, GFailed]));
    raise Exception.Create('NativeAsm self-test failed');
  end;
end;

end.
