{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }

unit NativeAsm.ConstPool;

{
  NativeAsm — Constant Pool
  =================================
  Author : NativeAsm Project
  Inspired by AsmJit's ConstPool design.

  Purpose
  -------
  Many x64 instructions cannot encode 64-bit or floating-point immediates
  directly.  Instead, the CPU uses a RIP-relative load to read the constant
  from a pool in the code section (MOVSD XMM0, [RIP+disp32]).

  This unit manages such a pool:
    1. Constants are deduplicated by value — identical data is stored once.
    2. Each entry is aligned to its natural size (4-byte for Single/Cardinal,
       8-byte for Double/UInt64, 16-byte for 128-bit, 4-byte otherwise).
    3. References are recorded as (disp32 offset, next-instruction offset, slot).
    4. Finalize() appends the pool after the code and back-patches every
       recorded RIP-relative displacement.

  Typical usage
  -------------
    var
      B    : TAsmBuilder;
      Pool : TConstPool;
      Slot : Integer;
    begin
      B    := TAsmBuilder.New;
      Pool := TConstPool.Create;
      try
        Slot := Pool.AddDouble(3.14159);

        B.Prolog;

        // Emit REX.W + MOVSDrm opcode + ModRM for [RIP+disp32]:
        //   F2 0F 10 05 00 00 00 00
        B.EmitByte($F2);   // SSE2 prefix
        B.EmitByte($0F);
        B.EmitByte($10);   // MOVSD xmm0, m64
        B.EmitByte($05);   // ModRM: Mod=00, Reg=0 (XMM0), R/M=101 (RIP-rel)
        Pool.EmitRef(B, Slot);   // emits disp32 placeholder + records fixup

        B.Epilog.Ret;

        var Code := Pool.Finalize(B.Build);
        // Code now contains the stub followed by the constant pool,
        // with the RIP-relative displacement correctly patched.
      finally
        Pool.Free;
        B.Free;
      end;
    end;

  Thread safety
  -------------
  TConstPool is NOT thread-safe.  Create one per builder / per thread.
}

{$ALIGN ON}
{$MINENUMSIZE 4}
{$RTTI EXPLICIT METHODS([]) PROPERTIES([]) FIELDS([])}
{$WEAKLINKRTTI ON}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  NativeAsm.Builder;

type
  EConstPoolError = class(Exception);

  /// <summary>
  ///   Deduplicated constant pool for RIP-relative data access.
  ///   See unit header for usage and design notes.
  /// </summary>
  TConstPool = class
  private
    type
      /// <summary>One deduplicated constant entry in the pool.</summary>
      TSlot = record
        Data     : TBytes;   // raw bytes of the constant
        Alignment: Integer;  // required alignment in the final pool layout
      end;

      /// <summary>One pending RIP-relative fixup to patch at Finalize time.</summary>
      TRef = record
        DispOffset : Integer;  // offset in emitted code where disp32 placeholder lives
        NextOffset : Integer;  // offset of the instruction following the disp32
        SlotIndex  : Integer;  // which TSlot this reference points to
      end;

  private
    FSlots: TList<TSlot>;
    FRefs : TList<TRef>;

    // Return the required alignment for a constant of DataSize bytes.
    class function NaturalAlignment(DataSize: Integer): Integer; static;

    // Search FSlots for an entry whose Data equals Data.  Returns -1 if absent.
    function FindSlot(const Data: TBytes): Integer;

    // Compute the starting offset of each slot within the pool (with padding).
    // Returns the total pool byte count.
    function BuildLayout(out Offsets: array of Integer): Integer; overload;

  public
    constructor Create;
    destructor  Destroy; override;

    // ── Adding constants ──────────────────────────────────────────────────────

    /// <summary>
    ///   Add an arbitrary byte blob as a pool constant.
    ///   If identical data is already in the pool, the existing slot index is
    ///   returned (deduplication).  The slot index is stable for the life of
    ///   this TConstPool instance.
    /// </summary>
    function AddConst(const Data: TBytes): Integer;

    /// <summary>Add a 64-bit IEEE 754 double-precision float (8 bytes, 8-byte aligned).</summary>
    function AddDouble(Value: Double): Integer;

    /// <summary>Add a 32-bit IEEE 754 single-precision float (4 bytes, 4-byte aligned).</summary>
    function AddSingle(Value: Single): Integer;

    /// <summary>Add a 64-bit unsigned integer (8 bytes, 8-byte aligned).</summary>
    function AddUInt64(Value: UInt64): Integer;

    /// <summary>Add a 32-bit unsigned integer (4 bytes, 4-byte aligned).</summary>
    function AddUInt32(Value: Cardinal): Integer;

    // ── Emitting references ───────────────────────────────────────────────────

    /// <summary>
    ///   Emit a 4-byte zero placeholder into Builder and record a fixup.
    ///   Call this immediately after emitting the last byte of the opcode +
    ///   ModRM sequence for a RIP-relative instruction, i.e. at the position
    ///   where the 32-bit displacement belongs.
    ///
    ///   At Finalize() time the placeholder is replaced with the correct
    ///   signed displacement = PoolSlotVA − (CodeBase + NextOffset).
    ///
    ///   SlotIdx must be a value previously returned by AddConst / AddDouble /
    ///   AddSingle / AddUInt64 / AddUInt32.
    /// </summary>
    procedure EmitRef(Builder: TAsmBuilder; SlotIdx: Integer);

    // ── Finalizing ────────────────────────────────────────────────────────────

    /// <summary>
    ///   Append the pool data after Code and patch every recorded RIP-relative
    ///   reference.  Returns a new TBytes that is Code || [padding] || Pool.
    ///
    ///   The pool is aligned to 16 bytes relative to the start of Code so
    ///   that the first entry (if 16-byte aligned) is placed correctly.
    ///
    ///   This method does not modify the internal state, allowing Finalize to
    ///   be called again on a rebuilt code buffer if needed (e.g. when using
    ///   the builder's Reset path).
    /// </summary>
    function Finalize(const Code: TBytes): TBytes;

    // ── Diagnostics ──────────────────────────────────────────────────────────

    /// <summary>
    ///   Predicted pool byte count (sum of slots + alignment padding between
    ///   them).  Useful for pre-allocating a buffer.
    /// </summary>
    function PoolSize: Integer;

    /// <summary>Number of unique constant entries (after deduplication).</summary>
    function EntryCount: Integer; inline;

    /// <summary>Number of pending fixups.</summary>
    function RefCount: Integer; inline;

    // ── Lifecycle ─────────────────────────────────────────────────────────────

    /// <summary>Remove all constants and references; resets to empty state.</summary>
    procedure Reset;
  end;

