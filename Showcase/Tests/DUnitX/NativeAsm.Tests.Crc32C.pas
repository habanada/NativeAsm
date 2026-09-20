{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
unit NativeAsm.Tests.Crc32C;

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  NativeAsm.CpuFeatures,
  NativeAsm.Algorithms.Crc32C;

type
  [TestFixture]
  TCrc32CTests = class
  private
    class function Reference(Buffer: Pointer; Length: NativeUInt; Initial: Cardinal = 0): Cardinal; static;
    class function MakeData(Count: Integer): TBytes; static;
  public
    [Test] procedure KnownVector;
    [Test] procedure EmptyPreservesInitial;
    [Test] procedure ScalarMatchesReference;
    [Test] procedure StreamingMatchesSinglePass;
    [Test] procedure UnalignedInputMatchesReference;
    [Test] procedure AutoSelectsAvailableKernel;
    [Test] procedure ForcedSse42IsCorrectOrRejected;
    [Test] procedure NilWithNonZeroLengthIsRejected;
  end;

implementation

class function TCrc32CTests.Reference(Buffer: Pointer; Length: NativeUInt; Initial: Cardinal): Cardinal;
const
  Polynomial = Cardinal($82F63B78);
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

class function TCrc32CTests.MakeData(Count: Integer): TBytes;
var
  I: Integer;
begin
  SetLength(Result, Count);
  for I := 0 to High(Result) do Result[I] := Byte((I * 37 + (I shr 2) + 11) and $FF);
end;

procedure TCrc32CTests.KnownVector;
var
  Jit: TCrc32CJit;
  Data: TBytes;
begin
  Data := TEncoding.ASCII.GetBytes('123456789');
  Jit := TCrc32CJit.Create(cmScalar);
  try
    Assert.IsTrue(Jit.Compute(Data) = Cardinal($E3069283));
  finally
    Jit.Free;
  end;
end;

procedure TCrc32CTests.EmptyPreservesInitial;
var
  Jit: TCrc32CJit;
begin
  Jit := TCrc32CJit.Create(cmScalar);
  try
    Assert.IsTrue(Jit.Compute(nil, 0, $12345678) = Cardinal($12345678));
  finally
    Jit.Free;
  end;
end;

procedure TCrc32CTests.ScalarMatchesReference;
var
  Jit: TCrc32CJit;
  Data: TBytes;
  I: Integer;
  Expected: Cardinal;
begin
  Jit := TCrc32CJit.Create(cmScalar);
  try
    for I := 0 to 257 do
    begin
      Data := MakeData(I);
      if I = 0 then Expected := Reference(nil, 0) else Expected := Reference(@Data[0], NativeUInt(I));
      Assert.IsTrue(Jit.Compute(Data) = Expected, 'Length ' + IntToStr(I));
    end;
  finally
    Jit.Free;
  end;
end;

procedure TCrc32CTests.StreamingMatchesSinglePass;
var
  Jit: TCrc32CJit;
  Data: TBytes;
  Full, First, Split: Cardinal;
begin
  Data := MakeData(4097);
  Jit := TCrc32CJit.Create(cmScalar);
  try
    Full := Jit.Compute(Data);
    First := Jit.Compute(@Data[0], 1337);
    Split := Jit.Compute(@Data[1337], NativeUInt(Length(Data) - 1337), First);
    Assert.IsTrue(Split = Full);
  finally
    Jit.Free;
  end;
end;

procedure TCrc32CTests.UnalignedInputMatchesReference;
var
  Jit: TCrc32CJit;
  Data: TBytes;
  I: Integer;
  Expected: Cardinal;
begin
  SetLength(Data, 1026);
  for I := 1 to 1025 do Data[I] := Byte((I * 19 + 7) and $FF);
  Expected := Reference(@Data[1], 1025);
  Jit := TCrc32CJit.Create(cmScalar);
  try
    Assert.IsTrue(Jit.Compute(@Data[1], 1025) = Expected);
  finally
    Jit.Free;
  end;
  if TCpuFeatures.Supports(cfSSE42) then
  begin
    Jit := TCrc32CJit.Create(cmSse42);
    try
      Assert.IsTrue(Jit.Compute(@Data[1], 1025) = Expected);
    finally
      Jit.Free;
    end;
  end;
end;

procedure TCrc32CTests.AutoSelectsAvailableKernel;
var
  Jit: TCrc32CJit;
begin
  Jit := TCrc32CJit.Create(cmAuto);
  try
    if TCpuFeatures.Supports(cfSSE42) then Assert.IsTrue(Jit.Mode = cmSse42) else Assert.IsTrue(Jit.Mode = cmScalar);
  finally
    Jit.Free;
  end;
end;

procedure TCrc32CTests.ForcedSse42IsCorrectOrRejected;
var
  Jit: TCrc32CJit;
  Data: TBytes;
  Expected: Cardinal;
  Raised: Boolean;
begin
  Data := MakeData(8193);
  Expected := Reference(@Data[0], NativeUInt(Length(Data)));
  if TCpuFeatures.Supports(cfSSE42) then
  begin
    Jit := TCrc32CJit.Create(cmSse42);
    try
      Assert.IsTrue(Jit.Compute(Data) = Expected);
    finally
      Jit.Free;
    end;
  end
  else
  begin
    Raised := False;
    try
      Jit := TCrc32CJit.Create(cmSse42);
      Jit.Free;
    except
      on E: EInvalidOp do Raised := True;
    end;
    Assert.IsTrue(Raised);
  end;
end;

procedure TCrc32CTests.NilWithNonZeroLengthIsRejected;
var
  Jit: TCrc32CJit;
  Raised: Boolean;
begin
  Jit := TCrc32CJit.Create(cmScalar);
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
  TDUnitX.RegisterTestFixture(TCrc32CTests);

end.
