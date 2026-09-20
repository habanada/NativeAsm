unit NativeAsm.InstructionDB;

{
  NativeAsm x64 JIT Builder - Static Instruction Descriptor Database
  ====================================================================

  Runtime design
  --------------
  * No JSON parser is used by the JIT/runtime.
  * Tools/Generate-InstructionDb.ps1 reads AsmJit's isa_x86.json at development
    time and emits NativeAsm.InstructionDB.Generated.pas.
  * The generated table contains only the deliberately selected legacy x64
    GP/control-flow/fence/timing/debug subset.
  * Unsupported APX/VEX/EVEX/REX2 forms are excluded by the generator.
  * Unknown selected encoding tokens are fatal to generation (fail closed).

  The descriptor layer preserves source facts separately from NativeAsm
  support/canonicalization. NativeSupport is per form, never per mnemonic.
}

{$ALIGN ON}
{$MINENUMSIZE 4}

interface

uses
  System.SysUtils,
  NativeAsm.Types;

type
  TSourceArch = (
    saAny,
    saX64
  );

  TEncodingForm = (
    efNone,
    efMR,
    efRM,
    efM,
    efOP,
    efOther
  );

  TOpcodeMap = (
    omPrimary,
    om0F,
    om0F38,
    om0F3A
  );

  TMandatoryPrefix = (
    mpNone,
    mpNP,
    mp66,
    mpF2,
    mpF3
  );

  TRexWPolicy = (
    rwNever,
    rwByResolvedGpWidth,
    rwForce
  );

  TLegacy66Policy = (
    p66Never,
    p66ByResolvedGpWidth,
    p66ForceOperandSize,
    p66MandatoryOpcode
  );

  TModRMKind = (
    mkNone,
    mkFromOperands,
    mkFixedRegField,
    mkIgnoredRegCanonicalZero,
    mkFixedByte
  );

  TDbFixupKind = (
    dfkNone,
    dfkRelative8,
    dfkRelative32
  );

  TOperandAccess = (
    oaNone,
    oaRead,
    oaWrite,
    oaWritePartial,
    oaReadWrite,
    oaReadWritePartial
  );

  TDbRegClass = (
    rcNone,
    rcGp8Any,
    rcGp8Lo,
    rcGp8Hi,
    rcGp16,
    rcGp32,
    rcGp64
  );

  TDbMemClass = (
    mcNone,
    mcUnspecified,
    mc8,
    mc16,
    mc32,
    mc64
  );

  TImmKind = (
    ikNone,
    ikRaw8,
    ikSigned8,
    ikUnsigned8,
    ikRaw16,
    ikUnsigned16,
    ikRaw32,
    ikSigned32,
    ikUnsigned32,
    ikRaw64
  );

  TNativeSupport = (
    nsSourceOnly,
    nsPartial,
    nsSupported
  );

  TNativeRestriction = (
    nrNone,
    nrMemorySourceOnly,
    nrRegisterSourceOnly,
    nrRegisterDestinationOnly,
    nrNoMemoryImmediate,
    nrSignedImm32For64Bit,
    nrBswap64Only,
    nrNativeConditionSubset,
    nrNoRelative8Fixup,
    nrNoIndirectJmpApi,
    nrNoSyscallBuilderApi,
    nrRotateRegisterImmediateOnly,
    nrShiftCount0To63,
    nrExplicitMemorySizeRequired,
    nrStackMemory64OrUnspecified,
    nrNotExposed
  );

  TNativeCanonicalization = (
    ncNone,
    ncLea16Uses66,
    ncSetccRegFieldZero,
    ncPushImmediateShortest,
    ncNativeMultiByteNop
  );

const
  // TDbOperandSpec.Kinds bits.
  DB_OK_REG = $01;
  DB_OK_MEM = $02;
  DB_OK_IMM = $04;
  DB_OK_REL = $08;

  // TDbOperandSpec.Flags bits.
  DB_OF_COMMUTATIVE        = $01;
  DB_OF_CONDITIONAL_ACCESS = $02;

  // TDbOperandSpec.FixedFlags bits.
  DB_FO_HAS_REG      = $01;
  DB_FO_IS_IMPLICIT  = $02;
  DB_FO_HAS_IMMEDIATE= $04;

  // CategoryMask bits. category and extension deliberately remain independent.
  DB_CAT_GP     = $0001;
  DB_CAT_GP_EXT = $0002;

  // ExtensionMask bits.
  DB_EXT_CMOV   = $0001;
  DB_EXT_POPCNT = $0002;
  DB_EXT_RDTSC  = $0004;
  DB_EXT_RDTSCP = $0008;
  DB_EXT_SSE    = $0010;
  DB_EXT_SSE2   = $0020;

  // AllowedOptionsMask bits.
  DB_AO_LOCK       = $0001;
  DB_AO_REP        = $0002;
  DB_AO_REPNE      = $0004;
  DB_AO_REP_IGNORE = $0008;
  DB_AO_XACQUIRE   = $0010;
  DB_AO_XRELEASE   = $0020;
  DB_AO_BND        = $0040;
  DB_AO_ILOCK      = $0080;

