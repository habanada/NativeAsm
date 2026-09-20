{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
unit NativeAsm.Extensions;

{
  NativeAsm — High-Level Extensions
  =========================================
  Author : Selahattin Erkoc
  Purpose: Higher-level abstractions built on top of TAsmBuilder:

    TExecutableCode   – manages a VirtualAlloc'd (or TJitAllocator-backed)
                        RX block; owns the memory and exposes typed Run
                        overloads.

    TSmartAsmBuilder  – extends TAsmBuilder with Win64-ABI-aware helpers,
                        loop sugar, and CompileToExecutable.

  Notes on executable memory
  --------------------------
  TExecutableCode uses PAGE_EXECUTE_READ by default (DEP-compatible).
  Pass SMC := True only when code will modify itself at runtime; this
  requires PAGE_EXECUTE_READWRITE, which is more conspicuous to security
  tooling.  For ordinary PE stubs, SMC is never needed.

  TJitAllocator integration
  -------------------------
  Pass an existing TJitAllocator to TExecutableCode.Create to sub-allocate
  from a shared pool rather than issuing a fresh VirtualAlloc per stub.
  When an allocator is provided, TExecutableCode does NOT free the memory
  on Destroy — the allocator owns the pool.  Commit() is still called on
  the slice so the CPU can execute it.
}

{$ALIGN ON}
{$MINENUMSIZE 4}
{$RTTI EXPLICIT METHODS([]) PROPERTIES([]) FIELDS([])}
{$WEAKLINKRTTI ON}

interface

uses
  System.SysUtils,
  System.Classes,
  Winapi.Windows,
  NativeAsm.Types,
  NativeAsm.Builder,
  NativeAsm.JitAlloc;

// ---------------------------------------------------------------------------
// TExecutableCode
// ---------------------------------------------------------------------------

type
  EAsmError = class(Exception);

  /// <summary>
  ///   Owns an executable memory region containing generated x64 machine code.
  ///
  ///   Memory source:
  ///     Allocator = nil (default) → VirtualAlloc per instance (PAGE_READWRITE,
  ///       then flipped to PAGE_EXECUTE_READ).  Freed on Destroy.
  ///     Allocator supplied → sub-allocates from the pool; Commit is called on
  ///       the slice.  The pool (and its memory) is owned by the caller.
  ///
  ///   Typical usage (standalone):
  ///     var Exe := TExecutableCode.FromBuilder(MyBuilder);
  ///     try
  ///       Result := Exe.Run(Arg1);
  ///     finally
  ///       Exe.Free;
  ///     end;
  ///
  ///   Typical usage (shared pool):
  ///     var Pool := TJitAllocator.Create;
  ///     try
  ///       Exe1 := TExecutableCode.FromBuilder(B1, False, Pool);
  ///       Exe2 := TExecutableCode.FromBuilder(B2, False, Pool);
  ///       ...
  ///     finally
  ///       Exe1.Free; Exe2.Free;
  ///       Pool.Free;   // releases all stubs at once
  ///     end;
  /// </summary>
  TExecutableCode = class
  private
    FMemory       : Pointer;
    FSize         : Integer;
    FIsExecutable : Boolean;
    FOwnsMemory   : Boolean;  // True when we VirtualAlloc'd our own region

    function CallInternal(const Args: array of UInt64): UInt64;
  public
    /// <summary>
    ///   Allocate and copy Code into executable memory.
    ///   SMC = True  → PAGE_EXECUTE_READWRITE (self-modifying code).
    ///   SMC = False → PAGE_EXECUTE_READ (default, DEP-friendly).
    ///   Allocator   → supply to sub-allocate from a shared pool; nil = own alloc.
    /// </summary>
    constructor Create(const Code: TBytes; SMC: Boolean = False;
      Allocator: TJitAllocator = nil);

    /// <summary>Build the builder and take ownership of the result.</summary>
    class function FromBuilder(Builder: TAsmBuilder;
      SMC: Boolean = False;
      Allocator: TJitAllocator = nil): TExecutableCode;

    destructor Destroy; override;

    // ── Execution ─────────────────────────────────────────────────────────────
    function Run: UInt64; overload;
    function Run(Arg1: UInt64): UInt64; overload;
    function Run(Arg1, Arg2: UInt64): UInt64; overload;
    function Run(Arg1, Arg2, Arg3: UInt64): UInt64; overload;
    function Run(Arg1, Arg2, Arg3, Arg4: UInt64): UInt64; overload;

    // ── Patching ──────────────────────────────────────────────────────────────

    /// <summary>
    ///   Patch an absolute 64-bit pointer at the given byte offset.
    ///   Temporarily uses PAGE_READWRITE; restores PAGE_EXECUTE_READ after.
    /// </summary>
    procedure PatchQWord(Offset: Integer; Value: UInt64);

    /// <summary>
    ///   Patch an absolute 32-bit value at the given byte offset.
    ///   Useful for RVAs and relative displacements computed at load time.
    /// </summary>
    procedure PatchDWord(Offset: Integer; Value: Cardinal);

    // ── Properties ────────────────────────────────────────────────────────────
    property EntryPoint   : Pointer read FMemory;
    property Size         : Integer read FSize;
    property IsExecutable : Boolean read FIsExecutable;
  end;

// ---------------------------------------------------------------------------
// TSmartAsmBuilder
// ---------------------------------------------------------------------------

  /// <summary>
  ///   TAsmBuilder subclass with ergonomic helpers for common Win64 patterns.
  /// </summary>
  TSmartAsmBuilder = class(TAsmBuilder)
  public
    // ── Covariant overrides (return TSmartAsmBuilder statt TAsmBuilder) ──────
    function Prolog(ShadowAndLocalBytes: Integer = 32): TSmartAsmBuilder; reintroduce;
    function Add(Dest, Src: TOperand): TSmartAsmBuilder; reintroduce;

    // ── Register idioms ───────────────────────────────────────────────────────
    /// <summary>XOR Reg, Reg — fastest 64-bit zero; 3 bytes with REX.W.</summary>
    function Zero(Reg: TRegister): TSmartAsmBuilder;

    /// <summary>
    ///   Save a list of non-volatile registers to the stack.
    ///   Registers are pushed in the order given; pair with RestoreRegs in
    ///   reverse order when unwinding.
    /// </summary>
    function SaveRegs(const Regs: array of TRegister): TSmartAsmBuilder;

    /// <summary>Restore registers previously saved by SaveRegs (in reverse).</summary>
    function RestoreRegs(const Regs: array of TRegister): TSmartAsmBuilder;

    // ── Loop helpers ──────────────────────────────────────────────────────────
    /// <summary>
    ///   MOV CountReg, Count + Label_(LoopLabel).
    ///   Pair with LoopEnd(CountReg, LoopLabel) to close the counted loop.
    /// </summary>
    function LoopBegin(CountReg: TRegister; Count: Integer;
      const LoopLabel: string): TSmartAsmBuilder;

    /// <summary>
    ///   DEC CountReg + JNZ LoopLabel.
    ///   Closes a loop opened with LoopBegin.
    /// </summary>
    function LoopEnd(CountReg: TRegister;
      const LoopLabel: string): TSmartAsmBuilder;

    // ── Win64 ABI call helpers ─────────────────────────────────────────────────
    /// <summary>
    ///   Emit a fully ABI-correct Win64 call to Target with up to N arguments.
    ///   Handles:
    ///     • Dynamic RSP 16-byte alignment (AND RSP, -16 via R11)
    ///     • 32-byte shadow space above the return address
    ///     • Stack arguments for Args[4..N-1] at RSP+32, +40, …
    ///     • First 4 args loaded into RCX, RDX, R8, R9
    ///   Result in RAX on return.
    ///
    ///   This emits a self-contained mini frame:
    ///     PUSH RBP / MOV RBP, RSP / (AND RSP, -16) / SUB RSP, space
    ///     … load args …
    ///     MOV RAX, Target / CALL RAX
    ///     MOV RSP, RBP / POP RBP
    ///
    ///   NOTE: if you are already inside a Prolog frame, use the lower-level
    ///   Call(Pointer) after loading registers manually instead.
    /// </summary>
    function CallWin64(Target: Pointer;
      const Args: array of UInt64): TSmartAsmBuilder;

    // ── Compilation ───────────────────────────────────────────────────────────
    /// <summary>Build and wrap result in TExecutableCode.</summary>
    function CompileToExecutable(SMC: Boolean = False;
      Allocator: TJitAllocator = nil): TExecutableCode;
  end;

implementation

// ---------------------------------------------------------------------------
// TExecutableCode
// ---------------------------------------------------------------------------

constructor TExecutableCode.Create(const Code: TBytes; SMC: Boolean;
  Allocator: TJitAllocator);
var
  OldProtect  : Cardinal;
  ProtectFlag : Cardinal;
begin
  FIsExecutable := False;
  FSize         := Length(Code);
  if FSize = 0 then Exit;

  if Allocator <> nil then
  begin
    // ── Sub-allocate from pool ──────────────────────────────────────────────
    FOwnsMemory := False;
    FMemory     := Allocator.Alloc(FSize);
    Move(Code[0], FMemory^, FSize);

    if SMC then
    begin
      // Allocator.Commit always flips to PAGE_EXECUTE_READ, which would deny
      // writes needed for self-modifying code.  When SMC=True we must use
      // PAGE_EXECUTE_READWRITE; call VirtualProtect directly and bypass the
      // allocator's Commit so it does not mark the chunk as non-writable.
      if not VirtualProtect(FMemory, FSize, PAGE_EXECUTE_READWRITE, OldProtect) then
        RaiseLastOSError;
      FlushInstructionCache(GetCurrentProcess, FMemory, FSize);
    end
    else
      Allocator.Commit(FMemory, FSize);

    FIsExecutable := True;
  end
  else
  begin
    // ── Own VirtualAlloc ───────────────────────────────────────────────────
    FOwnsMemory := True;
    FMemory     := VirtualAlloc(nil, FSize, MEM_COMMIT or MEM_RESERVE, PAGE_READWRITE);
    if FMemory = nil then RaiseLastOSError;

    try
      Move(Code[0], FMemory^, FSize);

      if SMC then
        ProtectFlag := PAGE_EXECUTE_READWRITE
      else
        ProtectFlag := PAGE_EXECUTE_READ;

      if not VirtualProtect(FMemory, FSize, ProtectFlag, OldProtect) then
        RaiseLastOSError;

      FlushInstructionCache(GetCurrentProcess, FMemory, FSize);
      FIsExecutable := True;
    except
      VirtualFree(FMemory, 0, MEM_RELEASE);
      FMemory := nil;
      raise;
    end;
  end;
end;

class function TExecutableCode.FromBuilder(Builder: TAsmBuilder;
  SMC: Boolean; Allocator: TJitAllocator): TExecutableCode;
begin
  if Builder = nil then
    raise EAsmError.Create('TExecutableCode.FromBuilder: Builder is nil');
  Result := TExecutableCode.Create(Builder.Build, SMC, Allocator);
end;

destructor TExecutableCode.Destroy;
begin
  if FOwnsMemory and (FMemory <> nil) then
  begin
    VirtualFree(FMemory, 0, MEM_RELEASE);
    FMemory := nil;
  end;
  inherited;
end;

function TExecutableCode.CallInternal(const Args: array of UInt64): UInt64;
begin
  if not FIsExecutable then
    raise EAsmError.Create('TExecutableCode.Run: code is not executable');

  case Length(Args) of
    0: Result := TAsmFunc0(FMemory)();
    1: Result := TAsmFunc1(FMemory)(Args[0]);
    2: Result := TAsmFunc2(FMemory)(Args[0], Args[1]);
    3: Result := TAsmFunc3(FMemory)(Args[0], Args[1], Args[2]);
    4: Result := TAsmFunc4(FMemory)(Args[0], Args[1], Args[2], Args[3]);
  else
    raise EAsmError.Create('TExecutableCode.Run: max 4 arguments supported');
  end;
end;

function TExecutableCode.Run: UInt64;
begin
  Result := CallInternal([]);
end;

function TExecutableCode.Run(Arg1: UInt64): UInt64;
begin
  Result := CallInternal([Arg1]);
end;

function TExecutableCode.Run(Arg1, Arg2: UInt64): UInt64;
begin
  Result := CallInternal([Arg1, Arg2]);
end;

function TExecutableCode.Run(Arg1, Arg2, Arg3: UInt64): UInt64;
begin
  Result := CallInternal([Arg1, Arg2, Arg3]);
end;

function TExecutableCode.Run(Arg1, Arg2, Arg3, Arg4: UInt64): UInt64;
begin
  Result := CallInternal([Arg1, Arg2, Arg3, Arg4]);
end;

procedure TExecutableCode.PatchQWord(Offset: Integer; Value: UInt64);
var
  OldProtect: Cardinal;
  Dest      : PUInt64;
begin
  // Use (Offset > FSize - 8) instead of (Offset + 8 > FSize) to avoid integer
  // overflow when Offset is close to MaxInt.  If FSize < 8 the subtraction
  // produces a negative result, so any non-negative Offset correctly triggers
  // the guard.
  if (Offset < 0) or (Offset > FSize - 8) then
    raise EAsmError.CreateFmt(
      'PatchQWord: offset %d is out of range for code size %d', [Offset, FSize]);

  // Check VirtualProtect return values — a failed flip leaves memory still
  // executable-only; the subsequent write would AV on the next line.
  if not VirtualProtect(FMemory, FSize, PAGE_READWRITE, OldProtect) then
    RaiseLastOSError;
  try
    Dest  := Pointer(NativeUInt(FMemory) + NativeUInt(Offset));
    Dest^ := Value;
  finally
    if not VirtualProtect(FMemory, FSize, OldProtect, OldProtect) then
      RaiseLastOSError;
    FlushInstructionCache(GetCurrentProcess, FMemory, FSize);
  end;
end;

procedure TExecutableCode.PatchDWord(Offset: Integer; Value: Cardinal);
var
  OldProtect: Cardinal;
  Dest      : PCardinal;
begin
  // Same overflow-safe bounds check as PatchQWord.
  if (Offset < 0) or (Offset > FSize - 4) then
    raise EAsmError.CreateFmt(
      'PatchDWord: offset %d is out of range for code size %d', [Offset, FSize]);

  if not VirtualProtect(FMemory, FSize, PAGE_READWRITE, OldProtect) then
    RaiseLastOSError;
  try
    Dest  := Pointer(NativeUInt(FMemory) + NativeUInt(Offset));
    Dest^ := Value;
  finally
    if not VirtualProtect(FMemory, FSize, OldProtect, OldProtect) then
      RaiseLastOSError;
    FlushInstructionCache(GetCurrentProcess, FMemory, FSize);
  end;
end;

// ---------------------------------------------------------------------------
// TSmartAsmBuilder
// ---------------------------------------------------------------------------

function TSmartAsmBuilder.Prolog(ShadowAndLocalBytes: Integer): TSmartAsmBuilder;
begin
  inherited Prolog(ShadowAndLocalBytes);
  Result := Self;
end;

function TSmartAsmBuilder.Add(Dest, Src: TOperand): TSmartAsmBuilder;
begin
  inherited Add(Dest, Src);
  Result := Self;
end;

function TSmartAsmBuilder.Zero(Reg: TRegister): TSmartAsmBuilder;
begin
  Xor_(TOperand(Reg), TOperand(Reg));
  Result := Self;
end;

function TSmartAsmBuilder.SaveRegs(
  const Regs: array of TRegister): TSmartAsmBuilder;
var
  I: Integer;
begin
  for I := 0 to High(Regs) do
    Push(TOperand(Regs[I]));
  Result := Self;
end;

function TSmartAsmBuilder.RestoreRegs(
  const Regs: array of TRegister): TSmartAsmBuilder;
var
  I: Integer;
begin
  for I := High(Regs) downto 0 do
    Pop(TOperand(Regs[I]));
  Result := Self;
end;

function TSmartAsmBuilder.LoopBegin(CountReg: TRegister; Count: Integer;
  const LoopLabel: string): TSmartAsmBuilder;
begin
  // Guard against Count=0: MOV reg,0 → body runs once → DEC → $FFFFFFFFFFFFFFFF
  // → JNE loops ~2^64 times.  Negative counts are equally wrong.
  if Count <= 0 then
    raise EAsmError.CreateFmt(
      'LoopBegin: Count must be >= 1 (got %d). A zero count would produce an ' +
      'infinite loop because the first iteration runs before the DEC+JNE check.',
      [Count]);
  Mov(TOperand(CountReg), TOperand(Int64(Count)));
  Label_(LoopLabel);
  Result := Self;
end;

function TSmartAsmBuilder.LoopEnd(CountReg: TRegister;
  const LoopLabel: string): TSmartAsmBuilder;
begin
  Dec_(TOperand(CountReg));
  J(cond_JNE, LoopLabel);
  Result := Self;
end;

function TSmartAsmBuilder.CallWin64(Target: Pointer;
  const Args: array of UInt64): TSmartAsmBuilder;
var
  I             : Integer;
  StackArgsCount: Integer;
  TotalAlloc    : Integer;
begin
  // ── Frame setup ────────────────────────────────────────────────────────────
  Push(TOperand(RBP));
  Mov(TOperand(RBP), TOperand(RSP));

  // Align RSP to 16 bytes using R11 (volatile scratch)
  Mov(TOperand(R11), Int64(-16));
  And_(TOperand(RSP), TOperand(R11));

  // ── Stack space calculation ────────────────────────────────────────────────
  StackArgsCount := Length(Args) - 4;
  if StackArgsCount < 0 then StackArgsCount := 0;

  TotalAlloc := 32 + StackArgsCount * 8;
  // Maintain 16-byte alignment after SUB
  if (TotalAlloc mod 16) <> 0 then
    Inc(TotalAlloc, 8);

  Sub(TOperand(RSP), TotalAlloc);

  // ── Register arguments: RCX, RDX, R8, R9 ─────────────────────────────────
  if Length(Args) > 0 then
    Mov(TOperand(RCX), TOperand(Int64(Args[0])));
  if Length(Args) > 1 then
    Mov(TOperand(RDX), TOperand(Int64(Args[1])));
  if Length(Args) > 2 then
    Mov(TOperand(R8),  TOperand(Int64(Args[2])));
  if Length(Args) > 3 then
    Mov(TOperand(R9),  TOperand(Int64(Args[3])));

  // ── Stack arguments [4..N-1] at RSP+32, RSP+40, … ────────────────────────
  for I := 4 to High(Args) do
  begin
    Mov(TOperand(RAX), TOperand(Int64(Args[I])));
    Mov(TOperand(TMemory.Create(ridRSP, 32 + (I - 4) * 8)), TOperand(RAX));
  end;

  // ── Call ──────────────────────────────────────────────────────────────────
  Mov(TOperand(RAX), Int64(NativeUInt(Target)));
  Call(TOperand(RAX));

  // ── Frame teardown ────────────────────────────────────────────────────────
  Mov(TOperand(RSP), TOperand(RBP));
  Pop(TOperand(RBP));

  Result := Self;
end;

function TSmartAsmBuilder.CompileToExecutable(SMC: Boolean;
  Allocator: TJitAllocator): TExecutableCode;
begin
  Result := TExecutableCode.Create(Build, SMC, Allocator);
end;

end.
