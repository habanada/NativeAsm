{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
unit NativeAsm.Rules;

{$ALIGN ON}
{$MINENUMSIZE 4}

interface

uses
  System.SysUtils,
  NativeAsm.Types,
  NativeAsm.InstructionDB;

type
  ENativeAsmRuleViolation = class(Exception);

  TAsmRuleValidator = class sealed
  private
    class function RequiredMemoryAlignment(const Mnemonic: string): Byte; static;
    class procedure ValidateAlignment(const Mnemonic, Signature: string; const Operands: array of TOperand); static;
  public
    class procedure Validate(FormIndex: Integer; const Operands: array of TOperand); overload; static;
    class procedure Validate(const Mnemonic: string; const Operands: array of TOperand); overload; static;
  end;

implementation

class function TAsmRuleValidator.RequiredMemoryAlignment(const Mnemonic: string): Byte;
begin
  if SameText(Mnemonic, 'movaps') or SameText(Mnemonic, 'movapd') or SameText(Mnemonic, 'movdqa') then Exit(16);
  Result := 0;
end;

class procedure TAsmRuleValidator.ValidateAlignment(const Mnemonic, Signature: string; const Operands: array of TOperand);
var
  Required: Byte;
  I: Integer;
begin
  Required := RequiredMemoryAlignment(Mnemonic);
  if Required = 0 then Exit;
  for I := 0 to High(Operands) do
    if Operands[I].Kind = otMem then
    begin
      if Operands[I].Mem.Alignment = 0 then
        raise ENativeAsmRuleViolation.CreateFmt('%s requires %d-byte aligned memory; operand alignment is unknown', [Signature, Required]);
      if Operands[I].Mem.Alignment < Required then
        raise ENativeAsmRuleViolation.CreateFmt('%s requires %d-byte aligned memory; operand guarantees only %d-byte alignment', [Signature, Required, Operands[I].Mem.Alignment]);
    end;
end;

class procedure TAsmRuleValidator.Validate(FormIndex: Integer; const Operands: array of TOperand);
var
  D: PEncodingDescriptor;
  Mnemonic: string;
begin
  D := TInstructionDb.Form(FormIndex);
  if (D^.ExtensionMask and (DB_EXT_SSE or DB_EXT_SSE2)) = 0 then Exit;
  Mnemonic := TInstructionDb.MnemonicName(D^.MnemonicIndex);
  ValidateAlignment(Mnemonic, TInstructionDb.SourceSignature(FormIndex), Operands);
end;

class procedure TAsmRuleValidator.Validate(const Mnemonic: string; const Operands: array of TOperand);
begin
  ValidateAlignment(Mnemonic, UpperCase(Mnemonic), Operands);
end;

end.
