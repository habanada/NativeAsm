{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }

unit NativeAsm.Builder;



{

  NativeAsm x64 JIT Builder — Fluent Builder

  ==============================================

  Author : NativeAsm Project

  Purpose: Fluent (method-chaining) API for composing x64 machine code at

           runtime.  All methods return Self so you can write:



    TAsmBuilder.New

      .Prolog

      .Mov(RAX, RCX)

      .Add(RAX, RDX)

      .Epilog

      .Ret;



  Label / fixup model

  -------------------

  Two complementary labelling systems are available:



  1. Integer-label API (AsmJit-inspired, preferred):

       var L := B.NewLabel;         // allocate

       B.Bind(L);                   // position at current offset

       B.J(cond_JE, L);             // backward or forward branch

       B.CallLabel(L);              // call to label



  2. String-label API (backward-compatible, still fully supported):

       B.Label_('loop');            // position

       B.J(cond_JNE, 'loop');      // branch

       B.CallLabel('loop');         // call



  Integer labels are translated internally to collision-safe string keys

  with a null-character prefix (#0'<id>') that cannot be produced by the

  string API, so both APIs coexist in one builder without any risk of

  integer-label key 1 colliding with user string label '#1'.



  Forward references are supported in both APIs: fixups are applied at

  Build() time.  Three fixup kinds:

    fkRelative32   – JMP/CALL: displacement relative to next instruction

    fkAbsolute64   – reserved for runtime patching

    fkDataOffset32 – raw offset with optional XOR mask (for data references)



  Code alignment

  --------------

  AlignTo(N) pads the current offset to the next N-byte boundary using the

  Intel-recommended multi-byte NOP sequences (when FillByte = $90) or any

  fill byte you choose.  N must be a power of two.



  Win64 ABI overview (quick reference)

  -------------------------------------

    Volatile:   RAX RCX RDX R8 R9 R10 R11  (caller saves)

    Non-volatile: RBX RSI RDI R12–R15 RBP RSP  (callee saves)

    Args 1–4:   RCX  RDX  R8  R9

    Return:     RAX

    Shadow space: 32 bytes reserved by caller above return address

    RSP alignment: 16-byte before CALL (i.e. 8-byte on entry to callee)

}



{$ALIGN ON}

{$MINENUMSIZE 4}



interface



uses

  System.SysUtils,

  System.Classes,

  System.Generics.Collections,

  Winapi.Windows,

  NativeAsm.Types,

  NativeAsm.Encoder;



// ---------------------------------------------------------------------------

// Supporting types

// ---------------------------------------------------------------------------



type

  /// <summary>Branch condition codes mirroring x64 Jcc opcodes.</summary>

  TCondition = (

    cond_JMP,   // unconditional

    cond_JE,    // equal / zero

    cond_JNE,   // not equal / not zero

    cond_JG,    // greater (signed)

    cond_JGE,   // greater or equal (signed)

    cond_JL,    // less (signed)

    cond_JLE,   // less or equal (signed)

    cond_JA,    // above (unsigned)

    cond_JAE,   // above or equal (unsigned)

    cond_JB,    // below (unsigned)

    cond_JBE    // below or equal (unsigned)

  );



  /// <summary>Determines how a label fixup is patched at Build time.</summary>

  TFixupKind = (

    fkRelative32,    // rel32: target - (fixup_offset + 4)

    fkAbsolute64,    // abs64: requires runtime base address (not auto-patched)

    fkDataOffset32   // raw offset with optional XOR key

  );



  TFixup = record

    Offset    : Integer;       // byte offset of the placeholder in the stream

    LabelName : string;        // target label (string key, possibly '#<id>')

    Kind      : TFixupKind;

    XorKey    : Integer;       // mask applied during Build for fkDataOffset32

  end;



// ---------------------------------------------------------------------------

// TAsmBuilder

// ---------------------------------------------------------------------------



  /// <summary>

  ///   Fluent x64 machine-code builder.

  ///   All Emit/instruction methods return Self to enable chaining.

  /// </summary>

  TAsmBuilder = class

  private

    FEncoder     : TEncoderX64;

    FLabels      : TDictionary<string, Integer>;

    FFixups      : TList<TFixup>;

    FNextLabelID : Integer;   // counter for integer-label allocation



    procedure PatchLabels(var Code: TBytes);

    function  InternalRun(const Code: TBytes; const Args: array of UInt64): UInt64;



    // Map the public condition enum to the canonical generated DB suffix.

    class function ConditionSuffix(Cond: TCondition): string; static;



    // Convert integer label ID to internal string key (collision-safe)

    class function LabelKey(ID: Integer): string; static; inline;



  public

    constructor Create;

    destructor  Destroy; override;



    // ── Factory ─────────────────────────────────────────────────────────────

    /// <summary>

    ///   Convenience factory.  Caller owns the returned instance.

    ///   Enables: var B := TAsmBuilder.New; … B.Free;

    /// </summary>

    class function New: TAsmBuilder;



    // ── Builder state ────────────────────────────────────────────────────────

    /// <summary>

    ///   Reset builder to empty state, discarding all emitted bytes, labels

    ///   and fixups.  The encoder buffer is kept allocated for reuse.

    /// </summary>

    function Reset: TAsmBuilder;



    /// <summary>Number of bytes emitted so far.</summary>

    function CodeSize: Integer;

    procedure CopyLabelsTo(Target: TDictionary<string, Integer>);



    // ── Integer-label API (AsmJit-inspired) ─────────────────────────────────

    /// <summary>

    ///   Allocate a new label.  The label is initially unbound (no position).

    ///   Bind it to the current offset with Bind(L) when you reach the target.

    /// </summary>

    function NewLabel: TLabel;



    /// <summary>

    ///   Mark the current offset as the target of integer label L.

    ///   Equivalent to Label_() for string labels.

    /// </summary>

    function Bind(L: TLabel): TAsmBuilder;



    // ── String-label API (classic, backward-compatible) ──────────────────────

    /// <summary>Mark the current offset as a named label.</summary>

    function Label_(const Name: string): TAsmBuilder;



    // ── Branching — string overloads ─────────────────────────────────────────

    /// <summary>Emit a conditional (or unconditional) near branch to a string label.</summary>

    function J(Cond: TCondition; const LabelName: string): TAsmBuilder; overload;



    /// <summary>Emit a CALL rel32 to a named string label.</summary>

    function CallLabel(const LabelName: string): TAsmBuilder; overload;



    // ── Branching — integer-label overloads ──────────────────────────────────

    /// <summary>Emit a conditional (or unconditional) near branch to an integer label.</summary>

    function J(Cond: TCondition; L: TLabel): TAsmBuilder; overload;



    /// <summary>Emit a CALL rel32 to an integer label.</summary>

    function CallLabel(L: TLabel): TAsmBuilder; overload;



    // ── Data / offset emission ────────────────────────────────────────────────

    /// <summary>

    ///   Emit a 4-byte placeholder that Build() will fill with the offset of

    ///   LabelName from the placeholder position, optionally XOR'd with XorKey.

    /// </summary>

    function EmitLabelOffset(const LabelName: string; XorKey: Integer = 0): TAsmBuilder;



    // ── Code alignment ────────────────────────────────────────────────────────

    /// <summary>

    ///   Pad the code stream to the next N-byte boundary.

    ///   N must be a power of two (1, 2, 4, 8, 16, 32, 64 …).

    ///

    ///   When FillByte = $90 (default), uses Intel-recommended multi-byte NOP

    ///   sequences (up to 9 bytes each) for performance-optimal padding.

    ///   For data alignment or when NOPs are undesirable, pass a different

    ///   fill byte (e.g. $CC for INT3, $00 for zero, $90 for single-byte NOP).

    ///

    ///   If the current offset is already aligned, nothing is emitted.

    /// </summary>

    function AlignTo(Alignment: Integer; FillByte: Byte = $90): TAsmBuilder;



    // ── Raw emission (escape hatch for unsupported encodings) ─────────────────

    function EmitByte(B: Byte): TAsmBuilder;

    function EmitBytes(const Data: array of Byte): TAsmBuilder;



    // ── Data Transfer ─────────────────────────────────────────────────────────

    /// <summary>

    ///   Universal MOV dispatcher.  Handles all combinations:

    ///     Reg ← Reg | Mem | Imm

    ///     Mem ← Reg

    ///   Width is selected from the register operand and checked against an

    ///   explicit memory size. Unsized memory paired with a register inherits

    ///   that register width; it is never globally treated as qword.

    ///   Imm32 uses sign-extended MOV r/m64, imm32 (C7 /0).

    ///   Imm64 uses full MOV r64, imm64 (B8+rd io).

    ///   NOTE: Imm=0 is encoded as C7 /0 (not as XOR), so flags are preserved.

    /// </summary>

    function Mov(Dest, Src: TOperand): TAsmBuilder;



    /// <summary>

    ///   MOVSX/MOVSXD — sign-extend an explicitly sized memory source.

    ///   Valid destination widths follow the generated source forms.

    /// </summary>

    function Movsx(Dest: TRegister; Src: TOperand): TAsmBuilder;



    /// <summary>

    ///   MOVZX — zero-extend an explicitly sized sz8/sz16 memory source.

    ///   Valid destination widths follow the generated source forms.

    /// </summary>

    function Movzx(Dest: TRegister; Src: TOperand): TAsmBuilder;



    /// <summary>LEA Dest, [Mem]</summary>

    function Lea(Dest: TRegister; Mem: TMemory): TAsmBuilder;



    /// <summary>XCHG register/register for supported 8/16/32/64-bit forms.</summary>

    function Xchg(A, B: TRegister): TAsmBuilder;



    // ── Arithmetic ────────────────────────────────────────────────────────────

    function Add(Dest, Src: TOperand): TAsmBuilder;

    function Adc(Dest, Src: TOperand): TAsmBuilder;

    function Sub(Dest, Src: TOperand): TAsmBuilder;

    function Sbb(Dest, Src: TOperand): TAsmBuilder;

    function Inc_(Dest: TOperand): TAsmBuilder;

    function Dec_(Dest: TOperand): TAsmBuilder;

    function Neg(Dest: TOperand): TAsmBuilder;

    function Imul(Dest, Src: TRegister): TAsmBuilder; overload;

    function Imul(Dest, Src: TRegister; Imm: Integer): TAsmBuilder; overload;

    function Mul(Src: TOperand): TAsmBuilder;



    // ── Bit manipulation ──────────────────────────────────────────────────────

    function Shl_(Dest: TOperand; Count: TOperand): TAsmBuilder;

    function Shr_(Dest: TOperand; Count: TOperand): TAsmBuilder;

    function Sar(Dest: TOperand; Count: TOperand): TAsmBuilder;

    function Rol(Dest: TRegister; Count: Byte): TAsmBuilder;

    function Ror(Dest: TRegister; Count: Byte): TAsmBuilder;

    function Bsf(Dest, Src: TRegister): TAsmBuilder;

    function Bsr(Dest, Src: TRegister): TAsmBuilder;

    /// <summary>POPCNT register/register; source DB also retains r/m forms.</summary>

    function Popcnt(Dest, Src: TRegister): TAsmBuilder;

    /// <summary>BSWAP r64 — byte-reverse for endianness conversion</summary>

    function Bswap(Reg: TRegister): TAsmBuilder;



    // ── Logic ─────────────────────────────────────────────────────────────────

    function Xor_(Dest, Src: TOperand): TAsmBuilder;

    function And_(Dest, Src: TOperand): TAsmBuilder;

    function Or_(Dest, Src: TOperand): TAsmBuilder;

    function Not_(Dest: TOperand): TAsmBuilder;



    // ── Comparison / flags ────────────────────────────────────────────────────

    function Cmp(Dest, Src: TOperand): TAsmBuilder;

    function Test(Dest, Src: TOperand): TAsmBuilder;



    // ── Conditional move ──────────────────────────────────────────────────────

    function Cmov(Cond: TCondition; Dest, Src: TRegister): TAsmBuilder;



    // ── Conditional set ───────────────────────────────────────────────────────

    /// <summary>

    ///   SETcc AL/CL/… — sets the 8-bit register to 0 or 1 based on flags.

    ///   Use AL, CL, DL, BL, R8B … or RAX.AsR8Lo() for the Dest register.

    /// </summary>

    function Setcc(Cond: TCondition; Dest: TRegister): TAsmBuilder;



    // ── Stack ─────────────────────────────────────────────────────────────────

    function Push(Op: TOperand): TAsmBuilder;

    function Pop(Op: TOperand): TAsmBuilder;



    // ── Control flow ─────────────────────────────────────────────────────────

    function Call(Op: TOperand): TAsmBuilder; overload;

    function Call(Addr: Pointer): TAsmBuilder; overload;

    function Ret: TAsmBuilder; overload;

    function Ret(StackBytes: Word): TAsmBuilder; overload;



    // ── Structured frame helpers ──────────────────────────────────────────────

    /// <summary>

    ///   Win64-ABI-correct function prolog:

    ///     PUSH RBP

    ///     MOV  RBP, RSP

    ///     SUB  RSP, ShadowAndLocalBytes

    ///   ShadowAndLocalBytes must be ≥ 32 and 16-byte aligned.

    ///   Default 32 = shadow space only (no locals).

    /// </summary>

    function Prolog(ShadowAndLocalBytes: Integer = 32): TAsmBuilder;



    /// <summary>

    ///   Matching epilog:

    ///     MOV RSP, RBP

    ///     POP RBP

    ///   Caller must follow with Ret.

    /// </summary>

    function Epilog: TAsmBuilder;



    // ── Fence / timing ────────────────────────────────────────────────────────

    function Lfence: TAsmBuilder;

    function Mfence: TAsmBuilder;

    function Sfence: TAsmBuilder;

    function Rdtsc: TAsmBuilder;

    function Rdtscp: TAsmBuilder;



    // ── NOP / debug ───────────────────────────────────────────────────────────

    /// <summary>

    ///   Emit an Intel-recommended multi-byte NOP of exactly N bytes (1–9).

    ///   Prefer multi-byte NOPs over repeated 0x90 for alignment padding.

    /// </summary>

    function Nop(Count: Integer = 1): TAsmBuilder;



    /// <summary>INT 3 — software breakpoint trap for debugging.</summary>

    function Int3: TAsmBuilder;



    /// <summary>UD2 — architecturally undefined instruction; raises #UD.</summary>

    function Ud2: TAsmBuilder;



    // ── Build / run ───────────────────────────────────────────────────────────

    /// <summary>

    ///   Finalize the code stream: apply all label fixups and return the

    ///   byte array.  The builder remains usable for further emission.

    /// </summary>

    function Build: TBytes;



    /// <summary>

    ///   Build + allocate executable memory + execute + free.

    ///   Convenient for unit-testing generated snippets.

    ///   WARNING: only suitable for trusted, locally-generated code.

    /// </summary>

    function Run: UInt64; overload;

    function Run(Arg1: UInt64): UInt64; overload;

    function Run(Arg1, Arg2: UInt64): UInt64; overload;

    function Run(Arg1, Arg2, Arg3: UInt64): UInt64; overload;

    function Run(Arg1, Arg2, Arg3, Arg4: UInt64): UInt64; overload;

  end;



implementation



uses

  NativeAsm.StaticEncoder;



// ---------------------------------------------------------------------------

// Internal helpers

// ---------------------------------------------------------------------------



class function TAsmBuilder.LabelKey(ID: Integer): string;

begin

  // Use a null-character prefix so this key can NEVER collide with a

  // user-provided string label.  String literals in Pascal cannot contain

  // #0 unless the programmer embeds it explicitly with the #0 escape; no

  // reasonable label name would start with a null byte.

  // Old prefix '#' was the bug: Label_('#1') silently aliased integer label 1.

  Result := #0 + IntToStr(ID);

end;



class function TAsmBuilder.ConditionSuffix(Cond: TCondition): string;

begin

  case Cond of

    cond_JMP: Result := '';

    cond_JE:  Result := 'z';

    cond_JNE: Result := 'nz';

    cond_JG:  Result := 'nle';

    cond_JGE: Result := 'nl';

    cond_JL:  Result := 'l';

    cond_JLE: Result := 'le';

    cond_JA:  Result := 'nbe';

    cond_JAE: Result := 'nb';

    cond_JB:  Result := 'b';

    cond_JBE: Result := 'be';

  else

    raise EArgumentException.CreateFmt('Unknown condition %d', [Ord(Cond)]);

  end;

end;



procedure TAsmBuilder.PatchLabels(var Code: TBytes);

var

  Fix       : TFixup;

  TargetPos : Integer;

  RelOffset : Integer;

begin

  for Fix in FFixups do

  begin

    if not FLabels.TryGetValue(Fix.LabelName, TargetPos) then

      raise Exception.CreateFmt(

        'TAsmBuilder.Build: label "%s" referenced but never defined', [Fix.LabelName]);



    case Fix.Kind of

      fkRelative32:

      begin

        // displacement = target - (placeholder_end)

        RelOffset := TargetPos - (Fix.Offset + 4);

        Code[Fix.Offset]     :=  RelOffset         and $FF;

        Code[Fix.Offset + 1] := (RelOffset shr  8) and $FF;

        Code[Fix.Offset + 2] := (RelOffset shr 16) and $FF;

        Code[Fix.Offset + 3] := (RelOffset shr 24) and $FF;

      end;



      fkAbsolute64:

        raise Exception.Create(

          'fkAbsolute64 fixups require a runtime base address and cannot be ' +

          'patched by Build.  Use TExecutableCode.PatchQWord instead.');



      fkDataOffset32:

      begin

        RelOffset := (TargetPos - Fix.Offset) xor Fix.XorKey;

        Code[Fix.Offset]     :=  RelOffset         and $FF;

        Code[Fix.Offset + 1] := (RelOffset shr  8) and $FF;

        Code[Fix.Offset + 2] := (RelOffset shr 16) and $FF;

        Code[Fix.Offset + 3] := (RelOffset shr 24) and $FF;

      end;

    end;

  end;

end;



// ---------------------------------------------------------------------------

// Constructor / destructor

// ---------------------------------------------------------------------------



constructor TAsmBuilder.Create;

begin

  FEncoder     := TEncoderX64.Create(256);

  FLabels      := TDictionary<string, Integer>.Create;

  FFixups      := TList<TFixup>.Create;

  // AsmJit kInvalidId principle: 0 is the sentinel for "invalid label" (see TLabel.IsValid).

  // Real labels start at 1 so that Default(TLabel) is always invalid.

  FNextLabelID := 1;

end;



destructor TAsmBuilder.Destroy;

begin

  FEncoder.Free;

  FLabels.Free;

  FFixups.Free;

  inherited;

end;



class function TAsmBuilder.New: TAsmBuilder;

begin

  Result := TAsmBuilder.Create;

end;



function TAsmBuilder.Reset: TAsmBuilder;

begin

  FEncoder.Reset;

  FLabels.Clear;

  FFixups.Clear;

  FNextLabelID := 1;  // 0 = invalid sentinel

  Result := Self;

end;



function TAsmBuilder.CodeSize: Integer;

begin

  Result := FEncoder.CurrentOffset;

end;

procedure TAsmBuilder.CopyLabelsTo(Target: TDictionary<string, Integer>);
var
  Pair: TPair<string, Integer>;
begin
  if Target = nil then
    raise EArgumentNilException.Create('Target');
  Target.Clear;
  for Pair in FLabels do
    Target.AddOrSetValue(Pair.Key, Pair.Value);
end;



// ---------------------------------------------------------------------------

// Integer-label API

// ---------------------------------------------------------------------------



function TAsmBuilder.NewLabel: TLabel;

begin

  Result := TLabel.Create(FNextLabelID);

  Inc(FNextLabelID);

end;



function TAsmBuilder.Bind(L: TLabel): TAsmBuilder;

begin

  if not L.IsValid then

    raise Exception.Create('TAsmBuilder.Bind: invalid label (ID=0 is the unbound sentinel; call NewLabel first)');

  // Internally treated as a named label with a collision-safe key

  Label_(LabelKey(L.ID));

  Result := Self;

end;



// ---------------------------------------------------------------------------

// String-label API

// ---------------------------------------------------------------------------



function TAsmBuilder.Label_(const Name: string): TAsmBuilder;

begin

  if FLabels.ContainsKey(Name) then

    raise Exception.CreateFmt(

      'TAsmBuilder.Label_: label "%s" already defined', [Name]);

  FLabels.Add(Name, FEncoder.CurrentOffset);

  Result := Self;

end;



// ---------------------------------------------------------------------------

// Branching — internal helper

// ---------------------------------------------------------------------------



function TAsmBuilder.J(Cond: TCondition; const LabelName: string): TAsmBuilder;

var

  Fix: TFixup;

  PlaceholderOffset: Integer;

  Mnemonic: string;

begin

  if Cond = cond_JMP then

    Mnemonic := 'jmp'

  else

    Mnemonic := 'j' + ConditionSuffix(Cond);



  TStaticInstructionEncoder.EmitRelative32Placeholder(

    FEncoder, Mnemonic, PlaceholderOffset);



  Fix.Offset    := PlaceholderOffset;

  Fix.LabelName := LabelName;

  Fix.Kind      := fkRelative32;

  Fix.XorKey    := 0;

  FFixups.Add(Fix);

  Result := Self;

end;



function TAsmBuilder.J(Cond: TCondition; L: TLabel): TAsmBuilder;

begin

  if not L.IsValid then

    raise Exception.Create('TAsmBuilder.J: invalid label (ID=0 is the unbound sentinel; call NewLabel first)');

  Result := J(Cond, LabelKey(L.ID));

end;



function TAsmBuilder.CallLabel(const LabelName: string): TAsmBuilder;

var

  Fix: TFixup;

  PlaceholderOffset: Integer;

begin

  TStaticInstructionEncoder.EmitRelative32Placeholder(

    FEncoder, 'call', PlaceholderOffset);

  Fix.Offset    := PlaceholderOffset;

  Fix.LabelName := LabelName;

  Fix.Kind      := fkRelative32;

  Fix.XorKey    := 0;

  FFixups.Add(Fix);

  Result := Self;

end;



function TAsmBuilder.CallLabel(L: TLabel): TAsmBuilder;

begin

  if not L.IsValid then

    raise Exception.Create('TAsmBuilder.CallLabel: invalid label (ID=0 is the unbound sentinel; call NewLabel first)');

  Result := CallLabel(LabelKey(L.ID));

end;



function TAsmBuilder.EmitLabelOffset(const LabelName: string;

  XorKey: Integer): TAsmBuilder;

var

  Fix: TFixup;

begin

  Fix.Offset    := FEncoder.CurrentOffset;

  Fix.LabelName := LabelName;

  Fix.Kind      := fkDataOffset32;

  Fix.XorKey    := XorKey;

  FFixups.Add(Fix);

  FEncoder.EmitInt32Raw(0);

  Result := Self;

end;



// ---------------------------------------------------------------------------

// Code alignment

// ---------------------------------------------------------------------------



function TAsmBuilder.AlignTo(Alignment: Integer; FillByte: Byte): TAsmBuilder;

var

  Current, Rem, PadBytes, K: Integer;

begin

  if Alignment <= 1 then begin Result := Self; Exit; end;

  if (Alignment and (Alignment - 1)) <> 0 then

    raise Exception.CreateFmt(

      'AlignTo: alignment %d is not a power of two', [Alignment]);



  Current  := FEncoder.CurrentOffset;

  Rem      := Current and (Alignment - 1);

  PadBytes := (Alignment - Rem) and (Alignment - 1);



  if PadBytes = 0 then begin Result := Self; Exit; end;



  if FillByte = $90 then

    // Use multi-byte NOPs for instruction-stream alignment

    Nop(PadBytes)

  else

    for K := 1 to PadBytes do

      FEncoder.EmitRaw(FillByte);



  Result := Self;

end;



// ---------------------------------------------------------------------------

// Raw emission

// ---------------------------------------------------------------------------



function TAsmBuilder.EmitByte(B: Byte): TAsmBuilder;

begin

  FEncoder.EmitRaw(B);

  Result := Self;

end;



function TAsmBuilder.EmitBytes(const Data: array of Byte): TAsmBuilder;

var

  I: Integer;

begin

  for I := 0 to High(Data) do

    FEncoder.EmitRaw(Data[I]);

  Result := Self;

end;



// ---------------------------------------------------------------------------

// MOV — universal dispatcher

// ---------------------------------------------------------------------------



function TAsmBuilder.Mov(Dest, Src: TOperand): TAsmBuilder;

begin

  TStaticInstructionEncoder.Encode(FEncoder, 'mov', [Dest, Src]);

  Result := Self;

end;



function TAsmBuilder.Movsx(Dest: TRegister; Src: TOperand): TAsmBuilder;

begin

  // Current NativeAsm API intentionally exposes memory source only. An

  // explicit source width is mandatory so m8/m16/m32 cannot be guessed.

  if Src.Kind <> otMem then

    raise EArgumentException.Create('Movsx: source must be a memory operand');

  if not (Src.Mem.Size in [sz8, sz16, sz32]) then

    raise EArgumentException.Create(

      'Movsx: source memory operand must have sz8, sz16 or sz32');



  if Src.Mem.Size = sz32 then

    TStaticInstructionEncoder.Encode(FEncoder, 'movsxd',

      [TOperand(Dest), Src])

  else

    TStaticInstructionEncoder.Encode(FEncoder, 'movsx',

      [TOperand(Dest), Src]);

  Result := Self;

end;



function TAsmBuilder.Movzx(Dest: TRegister; Src: TOperand): TAsmBuilder;

begin

  if Src.Kind <> otMem then

    raise EArgumentException.Create('Movzx: source must be a memory operand');

  if not (Src.Mem.Size in [sz8, sz16]) then

    raise EArgumentException.Create(

      'Movzx: source memory operand must have sz8 or sz16');

  TStaticInstructionEncoder.Encode(FEncoder, 'movzx',

    [TOperand(Dest), Src]);

  Result := Self;

end;



function TAsmBuilder.Lea(Dest: TRegister; Mem: TMemory): TAsmBuilder;

begin

  TStaticInstructionEncoder.Encode(FEncoder, 'lea',

    [TOperand(Dest), TOperand(Mem)]);

  Result := Self;

end;



function TAsmBuilder.Xchg(A, B: TRegister): TAsmBuilder;

begin

  TStaticInstructionEncoder.Encode(FEncoder, 'xchg',

    [TOperand(A), TOperand(B)]);

  Result := Self;

end;



function TAsmBuilder.Add(Dest, Src: TOperand): TAsmBuilder;

begin

  TStaticInstructionEncoder.Encode(FEncoder, 'add', [Dest, Src]);

  Result := Self;

end;



function TAsmBuilder.Adc(Dest, Src: TOperand): TAsmBuilder;

begin

  TStaticInstructionEncoder.Encode(FEncoder, 'adc', [Dest, Src]);

  Result := Self;

end;



function TAsmBuilder.Sub(Dest, Src: TOperand): TAsmBuilder;

begin

  TStaticInstructionEncoder.Encode(FEncoder, 'sub', [Dest, Src]);

  Result := Self;

end;



function TAsmBuilder.Sbb(Dest, Src: TOperand): TAsmBuilder;

begin

  TStaticInstructionEncoder.Encode(FEncoder, 'sbb', [Dest, Src]);

  Result := Self;

end;



function TAsmBuilder.Inc_(Dest: TOperand): TAsmBuilder;

begin

  TStaticInstructionEncoder.Encode(FEncoder, 'inc', [Dest]);

  Result := Self;

end;



function TAsmBuilder.Dec_(Dest: TOperand): TAsmBuilder;

begin

  TStaticInstructionEncoder.Encode(FEncoder, 'dec', [Dest]);

  Result := Self;

end;



function TAsmBuilder.Neg(Dest: TOperand): TAsmBuilder;

begin

  TStaticInstructionEncoder.Encode(FEncoder, 'neg', [Dest]);

  Result := Self;

end;



function TAsmBuilder.Imul(Dest, Src: TRegister): TAsmBuilder;

begin

  TStaticInstructionEncoder.Encode(FEncoder, 'imul',

    [TOperand(Dest), TOperand(Src)]);

  Result := Self;

end;



function TAsmBuilder.Imul(Dest, Src: TRegister; Imm: Integer): TAsmBuilder;

begin

  TStaticInstructionEncoder.Encode(FEncoder, 'imul',

    [TOperand(Dest), TOperand(Src), TOperand(Int64(Imm))]);

  Result := Self;

end;



function TAsmBuilder.Mul(Src: TOperand): TAsmBuilder;

begin

  TStaticInstructionEncoder.Encode(FEncoder, 'mul', [Src]);

  Result := Self;

end;



function TAsmBuilder.Shl_(Dest: TOperand; Count: TOperand): TAsmBuilder;

begin

  TStaticInstructionEncoder.Encode(FEncoder, 'shl', [Dest, Count]);

  Result := Self;

end;



function TAsmBuilder.Shr_(Dest: TOperand; Count: TOperand): TAsmBuilder;

begin

  TStaticInstructionEncoder.Encode(FEncoder, 'shr', [Dest, Count]);

  Result := Self;

end;



function TAsmBuilder.Sar(Dest: TOperand; Count: TOperand): TAsmBuilder;

begin

  TStaticInstructionEncoder.Encode(FEncoder, 'sar', [Dest, Count]);

  Result := Self;

end;



function TAsmBuilder.Rol(Dest: TRegister; Count: Byte): TAsmBuilder;

begin

  TStaticInstructionEncoder.Encode(FEncoder, 'rol',

    [TOperand(Dest), TOperand(Int64(Count))]);

  Result := Self;

end;



function TAsmBuilder.Ror(Dest: TRegister; Count: Byte): TAsmBuilder;

begin

  TStaticInstructionEncoder.Encode(FEncoder, 'ror',

    [TOperand(Dest), TOperand(Int64(Count))]);

  Result := Self;

end;



function TAsmBuilder.Bsf(Dest, Src: TRegister): TAsmBuilder;

begin

  TStaticInstructionEncoder.Encode(FEncoder, 'bsf',

    [TOperand(Dest), TOperand(Src)]);

  Result := Self;

end;



function TAsmBuilder.Bsr(Dest, Src: TRegister): TAsmBuilder;

begin

  TStaticInstructionEncoder.Encode(FEncoder, 'bsr',

    [TOperand(Dest), TOperand(Src)]);

  Result := Self;

end;



function TAsmBuilder.Popcnt(Dest, Src: TRegister): TAsmBuilder;

begin

  TStaticInstructionEncoder.Encode(FEncoder, 'popcnt',

    [TOperand(Dest), TOperand(Src)]);

  Result := Self;

end;



function TAsmBuilder.Bswap(Reg: TRegister): TAsmBuilder;

begin

  TStaticInstructionEncoder.Encode(FEncoder, 'bswap', [TOperand(Reg)]);

  Result := Self;

end;



function TAsmBuilder.Xor_(Dest, Src: TOperand): TAsmBuilder;

begin

  TStaticInstructionEncoder.Encode(FEncoder, 'xor', [Dest, Src]);

  Result := Self;

end;



function TAsmBuilder.And_(Dest, Src: TOperand): TAsmBuilder;

begin

  TStaticInstructionEncoder.Encode(FEncoder, 'and', [Dest, Src]);

  Result := Self;

end;



function TAsmBuilder.Or_(Dest, Src: TOperand): TAsmBuilder;

begin

  TStaticInstructionEncoder.Encode(FEncoder, 'or', [Dest, Src]);

  Result := Self;

end;



function TAsmBuilder.Not_(Dest: TOperand): TAsmBuilder;

begin

  TStaticInstructionEncoder.Encode(FEncoder, 'not', [Dest]);

  Result := Self;

end;



function TAsmBuilder.Cmp(Dest, Src: TOperand): TAsmBuilder;

begin

  TStaticInstructionEncoder.Encode(FEncoder, 'cmp', [Dest, Src]);

  Result := Self;

end;



function TAsmBuilder.Test(Dest, Src: TOperand): TAsmBuilder;

begin

  // TEST has only the r/m,reg direction. The source marks it commutative, so

  // preserve the public Dest/Src spelling by swapping reg,mem here.

  if (Dest.Kind = otReg) and (Src.Kind = otMem) then

    TStaticInstructionEncoder.Encode(FEncoder, 'test', [Src, Dest])

  else

    TStaticInstructionEncoder.Encode(FEncoder, 'test', [Dest, Src]);

  Result := Self;

end;



function TAsmBuilder.Cmov(Cond: TCondition; Dest, Src: TRegister): TAsmBuilder;

begin

  if Cond = cond_JMP then

    raise EArgumentException.Create('Cmov: cond_JMP has no CMOVcc form');

  TStaticInstructionEncoder.Encode(FEncoder, 'cmov' + ConditionSuffix(Cond),

    [TOperand(Dest), TOperand(Src)]);

  Result := Self;

end;



function TAsmBuilder.Setcc(Cond: TCondition; Dest: TRegister): TAsmBuilder;

begin

  if Cond = cond_JMP then

    raise EArgumentException.Create('Setcc: cond_JMP has no SETcc form');

  TStaticInstructionEncoder.Encode(FEncoder, 'set' + ConditionSuffix(Cond),

    [TOperand(Dest)]);

  Result := Self;

end;



function TAsmBuilder.Push(Op: TOperand): TAsmBuilder;

begin

  TStaticInstructionEncoder.Encode(FEncoder, 'push', [Op]);

  Result := Self;

end;



function TAsmBuilder.Pop(Op: TOperand): TAsmBuilder;

begin

  TStaticInstructionEncoder.Encode(FEncoder, 'pop', [Op]);

  Result := Self;

end;



function TAsmBuilder.Call(Op: TOperand): TAsmBuilder;

begin

  TStaticInstructionEncoder.Encode(FEncoder, 'call', [Op]);

  Result := Self;

end;



function TAsmBuilder.Call(Addr: Pointer): TAsmBuilder;

begin

  // Load target into RAX (volatile scratch), then CALL RAX

  Mov(RAX, Int64(NativeUInt(Addr)));

  Call(TOperand(RAX));

  Result := Self;

end;



function TAsmBuilder.Ret: TAsmBuilder;

begin

  TStaticInstructionEncoder.Encode(FEncoder, 'ret', []);

  Result := Self;

end;



function TAsmBuilder.Ret(StackBytes: Word): TAsmBuilder;

begin

  TStaticInstructionEncoder.Encode(FEncoder, 'ret',

    [TOperand(Int64(StackBytes))]);

  Result := Self;

end;



function TAsmBuilder.Prolog(ShadowAndLocalBytes: Integer): TAsmBuilder;

begin

  if ShadowAndLocalBytes < 32 then

    raise Exception.CreateFmt(

      'Prolog: ShadowAndLocalBytes must be >= 32 (got %d)', [ShadowAndLocalBytes]);

  if (ShadowAndLocalBytes mod 16) <> 0 then

    raise Exception.CreateFmt(

      'Prolog: ShadowAndLocalBytes must be 16-byte aligned (got %d)', [ShadowAndLocalBytes]);



  Push(TOperand(RBP));

  Mov(TOperand(RBP), TOperand(RSP));

  Sub(TOperand(RSP), ShadowAndLocalBytes);

  Result := Self;

end;



function TAsmBuilder.Epilog: TAsmBuilder;

begin

  Mov(TOperand(RSP), TOperand(RBP));

  Pop(TOperand(RBP));

  Result := Self;

end;



// ---------------------------------------------------------------------------

// Fence / timing

// ---------------------------------------------------------------------------



function TAsmBuilder.Lfence: TAsmBuilder;

begin

  TStaticInstructionEncoder.Encode(FEncoder, 'lfence', []);

  Result := Self;

end;



function TAsmBuilder.Mfence: TAsmBuilder;

begin

  TStaticInstructionEncoder.Encode(FEncoder, 'mfence', []);

  Result := Self;

end;



function TAsmBuilder.Sfence: TAsmBuilder;

begin

  TStaticInstructionEncoder.Encode(FEncoder, 'sfence', []);

  Result := Self;

end;



function TAsmBuilder.Rdtsc: TAsmBuilder;

begin

  TStaticInstructionEncoder.Encode(FEncoder, 'rdtsc', []);

  Result := Self;

end;



function TAsmBuilder.Rdtscp: TAsmBuilder;

begin

  TStaticInstructionEncoder.Encode(FEncoder, 'rdtscp', []);

  Result := Self;

end;



function TAsmBuilder.Nop(Count: Integer): TAsmBuilder;

const

  // Intel-recommended multi-byte NOPs (Intel manual Vol.2 Table 4-12)

  // Each row is padded to 9 bytes; only the first [index] bytes are emitted.

  NopSeqs: array[1..9] of array[0..8] of Byte = (

    ($90, $00, $00, $00, $00, $00, $00, $00, $00),  // 1: NOP

    ($66, $90, $00, $00, $00, $00, $00, $00, $00),  // 2: 66 NOP

    ($0F, $1F, $00, $00, $00, $00, $00, $00, $00),  // 3: NOP [rax]

    ($0F, $1F, $40, $00, $00, $00, $00, $00, $00),  // 4: NOP [rax+00]

    ($0F, $1F, $44, $00, $00, $00, $00, $00, $00),  // 5: NOP [rax+rax+00]

    ($66, $0F, $1F, $44, $00, $00, $00, $00, $00),  // 6: 66 NOP [rax+rax+00]

    ($0F, $1F, $80, $00, $00, $00, $00, $00, $00),  // 7: NOP [rax+00000000]

    ($0F, $1F, $84, $00, $00, $00, $00, $00, $00),  // 8: NOP [rax+rax+00000000]

    ($66, $0F, $1F, $84, $00, $00, $00, $00, $00)   // 9: 66 NOP [rax+rax+00000000]

  );

var

  I, Chunk, K: Integer;

begin

  if Count < 1 then begin Result := Self; Exit; end;

  I := Count;

  while I > 0 do

  begin

    Chunk := I;

    if Chunk > 9 then Chunk := 9;

    for K := 0 to Chunk - 1 do

      FEncoder.EmitRaw(NopSeqs[Chunk][K]);

    Dec(I, Chunk);

  end;

  Result := Self;

end;



function TAsmBuilder.Int3: TAsmBuilder;

begin

  TStaticInstructionEncoder.Encode(FEncoder, 'int3', []);

  Result := Self;

end;



function TAsmBuilder.Ud2: TAsmBuilder;

begin

  TStaticInstructionEncoder.Encode(FEncoder, 'ud2', []);

  Result := Self;

end;



function TAsmBuilder.Build: TBytes;

var

  Raw: TBytes;

begin

  Raw := FEncoder.GetCode;

  PatchLabels(Raw);

  Result := Raw;

end;



// ---------------------------------------------------------------------------

// Run helpers — allocate RX memory, execute, free

// ---------------------------------------------------------------------------



function TAsmBuilder.InternalRun(const Code: TBytes;

  const Args: array of UInt64): UInt64;

var

  Mem        : Pointer;

  OldProtect : Cardinal;

  Fn0 : TAsmFunc0;

  Fn1 : TAsmFunc1;

  Fn2 : TAsmFunc2;

  Fn3 : TAsmFunc3;

  Fn4 : TAsmFunc4;

begin

  Result := 0;

  if Length(Code) = 0 then Exit;



  Mem := VirtualAlloc(nil, Length(Code),

           MEM_COMMIT or MEM_RESERVE, PAGE_READWRITE);

  if Mem = nil then RaiseLastOSError;

  try

    Move(Code[0], Mem^, Length(Code));

    if not VirtualProtect(Mem, Length(Code), PAGE_EXECUTE_READ, OldProtect) then

      RaiseLastOSError;

    FlushInstructionCache(GetCurrentProcess, Mem, Length(Code));



    case Length(Args) of

      0: begin Fn0 := Mem; Result := Fn0(); end;

      1: begin Fn1 := Mem; Result := Fn1(Args[0]); end;

      2: begin Fn2 := Mem; Result := Fn2(Args[0], Args[1]); end;

      3: begin Fn3 := Mem; Result := Fn3(Args[0], Args[1], Args[2]); end;

      4: begin Fn4 := Mem; Result := Fn4(Args[0], Args[1], Args[2], Args[3]); end;

    else

      raise Exception.Create('Run: a maximum of 4 arguments is supported');

    end;

  finally

    VirtualFree(Mem, 0, MEM_RELEASE);

  end;

end;



function TAsmBuilder.Run: UInt64;

begin

  Result := InternalRun(Build, []);

end;



function TAsmBuilder.Run(Arg1: UInt64): UInt64;

begin

  Result := InternalRun(Build, [Arg1]);

end;



function TAsmBuilder.Run(Arg1, Arg2: UInt64): UInt64;

begin

  Result := InternalRun(Build, [Arg1, Arg2]);

end;



function TAsmBuilder.Run(Arg1, Arg2, Arg3: UInt64): UInt64;

begin

  Result := InternalRun(Build, [Arg1, Arg2, Arg3]);

end;



function TAsmBuilder.Run(Arg1, Arg2, Arg3, Arg4: UInt64): UInt64;

begin

  Result := InternalRun(Build, [Arg1, Arg2, Arg3, Arg4]);

end;



end.

