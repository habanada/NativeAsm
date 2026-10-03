unit NativeAsm.Bmi.Encoder;

{$ALIGN ON}
{$MINENUMSIZE 4}

interface

uses
  NativeAsm.Builder,
  NativeAsm.Types;

type
  TBmiInstructionEncoder = class sealed
  public
    class function Encode(Builder: TAsmBuilder; const Mnemonic: string; const Operands: array of TOperand): Integer; static;
    class function SelectForm(const Mnemonic: string; const Operands: array of TOperand): Integer; static;
  end;

implementation

uses
  System.SysUtils,
  NativeAsm.Bmi.Db,
  NativeAsm.ByteBuffer;

function RegMatches(C: TBmiDbRegClass; const O: TOperand): Boolean;
begin
  if (O.Kind <> otReg) or not O.Reg.IsValid then Exit(False);
  case C of
    brc32: Result := O.Reg.RegType = rt32;
    brc64: Result := O.Reg.RegType = rt64;
  else
    Result := False;
  end;
end;

function MemMatches(C: TBmiDbMemClass; S: TOperandSize): Boolean;
begin
  if S = szUnspecified then Exit(C <> bmcNone);
  case C of
    bmc32: Result := S = sz32;
    bmc64: Result := S = sz64;
  else
    Result := False;
  end;
end;

function MatchOperand(const Spec: TBmiDbOperandSpec; const O: TOperand): Boolean;
begin
  case O.Kind of
    otReg: Result := ((Spec.Kinds and BMI_OK_REG) <> 0) and RegMatches(Spec.RegClass, O);
    otMem: Result := ((Spec.Kinds and BMI_OK_MEM) <> 0) and MemMatches(Spec.MemClass, O.Mem.Size);
    otImm: Result := ((Spec.Kinds and BMI_OK_IMM) <> 0) and (Spec.ImmBytes = 1) and (O.Imm >= -128) and (O.Imm <= 255);
  else
    Result := False;
  end;
end;

function FormMatches(FormIndex: Integer; const Operands: array of TOperand): Boolean;
var
  D: PBmiEncodingDescriptor;
  I: Integer;
begin
  D := TBmiInstructionDb.Form(FormIndex);
  if D^.OperandCount <> Length(Operands) then Exit(False);
  for I := 0 to D^.OperandCount - 1 do
    if not MatchOperand(TBmiInstructionDb.Operand(FormIndex, I)^, Operands[I]) then Exit(False);
  Result := True;
end;

class function TBmiInstructionEncoder.SelectForm(const Mnemonic: string; const Operands: array of TOperand): Integer;
var
  M, I, F: Integer;
begin
  M := TBmiInstructionDb.MnemonicIndexOf(Mnemonic);
  if M < 0 then raise EBmiError.CreateFmt('Unsupported BMI mnemonic: %s', [Mnemonic]);
  for I := 0 to TBmiInstructionDb.MnemonicFormCount(M) - 1 do
  begin
    F := TBmiInstructionDb.MnemonicFormIndex(M, I);
    if FormMatches(F, Operands) then Exit(F);
  end;
  raise EBmiError.CreateFmt('No BMI encoding form matches %s with %d operand(s)', [Mnemonic, Length(Operands)]);
end;

function RegID(const O: TOperand): Byte;
begin
  if (O.Kind <> otReg) or not O.Reg.IsValid then raise EBmiError.Create('BMI general-purpose register operand required');
  Result := Byte(Ord(O.Reg.ID));
end;

function RegField(const O: TOperand): Byte;
begin
  Result := RegID(O) and 7;
end;

function RegExtended(const O: TOperand): Boolean;
begin
  Result := RegID(O) >= 8;
end;

function MapBits(M: TBmiOpcodeMap): Byte;
begin
  case M of
    bom0F38: Result := 2;
    bom0F3A: Result := 3;
  else
    raise EBmiError.Create('Invalid BMI opcode map');
  end;
end;

procedure EmitModRM(var W: TAsmByteBuffer; RegVal: Byte; const RM: TOperand);
var
  ModV, RmVal, ScaleBits, IndexBits, BaseBits: Byte;
  M: TMemory;
  HasSib: Boolean;