type
  /// <summary>
  /// Concrete operand specification. Grouped AsmJit rv/ry/mv/my/immv forms
  /// are expanded by the generator before reaching this table.
  /// </summary>
  TDbOperandSpec = record
    Kinds         : Byte;
    RegClass      : TDbRegClass;
    MemClass      : TDbMemClass;
    RawAccess     : TOperandAccess;
    ExpandedAccess: TOperandAccess;
    Flags         : Byte;

    FixedFlags    : Byte;
    FixedRegID    : Byte;      // ordinal TRegID; only valid with DB_FO_HAS_REG
    FixedRegType  : TRegType;
    FixedImm      : Int64;     // only valid with DB_FO_HAS_IMMEDIATE

    ImmKind       : TImmKind;
    RelBytes      : Byte;
  end;
  PDbOperandSpec = ^TDbOperandSpec;

  /// <summary>
  /// Fully static, normalized encoding descriptor. String diagnostics are held
  /// in parallel generated arrays to keep the hot descriptor record compact.
  /// </summary>
  TEncodingDescriptor = record
    MnemonicIndex          : Word;
    SourceRecordIndex      : Word;
    SourceArch             : TSourceArch;
    CategoryMask           : Word;
    ExtensionMask          : Word;
    AllowedOptionsMask     : Word;
    SourceTag              : TEncodingForm;
    SourceAlt              : Boolean;
    ExpandedWidth          : Byte;  // 0, 16, 32, 64

    OpcodeMap              : TOpcodeMap;
    Opcode                 : Byte;
    OpcodePlusReg          : Boolean;
    MandatoryPrefix        : TMandatoryPrefix;
    Raw66                  : Boolean;
    Raw67                  : Boolean;
    RexWPolicy             : TRexWPolicy;
    Legacy66Policy         : TLegacy66Policy;

    ModRMKind              : TModRMKind;
    ModRegOperandIdx       : ShortInt;
    ModRmOperandIdx        : ShortInt;
    FixedRegValue          : Byte;
    FixedModRMByte         : Byte;
    OpcodeRegOperandIdx    : ShortInt;

    ImmediateOperandIdx    : ShortInt;
    ImmKind                : TImmKind;
    ImmediateBytes         : Byte;
    HasFixup               : Boolean;
    FixupKind              : TDbFixupKind;
    FixupOperandIdx        : ShortInt;

    OperandStart           : Word;
    OperandCount           : Byte;

    NativeSupport          : TNativeSupport;
    NativeRestriction      : TNativeRestriction;
    NativeCanonicalization : TNativeCanonicalization;
  end;
  PEncodingDescriptor = ^TEncodingDescriptor;

  TInstructionDb = class sealed
  public
    class function SourceSha256: string; static;
    class function FormCount: Integer; static;
    class function MnemonicCount: Integer; static;
    class function MnemonicName(MnemonicIndex: Integer): string; static;
    class function MnemonicIndexOf(const Mnemonic: string): Integer; static;
    class function MnemonicFormCount(MnemonicIndex: Integer): Integer; static;
    class function MnemonicFormIndex(MnemonicIndex, Position: Integer): Integer; static;
    class function SourceSignature(FormIndex: Integer): string; static;
    class function SourceEncoding(FormIndex: Integer): string; static;
    class function Form(FormIndex: Integer): PEncodingDescriptor; static;
    class function Operand(FormIndex, OperandIndex: Integer): PDbOperandSpec; static;
    class function FindFirst(const Mnemonic: string; out FormIndex: Integer): Boolean; static;
    class function FindNext(const Mnemonic: string; var FormIndex: Integer): Boolean; static;
    class procedure ValidateGeneratedDb; static;
  end;

implementation

