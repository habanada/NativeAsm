{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
program NativeAsmInstructionMapDemo;

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils,
  System.IOUtils,
  NativeAsm.Types,
  NativeAsm.Builder,
  NativeAsm.Extensions,
  NativeAsm.Debug;

procedure Check(const Name: string; Expected, Actual: UInt64);
begin
  if Expected <> Actual then raise Exception.CreateFmt('%s: expected %d, got %d', [Name, Expected, Actual]);
  Writeln('PASS  ', Name, ' = ', Actual);
end;

var
  B: TAsmBuilder;
  E: TExecutableCode;
  Registry: TAsmDebugRegistry;
  Block: TAsmDebugBlock;
  Map: TAsmInstructionMap;
  Info: TAsmInstructionInfo;
  Location: TAsmDebugLocation;
  I: Integer;
  Probe: Pointer;
  BinFile, MapFile, InstructionFile, OutDir: string;
begin
  B := nil;
  E := nil;
  Registry := nil;
  Map := nil;
  try
    try
    B := TAsmBuilder.New;
    B.Label_('entry')
      .Mov(RAX, RCX)
      .Cmp(RAX, RDX)
      .J(cond_JGE, 'have_max')
      .Mov(RAX, RDX)
      .Label_('have_max')
      .Add(RAX, 1)
      .Label_('return')
      .Ret;

    E := TExecutableCode.FromBuilder(B);
    Registry := TAsmDebugRegistry.Create;
    Block := Registry.RegisterBuilderBlock('Demo.MaxPlusOne', E.EntryPoint, E.Size, B);
    Map := Block.CreateInstructionMap;

    Writeln('NativeAsm Instruction Map Demo');
    Writeln('==============================');
    Writeln('Block: ', Block.Name);
    Writeln('Base : ', FormatAddress(Block.BaseAddress));
    Writeln('Size : ', Block.Size, ' bytes');
    Writeln;

    Check('MaxPlusOne(17,42)', 43, E.Run(17, 42));
    Check('MaxPlusOne(99,3)', 100, E.Run(99, 3));
    Check('MaxPlusOne(7,7)', 8, E.Run(7, 7));

    Writeln;
    Writeln('Instruction map');
    Writeln('---------------');
    Write(Map.FormatText);

    Probe := nil;
    for I := 0 to Map.Count - 1 do
    begin
      Info := Map.Item(I);
      if (Length(Info.Mnemonic) > 0) and (Info.Mnemonic[1] = 'j') then
      begin
        if Info.Size > 2 then Probe := Pointer(Info.Address + 2) else Probe := Pointer(Info.Address + NativeUInt(Info.Size - 1));
        Break;
      end;
    end;
    if Probe = nil then raise Exception.Create('No branch instruction found');

    Location := Registry.Resolve(Probe, 12);
    Writeln;
    Writeln('Runtime address resolution');
    Writeln('--------------------------');
    Write(Location.FormatText);

    OutDir := ExtractFilePath(ParamStr(0));
    BinFile := TPath.Combine(OutDir, 'NativeAsmInstructionMapDemo.bin');
    MapFile := TPath.Combine(OutDir, 'NativeAsmInstructionMapDemo.map');
    InstructionFile := TPath.Combine(OutDir, 'NativeAsmInstructionMapDemo.imap');
    Block.SaveBinary(BinFile);
    Block.SaveMap(MapFile);
    Map.SaveToFile(InstructionFile);
    Writeln;
    Writeln('Offline files');
    Writeln('-------------');
    Writeln(BinFile);
    Writeln(MapFile);
    Writeln(InstructionFile);
    Writeln;
    Writeln('Analyze with: NativeAsmDump "', BinFile, '" "', MapFile, '"');
    except
      on Ex: Exception do
      begin
        Writeln(Ex.ClassName, ': ', Ex.Message);
        ExitCode := 1;
      end;
    end;
  finally
    Map.Free;
    Registry.Free;
    E.Free;
    B.Free;
  end;
end.
