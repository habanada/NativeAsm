unit NativeAsm.Simd.Db;

{$ALIGN ON}
{$MINENUMSIZE 4}

interface

type
  TSimdExtension = (seSSE, seSSE2, seSSE3, seSSSE3, seSSE41, seSSE42, seSSE4A, seAESNI, seSHA, seLZCNT, seBMI, sePCLMULQDQ);
  TSimdEncodingForm = (sefNone, sefOP, sefRM, sefMR, sefM, sefR);
  TSimdOpcodeMap = (somPrimary, som0F, som0F38, som0F3A);
  TSimdDbRegClass = (srcNone, srcXmm, srcMm, srcGp8, srcGp16, srcGp32, srcGp64);
  TSimdDbMemClass = (smcNone, smcAny, smc8, smc16, smc32, smc64, smc128);
  TSimdFixedKind = (sfkNone, sfkXmm, sfkGp);
  TSimdModRMKind = (smkNone, smkOperands, smkFixedReg, smkFixedByte);

const
  SIMD_OK_REG = $01;
  SIMD_OK_MEM = $02;
  SIMD_OK_IMM = $04;

type
  TSimdDbOperandSpec = record
    Kinds: Byte;
    RegClass: TSimdDbRegClass;
    MemClass: TSimdDbMemClass;
    ImmBytes: Byte;
    Implicit: Boolean;
    FixedKind: TSimdFixedKind;
    FixedID: Byte;
  end;
  PSimdDbOperandSpec = ^TSimdDbOperandSpec;

  TSimdEncodingDescriptor = record
    MnemonicIndex: Word;
    Extension: TSimdExtension;
    FormTag: TSimdEncodingForm;
    Prefix1: Byte;
    Prefix2: Byte;
    RexW: Boolean;
    OpcodeMap: TSimdOpcodeMap;
    Opcode: Byte;
    ModRMKind: TSimdModRMKind;
    ModRegOperandIdx: ShortInt;
    ModRmOperandIdx: ShortInt;
    FixedRegValue: Byte;
    FixedModRMByte: Byte;
    Immediate0OperandIdx: ShortInt;
    Immediate1OperandIdx: ShortInt;
    OperandStart: Word;
    OperandCount: Byte;
    ExplicitOperandCount: Byte;
  end;
  PSimdEncodingDescriptor = ^TSimdEncodingDescriptor;

  TSimdInstructionDb = class sealed
  public
    class function SourceSha256: string; static;
    class function FormCount: Integer; static;
    class function MnemonicCount: Integer; static;
    class function MnemonicName(Index: Integer): string; static;
    class function MnemonicIndexOf(const Mnemonic: string): Integer; static;
    class function MnemonicFormCount(Index: Integer): Integer; static;
    class function MnemonicFormIndex(Index, Position: Integer): Integer; static;
    class function SourceSignature(FormIndex: Integer): string; static;
    class function SourceEncoding(FormIndex: Integer): string; static;
    class function Form(FormIndex: Integer): PSimdEncodingDescriptor; static;
    class function Operand(FormIndex, OperandIndex: Integer): PSimdDbOperandSpec; static;
  end;

implementation

uses
  System.SysUtils,
  NativeAsm.Simd.Db.Generated;

class function TSimdInstructionDb.SourceSha256: string;
begin
  Result := CSimdDbSourceSha256;
end;

class function TSimdInstructionDb.FormCount: Integer;
begin
  Result := CSimdFormCount;
end;

class function TSimdInstructionDb.MnemonicCount: Integer;
begin
  Result := CSimdMnemonicCount;
end;

class function TSimdInstructionDb.MnemonicName(Index: Integer): string;
begin
  if (Index < 0) or (Index >= CSimdMnemonicCount) then raise EArgumentOutOfRangeException.Create('SIMD mnemonic index');
  Result := CSimdMnemonicNames[Index];
end;

class function TSimdInstructionDb.MnemonicIndexOf(const Mnemonic: string): Integer;
var
  L, H, M, C: Integer;
begin
  L := 0;
  H := CSimdMnemonicCount - 1;
  while L <= H do
  begin
    M := L + ((H - L) shr 1);
    C := CompareText(CSimdMnemonicNames[M], Mnemonic);
    if C = 0 then Exit(M);
    if C < 0 then L := M + 1 else H := M - 1;
  end;
  Result := -1;
end;

class function TSimdInstructionDb.MnemonicFormCount(Index: Integer): Integer;
begin
  if (Index < 0) or (Index >= CSimdMnemonicCount) then raise EArgumentOutOfRangeException.Create('SIMD mnemonic index');
  Result := CSimdMnemonicFormCount[Index];
end;

class function TSimdInstructionDb.MnemonicFormIndex(Index, Position: Integer): Integer;
begin
  if (Index < 0) or (Index >= CSimdMnemonicCount) then raise EArgumentOutOfRangeException.Create('SIMD mnemonic index');
  if (Position < 0) or (Position >= CSimdMnemonicFormCount[Index]) then raise EArgumentOutOfRangeException.Create('SIMD form position');
  Result := CSimdFormOrder[CSimdMnemonicFormStart[Index] + Position];
end;

class function TSimdInstructionDb.SourceSignature(FormIndex: Integer): string;
begin
  if (FormIndex < 0) or (FormIndex >= CSimdFormCount) then raise EArgumentOutOfRangeException.Create('SIMD form index');
  Result := CSimdSourceSignatures[FormIndex];
end;

class function TSimdInstructionDb.SourceEncoding(FormIndex: Integer): string;
begin
  if (FormIndex < 0) or (FormIndex >= CSimdFormCount) then raise EArgumentOutOfRangeException.Create('SIMD form index');
  Result := CSimdSourceEncodings[FormIndex];
end;

class function TSimdInstructionDb.Form(FormIndex: Integer): PSimdEncodingDescriptor;
begin
  if (FormIndex < 0) or (FormIndex >= CSimdFormCount) then raise EArgumentOutOfRangeException.Create('SIMD form index');
  Result := @CSimdForms[FormIndex];
end;

class function TSimdInstructionDb.Operand(FormIndex, OperandIndex: Integer): PSimdDbOperandSpec;
var
  D: PSimdEncodingDescriptor;
begin
  D := Form(FormIndex);
  if (OperandIndex < 0) or (OperandIndex >= D^.OperandCount) then raise EArgumentOutOfRangeException.Create('SIMD operand index');
  Result := @CSimdOperands[D^.OperandStart + OperandIndex];
end;

end.
