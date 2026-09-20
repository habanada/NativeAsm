unit NativeAsm.Simd.Types;

{$ALIGN ON}
{$MINENUMSIZE 4}

interface

uses
  System.SysUtils,
  NativeAsm.Types;

type
  ESimdError = class(Exception);

  TSimdRegisterKind = (srkXmm, srkMm);

  TSimdRegister = record
    ID: Byte;
    Kind: TSimdRegisterKind;
    function IsValid: Boolean; inline;
    function IsExtended: Boolean; inline;
  end;

  TSimdMemSize = (smsUnspecified, sms8, sms16, sms32, sms64, sms128);

  TSimdMemory = record
    Address: TMemory;
    Size: TSimdMemSize;
    class function Create(Base: TRegID; Disp: Integer = 0; ASize: TSimdMemSize = smsUnspecified): TSimdMemory; static;
    class function CreateSib(Base, Index: TRegID; Scale: TScale; Disp: Integer = 0; ASize: TSimdMemSize = smsUnspecified): TSimdMemory; static;
    class function CreateRip(Disp: Integer = 0; ASize: TSimdMemSize = smsUnspecified): TSimdMemory; static;
    class function FromMemory(const M: TMemory): TSimdMemory; static;
  end;

  TSimdOperandKind = (sokNone, sokSimdReg, sokGpReg, sokMem, sokImm);

  TSimdOperand = record
    Kind: TSimdOperandKind;
    SimdReg: TSimdRegister;
    GpReg: TRegister;
    Mem: TSimdMemory;
    Imm: Int64;
    class operator Implicit(const R: TSimdRegister): TSimdOperand; inline;
    class operator Implicit(const R: TRegister): TSimdOperand; inline;
    class operator Implicit(const M: TSimdMemory): TSimdOperand; inline;
    class operator Implicit(const M: TMemory): TSimdOperand; inline;
    class operator Implicit(I: Integer): TSimdOperand; inline;
    class operator Implicit(I: Int64): TSimdOperand; inline;
  end;

const
  XMM0: TSimdRegister = (ID: 0; Kind: srkXmm);
  XMM1: TSimdRegister = (ID: 1; Kind: srkXmm);
  XMM2: TSimdRegister = (ID: 2; Kind: srkXmm);
  XMM3: TSimdRegister = (ID: 3; Kind: srkXmm);
  XMM4: TSimdRegister = (ID: 4; Kind: srkXmm);
  XMM5: TSimdRegister = (ID: 5; Kind: srkXmm);
  XMM6: TSimdRegister = (ID: 6; Kind: srkXmm);
  XMM7: TSimdRegister = (ID: 7; Kind: srkXmm);
  XMM8: TSimdRegister = (ID: 8; Kind: srkXmm);
  XMM9: TSimdRegister = (ID: 9; Kind: srkXmm);
  XMM10: TSimdRegister = (ID: 10; Kind: srkXmm);
  XMM11: TSimdRegister = (ID: 11; Kind: srkXmm);
  XMM12: TSimdRegister = (ID: 12; Kind: srkXmm);
  XMM13: TSimdRegister = (ID: 13; Kind: srkXmm);
  XMM14: TSimdRegister = (ID: 14; Kind: srkXmm);
  XMM15: TSimdRegister = (ID: 15; Kind: srkXmm);

  MM0: TSimdRegister = (ID: 0; Kind: srkMm);
  MM1: TSimdRegister = (ID: 1; Kind: srkMm);
  MM2: TSimdRegister = (ID: 2; Kind: srkMm);
  MM3: TSimdRegister = (ID: 3; Kind: srkMm);
  MM4: TSimdRegister = (ID: 4; Kind: srkMm);
  MM5: TSimdRegister = (ID: 5; Kind: srkMm);
  MM6: TSimdRegister = (ID: 6; Kind: srkMm);
  MM7: TSimdRegister = (ID: 7; Kind: srkMm);

function OWordPtr(Base: TRegID; Disp: Integer = 0): TSimdMemory; inline;
function OWordPtrSib(Base, Index: TRegID; Scale: TScale; Disp: Integer = 0): TSimdMemory; inline;
function OWordPtrRip(Disp: Integer = 0): TSimdMemory; inline;

implementation

function TSimdRegister.IsValid: Boolean;
begin
  if Kind = srkXmm then Result := ID <= 15 else Result := ID <= 7;
end;

function TSimdRegister.IsExtended: Boolean;
begin
  Result := (Kind = srkXmm) and (ID >= 8);
end;

class function TSimdMemory.Create(Base: TRegID; Disp: Integer; ASize: TSimdMemSize): TSimdMemory;
begin
  Result.Address := TMemory.Create(Base, Disp);
  Result.Size := ASize;
end;

class function TSimdMemory.CreateSib(Base, Index: TRegID; Scale: TScale; Disp: Integer; ASize: TSimdMemSize): TSimdMemory;
begin
  Result.Address := TMemory.CreateSib(Base, Index, Scale, Disp);
  Result.Size := ASize;
end;

class function TSimdMemory.CreateRip(Disp: Integer; ASize: TSimdMemSize): TSimdMemory;
begin
  Result.Address := TMemory.CreateRip(Disp);
  Result.Size := ASize;
end;

class function TSimdMemory.FromMemory(const M: TMemory): TSimdMemory;
begin
  Result.Address := M;
  case M.Size of
    sz8: Result.Size := sms8;
    sz16: Result.Size := sms16;
    sz32: Result.Size := sms32;
    sz64: Result.Size := sms64;
  else
    Result.Size := smsUnspecified;
  end;
end;

class operator TSimdOperand.Implicit(const R: TSimdRegister): TSimdOperand;
begin
  Result := Default(TSimdOperand);
  Result.Kind := sokSimdReg;
  Result.SimdReg := R;
end;

class operator TSimdOperand.Implicit(const R: TRegister): TSimdOperand;
begin
  Result := Default(TSimdOperand);
  Result.Kind := sokGpReg;
  Result.GpReg := R;
end;

class operator TSimdOperand.Implicit(const M: TSimdMemory): TSimdOperand;
begin
  Result := Default(TSimdOperand);
  Result.Kind := sokMem;
  Result.Mem := M;
end;

class operator TSimdOperand.Implicit(const M: TMemory): TSimdOperand;
begin
  Result := Default(TSimdOperand);
  Result.Kind := sokMem;
  Result.Mem := TSimdMemory.FromMemory(M);
end;

class operator TSimdOperand.Implicit(I: Integer): TSimdOperand;
begin
  Result := Default(TSimdOperand);
  Result.Kind := sokImm;
  Result.Imm := I;
end;

class operator TSimdOperand.Implicit(I: Int64): TSimdOperand;
begin
  Result := Default(TSimdOperand);
  Result.Kind := sokImm;
  Result.Imm := I;
end;

function OWordPtr(Base: TRegID; Disp: Integer): TSimdMemory;
begin
  Result := TSimdMemory.Create(Base, Disp, sms128);
end;

function OWordPtrSib(Base, Index: TRegID; Scale: TScale; Disp: Integer): TSimdMemory;
begin
  Result := TSimdMemory.CreateSib(Base, Index, Scale, Disp, sms128);
end;

function OWordPtrRip(Disp: Integer): TSimdMemory;
begin
  Result := TSimdMemory.CreateRip(Disp, sms128);
end;

end.