uses
  NativeAsm.InstructionDB.Generated;

class function TInstructionDb.SourceSha256: string;
begin
  Result := CInstructionDbSourceSha256;
end;

class function TInstructionDb.FormCount: Integer;
begin
  Result := CInstructionFormCount;
end;

class function TInstructionDb.MnemonicCount: Integer;
begin
  Result := CInstructionMnemonicCount;
end;

class function TInstructionDb.MnemonicName(MnemonicIndex: Integer): string;
begin
  if (MnemonicIndex < 0) or (MnemonicIndex >= CInstructionMnemonicCount) then
    raise EArgumentOutOfRangeException.CreateFmt(
      'Instruction DB mnemonic index %d is out of range', [MnemonicIndex]);
  Result := CInstructionMnemonicNames[MnemonicIndex];
end;

class function TInstructionDb.MnemonicIndexOf(const Mnemonic: string): Integer;
var
  Lo, Hi, Mid, C: Integer;
begin
  Lo := 0;
  Hi := CInstructionMnemonicCount - 1;
  while Lo <= Hi do
  begin
    Mid := Lo + ((Hi - Lo) shr 1);
    C := CompareText(CInstructionMnemonicNames[Mid], Mnemonic);
    if C = 0 then Exit(Mid);
    if C < 0 then Lo := Mid + 1 else Hi := Mid - 1;
  end;
  Result := -1;
end;

class function TInstructionDb.MnemonicFormCount(MnemonicIndex: Integer): Integer;
begin
  if (MnemonicIndex < 0) or (MnemonicIndex >= CInstructionMnemonicCount) then
    raise EArgumentOutOfRangeException.CreateFmt(
      'Instruction DB mnemonic index %d is out of range', [MnemonicIndex]);
  Result := CInstructionMnemonicFormCount[MnemonicIndex];
end;

class function TInstructionDb.MnemonicFormIndex(MnemonicIndex,
  Position: Integer): Integer;
var
  Start, Count: Integer;
begin
  if (MnemonicIndex < 0) or (MnemonicIndex >= CInstructionMnemonicCount) then
    raise EArgumentOutOfRangeException.CreateFmt(
      'Instruction DB mnemonic index %d is out of range', [MnemonicIndex]);
  Start := CInstructionMnemonicFormStart[MnemonicIndex];
  Count := CInstructionMnemonicFormCount[MnemonicIndex];
  if (Position < 0) or (Position >= Count) then
    raise EArgumentOutOfRangeException.CreateFmt(
      'Instruction DB form position %d is out of range for mnemonic %d',
      [Position, MnemonicIndex]);
  Result := CInstructionFormOrder[Start + Position];
end;

class function TInstructionDb.SourceSignature(FormIndex: Integer): string;
begin
  if (FormIndex < 0) or (FormIndex >= CInstructionFormCount) then
    raise EArgumentOutOfRangeException.CreateFmt(
      'Instruction DB form index %d is out of range', [FormIndex]);
  Result := CInstructionSourceSignatures[FormIndex];
end;

class function TInstructionDb.SourceEncoding(FormIndex: Integer): string;
begin
  if (FormIndex < 0) or (FormIndex >= CInstructionFormCount) then
    raise EArgumentOutOfRangeException.CreateFmt(
      'Instruction DB form index %d is out of range', [FormIndex]);
  Result := CInstructionSourceOps[FormIndex];
end;

class function TInstructionDb.Form(FormIndex: Integer): PEncodingDescriptor;
begin
  if (FormIndex < 0) or (FormIndex >= CInstructionFormCount) then
    raise EArgumentOutOfRangeException.CreateFmt(
      'Instruction DB form index %d is out of range', [FormIndex]);
  Result := @CInstructionForms[FormIndex];
end;

class function TInstructionDb.Operand(FormIndex, OperandIndex: Integer): PDbOperandSpec;
var
  D: PEncodingDescriptor;
  I: Integer;
begin
  D := Form(FormIndex);
  if (OperandIndex < 0) or (OperandIndex >= D^.OperandCount) then
    raise EArgumentOutOfRangeException.CreateFmt(
      'Instruction DB operand index %d is out of range for form %d',
      [OperandIndex, FormIndex]);
  I := D^.OperandStart + OperandIndex;
  Result := @CInstructionOperands[I];
end;

class function TInstructionDb.FindFirst(const Mnemonic: string;
  out FormIndex: Integer): Boolean;