begin
  RegVal := RegVal and 7;
  if RM.Kind = otReg then
  begin
    W.Put($C0 or (RegVal shl 3) or RegField(RM));
    Exit;
  end;
  if RM.Kind <> otMem then raise EBmiError.Create('BMI r/m operand required');
  M := RM.Mem;
  if M.IsRipRelative then
  begin
    W.Put((RegVal shl 3) or 5);
    W.PutInt32(M.Disp);
    Exit;
  end;
  RmVal := Byte(M.Base) and 7;
  HasSib := M.HasIndex or (M.Base = ridRSP) or (M.Base = ridR12);
  if HasSib then RmVal := 4;
  if M.Disp = 0 then
  begin
    ModV := 0;
    if (M.Base = ridRBP) or (M.Base = ridR13) then ModV := 1;
  end
  else if (M.Disp >= -128) and (M.Disp <= 127) then ModV := 1 else ModV := 2;
  W.Put((ModV shl 6) or (RegVal shl 3) or RmVal);
  if HasSib then
  begin
    ScaleBits := Byte(M.Scale);
    BaseBits := Byte(M.Base) and 7;
    if M.HasIndex then IndexBits := Byte(M.Index) and 7 else IndexBits := 4;
    W.Put((ScaleBits shl 6) or (IndexBits shl 3) or BaseBits);
  end;
  case ModV of
    1: W.Put(Byte(M.Disp));
    2: W.PutInt32(M.Disp);
  end;
end;

procedure VexExtensions(const D: TBmiEncodingDescriptor; const Operands: array of TOperand; out R, X, B: Boolean; out Vvvv: Byte);
var
  O: TOperand;
  M: TMemory;
begin
  R := False;
  X := False;
  B := False;
  Vvvv := $0F;
  if D.ModRegOperandIdx >= 0 then R := RegExtended(Operands[D.ModRegOperandIdx]);
  if D.ModRmOperandIdx >= 0 then
  begin
    O := Operands[D.ModRmOperandIdx];
    if O.Kind = otReg then
      B := RegExtended(O)
    else if O.Kind = otMem then
    begin
      M := O.Mem;
      if not M.IsRipRelative then
      begin
        B := Ord(M.Base) >= 8;
        X := M.HasIndex and (Ord(M.Index) >= 8);
      end;
    end;
  end;
  if D.VvvvOperandIdx >= 0 then Vvvv := (not RegID(Operands[D.VvvvOperandIdx])) and $0F;
end;

procedure EmitVex(var W: TAsmByteBuffer; const D: TBmiEncodingDescriptor; const Operands: array of TOperand);
var
  R, X, B: Boolean;
  Vvvv, P2, P3: Byte;
begin
  VexExtensions(D, Operands, R, X, B, Vvvv);
  W.Put($C4);
  P2 := MapBits(D.OpcodeMap);
  if not R then P2 := P2 or $80;
  if not X then P2 := P2 or $40;
  if not B then P2 := P2 or $20;
  W.Put(P2);
  P3 := ((D.VexW and 1) shl 7) or (Vvvv shl 3) or (D.VexPP and 3);
  W.Put(P3);
end;

class function TBmiInstructionEncoder.Encode(Builder: TAsmBuilder; const Mnemonic: string; const Operands: array of TOperand): Integer;
var
  D: PBmiEncodingDescriptor;
  W: TAsmByteBuffer;
  Bytes: TBytes;
begin
  if Builder = nil then raise EArgumentNilException.Create('Builder');
  Result := SelectForm(Mnemonic, Operands);
  D := TBmiInstructionDb.Form(Result);
  W.Init(24);
  EmitVex(W, D^, Operands);
  W.Put(D^.Opcode);
  if D^.ModRmOperandIdx >= 0 then
  begin
    if D^.ModRegOperandIdx >= 0 then EmitModRM(W, RegField(Operands[D^.ModRegOperandIdx]), Operands[D^.ModRmOperandIdx])
    else if D^.ModRegFixed >= 0 then EmitModRM(W, Byte(D^.ModRegFixed), Operands[D^.ModRmOperandIdx])
    else raise EBmiError.Create('BMI ModRM reg field is not defined');
  end;
  if D^.ImmediateOperandIdx >= 0 then W.Put(Byte(Operands[D^.ImmediateOperandIdx].Imm));
  Bytes := W.Finish;
  Builder.EmitBytes(Bytes);
end;

end.
