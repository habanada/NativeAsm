{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
unit NativeAsm.Encoder;

{
  NativeAsm x64 JIT Builder — Low-Level Encoder
  =================================================
  Author : Selahattin Erkoc
  Purpose: Builds the raw byte stream for x64 machine code.
           Handles REX prefix, ModRM byte, SIB byte, and immediates
           according to the Intel/AMD x86-64 specification.

  Buffer strategy
  ---------------
  Uses a capacity-doubling strategy to avoid the O(n²) cost of
  growing by one byte at a time.  Default initial capacity is 256 bytes;
  realistic stubs rarely exceed a few hundred bytes.

  Public surface (used only by TAsmBuilder)
  -----------------------------------------
    EmitRaw(B)            – append one byte
    EmitInt32Raw(V)       – append LE int32
    EmitInt64Raw(V)       – append LE int64
    EmitRexW(RegOp, RM)  – emit REX.W prefix (W=1)
    EmitRexNoW(RegOp, RM)– emit REX without W (extended-reg only)
    EmitModRM(RegOp, RM) – emit ModRM [+SIB] [+Disp]
    EncodeInstr(...)      – full instruction: REX + opcode + ModRM
    EncodeInstrImm(...)   – full instruction with immediate
    EncodeUnary(...)      – single-operand instruction
    GetCode               – snapshot of current buffer as TBytes
    CurrentOffset         – current byte position
    Reset                 – clear buffer, keep capacity
}

{$ALIGN ON}
{$MINENUMSIZE 4}

interface

uses
  System.SysUtils,
  NativeAsm.Types;

type
  /// <summary>
  ///   Low-level x64 instruction encoder.
  ///   Consumed exclusively by TAsmBuilder — do not use directly.
  /// </summary>
  TEncoderX64 = class
  private
    FBuffer   : TBytes;
    FSize     : Integer;   // logical size (bytes written)
    FCapacity : Integer;   // allocated length of FBuffer

    procedure Grow(Required: Integer);
    procedure WriteByte(B: Byte); inline;
    procedure WriteInt32(V: Integer);
    procedure WriteInt64(V: Int64);

    // Internal REX / ModRM helpers
    // RegReg is the /reg field register; its RegType determines NeedsRex
    // for SPL/BPL/SIL/DIL (bare REX) vs AH/CH/DH/BH (no REX allowed).
    procedure EmitRex(W: Boolean; const RegReg: TRegister; const RM: TOperand);
    procedure EmitModRMImpl(RegVal: Byte; const RM: TOperand);

  public
    constructor Create(InitialCapacity: Integer = 256);

    /// <summary>Snapshot of the bytes emitted so far.</summary>
    function GetCode: TBytes;

    /// <summary>Current write position (== number of bytes emitted).</summary>
    function CurrentOffset: Integer; inline;

    /// <summary>Discard all emitted bytes; keep the allocated buffer.</summary>
    procedure Reset;

    // -----------------------------------------------------------------------
    // Raw emission
    // -----------------------------------------------------------------------
    procedure EmitRaw(B: Byte); inline;
    procedure WriteInt16(V: Word);   // exposed for Builder 16-bit immediate writes
    procedure EmitInt32Raw(V: Integer);
    procedure EmitInt64Raw(V: Int64);

    // -----------------------------------------------------------------------
    // REX prefix helpers (public so TAsmBuilder can call for special encodings)
    // -----------------------------------------------------------------------

    /// <summary>
    ///   Emit REX prefix.  W = True sets REX.W (64-bit operand size).
    ///   RegReg is the /reg field register (TRegister, so NeedsRex handles
    ///   SPL/BPL/SIL/DIL correctly); RM is the r/m operand.
    ///   Nothing is emitted if no REX bits are needed.
    /// </summary>
    procedure EmitRexW(const RegReg: TRegister; const RM: TOperand);

    /// <summary>
    ///   Emit REX without forcing REX.W — used for 32/8-bit extended regs.
    ///   A bare REX byte ($40) is still emitted when RegReg.NeedsRex is True
    ///   (SPL/BPL/SIL/DIL in rt8 mode) or when RM requires extension bits.
    /// </summary>
    procedure EmitRexNoW(const RegReg: TRegister; const RM: TOperand);

    // -----------------------------------------------------------------------
    // ModRM / SIB emission (public for special multi-byte-opcode sequences)
    // -----------------------------------------------------------------------

    /// <summary>
    ///   Emit ModRM byte + optional SIB + optional displacement.
    ///   RegReg is the /reg field register; its ModRMField gives the 3-bit value
    ///   (handles AH/CH/DH/BH field 4–7 correctly).
    /// </summary>
    procedure EmitModRM(const RegReg: TRegister; const RM: TOperand);

    /// <summary>
    ///   Emit ModRM/SIB/Disp using a literal /reg field value (0..7).
    ///   Used by generated static descriptors for /0../7 and canonical SETcc.
    /// </summary>
    procedure EmitModRMValue(RegValue: Byte; const RM: TOperand);

    // -----------------------------------------------------------------------
    // High-level instruction encoders
    // -----------------------------------------------------------------------

    /// <summary>
    ///   Encode a two-operand instruction.
    ///
    ///   force64: when True, REX.W is emitted (64-bit operand size).
    ///   Opcode conventions:
    ///     Dest = Reg → encode as   opcode + ModRM(Dest.Reg, Src)
    ///     Dest = Mem → encode as   opcode + ModRM(Src.Reg, Dest)  (reversed /reg field)
    /// </summary>
    procedure EncodeInstr(Opcode: Byte; Dest, Src: TOperand;
      Force64Bit: Boolean = True); overload;

    /// <summary>
    ///   Encode an instruction whose source is an immediate value.
    ///   OpExtension fills the /reg field in ModRM (e.g. 0 for ADD, 5 for SUB).
    ///   ImmBytes controls how many immediate bytes are written:
    ///     0 = auto-detect from opcode ($80/$83/$C0/$C6/$F6 → 1, else 4)
    ///     1 = imm8   (sign-extended by CPU where applicable)
    ///     2 = imm16  (required when destination is 16-bit, i.e. $66 prefix used)
    ///     4 = imm32
    ///   Pass ImmBytes=2 when the caller emits the $66 prefix before this call.
    /// </summary>
    procedure EncodeInstrImm(Opcode: Byte; OpExtension: Byte;
      Dest: TOperand; Imm: Integer; Force64Bit: Boolean = True;
      ImmBytes: Integer = 0);

    /// <summary>
    ///   Encode a single-operand instruction (INC, DEC, NOT, NEG, PUSH/POP …).
    ///   OpExtension is the /reg field (0–7).
    /// </summary>
    procedure EncodeUnary(Opcode: Byte; OpExtension: Byte;
      Operand: TOperand; Force64Bit: Boolean = True);
  end;

implementation

// ---------------------------------------------------------------------------
// Buffer management
// ---------------------------------------------------------------------------

constructor TEncoderX64.Create(InitialCapacity: Integer);
begin
  if InitialCapacity < 16 then InitialCapacity := 16;
  FCapacity := InitialCapacity;
  FSize     := 0;
  SetLength(FBuffer, FCapacity);
end;

procedure TEncoderX64.Grow(Required: Integer);
var
  NewCap: Integer;
begin
  NewCap := FCapacity;
  while NewCap < Required do
    NewCap := NewCap * 2;
  // Assign before SetLength so a failed SetLength does not corrupt FCapacity.
  SetLength(FBuffer, NewCap);
  FCapacity := NewCap;
end;

procedure TEncoderX64.WriteByte(B: Byte);
begin
  if FSize = FCapacity then Grow(FSize + 1);
  FBuffer[FSize] := B;
  Inc(FSize);
end;

procedure TEncoderX64.WriteInt16(V: Word);
begin
  WriteByte(Byte(V));
  WriteByte(Byte(V shr 8));
end;

procedure TEncoderX64.WriteInt32(V: Integer);
var
  U: Cardinal absolute V;
begin
  WriteByte(Byte(U));
  WriteByte(Byte(U shr 8));
  WriteByte(Byte(U shr 16));
  WriteByte(Byte(U shr 24));
end;

procedure TEncoderX64.WriteInt64(V: Int64);
var
  U: UInt64 absolute V;
begin
  WriteInt32(Integer(U and $FFFFFFFF));
  WriteInt32(Integer(U shr 32));
end;

// ---------------------------------------------------------------------------
// Public API — raw emission
// ---------------------------------------------------------------------------

procedure TEncoderX64.EmitRaw(B: Byte);
begin
  WriteByte(B);
end;

procedure TEncoderX64.EmitInt32Raw(V: Integer);
begin
  WriteInt32(V);
end;

procedure TEncoderX64.EmitInt64Raw(V: Int64);
begin
  WriteInt64(V);
end;

function TEncoderX64.GetCode: TBytes;
begin
  SetLength(Result, FSize);
  if FSize > 0 then
    Move(FBuffer[0], Result[0], FSize);
end;

function TEncoderX64.CurrentOffset: Integer;
begin
  Result := FSize;
end;

procedure TEncoderX64.Reset;
begin
  FSize := 0;
end;

// ---------------------------------------------------------------------------
// REX prefix
// ---------------------------------------------------------------------------
//
// REX layout:  0100 W R X B
//   W = 1  → 64-bit operand size
//   R = 1  → /reg field refers to R8–R15
//   X = 1  → SIB Index refers to R8–R15
//   B = 1  → r/m (ModRM) or SIB Base refers to R8–R15
//
// AsmJit's FIXUP_GPB logic: after all REX bits are collected, if ANY bit
// is set and a High8 register (AH/CH/DH/BH) is involved → encoding is
// invalid.  This matches x86_instapi.cpp kInvalidUseOfGpbHi.
//
procedure TEncoderX64.EmitRex(W: Boolean; const RegReg: TRegister;
  const RM: TOperand);
var
  Rex     : Byte;
  NeedRex : Boolean;
  HasHigh8: Boolean;
begin
  Rex      := $40;
  NeedRex  := False;
  HasHigh8 := (RegReg.RegType = rt8High);

  if W then
  begin
    Rex     := Rex or $08;  // REX.W
    NeedRex := True;
  end;

  // REX.R — /reg field is R8–R15
  if RegReg.IsExtended then
  begin
    Rex     := Rex or $04;  // REX.R
    NeedRex := True;
  end;
  // Bare REX — SPL/BPL/SIL/DIL in rt8 mode need a REX prefix to select the
  // new-byte encoding (field values 4-7 without REX = AH/CH/DH/BH).
  if RegReg.NeedsRex then NeedRex := True;

  case RM.Kind of
    otReg:
    begin
      if RM.Reg.RegType = rt8High then HasHigh8 := True;
      if RM.Reg.ID >= ridR8 then
      begin
        Rex     := Rex or $01;  // REX.B
        NeedRex := True;
      end;
      // r/m side also needs bare REX for SPL/BPL/SIL/DIL
      if RM.Reg.NeedsRex then NeedRex := True;
    end;
    otMem:
    begin
      if not RM.Mem.IsRipRelative then
      begin
        if RM.Mem.Base >= ridR8 then
        begin
          Rex     := Rex or $01;  // REX.B (base)
          NeedRex := True;
        end;
        if RM.Mem.HasIndex and (RM.Mem.Index >= ridR8) then
        begin
          Rex     := Rex or $02;  // REX.X (index)
          NeedRex := True;
        end;
      end;
    end;
    otNone, otImm:
    begin
      // No r/m contribution.
    end;
  end;

  // AsmJit kInvalidUseOfGpbHi: any REX byte + a High8 register = illegal.
  // Without REX, field 4–7 = AH/CH/DH/BH.
  // With any REX byte, field 4–7 = SPL/BPL/SIL/DIL instead → wrong register.
  if NeedRex and HasHigh8 then
    raise Exception.Create(
      'Encoder: AH/CH/DH/BH (rt8High) cannot be combined with any REX prefix. ' +
      'A REX byte is required by R8–R15 or SPL/BPL/SIL/DIL operands, ' +
      'making the encoding of the High8 register impossible.');

  if NeedRex then WriteByte(Rex);
end;

procedure TEncoderX64.EmitRexW(const RegReg: TRegister; const RM: TOperand);
begin
  EmitRex(True, RegReg, RM);
end;

procedure TEncoderX64.EmitRexNoW(const RegReg: TRegister; const RM: TOperand);
begin
  EmitRex(False, RegReg, RM);
end;

// ---------------------------------------------------------------------------
// ModRM + SIB + displacement
// ---------------------------------------------------------------------------
//
// ModRM: [Mod:2][Reg:3][R/M:3]
//
//   Mod = 11 → register
//   Mod = 00 → [reg]              (or [RIP+Disp32] when R/M=101)
//   Mod = 01 → [reg + Disp8]
//   Mod = 10 → [reg + Disp32]
//
// When R/M = 100 (ESP/R12), a SIB byte follows.
//
procedure TEncoderX64.EmitModRMImpl(RegVal: Byte; const RM: TOperand);
var
  Mod_    : Byte;
  RmVal   : Byte;
  HasSib  : Boolean;
  ScaleBits, IndexBits, BaseBits: Byte;
begin
  RegVal := RegVal and 7;

  // ── Register operand ────────────────────────────────────────────────────────
  if RM.Kind = otReg then
  begin
    // Use ModRMField so that AH/CH/DH/BH (rt8High) resolve to field 4–7
    // instead of 0–3 (which would encode AL/CL/DL/BL instead).
    WriteByte(($03 shl 6) or (RegVal shl 3) or RM.Reg.ModRMField);
    Exit;
  end;

  if RM.Kind in [otImm, otNone] then
    raise Exception.CreateFmt(
      'EmitModRMImpl: illegal r/m operand kind %d (expected otReg or otMem). ' +
      'This indicates a missing code path in the encoder (e.g. TEST with imm).',
      [Ord(RM.Kind)]);

  // ── Memory operand ──────────────────────────────────────────────────────────
  if RM.Kind = otMem then
  begin
    // RIP-relative: Mod=00, R/M=101, followed by Disp32
    if RM.Mem.IsRipRelative then
    begin
      WriteByte((RegVal shl 3) or 5);  // Mod=00, R/M=101
      WriteInt32(RM.Mem.Disp);
      Exit;
    end;

    RmVal  := Byte(RM.Mem.Base) and 7;
    HasSib := False;

    // RSP (4) and R12 (4 in low 3 bits) require a SIB byte
    if RM.Mem.HasIndex or (RM.Mem.Base = ridRSP) or (RM.Mem.Base = ridR12) then
    begin
      HasSib := True;
      RmVal  := 4;  // signal SIB
    end;

    // Determine Mod field
    if RM.Mem.Disp = 0 then
    begin
      Mod_ := 0;
      // RBP (5) and R13 (5 in low 3 bits) can't use Mod=00, use Mod=01+Disp8=0
      if (RM.Mem.Base = ridRBP) or (RM.Mem.Base = ridR13) then Mod_ := 1;
    end
    else if (RM.Mem.Disp >= -128) and (RM.Mem.Disp <= 127) then
      Mod_ := 1
    else
      Mod_ := 2;

    WriteByte((Mod_ shl 6) or (RegVal shl 3) or RmVal);

    // SIB byte
    if HasSib then
    begin
      ScaleBits := Byte(RM.Mem.Scale);
      BaseBits  := Byte(RM.Mem.Base) and 7;
      if RM.Mem.HasIndex then
        IndexBits := Byte(RM.Mem.Index) and 7
      else
        IndexBits := 4;  // no-index sentinel
      WriteByte((ScaleBits shl 6) or (IndexBits shl 3) or BaseBits);
    end;

    // Displacement
    case Mod_ of
      1: WriteByte(Byte(RM.Mem.Disp));
      2: WriteInt32(RM.Mem.Disp);
      0:
        // RBP/R13 with Disp=0 still needs a forced Disp8=0
        if (RM.Mem.Base = ridRBP) or (RM.Mem.Base = ridR13) then
          WriteByte(0);
    end;
  end;
end;

procedure TEncoderX64.EmitModRM(const RegReg: TRegister; const RM: TOperand);
begin
  EmitModRMImpl(RegReg.ModRMField, RM);
end;

procedure TEncoderX64.EmitModRMValue(RegValue: Byte; const RM: TOperand);
begin
  if RegValue > 7 then
    raise EArgumentOutOfRangeException.CreateFmt(
      'EmitModRMValue: RegValue %d is out of range [0..7]', [RegValue]);
  EmitModRMImpl(RegValue, RM);
end;

// ---------------------------------------------------------------------------
// High-level encoders
// ---------------------------------------------------------------------------

procedure TEncoderX64.EncodeInstr(Opcode: Byte; Dest, Src: TOperand;
  Force64Bit: Boolean);
begin
  // All High8+REX conflict detection is centralised in EmitRex, which
  // mirrors AsmJit's FIXUP_GPB / kInvalidUseOfGpbHi approach: it collects
  // ALL REX bits from both operands before deciding whether to emit, and
  // raises if any REX bit is set while a High8 register is involved.
  if Dest.Kind = otReg then
  begin
    // Dest is the /reg field; Src is the r/m field.
    EmitRex(Force64Bit, Dest.Reg, Src);
    WriteByte(Opcode);
    EmitModRMImpl(Dest.Reg.ModRMField, Src);
  end
  else
  begin
    // Dest is the r/m field; Src must be a register (/reg field).
    if Src.Kind <> otReg then
      raise Exception.Create('EncodeInstr: cannot encode Mem←Mem or Mem←Imm this way');
    EmitRex(Force64Bit, Src.Reg, Dest);
    WriteByte(Opcode);
    EmitModRMImpl(Src.Reg.ModRMField, Dest);
  end;
end;

procedure TEncoderX64.EncodeInstrImm(Opcode: Byte; OpExtension: Byte;
  Dest: TOperand; Imm: Integer; Force64Bit: Boolean; ImmBytes: Integer);
var
  // Sentinel register: no extension bit, no NeedsRex → pure otNone /reg
  NullReg: TRegister;
  AutoImm: Integer;
begin
  if OpExtension > 7 then
    raise Exception.CreateFmt(
      'EncodeInstrImm: OpExtension %d is out of range [0..7]', [OpExtension]);
  if not (ImmBytes in [0, 1, 2, 4]) then
    raise Exception.CreateFmt(
      'EncodeInstrImm: ImmBytes %d is invalid (must be 0, 1, 2, or 4)', [ImmBytes]);

  // /reg side is the OpExtension field (no register); use a neutral rt32 reg
  // that never sets REX.R, so only the r/m side (Dest) drives extension bits.
  // High8 check in EmitRex: if Dest is rt8High and Force64Bit or Dest requires
  // REX extension the call will raise automatically.
  NullReg.ID      := ridRAX;
  NullReg.RegType := rt32;   // rt32: IsExtended=False, NeedsRex=False

  EmitRex(Force64Bit, NullReg, Dest);
  WriteByte(Opcode);
  EmitModRMImpl(OpExtension, Dest);

  // Determine immediate width.
  // $80  = r/m8,  imm8           $83 = r/m16/32/64, imm8 (sign-extended)
  // $C0  = shift r/m8, imm8      $C6 = MOV r/m8, imm8
  // $F6  = TEST/NOT/NEG r/m8, imm8 (TEST /0)
  // $81  = r/m16/32/64, imm16/32 — width depends on operand size (ImmBytes param)
  // $F7  = TEST/NOT/NEG r/m16/32/64, imm16/32 — same
  // Everything else defaults to imm32.
  if ImmBytes = 0 then
  begin
    if (Opcode = $80) or (Opcode = $83) or
       (Opcode = $C0) or (Opcode = $C6) or (Opcode = $F6) then
      AutoImm := 1
    else
      AutoImm := 4;
  end
  else
    AutoImm := ImmBytes;

  case AutoImm of
    1: WriteByte(Byte(Imm));
    2: WriteInt16(Word(Imm));
    4: WriteInt32(Imm);
  end;
end;

procedure TEncoderX64.EncodeUnary(Opcode: Byte; OpExtension: Byte;
  Operand: TOperand; Force64Bit: Boolean);
var
  NullReg: TRegister;
begin
  if OpExtension > 7 then
    raise Exception.CreateFmt(
      'EncodeUnary: OpExtension %d is out of range [0..7]', [OpExtension]);
  if Operand.Kind in [otImm, otNone] then
    raise Exception.Create('EncodeUnary: immediate/none operand not supported');

  // /reg side is the OpExtension field; use a neutral non-extended rt32 register
  // so only the Operand (r/m side) drives any extension or NeedsRex decisions.
  NullReg.ID      := ridRAX;
  NullReg.RegType := rt32;  // IsExtended=False, NeedsRex=False

  EmitRex(Force64Bit, NullReg, Operand);
  WriteByte(Opcode);
  EmitModRMImpl(OpExtension, Operand);
end;

end.
