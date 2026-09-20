{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
program NativeAsmDump;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  NativeAsm.Debug;

procedure ShowUsage;
begin
  Writeln('NativeAsmDump <file.bin> [file.map]');
  Writeln('NativeAsmDump <file.map>');
end;

procedure DumpMap(const Filename: string);
var
  Block: TAsmDebugBlock;
begin
  Block := TAsmDebugBlock.LoadMap(Filename);
  try
    Write(Block.FormatMap);
  finally
    Block.Free;
  end;
end;

procedure DumpBinary(const BinaryFile, MapFile: string);
var
  Code: TBytes;
  Block: TAsmDebugBlock;
  Instructions: TAsmInstructionMap;
  Symbols: TArray<TAsmDebugSymbol>;
  Base: UInt64;
begin
  Code := TFile.ReadAllBytes(BinaryFile);
  Base := 0;
  Block := nil;
  if MapFile <> '' then
  begin
    Block := TAsmDebugBlock.LoadMap(MapFile);
    Base := Block.BaseAddress;
  end;
  try
    Writeln(TAsmDumper.StatsText(Code));
    Write(TAsmDumper.HexDump(Code, Base));
    SetLength(Symbols, 0);
    if Block <> nil then Symbols := Block.Symbols;
    Instructions := TAsmInstructionMap.Create(Code, NativeUInt(Base), Symbols);
    try
      Writeln;
      Writeln('Instruction map:');
      Write(Instructions.FormatText);
    finally
      Instructions.Free;
    end;
    if Block <> nil then
    begin
      Writeln;
      Write(Block.FormatMap);
    end;
  finally
    Block.Free;
  end;
end;

var
  First, Second: string;
begin
  try
    if ParamCount = 0 then
    begin
      ShowUsage;
      ExitCode := 1;
      Exit;
    end;
    First := ParamStr(1);
    if not TFile.Exists(First) then
      raise Exception.Create('File not found: ' + First);
    if SameText(TPath.GetExtension(First), '.map') then
      DumpMap(First)
    else
    begin
      Second := '';
      if ParamCount > 1 then Second := ParamStr(2);
      if (Second <> '') and not TFile.Exists(Second) then
        raise Exception.Create('File not found: ' + Second);
      DumpBinary(First, Second);
    end;
  except
    on E: Exception do
    begin
      Writeln(E.ClassName + ': ' + E.Message);
      ExitCode := 2;
    end;
  end;
end.
