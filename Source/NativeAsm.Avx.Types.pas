unit NativeAsm.Avx.Types;

{$ALIGN ON}
{$MINENUMSIZE 4}

interface

uses
  System.SysUtils,
  NativeAsm.Types,
  NativeAsm.Simd.Types;

type
  EAvxError = class(Exception);

  TAvxYmmRegister = record
    ID: Byte;
    function IsValid: Boolean; inline;
    function IsExtended: Boolean; inline;
  end;

  TAvxMemSize = (amsUnspecified, ams8, ams16, ams32, ams64, ams128, ams256);
  TAvxVsibIndexKind = (avikNone, avikXmm, avikYmm);

  TAvxVsibMemory = record
    HasBase: Boolean;
    Base: TRegID;
    IndexKind: TAvxVsibIndexKind;
    IndexID: Byte;
    Scale: TScale;
    Disp: Integer;
    IndexSize: TAvxMemSize;
  end;

  TAvxMemory = record
    Address: TMemory;
    Size: TAvxMemSize;
    Vsib: TAvxVsibMemory;
    class function Create(Base: TRegID; Disp: Integer = 0; ASize: TAvxMemSize = amsUnspecified): TAvxMemory; static;
    class function CreateSib(Base, Index: TRegID; Scale: TScale; Disp: Integer = 0; ASize: TAvxMemSize = amsUnspecified): TAvxMemory; static;
    class function CreateRip(Disp: Integer = 0; ASize: TAvxMemSize = amsUnspecified): TAvxMemory; static;
    class function CreateVsib(Base: TRegID; Index: TSimdRegister; Scale: TScale; Disp: Integer; IndexSize: TAvxMemSize): TAvxMemory; overload; static;
    class function CreateVsib(Base: TRegID; Index: TAvxYmmRegister; Scale: TScale; Disp: Integer; IndexSize: TAvxMemSize): TAvxMemory; overload; static;
    class function CreateVsibNoBase(Index: TSimdRegister; Scale: TScale; Disp: Integer; IndexSize: TAvxMemSize): TAvxMemory; overload; static;
    class function CreateVsibNoBase(Index: TAvxYmmRegister; Scale: TScale; Disp: Integer; IndexSize: TAvxMemSize): TAvxMemory; overload; static;
    class function FromMemory(const M: TMemory): TAvxMemory; static;
    function IsVsib: Boolean; inline;
  end;

  TAvxOperandKind = (aokNone, aokXmmReg, aokYmmReg, aokMem, aokImm, aokGprReg);

  TAvxOperand = record
    Kind: TAvxOperandKind;
    XmmReg: TSimdRegister;
    YmmReg: TAvxYmmRegister;
    GprReg: TRegister;
    Mem: TAvxMemory;
    Imm: Int64;
    class operator Implicit(const R: TSimdRegister): TAvxOperand; inline;
    class operator Implicit(const R: TAvxYmmRegister): TAvxOperand; inline;
    class operator Implicit(const R: TRegister): TAvxOperand; inline;
    class operator Implicit(const M: TAvxMemory): TAvxOperand; inline;
    class operator Implicit(const M: TSimdMemory): TAvxOperand; inline;
    class operator Implicit(const M: TMemory): TAvxOperand; inline;
    class operator Implicit(I: Integer): TAvxOperand; inline;
    class operator Implicit(I: Int64): TAvxOperand; inline;
  end;

const
  YMM0: TAvxYmmRegister = (ID: 0);
  YMM1: TAvxYmmRegister = (ID: 1);
  YMM2: TAvxYmmRegister = (ID: 2);
  YMM3: TAvxYmmRegister = (ID: 3);
  YMM4: TAvxYmmRegister = (ID: 4);
  YMM5: TAvxYmmRegister = (ID: 5);
  YMM6: TAvxYmmRegister = (ID: 6);
  YMM7: TAvxYmmRegister = (ID: 7);
  YMM8: TAvxYmmRegister = (ID: 8);
  YMM9: TAvxYmmRegister = (ID: 9);
  YMM10: TAvxYmmRegister = (ID: 10);
  YMM11: TAvxYmmRegister = (ID: 11);
  YMM12: TAvxYmmRegister = (ID: 12);
  YMM13: TAvxYmmRegister = (ID: 13);
  YMM14: TAvxYmmRegister = (ID: 14);
  YMM15: TAvxYmmRegister = (ID: 15);