implementation

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function AlignUpI(V, Align: Integer): Integer; inline;
begin
  Result := (V + Align - 1) and (not (Align - 1));
end;

// ---------------------------------------------------------------------------
// TConstPool
// ---------------------------------------------------------------------------

class function TConstPool.NaturalAlignment(DataSize: Integer): Integer;
begin
  // Natural alignment by size; capped at 16 bytes
  case DataSize of
    1    : Result := 1;
    2    : Result := 2;
    3, 4 : Result := 4;
    5..8 : Result := 8;
  else
    Result := 16;
  end;
end;

constructor TConstPool.Create;
begin
  FSlots := TList<TSlot>.Create;
  FRefs  := TList<TRef>.Create;
end;

destructor TConstPool.Destroy;
begin
  FSlots.Free;
  FRefs.Free;
  inherited;
end;

function TConstPool.FindSlot(const Data: TBytes): Integer;
var
  I    : Integer;
  Slot : TSlot;
begin
  for I := 0 to FSlots.Count - 1 do
  begin
    Slot := FSlots[I];
    if Length(Slot.Data) = Length(Data) then
    begin
      if (Length(Data) = 0) or
         (CompareMem(Pointer(Slot.Data), Pointer(Data), Length(Data))) then
        Exit(I);
    end;
  end;
  Result := -1;
end;

function TConstPool.AddConst(const Data: TBytes): Integer;
var
  Slot: TSlot;
begin
  // Deduplicate
  Result := FindSlot(Data);
  if Result >= 0 then Exit;

  Slot.Data      := Copy(Data, 0, Length(Data));
  Slot.Alignment := NaturalAlignment(Length(Data));
  FSlots.Add(Slot);
  Result := FSlots.Count - 1;
end;

function TConstPool.AddDouble(Value: Double): Integer;
var
  B: TBytes;
begin
  SetLength(B, SizeOf(Double));
  Move(Value, B[0], SizeOf(Double));
  Result := AddConst(B);
end;

function TConstPool.AddSingle(Value: Single): Integer;
var
  B: TBytes;
begin
  SetLength(B, SizeOf(Single));
  Move(Value, B[0], SizeOf(Single));
  Result := AddConst(B);
end;

function TConstPool.AddUInt64(Value: UInt64): Integer;
var
  B: TBytes;
begin
  SetLength(B, SizeOf(UInt64));
  Move(Value, B[0], SizeOf(UInt64));
  Result := AddConst(B);
end;

function TConstPool.AddUInt32(Value: Cardinal): Integer;
var
  B: TBytes;
begin
  SetLength(B, SizeOf(Cardinal));
  Move(Value, B[0], SizeOf(Cardinal));
  Result := AddConst(B);
end;

procedure TConstPool.EmitRef(Builder: TAsmBuilder; SlotIdx: Integer);
var
  Ref: TRef;
