{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
program NativeAsmAesBitCountDemo;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  NativeAsm.Types,
  NativeAsm.Builder,
  NativeAsm.Debug,
  NativeAsm.Simd.Types,
  NativeAsm.Simd,
  NativeAsm.BitManip;

procedure Show(const Name: string; B: TAsmBuilder);
var Code: TBytes;
begin
  try
    Code := B.Build;
    Writeln(Name);
    Writeln(TAsmDumper.HexDump(Code, 0));
  finally
    B.Free;
  end;
end;

begin
  try
    Writeln('NativeAsm AES-NI and bit-count extension demo');
    Writeln('============================================');
    Show('AESENC xmm1, xmm2', TAsmBuilder.New.Aesenc(XMM1, XMM2));
    Show('AESKEYGENASSIST xmm9, [r12+r13*4+64], 55h', TAsmBuilder.New.Aeskeygenassist(XMM9, OWordPtrSib(ridR12, ridR13, s4, 64), $55));
    Show('LZCNT rcx, rdx', TAsmBuilder.New.Lzcnt(RCX, RDX));
    Show('LZCNT r9, r10', TAsmBuilder.New.Lzcnt(R9, R10));
    Show('TZCNT rcx, qword ptr [rdx]', TAsmBuilder.New.Tzcnt(RCX, QWordPtr(ridRDX)));
  except
    on E: Exception do
    begin
      Writeln(E.ClassName + ': ' + E.Message);
      ExitCode := 1;
    end;
  end;
end.