function XmmWordPtr(Base: TRegID; Disp: Integer = 0): TAvxMemory; inline;
function XmmWordPtrSib(Base, Index: TRegID; Scale: TScale; Disp: Integer = 0): TAvxMemory; inline;
function XmmWordPtrRip(Disp: Integer = 0): TAvxMemory; inline;
function YmmWordPtr(Base: TRegID; Disp: Integer = 0): TAvxMemory; inline;
function YmmWordPtrSib(Base, Index: TRegID; Scale: TScale; Disp: Integer = 0): TAvxMemory; inline;
function YmmWordPtrRip(Disp: Integer = 0): TAvxMemory; inline;
function Vm32x(Base: TRegID; Index: TSimdRegister; Scale: TScale = s1; Disp: Integer = 0): TAvxMemory; inline;
function Vm32y(Base: TRegID; Index: TAvxYmmRegister; Scale: TScale = s1; Disp: Integer = 0): TAvxMemory; inline;
function Vm64x(Base: TRegID; Index: TSimdRegister; Scale: TScale = s1; Disp: Integer = 0): TAvxMemory; inline;
function Vm64y(Base: TRegID; Index: TAvxYmmRegister; Scale: TScale = s1; Disp: Integer = 0): TAvxMemory; inline;
function Vm32xNoBase(Index: TSimdRegister; Scale: TScale = s1; Disp: Integer = 0): TAvxMemory; inline;
function Vm32yNoBase(Index: TAvxYmmRegister; Scale: TScale = s1; Disp: Integer = 0): TAvxMemory; inline;
function Vm64xNoBase(Index: TSimdRegister; Scale: TScale = s1; Disp: Integer = 0): TAvxMemory; inline;
function Vm64yNoBase(Index: TAvxYmmRegister; Scale: TScale = s1; Disp: Integer = 0): TAvxMemory; inline;

implementation

function TAvxYmmRegister.IsValid: Boolean;
begin
  Result := ID <= 15;
end;

function TAvxYmmRegister.IsExtended: Boolean;
begin
  Result := ID >= 8;
end;

class function TAvxMemory.Create(Base: TRegID; Disp: Integer; ASize: TAvxMemSize): TAvxMemory;
begin
  Result := Default(TAvxMemory);
  Result.Address := TMemory.Create(Base, Disp);
  Result.Size := ASize;
end;

class function TAvxMemory.CreateSib(Base, Index: TRegID; Scale: TScale; Disp: Integer; ASize: TAvxMemSize): TAvxMemory;
begin
  Result := Default(TAvxMemory);
  Result.Address := TMemory.CreateSib(Base, Index, Scale, Disp);
  Result.Size := ASize;
end;

class function TAvxMemory.CreateRip(Disp: Integer; ASize: TAvxMemSize): TAvxMemory;
begin
  Result := Default(TAvxMemory);
  Result.Address := TMemory.CreateRip(Disp);
  Result.Size := ASize;
end;

