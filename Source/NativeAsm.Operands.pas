{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
unit NativeAsm.Operands;

{$ALIGN ON}
{$MINENUMSIZE 4}

interface

uses
  NativeAsm.Types;

function OWordPtr(Base: TRegID; Disp: Integer = 0): TMemory; inline;
function AlignedWordPtr(Base: TRegID; Disp: Integer = 0): TMemory; inline;
function AlignedDWordPtr(Base: TRegID; Disp: Integer = 0): TMemory; inline;
function AlignedQWordPtr(Base: TRegID; Disp: Integer = 0): TMemory; inline;
function AlignedOWordPtr(Base: TRegID; Disp: Integer = 0): TMemory; inline;

implementation

function OWordPtr(Base: TRegID; Disp: Integer): TMemory;
begin
  Result := TMemory.Create(Base, Disp, sz128);
end;

function AlignedWordPtr(Base: TRegID; Disp: Integer): TMemory;
begin
  Result := WordPtr(Base, Disp);
  Result.Alignment := 2;
end;

function AlignedDWordPtr(Base: TRegID; Disp: Integer): TMemory;
begin
  Result := DWordPtr(Base, Disp);
  Result.Alignment := 4;
end;

function AlignedQWordPtr(Base: TRegID; Disp: Integer): TMemory;
begin
  Result := QWordPtr(Base, Disp);
  Result.Alignment := 8;
end;

function AlignedOWordPtr(Base: TRegID; Disp: Integer): TMemory;
begin
  Result := OWordPtr(Base, Disp);
  Result.Alignment := 16;
end;

end.