var
  M: Integer;
begin
  M := MnemonicIndexOf(Mnemonic);
  if (M < 0) or (CInstructionMnemonicFormCount[M] = 0) then
  begin
    FormIndex := -1;
    Exit(False);
  end;
  FormIndex := CInstructionFormOrder[CInstructionMnemonicFormStart[M]];
  Result := True;
end;

class function TInstructionDb.FindNext(const Mnemonic: string;
  var FormIndex: Integer): Boolean;
var
  M, P, Start, Count: Integer;
begin
  M := MnemonicIndexOf(Mnemonic);
  if M < 0 then
  begin
    FormIndex := -1;
    Exit(False);
  end;
  Start := CInstructionMnemonicFormStart[M];
  Count := CInstructionMnemonicFormCount[M];
  for P := 0 to Count - 2 do
    if CInstructionFormOrder[Start + P] = FormIndex then
    begin
      FormIndex := CInstructionFormOrder[Start + P + 1];
      Exit(True);
    end;
  FormIndex := -1;
  Result := False;
end;

class procedure TInstructionDb.ValidateGeneratedDb;
var
  I, J, EndOperand: Integer;
  D: PEncodingDescriptor;
begin
  // CInstructionFormCount and CInstructionMnemonicCount are compile-time
  // constants; a <= 0 check would always be false.  The loop bounds below
  // already cover the empty-table case by iterating zero times.

  for I := 0 to CInstructionMnemonicCount - 1 do
  begin
    if CInstructionMnemonicFormStart[I] + CInstructionMnemonicFormCount[I] >
       CInstructionFormCount then
      raise EInvalidOpException.CreateFmt(
        'Instruction DB mnemonic %d form range is out of bounds', [I]);
    for J := 0 to CInstructionMnemonicFormCount[I] - 1 do
      if CInstructionForms[CInstructionFormOrder[
           CInstructionMnemonicFormStart[I] + J]].MnemonicIndex <> I then
        raise EInvalidOpException.CreateFmt(
          'Instruction DB mnemonic %d index table points to the wrong form', [I]);
  end;

  for I := 0 to CInstructionFormCount - 1 do
  begin
    D := @CInstructionForms[I];
    if D^.MnemonicIndex >= CInstructionMnemonicCount then
      raise EInvalidOpException.CreateFmt(
        'Instruction DB form %d has invalid MnemonicIndex %d', [I, D^.MnemonicIndex]);

    EndOperand := D^.OperandStart + D^.OperandCount;
    if EndOperand > CInstructionOperandCount then
      raise EInvalidOpException.CreateFmt(
        'Instruction DB form %d operand span [%d..%d) is out of range',
        [I, D^.OperandStart, EndOperand]);

    // Index fields use ShortInt; -1 is the sentinel "not bound".
    // Only validate indices that are actually bound (>= 0).
    if ((D^.ModRegOperandIdx       >= 0) and (Integer(D^.ModRegOperandIdx)       >= Integer(D^.OperandCount))) or
       ((D^.ModRmOperandIdx        >= 0) and (Integer(D^.ModRmOperandIdx)        >= Integer(D^.OperandCount))) or
       ((D^.OpcodeRegOperandIdx    >= 0) and (Integer(D^.OpcodeRegOperandIdx)    >= Integer(D^.OperandCount))) or
       ((D^.ImmediateOperandIdx    >= 0) and (Integer(D^.ImmediateOperandIdx)    >= Integer(D^.OperandCount))) or
       ((D^.FixupOperandIdx        >= 0) and (Integer(D^.FixupOperandIdx)        >= Integer(D^.OperandCount))) then
      raise EInvalidOpException.CreateFmt(
        'Instruction DB form %d contains an invalid operand binding', [I]);

    if D^.HasFixup and (D^.FixupKind = dfkNone) then
      raise EInvalidOpException.CreateFmt(
        'Instruction DB form %d has HasFixup but no FixupKind', [I]);
    if (not D^.HasFixup) and (D^.FixupKind <> dfkNone) then
      raise EInvalidOpException.CreateFmt(
        'Instruction DB form %d has FixupKind without HasFixup', [I]);

    for J := 0 to D^.OperandCount - 1 do
      if CInstructionOperands[D^.OperandStart + J].Kinds = 0 then
        raise EInvalidOpException.CreateFmt(
          'Instruction DB form %d operand %d has no accepted operand kind', [I, J]);
  end;
end;

end.
