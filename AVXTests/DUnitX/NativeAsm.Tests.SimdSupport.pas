unit NativeAsm.Tests.SimdSupport;

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  NativeAsm.Types,
  NativeAsm.Builder,
  NativeAsm.Extensions,
  NativeAsm.Simd.Types,
  NativeAsm.Avx.Types,
  NativeAsm.Avx.Encoder,
  NativeAsm.Bmi.Db,
  NativeAsm.Bmi.Encoder;

type
  TAvxOperandArray = array of TAvxOperand;
  TBmiOperandArray = array of TOperand;

function XmmReg(ID: Integer): TSimdRegister;
function YmmReg(ID: Integer): TAvxYmmRegister;
function Gpr32(ID: Integer): TRegister;
function Gpr64(ID: Integer): TRegister;
function AvxOp(const R: TSimdRegister): TAvxOperand; overload;
function AvxOp(const R: TAvxYmmRegister): TAvxOperand; overload;
function AvxOp(const R: TRegister): TAvxOperand; overload;
function AvxOp(const M: TAvxMemory): TAvxOperand; overload;
function AvxOp(const M: TMemory): TAvxOperand; overload;
function AvxOp(I: Integer): TAvxOperand; overload;
function BmiOp(const R: TRegister): TOperand; overload;
function BmiOp(const M: TMemory): TOperand; overload;
function BmiOp(I: Integer): TOperand; overload;
function HexOf(const Data: TBytes): string;
function NormalizeHex(const Value: string): string;
procedure CheckBuilderHex(const Name: string; B: TAsmBuilder; const Expected: string);
procedure CheckAvxHex(const Name, Mnemonic: string; const Operands: array of TAvxOperand; const Expected: string);
procedure CheckBmiHex(const Name, Mnemonic: string; const Operands: array of TOperand; const Expected: string);
procedure ExpectAvxReject(const Name, Mnemonic: string; const Operands: array of TAvxOperand);
procedure ExpectAvxAtomicReject(const Name, Mnemonic: string; const Operands: array of TAvxOperand);
procedure ExpectBmiReject(const Name, Mnemonic: string; const Operands: array of TOperand);
procedure ExpectBmiAtomicReject(const Name, Mnemonic: string; const Operands: array of TOperand);

implementation

function XmmReg(ID: Integer): TSimdRegister;
begin
  Result := Default(TSimdRegister);
  Result.ID := Byte(ID);
  Result.Kind := srkXmm;
end;

function YmmReg(ID: Integer): TAvxYmmRegister;
begin
  Result := Default(TAvxYmmRegister);
  Result.ID := Byte(ID);
end;

function Gpr32(ID: Integer): TRegister;
begin
  Result := Default(TRegister);
  Result.ID := TRegID(ID);
  Result.RegType := rt32;
end;

function Gpr64(ID: Integer): TRegister;
begin
  Result := Default(TRegister);
  Result.ID := TRegID(ID);
  Result.RegType := rt64;
end;

function AvxOp(const R: TSimdRegister): TAvxOperand;
begin
  Result := R;
end;

function AvxOp(const R: TAvxYmmRegister): TAvxOperand;
begin
  Result := R;
end;

function AvxOp(const R: TRegister): TAvxOperand;
begin
  Result := R;
end;

function AvxOp(const M: TAvxMemory): TAvxOperand;
begin
  Result := M;
end;

function AvxOp(const M: TMemory): TAvxOperand;
begin
  Result := M;
end;

function AvxOp(I: Integer): TAvxOperand;
begin
  Result := I;
end;

function BmiOp(const R: TRegister): TOperand;
begin
  Result := R;
end;

function BmiOp(const M: TMemory): TOperand;
begin
  Result := M;
end;

function BmiOp(I: Integer): TOperand;
begin
  Result := I;
end;

function HexOf(const Data: TBytes): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(Data) do
  begin
    if I > 0 then Result := Result + ' ';
    Result := Result + IntToHex(Data[I], 2);
  end;
end;

function NormalizeHex(const Value: string): string;
begin
  Result := UpperCase(StringReplace(StringReplace(StringReplace(Value, '-', ' ', [rfReplaceAll]), ':', ' ', [rfReplaceAll]), '  ', ' ', [rfReplaceAll]));
  Result := Trim(Result);
  while Pos('  ', Result) > 0 do Result := StringReplace(Result, '  ', ' ', [rfReplaceAll]);
