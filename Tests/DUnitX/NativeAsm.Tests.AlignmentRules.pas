{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
unit NativeAsm.Tests.AlignmentRules;

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  NativeAsm.Types,
  NativeAsm.Operands,
  NativeAsm.Rules,
  NativeAsm.Builder;

type
  TLocalProc = reference to procedure;

  [TestFixture]
  TAlignmentRulesTests = class
  private
    procedure ExpectRuleViolation(const MessagePart: string; const Proc: TLocalProc);
  public
    [Test] procedure OperandSizeOrdinalsRemainStable;
    [Test] procedure MemoryConstructorsDefaultToUnknownAlignment;
    [Test] procedure PointerHelpersPreserveAddressAndSetExactAlignment;
    [Test] procedure AlignmentMetadataSurvivesOperandConversion;
    [Test] procedure AlignmentMetadataDoesNotChangeExistingEncoding;
    [Test] procedure AlignedMovesRejectUnknownAlignment;
    [Test] procedure AlignedMovesRejectEveryInsufficientAlignment;
    [Test] procedure AlignedMovesAcceptSixteenAndHigherAlignment;
    [Test] procedure MovdquAllowsEveryAlignmentState;
    [Test] procedure MnemonicMatchingIsCaseInsensitive;
    [Test] procedure NonMemoryOperandsDoNotTriggerAlignmentRules;
    [Test] procedure EveryMemoryOperandIsValidated;
    [Test] procedure UnrelatedMnemonicsIgnoreAlignmentMetadata;
  end;

implementation

procedure TAlignmentRulesTests.ExpectRuleViolation(const MessagePart: string; const Proc: TLocalProc);
var
  Raised: Boolean;
begin
  Raised := False;
  try
    Proc;
  except
    on E: ENativeAsmRuleViolation do
    begin
      Raised := True;
      Assert.IsTrue(Pos(MessagePart, E.Message) > 0, 'Unexpected message: ' + E.Message);
    end;
  end;
  Assert.IsTrue(Raised, 'ENativeAsmRuleViolation expected');
end;

procedure TAlignmentRulesTests.OperandSizeOrdinalsRemainStable;
begin
  Assert.IsTrue(Ord(szUnspecified) = 0);
  Assert.IsTrue(Ord(sz8) = 1);
  Assert.IsTrue(Ord(sz16) = 2);
  Assert.IsTrue(Ord(sz32) = 3);
  Assert.IsTrue(Ord(sz64) = 4);
  Assert.IsTrue(Ord(sz128) = 5);
end;

procedure TAlignmentRulesTests.MemoryConstructorsDefaultToUnknownAlignment;
var
  Reg: TRegID;
  M: TMemory;
begin
  for Reg := ridRAX to ridR15 do
  begin
    M := TMemory.Create(Reg, 17, sz64);
    Assert.IsTrue(M.Alignment = 0, 'Create alignment for register ' + IntToStr(Ord(Reg)));
    Assert.IsTrue((M.Base = Reg) and (M.Disp = 17) and (M.Size = sz64));
  end;
  M := TMemory.CreateSib(ridR12, ridR13, s8, -123, sz128);
  Assert.IsTrue(M.Alignment = 0);
  Assert.IsTrue((M.Base = ridR12) and (M.Index = ridR13) and (M.Scale = s8) and (M.Disp = -123) and M.HasIndex and (M.Size = sz128));
  M := TMemory.CreateRip(123456, sz128);
  Assert.IsTrue(M.Alignment = 0);
  Assert.IsTrue((M.Base = ridRIP) and M.IsRipRelative and (M.Disp = 123456) and (M.Size = sz128));
end;

procedure TAlignmentRulesTests.PointerHelpersPreserveAddressAndSetExactAlignment;
var
  M: TMemory;
begin
  M := OWordPtr(ridR14, -321);
  Assert.IsTrue((M.Base = ridR14) and (M.Disp = -321) and (M.Size = sz128) and (M.Alignment = 0));
  M := AlignedWordPtr(ridR8, 11);
  Assert.IsTrue((M.Base = ridR8) and (M.Disp = 11) and (M.Size = sz16) and (M.Alignment = 2));
  M := AlignedDWordPtr(ridR9, 12);
  Assert.IsTrue((M.Base = ridR9) and (M.Disp = 12) and (M.Size = sz32) and (M.Alignment = 4));
  M := AlignedQWordPtr(ridR10, 13);
  Assert.IsTrue((M.Base = ridR10) and (M.Disp = 13) and (M.Size = sz64) and (M.Alignment = 8));
  M := AlignedOWordPtr(ridR11, 14);
  Assert.IsTrue((M.Base = ridR11) and (M.Disp = 14) and (M.Size = sz128) and (M.Alignment = 16));
end;

procedure TAlignmentRulesTests.AlignmentMetadataSurvivesOperandConversion;
var
  M: TMemory;
  O: TOperand;
begin
  M := TMemory.CreateSib(ridR12, ridR13, s4, 77, sz128);
  M.Alignment := 32;
  O := M;
  Assert.IsTrue(O.Kind = otMem);
  Assert.IsTrue((O.Mem.Base = ridR12) and (O.Mem.Index = ridR13) and (O.Mem.Scale = s4) and (O.Mem.Disp = 77));
  Assert.IsTrue((O.Mem.Size = sz128) and (O.Mem.Alignment = 32));
end;


procedure TAlignmentRulesTests.AlignmentMetadataDoesNotChangeExistingEncoding;
var
  B: TAsmBuilder;
  A, C: TBytes;
  I: Integer;
begin
  B := TAsmBuilder.New;
  try
    B.Mov(RAX, QWordPtr(ridRCX, 37));
    A := B.Build;
  finally
    B.Free;
  end;
  B := TAsmBuilder.New;
  try
    B.Mov(RAX, AlignedQWordPtr(ridRCX, 37));
    C := B.Build;
  finally
    B.Free;
  end;
  Assert.IsTrue(Length(A) = Length(C));
  for I := 0 to High(A) do Assert.IsTrue(A[I] = C[I], 'Encoding differs at byte ' + IntToStr(I));
end;

procedure TAlignmentRulesTests.AlignedMovesRejectUnknownAlignment;
const
  Mnemonics: array[0..2] of string = ('movaps', 'movapd', 'movdqa');
var
  I: Integer;
begin
  for I := 0 to High(Mnemonics) do
    ExpectRuleViolation('operand alignment is unknown', procedure begin TAsmRuleValidator.Validate(Mnemonics[I], [TOperand(OWordPtr(ridRAX))]); end);
end;

procedure TAlignmentRulesTests.AlignedMovesRejectEveryInsufficientAlignment;
const
  Mnemonics: array[0..2] of string = ('movaps', 'movapd', 'movdqa');
  Alignments: array[0..3] of Byte = (1, 2, 4, 8);
var
  I, J: Integer;
  M: TMemory;
begin
  for I := 0 to High(Mnemonics) do
    for J := 0 to High(Alignments) do
    begin
      M := OWordPtr(ridRAX);
      M.Alignment := Alignments[J];
      ExpectRuleViolation('operand guarantees only ' + IntToStr(Alignments[J]) + '-byte alignment', procedure begin TAsmRuleValidator.Validate(Mnemonics[I], [TOperand(M)]); end);
    end;
end;

procedure TAlignmentRulesTests.AlignedMovesAcceptSixteenAndHigherAlignment;
const
  Mnemonics: array[0..2] of string = ('movaps', 'movapd', 'movdqa');
  Alignments: array[0..3] of Byte = (16, 32, 64, 128);
var
  I, J: Integer;
  M: TMemory;
begin
  for I := 0 to High(Mnemonics) do
    for J := 0 to High(Alignments) do
    begin
      M := OWordPtr(ridRAX);
      M.Alignment := Alignments[J];
      TAsmRuleValidator.Validate(Mnemonics[I], [TOperand(M)]);
      Assert.IsTrue(True);
    end;
end;

procedure TAlignmentRulesTests.MovdquAllowsEveryAlignmentState;
const
  Alignments: array[0..6] of Byte = (0, 1, 2, 4, 8, 16, 64);
var
  I: Integer;
  M: TMemory;
begin
  for I := 0 to High(Alignments) do
  begin
    M := OWordPtr(ridRAX);
    M.Alignment := Alignments[I];
    TAsmRuleValidator.Validate('movdqu', [TOperand(M)]);
  end;
  Assert.IsTrue(True);
end;

procedure TAlignmentRulesTests.MnemonicMatchingIsCaseInsensitive;
const
  Mnemonics: array[0..5] of string = ('MOVDQA', 'MovDqa', 'MOVAPS', 'MovAps', 'MOVAPD', 'MovApd');
var
  I: Integer;
begin
  for I := 0 to High(Mnemonics) do ExpectRuleViolation('requires 16-byte aligned memory', procedure begin TAsmRuleValidator.Validate(Mnemonics[I], [TOperand(OWordPtr(ridRAX))]); end);
end;

procedure TAlignmentRulesTests.NonMemoryOperandsDoNotTriggerAlignmentRules;
begin
  TAsmRuleValidator.Validate('movdqa', [TOperand(RAX)]);
  TAsmRuleValidator.Validate('movaps', [TOperand(Int64(123))]);
  TAsmRuleValidator.Validate('movapd', [TOperand(RAX), TOperand(RCX)]);
  Assert.IsTrue(True);
end;

procedure TAlignmentRulesTests.EveryMemoryOperandIsValidated;
var
  A, B: TMemory;
begin
  A := AlignedOWordPtr(ridRAX);
  B := OWordPtr(ridRCX);
  ExpectRuleViolation('operand alignment is unknown', procedure begin TAsmRuleValidator.Validate('movdqa', [TOperand(A), TOperand(B)]); end);
  B.Alignment := 8;
  ExpectRuleViolation('operand guarantees only 8-byte alignment', procedure begin TAsmRuleValidator.Validate('movdqa', [TOperand(A), TOperand(B)]); end);
  B.Alignment := 16;
  TAsmRuleValidator.Validate('movdqa', [TOperand(A), TOperand(B)]);
  Assert.IsTrue(True);
end;

procedure TAlignmentRulesTests.UnrelatedMnemonicsIgnoreAlignmentMetadata;
const
  Mnemonics: array[0..5] of string = ('mov', 'add', 'paddd', 'pxor', 'aesenc', 'sha256rnds2');
var
  I: Integer;
begin
  for I := 0 to High(Mnemonics) do TAsmRuleValidator.Validate(Mnemonics[I], [TOperand(OWordPtr(ridRAX))]);
  Assert.IsTrue(True);
end;

initialization
  TDUnitX.RegisterTestFixture(TAlignmentRulesTests);

end.