begin
  if (SlotIdx < 0) or (SlotIdx >= FSlots.Count) then
    raise EConstPoolError.CreateFmt(
      'TConstPool.EmitRef: slot index %d out of range [0..%d)',
      [SlotIdx, FSlots.Count]);
  if Builder = nil then
    raise EConstPoolError.Create('TConstPool.EmitRef: Builder is nil');

  Ref.DispOffset := Builder.CodeSize;
  Ref.SlotIndex  := SlotIdx;

  // Emit 4 zero bytes as placeholder for the disp32
  Builder.EmitByte(0);
  Builder.EmitByte(0);
  Builder.EmitByte(0);
  Builder.EmitByte(0);

  Ref.NextOffset := Builder.CodeSize;
  FRefs.Add(Ref);
end;

function TConstPool.BuildLayout(out Offsets: array of Integer): Integer;
var
  I      : Integer;
  Cursor : Integer;
  Slot   : TSlot;
begin
  // Offsets must have Length = FSlots.Count
  Cursor := 0;
  for I := 0 to FSlots.Count - 1 do
  begin
    Slot       := FSlots[I];
    Cursor     := AlignUpI(Cursor, Slot.Alignment);
    Offsets[I] := Cursor;
    Inc(Cursor, Length(Slot.Data));
  end;
  Result := Cursor;  // total pool size (without tail padding)
end;

function TConstPool.Finalize(const Code: TBytes): TBytes;
var
  SlotOffsets   : array of Integer;
  TotalPool     : Integer;
  PoolStart     : Integer;  // byte offset where pool begins in Result
  ResultLen     : Integer;
  Ref           : TRef;
  I             : Integer;
  SlotVA        : Integer;  // offset of slot within Result
  Disp          : Integer;  // RIP-relative displacement
  PDisp         : PInteger;
  Slot          : TSlot;
  WritePos      : Integer;
begin
  if FSlots.Count = 0 then
  begin
    Result := Copy(Code, 0, Length(Code));
    Exit;
  end;

  // Compute per-slot offsets within the pool
  SetLength(SlotOffsets, FSlots.Count);
  TotalPool := BuildLayout(SlotOffsets);

  // Pool starts after code, aligned to 16 bytes
  PoolStart := AlignUpI(Length(Code), 16);
  ResultLen := PoolStart + TotalPool;

  SetLength(Result, ResultLen);

  // Copy code
  if Length(Code) > 0 then
    Move(Code[0], Result[0], Length(Code));

  // Zero the padding between code end and pool start
  if PoolStart > Length(Code) then
    FillChar(Result[Length(Code)], PoolStart - Length(Code), $90);  // NOP pad

  // Copy pool data
  WritePos := PoolStart;
  for I := 0 to FSlots.Count - 1 do
  begin
    Slot := FSlots[I];
    // Align cursor
    WritePos := PoolStart + SlotOffsets[I];
    if Length(Slot.Data) > 0 then
      Move(Slot.Data[0], Result[WritePos], Length(Slot.Data));
  end;

  // Patch each RIP-relative reference
  for I := 0 to FRefs.Count - 1 do
  begin
    Ref    := FRefs[I];
    SlotVA := PoolStart + SlotOffsets[Ref.SlotIndex];
    // disp32 = SlotVA - NextOffset
    // (because CPU adds disp32 to the address of the *next* instruction)
    Disp   := SlotVA - Ref.NextOffset;

    // AsmJit principle: DispOffset was recorded BEFORE Finalize appended
    // pool data, so it must lie within the original code region [0..Length(Code)).
    // Validating against ResultLen (which includes the pool) would silently
    // accept a corrupt offset pointing into the pool area itself.
    if (Ref.DispOffset < 0) or (Ref.DispOffset + 4 > Length(Code)) then
      raise EConstPoolError.CreateFmt(
        'TConstPool.Finalize: reference at +%d is outside the original code ' +
        'region [0..%d) — DispOffset must be within the code emitted before Finalize',
        [Ref.DispOffset, Length(Code)]);

    PDisp  := PInteger(@Result[Ref.DispOffset]);
    PDisp^ := Disp;
  end;
end;

function TConstPool.PoolSize: Integer;
var
  Offsets: array of Integer;
begin
  if FSlots.Count = 0 then
    Exit(0);
  SetLength(Offsets, FSlots.Count);
  Result := BuildLayout(Offsets);
end;

function TConstPool.EntryCount: Integer;
begin
  Result := FSlots.Count;
end;

function TConstPool.RefCount: Integer;
begin
  Result := FRefs.Count;
end;

procedure TConstPool.Reset;
begin
  FSlots.Clear;
  FRefs.Clear;
end;

end.