end;

procedure CheckBuilderHex(const Name: string; B: TAsmBuilder; const Expected: string);
var
  Actual: TBytes;
  ActualHex, ExpectedHex: string;
begin
  try
    Actual := B.Build;
    ActualHex := HexOf(Actual);
    ExpectedHex := NormalizeHex(Expected);
    Assert.IsTrue(SameText(ActualHex, ExpectedHex), Name + ': ' + ActualHex + ' <> ' + ExpectedHex);
  finally
    B.Free;
  end;
end;

procedure CheckAvxHex(const Name, Mnemonic: string; const Operands: array of TAvxOperand; const Expected: string);
var
  B: TAsmBuilder;
  Actual: TBytes;
  ActualHex, ExpectedHex: string;
begin
  B := TAsmBuilder.New;
  try
    TAvxInstructionEncoder.Encode(B, Mnemonic, Operands);
    Actual := B.Build;
    ActualHex := HexOf(Actual);
    ExpectedHex := NormalizeHex(Expected);
    Assert.IsTrue(SameText(ActualHex, ExpectedHex), Name + ': ' + ActualHex + ' <> ' + ExpectedHex);
  finally
    B.Free;
  end;
end;

procedure CheckBmiHex(const Name, Mnemonic: string; const Operands: array of TOperand; const Expected: string);
var
  B: TAsmBuilder;
  Actual: TBytes;
  ActualHex, ExpectedHex: string;
begin
  B := TAsmBuilder.New;
  try
    TBmiInstructionEncoder.Encode(B, Mnemonic, Operands);
    Actual := B.Build;
    ActualHex := HexOf(Actual);
    ExpectedHex := NormalizeHex(Expected);
    Assert.IsTrue(SameText(ActualHex, ExpectedHex), Name + ': ' + ActualHex + ' <> ' + ExpectedHex);
  finally
    B.Free;
  end;
end;

procedure ExpectAvxReject(const Name, Mnemonic: string; const Operands: array of TAvxOperand);
var
  Raised: Boolean;
begin
  Raised := False;
  try
    TAvxInstructionEncoder.SelectForm(Mnemonic, Operands);
  except
    on E: EAvxError do Raised := True;
  end;
  Assert.IsTrue(Raised, Name + ': EAvxError expected');
end;

procedure ExpectAvxAtomicReject(const Name, Mnemonic: string; const Operands: array of TAvxOperand);
var
  B: TAsmBuilder;
  Before: Integer;
  Raised: Boolean;
begin
  B := TAsmBuilder.New;
  try
    B.Nop;
    Before := B.CodeSize;
    Raised := False;
    try
      TAvxInstructionEncoder.Encode(B, Mnemonic, Operands);
    except
      on E: EAvxError do Raised := True;
    end;
    Assert.IsTrue(Raised, Name + ': EAvxError expected');
    Assert.IsTrue(B.CodeSize = Before, Name + ': failed AVX encode changed builder size');
  finally
    B.Free;
  end;
end;

procedure ExpectBmiReject(const Name, Mnemonic: string; const Operands: array of TOperand);
var
  Raised: Boolean;
begin
  Raised := False;
  try
    TBmiInstructionEncoder.SelectForm(Mnemonic, Operands);
  except
    on E: EBmiError do Raised := True;
  end;
  Assert.IsTrue(Raised, Name + ': EBmiError expected');
end;

procedure ExpectBmiAtomicReject(const Name, Mnemonic: string; const Operands: array of TOperand);
var
  B: TAsmBuilder;
  Before: Integer;
  Raised: Boolean;
begin
  B := TAsmBuilder.New;
  try
    B.Nop;
    Before := B.CodeSize;
    Raised := False;
    try
      TBmiInstructionEncoder.Encode(B, Mnemonic, Operands);
    except
      on E: EBmiError do Raised := True;
    end;
    Assert.IsTrue(Raised, Name + ': EBmiError expected');
    Assert.IsTrue(B.CodeSize = Before, Name + ': failed BMI encode changed builder size');
  finally
    B.Free;
  end;
end;

end.
