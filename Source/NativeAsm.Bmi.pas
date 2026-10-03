unit NativeAsm.Bmi;

{$ALIGN ON}
{$MINENUMSIZE 4}

interface

uses
  NativeAsm.Builder,
  NativeAsm.Types,
  NativeAsm.Avx;

type
  TAsmBmiHelper = class helper(TAsmAvxHelper) for TAsmBuilder
  public
    function Bmi(const Mnemonic: string; const Operands: array of TOperand): TAsmBuilder;
{$I NativeAsm.Bmi.Api.Declarations.inc}
  end;

implementation

uses
  NativeAsm.Bmi.Encoder;

function TAsmBmiHelper.Bmi(const Mnemonic: string; const Operands: array of TOperand): TAsmBuilder;
begin
  TBmiInstructionEncoder.Encode(Self, Mnemonic, Operands);
  Result := Self;
end;

{$I NativeAsm.Bmi.Api.Implementation.inc}

end.
