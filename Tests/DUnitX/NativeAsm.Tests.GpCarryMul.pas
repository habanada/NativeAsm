{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
unit NativeAsm.Tests.GpCarryMul;

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  NativeAsm.Types,
  NativeAsm.Builder,
  NativeAsm.Extensions;

type
  [TestFixture]
  TGpCarryMulTests = class
  private
    class procedure AssertBytes(const Actual: TBytes; const Expected: array of Byte); static;
  public
    [Test] procedure AdcEncoding;
    [Test] procedure SbbEncoding;
    [Test] procedure MulEncoding;
    [Test] procedure MemoryOperandEncodings;
    [Test] procedure AdcExecution;
    [Test] procedure SbbExecution;
    [Test] procedure MulExecution;
  end;

implementation

class procedure TGpCarryMulTests.AssertBytes(const Actual: TBytes; const Expected: array of Byte);
var
  I: Integer;
begin
  Assert.AreEqual(Length(Expected), Length(Actual));
  for I := 0 to High(Expected) do Assert.AreEqual(Expected[I], Actual[I], 'Byte ' + IntToStr(I));
end;

procedure TGpCarryMulTests.AdcEncoding;
var
  B: TAsmBuilder;
  Code: TBytes;
begin
  B := TAsmBuilder.Create;
  try
    B.Adc(RAX, RDX);
    Code := B.Build;
    AssertBytes(Code, [$48, $13, $C2]);
  finally
    B.Free;
  end;
end;

procedure TGpCarryMulTests.SbbEncoding;
var
  B: TAsmBuilder;
  Code: TBytes;
begin
  B := TAsmBuilder.Create;
  try
    B.Sbb(R9, R10);
    Code := B.Build;
    AssertBytes(Code, [$4D, $1B, $CA]);
  finally
    B.Free;
  end;
end;

procedure TGpCarryMulTests.MulEncoding;
var
  B: TAsmBuilder;
  Code: TBytes;
begin
  B := TAsmBuilder.Create;
  try
    B.Mul(R8);
    Code := B.Build;
    AssertBytes(Code, [$49, $F7, $E0]);
  finally
    B.Free;
  end;
end;


procedure TGpCarryMulTests.MemoryOperandEncodings;
var
  B: TAsmBuilder;
  Code: TBytes;
begin
  B := TAsmBuilder.Create;
  try
    B.Adc(RAX, QWordPtr(ridR11, 16)).Sbb(R9, QWordPtr(ridR10, 24)).Mul(QWordPtr(ridR11, 16));
    Code := B.Build;
    AssertBytes(Code, [$49, $13, $43, $10, $4D, $1B, $4A, $18, $49, $F7, $63, $10]);
  finally
    B.Free;
  end;
end;

procedure TGpCarryMulTests.AdcExecution;
var
  B: TAsmBuilder;
  Code: TExecutableCode;
begin
  B := TAsmBuilder.Create;
  try
    B.Mov(RAX, -1).Mov(RDX, 1).Add(RAX, RDX).Mov(R9, 5).Adc(R9, 0).Mov(RAX, R9).Ret;
    Code := TExecutableCode.FromBuilder(B);
  finally
    B.Free;
  end;
  try
    Assert.IsTrue(Code.Run = 6);
  finally
    Code.Free;
  end;
end;

procedure TGpCarryMulTests.SbbExecution;
var
  B: TAsmBuilder;
  Code: TExecutableCode;
begin
  B := TAsmBuilder.Create;
  try
    B.Xor_(RAX, RAX).Mov(RDX, 1).Sub(RAX, RDX).Mov(R9, 5).Sbb(R9, 0).Mov(RAX, R9).Ret;
    Code := TExecutableCode.FromBuilder(B);
  finally
    B.Free;
  end;
  try
    Assert.IsTrue(Code.Run = 4);
  finally
    Code.Free;
  end;
end;

procedure TGpCarryMulTests.MulExecution;
var
  B: TAsmBuilder;
  Code: TExecutableCode;
begin
  B := TAsmBuilder.Create;
  try
    B.Mov(RAX, -1).Mov(R8, 2).Mul(R8).Mov(RAX, RDX).Ret;
    Code := TExecutableCode.FromBuilder(B);
  finally
    B.Free;
  end;
  try
    Assert.IsTrue(Code.Run = 1);
  finally
    Code.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TGpCarryMulTests);

end.
