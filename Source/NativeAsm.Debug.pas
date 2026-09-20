{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
unit NativeAsm.Debug;

(*
  NativeAsm -- Debug Utilities
  ====================================
  Author : NativeAsm Project
  Purpose: Development-time tools for inspecting and validating generated
           x64 machine code.

  TAsmDumper
  ----------
  Produces human-readable representations of a byte array:

    HexDump           - classic hex+ASCII dump, 16 bytes per line
    ByteView          - compact single-line hex string "48 89 C8 C3 ..."
    AnnotatedByteView - each byte with its decimal offset
    StatsText         - one-line summary (size, first, last, density)
    TokenView         - lightweight opcode recognition (not a disassembler)
    Diff              - side-by-side byte comparison of two arrays
    AssertPrefix      - assertion helper for unit tests
    AssertSuffix      - assertion helper for unit tests

  TAsmLabelMap
  ------------
  Read-only snapshot of a builder's label->offset mapping; also formats
  a human-readable table for logging.

  TAsmBuilderInspector
  --------------------
  Non-invasive wrapper that prints a hex dump to the console, a TStrings,
  or a binary file on demand.

  Usage (typical test harness)
  ----------------------------
    var
      B: TAsmBuilder;
    begin
      B := TAsmBuilder.New;
      try
        B.Prolog.Label_('loop')...J(cond_JNE,'loop').Epilog.Ret;
        Writeln(TAsmDumper.HexDump(B.Build));
        Writeln(TAsmDumper.StatsText(B.Build));
      finally
        B.Free;
      end;
    end;
*)

{$ALIGN ON}
{$MINENUMSIZE 4}
{$RTTI EXPLICIT METHODS([]) PROPERTIES([]) FIELDS([])}
{$WEAKLINKRTTI ON}

interface

uses
  System.SysUtils,
  System.Classes,
  System.Math,
  System.Generics.Collections,
  NativeAsm.Types,
  NativeAsm.Builder;

// ---------------------------------------------------------------------------
// TAsmDumper
// ---------------------------------------------------------------------------

type
  EAsmDebugError = class(Exception);

  TAsmDumper = record
  public
    /// <summary>
    ///   Classic hex+ASCII dump, 16 bytes per row, optional base RVA.
    ///   Example (BaseRVA = $1000):
    ///     00001000  48 89 C8 48 83 C0 01 C3  48 89 C8 48 83 C0 01 C3  |H..H....H..H....|
    /// </summary>
    class function HexDump(const Code: TBytes;
      BaseRVA: UInt64 = 0): string; static;

    /// <summary>
    ///   Compact single-line hex string: "48 89 C8 C3".
    ///   Useful for logging, assertions, and copy-paste into assemblers.
    /// </summary>
    class function ByteView(const Code: TBytes): string; static;

    /// <summary>
    ///   Annotated byte view: each byte with its decimal offset.
    ///   Format: "+000: 48  +001: 89  +002: C8  ..."
    /// </summary>
    class function AnnotatedByteView(const Code: TBytes): string; static;

    /// <summary>
    ///   One-line statistics:
    ///   "Size: 42 bytes | First: 48 | Last: C3 | Non-zero: 40 | Zero density: 4.8%"
    /// </summary>
    class function StatsText(const Code: TBytes): string; static;

    /// <summary>
    ///   Lightweight opcode recognizer -- identifies common single-byte opcodes
    ///   and REX prefixes, one line per byte.  NOT a full disassembler.
    ///   Use NativePe.Lde for accurate instruction parsing.
    /// </summary>
    class function TokenView(const Code: TBytes;
      BaseRVA: UInt64 = 0): TStringList; static;

    /// <summary>
    ///   Side-by-side comparison of two byte arrays.
    ///   Lines where A and B differ are marked with ">>>":
    ///     +003  C3   >>>   90   <- changed
    /// </summary>
    class function Diff(const A, B: TBytes): string; static;

    /// <summary>
    ///   Assert that Code begins with the given bytes.
    ///   Raises EAssertionFailed on mismatch -- useful in unit tests.
    /// </summary>
    class procedure AssertPrefix(const Code: TBytes;
      const Expected: array of Byte); static;

    /// <summary>
    ///   Assert that Code ends with the given bytes.
    /// </summary>
    class procedure AssertSuffix(const Code: TBytes;
      const Expected: array of Byte); static;
  end;

// ---------------------------------------------------------------------------
// TAsmLabelMap -- snapshot of a builder's label table
// ---------------------------------------------------------------------------

  /// <summary>
  ///   Read-only snapshot of the label->offset mapping from a TAsmBuilder run.
  ///   Use it to locate specific code positions after Build() for patching,
  ///   logging, or test verification.
  /// </summary>
  TAsmLabelMap = class
  private
    FMap: TDictionary<string, Integer>;
  public
    constructor Create;
    class function FromBuilder(Builder: TAsmBuilder): TAsmLabelMap; static;
    destructor  Destroy; override;

    /// <summary>Record a label name and its byte offset.</summary>
    procedure Add(const Name: string; Offset: Integer);

    /// <summary>Look up a label.  Returns -1 if not found.</summary>
    function  OffsetOf(const Name: string): Integer;

    /// <summary>True if the label exists in the map.</summary>
    function  Contains(const Name: string): Boolean;

    /// <summary>
    ///   Formatted table:
    ///     Label                          Offset  (+0x)
    ///     ---------------------------------------------
    ///     loop_begin                   00000010  (+0x00000010)
    /// </summary>
    function  FormatTable: string;

    property Map: TDictionary<string, Integer> read FMap;
  end;

  TAsmDebugSymbol = record
    Name: string;
    Offset: Integer;
  end;

  TAsmInstructionInfo = record
    Address: NativeUInt;
    Offset: Integer;
    Size: Integer;
    Mnemonic: string;
    Text: string;
    Bytes: TBytes;
    SymbolName: string;
    SymbolOffset: Integer;
    SymbolDelta: Integer;
    HasTarget: Boolean;
    TargetAddress: NativeUInt;
    TargetSymbol: string;
  end;

  TAsmInstructionMap = class
  private
    FBaseAddress: NativeUInt;
    FCode: TBytes;
    FSymbols: TArray<TAsmDebugSymbol>;
    FItems: TArray<TAsmInstructionInfo>;
    procedure Decode;
    function FindNearestSymbol(Offset: Integer; out Symbol: TAsmDebugSymbol): Boolean;
  public
    constructor Create(const Code: TBytes; BaseAddress: NativeUInt; const Symbols: TArray<TAsmDebugSymbol>);
    function Count: Integer;
    function Item(Index: Integer): TAsmInstructionInfo;
    function FindByOffset(Offset: Integer; out Info: TAsmInstructionInfo): Boolean;
    function FindByAddress(Address: Pointer; out Info: TAsmInstructionInfo): Boolean;
    function FormatText: string;
    procedure SaveToFile(const Filename: string);
    property BaseAddress: NativeUInt read FBaseAddress;
  end;

  TAsmDebugLocation = record
    Found: Boolean;
    Address: NativeUInt;
    BlockName: string;
    BaseAddress: NativeUInt;
    BlockSize: Integer;
    Offset: Integer;
    SymbolName: string;
    SymbolOffset: Integer;
    SymbolDelta: Integer;
    BytesOffset: Integer;
    Bytes: TBytes;
    InstructionOffset: Integer;
    InstructionSize: Integer;
    InstructionDelta: Integer;
    InstructionText: string;
    InstructionBytes: TBytes;
    function FormatText: string;
  end;

  TAsmDebugBlock = class
  private
    FName: string;
    FBaseAddress: NativeUInt;
    FSize: Integer;
    FSymbols: TList<TAsmDebugSymbol>;
    FCode: TBytes;
    FInstructionMap: TAsmInstructionMap;
    function GetSymbols: TArray<TAsmDebugSymbol>;
    function GetInstructionMap: TAsmInstructionMap;
  public
    constructor Create(const AName: string; ABaseAddress: NativeUInt; ASize: Integer; SnapshotBytes: Boolean = True);
    destructor Destroy; override;
    procedure AddSymbol(const Name: string; Offset: Integer);
    procedure AddLabels(Labels: TAsmLabelMap);
    procedure RefreshBytes;
    function FindNearestSymbol(Offset: Integer; out Symbol: TAsmDebugSymbol): Boolean;
    function BytesAt(Offset, Count: Integer): TBytes;
    function FormatMap: string;
    function CreateInstructionMap: TAsmInstructionMap;
    procedure SaveBinary(const Filename: string);
    procedure SaveMap(const Filename: string);
    class function LoadMap(const Filename: string): TAsmDebugBlock; static;
    property Name: string read FName;
    property BaseAddress: NativeUInt read FBaseAddress;
    property Size: Integer read FSize;
    property Symbols: TArray<TAsmDebugSymbol> read GetSymbols;
  end;

  TAsmDebugRegistry = class
  private
    FBlocks: TObjectList<TAsmDebugBlock>;
  public
    constructor Create;
    destructor Destroy; override;
    function RegisterBlock(const Name: string; BaseAddress: Pointer; Size: Integer; Labels: TAsmLabelMap = nil; SnapshotBytes: Boolean = True): TAsmDebugBlock;
    function RegisterBuilderBlock(const Name: string; BaseAddress: Pointer; Size: Integer; Builder: TAsmBuilder; SnapshotBytes: Boolean = True): TAsmDebugBlock;
    function UnregisterBlock(BaseAddress: Pointer): Boolean;
    function Resolve(Address: Pointer; ByteCount: Integer = 16): TAsmDebugLocation;
    procedure Clear;
    function Count: Integer;
  end;

  TAsmRegisterSnapshot = record
    Rax: UInt64;
    Rbx: UInt64;
    Rcx: UInt64;
    Rdx: UInt64;
    Rsi: UInt64;
    Rdi: UInt64;
    Rbp: UInt64;
    Rsp: UInt64;
    R8: UInt64;
    R9: UInt64;
    R10: UInt64;
    R11: UInt64;
    R12: UInt64;
    R13: UInt64;
    R14: UInt64;
    R15: UInt64;
    Rip: UInt64;
    EFlags: Cardinal;
    function FormatText: string;
  end;

  TAsmSoftwareBreakpoint = class
  private
    FName: string;
    FBlockName: string;
    FAddress: NativeUInt;
    FOffset: Integer;
    FOriginalByte: Byte;
    FEnabled: Boolean;
    FHitCount: UInt64;
  public
    property Name: string read FName;
    property BlockName: string read FBlockName;
    property Address: NativeUInt read FAddress;
    property Offset: Integer read FOffset;
    property OriginalByte: Byte read FOriginalByte;
    property Enabled: Boolean read FEnabled;
    property HitCount: UInt64 read FHitCount;
  end;

  TAsmBreakpointHit = record
    Breakpoint: TAsmSoftwareBreakpoint;
    ThreadId: Cardinal;
    Location: TAsmDebugLocation;
    Registers: TAsmRegisterSnapshot;
    function FormatText: string;
  end;

  TAsmBreakpointHitEvent = reference to procedure(const Hit: TAsmBreakpointHit);

  TAsmBreakpointRawHit = record
    Breakpoint: TAsmSoftwareBreakpoint;
    ThreadId: Cardinal;
    Registers: TAsmRegisterSnapshot;
  end;

  TAsmBreakpointManager = class
  private
    FRegistry: TAsmDebugRegistry;
    FBreakpoints: TObjectList<TAsmSoftwareBreakpoint>;
    FHandler: Pointer;
    FTlsIndex: Cardinal;
    FInstalled: Boolean;
    FPendingCount: LongInt;
    FHitBuffer: TArray<TAsmBreakpointRawHit>;
    FHitWrite: LongInt;
    FHitRead: LongInt;
    FDroppedHits: LongInt;
    FOnHit: TAsmBreakpointHitEvent;
    FLastCallbackError: string;
    function FindByAddress(Address: NativeUInt): TAsmSoftwareBreakpoint;
    function AddBreakpoint(Block: TAsmDebugBlock; Offset: Integer; const Name: string): TAsmSoftwareBreakpoint;
    function HandleException(ExceptionInfo: Pointer): LongInt;
    procedure QueueHit(Breakpoint: TAsmSoftwareBreakpoint; ThreadId: Cardinal; const Registers: TAsmRegisterSnapshot);
    class function TryPatchByte(Address: NativeUInt; Value: Byte): Boolean; static;
    class procedure PatchByte(Address: NativeUInt; Value: Byte); static;
  public
    constructor Create(Registry: TAsmDebugRegistry);
    destructor Destroy; override;
    procedure Install;
    procedure Uninstall;
    function SetBreakpoint(Block: TAsmDebugBlock; Offset: Integer): TAsmSoftwareBreakpoint; overload;
    function SetBreakpoint(Block: TAsmDebugBlock; const SymbolName: string): TAsmSoftwareBreakpoint; overload;
    procedure EnableBreakpoint(Breakpoint: TAsmSoftwareBreakpoint);
    procedure DisableBreakpoint(Breakpoint: TAsmSoftwareBreakpoint);
    function RemoveBreakpoint(Breakpoint: TAsmSoftwareBreakpoint): Boolean;
    procedure Clear;
    function TryDequeueHit(out Hit: TAsmBreakpointHit): Boolean;
    procedure DispatchPendingHits;
    function PendingHitCount: Integer;
    function Count: Integer;
    property Installed: Boolean read FInstalled;
    property DroppedHitCount: LongInt read FDroppedHits;
    property OnHit: TAsmBreakpointHitEvent read FOnHit write FOnHit;
    property LastCallbackError: string read FLastCallbackError;
  end;

// ---------------------------------------------------------------------------
// TAsmBuilderInspector -- non-invasive builder wrapper for debugging
// ---------------------------------------------------------------------------

  /// <summary>
  ///   Wraps a TAsmBuilder and produces diagnostic output on demand.
  ///   Drop-in for development; remove or ifdef-out in production.
  ///
  ///   Does NOT take ownership of the wrapped builder.
  /// </summary>
  TAsmBuilderInspector = class
  private
    FBuilder: TAsmBuilder;
    FLabel  : string;
  public
    constructor Create(Builder: TAsmBuilder; const Label_: string = '');

    /// <summary>Build and print a hex dump + stats to the console.</summary>
    procedure DumpToConsole;

    /// <summary>Build and write the dump to a TStrings (e.g. a TMemo.Lines).</summary>
    procedure DumpToStrings(Target: TStrings);

    /// <summary>
    ///   Build and write raw bytes to Filename.
    ///   ndisasm usage:   ndisasm -b 64 output.bin
    ///   objdump usage:   objdump -D -b binary -m i386:x86-64 output.bin
    /// </summary>
    procedure DumpToFile(const Filename: string);
  end;

function FormatAddress(Address: NativeUInt): string;
function ResolveAddress(Registry: TAsmDebugRegistry; Address: Pointer; ByteCount: Integer = 16): TAsmDebugLocation;

implementation

uses
  System.IOUtils,
  Winapi.Windows,
  NativeAsm.InstructionDB;

const
  NATIVEASM_EXCEPTION_CONTINUE_EXECUTION = -1;
  NATIVEASM_EXCEPTION_CONTINUE_SEARCH = 0;

function NativeAsmAddVectoredExceptionHandler(FirstHandler: Cardinal; Handler: Pointer): Pointer; stdcall; external 'kernel32.dll' name 'AddVectoredExceptionHandler';
function NativeAsmRemoveVectoredExceptionHandler(Handle: Pointer): Cardinal; stdcall; external 'kernel32.dll' name 'RemoveVectoredExceptionHandler';

// ---------------------------------------------------------------------------
// TAsmDumper
// ---------------------------------------------------------------------------

class function TAsmDumper.HexDump(const Code: TBytes;
  BaseRVA: UInt64): string;
const
  BytesPerRow = 16;
var
  SB        : TStringBuilder;
  Row, Col  : Integer;
  Idx       : Integer;
  B         : Byte;
  HexPart   : string;
  AsciiPart : string;
begin
  if Length(Code) = 0 then
    Exit('(empty)');

  SB := TStringBuilder.Create;
  try
    Row := 0;
    while Row * BytesPerRow < Length(Code) do
    begin
      HexPart   := '';
      AsciiPart := '';

      for Col := 0 to BytesPerRow - 1 do
      begin
        Idx := Row * BytesPerRow + Col;
        if Idx < Length(Code) then
        begin
          B := Code[Idx];
          HexPart := HexPart + IntToHex(B, 2) + ' ';
          if (B >= 32) and (B < 127) then
            AsciiPart := AsciiPart + Char(B)
          else
            AsciiPart := AsciiPart + '.';
        end
        else
        begin
          HexPart   := HexPart   + '   ';
          AsciiPart := AsciiPart + ' ';
        end;

        if Col = 7 then HexPart := HexPart + ' ';
      end;

      SB.AppendFormat('%8.8x  %s |%s|',
        [BaseRVA + UInt64(Row * BytesPerRow), HexPart, AsciiPart]);
      SB.AppendLine;
      Inc(Row);
    end;
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

class function TAsmDumper.ByteView(const Code: TBytes): string;
var
  SB: TStringBuilder;
  I : Integer;
begin
  if Length(Code) = 0 then Exit('');
  SB := TStringBuilder.Create(Length(Code) * 3);
  try
    for I := 0 to High(Code) do
    begin
      if I > 0 then SB.Append(' ');
      SB.Append(IntToHex(Code[I], 2));
    end;
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

class function TAsmDumper.AnnotatedByteView(const Code: TBytes): string;
var
  SB: TStringBuilder;
  I : Integer;
begin
  SB := TStringBuilder.Create;
  try
    for I := 0 to High(Code) do
    begin
      if I > 0 then SB.Append('  ');
      SB.AppendFormat('+%3.3d: %2.2x', [I, Code[I]]);
    end;
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

class function TAsmDumper.StatsText(const Code: TBytes): string;
var
  I, NonZero : Integer;
  ZeroDensity: Double;
begin
  if Length(Code) = 0 then
    Exit('Size: 0 bytes');

  NonZero := 0;
  for I := 0 to High(Code) do
    if Code[I] <> 0 then Inc(NonZero);

  ZeroDensity := 100.0 * (Length(Code) - NonZero) / Length(Code);

  Result := Format(
    'Size: %d bytes | First: %2.2x | Last: %2.2x | Non-zero: %d | Zero density: %.1f%%',
    [Length(Code), Code[0], Code[High(Code)], NonZero, ZeroDensity]);
end;

class function TAsmDumper.TokenView(const Code: TBytes;
  BaseRVA: UInt64): TStringList;
var
  I  : Integer;
  B  : Byte;
  Tok: string;
begin
  Result := TStringList.Create;
  if Length(Code) = 0 then Exit;

  I := 0;
  while I < Length(Code) do
  begin
    B   := Code[I];
    Tok := Format('+%4.4x [%8.8x]  %2.2x', [I, BaseRVA + UInt64(I), B]);

    case B of
      $40..$4F:
      begin
        // Decode the four REX bits individually -- avoids Delphi 12 E2010
        // "duplicate case label" error from listing $48/$49/$4C/$4D inside
        // the $40..$4F range.
        Tok := Tok + '  ; REX';
        if (B and $08) <> 0 then Tok := Tok + '.W';
        if (B and $04) <> 0 then Tok := Tok + 'R';
        if (B and $02) <> 0 then Tok := Tok + 'X';
        if (B and $01) <> 0 then Tok := Tok + 'B';
        if B = $40 then Tok := Tok + ' (no bits set)';
      end;
      $50..$57: Tok := Tok + Format('  ; PUSH r%d', [B - $50]);
      $58..$5F: Tok := Tok + Format('  ; POP  r%d', [B - $58]);
      $90:      Tok := Tok + '  ; NOP';
      $C3:      Tok := Tok + '  ; RET';
      $CC:      Tok := Tok + '  ; INT 3';
      $E8:      Tok := Tok + '  ; CALL rel32';
      $E9:      Tok := Tok + '  ; JMP  rel32';
      $EB:      Tok := Tok + '  ; JMP  rel8';
      $FF:      Tok := Tok + '  ; FF /n (CALL/JMP/INC/DEC r/m)';
      $0F:
        if (I + 1) < Length(Code) then
          case Code[I + 1] of
            $05: Tok := Tok + '  ; SYSCALL';
            $0B: Tok := Tok + '  ; UD2';
            $1F: Tok := Tok + '  ; NOP r/m (multi-byte)';
            $84: Tok := Tok + '  ; JE  rel32';
            $85: Tok := Tok + '  ; JNE rel32';
          end;
    end;

    Result.Add(Tok);
    Inc(I);
  end;
end;

class function TAsmDumper.Diff(const A, B: TBytes): string;
var
  SB            : TStringBuilder;
  I, MaxN       : Integer;
  AHex, BHex    : string;
  Mark          : string;
begin
  SB := TStringBuilder.Create;
  try
    MaxN := Max(Length(A), Length(B));

    for I := 0 to MaxN - 1 do
    begin
      if I < Length(A) then
        AHex := IntToHex(A[I], 2)
      else
        AHex := '--';

      if I < Length(B) then
        BHex := IntToHex(B[I], 2)
      else
        BHex := '--';

      if AHex = BHex then
        Mark := '='
      else
        Mark := '>>>';

      SB.AppendFormat('+%3.3d  %2s  %3s  %2s', [I, AHex, Mark, BHex]);
      SB.AppendLine;
    end;
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

class procedure TAsmDumper.AssertPrefix(const Code: TBytes;
  const Expected: array of Byte);
var
  I: Integer;
begin
  if Length(Expected) > Length(Code) then
    raise EAssertionFailed.CreateFmt(
      'AssertPrefix: expected %d bytes but code is only %d bytes',
      [Length(Expected), Length(Code)]);

  for I := 0 to High(Expected) do
    if Code[I] <> Expected[I] then
      raise EAssertionFailed.CreateFmt(
        'AssertPrefix: byte +%d -- expected $%2.2x but got $%2.2x',
        [I, Expected[I], Code[I]]);
end;

class procedure TAsmDumper.AssertSuffix(const Code: TBytes;
  const Expected: array of Byte);
var
  I, Base: Integer;
begin
  if Length(Expected) > Length(Code) then
    raise EAssertionFailed.CreateFmt(
      'AssertSuffix: expected %d bytes but code is only %d bytes',
      [Length(Expected), Length(Code)]);

  Base := Length(Code) - Length(Expected);
  for I := 0 to High(Expected) do
    if Code[Base + I] <> Expected[I] then
      raise EAssertionFailed.CreateFmt(
        'AssertSuffix: byte +%d (absolute +%d) -- expected $%2.2x but got $%2.2x',
        [I, Base + I, Expected[I], Code[Base + I]]);
end;

// ---------------------------------------------------------------------------
// TAsmLabelMap
// ---------------------------------------------------------------------------

constructor TAsmLabelMap.Create;
begin
  FMap := TDictionary<string, Integer>.Create;
end;

class function TAsmLabelMap.FromBuilder(Builder: TAsmBuilder): TAsmLabelMap;
begin
  if Builder = nil then
    raise EArgumentNilException.Create('Builder');
  Result := TAsmLabelMap.Create;
  try
    Builder.CopyLabelsTo(Result.FMap);
  except
    Result.Free;
    raise;
  end;
end;

destructor TAsmLabelMap.Destroy;
begin
  FMap.Free;
  inherited;
end;

procedure TAsmLabelMap.Add(const Name: string; Offset: Integer);
begin
  FMap.AddOrSetValue(Name, Offset);
end;

function TAsmLabelMap.OffsetOf(const Name: string): Integer;
begin
  if not FMap.TryGetValue(Name, Result) then
    Result := -1;
end;

function TAsmLabelMap.Contains(const Name: string): Boolean;
begin
  Result := FMap.ContainsKey(Name);
end;

function TAsmLabelMap.FormatTable: string;
const
  Separator = '------------------------------------------';
var
  SB  : TStringBuilder;
  Pair: TPair<string, Integer>;
begin
  SB := TStringBuilder.Create;
  try
    SB.AppendFormat('%-30s  %8s  (%s)', ['Label', 'Offset', 'hex']);
    SB.AppendLine;
    SB.AppendLine(Separator);

    for Pair in FMap do
      SB.AppendFormat('%-30s  %8d  (+0x%8.8x)%s',
        [Pair.Key, Pair.Value, Pair.Value, sLineBreak]);

    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

function FormatAddress(Address: NativeUInt): string;
begin
  Result := '$' + IntToHex(Int64(Address), SizeOf(Pointer) * 2);
end;

function EscapeMapText(const Value: string): string;
begin
  Result := StringReplace(Value, '\', '\\', [rfReplaceAll]);
  Result := StringReplace(Result, '|', '\p', [rfReplaceAll]);
  Result := StringReplace(Result, #13, '\r', [rfReplaceAll]);
  Result := StringReplace(Result, #10, '\n', [rfReplaceAll]);
end;

function UnescapeMapText(const Value: string): string;
var
  I: Integer;
begin
  Result := '';
  I := 1;
  while I <= Length(Value) do
  begin
    if (Value[I] = '\') and (I < Length(Value)) then
    begin
      Inc(I);
      case Value[I] of
        '\': Result := Result + '\';
        'p': Result := Result + '|';
        'r': Result := Result + #13;
        'n': Result := Result + #10;
      else
        Result := Result + '\' + Value[I];
      end;
    end
    else
      Result := Result + Value[I];
    Inc(I);
  end;
end;

function ParseHexUInt64(const Value: string): UInt64;
var
  I: Integer;
  D: Byte;
  C: Char;
begin
  Result := 0;
  if Value = '' then
    raise EConvertError.Create('Empty hexadecimal value');
  for I := 1 to Length(Value) do
  begin
    C := Value[I];
    case C of
      '0'..'9': D := Ord(C) - Ord('0');
      'A'..'F': D := Ord(C) - Ord('A') + 10;
      'a'..'f': D := Ord(C) - Ord('a') + 10;
    else
      raise EConvertError.CreateFmt('Invalid hexadecimal value "%s"', [Value]);
    end;
    if Result > (High(UInt64) shr 4) then
      raise EConvertError.CreateFmt('Hexadecimal value "%s" is out of range', [Value]);
    Result := (Result shl 4) or D;
  end;
end;

function DisplayLabelName(const Value: string): string;
begin
  if (Value <> '') and (Value[1] = #0) then
    Result := 'L#' + Copy(Value, 2, MaxInt)
  else
    Result := Value;
end;

type
  TAsmDecodePrefix = record
    Next: Integer;
    Has66: Boolean;
    Has67: Boolean;
    HasF2: Boolean;
    HasF3: Boolean;
    Rex: Byte;
  end;

  TAsmDecodedRM = record
    Present: Boolean;
    ModValue: Byte;
    RegField: Integer;
    RmField: Integer;
    IsRegister: Boolean;
    HasSib: Boolean;
    Scale: Integer;
    HasBase: Boolean;
    BaseReg: Integer;
    HasIndex: Boolean;
    IndexReg: Integer;
    RipRelative: Boolean;
    Disp: Int64;
    EndPos: Integer;
  end;

  TAsmDecodeCandidate = record
    FormIndex: Integer;
    Prefix: TAsmDecodePrefix;
    OpcodePos: Integer;
    OpcodeByte: Byte;
    RM: TAsmDecodedRM;
    ImmPos: Integer;
    EndPos: Integer;
    Score: Integer;
  end;

function DecodePrefixes(const Code: TBytes; Start: Integer): TAsmDecodePrefix;
var
  B: Byte;
begin
  Result := Default(TAsmDecodePrefix);
  Result.Next := Start;
  while Result.Next < Length(Code) do
  begin
    B := Code[Result.Next];
    case B of
      $66: Result.Has66 := True;
      $67: Result.Has67 := True;
      $F2: Result.HasF2 := True;
      $F3: Result.HasF3 := True;
      $40..$4F: Result.Rex := B;
    else
      Exit;
    end;
    Inc(Result.Next);
  end;
end;

function ReadUnsigned(const Code: TBytes; Pos, Count: Integer; out Value: UInt64): Boolean;
var
  I: Integer;
begin
  Result := False;
  Value := 0;
  if (Count < 0) or (Pos < 0) or (Pos + Count > Length(Code)) then Exit;
  for I := 0 to Count - 1 do Value := Value or (UInt64(Code[Pos + I]) shl (I * 8));
  Result := True;
end;

function ReadSigned(const Code: TBytes; Pos, Count: Integer; out Value: Int64): Boolean;
var
  U: UInt64;
  B: Byte;
  W: Word;
  C: Cardinal;
  S8: ShortInt;
  S16: SmallInt;
  S32: Integer;
begin
  Result := ReadUnsigned(Code, Pos, Count, U);
  if not Result then Exit;
  case Count of
    1:
    begin
      B := Byte(U);
      Move(B, S8, SizeOf(S8));
      Value := S8;
    end;
    2:
    begin
      W := Word(U);
      Move(W, S16, SizeOf(S16));
      Value := S16;
    end;
    4:
    begin
      C := Cardinal(U);
      Move(C, S32, SizeOf(S32));
      Value := S32;
    end;
    8: Move(U, Value, SizeOf(Value));
  else
    Value := Int64(U);
  end;
end;

function RelativeAddress(BaseAddress: NativeUInt; EndOffset: Integer; Delta: Int64): NativeUInt;
begin
  Result := BaseAddress + NativeUInt(EndOffset);
  if Delta < 0 then Result := Result - NativeUInt(-Delta) else Result := Result + NativeUInt(Delta);
end;

function ParseRM(const Code: TBytes; Pos: Integer; Rex: Byte; out RM: TAsmDecodedRM): Boolean;
var
  M, RawRm, RawIndex, RawBase, DispSize: Integer;
  D: Int64;
begin
  Result := False;
  RM := Default(TAsmDecodedRM);
  if Pos >= Length(Code) then Exit;
  M := Code[Pos];
  RM.Present := True;
  RM.ModValue := Byte(M shr 6);
  RM.RegField := ((M shr 3) and 7) or (((Rex shr 2) and 1) shl 3);
  RawRm := M and 7;
  RM.RmField := RawRm or ((Rex and 1) shl 3);
  Inc(Pos);
  if RM.ModValue = 3 then
  begin
    RM.IsRegister := True;
    RM.EndPos := Pos;
    Exit(True);
  end;
  DispSize := 0;
  if RawRm = 4 then
  begin
    if Pos >= Length(Code) then Exit;
    M := Code[Pos];
    Inc(Pos);
    RM.HasSib := True;
    RM.Scale := 1 shl (M shr 6);
    RawIndex := (M shr 3) and 7;
    RawBase := M and 7;
    if not ((RawIndex = 4) and ((Rex and 2) = 0)) then
    begin
      RM.HasIndex := True;
      RM.IndexReg := RawIndex or (((Rex shr 1) and 1) shl 3);
    end;
    if (RM.ModValue = 0) and (RawBase = 5) then
      DispSize := 4
    else
    begin
      RM.HasBase := True;
      RM.BaseReg := RawBase or ((Rex and 1) shl 3);
    end;
  end
  else if (RM.ModValue = 0) and (RawRm = 5) then
  begin
    RM.RipRelative := True;
    DispSize := 4;
  end
  else
  begin
    RM.HasBase := True;
    RM.BaseReg := RM.RmField;
  end;
  if RM.ModValue = 1 then DispSize := 1 else if RM.ModValue = 2 then DispSize := 4;
  if DispSize > 0 then
  begin
    if not ReadSigned(Code, Pos, DispSize, D) then Exit;
    RM.Disp := D;
    Inc(Pos, DispSize);
  end;
  RM.EndPos := Pos;
  Result := True;
end;

function MapOpcodeAt(const Code: TBytes; Pos: Integer; out Map: TOpcodeMap; out OpcodePos: Integer): Boolean;
begin
  Result := False;
  if Pos >= Length(Code) then Exit;
  if Code[Pos] <> $0F then
  begin
    Map := omPrimary;
    OpcodePos := Pos;
    Exit(True);
  end;
  Inc(Pos);
  if Pos >= Length(Code) then Exit;
  if Code[Pos] = $38 then
  begin
    Map := om0F38;
    Inc(Pos);
  end
  else if Code[Pos] = $3A then
  begin
    Map := om0F3A;
    Inc(Pos);
  end
  else
    Map := om0F;
  if Pos >= Length(Code) then Exit;
  OpcodePos := Pos;
  Result := True;
end;

function FormNeeds66(const D: TEncodingDescriptor): Boolean;
begin
  Result := D.Raw66 or (D.MandatoryPrefix = mp66) or (D.Legacy66Policy = p66ForceOperandSize) or
    (D.Legacy66Policy = p66MandatoryOpcode) or ((D.Legacy66Policy = p66ByResolvedGpWidth) and (D.ExpandedWidth = 16)) or
    (D.NativeCanonicalization = ncLea16Uses66);
end;

function FormNeeds67(const D: TEncodingDescriptor): Boolean;
begin
  Result := D.Raw67 and (D.NativeCanonicalization <> ncLea16Uses66);
end;

function TryDecodeForm(const Code: TBytes; FormIndex: Integer; const Prefix: TAsmDecodePrefix; Map: TOpcodeMap; OpcodePos: Integer; out C: TAsmDecodeCandidate): Boolean;
var
  D: PEncodingDescriptor;
  Op: Byte;
  Pos, FixBytes: Integer;
  ForceW: Boolean;
begin
  Result := False;
  C := Default(TAsmDecodeCandidate);
  D := TInstructionDb.Form(FormIndex);
  if D^.OpcodeMap <> Map then Exit;
  if Prefix.HasF2 <> (D^.MandatoryPrefix = mpF2) then Exit;
  if Prefix.HasF3 <> (D^.MandatoryPrefix = mpF3) then Exit;
  if Prefix.Has66 <> FormNeeds66(D^) then Exit;
  if Prefix.Has67 <> FormNeeds67(D^) then Exit;
  ForceW := (D^.RexWPolicy = rwForce) or ((D^.RexWPolicy = rwByResolvedGpWidth) and (D^.ExpandedWidth = 64));
  if ((Prefix.Rex and $08) <> 0) <> ForceW then Exit;
  Op := Code[OpcodePos];
  if D^.OpcodePlusReg then
  begin
    if (Op and $F8) <> (D^.Opcode and $F8) then Exit;
  end
  else if Op <> D^.Opcode then Exit;
  Pos := OpcodePos + 1;
  if D^.ModRMKind <> mkNone then
  begin
    if not ParseRM(Code, Pos, Prefix.Rex, C.RM) then Exit;
    if (D^.ModRMKind = mkFixedRegField) and (((Code[Pos] shr 3) and 7) <> D^.FixedRegValue) then Exit;
    if (D^.ModRMKind = mkIgnoredRegCanonicalZero) and (((Code[Pos] shr 3) and 7) <> 0) then Exit;
    if (D^.ModRMKind = mkFixedByte) and (Code[Pos] <> D^.FixedModRMByte) then Exit;
    Pos := C.RM.EndPos;
  end;
  C.ImmPos := Pos;
  if D^.HasFixup then
  begin
    case D^.FixupKind of
      dfkRelative8: FixBytes := 1;
      dfkRelative32: FixBytes := 4;
    else
      FixBytes := 0;
    end;
    Inc(Pos, FixBytes);
  end
  else
    Inc(Pos, D^.ImmediateBytes);
  if Pos > Length(Code) then Exit;
  C.FormIndex := FormIndex;
  C.Prefix := Prefix;
  C.OpcodePos := OpcodePos;
  C.OpcodeByte := Op;
  C.EndPos := Pos;
  C.Score := 0;
  if D^.NativeSupport = nsSupported then Inc(C.Score, 4) else if D^.NativeSupport = nsPartial then Inc(C.Score, 2);
  if not D^.SourceAlt then Inc(C.Score);
  if D^.ExpandedWidth <> 0 then Inc(C.Score);
  Result := True;
end;

function RegName(Index: Integer; RegClass: TDbRegClass; Rex: Byte): string;
const
  R64: array[0..15] of string = ('rax','rcx','rdx','rbx','rsp','rbp','rsi','rdi','r8','r9','r10','r11','r12','r13','r14','r15');
  R32: array[0..15] of string = ('eax','ecx','edx','ebx','esp','ebp','esi','edi','r8d','r9d','r10d','r11d','r12d','r13d','r14d','r15d');
  R16: array[0..15] of string = ('ax','cx','dx','bx','sp','bp','si','di','r8w','r9w','r10w','r11w','r12w','r13w','r14w','r15w');
  R8L: array[0..15] of string = ('al','cl','dl','bl','spl','bpl','sil','dil','r8b','r9b','r10b','r11b','r12b','r13b','r14b','r15b');
  R8H: array[0..7] of string = ('al','cl','dl','bl','ah','ch','dh','bh');
begin
  if (Index < 0) or (Index > 15) then Exit('?');
  case RegClass of
    rcGp16: Result := R16[Index];
    rcGp32: Result := R32[Index];
    rcGp64: Result := R64[Index];
    rcGp8Lo: Result := R8L[Index];
    rcGp8Hi: if Index <= 7 then Result := R8H[Index] else Result := '?';
    rcGp8Any:
      if (Rex = 0) and (Index >= 4) and (Index <= 7) then Result := R8H[Index] else Result := R8L[Index];
  else
    Result := R64[Index];
  end;
end;

function MemSizeName(MemClass: TDbMemClass): string;
begin
  case MemClass of
    mc8: Result := 'byte ptr ';
    mc16: Result := 'word ptr ';
    mc32: Result := 'dword ptr ';
    mc64: Result := 'qword ptr ';
  else
    Result := '';
  end;
end;

function SignedHex(Value: Int64): string;
begin
  if Value < 0 then Result := '-$' + IntToHex(UInt64(-(Value + 1)) + 1, 1) else Result := '+$' + IntToHex(UInt64(Value), 1);
end;

function FormatMemory(const RM: TAsmDecodedRM; MemClass: TDbMemClass): string;
var
  S: string;
begin
  S := '';
  if RM.RipRelative then S := 'rip'
  else if RM.HasBase then S := RegName(RM.BaseReg, rcGp64, $40);
  if RM.HasIndex then
  begin
    if S <> '' then S := S + '+';
    S := S + RegName(RM.IndexReg, rcGp64, $40);
    if RM.Scale <> 1 then S := S + '*' + IntToStr(RM.Scale);
  end;
  if RM.Disp <> 0 then
  begin
    if S = '' then
    begin
      if RM.Disp < 0 then S := '-$' + IntToHex(UInt64(-(RM.Disp + 1)) + 1, 1) else S := '$' + IntToHex(UInt64(RM.Disp), 1);
    end
    else
      S := S + SignedHex(RM.Disp);
  end;
  if S = '' then S := '0';
  Result := MemSizeName(MemClass) + '[' + S + ']';
end;

function ImmediateText(const Code: TBytes; Pos, Count: Integer; Kind: TImmKind): string;
var
  U: UInt64;
  S: Int64;
begin
  if not ReadUnsigned(Code, Pos, Count, U) then Exit('?');
  if Kind in [ikSigned8, ikSigned32] then
  begin
    if not ReadSigned(Code, Pos, Count, S) then Exit('?');
    if S < 0 then Exit('-$' + IntToHex(UInt64(-(S + 1)) + 1, 1));
  end;
  Result := '$' + IntToHex(U, 1);
end;

function FormatDecodedOperand(const Code: TBytes; BaseAddress: NativeUInt; const C: TAsmDecodeCandidate; OperandIndex: Integer): string;
var
  D: PEncodingDescriptor;
  Spec: PDbOperandSpec;
  RegIndex, Count: Integer;
  Rel: Int64;
  Target: NativeUInt;
begin
  D := TInstructionDb.Form(C.FormIndex);
  Spec := TInstructionDb.Operand(C.FormIndex, OperandIndex);
  if (Spec^.FixedFlags and DB_FO_HAS_REG) <> 0 then Exit(RegName(Spec^.FixedRegID, Spec^.RegClass, C.Prefix.Rex));
  if OperandIndex = D^.ModRegOperandIdx then Exit(RegName(C.RM.RegField, Spec^.RegClass, C.Prefix.Rex));
  if OperandIndex = D^.ModRmOperandIdx then
  begin
    if C.RM.IsRegister then Exit(RegName(C.RM.RmField, Spec^.RegClass, C.Prefix.Rex));
    Exit(FormatMemory(C.RM, Spec^.MemClass));
  end;
  if OperandIndex = D^.OpcodeRegOperandIdx then
  begin
    RegIndex := (C.OpcodeByte and 7) or ((C.Prefix.Rex and 1) shl 3);
    Exit(RegName(RegIndex, Spec^.RegClass, C.Prefix.Rex));
  end;
  if OperandIndex = D^.ImmediateOperandIdx then Exit(ImmediateText(Code, C.ImmPos, D^.ImmediateBytes, D^.ImmKind));
  if OperandIndex = D^.FixupOperandIdx then
  begin
    case D^.FixupKind of
      dfkRelative8: Count := 1;
      dfkRelative32: Count := 4;
    else
      Count := 0;
    end;
    if not ReadSigned(Code, C.ImmPos, Count, Rel) then Exit('?');
    Target := RelativeAddress(BaseAddress, C.EndPos, Rel);
    Exit(FormatAddress(Target));
  end;
  if (Spec^.FixedFlags and DB_FO_HAS_IMMEDIATE) <> 0 then Exit('$' + IntToHex(Spec^.FixedImm, 1));
  Result := '?';
end;

function FormatDecodedText(const Code: TBytes; BaseAddress: NativeUInt; const C: TAsmDecodeCandidate): string;
var
  D: PEncodingDescriptor;
  Spec: PDbOperandSpec;
  I: Integer;
  Operand: string;
begin
  D := TInstructionDb.Form(C.FormIndex);
  Result := LowerCase(TInstructionDb.MnemonicName(D^.MnemonicIndex));
  for I := 0 to D^.OperandCount - 1 do
  begin
    Spec := TInstructionDb.Operand(C.FormIndex, I);
    if (Spec^.FixedFlags and DB_FO_IS_IMPLICIT) <> 0 then Continue;
    Operand := FormatDecodedOperand(Code, BaseAddress, C, I);
    if Pos(' ', Result) = 0 then Result := Result + ' ' + Operand else Result := Result + ', ' + Operand;
  end;
end;

function DecodeOneInstruction(const Code: TBytes; BaseAddress: NativeUInt; Start: Integer; out Info: TAsmInstructionInfo): Boolean;
var
  Prefix: TAsmDecodePrefix;
  Map: TOpcodeMap;
  OpcodePos, I, N: Integer;
  C, Best: TAsmDecodeCandidate;
  D: PEncodingDescriptor;
  Rel: Int64;
begin
  Info := Default(TAsmInstructionInfo);
  Result := False;
  if (Start < 0) or (Start >= Length(Code)) then Exit;
  Prefix := DecodePrefixes(Code, Start);
  if not MapOpcodeAt(Code, Prefix.Next, Map, OpcodePos) then
  begin
    Info.Address := BaseAddress + NativeUInt(Start);
    Info.Offset := Start;
    Info.Size := 1;
    Info.Mnemonic := 'db';
    Info.Text := 'db $' + IntToHex(Code[Start], 2);
    SetLength(Info.Bytes, 1);
    Info.Bytes[0] := Code[Start];
    Exit(True);
  end;
  Best.FormIndex := -1;
  Best.Score := Low(Integer);
  for I := 0 to TInstructionDb.FormCount - 1 do
    if TryDecodeForm(Code, I, Prefix, Map, OpcodePos, C) and (C.Score > Best.Score) then Best := C;
  if Best.FormIndex < 0 then
  begin
    Info.Address := BaseAddress + NativeUInt(Start);
    Info.Offset := Start;
    Info.Size := 1;
    Info.Mnemonic := 'db';
    Info.Text := 'db $' + IntToHex(Code[Start], 2);
    SetLength(Info.Bytes, 1);
    Info.Bytes[0] := Code[Start];
    Exit(True);
  end;
  D := TInstructionDb.Form(Best.FormIndex);
  Info.Address := BaseAddress + NativeUInt(Start);
  Info.Offset := Start;
  Info.Size := Best.EndPos - Start;
  Info.Mnemonic := LowerCase(TInstructionDb.MnemonicName(D^.MnemonicIndex));
  Info.Text := FormatDecodedText(Code, BaseAddress, Best);
  if D^.HasFixup then
  begin
    case D^.FixupKind of
      dfkRelative8: N := 1;
      dfkRelative32: N := 4;
    else
      N := 0;
    end;
    if ReadSigned(Code, Best.ImmPos, N, Rel) then
    begin
      Info.HasTarget := True;
      Info.TargetAddress := RelativeAddress(BaseAddress, Best.EndPos, Rel);
    end;
  end;
  N := Info.Size;
  SetLength(Info.Bytes, N);
  if N > 0 then Move(Code[Start], Info.Bytes[0], N);
  Result := True;
end;

constructor TAsmInstructionMap.Create(const Code: TBytes; BaseAddress: NativeUInt; const Symbols: TArray<TAsmDebugSymbol>);
begin
  inherited Create;
  FBaseAddress := BaseAddress;
  FCode := System.Copy(Code, 0, Length(Code));
  FSymbols := System.Copy(Symbols, 0, Length(Symbols));
  Decode;
end;

procedure TAsmInstructionMap.Decode;
var
  Offset, N: Integer;
  Info: TAsmInstructionInfo;
  Symbol: TAsmDebugSymbol;
begin
  SetLength(FItems, 0);
  Offset := 0;
  while Offset < Length(FCode) do
  begin
    if not DecodeOneInstruction(FCode, FBaseAddress, Offset, Info) then Break;
    if FindNearestSymbol(Offset, Symbol) then
    begin
      Info.SymbolName := Symbol.Name;
      Info.SymbolOffset := Symbol.Offset;
      Info.SymbolDelta := Offset - Symbol.Offset;
    end;
    if Info.HasTarget and (Info.TargetAddress >= FBaseAddress) then
      if Info.TargetAddress - FBaseAddress <= NativeUInt(High(Integer)) then
        if FindNearestSymbol(Integer(Info.TargetAddress - FBaseAddress), Symbol) then
          if Symbol.Offset = Integer(Info.TargetAddress - FBaseAddress) then
          begin
            Info.TargetSymbol := Symbol.Name;
            Info.Text := Info.Mnemonic + ' ' + Symbol.Name + ' (' + FormatAddress(Info.TargetAddress) + ')';
          end;
    N := Length(FItems);
    SetLength(FItems, N + 1);
    FItems[N] := Info;
    if Info.Size <= 0 then Break;
    Inc(Offset, Info.Size);
  end;
end;

function TAsmInstructionMap.FindNearestSymbol(Offset: Integer; out Symbol: TAsmDebugSymbol): Boolean;
var
  I, Best: Integer;
begin
  Result := False;
  Best := -1;
  Symbol := Default(TAsmDebugSymbol);
  for I := 0 to High(FSymbols) do
    if (FSymbols[I].Offset <= Offset) and (FSymbols[I].Offset > Best) then
    begin
      Best := FSymbols[I].Offset;
      Symbol := FSymbols[I];
      Result := True;
    end;
end;

function TAsmInstructionMap.Count: Integer;
begin
  Result := Length(FItems);
end;

function TAsmInstructionMap.Item(Index: Integer): TAsmInstructionInfo;
begin
  if (Index < 0) or (Index >= Length(FItems)) then raise EArgumentOutOfRangeException.Create('Index');
  Result := FItems[Index];
end;

function TAsmInstructionMap.FindByOffset(Offset: Integer; out Info: TAsmInstructionInfo): Boolean;
var
  I: Integer;
begin
  Info := Default(TAsmInstructionInfo);
  for I := 0 to High(FItems) do
    if (Offset >= FItems[I].Offset) and (Offset < FItems[I].Offset + FItems[I].Size) then
    begin
      Info := FItems[I];
      Exit(True);
    end;
  Result := False;
end;

function TAsmInstructionMap.FindByAddress(Address: Pointer; out Info: TAsmInstructionInfo): Boolean;
var
  A: NativeUInt;
begin
  A := NativeUInt(Address);
  if A < FBaseAddress then Exit(False);
  if A - FBaseAddress > NativeUInt(High(Integer)) then Exit(False);
  Result := FindByOffset(Integer(A - FBaseAddress), Info);
end;

procedure TAsmInstructionMap.SaveToFile(const Filename: string);
begin
  TFile.WriteAllText(Filename, FormatText, TEncoding.UTF8);
end;

function TAsmInstructionMap.FormatText: string;
var
  SB: TStringBuilder;
  I: Integer;
  Info: TAsmInstructionInfo;
  LabelText: string;
begin
  SB := TStringBuilder.Create;
  try
    for I := 0 to High(FItems) do
    begin
      Info := FItems[I];
      if Info.SymbolName <> '' then
      begin
        if Info.SymbolDelta = 0 then LabelText := Info.SymbolName + ':' else LabelText := Info.SymbolName + '+$' + IntToHex(Info.SymbolDelta, 1);
      end
      else
        LabelText := '';
      SB.AppendFormat('+$%4.4x  %s  %-32s %-20s %s', [Info.Offset, FormatAddress(Info.Address), TAsmDumper.ByteView(Info.Bytes), LabelText, Info.Text]);
      SB.AppendLine;
    end;
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

function TAsmDebugLocation.FormatText: string;
var
  SB: TStringBuilder;
begin
  if not Found then
    Exit('Address: ' + FormatAddress(Address) + sLineBreak + 'Block: (not found)');
  SB := TStringBuilder.Create;
  try
    SB.AppendLine('Address: ' + FormatAddress(Address));
    SB.AppendLine('Block: ' + BlockName);
    SB.AppendLine('Base: ' + FormatAddress(BaseAddress));
    SB.AppendLine('Offset: +$' + IntToHex(Offset, 1));
    if SymbolName <> '' then
      SB.AppendLine('Nearest symbol: ' + SymbolName + ' +$' + IntToHex(SymbolDelta, 1))
    else
      SB.AppendLine('Nearest symbol: (none)');
    if InstructionText <> '' then
      SB.AppendLine('Instruction +$' + IntToHex(InstructionOffset, 1) + ' +$' + IntToHex(InstructionDelta, 1) + ' (' + IntToStr(InstructionSize) + ' bytes): ' + InstructionText);
    if Length(InstructionBytes) > 0 then
      SB.AppendLine('Instruction bytes: ' + TAsmDumper.ByteView(InstructionBytes));
    if Length(Bytes) > 0 then
      SB.AppendLine('Bytes +' + IntToHex(BytesOffset, 1) + ': ' + TAsmDumper.ByteView(Bytes));
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

constructor TAsmDebugBlock.Create(const AName: string; ABaseAddress: NativeUInt; ASize: Integer; SnapshotBytes: Boolean);
begin
  if ASize < 0 then
    raise EArgumentOutOfRangeException.Create('ASize');
  FName := AName;
  FBaseAddress := ABaseAddress;
  FSize := ASize;
  FSymbols := TList<TAsmDebugSymbol>.Create;
  if SnapshotBytes then
    RefreshBytes;
end;

destructor TAsmDebugBlock.Destroy;
begin
  FInstructionMap.Free;
  FSymbols.Free;
  inherited;
end;

procedure TAsmDebugBlock.AddSymbol(const Name: string; Offset: Integer);
var
  Item: TAsmDebugSymbol;
begin
  if Name = '' then
    raise EArgumentException.Create('Symbol name must not be empty');
  if (Offset < 0) or (Offset > FSize) then
    raise EArgumentOutOfRangeException.CreateFmt('Symbol offset %d is outside block size %d', [Offset, FSize]);
  Item.Name := Name;
  Item.Offset := Offset;
  FSymbols.Add(Item);
  FreeAndNil(FInstructionMap);
end;

procedure TAsmDebugBlock.AddLabels(Labels: TAsmLabelMap);
var
  Pair: TPair<string, Integer>;
begin
  if Labels = nil then Exit;
  for Pair in Labels.Map do
    AddSymbol(DisplayLabelName(Pair.Key), Pair.Value);
end;

procedure TAsmDebugBlock.RefreshBytes;
begin
  FreeAndNil(FInstructionMap);
  if (FBaseAddress = 0) or (FSize = 0) then
  begin
    SetLength(FCode, 0);
    Exit;
  end;
  SetLength(FCode, FSize);
  Move(Pointer(FBaseAddress)^, FCode[0], FSize);
end;

function TAsmDebugBlock.FindNearestSymbol(Offset: Integer; out Symbol: TAsmDebugSymbol): Boolean;
var
  I, Best: Integer;
begin
  Result := False;
  Best := -1;
  Symbol := Default(TAsmDebugSymbol);
  for I := 0 to FSymbols.Count - 1 do
    if (FSymbols[I].Offset <= Offset) and (FSymbols[I].Offset > Best) then
    begin
      Best := FSymbols[I].Offset;
      Symbol := FSymbols[I];
      Result := True;
    end;
end;

function TAsmDebugBlock.BytesAt(Offset, Count: Integer): TBytes;
var
  N: Integer;
begin
  SetLength(Result, 0);
  if (Offset < 0) or (Count <= 0) or (Offset >= Length(FCode)) then Exit;
  N := Count;
  if N > Length(FCode) - Offset then
    N := Length(FCode) - Offset;
  SetLength(Result, N);
  Move(FCode[Offset], Result[0], N);
end;

function TAsmDebugBlock.GetSymbols: TArray<TAsmDebugSymbol>;
var
  I, J: Integer;
  Temp: TAsmDebugSymbol;
begin
  SetLength(Result, FSymbols.Count);
  for I := 0 to FSymbols.Count - 1 do
    Result[I] := FSymbols[I];
  for I := 1 to High(Result) do
  begin
    Temp := Result[I];
    J := I - 1;
    while (J >= 0) and (Result[J].Offset > Temp.Offset) do
    begin
      Result[J + 1] := Result[J];
      Dec(J);
    end;
    Result[J + 1] := Temp;
  end;
end;

function TAsmDebugBlock.FormatMap: string;
var
  SB: TStringBuilder;
  Items: TArray<TAsmDebugSymbol>;
  Item: TAsmDebugSymbol;
begin
  SB := TStringBuilder.Create;
  try
    SB.AppendLine('Block: ' + FName);
    SB.AppendLine('Base: ' + FormatAddress(FBaseAddress));
    SB.AppendLine('Size: ' + IntToStr(FSize));
    Items := GetSymbols;
    for Item in Items do
      SB.AppendLine('+$' + IntToHex(Item.Offset, 4) + ' ' + Item.Name);
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

function TAsmDebugBlock.GetInstructionMap: TAsmInstructionMap;
begin
  if FInstructionMap = nil then FInstructionMap := CreateInstructionMap;
  Result := FInstructionMap;
end;

function TAsmDebugBlock.CreateInstructionMap: TAsmInstructionMap;
begin
  if Length(FCode) <> FSize then raise Exception.Create('No byte snapshot is available for this block');
  Result := TAsmInstructionMap.Create(FCode, FBaseAddress, GetSymbols);
end;

procedure TAsmDebugBlock.SaveBinary(const Filename: string);
begin
  if Length(FCode) <> FSize then
    raise Exception.Create('No byte snapshot is available for this block');
  TFile.WriteAllBytes(Filename, FCode);
end;

procedure TAsmDebugBlock.SaveMap(const Filename: string);
var
  Lines: TStringList;
  Items: TArray<TAsmDebugSymbol>;
  Item: TAsmDebugSymbol;
begin
  Lines := TStringList.Create;
  try
    Lines.Add('NativeAsmMap=1');
    Lines.Add('Name=' + EscapeMapText(FName));
    Lines.Add('Base=' + IntToHex(Int64(FBaseAddress), SizeOf(Pointer) * 2));
    Lines.Add('Size=' + IntToHex(FSize, 8));
    Items := GetSymbols;
    for Item in Items do
      Lines.Add('Symbol=' + IntToHex(Item.Offset, 8) + '|' + EscapeMapText(Item.Name));
    Lines.SaveToFile(Filename, TEncoding.UTF8);
  finally
    Lines.Free;
  end;
end;

class function TAsmDebugBlock.LoadMap(const Filename: string): TAsmDebugBlock;
var
  Lines: TStringList;
  Name, Value: string;
  Base: UInt64;
  Size64, Offset64: UInt64;
  I, P: Integer;
begin
  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(Filename, TEncoding.UTF8);
    if (Lines.Count = 0) or (Lines[0] <> 'NativeAsmMap=1') then
      raise EConvertError.Create('Invalid NativeAsm map file');
    Name := '';
    Base := 0;
    Size64 := 0;
    for I := 1 to Lines.Count - 1 do
    begin
      if Copy(Lines[I], 1, 5) = 'Name=' then
        Name := UnescapeMapText(Copy(Lines[I], 6, MaxInt))
      else if Copy(Lines[I], 1, 5) = 'Base=' then
        Base := ParseHexUInt64(Copy(Lines[I], 6, MaxInt))
      else if Copy(Lines[I], 1, 5) = 'Size=' then
        Size64 := ParseHexUInt64(Copy(Lines[I], 6, MaxInt));
    end;
    if Base > UInt64(High(NativeUInt)) then
      raise EConvertError.Create('Map base address is out of range');
    if Size64 > UInt64(MaxInt) then
      raise EConvertError.Create('Map block size is out of range');
    Result := TAsmDebugBlock.Create(Name, NativeUInt(Base), Integer(Size64), False);
    try
      for I := 1 to Lines.Count - 1 do
        if Copy(Lines[I], 1, 7) = 'Symbol=' then
        begin
          Value := Copy(Lines[I], 8, MaxInt);
          P := Pos('|', Value);
          if P <= 1 then
            raise EConvertError.CreateFmt('Invalid symbol line %d', [I + 1]);
          Offset64 := ParseHexUInt64(Copy(Value, 1, P - 1));
          if Offset64 > UInt64(MaxInt) then
            raise EConvertError.CreateFmt('Symbol offset on line %d is out of range', [I + 1]);
          Result.AddSymbol(UnescapeMapText(Copy(Value, P + 1, MaxInt)), Integer(Offset64));
        end;
    except
      Result.Free;
      raise;
    end;
  finally
    Lines.Free;
  end;
end;

function ResolveAddress(Registry: TAsmDebugRegistry; Address: Pointer; ByteCount: Integer): TAsmDebugLocation;
begin
  if Registry = nil then
    raise EArgumentNilException.Create('Registry');
  Result := Registry.Resolve(Address, ByteCount);
end;

constructor TAsmDebugRegistry.Create;
begin
  FBlocks := TObjectList<TAsmDebugBlock>.Create(True);
end;

destructor TAsmDebugRegistry.Destroy;
begin
  FBlocks.Free;
  inherited;
end;

function TAsmDebugRegistry.RegisterBlock(const Name: string; BaseAddress: Pointer; Size: Integer; Labels: TAsmLabelMap; SnapshotBytes: Boolean): TAsmDebugBlock;
var
  I: Integer;
  Base, Last, OtherBase, OtherLast: NativeUInt;
begin
  if Name = '' then
    raise EArgumentException.Create('Block name must not be empty');
  if BaseAddress = nil then
    raise EArgumentNilException.Create('BaseAddress');
  if Size <= 0 then
    raise EArgumentOutOfRangeException.Create('Size');
  Base := NativeUInt(BaseAddress);
  if NativeUInt(Size) > High(NativeUInt) - Base then
    raise EArgumentOutOfRangeException.Create('Size');
  Last := Base + NativeUInt(Size);
  Result := TAsmDebugBlock.Create(Name, Base, Size, SnapshotBytes);
  try
    Result.AddLabels(Labels);
    TMonitor.Enter(Self);
    try
      for I := 0 to FBlocks.Count - 1 do
      begin
        OtherBase := FBlocks[I].BaseAddress;
        OtherLast := OtherBase + NativeUInt(FBlocks[I].Size);
        if (Base < OtherLast) and (OtherBase < Last) then
          raise EArgumentException.CreateFmt('Debug block "%s" overlaps "%s"', [Name, FBlocks[I].Name]);
      end;
      FBlocks.Add(Result);
    finally
      TMonitor.Exit(Self);
    end;
  except
    Result.Free;
    raise;
  end;
end;

function TAsmDebugRegistry.RegisterBuilderBlock(const Name: string; BaseAddress: Pointer; Size: Integer; Builder: TAsmBuilder; SnapshotBytes: Boolean): TAsmDebugBlock;
var
  Labels: TAsmLabelMap;
begin
  if Builder = nil then
    raise EArgumentNilException.Create('Builder');
  Labels := TAsmLabelMap.FromBuilder(Builder);
  try
    Result := RegisterBlock(Name, BaseAddress, Size, Labels, SnapshotBytes);
  finally
    Labels.Free;
  end;
end;

function TAsmDebugRegistry.UnregisterBlock(BaseAddress: Pointer): Boolean;
var
  I: Integer;
begin
  Result := False;
  TMonitor.Enter(Self);
  try
    for I := FBlocks.Count - 1 downto 0 do
      if FBlocks[I].BaseAddress = NativeUInt(BaseAddress) then
      begin
        FBlocks.Delete(I);
        Exit(True);
      end;
  finally
    TMonitor.Exit(Self);
  end;
end;

function TAsmDebugRegistry.Resolve(Address: Pointer; ByteCount: Integer): TAsmDebugLocation;
var
  I: Integer;
  A, BlockEnd: NativeUInt;
  Block: TAsmDebugBlock;
  Symbol: TAsmDebugSymbol;
  Instruction: TAsmInstructionInfo;
begin
  Result := Default(TAsmDebugLocation);
  A := NativeUInt(Address);
  Result.Address := A;
  if ByteCount < 0 then
    raise EArgumentOutOfRangeException.Create('ByteCount');
  TMonitor.Enter(Self);
  try
    for I := 0 to FBlocks.Count - 1 do
    begin
      Block := FBlocks[I];
      BlockEnd := Block.BaseAddress + NativeUInt(Block.Size);
      if (A >= Block.BaseAddress) and (A < BlockEnd) then
      begin
        Result.Found := True;
        Result.BlockName := Block.Name;
        Result.BaseAddress := Block.BaseAddress;
        Result.BlockSize := Block.Size;
        Result.Offset := Integer(A - Block.BaseAddress);
        if Block.FindNearestSymbol(Result.Offset, Symbol) then
        begin
          Result.SymbolName := Symbol.Name;
          Result.SymbolOffset := Symbol.Offset;
          Result.SymbolDelta := Result.Offset - Symbol.Offset;
        end;
        Result.BytesOffset := Result.Offset;
        Result.Bytes := Block.BytesAt(Result.Offset, ByteCount);
        if Block.GetInstructionMap.FindByOffset(Result.Offset, Instruction) then
        begin
          Result.InstructionOffset := Instruction.Offset;
          Result.InstructionSize := Instruction.Size;
          Result.InstructionDelta := Result.Offset - Instruction.Offset;
          Result.InstructionText := Instruction.Text;
          Result.InstructionBytes := Instruction.Bytes;
        end;
        Exit;
      end;
    end;
  finally
    TMonitor.Exit(Self);
  end;
end;

procedure TAsmDebugRegistry.Clear;
begin
  TMonitor.Enter(Self);
  try
    FBlocks.Clear;
  finally
    TMonitor.Exit(Self);
  end;
end;

function TAsmDebugRegistry.Count: Integer;
begin
  TMonitor.Enter(Self);
  try
    Result := FBlocks.Count;
  finally
    TMonitor.Exit(Self);
  end;
end;

function HexRegister(Value: UInt64): string;
begin
  Result := '$' + IntToHex(Int64(Value), 16);
end;

function TAsmRegisterSnapshot.FormatText: string;
var
  SB: TStringBuilder;
begin
  SB := TStringBuilder.Create;
  try
    SB.AppendLine('RAX=' + HexRegister(Rax) + '  RBX=' + HexRegister(Rbx) + '  RCX=' + HexRegister(Rcx) + '  RDX=' + HexRegister(Rdx));
    SB.AppendLine('RSI=' + HexRegister(Rsi) + '  RDI=' + HexRegister(Rdi) + '  RBP=' + HexRegister(Rbp) + '  RSP=' + HexRegister(Rsp));
    SB.AppendLine('R8 =' + HexRegister(R8) + '  R9 =' + HexRegister(R9) + '  R10=' + HexRegister(R10) + '  R11=' + HexRegister(R11));
    SB.AppendLine('R12=' + HexRegister(R12) + '  R13=' + HexRegister(R13) + '  R14=' + HexRegister(R14) + '  R15=' + HexRegister(R15));
    SB.AppendLine('RIP=' + HexRegister(Rip) + '  EFLAGS=$' + IntToHex(EFlags, 8));
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

function TAsmBreakpointHit.FormatText: string;
var
  SB: TStringBuilder;
begin
  SB := TStringBuilder.Create;
  try
    if Breakpoint <> nil then
    begin
      SB.AppendLine('Breakpoint: ' + Breakpoint.Name);
      SB.AppendLine('Hit count: ' + UIntToStr(Breakpoint.HitCount));
    end;
    SB.AppendLine('Thread: ' + UIntToStr(ThreadId));
    SB.Append(Location.FormatText);
    SB.AppendLine;
    SB.AppendLine('Registers:');
    SB.Append(Registers.FormatText);
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

var
  GAsmBreakpointManager: TAsmBreakpointManager;

function NativeAsmBreakpointVectoredHandler(ExceptionInfo: PExceptionPointers): LongInt; stdcall;
var
  Manager: TAsmBreakpointManager;
begin
  Manager := GAsmBreakpointManager;
  if Manager = nil then Exit(NATIVEASM_EXCEPTION_CONTINUE_SEARCH);
  Result := Manager.HandleException(ExceptionInfo);
end;

constructor TAsmBreakpointManager.Create(Registry: TAsmDebugRegistry);
begin
  if Registry = nil then raise EArgumentNilException.Create('Registry');
  FRegistry := Registry;
  FTlsIndex := TLS_OUT_OF_INDEXES;
  FBreakpoints := TObjectList<TAsmSoftwareBreakpoint>.Create(True);
  FTlsIndex := TlsAlloc;
  if FTlsIndex = TLS_OUT_OF_INDEXES then raise EAsmDebugError.Create('Unable to allocate breakpoint TLS slot');
  SetLength(FHitBuffer, 256);
end;

destructor TAsmBreakpointManager.Destroy;
var
  I: Integer;
begin
  if FBreakpoints <> nil then
    for I := 0 to FBreakpoints.Count - 1 do
      if FBreakpoints[I].FEnabled then
      begin
        TryPatchByte(FBreakpoints[I].FAddress, FBreakpoints[I].FOriginalByte);
        FBreakpoints[I].FEnabled := False;
      end;
  if FHandler <> nil then NativeAsmRemoveVectoredExceptionHandler(FHandler);
  if GAsmBreakpointManager = Self then GAsmBreakpointManager := nil;
  if FTlsIndex <> TLS_OUT_OF_INDEXES then TlsFree(FTlsIndex);
  FBreakpoints.Free;
  inherited;
end;

class function TAsmBreakpointManager.TryPatchByte(Address: NativeUInt; Value: Byte): Boolean;
var
  OldProtect, DummyProtect: Cardinal;
begin
  Result := False;
  if Address = 0 then Exit;
  if not VirtualProtect(Pointer(Address), 1, PAGE_EXECUTE_READWRITE, OldProtect) then Exit;
  PByte(Pointer(Address))^ := Value;
  Result := VirtualProtect(Pointer(Address), 1, OldProtect, DummyProtect);
  if not FlushInstructionCache(GetCurrentProcess, Pointer(Address), 1) then Result := False;
end;

class procedure TAsmBreakpointManager.PatchByte(Address: NativeUInt; Value: Byte);
begin
  if not TryPatchByte(Address, Value) then RaiseLastOSError;
end;

procedure TAsmBreakpointManager.Install;
begin
{$IFNDEF WIN64}
  raise EAsmDebugError.Create('NativeAsm software breakpoints require Win64');
{$ENDIF}
  TMonitor.Enter(Self);
  try
    if FInstalled then Exit;
    if (GAsmBreakpointManager <> nil) and (GAsmBreakpointManager <> Self) then
      raise EAsmDebugError.Create('Another NativeAsm breakpoint manager is already installed');
    GAsmBreakpointManager := Self;
    FHandler := NativeAsmAddVectoredExceptionHandler(1, @NativeAsmBreakpointVectoredHandler);
    if FHandler = nil then
    begin
      GAsmBreakpointManager := nil;
      RaiseLastOSError;
    end;
    FInstalled := True;
  finally
    TMonitor.Exit(Self);
  end;
end;

procedure TAsmBreakpointManager.Uninstall;
var
  I: Integer;
begin
  TMonitor.Enter(Self);
  try
    if not FInstalled then Exit;
    if FPendingCount <> 0 then raise EAsmDebugError.Create('Cannot uninstall while a breakpoint is pending single-step rearm');
    for I := 0 to FBreakpoints.Count - 1 do
      if FBreakpoints[I].FEnabled then
      begin
        PatchByte(FBreakpoints[I].FAddress, FBreakpoints[I].FOriginalByte);
        FBreakpoints[I].FEnabled := False;
      end;
    if NativeAsmRemoveVectoredExceptionHandler(FHandler) = Cardinal(0) then RaiseLastOSError;
    FHandler := nil;
    FInstalled := False;
    if GAsmBreakpointManager = Self then GAsmBreakpointManager := nil;
  finally
    TMonitor.Exit(Self);
  end;
end;

function TAsmBreakpointManager.FindByAddress(Address: NativeUInt): TAsmSoftwareBreakpoint;
var
  I: Integer;
begin
  for I := 0 to FBreakpoints.Count - 1 do
    if FBreakpoints[I].FAddress = Address then Exit(FBreakpoints[I]);
  Result := nil;
end;

function TAsmBreakpointManager.AddBreakpoint(Block: TAsmDebugBlock; Offset: Integer; const Name: string): TAsmSoftwareBreakpoint;
var
  Info: TAsmInstructionInfo;
  BlockLocation: TAsmDebugLocation;
  Address: NativeUInt;
begin
  if Block = nil then raise EArgumentNilException.Create('Block');
  BlockLocation := FRegistry.Resolve(Pointer(Block.BaseAddress), 0);
  if not BlockLocation.Found or (BlockLocation.BaseAddress <> Block.BaseAddress) then
    raise EArgumentException.Create('Block is not registered in this breakpoint manager registry');
  if (Offset < 0) or (Offset >= Block.Size) then raise EArgumentOutOfRangeException.Create('Offset');
  if not Block.GetInstructionMap.FindByOffset(Offset, Info) or (Info.Offset <> Offset) then
    raise EArgumentException.CreateFmt('Breakpoint offset %d is not an instruction boundary', [Offset]);
  if Info.Mnemonic = 'db' then
    raise EArgumentException.CreateFmt('Breakpoint offset %d does not resolve to a known instruction', [Offset]);
  Address := Block.BaseAddress + NativeUInt(Offset);
  if not FInstalled then Install;
  TMonitor.Enter(Self);
  try
    if (FPendingCount <> 0) or (PendingHitCount <> 0) then raise EAsmDebugError.Create('Cannot modify breakpoints while breakpoint hits are pending');
    if FindByAddress(Address) <> nil then raise EArgumentException.CreateFmt('A breakpoint already exists at +$%x', [Offset]);
    Result := TAsmSoftwareBreakpoint.Create;
    try
      Result.FName := Name;
      Result.FBlockName := Block.Name;
      Result.FAddress := Address;
      Result.FOffset := Offset;
      Result.FOriginalByte := Info.Bytes[0];
      PatchByte(Address, $CC);
      Result.FEnabled := True;
      try
        FBreakpoints.Add(Result);
      except
        TryPatchByte(Address, Result.FOriginalByte);
        Result.FEnabled := False;
        raise;
      end;
    except
      Result.Free;
      raise;
    end;
  finally
    TMonitor.Exit(Self);
  end;
end;

function TAsmBreakpointManager.SetBreakpoint(Block: TAsmDebugBlock; Offset: Integer): TAsmSoftwareBreakpoint;
begin
  if Block = nil then raise EArgumentNilException.Create('Block');
  Result := AddBreakpoint(Block, Offset, Block.Name + '+$' + IntToHex(Offset, 1));
end;

function TAsmBreakpointManager.SetBreakpoint(Block: TAsmDebugBlock; const SymbolName: string): TAsmSoftwareBreakpoint;
var
  Symbols: TArray<TAsmDebugSymbol>;
  Symbol: TAsmDebugSymbol;
  I, Matches: Integer;
begin
  if Block = nil then raise EArgumentNilException.Create('Block');
  if SymbolName = '' then raise EArgumentException.Create('SymbolName must not be empty');
  Symbols := Block.Symbols;
  Matches := 0;
  Symbol := Default(TAsmDebugSymbol);
  for I := 0 to High(Symbols) do
    if Symbols[I].Name = SymbolName then
    begin
      Symbol := Symbols[I];
      Inc(Matches);
    end;
  if Matches = 0 then raise EArgumentException.CreateFmt('Symbol "%s" was not found in block "%s"', [SymbolName, Block.Name]);
  if Matches > 1 then raise EArgumentException.CreateFmt('Symbol "%s" is ambiguous in block "%s"', [SymbolName, Block.Name]);
  Result := AddBreakpoint(Block, Symbol.Offset, SymbolName);
end;

procedure TAsmBreakpointManager.EnableBreakpoint(Breakpoint: TAsmSoftwareBreakpoint);
begin
  if Breakpoint = nil then raise EArgumentNilException.Create('Breakpoint');
  if not FInstalled then Install;
  TMonitor.Enter(Self);
  try
    if (FPendingCount <> 0) or (PendingHitCount <> 0) then raise EAsmDebugError.Create('Cannot modify breakpoints while breakpoint hits are pending');
    if FBreakpoints.IndexOf(Breakpoint) < 0 then raise EArgumentException.Create('Breakpoint does not belong to this manager');
    if Breakpoint.FEnabled then Exit;
    PatchByte(Breakpoint.FAddress, $CC);
    Breakpoint.FEnabled := True;
  finally
    TMonitor.Exit(Self);
  end;
end;

procedure TAsmBreakpointManager.DisableBreakpoint(Breakpoint: TAsmSoftwareBreakpoint);
begin
  if Breakpoint = nil then raise EArgumentNilException.Create('Breakpoint');
  TMonitor.Enter(Self);
  try
    if FPendingCount <> 0 then raise EAsmDebugError.Create('Cannot modify breakpoints while single-step rearm is pending');
    if FBreakpoints.IndexOf(Breakpoint) < 0 then raise EArgumentException.Create('Breakpoint does not belong to this manager');
    if not Breakpoint.FEnabled then Exit;
    PatchByte(Breakpoint.FAddress, Breakpoint.FOriginalByte);
    Breakpoint.FEnabled := False;
  finally
    TMonitor.Exit(Self);
  end;
end;

function TAsmBreakpointManager.RemoveBreakpoint(Breakpoint: TAsmSoftwareBreakpoint): Boolean;
var
  Index: Integer;
begin
  if Breakpoint = nil then Exit(False);
  TMonitor.Enter(Self);
  try
    if (FPendingCount <> 0) or (PendingHitCount <> 0) then raise EAsmDebugError.Create('Cannot modify breakpoints while breakpoint hits are pending');
    Index := FBreakpoints.IndexOf(Breakpoint);
    if Index < 0 then Exit(False);
    if Breakpoint.FEnabled then PatchByte(Breakpoint.FAddress, Breakpoint.FOriginalByte);
    FBreakpoints.Delete(Index);
    Result := True;
  finally
    TMonitor.Exit(Self);
  end;
end;

procedure TAsmBreakpointManager.Clear;
var
  I: Integer;
begin
  TMonitor.Enter(Self);
  try
    if (FPendingCount <> 0) or (PendingHitCount <> 0) then raise EAsmDebugError.Create('Cannot modify breakpoints while breakpoint hits are pending');
    for I := 0 to FBreakpoints.Count - 1 do
      if FBreakpoints[I].FEnabled then PatchByte(FBreakpoints[I].FAddress, FBreakpoints[I].FOriginalByte);
    FBreakpoints.Clear;
  finally
    TMonitor.Exit(Self);
  end;
end;

procedure TAsmBreakpointManager.QueueHit(Breakpoint: TAsmSoftwareBreakpoint; ThreadId: Cardinal; const Registers: TAsmRegisterSnapshot);
var
  Sequence, Index: LongInt;
begin
  Sequence := InterlockedIncrement(FHitWrite) - 1;
  Index := Sequence mod Length(FHitBuffer);
  FHitBuffer[Index].Breakpoint := Breakpoint;
  FHitBuffer[Index].ThreadId := ThreadId;
  FHitBuffer[Index].Registers := Registers;
end;

function TAsmBreakpointManager.TryDequeueHit(out Hit: TAsmBreakpointHit): Boolean;
var
  WriteIndex, Lost, Index: LongInt;
  Raw: TAsmBreakpointRawHit;
begin
  Hit := Default(TAsmBreakpointHit);
  WriteIndex := FHitWrite;
  if FHitRead >= WriteIndex then Exit(False);
  if WriteIndex - FHitRead > Length(FHitBuffer) then
  begin
    Lost := WriteIndex - FHitRead - Length(FHitBuffer);
    Inc(FDroppedHits, Lost);
    FHitRead := WriteIndex - Length(FHitBuffer);
  end;
  Index := FHitRead mod Length(FHitBuffer);
  Raw := FHitBuffer[Index];
  Inc(FHitRead);
  if Raw.Breakpoint = nil then Exit(False);
  Hit.Breakpoint := Raw.Breakpoint;
  Hit.ThreadId := Raw.ThreadId;
  Hit.Registers := Raw.Registers;
  Hit.Location := FRegistry.Resolve(Pointer(Raw.Breakpoint.Address));
  Result := True;
end;

procedure TAsmBreakpointManager.DispatchPendingHits;
var
  Hit: TAsmBreakpointHit;
  Callback: TAsmBreakpointHitEvent;
begin
  FLastCallbackError := '';
  Callback := FOnHit;
  while TryDequeueHit(Hit) do
    if Assigned(Callback) then
      try
        Callback(Hit);
      except
        on E: Exception do FLastCallbackError := E.ClassName + ': ' + E.Message;
      end;
end;

function TAsmBreakpointManager.PendingHitCount: Integer;
var
  N: LongInt;
begin
  N := FHitWrite - FHitRead;
  if N < 0 then N := 0;
  if N > Length(FHitBuffer) then N := Length(FHitBuffer);
  Result := N;
end;

function TAsmBreakpointManager.Count: Integer;
begin
  TMonitor.Enter(Self);
  try
    Result := FBreakpoints.Count;
  finally
    TMonitor.Exit(Self);
  end;
end;

function SnapshotRegisters(Context: PContext): TAsmRegisterSnapshot;
begin
  Result := Default(TAsmRegisterSnapshot);
{$IFDEF WIN64}
  Result.Rax := Context^.Rax;
  Result.Rbx := Context^.Rbx;
  Result.Rcx := Context^.Rcx;
  Result.Rdx := Context^.Rdx;
  Result.Rsi := Context^.Rsi;
  Result.Rdi := Context^.Rdi;
  Result.Rbp := Context^.Rbp;
  Result.Rsp := Context^.Rsp;
  Result.R8 := Context^.R8;
  Result.R9 := Context^.R9;
  Result.R10 := Context^.R10;
  Result.R11 := Context^.R11;
  Result.R12 := Context^.R12;
  Result.R13 := Context^.R13;
  Result.R14 := Context^.R14;
  Result.R15 := Context^.R15;
  Result.Rip := Context^.Rip;
  Result.EFlags := Context^.EFlags;
{$ENDIF}
end;

function TAsmBreakpointManager.HandleException(ExceptionInfo: Pointer): LongInt;
var
  Info: PExceptionPointers;
  Breakpoint: TAsmSoftwareBreakpoint;
  Address: NativeUInt;
  ThreadId: Cardinal;
  Registers: TAsmRegisterSnapshot;
begin
  Result := NATIVEASM_EXCEPTION_CONTINUE_SEARCH;
  if not FInstalled or (ExceptionInfo = nil) then Exit;
  Info := PExceptionPointers(ExceptionInfo);
{$IFNDEF WIN64}
  Exit;
{$ELSE}
  ThreadId := GetCurrentThreadId;
  if Info^.ExceptionRecord^.ExceptionCode = EXCEPTION_BREAKPOINT then
  begin
    Address := NativeUInt(Info^.ExceptionRecord^.ExceptionAddress);
    Breakpoint := FindByAddress(Address);
    if (Breakpoint = nil) or not Breakpoint.FEnabled then Exit;
    if not TryPatchByte(Address, Breakpoint.FOriginalByte) then Exit;
    if not TlsSetValue(FTlsIndex, Pointer(Breakpoint)) then
    begin
      TryPatchByte(Address, $CC);
      Exit;
    end;
    InterlockedIncrement(FPendingCount);
    Inc(Breakpoint.FHitCount);
    PContext(Info^.ContextRecord)^.Rip := Address;
    Registers := SnapshotRegisters(PContext(Info^.ContextRecord));
    QueueHit(Breakpoint, ThreadId, Registers);
    PContext(Info^.ContextRecord)^.EFlags := PContext(Info^.ContextRecord)^.EFlags or $100;
    Exit(NATIVEASM_EXCEPTION_CONTINUE_EXECUTION);
  end;
  if Info^.ExceptionRecord^.ExceptionCode = EXCEPTION_SINGLE_STEP then
  begin
    Breakpoint := TAsmSoftwareBreakpoint(TlsGetValue(FTlsIndex));
    if Breakpoint = nil then Exit;
    if Breakpoint.FEnabled and not TryPatchByte(Breakpoint.FAddress, $CC) then Breakpoint.FEnabled := False;
    TlsSetValue(FTlsIndex, nil);
    InterlockedDecrement(FPendingCount);
    PContext(Info^.ContextRecord)^.EFlags := PContext(Info^.ContextRecord)^.EFlags and not Cardinal($100);
    Exit(NATIVEASM_EXCEPTION_CONTINUE_EXECUTION);
  end;
{$ENDIF}
end;

// ---------------------------------------------------------------------------
// TAsmBuilderInspector
// ---------------------------------------------------------------------------

constructor TAsmBuilderInspector.Create(Builder: TAsmBuilder;
  const Label_: string);
begin
  FBuilder := Builder;
  FLabel   := Label_;
end;

procedure TAsmBuilderInspector.DumpToConsole;
var
  Code : TBytes;
  Title: string;
begin
  Code := FBuilder.Build;
  if FLabel <> '' then
    Title := '[' + FLabel + '] '
  else
    Title := '';

  Writeln(Title + 'Code size: ', Length(Code), ' bytes');
  Writeln(TAsmDumper.StatsText(Code));
  Write(TAsmDumper.HexDump(Code));
end;

procedure TAsmBuilderInspector.DumpToStrings(Target: TStrings);
var
  Code  : TBytes;
  Title : string;
  Tokens: TStringList;
begin
  if Target = nil then Exit;
  Code := FBuilder.Build;

  if FLabel <> '' then
    Title := '[' + FLabel + '] '
  else
    Title := '';

  Target.Add(Title + 'Code size: ' + IntToStr(Length(Code)) + ' bytes');
  Target.Add(TAsmDumper.StatsText(Code));

  // TokenView allocates a TStringList -- must be freed after use to avoid leak.
  Tokens := TAsmDumper.TokenView(Code);
  try
    Target.AddStrings(Tokens);
  finally
    Tokens.Free;
  end;

  Target.Add('');
  Target.Add(TAsmDumper.HexDump(Code));
end;

procedure TAsmBuilderInspector.DumpToFile(const Filename: string);
var
  Code: TBytes;
begin
  Code := FBuilder.Build;
  TFile.WriteAllBytes(Filename, Code);
end;

end.