class function TAvxMemory.CreateVsib(Base: TRegID; Index: TSimdRegister; Scale: TScale; Disp: Integer; IndexSize: TAvxMemSize): TAvxMemory;
begin
  if Base = ridRIP then raise EArgumentException.Create('VSIB base cannot be RIP');
  if (Index.Kind <> srkXmm) or not Index.IsValid then raise EArgumentException.Create('VSIB XMM index is invalid');
  if not (IndexSize in [ams32, ams64]) then raise EArgumentException.Create('VSIB index size must be 32 or 64 bits');
  Result := Default(TAvxMemory);
  Result.Size := amsUnspecified;
  Result.Vsib.HasBase := True;
  Result.Vsib.Base := Base;
  Result.Vsib.IndexKind := avikXmm;
  Result.Vsib.IndexID := Index.ID;
  Result.Vsib.Scale := Scale;
  Result.Vsib.Disp := Disp;
  Result.Vsib.IndexSize := IndexSize;
end;

class function TAvxMemory.CreateVsib(Base: TRegID; Index: TAvxYmmRegister; Scale: TScale; Disp: Integer; IndexSize: TAvxMemSize): TAvxMemory;
begin
  if Base = ridRIP then raise EArgumentException.Create('VSIB base cannot be RIP');
  if not Index.IsValid then raise EArgumentException.Create('VSIB YMM index is invalid');
  if not (IndexSize in [ams32, ams64]) then raise EArgumentException.Create('VSIB index size must be 32 or 64 bits');
  Result := Default(TAvxMemory);
  Result.Size := amsUnspecified;
  Result.Vsib.HasBase := True;
  Result.Vsib.Base := Base;
  Result.Vsib.IndexKind := avikYmm;
  Result.Vsib.IndexID := Index.ID;
  Result.Vsib.Scale := Scale;
  Result.Vsib.Disp := Disp;
  Result.Vsib.IndexSize := IndexSize;
end;

class function TAvxMemory.CreateVsibNoBase(Index: TSimdRegister; Scale: TScale; Disp: Integer; IndexSize: TAvxMemSize): TAvxMemory;
begin
  Result := CreateVsib(ridRAX, Index, Scale, Disp, IndexSize);
  Result.Vsib.HasBase := False;
end;

class function TAvxMemory.CreateVsibNoBase(Index: TAvxYmmRegister; Scale: TScale; Disp: Integer; IndexSize: TAvxMemSize): TAvxMemory;
begin
  Result := CreateVsib(ridRAX, Index, Scale, Disp, IndexSize);
  Result.Vsib.HasBase := False;
end;

class function TAvxMemory.FromMemory(const M: TMemory): TAvxMemory;
begin
  Result := Default(TAvxMemory);
  Result.Address := M;
  case M.Size of
    sz8: Result.Size := ams8;
    sz16: Result.Size := ams16;
    sz32: Result.Size := ams32;
    sz64: Result.Size := ams64;
    sz128: Result.Size := ams128;
  else
    Result.Size := amsUnspecified;
  end;
end;

function TAvxMemory.IsVsib: Boolean;
begin
  Result := Vsib.IndexKind <> avikNone;
end;

class operator TAvxOperand.Implicit(const R: TSimdRegister): TAvxOperand;
begin
  Result := Default(TAvxOperand);
  Result.Kind := aokXmmReg;
  Result.XmmReg := R;
end;

class operator TAvxOperand.Implicit(const R: TAvxYmmRegister): TAvxOperand;
begin
  Result := Default(TAvxOperand);
  Result.Kind := aokYmmReg;
  Result.YmmReg := R;
end;

class operator TAvxOperand.Implicit(const R: TRegister): TAvxOperand;
begin
  Result := Default(TAvxOperand);
  Result.Kind := aokGprReg;
  Result.GprReg := R;
end;

class operator TAvxOperand.Implicit(const M: TAvxMemory): TAvxOperand;
begin
  Result := Default(TAvxOperand);
  Result.Kind := aokMem;
  Result.Mem := M;
end;

class operator TAvxOperand.Implicit(const M: TSimdMemory): TAvxOperand;
begin
  Result := Default(TAvxOperand);
  Result.Kind := aokMem;
  Result.Mem.Address := M.Address;
  case M.Size of
    sms8: Result.Mem.Size := ams8;
    sms16: Result.Mem.Size := ams16;
    sms32: Result.Mem.Size := ams32;
    sms64: Result.Mem.Size := ams64;
    sms128: Result.Mem.Size := ams128;
  else
    Result.Mem.Size := amsUnspecified;
  end;
