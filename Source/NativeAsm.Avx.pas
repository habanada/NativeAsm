unit NativeAsm.Avx;

{$ALIGN ON}
{$MINENUMSIZE 4}

interface

uses
  NativeAsm.Builder,
  NativeAsm.Avx.Types,
  NativeAsm.Simd;

type
  TAsmAvxHelper = class helper(TAsmSimdHelper) for TAsmBuilder
  public
    function Avx(const Mnemonic: string; const Operands: array of TAvxOperand): TAsmBuilder;
{$I NativeAsm.Avx.Api.Declarations.inc}
  end;

implementation

uses
  NativeAsm.Avx.Encoder;

function TAsmAvxHelper.Avx(const Mnemonic: string; const Operands: array of TAvxOperand): TAsmBuilder;
begin
  TAvxInstructionEncoder.Encode(Self, Mnemonic, Operands);
  Result := Self;
end;

{$I NativeAsm.Avx.Api.Implementation.inc}

end.
