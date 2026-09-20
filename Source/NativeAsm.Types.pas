{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
unit NativeAsm.Types;

{
  NativeAsm x64 JIT Builder — Type Definitions
  ================================================
  Author : Selahattin Erkoc
  Purpose: Core operand, register, and memory types for the x64 instruction
           builder.  Every other unit in this library depends on this one and
           on nothing else, keeping the dependency graph clean.

  Design notes
  ------------
  * TLabel is an integer-ID-based label handle (inspired by AsmJit).
    Integer IDs allow O(1) lookup and avoid string-hashing overhead.
    Use TAsmBuilder.NewLabel to allocate, TAsmBuilder.Bind to position.
  * TRegister is a value type (record).  All 16 GPRs are predefined as typed
    constants (RAX … R15) so the caller never has to build one by hand.
    The AsR8Lo / AsR16 / AsR32 / AsR64 cast methods let you reinterpret a
    register at a different width without constructing a new constant.
  * TMemory models [Base + Index*Scale + Disp] addressing plus RIP-relative.
  * TOperand is the universal "one argument" type.  Implicit conversion operators
    from TRegister, TMemory, Integer, and Int64 mean the builder methods accept
    any combination without extra casting syntax.
  * Size helpers BytePtr / WordPtr / DWordPtr / QWordPtr produce sized memory
    references that drive MOVZX / MOVSX size selection in the builder.

  Register-type encoding table
  ----------------------------
    rt64   → 64-bit GPR; REX.W only when required by the selected encoding form
    rt32   → 32-bit GPR, no REX.W; zero-extends upper 32 bits on write
    rt16   → 16-bit GPR, 66h operand-size prefix required
    rt8    → 8-bit low-byte GPR (AL/CL/DL/BL/SPL/BPL/SIL/DIL)
    rt8High→ 8-bit high-byte GPR (AH/CH/DH/BH), illegal with REX prefix

  TLabel design (AsmJit-inspired)
  --------------------------------
  Labels are allocated by TAsmBuilder.NewLabel, which returns a TLabel
  with a unique integer ID (0, 1, 2, …).  The label is "positioned" by
  calling TAsmBuilder.Bind(L), which records the current code offset as
  the label's target.  Both forward and backward references are supported:
  fixups are resolved at Build() time.

  An ID of -1 is the invalid / uninitialized sentinel (TLabel.Invalid).
  Mixing TLabel and string-named labels is fully supported.
}

{$ALIGN ON}
{$MINENUMSIZE 4}

// Compile-time guard: this library targets Win64 / x86-64 exclusively.
{$IFNDEF WIN64}
  {$MESSAGE FATAL 'NativeAsm requires a 64-bit Windows target (WIN64). ' +
    'Set the target platform to x64 in Project Options.'}
{$ENDIF}

interface

// ---------------------------------------------------------------------------
// Label handle (integer-ID, type-safe)
// ---------------------------------------------------------------------------

type
  /// <summary>
  ///   Opaque integer-ID label handle.
  ///   Allocate with <c>TAsmBuilder.NewLabel</c>.
  ///   Position in the code stream with <c>TAsmBuilder.Bind(L)</c>.
  ///   Reference in branches and calls with the TLabel overloads of
  ///   <c>J</c> and <c>CallLabel</c>.
  ///   An ID of -1 indicates an uninitialized / invalid label.
  /// </summary>
  TLabel = record
  strict private
    FID: Integer;
  public
    /// <summary>
    ///   Internal constructor used by TAsmBuilder.NewLabel only.
    ///   Callers must never call this directly — it is public only because
    ///   Delphi records cannot restrict construction from the same unit.
    ///   Valid label IDs are 1 .. MaxInt.  ID = 0 is the invalid sentinel so
    ///   that a zero-initialised (Default) TLabel is always invalid,
    ///   matching AsmJit's kInvalidId design.
    /// </summary>
    class function Create(AID: Integer): TLabel; static; inline;
    /// <summary>Returns an invalid label handle (ID = 0).</summary>
    class function Invalid: TLabel; static; inline;
    /// <summary>True when the label was allocated by NewLabel (ID >= 1).</summary>
    function IsValid: Boolean; inline;
    property ID: Integer read FID;
  end;

// ---------------------------------------------------------------------------
// Register identity
// ---------------------------------------------------------------------------

  /// <summary>
  ///   Canonical encoding index (0-15) used for REX / ModRM / opcode+rd
  ///   computation.  ridRIP is a sentinel for RIP-relative addressing; it
  ///   never appears in a REX or ModRM byte directly.
  /// </summary>
  TRegID = (
    ridRAX = 0,  ridRCX = 1,  ridRDX = 2,  ridRBX = 3,
    ridRSP = 4,  ridRBP = 5,  ridRSI = 6,  ridRDI = 7,
    ridR8  = 8,  ridR9  = 9,  ridR10 = 10, ridR11 = 11,
    ridR12 = 12, ridR13 = 13, ridR14 = 14, ridR15 = 15,
    ridRIP = 16   // sentinel for RIP-relative memory operands
  );

  /// <summary>Width of a register — drives prefix / REX.W selection.</summary>
  TRegType = (
    rt64,     // 64-bit GPR; REX.W is form-dependent (default-64 forms may omit W)
    rt32,     // 32-bit: no REX.W; upper 32 bits zero-extended on write
    rt16,     // 16-bit: 0x66 operand-size prefix
    rt8,      // 8-bit low (AL, CL, DL, BL, SPL, BPL, SIL, DIL)
    rt8High   // 8-bit high (AH, CH, DH, BH) — incompatible with REX prefix
  );

  /// <summary>
  ///   Represents a single x64 general-purpose register.
  ///   Use the typed constants (RAX, RCX, …, R15) rather than constructing
  ///   one by hand.
  ///
  ///   Width-cast methods (AsmJit-inspired)
  ///   ------------------------------------
  ///   AsR8Lo / AsR16 / AsR32 / AsR64 return a new TRegister with the same
  ///   encoding index but a different RegType.  They are useful when you have
  ///   a 64-bit register constant and need to emit a narrower operation:
  ///
  ///     B.Movzx(RAX, BytePtr(ridRCX))       // MOVZX RAX, BYTE [RCX]
  ///     B.Mov(TOperand(RCX.AsR32), ...)     // MOV ECX, …
  ///     B.Setcc(cond_JE, RAX.AsR8Lo)        // SETE AL
  ///
  ///   AsR8Lo on ID 4-7 (RSP/RBP/RSI/RDI family) produces SPL/BPL/SIL/DIL,
  ///   which require a REX prefix — NeedsRex() handles this correctly.
  ///   AH/CH/DH/BH have no AsRXX counterpart; use the typed constants directly.
  /// </summary>
  TRegister = record
    ID      : TRegID;
    RegType : TRegType;

    /// <summary>True for R8–R15: requires REX.R or REX.B bit.</summary>
    function IsExtended: Boolean; inline;

    /// <summary>
    ///   True when a REX prefix is required even without REX.W or extension
    ///   bits — applies to SPL/BPL/SIL/DIL in 8-bit mode.
    /// </summary>
    function NeedsRex: Boolean; inline;

    /// <summary>Operand size in bytes implied by RegType.</summary>
    function OperandBytes: Integer; inline;

    // ── Width casts (inspired by AsmJit's Gp::r8/r16/r32/r64) ───────────────
    /// <summary>Return this register reinterpreted as 8-bit low (rt8).</summary>
    function AsR8Lo: TRegister; inline;
    /// <summary>Return this register reinterpreted as 16-bit (rt16).</summary>
    function AsR16:  TRegister; inline;
    /// <summary>Return this register reinterpreted as 32-bit (rt32).</summary>
    function AsR32:  TRegister; inline;
    /// <summary>Return this register reinterpreted as 64-bit (rt64).</summary>
    function AsR64:  TRegister; inline;

    /// <summary>
    ///   Returns the 3-bit value for this register in a ModRM /reg or /rm field.
    ///   For rt8High (AH/CH/DH/BH): returns ID + 4 (AH=4, CH=5, DH=6, BH=7)
    ///   because the high-byte encoding reuses the field values 4–7.
    ///   For all other register types: returns Ord(ID) and 7 (low 3 bits).
    ///   Note: REX prefix is incompatible with rt8High — callers must ensure
    ///   Force64Bit = False and no extension bits are set when using rt8High.
    /// </summary>
    function ModRMField: Byte; inline;

    /// <summary>
    ///   True when this register has a valid ID (0..15).
    ///   ridRIP (16) is not a general-purpose register and must never appear
    ///   in instruction operands directly.
    /// </summary>
    function IsValid: Boolean; inline;
  end;

// ---------------------------------------------------------------------------
// Memory addressing
// ---------------------------------------------------------------------------

  /// <summary>Scale factor for SIB encoding.</summary>
  TScale = (s1 = 0, s2 = 1, s4 = 2, s8 = 3);

  /// <summary>Operand size tag carried inside TMemory.</summary>
  TOperandSize = (
    szUnspecified = 0,
    sz8,    // BYTE  PTR
    sz16,   // WORD  PTR
    sz32,   // DWORD PTR
    sz64,   // QWORD PTR
    sz128
  );

  /// <summary>
  ///   Models an x64 effective-address expression:
  ///   [Base + Index*Scale + Disp] or [RIP + Disp].
  ///
  ///   Factory methods
  ///   ---------------
  ///     TMemory.Create(Base, Disp)            → [Base + Disp]
  ///     TMemory.CreateSib(Base, Idx, S, Disp) → [Base + Idx*S + Disp]
  ///     TMemory.CreateRip(Disp)               → [RIP + Disp]
  ///
  ///   Size helper shortcuts (see below):
  ///     BytePtr / WordPtr / DWordPtr / QWordPtr
  /// </summary>
  TMemory = record
    Base          : TRegID;
    Index         : TRegID;
    Scale         : TScale;
    Disp          : Integer;
    HasIndex      : Boolean;
    IsRipRelative : Boolean;
    Size          : TOperandSize;
    Alignment     : Byte;

    /// <summary>
    ///   [Base + Disp]
    ///   Base must not be ridRIP — use CreateRip for RIP-relative addressing.
    /// </summary>
    class function Create(
      BaseReg      : TRegID;
      Displacement : Integer       = 0;
      OpSize       : TOperandSize  = szUnspecified): TMemory; static;

    /// <summary>
    ///   [Base + Index*Scale + Disp]
    ///   IndexReg must not be ridRSP (field 100b with no REX.X means "no index")
    ///   and must not be ridRIP.
    ///   Base must not be ridRIP (use CreateRip for RIP-relative refs).
    ///   Raises EArgumentException on violation.
    /// </summary>
    class function CreateSib(
      BaseReg, IndexReg : TRegID;
      ScaleVal          : TScale;
      Displacement      : Integer      = 0;
      OpSize            : TOperandSize = szUnspecified): TMemory; static;

    /// <summary>[RIP + Disp] — position-independent data reference</summary>
    class function CreateRip(
      Displacement : Integer;
      OpSize       : TOperandSize = szUnspecified): TMemory; static; inline;
  end;

// ---------------------------------------------------------------------------
// Universal operand
// ---------------------------------------------------------------------------

  TOperandType = (
    otNone = 0,  // zero-initialised / uninitialised sentinel — AsmJit's kNone
    otReg,
    otMem,
    otImm
  );

  /// <summary>
  ///   Universal "one operand" type accepted by all builder methods.
  ///   Implicit conversions let you write:
  ///     .Mov(RAX, RCX)                  // reg ← reg
  ///     .Mov(RAX, QWordPtr(ridRCX, 8))  // reg ← [RCX+8]
  ///     .Add(RDX, 42)                   // reg += imm
  /// </summary>
  TOperand = record
    Kind : TOperandType;
    Reg  : TRegister;
    Mem  : TMemory;
    Imm  : Int64;

    class operator Implicit(R: TRegister): TOperand; inline;
    class operator Implicit(M: TMemory):   TOperand; inline;
    class operator Implicit(I: Integer):   TOperand; inline;
    class operator Implicit(I: Int64):     TOperand; inline;

    /// <summary>True when this operand was explicitly constructed (Kind &lt;&gt; otNone).</summary>
    function IsValid: Boolean; inline;
  end;

// ---------------------------------------------------------------------------
// Function-pointer types used by TExecutableCode.Run
// ---------------------------------------------------------------------------

  TAsmFunc0 = function: UInt64; stdcall;
  TAsmFunc1 = function(P1: UInt64): UInt64; stdcall;
  TAsmFunc2 = function(P1, P2: UInt64): UInt64; stdcall;
  TAsmFunc3 = function(P1, P2, P3: UInt64): UInt64; stdcall;
  TAsmFunc4 = function(P1, P2, P3, P4: UInt64): UInt64; stdcall;

// ---------------------------------------------------------------------------
// Typed 64-bit constants for all GPRs  (16 × 64-bit, 16 × 32-bit, etc.)
// ---------------------------------------------------------------------------

const
  //— 64-bit (REX.W) ———————————————————————————————————————————————————————————
  RAX: TRegister = (ID: ridRAX; RegType: rt64);
  RCX: TRegister = (ID: ridRCX; RegType: rt64);
  RDX: TRegister = (ID: ridRDX; RegType: rt64);
  RBX: TRegister = (ID: ridRBX; RegType: rt64);
  RSP: TRegister = (ID: ridRSP; RegType: rt64);
  RBP: TRegister = (ID: ridRBP; RegType: rt64);
  RSI: TRegister = (ID: ridRSI; RegType: rt64);
  RDI: TRegister = (ID: ridRDI; RegType: rt64);
  R8 : TRegister = (ID: ridR8;  RegType: rt64);
  R9 : TRegister = (ID: ridR9;  RegType: rt64);
  R10: TRegister = (ID: ridR10; RegType: rt64);
  R11: TRegister = (ID: ridR11; RegType: rt64);
  R12: TRegister = (ID: ridR12; RegType: rt64);
  R13: TRegister = (ID: ridR13; RegType: rt64);
  R14: TRegister = (ID: ridR14; RegType: rt64);
  R15: TRegister = (ID: ridR15; RegType: rt64);

  //— 32-bit (no REX.W, upper 32 bits zeroed on write) ————————————————————————
  EAX : TRegister = (ID: ridRAX; RegType: rt32);
  ECX : TRegister = (ID: ridRCX; RegType: rt32);
  EDX : TRegister = (ID: ridRDX; RegType: rt32);
  EBX : TRegister = (ID: ridRBX; RegType: rt32);
  ESP : TRegister = (ID: ridRSP; RegType: rt32);
  EBP : TRegister = (ID: ridRBP; RegType: rt32);
  ESI : TRegister = (ID: ridRSI; RegType: rt32);
  EDI : TRegister = (ID: ridRDI; RegType: rt32);
  R8D : TRegister = (ID: ridR8;  RegType: rt32);
  R9D : TRegister = (ID: ridR9;  RegType: rt32);
  R10D: TRegister = (ID: ridR10; RegType: rt32);
  R11D: TRegister = (ID: ridR11; RegType: rt32);
  R12D: TRegister = (ID: ridR12; RegType: rt32);
  R13D: TRegister = (ID: ridR13; RegType: rt32);
  R14D: TRegister = (ID: ridR14; RegType: rt32);
  R15D: TRegister = (ID: ridR15; RegType: rt32);

  //— 16-bit (66h prefix) ——————————————————————————————————————————————————————
  AX  : TRegister = (ID: ridRAX; RegType: rt16);
  CX  : TRegister = (ID: ridRCX; RegType: rt16);
  DX  : TRegister = (ID: ridRDX; RegType: rt16);
  BX  : TRegister = (ID: ridRBX; RegType: rt16);
  SP  : TRegister = (ID: ridRSP; RegType: rt16);
  BP  : TRegister = (ID: ridRBP; RegType: rt16);
  SI  : TRegister = (ID: ridRSI; RegType: rt16);
  DI  : TRegister = (ID: ridRDI; RegType: rt16);
  R8W : TRegister = (ID: ridR8;  RegType: rt16);
  R9W : TRegister = (ID: ridR9;  RegType: rt16);
  R10W: TRegister = (ID: ridR10; RegType: rt16);
  R11W: TRegister = (ID: ridR11; RegType: rt16);
  R12W: TRegister = (ID: ridR12; RegType: rt16);
  R13W: TRegister = (ID: ridR13; RegType: rt16);
  R14W: TRegister = (ID: ridR14; RegType: rt16);
  R15W: TRegister = (ID: ridR15; RegType: rt16);

  //— 8-bit low ————————————————————————————————————————————————————————————————
  AL  : TRegister = (ID: ridRAX; RegType: rt8);
  CL  : TRegister = (ID: ridRCX; RegType: rt8);
  DL  : TRegister = (ID: ridRDX; RegType: rt8);
  BL  : TRegister = (ID: ridRBX; RegType: rt8);
  SPL : TRegister = (ID: ridRSP; RegType: rt8);   // requires REX prefix
  BPL : TRegister = (ID: ridRBP; RegType: rt8);   // requires REX prefix
  SIL : TRegister = (ID: ridRSI; RegType: rt8);   // requires REX prefix
  DIL : TRegister = (ID: ridRDI; RegType: rt8);   // requires REX prefix
  R8B : TRegister = (ID: ridR8;  RegType: rt8);
  R9B : TRegister = (ID: ridR9;  RegType: rt8);
  R10B: TRegister = (ID: ridR10; RegType: rt8);
  R11B: TRegister = (ID: ridR11; RegType: rt8);
  R12B: TRegister = (ID: ridR12; RegType: rt8);
  R13B: TRegister = (ID: ridR13; RegType: rt8);
  R14B: TRegister = (ID: ridR14; RegType: rt8);
  R15B: TRegister = (ID: ridR15; RegType: rt8);

  //— 8-bit high (AH/CH/DH/BH — no REX prefix allowed) ————————————————————————
  AH  : TRegister = (ID: ridRAX; RegType: rt8High);
  CH  : TRegister = (ID: ridRCX; RegType: rt8High);
  DH  : TRegister = (ID: ridRDX; RegType: rt8High);
  BH  : TRegister = (ID: ridRBX; RegType: rt8High);

// ---------------------------------------------------------------------------
// Typed memory-size shorthand functions
// ---------------------------------------------------------------------------

/// <summary>BYTE PTR [Base + Disp]</summary>
function BytePtr(Base: TRegID; Disp: Integer = 0): TMemory; inline;
/// <summary>WORD PTR [Base + Disp]</summary>
function WordPtr(Base: TRegID; Disp: Integer = 0): TMemory; inline;
/// <summary>DWORD PTR [Base + Disp]</summary>
function DWordPtr(Base: TRegID; Disp: Integer = 0): TMemory; inline;
/// <summary>QWORD PTR [Base + Disp]</summary>
function QWordPtr(Base: TRegID; Disp: Integer = 0): TMemory; inline;

/// <summary>BYTE PTR [Base + Index*Scale + Disp]</summary>
function BytePtrSib(Base, Index: TRegID; Scale: TScale; Disp: Integer = 0): TMemory; inline;
/// <summary>QWORD PTR [Base + Index*Scale + Disp]</summary>
function QWordPtrSib(Base, Index: TRegID; Scale: TScale; Disp: Integer = 0): TMemory; inline;

/// <summary>QWORD PTR [RIP + Disp]  — RIP-relative, for PIC stubs</summary>
function QWordRip(Disp: Integer): TMemory; inline;

implementation

uses
  System.SysUtils;

// ---------------------------------------------------------------------------
// TLabel
// ---------------------------------------------------------------------------

class function TLabel.Create(AID: Integer): TLabel;
begin
  Result.FID := AID;
end;

class function TLabel.Invalid: TLabel;
begin
  // ID = 0 is the sentinel.  Default(TLabel) has FID = 0 → IsValid = False.
  Result.FID := 0;
end;

function TLabel.IsValid: Boolean;
begin
  // Valid label IDs are 1 .. MaxInt.
  // 0  = uninitialised / invalid (matches AsmJit kInvalidId principle).
  // <0 = also treated as invalid (legacy guard).
  Result := FID > 0;
end;

// ---------------------------------------------------------------------------
// TRegister
// ---------------------------------------------------------------------------

function TRegister.IsExtended: Boolean;
begin
  Result := (ID >= ridR8) and (ID <= ridR15);
end;

function TRegister.NeedsRex: Boolean;
begin
  if IsExtended then Exit(True);
  // SPL/BPL/SIL/DIL need a REX prefix so the encoder uses new-byte encoding
  if (RegType = rt8) and (ID >= ridRSP) and (ID <= ridRDI) then Exit(True);
  Result := False;
end;

function TRegister.OperandBytes: Integer;
begin
  case RegType of
    rt64     : Result := 8;
    rt32     : Result := 4;
    rt16     : Result := 2;
    rt8,
    rt8High  : Result := 1;
  else
    Result := 8;
  end;
end;

// ── Width casts ──────────────────────────────────────────────────────────────

function TRegister.AsR8Lo: TRegister;
begin
  Result.ID      := Self.ID;
  Result.RegType := rt8;
end;

function TRegister.AsR16: TRegister;
begin
  Result.ID      := Self.ID;
  Result.RegType := rt16;
end;

function TRegister.AsR32: TRegister;
begin
  Result.ID      := Self.ID;
  Result.RegType := rt32;
end;

function TRegister.AsR64: TRegister;
begin
  Result.ID      := Self.ID;
  Result.RegType := rt64;
end;

function TRegister.ModRMField: Byte;
begin
  // AH/CH/DH/BH have RegType = rt8High.  Without a REX prefix the CPU
  // interprets ModRM field values 4–7 as AH/CH/DH/BH rather than
  // SPL/BPL/SIL/DIL.  The register constants store ID = ridRAX/RCX/RDX/RBX
  // (0–3) so we add 4 to get the correct ModRM encoding.
  if RegType = rt8High then
    Result := Byte(Ord(ID)) + 4   // AH=4, CH=5, DH=6, BH=7
  else
    Result := Byte(Ord(ID)) and 7; // low 3 bits; REX.R/B extends the 4th
end;

function TRegister.IsValid: Boolean;
begin
  // ridRIP (16) is a sentinel for memory operands, never a real GPR.
  Result := (Ord(ID) >= 0) and (Ord(ID) <= 15);
end;

// ---------------------------------------------------------------------------
// TMemory
// ---------------------------------------------------------------------------

class function TMemory.Create(BaseReg: TRegID; Displacement: Integer;
  OpSize: TOperandSize): TMemory;
begin
  if BaseReg = ridRIP then
    raise EArgumentException.Create(
      'TMemory.Create: ridRIP cannot be used as a base register in a normal ' +
      'memory operand. Use TMemory.CreateRip for RIP-relative addressing.');
  Result.Base          := BaseReg;
  Result.Disp          := Displacement;
  Result.HasIndex      := False;
  Result.IsRipRelative := False;
  Result.Index         := ridRAX;  // unused
  Result.Scale         := s1;
  Result.Size          := OpSize;
  Result.Alignment     := 0;
end;

class function TMemory.CreateSib(BaseReg, IndexReg: TRegID; ScaleVal: TScale;
  Displacement: Integer; OpSize: TOperandSize): TMemory;
begin
  // ridRSP as index: the SIB index field 100b with REX.X=0 means "no index"
  // in the x64 encoding.  ridRSP would silently vanish from the address.
  // ridR12 is fine as index because REX.X=1 distinguishes it from "no index".
  if IndexReg = ridRSP then
    raise EArgumentException.Create(
      'TMemory.CreateSib: RSP (ridRSP) cannot be used as an SIB index register. ' +
      'The encoding field 100b with REX.X=0 means "no index", so the index ' +
      'would be silently ignored. Use a different index register.');
  if IndexReg = ridRIP then
    raise EArgumentException.Create(
      'TMemory.CreateSib: ridRIP is a sentinel and cannot be used as an SIB index.');
  if BaseReg = ridRIP then
    raise EArgumentException.Create(
      'TMemory.CreateSib: ridRIP cannot be used as a base register in an SIB operand. ' +
      'RIP-relative addressing does not support a scaled index. Use TMemory.CreateRip.');
  Result.Base          := BaseReg;
  Result.Index         := IndexReg;
  Result.Scale         := ScaleVal;
  Result.Disp          := Displacement;
  Result.HasIndex      := True;
  Result.IsRipRelative := False;
  Result.Size          := OpSize;
  Result.Alignment     := 0;
end;

class function TMemory.CreateRip(Displacement: Integer;
  OpSize: TOperandSize): TMemory;
begin
  Result.Base          := ridRIP;   // sentinel
  Result.Disp          := Displacement;
  Result.IsRipRelative := True;
  Result.HasIndex      := False;
  Result.Index         := ridRAX;
  Result.Scale         := s1;
  Result.Size          := OpSize;
  Result.Alignment     := 0;
end;

// ---------------------------------------------------------------------------
// TOperand
// ---------------------------------------------------------------------------

class operator TOperand.Implicit(R: TRegister): TOperand;
begin
  Result.Kind := otReg;
  Result.Reg  := R;
  Result.Imm  := 0;
end;

class operator TOperand.Implicit(M: TMemory): TOperand;
begin
  Result.Kind := otMem;
  Result.Mem  := M;
  Result.Imm  := 0;
end;

class operator TOperand.Implicit(I: Integer): TOperand;
begin
  Result.Kind := otImm;
  Result.Imm  := I;
end;

class operator TOperand.Implicit(I: Int64): TOperand;
begin
  Result.Kind := otImm;
  Result.Imm  := I;
end;

function TOperand.IsValid: Boolean;
begin
  Result := Kind <> otNone;
end;

// ---------------------------------------------------------------------------
// Size-helper factories
// ---------------------------------------------------------------------------

function BytePtr(Base: TRegID; Disp: Integer): TMemory;
begin
  Result := TMemory.Create(Base, Disp, sz8);
end;

function WordPtr(Base: TRegID; Disp: Integer): TMemory;
begin
  Result := TMemory.Create(Base, Disp, sz16);
end;

function DWordPtr(Base: TRegID; Disp: Integer): TMemory;
begin
  Result := TMemory.Create(Base, Disp, sz32);
end;

function QWordPtr(Base: TRegID; Disp: Integer): TMemory;
begin
  Result := TMemory.Create(Base, Disp, sz64);
end;

function BytePtrSib(Base, Index: TRegID; Scale: TScale; Disp: Integer): TMemory;
begin
  Result := TMemory.CreateSib(Base, Index, Scale, Disp, sz8);
end;

function QWordPtrSib(Base, Index: TRegID; Scale: TScale; Disp: Integer): TMemory;
begin
  Result := TMemory.CreateSib(Base, Index, Scale, Disp, sz64);
end;

function QWordRip(Disp: Integer): TMemory;
begin
  Result := TMemory.CreateRip(Disp, sz64);
end;

end.
