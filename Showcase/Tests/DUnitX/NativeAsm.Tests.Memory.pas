{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
unit NativeAsm.Tests.Memory;

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  NativeAsm.CpuFeatures,
  NativeAsm.Memory;

type
  [TestFixture]
  TNativeMemoryTests = class
  private
    class function ReferenceCompare(A, B: PByte; Length: NativeUInt): Integer; static;
    class function ReferenceFind(Buffer: PByte; Length: NativeUInt; Value: Byte): NativeInt; static;
    procedure CheckMode(Mode: TNativeMemoryMode);
  public
    [Test] procedure ScalarMatchesReference;
    [Test] procedure Sse2MatchesReferenceWhenAvailable;
    [Test] procedure AutoSelectsAvailableKernel;
    [Test] procedure ZeroLengthAcceptsNil;
    [Test] procedure NonZeroLengthRejectsNil;
  end;

implementation

class function TNativeMemoryTests.ReferenceCompare(A, B: PByte; Length: NativeUInt): Integer;
begin
  while Length <> 0 do
  begin
    if A^ <> B^ then Exit(Integer(A^) - Integer(B^));
    Inc(A);
    Inc(B);
    Dec(Length);
  end;
  Result := 0;
end;

class function TNativeMemoryTests.ReferenceFind(Buffer: PByte; Length: NativeUInt; Value: Byte): NativeInt;
var
  I: NativeUInt;
begin
  I := 0;
  while I < Length do
  begin
    if Buffer^ = Value then Exit(NativeInt(I));
    Inc(Buffer);
    Inc(I);
  end;
  Result := -1;
end;

procedure TNativeMemoryTests.CheckMode(Mode: TNativeMemoryMode);
var
  Jit: TNativeMemoryJit;
  A, B, D: TBytes;
  I, Len, DiffIndex: Integer;
  ExpectedCompare: Integer;
  ExpectedFind: NativeInt;
begin
  SetLength(A, 260);
  SetLength(B, 260);
  SetLength(D, 260);
  for I := 0 to High(A) do
  begin
    A[I] := Byte((I * 29 + 17) and $FF);
    B[I] := A[I];
  end;
  Jit := TNativeMemoryJit.Create(Mode);
  try
    for Len := 0 to 129 do
    begin
      if Len = 0 then
      begin
        Assert.IsTrue(Jit.Compare(nil, nil, 0) = 0);
        Assert.IsTrue(Jit.FindByte(nil, 0, $7A) = -1);
      end
      else
      begin
        ExpectedCompare := ReferenceCompare(@A[1], @B[1], NativeUInt(Len));
        Assert.IsTrue(Jit.Compare(@A[1], @B[1], NativeUInt(Len)) = ExpectedCompare, 'equal len ' + IntToStr(Len));
        ExpectedFind := ReferenceFind(@A[1], NativeUInt(Len), A[1 + Len div 2]);
        Assert.IsTrue(Jit.FindByte(@A[1], NativeUInt(Len), A[1 + Len div 2]) = ExpectedFind, 'find len ' + IntToStr(Len));
        Jit.Copy(@D[1], @A[1], NativeUInt(Len));
        for I := 0 to Len - 1 do Assert.IsTrue(D[1 + I] = A[1 + I], 'copy len ' + IntToStr(Len));
        Jit.Fill(@D[1], NativeUInt(Len), $A7);
        for I := 0 to Len - 1 do Assert.IsTrue(D[1 + I] = $A7, 'fill len ' + IntToStr(Len));
      end;
    end;
    for DiffIndex := 0 to 63 do
    begin
      for I := 0 to 79 do B[1 + I] := A[1 + I];
      B[1 + DiffIndex] := Byte(A[1 + DiffIndex] xor $7F);
      ExpectedCompare := ReferenceCompare(@A[1], @B[1], 80);
      Assert.IsTrue(Jit.Compare(@A[1], @B[1], 80) = ExpectedCompare, 'difference ' + IntToStr(DiffIndex));
    end;
  finally
    Jit.Free;
  end;
end;

procedure TNativeMemoryTests.ScalarMatchesReference;
begin
  CheckMode(nmmScalar);
end;

procedure TNativeMemoryTests.Sse2MatchesReferenceWhenAvailable;
begin
  if TCpuFeatures.Supports(cfSSE2) then CheckMode(nmmSse2) else Assert.IsTrue(True);
end;

procedure TNativeMemoryTests.AutoSelectsAvailableKernel;
var
  Jit: TNativeMemoryJit;
begin
  Jit := TNativeMemoryJit.Create;
  try
    if TCpuFeatures.Supports(cfSSE2) then Assert.IsTrue(Jit.Mode = nmmSse2) else Assert.IsTrue(Jit.Mode = nmmScalar);
  finally
    Jit.Free;
  end;
end;

procedure TNativeMemoryTests.ZeroLengthAcceptsNil;
var
  Jit: TNativeMemoryJit;
begin
  Jit := TNativeMemoryJit.Create(nmmScalar);
  try
    Assert.IsTrue(Jit.Compare(nil, nil, 0) = 0);
    Assert.IsTrue(Jit.FindByte(nil, 0, 1) = -1);
    Jit.Fill(nil, 0, 1);
    Jit.Copy(nil, nil, 0);
  finally
    Jit.Free;
  end;
end;

procedure TNativeMemoryTests.NonZeroLengthRejectsNil;
var
  Jit: TNativeMemoryJit;
  Raised: Boolean;
begin
  Jit := TNativeMemoryJit.Create(nmmScalar);
  try
    Raised := False;
    try
      Jit.FindByte(nil, 1, 0);
    except
      on E: EArgumentNilException do Raised := True;
    end;
    Assert.IsTrue(Raised);
  finally
    Jit.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TNativeMemoryTests);

end.
