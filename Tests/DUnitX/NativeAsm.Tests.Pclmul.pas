{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
unit NativeAsm.Tests.Pclmul;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TPclmulTests = class
  public
    [Test] procedure DatabaseContainsPclmul;
    [Test] procedure RegisterEncoding;
    [Test] procedure MemoryEncoding;
    [Test] procedure InvalidOperandsAreRejected;
  end;

implementation

uses
  System.SysUtils,
  NativeAsm.Types,
  NativeAsm.Builder,
  NativeAsm.Simd,
  NativeAsm.Simd.Types,
  NativeAsm.Simd.Db;

function HexOf(const Data: TBytes): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(Data) do Result := Result + IntToHex(Data[I], 2);
end;

procedure TPclmulTests.DatabaseContainsPclmul;
var
  M, F: Integer;
  D: PSimdEncodingDescriptor;
begin
  M := TSimdInstructionDb.MnemonicIndexOf('pclmulqdq');
  Assert.IsTrue(M >= 0);
  Assert.IsTrue(TSimdInstructionDb.MnemonicFormCount(M) = 1);
  F := TSimdInstructionDb.MnemonicFormIndex(M, 0);
  D := TSimdInstructionDb.Form(F);
  Assert.IsTrue(D^.Extension = sePCLMULQDQ);
  Assert.IsTrue(TSimdInstructionDb.SourceSignature(F) = 'pclmulqdq X:xmm, xmm/m128, imm8');
end;

procedure TPclmulTests.RegisterEncoding;
var
  B: TAsmBuilder;
  Code: TBytes;
begin
  B := TAsmBuilder.Create;
  try
    B.Pclmulqdq(XMM1, XMM2, $11);
    Code := B.Build;
    Assert.IsTrue(HexOf(Code) = '660F3A44CA11');
  finally
    B.Free;
  end;
end;

procedure TPclmulTests.MemoryEncoding;
var
  B: TAsmBuilder;
  Code: TBytes;
begin
  B := TAsmBuilder.Create;
  try
    B.Pclmulqdq(XMM9, NativeAsm.Simd.Types.OWordPtrSib(ridR12, ridR13, s4, 64), 0);
    Code := B.Build;
    Assert.IsTrue(HexOf(Code) = '66470F3A444CAC4000');
  finally
    B.Free;
  end;
end;

procedure TPclmulTests.InvalidOperandsAreRejected;
var
  B: TAsmBuilder;
  Raised: Boolean;
begin
  B := TAsmBuilder.Create;
  try
    Raised := False;
    try
      B.Pclmulqdq(RAX, XMM1, 0);
    except
      on E: Exception do Raised := True;
    end;
    Assert.IsTrue(Raised);
  finally
    B.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TPclmulTests);

end.
