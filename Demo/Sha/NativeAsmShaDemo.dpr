{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
program NativeAsmShaDemo;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  NativeAsm.Types,
  NativeAsm.Builder,
  NativeAsm.Debug,
  NativeAsm.Simd.Types,
  NativeAsm.Simd;

procedure Show(const Name: string; B: TAsmBuilder);
var
  Code: TBytes;
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
    Writeln('NativeAsm SHA extension demo');
    Writeln('============================');
    Show('SHA1MSG1 xmm1, xmm2', TAsmBuilder.New.Sha1msg1(XMM1, XMM2));
    Show('SHA1MSG2 xmm1, xmm2', TAsmBuilder.New.Sha1msg2(XMM1, XMM2));
    Show('SHA1NEXTE xmm1, xmm2', TAsmBuilder.New.Sha1nexte(XMM1, XMM2));
    Show('SHA1RNDS4 xmm1, xmm2, 2', TAsmBuilder.New.Sha1rnds4(XMM1, XMM2, 2));
    Show('SHA256MSG1 xmm1, xmm2', TAsmBuilder.New.Sha256msg1(XMM1, XMM2));
    Show('SHA256MSG2 xmm1, xmm2', TAsmBuilder.New.Sha256msg2(XMM1, XMM2));
    Show('SHA256RNDS2 xmm1, xmm2', TAsmBuilder.New.Sha256rnds2(XMM1, XMM2));
    Show('SHA256RNDS2 xmm9, xmm10', TAsmBuilder.New.Sha256rnds2(XMM9, XMM10));
    Show('SHA1MSG1 xmm9, [r12+r13*4+64]', TAsmBuilder.New.Sha1msg1(XMM9, OWordPtrSib(ridR12, ridR13, s4, 64)));
  except
    on E: Exception do
    begin
      Writeln(E.ClassName + ': ' + E.Message);
      ExitCode := 1;
    end;
  end;
end.
