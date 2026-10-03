unit NativeAsm.Bmi.Db;

{$ALIGN ON}
{$MINENUMSIZE 4}

interface

uses
  System.SysUtils;

type
  EBmiError = class(Exception);
  TBmiExtension = (beBMI1, beBMI2);
  TBmiEncodingForm = (befRVM, befRMV, befVM, befRM);
  TBmiOpcodeMap = (bom0F38, bom0F3A);
  TBmiDbRegClass = (brcNone, brc32, brc64);
  TBmiDbMemClass = (bmcNone, bmc32, bmc64);

const
  BMI_OK_REG = $01;
  BMI_OK_MEM = $02;
  BMI_OK_IMM = $04;

type
  TBmiDbOperandSpec = record
    Kinds: Byte;
    RegClass: TBmiDbRegClass;
    MemClass: TBmiDbMemClass;
    ImmBytes: Byte;
  end;
  PBmiDbOperandSpec = ^TBmiDbOperandSpec;

  TBmiEncodingDescriptor = record
    MnemonicIndex: Word;
    Extension: TBmiExtension;
    FormTag: TBmiEncodingForm;
    VexPP: Byte;
    VexW: Byte;
    OpcodeMap: TBmiOpcodeMap;
    Opcode: Byte;
    ModRegOperandIdx: ShortInt;
    ModRegFixed: ShortInt;
    ModRmOperandIdx: ShortInt;
    VvvvOperandIdx: ShortInt;
    ImmediateOperandIdx: ShortInt;
    OperandStart: Word;
    OperandCount: Byte;
  end;
  PBmiEncodingDescriptor = ^TBmiEncodingDescriptor;

  TBmiInstructionDb = class sealed
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
    class function Form(FormIndex: Integer): PBmiEncodingDescriptor; static;
    class function Operand(FormIndex, OperandIndex: Integer): PBmiDbOperandSpec; static;
  end;

implementation

uses
  NativeAsm.Bmi.Db.Generated;

class function TBmiInstructionDb.SourceSha256: string;
begin
  Result := CBmiDbSourceSha256;
end;

class function TBmiInstructionDb.FormCount: Integer;
begin
  Result := CBmiFormCount;
end;

class function TBmiInstructionDb.MnemonicCount: Integer;
begin
  Result := CBmiMnemonicCount;
end;

class function TBmiInstructionDb.MnemonicName(Index: Integer): string;
begin
  if (Index < 0) or (Index >= CBmiMnemonicCount) then raise EArgumentOutOfRangeException.Create('BMI mnemonic index');
  Result := CBmiMnemonicNames[Index];
end;

class function TBmiInstructionDb.MnemonicIndexOf(const Mnemonic: string): Integer;
var
  L, H, M, C: Integer;
begin
  L := 0;
  H := CBmiMnemonicCount - 1;
  while L <= H do
  begin
    M := L + ((H - L) shr 1);
    C := CompareText(CBmiMnemonicNames[M], Mnemonic);
    if C = 0 then Exit(M);
    if C < 0 then L := M + 1 else H := M - 1;
  end;
  Result := -1;
end;

class function TBmiInstructionDb.MnemonicFormCount(Index: Integer): Integer;
begin
  if (Index < 0) or (Index >= CBmiMnemonicCount) then raise EArgumentOutOfRangeException.Create('BMI mnemonic index');
  Result := CBmiMnemonicFormCount[Index];
end;

class function TBmiInstructionDb.MnemonicFormIndex(Index, Position: Integer): Integer;
begin
  if (Index < 0) or (Index >= CBmiMnemonicCount) then raise EArgumentOutOfRangeException.Create('BMI mnemonic index');
  if (Position < 0) or (Position >= CBmiMnemonicFormCount[Index]) then raise EArgumentOutOfRangeException.Create('BMI form position');
  Result := CBmiFormOrder[CBmiMnemonicFormStart[Index] + Position];
end;

class function TBmiInstructionDb.SourceSignature(FormIndex: Integer): string;
begin
  if (FormIndex < 0) or (FormIndex >= CBmiFormCount) then raise EArgumentOutOfRangeException.Create('BMI form index');
  Result := CBmiSourceSignatures[FormIndex];
end;

class function TBmiInstructionDb.SourceEncoding(FormIndex: Integer): string;
begin
  if (FormIndex < 0) or (FormIndex >= CBmiFormCount) then raise EArgumentOutOfRangeException.Create('BMI form index');
  Result := CBmiSourceEncodings[FormIndex];
end;

class function TBmiInstructionDb.Form(FormIndex: Integer): PBmiEncodingDescriptor;
begin
  if (FormIndex < 0) or (FormIndex >= CBmiFormCount) then raise EArgumentOutOfRangeException.Create('BMI form index');
  Result := @CBmiForms[FormIndex];
end;

class function TBmiInstructionDb.Operand(FormIndex, OperandIndex: Integer): PBmiDbOperandSpec;
var
  D: PBmiEncodingDescriptor;
begin
  D := Form(FormIndex);
  if (OperandIndex < 0) or (OperandIndex >= D^.OperandCount) then raise EArgumentOutOfRangeException.Create('BMI operand index');
  Result := @CBmiOperands[D^.OperandStart + OperandIndex];
end;

end.