end;

class operator TAvxOperand.Implicit(const M: TMemory): TAvxOperand;
begin
  Result := Default(TAvxOperand);
  Result.Kind := aokMem;
  Result.Mem := TAvxMemory.FromMemory(M);
end;

class operator TAvxOperand.Implicit(I: Integer): TAvxOperand;
begin
  Result := Default(TAvxOperand);
  Result.Kind := aokImm;
  Result.Imm := I;
end;

class operator TAvxOperand.Implicit(I: Int64): TAvxOperand;
begin
  Result := Default(TAvxOperand);
  Result.Kind := aokImm;
  Result.Imm := I;
end;

function XmmWordPtr(Base: TRegID; Disp: Integer): TAvxMemory;
begin
  Result := TAvxMemory.Create(Base, Disp, ams128);
end;

function XmmWordPtrSib(Base, Index: TRegID; Scale: TScale; Disp: Integer): TAvxMemory;
begin
  Result := TAvxMemory.CreateSib(Base, Index, Scale, Disp, ams128);
end;

function XmmWordPtrRip(Disp: Integer): TAvxMemory;
begin
  Result := TAvxMemory.CreateRip(Disp, ams128);
end;

function YmmWordPtr(Base: TRegID; Disp: Integer): TAvxMemory;
begin
  Result := TAvxMemory.Create(Base, Disp, ams256);
end;

function YmmWordPtrSib(Base, Index: TRegID; Scale: TScale; Disp: Integer): TAvxMemory;
begin
  Result := TAvxMemory.CreateSib(Base, Index, Scale, Disp, ams256);
end;

function YmmWordPtrRip(Disp: Integer): TAvxMemory;
begin
  Result := TAvxMemory.CreateRip(Disp, ams256);
end;

function Vm32x(Base: TRegID; Index: TSimdRegister; Scale: TScale; Disp: Integer): TAvxMemory;
begin
  Result := TAvxMemory.CreateVsib(Base, Index, Scale, Disp, ams32);
end;

function Vm32y(Base: TRegID; Index: TAvxYmmRegister; Scale: TScale; Disp: Integer): TAvxMemory;
begin
  Result := TAvxMemory.CreateVsib(Base, Index, Scale, Disp, ams32);
end;

function Vm64x(Base: TRegID; Index: TSimdRegister; Scale: TScale; Disp: Integer): TAvxMemory;
begin
  Result := TAvxMemory.CreateVsib(Base, Index, Scale, Disp, ams64);
end;

function Vm64y(Base: TRegID; Index: TAvxYmmRegister; Scale: TScale; Disp: Integer): TAvxMemory;
begin
  Result := TAvxMemory.CreateVsib(Base, Index, Scale, Disp, ams64);
end;

function Vm32xNoBase(Index: TSimdRegister; Scale: TScale; Disp: Integer): TAvxMemory;
begin
  Result := TAvxMemory.CreateVsibNoBase(Index, Scale, Disp, ams32);
end;

function Vm32yNoBase(Index: TAvxYmmRegister; Scale: TScale; Disp: Integer): TAvxMemory;
begin
  Result := TAvxMemory.CreateVsibNoBase(Index, Scale, Disp, ams32);
end;

function Vm64xNoBase(Index: TSimdRegister; Scale: TScale; Disp: Integer): TAvxMemory;
begin
  Result := TAvxMemory.CreateVsibNoBase(Index, Scale, Disp, ams64);
end;

function Vm64yNoBase(Index: TAvxYmmRegister; Scale: TScale; Disp: Integer): TAvxMemory;
begin
  Result := TAvxMemory.CreateVsibNoBase(Index, Scale, Disp, ams64);
end;

end.
