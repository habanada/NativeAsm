unit NativeAsm.Avx2.Tests.Support;

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  NativeAsm.Types,
  NativeAsm.Builder,
  NativeAsm.Extensions,
  NativeAsm.Simd.Types,
  NativeAsm.Avx.Types,
  NativeAsm.Avx.Encoder;

type
  TAvx2OperandArray = array of TAvxOperand;
  TUInt8x32 = array[0..31] of Byte;
  TInt8x32 = array[0..31] of ShortInt;
  TUInt16x16 = array[0..15] of Word;
  TInt16x16 = array[0..15] of SmallInt;
  TUInt32x8 = array[0..7] of Cardinal;
  TInt32x8 = array[0..7] of Integer;
  TUInt64x4 = array[0..3] of UInt64;
  TInt64x4 = array[0..3] of Int64;

function AvxOp(const R: TSimdRegister): TAvxOperand; overload;
function AvxOp(const R: TAvxYmmRegister): TAvxOperand; overload;
function AvxOp(const R: TRegister): TAvxOperand; overload;
function AvxOp(const M: TAvxMemory): TAvxOperand; overload;
function AvxOp(const M: TMemory): TAvxOperand; overload;
function AvxOp(I: Integer): TAvxOperand; overload;
function HexOf(const Data: TBytes): string;
function NormalizeHex(const Value: string): string;
procedure CheckAvx2Hex(const Name, Mnemonic: string; const Operands: array of TAvxOperand; const Expected: string);
function Avx2Available: Boolean;
function NextRandom(var State: Cardinal): Cardinal;
function SatS8(Value: Integer): ShortInt;
function SatU8(Value: Integer): Byte;
function SatS16(Value: Integer): SmallInt;
function SatU16(Value: Integer): Word;

implementation

uses
  NativeAsm.Avx.Cpu;

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

function HexOf(const Data: TBytes): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(Data) do
  begin
    if I > 0 then
      Result := Result + ' ';
    Result := Result + IntToHex(Data[I], 2);
  end;
end;

function NormalizeHex(const Value: string): string;
begin
  Result := UpperCase(StringReplace(StringReplace(StringReplace(Value, '-', ' ', [rfReplaceAll]), ':', ' ', [rfReplaceAll]), '  ', ' ', [rfReplaceAll]));
  Result := Trim(Result);
  while Pos('  ', Result) > 0 do
    Result := StringReplace(Result, '  ', ' ', [rfReplaceAll]);
end;

procedure CheckAvx2Hex(const Name, Mnemonic: string; const Operands: array of TAvxOperand; const Expected: string);
var
  B: TAsmBuilder;
  Actual: TBytes;
  ActualHex: string;
  ExpectedHex: string;
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

function Avx2Available: Boolean;
var
  Status: TAvxCpuStatus;
begin
  Status := TAvxCpuFeatures.Query;
  Result := Status.Avx2Usable;
end;

function NextRandom(var State: Cardinal): Cardinal;
begin
  State := Cardinal((UInt64(State) * UInt64(1664525) + UInt64(1013904223)) and UInt64($FFFFFFFF));
  Result := State;
end;

function SatS8(Value: Integer): ShortInt;
begin
  if Value > 127 then
    Exit(127);
  if Value < -128 then
    Exit(-128);
  Result := ShortInt(Value);
end;

function SatU8(Value: Integer): Byte;
begin
  if Value > 255 then
    Exit(255);
  if Value < 0 then
    Exit(0);
  Result := Byte(Value);
end;

function SatS16(Value: Integer): SmallInt;
begin
  if Value > 32767 then
    Exit(32767);
  if Value < -32768 then
    Exit(-32768);
  Result := SmallInt(Value);
end;

function SatU16(Value: Integer): Word;
begin
  if Value > 65535 then
    Exit(65535);
  if Value < 0 then
    Exit(0);
  Result := Word(Value);
end;

end.
