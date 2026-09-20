{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
unit NativeAsm.Stubs;

{
  NativeAsm — PE Stub Factory
  ====================================
  Author : Selahattin Erkoc
  Purpose: Ready-made x64 code stub patterns for PE loading, import
           resolution, hooking, and calling-convention adaptation.

  All factory methods return TBytes or populate an existing TAsmBuilder.
  None of the stubs here are offensive — they model the same patterns
  used by the Windows loader, linker-generated thunks, and legitimate
  API hooking frameworks (Detours, EasyHook, …).

  Stub catalogue
  --------------
  Absolute JMP stubs (for thunk tables, trampolines)
  ┌─ TJmpStub.AbsoluteIndirect ─ FF 25 pattern (14 bytes, used in IAT)
  ├─ TJmpStub.AbsoluteDirect   ─ MOV RAX, addr + JMP RAX (12 bytes)
  ├─ TJmpStub.Relative         ─ E9 rel32 (5 bytes, ±2 GB range)
  └─ TJmpStub.PushRet          ─ PUSH lo32 + MOV [RSP+4], hi32 + RET (14 bytes)

  IAT thunk
  └─ TIatThunk.Build           ─ FF 25 stub + 8-byte address slot

  Function trampoline (for non-destructive hooking)
  └─ TTrampoline.Build         ─ saved N bytes + absolute JMP to original+N

  Win64 pass-through relay (alignment + shadow-space guarantee)
  └─ TWin64Relay.BuildPassThrough

  Direct syscall stub (SYSCALL instruction, not ntdll — for robust loaders)
  └─ TSyscallStub.Build

  Position-independent RIP capture
  └─ TPicHelper.EmitGetRip / VaToRva / Rel32
}

{$ALIGN ON}
{$MINENUMSIZE 4}
{$RTTI EXPLICIT METHODS([]) PROPERTIES([]) FIELDS([])}
{$WEAKLINKRTTI ON}

interface

uses
  System.SysUtils,
  NativeAsm.Types,
  NativeAsm.Builder;

// ---------------------------------------------------------------------------
// TJmpStub — raw JMP encodings
// ---------------------------------------------------------------------------

type
  /// <summary>
  ///   Raw JMP stubs as byte arrays.  These are the fundamental building
  ///   blocks for IAT patches, trampolines, and code-cave redirects.
  /// </summary>
  TJmpStub = record
  public
    /// <summary>
    ///   14-byte absolute-indirect JMP:
    ///     FF 25 00 00 00 00   ; JMP QWORD PTR [RIP+0]
    ///     XX XX XX XX XX XX XX XX  ; 64-bit target address (little-endian)
    ///
    ///   This is the exact encoding used by the Windows linker for IAT thunks
    ///   and by the loader when building import address table jump entries.
    ///   The CPU dereferences [RIP+0] = the 8 bytes immediately following
    ///   the instruction.
    ///
    ///   Use cases: IAT slot patching, code-cave redirects (14 free bytes),
    ///   delay-load resolution stubs.
    /// </summary>
    class function AbsoluteIndirect(Target: Pointer): TBytes; static;

    /// <summary>
    ///   12-byte absolute-direct JMP via scratch register:
    ///     48 B8 XX XX XX XX XX XX XX XX  ; MOV RAX, imm64
    ///     FF E0                           ; JMP RAX
    ///
    ///   Overwrites RAX (volatile scratch per Win64 ABI).
    ///   Use when only 12 bytes are available and RAX destruction is acceptable.
    /// </summary>
    class function AbsoluteDirect(Target: Pointer): TBytes; static;

    /// <summary>
    ///   5-byte relative JMP:
    ///     E9 XX XX XX XX  ; JMP rel32
    ///
    ///   Range: ±2 GB from the next instruction.  StubVA is the virtual
    ///   address where the stub will live (needed to compute the displacement).
    /// </summary>
    class function Relative(Target: Pointer; StubVA: Pointer): TBytes; static;

    /// <summary>
    ///   14-byte absolute JMP via PUSH+RET (no register clobber):
    ///     68 XX XX XX XX           ; PUSH imm32 (low 32 bits)     [5 bytes]
    ///     C7 44 24 04 XX XX XX XX  ; MOV DWORD [RSP+4], imm32 (high 32 bits) [8 bytes]
    ///     C3                       ; RET                           [1 byte]
    ///   Total: 5 + 8 + 1 = 14 bytes.
    ///
    ///   Transfers control without overwriting any general-purpose register.
    ///   Slightly slower than MOV+JMP but register-safe.
    /// </summary>
    class function PushRet(Target: Pointer): TBytes; static;
  end;

// ---------------------------------------------------------------------------
// TIatThunk
// ---------------------------------------------------------------------------

  /// <summary>
  ///   IAT thunk — an FF 25 stub whose 8-byte address slot is patchable
  ///   at load time, mirroring the Windows loader's import thunk layout.
  ///
  ///   Layout (14 bytes):
  ///     [+0]  FF 25 00 00 00 00  ; JMP [RIP+0]
  ///     [+6]  <8-byte address>   ; initially = InitialTarget (or 0)
  ///
  ///   To redirect the thunk at runtime:
  ///     PUInt64(Pointer(NativeUInt(Thunk.Stub)+6))^ := NewTarget;
  ///   (with VirtualProtect if the page is RX).
  /// </summary>
  TIatThunk = record
    Stub         : TBytes;   // 14-byte code
    AddressOffset: Integer;  // byte offset of the 8-byte address slot (always 6)

    /// <summary>
    ///   Build an IAT thunk pointing to InitialTarget.
    ///   If InitialTarget is nil, the slot is zero-initialized for lazy fill.
    /// </summary>
    class function Build(InitialTarget: Pointer = nil): TIatThunk; static;
  end;

// ---------------------------------------------------------------------------
// TTrampoline
// ---------------------------------------------------------------------------

  /// <summary>
  ///   Classic function trampoline for transparent, non-destructive hooking.
  ///
  ///   Pattern:
  ///     [Trampoline]                  [Hooked function prolog]
  ///     ┌──────────────────────┐      ┌───────────────────────┐
  ///     │ <SavedBytes> (N bytes│      │ JMP Hook              │ ← you write this
  ///     │  from original func) │      │  (overwrites N bytes)  │
  ///     │ JMP Original+N       │      └───────────────────────┘
  ///     └──────────────────────┘
  ///
  ///   The trampoline lets the hook call the original function by jumping
  ///   through here (which replays the overwritten bytes, then continues
  ///   at Original+N) rather than calling the hooked address directly.
  ///
  ///   IMPORTANT: SavedBytes must end on an instruction boundary.  Use a
  ///   length-disassembler (e.g. NativePe.Lde) to find the correct boundary.
  /// </summary>
  TTrampoline = record
    /// <summary>
    ///   Build a trampoline.
    ///   OriginalFn  – address of the function being hooked
    ///   SavedBytes  – exactly N bytes from the original function's prolog,
    ///                 ending on a complete instruction boundary
    ///   Returns a byte array ready to be placed in RX memory.
    /// </summary>
    class function Build(OriginalFn: Pointer;
      const SavedBytes: TBytes): TBytes; static;
  end;

// ---------------------------------------------------------------------------
// TWin64Relay
// ---------------------------------------------------------------------------

  /// <summary>
  ///   Win64-ABI relay stub: wraps a target function to guarantee 16-byte
  ///   RSP alignment and a correct 32-byte shadow space, forwarding all four
  ///   register arguments (RCX, RDX, R8, R9) unchanged.
  ///
  ///   Use this when calling code that assumes a correctly aligned stack from
  ///   a context where alignment cannot be guaranteed.
  /// </summary>
  TWin64Relay = record
    /// <summary>
    ///   Build a pass-through relay to Target.  Arguments and return value
    ///   pass through unchanged.
    /// </summary>
    class function BuildPassThrough(Target: Pointer): TBytes; static;
  end;

// ---------------------------------------------------------------------------
// TSyscallStub
// ---------------------------------------------------------------------------

  /// <summary>
  ///   Direct-syscall stub: calls the kernel via SYSCALL rather than through
  ///   ntdll.  Useful in robust PE loaders that must work even when ntdll
  ///   is patched (e.g. by an AV or DBI framework).
  ///
  ///   Layout (Win64 syscall convention, 11 bytes):
  ///     49 89 CA         ; MOV R10, RCX   (first arg → R10)
  ///     B8 xx xx xx xx  ; MOV EAX, Nr    (syscall number → EAX)
  ///     0F 05            ; SYSCALL
  ///     C3               ; RET
  ///
  ///   The stub is API-compatible with the ntdll stub it replaces.
  ///   SyscallNr values are OS-version specific; callers must look them up
  ///   at runtime or use a version-dispatch table (e.g. j00ru's table).
  /// </summary>
  TSyscallStub = record
    class function Build(SyscallNr: Cardinal): TBytes; static;
  end;

// ---------------------------------------------------------------------------
// TPicHelper
// ---------------------------------------------------------------------------

  /// <summary>
  ///   Position-independent code helpers.
  ///   EmitGetRip establishes a register holding the current RIP value,
  ///   enabling RIP-relative data access when you need an absolute base.
  /// </summary>
  TPicHelper = record
    /// <summary>
    ///   Emit a LEA that captures the address of the following instruction
    ///   into DestReg:
    ///     LEA DestReg, [RIP+0]   ; 7 bytes  (REX.W 8D /r disp32=0)
    ///
    ///   DestReg must be a 64-bit general-purpose register (rt64) and must
    ///   not be RSP.  Raises EArgumentException otherwise.
    ///
    ///   The LEA approach is preferred over the classic CALL/POP because:
    ///     • It does not use the RSP-relative stack (CALL/POP interacts badly
    ///       with CET Shadow Stack on modern Windows).
    ///     • It does not modify RSP or any other register except DestReg.
    ///     • It is a single, predictable instruction (no branch-predictor
    ///       side effects from a CALL that never returns).
    /// </summary>
    class procedure EmitGetRip(Builder: TAsmBuilder;
      DestReg: TRegister); static;

    /// <summary>
    ///   Compute an RVA (offset from module base) from an absolute VA.
    /// </summary>
    class function VaToRva(VA, ImageBase: Pointer): Cardinal; static; inline;

    /// <summary>
    ///   Compute a REL32 displacement between a source VA and a target VA.
    ///   Assumes a 5-byte instruction at Source; adjust NextInstr if needed.
    ///   Raises if the displacement falls outside the ±2 GB range.
    /// </summary>
    class function Rel32(Source, Target: Pointer): Integer; static; inline;

    /// <summary>
    ///   14-byte absolute JMP via PUSH+RET (no register clobber).
    ///   Delegates to TJmpStub.PushRet.
    ///   See TJmpStub.PushRet for encoding details.
    /// </summary>
    class function PushRet(Target: Pointer): TBytes; static;
  end;

implementation

// ---------------------------------------------------------------------------
// TJmpStub
// ---------------------------------------------------------------------------

class function TJmpStub.AbsoluteIndirect(Target: Pointer): TBytes;
var
  Addr: UInt64;
begin
  //  FF 25 00 00 00 00  ; JMP QWORD PTR [RIP+0]
  //  XX XX XX XX XX XX XX XX  ; 64-bit target (little-endian)
  SetLength(Result, 14);
  Result[0] := $FF;
  Result[1] := $25;
  Result[2] := $00;
  Result[3] := $00;
  Result[4] := $00;
  Result[5] := $00;
  Addr := UInt64(NativeUInt(Target));
  Move(Addr, Result[6], 8);
end;

class function TJmpStub.AbsoluteDirect(Target: Pointer): TBytes;
var
  Addr: UInt64;
begin
  //  48 B8 XX XX XX XX XX XX XX XX  ; MOV RAX, imm64
  //  FF E0                           ; JMP RAX
  SetLength(Result, 12);
  Result[0]  := $48;
  Result[1]  := $B8;
  Addr := UInt64(NativeUInt(Target));
  Move(Addr, Result[2], 8);
  Result[10] := $FF;
  Result[11] := $E0;
end;

class function TJmpStub.Relative(Target: Pointer; StubVA: Pointer): TBytes;
var
  Rel  : Int64;
  Disp : Integer;
begin
  //  E9 XX XX XX XX  ; JMP rel32
  // rel32 = Target - (StubVA + 5)
  Rel := Int64(NativeUInt(Target)) - (Int64(NativeUInt(StubVA)) + 5);
  if (Rel < Low(Integer)) or (Rel > High(Integer)) then
    raise Exception.CreateFmt(
      'TJmpStub.Relative: displacement $%x exceeds ±2 GB range', [Rel]);

  Disp := Integer(Rel);
  SetLength(Result, 5);
  Result[0] := $E9;
  Move(Disp, Result[1], 4);
end;

class function TJmpStub.PushRet(Target: Pointer): TBytes;
var
  Addr : UInt64;
  Lo32 : Cardinal;
  Hi32 : Cardinal;
begin
  // 14 bytes  (5 + 8 + 1):
  //  68 XX XX XX XX           ; PUSH imm32 (low 32)           bytes 0..4
  //  C7 44 24 04 XX XX XX XX  ; MOV DWORD PTR [RSP+4], imm32  bytes 5..12
  //  C3                       ; RET                            byte  13
  SetLength(Result, 14);
  Addr := UInt64(NativeUInt(Target));
  Lo32 := Cardinal(Addr and $FFFFFFFF);
  Hi32 := Cardinal(Addr shr 32);

  Result[0] := $68;
  Move(Lo32, Result[1], 4);   // bytes 1..4

  Result[5] := $C7;
  Result[6] := $44;
  Result[7] := $24;
  Result[8] := $04;
  Move(Hi32, Result[9], 4);   // bytes 9..12

  Result[13] := $C3;          // RET at correct offset 13
end;

// ---------------------------------------------------------------------------
// TIatThunk
// ---------------------------------------------------------------------------

class function TIatThunk.Build(InitialTarget: Pointer): TIatThunk;
begin
  Result.Stub          := TJmpStub.AbsoluteIndirect(InitialTarget);
  Result.AddressOffset := 6;
end;

// ---------------------------------------------------------------------------
// TTrampoline
// ---------------------------------------------------------------------------

class function TTrampoline.Build(OriginalFn: Pointer;
  const SavedBytes: TBytes): TBytes;
var
  B           : TAsmBuilder;
  Continuation: Pointer;
  JmpBytes    : TBytes;
begin
  if OriginalFn = nil then
    raise Exception.Create('TTrampoline.Build: OriginalFn must not be nil');
  if Length(SavedBytes) = 0 then
    raise Exception.Create('TTrampoline.Build: SavedBytes must not be empty');

  // Continuation = address of the first intact instruction in OriginalFn
  Continuation := Pointer(NativeUInt(OriginalFn) + NativeUInt(Length(SavedBytes)));

  B := TAsmBuilder.Create;
  try
    // 1. Replay the bytes that were overwritten by the hook
    B.EmitBytes(SavedBytes);

    // 2. Absolute JMP to the continuation point.
    //    Use AbsoluteIndirect (FF 25 + 8-byte slot, 14 bytes) rather than
    //    AbsoluteDirect (MOV RAX + JMP RAX, 12 bytes) so that RAX — which
    //    carries the return value of the original function — is not clobbered
    //    when the hook's call-through path uses the trampoline.
    JmpBytes := TJmpStub.AbsoluteIndirect(Continuation);
    B.EmitBytes(JmpBytes);

    Result := B.Build;
  finally
    B.Free;
  end;
end;

// ---------------------------------------------------------------------------
// TWin64Relay
// ---------------------------------------------------------------------------

class function TWin64Relay.BuildPassThrough(Target: Pointer): TBytes;
var
  B: TAsmBuilder;
begin
  // A pass-through relay that:
  //   1. Guarantees 16-byte alignment (AND RSP, -16)
  //   2. Provides the mandatory 32-byte shadow space
  //   3. Forwards RCX, RDX, R8, R9 unchanged
  //   4. Calls Target via RAX
  //   5. Returns with RAX unchanged (already the return value)

  B := TAsmBuilder.Create;
  try
    // --- Frame setup ---
    B.Push(TOperand(RBP));
    B.Mov(TOperand(RBP), TOperand(RSP));

    // AND RSP, -16  (align via R11 to avoid sign-extension issues with imm)
    B.Mov(TOperand(R11), Int64(-16));
    B.And_(TOperand(RSP), TOperand(R11));

    // Shadow space (32 bytes)
    B.Sub(TOperand(RSP), 32);

    // --- Arguments pass through in RCX, RDX, R8, R9 — nothing to do ---

    // --- Call Target ---
    B.Mov(TOperand(RAX), Int64(NativeUInt(Target)));
    B.Call(TOperand(RAX));

    // --- Frame teardown ---
    B.Mov(TOperand(RSP), TOperand(RBP));
    B.Pop(TOperand(RBP));
    B.Ret;

    Result := B.Build;
  finally
    B.Free;
  end;
end;

// ---------------------------------------------------------------------------
// TSyscallStub
// ---------------------------------------------------------------------------

class function TSyscallStub.Build(SyscallNr: Cardinal): TBytes;
var
  B: TAsmBuilder;
begin
  // Win64 direct-syscall stub (matches ntdll stub layout on Win10):
  //   49 89 CA        ; MOV R10, RCX     (first arg in R10 for kernel)
  //   B8 xx xx xx xx ; MOV EAX, Nr      (32-bit; zero-extends EAX→RAX)
  //   0F 05           ; SYSCALL
  //   C3              ; RET

  B := TAsmBuilder.Create;
  try
    B.EmitByte($49);  // REX.WB
    B.EmitByte($89);
    B.EmitByte($CA);  // ModRM: 11 001 010  → MOV r/m(R10), RCX

    B.EmitByte($B8);
    B.EmitByte(Byte(SyscallNr));
    B.EmitByte(Byte(SyscallNr shr 8));
    B.EmitByte(Byte(SyscallNr shr 16));
    B.EmitByte(Byte(SyscallNr shr 24));

    B.EmitByte($0F);
    B.EmitByte($05);  // SYSCALL

    B.Ret;

    Result := B.Build;
  finally
    B.Free;
  end;
end;

// ---------------------------------------------------------------------------
// TPicHelper
// ---------------------------------------------------------------------------

class procedure TPicHelper.EmitGetRip(Builder: TAsmBuilder;
  DestReg: TRegister);
var
  Rex    : Byte;
  ModRM  : Byte;
begin
  // Validate: must be a 64-bit GPR, must not be RSP
  if DestReg.RegType <> rt64 then
    raise EArgumentException.CreateFmt(
      'TPicHelper.EmitGetRip: DestReg must be a 64-bit register (got kind %d)',
      [Ord(DestReg.RegType)]);
  if DestReg.ID = ridRSP then
    raise EArgumentException.Create(
      'TPicHelper.EmitGetRip: RSP cannot be used as destination');
  if Builder = nil then
    raise EArgumentException.Create(
      'TPicHelper.EmitGetRip: Builder must not be nil');

  // Encode  LEA DestReg, [RIP+0]
  //   Opcode : 8D /r  with ModRM Mod=00 Reg=DestReg R/M=101 (RIP-relative)
  //   REX    : 48 (REX.W) or 4C (REX.W + REX.R for R8..R15)
  //   disp32 : 00 00 00 00  (offset 0 from RIP = address of the next insn)
  //
  // 7 bytes total:  REX  8D  ModRM  00 00 00 00
  if DestReg.ID >= ridR8 then
    Rex := $4C   // REX.W + REX.R
  else
    Rex := $48;  // REX.W only

  // ModRM: Mod=00 (11=reg-direct, 00=mem), Reg=DestReg (bits 5..3), R/M=101
  // Mod=00, R/M=101 → RIP-relative disp32
  ModRM := $05 or (Byte(Ord(DestReg.ID) and 7) shl 3);

  Builder.EmitByte(Rex);
  Builder.EmitByte($8D);   // LEA opcode
  Builder.EmitByte(ModRM);
  Builder.EmitByte($00);   // disp32 = 0
  Builder.EmitByte($00);
  Builder.EmitByte($00);
  Builder.EmitByte($00);
end;

class function TPicHelper.PushRet(Target: Pointer): TBytes;
begin
  Result := TJmpStub.PushRet(Target);
end;

class function TPicHelper.VaToRva(VA, ImageBase: Pointer): Cardinal;
var
  VAAddr  : NativeUInt;
  BaseAddr: NativeUInt;
  Delta   : UInt64;
begin
  VAAddr   := NativeUInt(VA);
  BaseAddr := NativeUInt(ImageBase);

  // Guard against underflow: VA must be >= ImageBase
  if VAAddr < BaseAddr then
    raise EArgumentException.CreateFmt(
      'TPicHelper.VaToRva: VA ($%p) is below ImageBase ($%p) — negative RVA',
      [VA, ImageBase]);

  // Guard against truncation: delta must fit in 32 bits
  Delta := UInt64(VAAddr) - UInt64(BaseAddr);
  if Delta > High(Cardinal) then
    raise EArgumentException.CreateFmt(
      'TPicHelper.VaToRva: offset $%x exceeds 4 GB — cannot fit in a 32-bit RVA',
      [Delta]);

  Result := Cardinal(Delta);
end;

class function TPicHelper.Rel32(Source, Target: Pointer): Integer;
var
  Displacement: Int64;
begin
  // Standard: displacement = Target - (Source + 5)  (for a 5-byte instruction)
  Displacement := Int64(NativeUInt(Target)) - (Int64(NativeUInt(Source)) + 5);
  if (Displacement < Low(Integer)) or (Displacement > High(Integer)) then
    raise Exception.CreateFmt(
      'TPicHelper.Rel32: displacement 0x%x exceeds ±2 GB', [Displacement]);
  Result := Integer(Displacement);
end;

end.
