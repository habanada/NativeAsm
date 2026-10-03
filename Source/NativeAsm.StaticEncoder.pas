{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
unit NativeAsm.StaticEncoder;

{
  NativeAsm x64 JIT Builder - Descriptor-Driven Encoder
  ========================================================

  This unit is the runtime half of the AsmJit-JSON -> generated Pascal table
  pipeline. It never parses JSON or compact opcode strings. It selects a fully
  normalized TEncodingDescriptor and emits bytes through TEncoderX64.

  Selection is deliberately conservative:
  * nsSourceOnly forms are never selected by the current NativeAsm API path.
  * NativeRestriction is enforced per concrete form.
  * unsized memory is accepted only when another operand/form makes width
    unambiguous; unary/immediate-only operations require explicit size.
  * immediate ranges are semantic, not truncating casts.
  * High-8 + any required REX remains centrally rejected by TEncoderX64.
}

{$ALIGN ON}
{$MINENUMSIZE 4}

interface

uses
  System.SysUtils,
  NativeAsm.Types,
  NativeAsm.Encoder,
  NativeAsm.InstructionDB;

type
  TStaticInstructionEncoder = class sealed
  private type
    TOperandMap = array[0..7] of ShortInt;
  private
    class function RegClassMatches(RegClass: TDbRegClass;
      const Reg: TRegister): Boolean; static;
    class function MemClassMatches(MemClass: TDbMemClass;
      const Mem: TMemory): Boolean; static;
    class function ImmKindMatches(Kind: TImmKind; Value: Int64): Boolean; static;
    class function MatchOperand(const Spec: TDbOperandSpec;
      const Op: TOperand): Boolean; static;
    class function BuildOperandMap(FormIndex: Integer;
      const Operands: array of TOperand; out Map: TOperandMap): Boolean; static;
    class function CheckNativeRestriction(FormIndex: Integer;
      const Operands: array of TOperand; const Map: TOperandMap): Boolean; static;
    class function ScoreForm(FormIndex: Integer;
      const Operands: array of TOperand; const Map: TOperandMap): Integer; static;
    class function ActualOperandIndex(FormIndex, SourceOperandIndex: Integer;
      const Map: TOperandMap): Integer; static;
    class procedure EmitPrefixes(Encoder: TEncoderX64;
      const D: TEncodingDescriptor); static;
    class procedure EmitRex(Encoder: TEncoderX64; FormIndex: Integer;
      const Operands: array of TOperand; const Map: TOperandMap); static;
    class procedure EmitOpcodeMap(Encoder: TEncoderX64;
      OpcodeMap: TOpcodeMap); static;
    class procedure EmitImmediate(Encoder: TEncoderX64; FormIndex: Integer;
      const Operands: array of TOperand; const Map: TOperandMap); static;
    class procedure EmitSelected(Encoder: TEncoderX64; FormIndex: Integer;
      const Operands: array of TOperand; const Map: TOperandMap); static;
  public
    /// <summary>
    /// Select and emit one non-relative instruction form. Returns the selected
    /// generated form index for diagnostics/tests.
    /// </summary>
    class function Encode(Encoder: TEncoderX64; const Mnemonic: string;
      const Operands: array of TOperand): Integer; static;

    /// <summary>Select the best current-Native form without emitting bytes.</summary>
    class function SelectForm(const Mnemonic: string;
      const Operands: array of TOperand): Integer; static;

    /// <summary>
    /// Emit only a rel32 branch/call opcode plus a four-byte zero placeholder.
    /// Builder label fixups patch that placeholder later.
    /// </summary>
    class function EmitRelative32Placeholder(Encoder: TEncoderX64;
      const Mnemonic: string; out PlaceholderOffset: Integer): Integer; static;
  end;

implementation

uses
  NativeAsm.Rules;

class function TStaticInstructionEncoder.RegClassMatches(RegClass: TDbRegClass;
  const Reg: TRegister): Boolean;
begin
  case RegClass of
    rcNone:   Result := False;
    rcGp8Any: Result := Reg.RegType in [rt8, rt8High];
    rcGp8Lo:  Result := Reg.RegType = rt8;
    rcGp8Hi:  Result := Reg.RegType = rt8High;
    rcGp16:   Result := Reg.RegType = rt16;
    rcGp32:   Result := Reg.RegType = rt32;
    rcGp64:   Result := Reg.RegType = rt64;
  else
    Result := False;
  end;
end;

class function TStaticInstructionEncoder.MemClassMatches(MemClass: TDbMemClass;
  const Mem: TMemory): Boolean;
begin
  case MemClass of
    mcNone:
      Result := False;
    mcUnspecified:
      // AsmJit 'mem' means address-only memory where data width is not part of
      // the operand signature (LEA is the current relevant example).
      Result := True;
    mc8:
      Result := (Mem.Size = sz8) or (Mem.Size = szUnspecified);
    mc16:
      Result := (Mem.Size = sz16) or (Mem.Size = szUnspecified);
    mc32:
      Result := (Mem.Size = sz32) or (Mem.Size = szUnspecified);
    mc64:
      Result := (Mem.Size = sz64) or (Mem.Size = szUnspecified);
  else
    Result := False;
  end;
end;

class function TStaticInstructionEncoder.ImmKindMatches(Kind: TImmKind;
  Value: Int64): Boolean;
begin
  case Kind of
    ikNone:       Result := False;
    ikRaw8:       Result := (Value >= -128) and (Value <= 255);
    ikSigned8:    Result := (Value >= -128) and (Value <= 127);
    ikUnsigned8:  Result := (Value >= 0) and (Value <= 255);
    ikRaw16:      Result := (Value >= -32768) and (Value <= 65535);
    ikUnsigned16: Result := (Value >= 0) and (Value <= 65535);
    ikRaw32:      Result := (Value >= Low(Integer)) and (Value <= Int64($FFFFFFFF));
    ikSigned32:   Result := (Value >= Low(Integer)) and (Value <= High(Integer));
    ikUnsigned32: Result := (Value >= 0) and (Value <= Int64($FFFFFFFF));
    ikRaw64:      Result := True;
  else
    Result := False;
  end;
end;

class function TStaticInstructionEncoder.MatchOperand(const Spec: TDbOperandSpec;
  const Op: TOperand): Boolean;
begin
  Result := False;
  case Op.Kind of
    otReg:
    begin
      if (Spec.Kinds and DB_OK_REG) = 0 then Exit;
      if (Spec.FixedFlags and DB_FO_HAS_REG) <> 0 then
        Exit((Ord(Op.Reg.ID) = Integer(Spec.FixedRegID)) and
             (Op.Reg.RegType = Spec.FixedRegType));
      Result := RegClassMatches(Spec.RegClass, Op.Reg);
    end;

    otMem:
    begin
      if (Spec.Kinds and DB_OK_MEM) = 0 then Exit;
      Result := MemClassMatches(Spec.MemClass, Op.Mem);
    end;

    otImm:
    begin
      if (Spec.Kinds and DB_OK_IMM) = 0 then Exit;
      if (Spec.FixedFlags and DB_FO_HAS_IMMEDIATE) <> 0 then
        Exit(Op.Imm = Spec.FixedImm);
      Result := ImmKindMatches(Spec.ImmKind, Op.Imm);
    end;
  else
    Result := False;
  end;
end;

class function TStaticInstructionEncoder.BuildOperandMap(FormIndex: Integer;
  const Operands: array of TOperand; out Map: TOperandMap): Boolean;
var
  D: PEncodingDescriptor;
  Spec: PDbOperandSpec;
  SourceIndex, ActualIndex, I: Integer;
begin
  for I := Low(Map) to High(Map) do
    Map[I] := -1;

  D := TInstructionDb.Form(FormIndex);
  if D^.OperandCount > Length(Map) then
    Exit(False);

  ActualIndex := 0;
  for SourceIndex := 0 to D^.OperandCount - 1 do
  begin
    Spec := TInstructionDb.Operand(FormIndex, SourceIndex);
    if (Spec^.FixedFlags and DB_FO_IS_IMPLICIT) <> 0 then
      Continue;

    if ActualIndex >= Length(Operands) then
      Exit(False);
    if not MatchOperand(Spec^, Operands[ActualIndex]) then
      Exit(False);

    Map[SourceIndex] := ActualIndex;
    Inc(ActualIndex);
  end;

  Result := ActualIndex = Length(Operands);
end;

class function TStaticInstructionEncoder.ActualOperandIndex(FormIndex,
  SourceOperandIndex: Integer; const Map: TOperandMap): Integer;
var
  D: PEncodingDescriptor;
begin
  D := TInstructionDb.Form(FormIndex);
  if (SourceOperandIndex < 0) or (SourceOperandIndex >= D^.OperandCount) then
    Exit(-1);
  Result := Map[SourceOperandIndex];
end;

class function TStaticInstructionEncoder.CheckNativeRestriction(FormIndex: Integer;
  const Operands: array of TOperand; const Map: TOperandMap): Boolean;
var
  D: PEncodingDescriptor;
  I: Integer;
  Spec: PDbOperandSpec;
  HasMem, HasImm, HasUnspecifiedMem, HasMem64Class: Boolean;
  ImmValue: Int64;
begin
  D := TInstructionDb.Form(FormIndex);
  if D^.NativeSupport = nsSourceOnly then
    Exit(False);

  HasMem := False;
  HasImm := False;
  HasUnspecifiedMem := False;
  ImmValue := 0;
  for I := 0 to High(Operands) do
  begin
    if Operands[I].Kind = otMem then
    begin
      HasMem := True;
      HasUnspecifiedMem := HasUnspecifiedMem or
        (Operands[I].Mem.Size = szUnspecified);
    end
    else if Operands[I].Kind = otImm then
    begin
      HasImm := True;
      ImmValue := Operands[I].Imm;
    end;
  end;

  if D^.SourceAlt and (D^.ModRMKind = mkNone) and (not D^.OpcodePlusReg) and
     (D^.ExpandedWidth = 0) and HasImm and
     (Length(Operands) > 0) and (Operands[0].Kind = otReg) then
    Exit(False);

  case D^.NativeRestriction of
    nrNone:
      Result := True;

    nrMemorySourceOnly:
      Result := (Length(Operands) >= 2) and (Operands[1].Kind = otMem);

    nrRegisterSourceOnly:
      Result := (Length(Operands) >= 2) and (Operands[1].Kind = otReg);

    nrRegisterDestinationOnly:
      Result := (Length(Operands) >= 1) and (Operands[0].Kind = otReg);

    nrNoMemoryImmediate:
      Result := not ((Length(Operands) >= 1) and
                     (Operands[0].Kind = otMem) and HasImm);

    nrSignedImm32For64Bit:
    begin
      // The current Builder deliberately requires an explicit memory width for
      // immediate-only memory operations.  Do not let an m64 descriptor turn an
      // unsized memory operand into an implicit qword operation.
      Result := (not HasUnspecifiedMem) and
        ((not HasImm) or
         ((ImmValue >= Low(Integer)) and (ImmValue <= High(Integer))));
    end;

    nrBswap64Only:
      Result := (Length(Operands) = 1) and (Operands[0].Kind = otReg) and
                (Operands[0].Reg.RegType = rt64);

    nrNativeConditionSubset:
      // Public TCondition performs the 10-condition restriction before this
      // path. Descriptor-level rel32 encoding itself is valid.
      Result := True;

    nrNoRelative8Fixup,
    nrNoIndirectJmpApi,
    nrNoSyscallBuilderApi,
    nrNotExposed:
      Result := False;

    nrRotateRegisterImmediateOnly:
      Result := (Length(Operands) = 2) and
                (Operands[0].Kind = otReg) and
                (Operands[1].Kind = otImm) and
                (Operands[1].Imm >= 0) and (Operands[1].Imm <= 63);

    nrShiftCount0To63:
    begin
      Result := (Length(Operands) = 2) and (not HasUnspecifiedMem);
      if not Result then Exit;
      if Operands[1].Kind = otImm then
        Result := (Operands[1].Imm >= 0) and (Operands[1].Imm <= 63)
      else if Operands[1].Kind = otReg then
        Result := (Operands[1].Reg.ID = ridRCX) and
                  (Operands[1].Reg.RegType = rt8)
      else
        Result := False;
    end;

    nrExplicitMemorySizeRequired:
      Result := not HasUnspecifiedMem;

    nrStackMemory64OrUnspecified:
    begin
      // Existing NativeAsm Push/Pop memory API is qword-only. Source imm16
      // and r16/m16 records are preserved but not selected for this API path.
      HasMem64Class := False;
      for I := 0 to D^.OperandCount - 1 do
      begin
        Spec := TInstructionDb.Operand(FormIndex, I);
        HasMem64Class := HasMem64Class or (Spec^.MemClass = mc64);
      end;
      Result := HasMem64Class and HasMem;
      if Result then
        for I := 0 to High(Operands) do
          if Operands[I].Kind = otMem then
            Result := Result and (Operands[I].Mem.Size in [sz64, szUnspecified]);
    end;
  else
    Result := False;
  end;

  // Native numeric PUSH canonicalization: 6A is selected only for signed
  // -128..127 even though the raw DB operand token is imm8.
  if Result and (D^.NativeCanonicalization = ncPushImmediateShortest) and
     HasImm and (D^.ImmediateBytes = 1) then
    Result := (ImmValue >= -128) and (ImmValue <= 127);
end;

class function TStaticInstructionEncoder.ScoreForm(FormIndex: Integer;
  const Operands: array of TOperand; const Map: TOperandMap): Integer;
var
  D: PEncodingDescriptor;
  I, ActualIndex, EncLen: Integer;
  Spec: PDbOperandSpec;
  Need66, NeedRex: Boolean;
begin
  D := TInstructionDb.Form(FormIndex);

  // Canonical selection is length-first. AsmJit's `alt:true` means
  // "alternative form", not "always prefer this form". In particular an
  // accumulator immediate opcode can be longer than 83 /n ib for small
  // immediates. Estimate the fixed portion of the instruction here; memory
  // SIB/displacement bytes are equal between competing forms in this subset.
  EncLen := 1 + D^.ImmediateBytes; // final opcode + immediate
  case D^.OpcodeMap of
    om0F:   Inc(EncLen, 1);
    om0F38,
    om0F3A: Inc(EncLen, 2);
  end;
  if D^.ModRMKind <> mkNone then
    Inc(EncLen);

  if D^.MandatoryPrefix in [mpF2, mpF3] then
    Inc(EncLen);
  Need66 := D^.Raw66 or
            (D^.MandatoryPrefix = mp66) or
            (D^.Legacy66Policy = p66ForceOperandSize) or
            (D^.Legacy66Policy = p66MandatoryOpcode) or
            ((D^.Legacy66Policy = p66ByResolvedGpWidth) and
             (D^.ExpandedWidth = 16)) or
            (D^.NativeCanonicalization = ncLea16Uses66);
  if Need66 then Inc(EncLen);
  if D^.Raw67 and (D^.NativeCanonicalization <> ncLea16Uses66) then
    Inc(EncLen);

  NeedRex := (D^.RexWPolicy = rwForce) or
             ((D^.RexWPolicy = rwByResolvedGpWidth) and
              (D^.ExpandedWidth = 64));
  // Extended/new-low-byte registers and extended memory addressing require a
  // REX byte even when W=0. This is used only for length ranking; the actual
  // legality check remains centralized in TEncoderX64.EmitRex.
  for I := 0 to High(Operands) do
    case Operands[I].Kind of
      otReg:
        NeedRex := NeedRex or Operands[I].Reg.NeedsRex;
      otMem:
        if not Operands[I].Mem.IsRipRelative then
          NeedRex := NeedRex or (Operands[I].Mem.Base >= ridR8) or
            (Operands[I].Mem.HasIndex and (Operands[I].Mem.Index >= ridR8));
    end;
  if NeedRex then Inc(EncLen);

  Result := 1000 - (EncLen * 16);

  // Tie breakers only; none may beat a one-byte shorter encoding.
  if D^.NativeSupport = nsSupported then Inc(Result, 2)
  else if D^.NativeSupport = nsPartial then Inc(Result);
  if D^.SourceAlt then Inc(Result);

  if Length(Operands) > 0 then
  begin
    if Operands[0].Kind = otReg then
    begin
      if D^.SourceTag = efRM then Inc(Result, 2)
      else if D^.SourceTag = efOP then Inc(Result);
    end
    else if (Operands[0].Kind = otMem) and (D^.SourceTag in [efMR, efM]) then
      Inc(Result, 2);
  end;

  for I := 0 to D^.OperandCount - 1 do
  begin
    Spec := TInstructionDb.Operand(FormIndex, I);
    if (Spec^.FixedFlags and DB_FO_IS_IMPLICIT) <> 0 then
      Continue;
    ActualIndex := Map[I];
    if ActualIndex < 0 then Continue;
    if (Operands[ActualIndex].Kind = otMem) and
       (Operands[ActualIndex].Mem.Size <> szUnspecified) and
       (Spec^.MemClass <> mcUnspecified) then
      Inc(Result);
  end;
end;

class function TStaticInstructionEncoder.SelectForm(const Mnemonic: string;
  const Operands: array of TOperand): Integer;
var
  MnemonicIndex, Position, I, BestScore, Score: Integer;
  D: PEncodingDescriptor;
  Map: TOperandMap;
begin
  Result := -1;
  BestScore := Low(Integer);
  MnemonicIndex := TInstructionDb.MnemonicIndexOf(Mnemonic);
  if MnemonicIndex < 0 then Exit;

  for Position := 0 to TInstructionDb.MnemonicFormCount(MnemonicIndex) - 1 do
  begin
    I := TInstructionDb.MnemonicFormIndex(MnemonicIndex, Position);
    D := TInstructionDb.Form(I);
    if D^.HasFixup then
      Continue;
    if not BuildOperandMap(I, Operands, Map) then
      Continue;
    if not CheckNativeRestriction(I, Operands, Map) then
      Continue;

    Score := ScoreForm(I, Operands, Map);
    if Score > BestScore then
    begin
      BestScore := Score;
      Result := I;
    end;
  end;
end;

class procedure TStaticInstructionEncoder.EmitPrefixes(Encoder: TEncoderX64;
  const D: TEncodingDescriptor);
var
  Need66: Boolean;
begin
  // F2/F3 group prefix precedes operand-size 66 in NativeAsm's canonical
  // output (for example POPCNT r16: F3 66 ...).
  case D.MandatoryPrefix of
    mpF2: Encoder.EmitRaw($F2);
    mpF3: Encoder.EmitRaw($F3);
  end;

  Need66 := D.Raw66 or
            (D.MandatoryPrefix = mp66) or
            (D.Legacy66Policy = p66ForceOperandSize) or
            (D.Legacy66Policy = p66MandatoryOpcode) or
            ((D.Legacy66Policy = p66ByResolvedGpWidth) and
             (D.ExpandedWidth = 16)) or
            (D.NativeCanonicalization = ncLea16Uses66);
  if Need66 then
    Encoder.EmitRaw($66);

  if D.Raw67 and (D.NativeCanonicalization <> ncLea16Uses66) then
    Encoder.EmitRaw($67);
end;

class procedure TStaticInstructionEncoder.EmitRex(Encoder: TEncoderX64;
  FormIndex: Integer; const Operands: array of TOperand;
  const Map: TOperandMap);
var
  D: PEncodingDescriptor;
  RegOp, NullReg: TRegister;
  RMOp: TOperand;
  RegActual, RMActual: Integer;
  ForceW: Boolean;
begin
  D := TInstructionDb.Form(FormIndex);
  ForceW := (D^.RexWPolicy = rwForce) or
            ((D^.RexWPolicy = rwByResolvedGpWidth) and
             (D^.ExpandedWidth = 64));

  NullReg.ID := ridRAX;
  NullReg.RegType := rt32;
  RegOp := NullReg;
  RMOp.Kind := otNone;

  case D^.ModRMKind of
    mkFromOperands:
    begin
      RegActual := ActualOperandIndex(FormIndex, D^.ModRegOperandIdx, Map);
      RMActual := ActualOperandIndex(FormIndex, D^.ModRmOperandIdx, Map);
      if (RegActual < 0) or (RMActual < 0) or
         (Operands[RegActual].Kind <> otReg) then
        raise EInvalidOpException.CreateFmt(
          'Static encoder: unresolved /r binding for form %d', [FormIndex]);
      RegOp := Operands[RegActual].Reg;
      RMOp := Operands[RMActual];
    end;

    mkFixedRegField,
    mkIgnoredRegCanonicalZero:
    begin
      RMActual := ActualOperandIndex(FormIndex, D^.ModRmOperandIdx, Map);
      if RMActual < 0 then
        raise EInvalidOpException.CreateFmt(
          'Static encoder: unresolved fixed ModRM binding for form %d', [FormIndex]);
      RMOp := Operands[RMActual];
    end;

    mkNone:
    begin
      if D^.OpcodePlusReg then
      begin
        RMActual := ActualOperandIndex(FormIndex, D^.OpcodeRegOperandIdx, Map);
        if (RMActual < 0) or (Operands[RMActual].Kind <> otReg) then
          raise EInvalidOpException.CreateFmt(
            'Static encoder: unresolved opcode+reg binding for form %d', [FormIndex]);
        // Feeding opcode+reg through the RM side produces the required REX.B
        // bit for R8-R15 and the bare REX for SPL/BPL/SIL/DIL.
        RMOp := Operands[RMActual];
      end
      else
      begin
        if not ForceW then
          Exit;
        // ForceW mit keinem Register-Operanden (z.B. ADD RAX,imm32 Akkumulator-Form):
        // nur REX.W ($48) emittieren, keine Extension-Bits. Durchfallen zu EmitRexW.
      end;
    end;

    mkFixedByte:
      Exit;
  end;

  if ForceW then
    Encoder.EmitRexW(RegOp, RMOp)
  else
    Encoder.EmitRexNoW(RegOp, RMOp);
end;

class procedure TStaticInstructionEncoder.EmitOpcodeMap(Encoder: TEncoderX64;
  OpcodeMap: TOpcodeMap);
begin
  case OpcodeMap of
    omPrimary: ;
    om0F:
      Encoder.EmitRaw($0F);
    om0F38:
    begin
      Encoder.EmitRaw($0F);
      Encoder.EmitRaw($38);
    end;
    om0F3A:
    begin
      Encoder.EmitRaw($0F);
      Encoder.EmitRaw($3A);
    end;
  end;
end;

class procedure TStaticInstructionEncoder.EmitImmediate(Encoder: TEncoderX64;
  FormIndex: Integer; const Operands: array of TOperand;
  const Map: TOperandMap);
var
  D: PEncodingDescriptor;
  ActualIndex: Integer;
  V: Int64;
begin
  D := TInstructionDb.Form(FormIndex);
  if D^.ImmediateOperandIdx < 0 then Exit;

  ActualIndex := ActualOperandIndex(FormIndex, D^.ImmediateOperandIdx, Map);
  if (ActualIndex < 0) or (Operands[ActualIndex].Kind <> otImm) then
    raise EInvalidOpException.CreateFmt(
      'Static encoder: unresolved immediate binding for form %d', [FormIndex]);
  V := Operands[ActualIndex].Imm;

  case D^.ImmediateBytes of
    1: Encoder.EmitRaw(Byte(V));
    2: Encoder.WriteInt16(Word(V));
    4: Encoder.EmitInt32Raw(Integer(V));
    8: Encoder.EmitInt64Raw(V);
  else
    raise EInvalidOpException.CreateFmt(
      'Static encoder: invalid immediate width %d in form %d',
      [D^.ImmediateBytes, FormIndex]);
  end;
end;

class procedure TStaticInstructionEncoder.EmitSelected(Encoder: TEncoderX64;
  FormIndex: Integer; const Operands: array of TOperand;
  const Map: TOperandMap);
var
  D: PEncodingDescriptor;
  RegActual, RMActual: Integer;
  OpcodeByte: Byte;
begin
  D := TInstructionDb.Form(FormIndex);
  if D^.HasFixup then
    raise EInvalidOpException.Create(
      'Static encoder: relative forms require EmitRelative32Placeholder');

  EmitPrefixes(Encoder, D^);
  EmitRex(Encoder, FormIndex, Operands, Map);
  EmitOpcodeMap(Encoder, D^.OpcodeMap);

  OpcodeByte := D^.Opcode;
  if D^.OpcodePlusReg then
  begin
    RegActual := ActualOperandIndex(FormIndex, D^.OpcodeRegOperandIdx, Map);
    if (RegActual < 0) or (Operands[RegActual].Kind <> otReg) then
      raise EInvalidOpException.CreateFmt(
        'Static encoder: invalid opcode+reg operand in form %d', [FormIndex]);
    OpcodeByte := OpcodeByte + Operands[RegActual].Reg.ModRMField;
  end;
  Encoder.EmitRaw(OpcodeByte);

  case D^.ModRMKind of
    mkNone:
      ;
    mkFromOperands:
    begin
      RegActual := ActualOperandIndex(FormIndex, D^.ModRegOperandIdx, Map);
      RMActual := ActualOperandIndex(FormIndex, D^.ModRmOperandIdx, Map);
      Encoder.EmitModRM(Operands[RegActual].Reg, Operands[RMActual]);
    end;
    mkFixedRegField:
    begin
      RMActual := ActualOperandIndex(FormIndex, D^.ModRmOperandIdx, Map);
      Encoder.EmitModRMValue(D^.FixedRegValue, Operands[RMActual]);
    end;
    mkIgnoredRegCanonicalZero:
    begin
      RMActual := ActualOperandIndex(FormIndex, D^.ModRmOperandIdx, Map);
      Encoder.EmitModRMValue(0, Operands[RMActual]);
    end;
    mkFixedByte:
      Encoder.EmitRaw(D^.FixedModRMByte);
  end;

  EmitImmediate(Encoder, FormIndex, Operands, Map);
end;

class function TStaticInstructionEncoder.Encode(Encoder: TEncoderX64;
  const Mnemonic: string; const Operands: array of TOperand): Integer;
var
  Map: TOperandMap;
begin
  if Encoder = nil then
    raise EArgumentNilException.Create('Encoder');

  Result := SelectForm(Mnemonic, Operands);
  if Result < 0 then
    raise EArgumentException.CreateFmt(
      'No supported static x64 form matches "%s" with %d explicit operand(s)',
      [Mnemonic, Length(Operands)]);

  if not BuildOperandMap(Result, Operands, Map) then
    raise EInvalidOpException.Create('Static encoder selected a form that no longer matches');
  TAsmRuleValidator.Validate(Result, Operands);
  EmitSelected(Encoder, Result, Operands, Map);
end;

class function TStaticInstructionEncoder.EmitRelative32Placeholder(
  Encoder: TEncoderX64; const Mnemonic: string;
  out PlaceholderOffset: Integer): Integer;
var
  MnemonicIndex, Position, I: Integer;
  D: PEncodingDescriptor;
begin
  if Encoder = nil then
    raise EArgumentNilException.Create('Encoder');

  Result := -1;
  MnemonicIndex := TInstructionDb.MnemonicIndexOf(Mnemonic);
  if MnemonicIndex >= 0 then
    for Position := 0 to TInstructionDb.MnemonicFormCount(MnemonicIndex) - 1 do
    begin
      I := TInstructionDb.MnemonicFormIndex(MnemonicIndex, Position);
      D := TInstructionDb.Form(I);
      if (D^.NativeSupport = nsSourceOnly) or
         (not D^.HasFixup) or (D^.FixupKind <> dfkRelative32) then
        Continue;
      if (D^.NativeRestriction = nrNativeConditionSubset) and
         not (SameText(Mnemonic, 'jz') or SameText(Mnemonic, 'jnz') or
              SameText(Mnemonic, 'jnle') or SameText(Mnemonic, 'jnl') or
              SameText(Mnemonic, 'jl') or SameText(Mnemonic, 'jle') or
              SameText(Mnemonic, 'jnbe') or SameText(Mnemonic, 'jnb') or
              SameText(Mnemonic, 'jb') or SameText(Mnemonic, 'jbe')) then
        Continue;
      if D^.ModRMKind <> mkNone then
        Continue;
      Result := I;
      Break;
    end;

  if Result < 0 then
    raise EArgumentException.CreateFmt(
      'No supported rel32 static form found for "%s"', [Mnemonic]);

  D := TInstructionDb.Form(Result);
  EmitPrefixes(Encoder, D^);
  EmitOpcodeMap(Encoder, D^.OpcodeMap);
  Encoder.EmitRaw(D^.Opcode);
  PlaceholderOffset := Encoder.CurrentOffset;
  Encoder.EmitInt32Raw(0);
end;

end.
