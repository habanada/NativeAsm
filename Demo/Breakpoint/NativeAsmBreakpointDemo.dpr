{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
program NativeAsmBreakpointDemo;

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils,
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
  Manager: TAsmBreakpointManager;
  Block: TAsmDebugBlock;
  Map: TAsmInstructionMap;
  EntryBreakpoint, MaxBreakpoint: TAsmSoftwareBreakpoint;
  HitCount: Integer;
  Value: UInt64;
begin
  B := nil;
  E := nil;
  Registry := nil;
  Manager := nil;
  Map := nil;
  HitCount := 0;
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
      Manager := TAsmBreakpointManager.Create(Registry);
      Manager.OnHit := procedure(const Hit: TAsmBreakpointHit)
        begin
          Inc(HitCount);
          Writeln;
          Writeln('BREAKPOINT HIT #', HitCount);
          Writeln('=================');
          Write(Hit.FormatText);
        end;

      Writeln('NativeAsm Runtime Breakpoint Demo');
      Writeln('=================================');
      Writeln('Block: ', Block.Name);
      Writeln('Base : ', FormatAddress(Block.BaseAddress));
      Writeln('Size : ', Block.Size, ' bytes');
      Writeln;
      Writeln('Instruction map');
      Writeln('---------------');
      Write(Map.FormatText);

      EntryBreakpoint := Manager.SetBreakpoint(Block, 'entry');
      MaxBreakpoint := Manager.SetBreakpoint(Block, 'have_max');
      Writeln;
      Writeln('Breakpoints armed');
      Writeln('-----------------');
      Writeln(EntryBreakpoint.Name, ' at ', FormatAddress(EntryBreakpoint.Address), ' byte=$', IntToHex(PByte(Pointer(EntryBreakpoint.Address))^, 2));
      Writeln(MaxBreakpoint.Name, ' at ', FormatAddress(MaxBreakpoint.Address), ' byte=$', IntToHex(PByte(Pointer(MaxBreakpoint.Address))^, 2));

      Writeln;
      Writeln('Run with both breakpoints');
      Writeln('-------------------------');
      Value := E.Run(17, 42);
      Manager.DispatchPendingHits;
      Check('MaxPlusOne(17,42)', 43, Value);
      Value := E.Run(99, 3);
      Manager.DispatchPendingHits;
      Check('MaxPlusOne(99,3)', 100, Value);
      Writeln('entry hits    : ', EntryBreakpoint.HitCount);
      Writeln('have_max hits : ', MaxBreakpoint.HitCount);
      Writeln('entry byte    : $', IntToHex(PByte(Pointer(EntryBreakpoint.Address))^, 2));
      Writeln('have_max byte : $', IntToHex(PByte(Pointer(MaxBreakpoint.Address))^, 2));

      Manager.DisableBreakpoint(EntryBreakpoint);
      Writeln;
      Writeln('Entry breakpoint disabled');
      Writeln('-------------------------');
      Writeln('entry byte    : $', IntToHex(PByte(Pointer(EntryBreakpoint.Address))^, 2));
      Writeln('have_max byte : $', IntToHex(PByte(Pointer(MaxBreakpoint.Address))^, 2));
      Value := E.Run(7, 7);
      Manager.DispatchPendingHits;
      Check('MaxPlusOne(7,7)', 8, Value);
      Writeln('entry hits    : ', EntryBreakpoint.HitCount);
      Writeln('have_max hits : ', MaxBreakpoint.HitCount);

      Manager.EnableBreakpoint(EntryBreakpoint);
      Value := E.Run(1, 2);
      Manager.DispatchPendingHits;
      Check('MaxPlusOne(1,2)', 3, Value);
      Writeln('entry hits    : ', EntryBreakpoint.HitCount);
      Writeln('have_max hits : ', MaxBreakpoint.HitCount);

      Manager.RemoveBreakpoint(MaxBreakpoint);
      Manager.RemoveBreakpoint(EntryBreakpoint);
      Writeln;
      Writeln('All breakpoints removed');
      Writeln('-----------------------');
      Writeln('Manager count: ', Manager.Count);
      Value := E.Run(100, 200);
      Manager.DispatchPendingHits;
      Check('MaxPlusOne(100,200)', 201, Value);
      Writeln('Total callback hits: ', HitCount);
      Manager.Uninstall;
    except
      on Ex: Exception do
      begin
        Writeln(Ex.ClassName, ': ', Ex.Message);
        ExitCode := 1;
      end;
    end;
  finally
    Map.Free;
    Manager.Free;
    Registry.Free;
    E.Free;
    B.Free;
  end;
end.
