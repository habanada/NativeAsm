{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
program NativeAsmDisassemblerDemo;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  NativeAsm.Types in '..\..\Source\NativeAsm.Types.pas',
  NativeAsm.InstructionDB in '..\..\Source\NativeAsm.InstructionDB.pas',
  NativeAsm.InstructionDB.Generated in '..\..\Source\NativeAsm.InstructionDB.Generated.pas',
  NativeAsm.Encoder in '..\..\Source\NativeAsm.Encoder.pas',
  NativeAsm.Builder in '..\..\Source\NativeAsm.Builder.pas',
  NativeAsm.Disassembler in '..\..\Source\NativeAsm.Disassembler.pas';

procedure PrintDetails(const Info: TNativeAsmDisasmInstruction);
begin
  Writeln(TNativeAsmDisassembler.FormatInstruction(Info));
  if Info.FormIndex >= 0 then
  begin
    Writeln('  FormIndex       : ', Info.FormIndex);
    Writeln('  SourceSignature : ', Info.SourceSignature);
    Writeln('  SourceEncoding  : ', Info.SourceEncoding);
    Writeln('  NativeSupport   : ', Ord(Info.NativeSupport));
    Writeln('  Restriction     : ', Ord(Info.NativeRestriction));
    Writeln('  Canonicalization: ', Ord(Info.NativeCanonicalization));
    Writeln('  Candidates      : ', Info.CandidateCount);
    if Info.HasTarget then Writeln('  Target          : $', IntToHex(Info.TargetAddress, 16));
  end;
end;

var
  B: TAsmBuilder;
  Code, SourceOnly: TBytes;
  Items: TArray<TNativeAsmDisasmInstruction>;
  I: Integer;
begin
  Writeln('NativeAsm InstructionDB Disassembler Demo');
  Writeln('=========================================');
  Writeln('DB mnemonics: ', TInstructionDb.MnemonicCount);
  Writeln('DB forms    : ', TInstructionDb.FormCount);
  Writeln;
  B := TAsmBuilder.New;
  try
    B.Label_('entry').Mov(RAX, RCX).Cmp(RAX, RDX).J(cond_JGE, 'have_max').Mov(RAX, RDX).Label_('have_max').Add(RAX, 1).Ret;
    Code := B.Build;
  finally
    B.Free;
  end;
  Writeln('Builder-generated code');
  Writeln('----------------------');
  Items := TNativeAsmDisassembler.DecodeAll(Code, $0000018000000000);
  for I := 0 to High(Items) do PrintDetails(Items[I]);
  Writeln;
  Writeln('Source-only InstructionDB form');
  Writeln('------------------------------');
  SetLength(SourceOnly, 2);
  SourceOnly[0] := $0F;
  SourceOnly[1] := $C8;
  if TNativeAsmDisassembler.DecodeOne(SourceOnly, $0000018000001000, 0, Items[0]) then PrintDetails(Items[0]);
  Writeln;
  Writeln('The last instruction is decoded from the InstructionDB even though NativeASM does not expose that form through the public builder API.');
end.
