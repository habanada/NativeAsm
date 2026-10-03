unit NativeAsm.Avx.Db;

{$ALIGN ON}
{$MINENUMSIZE 4}

interface

type
  TAvxExtension = (aeAVX, aeAVX2, aeFMA);
  TAvxEncodingForm = (aefOP, aefRM, aefMR, aefRVM, aefVM, aefMVR, aefRMV, aefM, aefRVMS);
  TAvxOpcodeMap = (aom0F, aom0F38, aom0F3A);
  TAvxDbRegClass = (arcNone, arcXmm, arcYmm, arcGp32, arcGp64);
  TAvxDbMemClass = (amcNone, amc128, amc256, amc8, amc16, amc32, amc64, amcVm32x, amcVm32y, amcVm64x, amcVm64y);

const
  AVX_OK_REG = $01;
  AVX_OK_MEM = $02;
  AVX_OK_IMM = $04;

type
  TAvxDbOperandSpec = record
    Kinds: Byte;
    RegClass: TAvxDbRegClass;
    MemClass: TAvxDbMemClass;
    ImmBytes: Byte;
  end;
  PAvxDbOperandSpec = ^TAvxDbOperandSpec;

  TAvxEncodingDescriptor = record
    MnemonicIndex: Word;
    Extension: TAvxExtension;
    FormTag: TAvxEncodingForm;
    VexL: Byte;
    VexPP: Byte;
    VexW: Byte;
    OpcodeMap: TAvxOpcodeMap;
    Opcode: Byte;
    ModRegOperandIdx: ShortInt;
    ModRegFixed: ShortInt;
    ModRmOperandIdx: ShortInt;
    VvvvOperandIdx: ShortInt;
    ImmediateOperandIdx: ShortInt;
    OperandStart: Word;
    OperandCount: Byte;
  end;
  PAvxEncodingDescriptor = ^TAvxEncodingDescriptor;

  TAvxInstructionDb = class sealed
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
    class function Form(FormIndex: Integer): PAvxEncodingDescriptor; static;
    class function Operand(FormIndex, OperandIndex: Integer): PAvxDbOperandSpec; static;
  end;

implementation

uses
  System.SysUtils,
  NativeAsm.Avx.Db.Generated;

class function TAvxInstructionDb.SourceSha256: string;
begin
  Result := CAvxDbSourceSha256;
end;

class function TAvxInstructionDb.FormCount: Integer;
begin
  Result := CAvxFormCount;
end;

class function TAvxInstructionDb.MnemonicCount: Integer;
begin
  Result := CAvxMnemonicCount;
end;

class function TAvxInstructionDb.MnemonicName(Index: Integer): string;
begin
  if (Index < 0) or (Index >= CAvxMnemonicCount) then raise EArgumentOutOfRangeException.Create('AVX mnemonic index');
  Result := CAvxMnemonicNames[Index];
end;

class function TAvxInstructionDb.MnemonicIndexOf(const Mnemonic: string): Integer;
var
  L, H, M, I, C: Integer;
begin
  L := 0;
  H := CAvxMnemonicCount - 1;
  while L <= H do
  begin
    M := L + ((H - L) shr 1);
    I := CAvxMnemonicLookupOrder[M];
    C := CompareText(CAvxMnemonicNames[I], Mnemonic);
    if C = 0 then Exit(I);
    if C < 0 then L := M + 1 else H := M - 1;
  end;
  Result := -1;
end;

class function TAvxInstructionDb.MnemonicFormCount(Index: Integer): Integer;
begin
  if (Index < 0) or (Index >= CAvxMnemonicCount) then raise EArgumentOutOfRangeException.Create('AVX mnemonic index');
  Result := CAvxMnemonicFormCount[Index];
end;

class function TAvxInstructionDb.MnemonicFormIndex(Index, Position: Integer): Integer;
begin
  if (Index < 0) or (Index >= CAvxMnemonicCount) then raise EArgumentOutOfRangeException.Create('AVX mnemonic index');
  if (Position < 0) or (Position >= CAvxMnemonicFormCount[Index]) then raise EArgumentOutOfRangeException.Create('AVX form position');
  Result := CAvxFormOrder[CAvxMnemonicFormStart[Index] + Position];
end;

class function TAvxInstructionDb.SourceSignature(FormIndex: Integer): string;
begin
  if (FormIndex < 0) or (FormIndex >= CAvxFormCount) then raise EArgumentOutOfRangeException.Create('AVX form index');
  Result := CAvxSourceSignatures[FormIndex];
end;

class function TAvxInstructionDb.SourceEncoding(FormIndex: Integer): string;
begin
  if (FormIndex < 0) or (FormIndex >= CAvxFormCount) then raise EArgumentOutOfRangeException.Create('AVX form index');
  Result := CAvxSourceEncodings[FormIndex];
end;

class function TAvxInstructionDb.Form(FormIndex: Integer): PAvxEncodingDescriptor;
begin
  if (FormIndex < 0) or (FormIndex >= CAvxFormCount) then raise EArgumentOutOfRangeException.Create('AVX form index');
  Result := @CAvxForms[FormIndex];
end;

class function TAvxInstructionDb.Operand(FormIndex, OperandIndex: Integer): PAvxDbOperandSpec;
var
  D: PAvxEncodingDescriptor;
begin
  D := Form(FormIndex);
  if (OperandIndex < 0) or (OperandIndex >= D^.OperandCount) then raise EArgumentOutOfRangeException.Create('AVX operand index');
  Result := @CAvxOperands[D^.OperandStart + OperandIndex];
end;

end.
