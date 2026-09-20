{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
program NativeAsmDisasm;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.IOUtils,
  NativeAsm.InstructionDB in '..\Source\NativeAsm.InstructionDB.pas',
  NativeAsm.InstructionDB.Generated in '..\Source\NativeAsm.InstructionDB.Generated.pas',
  NativeAsm.Types in '..\Source\NativeAsm.Types.pas',
  NativeAsm.Disassembler in '..\Source\NativeAsm.Disassembler.pas';

function ParseBase(const S: string): NativeUInt;
var V: UInt64; T: string;
begin
  T := Trim(S);
  if T = '' then Exit(0);
  if Copy(T, 1, 1) = '$' then T := Copy(T, 2, MaxInt)
  else if SameText(Copy(T, 1, 2), '0x') then T := Copy(T, 3, MaxInt);
  if not TryStrToUInt64('$' + T, V) then raise EConvertError.CreateFmt('Invalid base address: %s', [S]);
  Result := NativeUInt(V);
end;

function SupportText(Value: TNativeSupport): string;
begin
  case Value of
    nsSupported: Result := 'supported';
    nsPartial: Result := 'partial';
    nsSourceOnly: Result := 'source-only';
  else
    Result := '?';
  end;
end;

var
  FileName: string;
  BaseAddress: NativeUInt;
  ShowMeta: Boolean;
  Code: TBytes;
  Items: TArray<TNativeAsmDisasmInstruction>;
  I: Integer;
begin
  try
    if ParamCount < 1 then
    begin
      Writeln('Usage: NativeAsmDisasm <file.bin> [base-address] [/meta]');
      Halt(1);
    end;
    FileName := ParamStr(1);
    BaseAddress := 0;
    ShowMeta := False;
    if (ParamCount >= 2) and not SameText(ParamStr(2), '/meta') then BaseAddress := ParseBase(ParamStr(2));
    for I := 2 to ParamCount do if SameText(ParamStr(I), '/meta') then ShowMeta := True;
    Code := TFile.ReadAllBytes(FileName);
    Items := TNativeAsmDisassembler.DecodeAll(Code, BaseAddress);
    Writeln('NativeAsm InstructionDB Disassembler');
    Writeln('File      : ', FileName);
    Writeln('Size      : ', Length(Code), ' bytes');
    Writeln('Base      : $', IntToHex(BaseAddress, SizeOf(Pointer) * 2));
    Writeln('DB        : ', TInstructionDb.MnemonicCount, ' mnemonics / ', TInstructionDb.FormCount, ' forms');
    Writeln;
    for I := 0 to High(Items) do
    begin
      Writeln(TNativeAsmDisassembler.FormatInstruction(Items[I]));
      if ShowMeta and (Items[I].FormIndex >= 0) then
      begin
        Writeln('          form=', Items[I].FormIndex, ' support=', SupportText(Items[I].NativeSupport), ' candidates=', Items[I].CandidateCount);
        Writeln('          signature=', Items[I].SourceSignature);
        Writeln('          encoding=', Items[I].SourceEncoding);
      end;
    end;
  except
    on E: Exception do
    begin
      Writeln(E.ClassName, ': ', E.Message);
      Halt(2);
    end;
  end;
end.
