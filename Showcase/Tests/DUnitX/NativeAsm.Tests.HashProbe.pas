{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
unit NativeAsm.Tests.HashProbe;

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  NativeAsm.CpuFeatures,
  NativeAsm.Algorithms.HashProbe;

type
  [TestFixture]
  THashProbeTests = class
  private
    class function ReferenceMask(Control: PByte; Tag: Byte): Word; static;
    procedure CheckMode(Mode: THashProbeMode);
  public
    [Test] procedure ScalarMatchesReference;
    [Test] procedure Sse2MatchesReferenceWhenAvailable;
    [Test] procedure Bmi1FindMatchesWhenAvailable;
    [Test] procedure AutoSelectsBestAvailableKernel;
    [Test] procedure UnalignedControlBlockWorks;
    [Test] procedure MissingTagReturnsMinusOne;
    [Test] procedure NilControlIsRejected;
  end;

implementation

class function THashProbeTests.ReferenceMask(Control: PByte; Tag: Byte): Word;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to 15 do
  begin
    if Control^ = Tag then Result := Result or Word(1 shl I);
    Inc(Control);
  end;
end;

procedure THashProbeTests.CheckMode(Mode: THashProbeMode);
var
  Jit: THashProbeJit;
  Control: array[0..15] of Byte;
  Tag: Integer;
  I, First: Integer;
  Mask: Word;
begin
  for I := 0 to 15 do Control[I] := Byte((I * 7 + 3) and $0F);
  Control[1] := $A5;
  Control[7] := $A5;
  Control[15] := $A5;
  Jit := THashProbeJit.Create(Mode);
  try
    for Tag := 0 to 255 do
    begin
      Mask := ReferenceMask(@Control[0], Byte(Tag));
      Assert.IsTrue(Jit.MatchTag16(@Control[0], Byte(Tag)) = Mask, 'Tag ' + IntToStr(Tag));
      First := Jit.FindFirstTag16(@Control[0], Byte(Tag));
      if Mask = 0 then Assert.IsTrue(First = -1, 'Tag ' + IntToStr(Tag))
      else
      begin
        I := 0;
        while (Mask and Word(1 shl I)) = 0 do Inc(I);
        Assert.IsTrue(First = I, 'Tag ' + IntToStr(Tag));
      end;
    end;
  finally
    Jit.Free;
  end;
end;

procedure THashProbeTests.ScalarMatchesReference;
begin
  CheckMode(hpmScalar);
end;

procedure THashProbeTests.Sse2MatchesReferenceWhenAvailable;
begin
  if TCpuFeatures.Supports(cfSSE2) then CheckMode(hpmSse2) else Assert.IsTrue(True);
end;

procedure THashProbeTests.Bmi1FindMatchesWhenAvailable;
begin
  if TCpuFeatures.Supports(cfSSE2) and TCpuFeatures.Supports(cfBMI1) then CheckMode(hpmSse2Bmi1) else Assert.IsTrue(True);
end;

procedure THashProbeTests.AutoSelectsBestAvailableKernel;
var
  Jit: THashProbeJit;
  Expected: THashProbeMode;
begin
  if TCpuFeatures.Supports(cfSSE2) and TCpuFeatures.Supports(cfBMI1) then Expected := hpmSse2Bmi1
  else if TCpuFeatures.Supports(cfSSE2) then Expected := hpmSse2
  else Expected := hpmScalar;
  Jit := THashProbeJit.Create;
  try
    Assert.IsTrue(Jit.Mode = Expected);
  finally
    Jit.Free;
  end;
end;

procedure THashProbeTests.UnalignedControlBlockWorks;
var
  Jit: THashProbeJit;
  Data: array[0..16] of Byte;
  I: Integer;
  Expected: Word;
begin
  for I := 0 to 16 do Data[I] := Byte(I);
  Data[2] := $77;
  Data[9] := $77;
  Expected := ReferenceMask(@Data[1], $77);
  Jit := THashProbeJit.Create;
  try
    Assert.IsTrue(Jit.MatchTag16(@Data[1], $77) = Expected);
  finally
    Jit.Free;
  end;
end;

procedure THashProbeTests.MissingTagReturnsMinusOne;
var
  Jit: THashProbeJit;
  Control: array[0..15] of Byte;
begin
  FillChar(Control, SizeOf(Control), 0);
  Jit := THashProbeJit.Create;
  try
    Assert.IsTrue(Jit.FindFirstTag16(@Control[0], $FF) = -1);
  finally
    Jit.Free;
  end;
end;

procedure THashProbeTests.NilControlIsRejected;
var
  Jit: THashProbeJit;
  Raised: Boolean;
begin
  Jit := THashProbeJit.Create(hpmScalar);
  try
    Raised := False;
    try
      Jit.MatchTag16(nil, 0);
    except
      on E: EArgumentNilException do Raised := True;
    end;
    Assert.IsTrue(Raised);
  finally
    Jit.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(THashProbeTests);

end.
