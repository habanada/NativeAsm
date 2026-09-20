{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
unit NativeAsm.Abi.Win64;

{$ALIGN ON}
{$MINENUMSIZE 4}

interface

uses
  System.SysUtils,
  NativeAsm.Types;

type
  TRegIDSet = set of TRegID;
  TXmmRegisterMask = UInt16;

  TWin64AbiUsage = record
    ModifiedGprs: TRegIDSet;
    SavedGprs: TRegIDSet;
    RestoredGprs: TRegIDSet;
    ModifiedXmm: TXmmRegisterMask;
    SavedXmm: TXmmRegisterMask;
    RestoredXmm: TXmmRegisterMask;
  end;

  ENativeAsmAbiViolation = class(Exception);

  TWin64AbiValidator = class sealed
  private
    class function GprName(Reg: TRegID): string; static;
  public
    class function IsVolatileGpr(Reg: TRegID): Boolean; static;
    class function RequiresPreservationGpr(Reg: TRegID): Boolean; static;
    class function IsVolatileXmm(Index: Integer): Boolean; static;
    class function RequiresPreservationXmm(Index: Integer): Boolean; static;
    class function Xmm(Index: Integer): TXmmRegisterMask; static;
    class procedure Validate(const Usage: TWin64AbiUsage); static;
  end;

implementation

class function TWin64AbiValidator.GprName(Reg: TRegID): string;
begin
  case Reg of
    ridRAX: Result := 'RAX';
    ridRCX: Result := 'RCX';
    ridRDX: Result := 'RDX';
    ridRBX: Result := 'RBX';
    ridRSP: Result := 'RSP';
    ridRBP: Result := 'RBP';
    ridRSI: Result := 'RSI';
    ridRDI: Result := 'RDI';
    ridR8: Result := 'R8';
    ridR9: Result := 'R9';
    ridR10: Result := 'R10';
    ridR11: Result := 'R11';
    ridR12: Result := 'R12';
    ridR13: Result := 'R13';
    ridR14: Result := 'R14';
    ridR15: Result := 'R15';
  else
    Result := 'GPR' + IntToStr(Ord(Reg));
  end;
end;

class function TWin64AbiValidator.IsVolatileGpr(Reg: TRegID): Boolean;
begin
  Result := Reg in [ridRAX, ridRCX, ridRDX, ridR8, ridR9, ridR10, ridR11];
end;

class function TWin64AbiValidator.RequiresPreservationGpr(Reg: TRegID): Boolean;
begin
  Result := Reg in [ridRBX, ridRBP, ridRSI, ridRDI, ridR12, ridR13, ridR14, ridR15];
end;

class function TWin64AbiValidator.IsVolatileXmm(Index: Integer): Boolean;
begin
  Result := (Index >= 0) and (Index <= 5);
end;

class function TWin64AbiValidator.RequiresPreservationXmm(Index: Integer): Boolean;
begin
  Result := (Index >= 6) and (Index <= 15);
end;

class function TWin64AbiValidator.Xmm(Index: Integer): TXmmRegisterMask;
begin
  if (Index < 0) or (Index > 15) then raise ENativeAsmAbiViolation.CreateFmt('XMM register index %d is out of range 0..15', [Index]);
  Result := TXmmRegisterMask(UInt16(1) shl Index);
end;

class procedure TWin64AbiValidator.Validate(const Usage: TWin64AbiUsage);
var
  Reg: TRegID;
  Index: Integer;
  Mask: TXmmRegisterMask;
begin
  for Reg := Low(TRegID) to High(TRegID) do
    if (Reg in Usage.ModifiedGprs) and RequiresPreservationGpr(Reg) and ((not (Reg in Usage.SavedGprs)) or (not (Reg in Usage.RestoredGprs))) then
      raise ENativeAsmAbiViolation.CreateFmt('Win64 ABI: %s is nonvolatile and must be saved and restored when modified', [GprName(Reg)]);

  for Index := 6 to 15 do
  begin
    Mask := Xmm(Index);
    if ((Usage.ModifiedXmm and Mask) <> 0) and (((Usage.SavedXmm and Mask) = 0) or ((Usage.RestoredXmm and Mask) = 0)) then
      raise ENativeAsmAbiViolation.CreateFmt('Win64 ABI: XMM%d is nonvolatile and must be saved and restored when modified', [Index]);
  end;
end;

end.
