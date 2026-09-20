{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
unit NativeAsm.Simd;

{$ALIGN ON}
{$MINENUMSIZE 4}

interface

uses
  NativeAsm.Builder,
  NativeAsm.Types,
  NativeAsm.Simd.Types;

type
  TAsmSimdHelper = class helper for TAsmBuilder
  public
    function Simd(const Mnemonic: string; const Operands: array of TSimdOperand): TAsmBuilder;
    function Lzcnt(Dest: TRegister; Src: TOperand): TAsmBuilder;
    function Tzcnt(Dest: TRegister; Src: TOperand): TAsmBuilder;
{$I NativeAsm.Simd.Api.Declarations.inc}
  end;

implementation

uses
  NativeAsm.Simd.Encoder,
  NativeAsm.BitManip;

function TAsmSimdHelper.Simd(const Mnemonic: string; const Operands: array of TSimdOperand): TAsmBuilder;
begin
  TSimdInstructionEncoder.Encode(Self, Mnemonic, Operands);
  Result := Self;
end;

function TAsmSimdHelper.Lzcnt(Dest: TRegister; Src: TOperand): TAsmBuilder;
begin
  Result := TBitManipEncoder.Lzcnt(Self, Dest, Src);
end;

function TAsmSimdHelper.Tzcnt(Dest: TRegister; Src: TOperand): TAsmBuilder;
begin
  Result := TBitManipEncoder.Tzcnt(Self, Dest, Src);
end;

{$I NativeAsm.Simd.Api.Implementation.inc}

end.
