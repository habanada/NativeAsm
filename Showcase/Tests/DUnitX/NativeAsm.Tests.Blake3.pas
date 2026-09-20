{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
unit NativeAsm.Tests.Blake3;

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  NativeAsm.CpuFeatures,
  NativeAsm.Crypto.Blake3;

type
  [TestFixture]
  TBlake3Tests = class
  private
    class function DigestHex(const D: TBlake3Digest): string; static;
    class function MakeData(Count: Integer): TBytes; static;
  public
    [Test] procedure OfficialEmptyVector;
    [Test] procedure AbcVector;
    [Test] procedure SmallInputVector;
    [Test] procedure LargeInputVector;
    [Test] procedure Sse2MatchesScalarAcrossTreeBoundaries;
    [Test] procedure Ssse3MatchesScalarAcrossTreeBoundaries;
    [Test] procedure FourWayChunkGroupsMatchScalar;
    [Test] procedure UnalignedInputMatches;
    [Test] procedure UnalignedFourWayInputMatches;
    [Test] procedure AutoSelectsBestAvailable;
  end;

implementation

class function TBlake3Tests.DigestHex(const D: TBlake3Digest): string;
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

class function TBlake3Tests.MakeData(Count: Integer): TBytes;
var
  I: Integer;
begin
  SetLength(Result, Count);
  for I := 0 to High(Result) do Result[I] := Byte((I * 131 + (I shr 3) + 17) and $FF);
end;

procedure TBlake3Tests.OfficialEmptyVector;
var
  Jit: TBlake3Jit;
  D: TBlake3Digest;
begin
  Jit := TBlake3Jit.Create(b3mScalar);
  try
    D := Jit.Compute(nil, 0);
    Assert.IsTrue(DigestHex(D) = 'af1349b9f5f9a1a6a0404dea36dcc9499bcb25c9adc112b7cc9a93cae41f3262');
  finally
    Jit.Free;
  end;
end;

procedure TBlake3Tests.AbcVector;
var
  Jit: TBlake3Jit;
  Data: TBytes;
  D: TBlake3Digest;
begin
  Data := TEncoding.ASCII.GetBytes('abc');
  Jit := TBlake3Jit.Create(b3mAuto);
  try
    D := Jit.Compute(Data);
    Assert.IsTrue(DigestHex(D) = '6437b3ac38465133ffb63b75273a8db548c558465d79db03fd359c6cd5bd9d85');
  finally
    Jit.Free;
  end;
end;

procedure TBlake3Tests.SmallInputVector;
var
  Jit: TBlake3Jit;
  Data: TBytes;
  D: TBlake3Digest;
begin
  Data := TEncoding.ASCII.GetBytes('some data');
  Jit := TBlake3Jit.Create(b3mAuto);
  try
    D := Jit.Compute(Data);
    Assert.IsTrue(DigestHex(D) = 'b224a1da2bf5e72b337dc6dde457a05265a06dec8875be379e2ad2be5edb3bf2');
  finally
    Jit.Free;
  end;
end;

procedure TBlake3Tests.LargeInputVector;
var
  Jit: TBlake3Jit;
  Data: TBytes;
  D: TBlake3Digest;
begin
  SetLength(Data, 10240);
  FillChar(Data[0], Length(Data), Ord('a'));
  Jit := TBlake3Jit.Create(b3mAuto);
  try
    D := Jit.Compute(Data);
    Assert.IsTrue(DigestHex(D) = '9afd0ba102b2cc68be10ba4d383b3139b97ed36d425b82631a7a1e2424088f7e');
  finally
    Jit.Free;
  end;
end;

procedure TBlake3Tests.Sse2MatchesScalarAcrossTreeBoundaries;
const
  Lengths: array[0..21] of Integer = (0, 1, 31, 63, 64, 65, 127, 255, 1023, 1024, 1025, 2047, 2048, 2049, 3072, 4095, 4096, 4097, 8192, 8193, 16384, 16385);
var
  Scalar, Simd: TBlake3Jit;
  Data: TBytes;
  A, B: TBlake3Digest;
  I: Integer;
begin
  if not TCpuFeatures.Supports(cfSSE2) then Exit;
  Scalar := TBlake3Jit.Create(b3mScalar);
  Simd := TBlake3Jit.Create(b3mSse2);
  try
    for I := Low(Lengths) to High(Lengths) do
    begin
      Data := MakeData(Lengths[I]);
      A := Scalar.Compute(Data);
      B := Simd.Compute(Data);
      Assert.IsTrue(DigestHex(A) = DigestHex(B), 'Length ' + IntToStr(Lengths[I]));
    end;
  finally
    Simd.Free;
    Scalar.Free;
  end;
end;

procedure TBlake3Tests.Ssse3MatchesScalarAcrossTreeBoundaries;
const
  Lengths: array[0..16] of Integer = (0, 1, 63, 64, 65, 1023, 1024, 1025, 4095, 4096, 4097, 5119, 5120, 5121, 8192, 8193, 16385);
var
  Scalar, Simd: TBlake3Jit;
  Data: TBytes;
  A, B: TBlake3Digest;
  I: Integer;
begin
  if not TCpuFeatures.Supports(cfSSSE3) then Exit;
  Scalar := TBlake3Jit.Create(b3mScalar);
  Simd := TBlake3Jit.Create(b3mSsse3);
  try
    for I := Low(Lengths) to High(Lengths) do
    begin
      Data := MakeData(Lengths[I]);
      A := Scalar.Compute(Data);
      B := Simd.Compute(Data);
      Assert.IsTrue(DigestHex(A) = DigestHex(B), 'Length ' + IntToStr(Lengths[I]));
    end;
  finally
    Simd.Free;
    Scalar.Free;
  end;
end;

procedure TBlake3Tests.FourWayChunkGroupsMatchScalar;
const
  Lengths: array[0..12] of Integer = (4097, 5119, 5120, 5121, 6144, 8192, 8193, 9216, 12289, 16384, 16385, 32768, 32769);
var
  Scalar, Sse2, Ssse3: TBlake3Jit;
  Data: TBytes;
  Reference, Actual: TBlake3Digest;
  I: Integer;
begin
  Scalar := TBlake3Jit.Create(b3mScalar);
  Sse2 := nil;
  Ssse3 := nil;
  if TCpuFeatures.Supports(cfSSE2) then Sse2 := TBlake3Jit.Create(b3mSse2);
  if TCpuFeatures.Supports(cfSSSE3) then Ssse3 := TBlake3Jit.Create(b3mSsse3);
  try
    for I := Low(Lengths) to High(Lengths) do
    begin
      Data := MakeData(Lengths[I]);
      Reference := Scalar.Compute(Data);
      if Sse2 <> nil then
      begin
        Actual := Sse2.Compute(Data);
        Assert.IsTrue(DigestHex(Reference) = DigestHex(Actual), 'SSE2 length ' + IntToStr(Lengths[I]));
      end;
      if Ssse3 <> nil then
      begin
        Actual := Ssse3.Compute(Data);
        Assert.IsTrue(DigestHex(Reference) = DigestHex(Actual), 'SSSE3 length ' + IntToStr(Lengths[I]));
      end;
    end;
  finally
    Ssse3.Free;
    Sse2.Free;
    Scalar.Free;
  end;
end;

procedure TBlake3Tests.UnalignedInputMatches;
var
  Jit: TBlake3Jit;
  Raw, CopyData: TBytes;
  A, B: TBlake3Digest;
  I: Integer;
begin
  SetLength(Raw, 4099);
  SetLength(CopyData, 4097);
  for I := 0 to 4096 do
  begin
    Raw[I + 1] := Byte((I * 23 + 7) and $FF);
    CopyData[I] := Raw[I + 1];
  end;
  Jit := TBlake3Jit.Create;
  try
    A := Jit.Compute(@Raw[1], 4097);
    B := Jit.Compute(CopyData);
    Assert.IsTrue(DigestHex(A) = DigestHex(B));
  finally
    Jit.Free;
  end;
end;

procedure TBlake3Tests.UnalignedFourWayInputMatches;
const
  DataLength = 16385;
var
  Scalar, Simd: TBlake3Jit;
  Raw, CopyData: TBytes;
  A, B: TBlake3Digest;
  I: Integer;
begin
  if not TCpuFeatures.Supports(cfSSE2) then Exit;
  SetLength(Raw, DataLength + 3);
  SetLength(CopyData, DataLength);
  for I := 0 to DataLength - 1 do
  begin
    Raw[I + 3] := Byte((I * 37 + 29) and $FF);
    CopyData[I] := Raw[I + 3];
  end;
  Scalar := TBlake3Jit.Create(b3mScalar);
  if TCpuFeatures.Supports(cfSSSE3) then Simd := TBlake3Jit.Create(b3mSsse3) else Simd := TBlake3Jit.Create(b3mSse2);
  try
    A := Scalar.Compute(CopyData);
    B := Simd.Compute(@Raw[3], DataLength);
    Assert.IsTrue(DigestHex(A) = DigestHex(B));
  finally
    Simd.Free;
    Scalar.Free;
  end;
end;

procedure TBlake3Tests.AutoSelectsBestAvailable;
var
  Jit: TBlake3Jit;
begin
  Jit := TBlake3Jit.Create;
  try
    if TCpuFeatures.Supports(cfSSSE3) then Assert.IsTrue(Jit.Mode = b3mSsse3)
    else if TCpuFeatures.Supports(cfSSE2) then Assert.IsTrue(Jit.Mode = b3mSse2)
    else Assert.IsTrue(Jit.Mode = b3mScalar);
  finally
    Jit.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TBlake3Tests);

end.
