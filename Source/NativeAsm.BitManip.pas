{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
unit NativeAsm.BitManip;

{$ALIGN ON}
{$MINENUMSIZE 4}

interface

uses
  NativeAsm.Builder,
  NativeAsm.Types;

type
  TBitManipEncoder = class sealed
  public
    class function Lzcnt(Builder: TAsmBuilder; Dest: TRegister; Src: TOperand): TAsmBuilder; static;
    class function Tzcnt(Builder: TAsmBuilder; Dest: TRegister; Src: TOperand): TAsmBuilder; static;
  end;

implementation

uses
  System.SysUtils,
  NativeAsm.Simd.Types,
  NativeAsm.Simd.Encoder;

function ToExtOperand(const O: TOperand): TSimdOperand;
begin
  case O.Kind of
    otReg: Result := O.Reg;
    otMem: Result := O.Mem;
  else
    raise EArgumentException.Create('LZCNT/TZCNT source must be a register or memory operand');
  end;
end;

class function TBitManipEncoder.Lzcnt(Builder: TAsmBuilder; Dest: TRegister; Src: TOperand): TAsmBuilder;
var D, S: TSimdOperand;
begin
  if Builder = nil then raise EArgumentNilException.Create('Builder');
  D := Dest;
  S := ToExtOperand(Src);
  TSimdInstructionEncoder.Encode(Builder, 'lzcnt', [D, S]);
  Result := Builder;
end;

class function TBitManipEncoder.Tzcnt(Builder: TAsmBuilder; Dest: TRegister; Src: TOperand): TAsmBuilder;
var D, S: TSimdOperand;
begin
  if Builder = nil then raise EArgumentNilException.Create('Builder');
  D := Dest;
  S := ToExtOperand(Src);
  TSimdInstructionEncoder.Encode(Builder, 'tzcnt', [D, S]);
  Result := Builder;
end;

end.
