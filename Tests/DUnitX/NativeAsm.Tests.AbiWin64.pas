{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
unit NativeAsm.Tests.AbiWin64;

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  NativeAsm.Types,
  NativeAsm.Abi.Win64;

type
  TLocalProc = reference to procedure;

  [TestFixture]
  TWin64AbiTests = class
  private
    procedure ExpectAbiViolation(const MessagePart: string; const Proc: TLocalProc);
  public
    [Test] procedure GprClassificationIsCompleteAndDisjoint;
    [Test] procedure XmmClassificationIsCompleteAndDisjoint;
    [Test] procedure XmmMasksCoverAllSixteenBitsExactlyOnce;
    [Test] procedure XmmRejectsIndicesOutsideRange;
    [Test] procedure VolatileGprsNeedNoPreservation;
    [Test] procedure EveryNonvolatileGprRequiresBothSaveAndRestore;
    [Test] procedure AllNonvolatileGprsCanBePreservedTogether;
    [Test] procedure MissingSingleGprSaveOrRestoreIsDetected;
    [Test] procedure UnmodifiedGprSaveRestoreMetadataIsHarmless;
    [Test] procedure VolatileXmmsNeedNoPreservation;
    [Test] procedure EveryNonvolatileXmmRequiresBothSaveAndRestore;
    [Test] procedure AllNonvolatileXmmsCanBePreservedTogether;
    [Test] procedure MissingSingleXmmSaveOrRestoreIsDetected;
    [Test] procedure UnmodifiedXmmSaveRestoreMetadataIsHarmless;
    [Test] procedure MixedGprAndXmmUsageValidatesTogether;
  end;

implementation

procedure TWin64AbiTests.ExpectAbiViolation(const MessagePart: string; const Proc: TLocalProc);
var
  Raised: Boolean;
begin
  Raised := False;
  try
    Proc;
  except
    on E: ENativeAsmAbiViolation do
    begin
      Raised := True;
      Assert.IsTrue(Pos(MessagePart, E.Message) > 0, 'Unexpected message: ' + E.Message);
    end;
  end;
  Assert.IsTrue(Raised, 'ENativeAsmAbiViolation expected');
end;

procedure TWin64AbiTests.GprClassificationIsCompleteAndDisjoint;
var
  Reg: TRegID;
  VolatileExpected, PreservedExpected: Boolean;
begin
  for Reg := Low(TRegID) to High(TRegID) do
  begin
    VolatileExpected := Reg in [ridRAX, ridRCX, ridRDX, ridR8, ridR9, ridR10, ridR11];
    PreservedExpected := Reg in [ridRBX, ridRBP, ridRSI, ridRDI, ridR12, ridR13, ridR14, ridR15];
    Assert.IsTrue(TWin64AbiValidator.IsVolatileGpr(Reg) = VolatileExpected, 'Volatile classification mismatch for ' + IntToStr(Ord(Reg)));
    Assert.IsTrue(TWin64AbiValidator.RequiresPreservationGpr(Reg) = PreservedExpected, 'Preservation classification mismatch for ' + IntToStr(Ord(Reg)));
    Assert.IsTrue(not (TWin64AbiValidator.IsVolatileGpr(Reg) and TWin64AbiValidator.RequiresPreservationGpr(Reg)), 'Classification overlap for ' + IntToStr(Ord(Reg)));
  end;
end;

procedure TWin64AbiTests.XmmClassificationIsCompleteAndDisjoint;
var
  I: Integer;
  VolatileExpected, PreservedExpected: Boolean;
begin
  for I := -3 to 18 do
  begin
    VolatileExpected := (I >= 0) and (I <= 5);
    PreservedExpected := (I >= 6) and (I <= 15);
    Assert.IsTrue(TWin64AbiValidator.IsVolatileXmm(I) = VolatileExpected, 'Volatile XMM classification mismatch for ' + IntToStr(I));
    Assert.IsTrue(TWin64AbiValidator.RequiresPreservationXmm(I) = PreservedExpected, 'Preservation XMM classification mismatch for ' + IntToStr(I));
    Assert.IsTrue(not (TWin64AbiValidator.IsVolatileXmm(I) and TWin64AbiValidator.RequiresPreservationXmm(I)), 'XMM classification overlap for ' + IntToStr(I));
  end;
end;

procedure TWin64AbiTests.XmmMasksCoverAllSixteenBitsExactlyOnce;
var
  I: Integer;
  Mask, Combined: TXmmRegisterMask;
begin
  Combined := 0;
  for I := 0 to 15 do
  begin
    Mask := TWin64AbiValidator.Xmm(I);
    Assert.IsTrue(Mask = TXmmRegisterMask(UInt16(1) shl I), 'Wrong mask for XMM' + IntToStr(I));
    Assert.IsTrue((Combined and Mask) = 0, 'Duplicate mask for XMM' + IntToStr(I));
    Combined := Combined or Mask;
  end;
  Assert.IsTrue(Combined = $FFFF);
end;

procedure TWin64AbiTests.XmmRejectsIndicesOutsideRange;
begin
  ExpectAbiViolation('out of range 0..15', procedure begin TWin64AbiValidator.Xmm(-1); end);
  ExpectAbiViolation('out of range 0..15', procedure begin TWin64AbiValidator.Xmm(16); end);
  ExpectAbiViolation('out of range 0..15', procedure begin TWin64AbiValidator.Xmm(Low(Integer)); end);
  ExpectAbiViolation('out of range 0..15', procedure begin TWin64AbiValidator.Xmm(High(Integer)); end);
end;

procedure TWin64AbiTests.VolatileGprsNeedNoPreservation;
var
  Usage: TWin64AbiUsage;
begin
  Usage := Default(TWin64AbiUsage);
  Usage.ModifiedGprs := [ridRAX, ridRCX, ridRDX, ridR8, ridR9, ridR10, ridR11];
  TWin64AbiValidator.Validate(Usage);
  Assert.IsTrue(True);
end;

procedure TWin64AbiTests.EveryNonvolatileGprRequiresBothSaveAndRestore;
var
  Reg: TRegID;
  Usage: TWin64AbiUsage;
begin
  for Reg := Low(TRegID) to High(TRegID) do
    if TWin64AbiValidator.RequiresPreservationGpr(Reg) then
    begin
      Usage := Default(TWin64AbiUsage);
      Include(Usage.ModifiedGprs, Reg);
      ExpectAbiViolation('is nonvolatile', procedure begin TWin64AbiValidator.Validate(Usage); end);
      Include(Usage.SavedGprs, Reg);
      ExpectAbiViolation('is nonvolatile', procedure begin TWin64AbiValidator.Validate(Usage); end);
      Exclude(Usage.SavedGprs, Reg);
      Include(Usage.RestoredGprs, Reg);
      ExpectAbiViolation('is nonvolatile', procedure begin TWin64AbiValidator.Validate(Usage); end);
      Include(Usage.SavedGprs, Reg);
      TWin64AbiValidator.Validate(Usage);
      Assert.IsTrue(True);
    end;
end;

procedure TWin64AbiTests.AllNonvolatileGprsCanBePreservedTogether;
var
  Usage: TWin64AbiUsage;
begin
  Usage := Default(TWin64AbiUsage);
  Usage.ModifiedGprs := [ridRBX, ridRBP, ridRSI, ridRDI, ridR12, ridR13, ridR14, ridR15];
  Usage.SavedGprs := Usage.ModifiedGprs;
  Usage.RestoredGprs := Usage.ModifiedGprs;
  TWin64AbiValidator.Validate(Usage);
  Assert.IsTrue(True);
end;

procedure TWin64AbiTests.MissingSingleGprSaveOrRestoreIsDetected;
var
  Usage: TWin64AbiUsage;
begin
  Usage := Default(TWin64AbiUsage);
  Usage.ModifiedGprs := [ridRBX, ridRBP, ridRSI, ridRDI, ridR12, ridR13, ridR14, ridR15];
  Usage.SavedGprs := Usage.ModifiedGprs;
  Usage.RestoredGprs := Usage.ModifiedGprs;
  Exclude(Usage.RestoredGprs, ridR13);
  ExpectAbiViolation('R13 is nonvolatile', procedure begin TWin64AbiValidator.Validate(Usage); end);
  Usage.RestoredGprs := Usage.ModifiedGprs;
  Exclude(Usage.SavedGprs, ridR14);
  ExpectAbiViolation('R14 is nonvolatile', procedure begin TWin64AbiValidator.Validate(Usage); end);
end;

procedure TWin64AbiTests.UnmodifiedGprSaveRestoreMetadataIsHarmless;
var
  Usage: TWin64AbiUsage;
begin
  Usage := Default(TWin64AbiUsage);
  Usage.SavedGprs := [ridRBX, ridRBP, ridRSI, ridRDI, ridR12, ridR13, ridR14, ridR15];
  Usage.RestoredGprs := Usage.SavedGprs;
  TWin64AbiValidator.Validate(Usage);
  Assert.IsTrue(True);
end;

procedure TWin64AbiTests.VolatileXmmsNeedNoPreservation;
var
  Usage: TWin64AbiUsage;
begin
  Usage := Default(TWin64AbiUsage);
  Usage.ModifiedXmm := $003F;
  TWin64AbiValidator.Validate(Usage);
  Assert.IsTrue(True);
end;

procedure TWin64AbiTests.EveryNonvolatileXmmRequiresBothSaveAndRestore;
var
  I: Integer;
  Mask: TXmmRegisterMask;
  Usage: TWin64AbiUsage;
begin
  for I := 6 to 15 do
  begin
    Mask := TWin64AbiValidator.Xmm(I);
    Usage := Default(TWin64AbiUsage);
    Usage.ModifiedXmm := Mask;
    ExpectAbiViolation('XMM' + IntToStr(I) + ' is nonvolatile', procedure begin TWin64AbiValidator.Validate(Usage); end);
    Usage.SavedXmm := Mask;
    ExpectAbiViolation('XMM' + IntToStr(I) + ' is nonvolatile', procedure begin TWin64AbiValidator.Validate(Usage); end);
    Usage.SavedXmm := 0;
    Usage.RestoredXmm := Mask;
    ExpectAbiViolation('XMM' + IntToStr(I) + ' is nonvolatile', procedure begin TWin64AbiValidator.Validate(Usage); end);
    Usage.SavedXmm := Mask;
    TWin64AbiValidator.Validate(Usage);
    Assert.IsTrue(True);
  end;
end;

procedure TWin64AbiTests.AllNonvolatileXmmsCanBePreservedTogether;
var
  Usage: TWin64AbiUsage;
begin
  Usage := Default(TWin64AbiUsage);
  Usage.ModifiedXmm := $FFC0;
  Usage.SavedXmm := $FFC0;
  Usage.RestoredXmm := $FFC0;
  TWin64AbiValidator.Validate(Usage);
  Assert.IsTrue(True);
end;

procedure TWin64AbiTests.MissingSingleXmmSaveOrRestoreIsDetected;
var
  Usage: TWin64AbiUsage;
begin
  Usage := Default(TWin64AbiUsage);
  Usage.ModifiedXmm := $FFC0;
  Usage.SavedXmm := $FFC0;
  Usage.RestoredXmm := TXmmRegisterMask($FFC0);
  Usage.RestoredXmm := Usage.RestoredXmm xor TWin64AbiValidator.Xmm(11);
  ExpectAbiViolation('XMM11 is nonvolatile', procedure begin TWin64AbiValidator.Validate(Usage); end);
  Usage.RestoredXmm := $FFC0;
  Usage.SavedXmm := TXmmRegisterMask($FFC0);
  Usage.SavedXmm := Usage.SavedXmm xor TWin64AbiValidator.Xmm(12);
  ExpectAbiViolation('XMM12 is nonvolatile', procedure begin TWin64AbiValidator.Validate(Usage); end);
end;

procedure TWin64AbiTests.UnmodifiedXmmSaveRestoreMetadataIsHarmless;
var
  Usage: TWin64AbiUsage;
begin
  Usage := Default(TWin64AbiUsage);
  Usage.SavedXmm := $FFC0;
  Usage.RestoredXmm := $FFC0;
  TWin64AbiValidator.Validate(Usage);
  Assert.IsTrue(True);
end;

procedure TWin64AbiTests.MixedGprAndXmmUsageValidatesTogether;
var
  Usage: TWin64AbiUsage;
begin
  Usage := Default(TWin64AbiUsage);
  Usage.ModifiedGprs := [ridRAX, ridRBX, ridR15];
  Usage.SavedGprs := [ridRBX, ridR15];
  Usage.RestoredGprs := [ridRBX, ridR15];
  Usage.ModifiedXmm := TWin64AbiValidator.Xmm(0) or TWin64AbiValidator.Xmm(6) or TWin64AbiValidator.Xmm(15);
  Usage.SavedXmm := TWin64AbiValidator.Xmm(6) or TWin64AbiValidator.Xmm(15);
  Usage.RestoredXmm := Usage.SavedXmm;
  TWin64AbiValidator.Validate(Usage);
  Assert.IsTrue(True);
end;

initialization
  TDUnitX.RegisterTestFixture(TWin64AbiTests);

end.
