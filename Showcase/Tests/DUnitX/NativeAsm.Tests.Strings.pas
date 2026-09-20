{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
unit NativeAsm.Tests.Strings;

interface

uses
  System.SysUtils,
  Winapi.Windows,
  DUnitX.TestFramework,
  NativeAsm.CpuFeatures,
  NativeAsm.Strings;

type
  [TestFixture]
  TNativeStringTests = class
  private
    procedure CheckMode(Mode: TNativeStringMode);
    procedure CheckPageBoundary(Mode: TNativeStringMode);
  public
    [Test] procedure ScalarLengthsAreCorrect;
    [Test] procedure Sse2LengthsAreCorrectWhenAvailable;
    [Test] procedure AutoSelectsAvailableKernel;
    [Test] procedure Sse2DoesNotCrossGuardPage;
    [Test] procedure NilIsRejected;
  end;

implementation

procedure TNativeStringTests.CheckMode(Mode: TNativeStringMode);
var
  Jit: TNativeStringJit;
  A: AnsiString;
  W: UnicodeString;
  I: Integer;
begin
  Jit := TNativeStringJit.Create(Mode);
  try
    A := #0;
    W := #0;
    Assert.IsTrue(Jit.Length8(PAnsiChar(A)) = 0);
    Assert.IsTrue(Jit.Length16(PWideChar(W)) = 0);
    for I := 1 to 257 do
    begin
      A := AnsiString(StringOfChar('A', I));
      W := StringOfChar('W', I);
      Assert.IsTrue(Jit.Length8(PAnsiChar(A)) = NativeUInt(I), 'ansi ' + IntToStr(I));
      Assert.IsTrue(Jit.Length16(PWideChar(W)) = NativeUInt(I), 'wide ' + IntToStr(I));
    end;
  finally
    Jit.Free;
  end;
end;

procedure TNativeStringTests.CheckPageBoundary(Mode: TNativeStringMode);
var
  Jit: TNativeStringJit;
  Mem: Pointer;
  OldProtect: Cardinal;
  I: Integer;
  A: PAnsiChar;
  W: PWideChar;
begin
  Mem := VirtualAlloc(nil, 8192, MEM_COMMIT or MEM_RESERVE, PAGE_READWRITE);
  Assert.IsTrue(Mem <> nil);
  try
    A := PAnsiChar(NativeUInt(Mem) + 4090);
    for I := 0 to 4 do PByte(NativeUInt(A) + NativeUInt(I))^ := Ord('A');
    PByte(NativeUInt(A) + 5)^ := 0;
    Assert.IsTrue(VirtualProtect(Pointer(NativeUInt(Mem) + 4096), 4096, PAGE_NOACCESS, OldProtect));
    Jit := TNativeStringJit.Create(Mode);
    try
      Assert.IsTrue(Jit.Length8(A) = 5);
      W := PWideChar(NativeUInt(Mem) + 4086);
      for I := 0 to 3 do PWord(NativeUInt(W) + NativeUInt(I * 2))^ := Ord('W');
      PWord(NativeUInt(W) + 8)^ := 0;
      Assert.IsTrue(Jit.Length16(W) = 4);
    finally
      Jit.Free;
    end;
  finally
    VirtualFree(Mem, 0, MEM_RELEASE);
  end;
end;

procedure TNativeStringTests.ScalarLengthsAreCorrect;
begin
  CheckMode(nsmScalar);
end;

procedure TNativeStringTests.Sse2LengthsAreCorrectWhenAvailable;
begin
  if TCpuFeatures.Supports(cfSSE2) then CheckMode(nsmSse2) else Assert.IsTrue(True);
end;

procedure TNativeStringTests.AutoSelectsAvailableKernel;
var
  Jit: TNativeStringJit;
begin
  Jit := TNativeStringJit.Create;
  try
    if TCpuFeatures.Supports(cfSSE2) then Assert.IsTrue(Jit.Mode = nsmSse2) else Assert.IsTrue(Jit.Mode = nsmScalar);
  finally
    Jit.Free;
  end;
end;

procedure TNativeStringTests.Sse2DoesNotCrossGuardPage;
begin
  CheckPageBoundary(nsmScalar);
  if TCpuFeatures.Supports(cfSSE2) then CheckPageBoundary(nsmSse2);
end;

procedure TNativeStringTests.NilIsRejected;
var
  Jit: TNativeStringJit;
  Raised: Boolean;
begin
  Jit := TNativeStringJit.Create(nsmScalar);
  try
    Raised := False;
    try
      Jit.Length8(nil);
    except
      on E: EArgumentNilException do Raised := True;
    end;
    Assert.IsTrue(Raised);
    Raised := False;
    try
      Jit.Length16(nil);
    except
      on E: EArgumentNilException do Raised := True;
    end;
    Assert.IsTrue(Raised);
  finally
    Jit.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TNativeStringTests);

end.
