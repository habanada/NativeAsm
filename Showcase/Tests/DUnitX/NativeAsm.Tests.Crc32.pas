{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
unit NativeAsm.Tests.Crc32;

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  NativeAsm.CpuFeatures,
  NativeAsm.Algorithms.Crc32;

type
  [TestFixture]
  TCrc32Tests = class
  private
    class function Reference(Buffer: Pointer; Length: NativeUInt; Initial: Cardinal = 0): Cardinal; static;
    class function MakeData(Count: Integer): TBytes; static;
  public
    [Test] procedure KnownVector;
    [Test] procedure EmptyPreservesInitial;
    [Test] procedure ScalarMatchesReference;
    [Test] procedure BoundaryLengthsMatchReference;
    [Test] procedure StreamingMatchesSinglePass;
    [Test] procedure UnalignedInputMatchesReference;
    [Test] procedure AutoSelectsAvailableKernel;
    [Test] procedure ForcedPclmulIsCorrectOrRejected;
    [Test] procedure NilWithNonZeroLengthIsRejected;
  end;

implementation

class function TCrc32Tests.Reference(Buffer: Pointer; Length: NativeUInt; Initial: Cardinal): Cardinal;
const
  Polynomial = Cardinal($EDB88320);
var
  C: Cardinal;
  P: PByte;
  I: NativeUInt;
  J: Integer;
begin
  if Length = 0 then Exit(Initial);
  C := not Initial;
  P := PByte(Buffer);
  for I := 0 to Length - 1 do
  begin
    C := C xor P^;
    Inc(P);
    for J := 0 to 7 do
      if (C and 1) <> 0 then C := (C shr 1) xor Polynomial else C := C shr 1;
  end;
  Result := not C;
end;

class function TCrc32Tests.MakeData(Count: Integer): TBytes;
var
  I: Integer;
begin
  SetLength(Result, Count);
  for I := 0 to High(Result) do Result[I] := Byte((I * 73 + (I shr 1) + 29) and $FF);
end;

procedure TCrc32Tests.KnownVector;
var
  Jit: TCrc32Jit;
  Data: TBytes;
begin
  Data := TEncoding.ASCII.GetBytes('123456789');
  Jit := TCrc32Jit.Create(crc32mScalar);
  try
    Assert.IsTrue(Jit.Compute(Data) = Cardinal($CBF43926));
  finally
    Jit.Free;
  end;
end;

procedure TCrc32Tests.EmptyPreservesInitial;
var
  Jit: TCrc32Jit;
begin
  Jit := TCrc32Jit.Create(crc32mScalar);
  try
    Assert.IsTrue(Jit.Compute(nil, 0, $12345678) = Cardinal($12345678));
  finally
    Jit.Free;
  end;
end;

procedure TCrc32Tests.ScalarMatchesReference;
var
  Jit: TCrc32Jit;
  Data: TBytes;
  I: Integer;
  Expected: Cardinal;
begin
  Jit := TCrc32Jit.Create(crc32mScalar);
  try
    for I := 0 to 257 do
    begin
      Data := MakeData(I);
      if I = 0 then Expected := Reference(nil, 0, $89ABCDEF) else Expected := Reference(@Data[0], NativeUInt(I), $89ABCDEF);
      Assert.IsTrue(Jit.Compute(Data, $89ABCDEF) = Expected, 'Length ' + IntToStr(I));
    end;
  finally
    Jit.Free;
  end;
end;

procedure TCrc32Tests.BoundaryLengthsMatchReference;
const
  Lengths: array[0..18] of Integer = (1, 7, 15, 16, 17, 31, 32, 33, 47, 48, 49, 63, 64, 65, 255, 256, 257, 4095, 4097);
var
  Jit: TCrc32Jit;
  Data: TBytes;
  I, N: Integer;
  Expected: Cardinal;
begin
  if not TCrc32Jit.IsPclmulAvailable then Exit;
  Jit := TCrc32Jit.Create(crc32mPclmul);
  try
    for I := Low(Lengths) to High(Lengths) do
    begin
      N := Lengths[I];
      Data := MakeData(N);
      Expected := Reference(@Data[0], NativeUInt(N), $10203040);
      Assert.IsTrue(Jit.Compute(Data, $10203040) = Expected, 'Length ' + IntToStr(N));
    end;
  finally
    Jit.Free;
  end;
end;

procedure TCrc32Tests.StreamingMatchesSinglePass;
var
  Jit: TCrc32Jit;
  Data: TBytes;
  Full, Part: Cardinal;
begin
  Data := MakeData(8195);
  Jit := TCrc32Jit.Create(crc32mAuto);
  try
    Full := Jit.Compute(Data);
    Part := Jit.Compute(@Data[0], 13);
    Part := Jit.Compute(@Data[13], 2048, Part);
    Part := Jit.Compute(@Data[2061], NativeUInt(Length(Data) - 2061), Part);
    Assert.IsTrue(Part = Full);
  finally
    Jit.Free;
  end;
end;

procedure TCrc32Tests.UnalignedInputMatchesReference;
var
  Jit: TCrc32Jit;
  Data: TBytes;
  I: Integer;
  Expected: Cardinal;
begin
  SetLength(Data, 4099);
  for I := 1 to High(Data) do Data[I] := Byte((I * 41 + 3) and $FF);
  Expected := Reference(@Data[1], 4097, $13572468);
  Jit := TCrc32Jit.Create(crc32mAuto);
  try
    Assert.IsTrue(Jit.Compute(@Data[1], 4097, $13572468) = Expected);
  finally
    Jit.Free;
  end;
end;

procedure TCrc32Tests.AutoSelectsAvailableKernel;
var
  Jit: TCrc32Jit;
begin
  Jit := TCrc32Jit.Create(crc32mAuto);
  try
    if TCrc32Jit.IsPclmulAvailable then Assert.IsTrue(Jit.Mode = crc32mPclmul) else Assert.IsTrue(Jit.Mode = crc32mScalar);
  finally
    Jit.Free;
  end;
end;

procedure TCrc32Tests.ForcedPclmulIsCorrectOrRejected;
var
  Jit: TCrc32Jit;
  Data: TBytes;
  Expected: Cardinal;
  Raised: Boolean;
begin
  Data := MakeData(32771);
  Expected := Reference(@Data[0], NativeUInt(Length(Data)), $76543210);
  if TCrc32Jit.IsPclmulAvailable then
  begin
    Jit := TCrc32Jit.Create(crc32mPclmul);
    try
      Assert.IsTrue(Jit.Compute(Data, $76543210) = Expected);
    finally
      Jit.Free;
    end;
  end
  else
  begin
    Raised := False;
    try
      Jit := TCrc32Jit.Create(crc32mPclmul);
      Jit.Free;
    except
      on E: EInvalidOp do Raised := True;
    end;
    Assert.IsTrue(Raised);
  end;
end;

procedure TCrc32Tests.NilWithNonZeroLengthIsRejected;
var
  Jit: TCrc32Jit;
  Raised: Boolean;
begin
  Jit := TCrc32Jit.Create(crc32mScalar);
  try
    Raised := False;
    try
      Jit.Compute(nil, 1);
    except
      on E: EArgumentNilException do Raised := True;
    end;
    Assert.IsTrue(Raised);
  finally
    Jit.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TCrc32Tests);

end.
