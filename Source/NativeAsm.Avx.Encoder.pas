unit NativeAsm.Avx.Encoder;

{$ALIGN ON}
{$MINENUMSIZE 4}

interface

uses
  NativeAsm.Builder,
  NativeAsm.Avx.Types;

type
  TAvxInstructionEncoder = class sealed
  public
    class function Encode(Builder: TAsmBuilder; const Mnemonic: string; const Operands: array of TAvxOperand): Integer; static;
    class function SelectForm(const Mnemonic: string; const Operands: array of TAvxOperand): Integer; static;
  end;

implementation

uses
  System.SysUtils,
  NativeAsm.Types,
  NativeAsm.Simd.Types,
  NativeAsm.Avx.Db,
  NativeAsm.ByteBuffer;

type
  TAvxOperandMap = array[0..7] of ShortInt;

function RegMatches(C: TAvxDbRegClass; const O: TAvxOperand): Boolean;
begin
  case C of
    arcXmm: Result := (O.Kind = aokXmmReg) and (O.XmmReg.Kind = srkXmm) and O.XmmReg.IsValid;
    arcYmm: Result := (O.Kind = aokYmmReg) and O.YmmReg.IsValid;
    arcGp32: Result := (O.Kind = aokGprReg) and O.GprReg.IsValid and (O.GprReg.RegType = rt32);
    arcGp64: Result := (O.Kind = aokGprReg) and O.GprReg.IsValid and (O.GprReg.RegType = rt64);
  else
    Result := False;
  end;
end;

function MemMatches(C: TAvxDbMemClass; const M: TAvxMemory): Boolean;
var
  S: TAvxMemSize;
begin
  case C of
    amcVm32x: Exit(M.IsVsib and (M.Vsib.IndexSize = ams32) and (M.Vsib.IndexKind = avikXmm));
    amcVm32y: Exit(M.IsVsib and (M.Vsib.IndexSize = ams32) and (M.Vsib.IndexKind = avikYmm));
    amcVm64x: Exit(M.IsVsib and (M.Vsib.IndexSize = ams64) and (M.Vsib.IndexKind = avikXmm));
    amcVm64y: Exit(M.IsVsib and (M.Vsib.IndexSize = ams64) and (M.Vsib.IndexKind = avikYmm));
  end;
  if M.IsVsib then Exit(False);
  S := M.Size;
  if S = amsUnspecified then Exit(C <> amcNone);
  case C of
    amc8: Result := S = ams8;
    amc16: Result := S = ams16;
    amc32: Result := S = ams32;
    amc64: Result := S = ams64;
    amc128: Result := S = ams128;
    amc256: Result := S = ams256;
  else
    Result := False;
  end;
end;

function MatchOperand(const Spec: TAvxDbOperandSpec; const O: TAvxOperand): Boolean;
begin
  case O.Kind of
    aokXmmReg, aokYmmReg, aokGprReg: Result := ((Spec.Kinds and AVX_OK_REG) <> 0) and RegMatches(Spec.RegClass, O);
    aokMem: Result := ((Spec.Kinds and AVX_OK_MEM) <> 0) and MemMatches(Spec.MemClass, O.Mem);
    aokImm: Result := ((Spec.Kinds and AVX_OK_IMM) <> 0) and (Spec.ImmBytes = 1) and (O.Imm >= -128) and (O.Imm <= 255);
  else
    Result := False;
  end;
end;

function OperandRegID(const O: TAvxOperand): Byte;
begin
  case O.Kind of
    aokXmmReg: Result := O.XmmReg.ID;
    aokYmmReg: Result := O.YmmReg.ID;
    aokGprReg: Result := Byte(Ord(O.GprReg.ID));
  else
    raise EAvxError.Create('AVX register operand required');
  end;
end;

function BuildMap(FormIndex: Integer; const Operands: array of TAvxOperand; out Map: TAvxOperandMap): Boolean;
var
  D: PAvxEncodingDescriptor;
  S: PAvxDbOperandSpec;
  I: Integer;
begin
  for I := Low(Map) to High(Map) do Map[I] := -1;
  D := TAvxInstructionDb.Form(FormIndex);
  if D^.OperandCount <> Length(Operands) then Exit(False);
  for I := 0 to D^.OperandCount - 1 do
  begin
    S := TAvxInstructionDb.Operand(FormIndex, I);
    if not MatchOperand(S^, Operands[I]) then Exit(False);
    Map[I] := I;
  end;
  if D^.FormTag = aefRMV then
  begin
    if (D^.ModRegOperandIdx < 0) or (D^.ModRmOperandIdx < 0) or (D^.VvvvOperandIdx < 0) then Exit(False);
    if not Operands[D^.ModRmOperandIdx].Mem.IsVsib then Exit(False);
    if OperandRegID(Operands[D^.ModRegOperandIdx]) = OperandRegID(Operands[D^.VvvvOperandIdx]) then Exit(False);
    if OperandRegID(Operands[D^.ModRegOperandIdx]) = Operands[D^.ModRmOperandIdx].Mem.Vsib.IndexID then Exit(False);
    if OperandRegID(Operands[D^.VvvvOperandIdx]) = Operands[D^.ModRmOperandIdx].Mem.Vsib.IndexID then Exit(False);
  end;
  Result := True;
end;

function ScoreForm(FormIndex: Integer; const Operands: array of TAvxOperand): Integer;
var
  D: PAvxEncodingDescriptor;
  I: Integer;
  NoMemory: Boolean;
begin
  Result := 0;
  NoMemory := True;
  for I := 0 to High(Operands) do
  begin
    if Operands[I].Kind = aokMem then
    begin
      NoMemory := False;
      if Operands[I].Mem.IsVsib then Inc(Result, 16) else if Operands[I].Mem.Size = amsUnspecified then Inc(Result) else Inc(Result, 16);
    end
    else
    begin
      Inc(Result, 8);
    end;
  end;
  if NoMemory then
  begin
    D := TAvxInstructionDb.Form(FormIndex);
    case D^.FormTag of
      aefRM, aefRVM: Inc(Result, 2);
      aefMR, aefMVR: Inc(Result);
    end;
  end;
end;

class function TAvxInstructionEncoder.SelectForm(const Mnemonic: string; const Operands: array of TAvxOperand): Integer;
var
  M, I, F, S, BestScore: Integer;
  Map: TAvxOperandMap;
begin
  M := TAvxInstructionDb.MnemonicIndexOf(Mnemonic);
  if M < 0 then raise EAvxError.CreateFmt('Unsupported AVX mnemonic: %s', [Mnemonic]);
  Result := -1;
  BestScore := Low(Integer);
  for I := 0 to TAvxInstructionDb.MnemonicFormCount(M) - 1 do
  begin
    F := TAvxInstructionDb.MnemonicFormIndex(M, I);
    if not BuildMap(F, Operands, Map) then Continue;
    S := ScoreForm(F, Operands);
    if S > BestScore then
    begin
      BestScore := S;
      Result := F;
    end;
  end;
  if Result < 0 then raise EAvxError.CreateFmt('No AVX encoding form matches %s with %d operand(s)', [Mnemonic, Length(Operands)]);
end;

function RegID(const O: TAvxOperand): Byte;
begin
  Result := OperandRegID(O);
end;

function RegField(const O: TAvxOperand): Byte;
begin
  Result := RegID(O) and 7;
end;

function RegExtended(const O: TAvxOperand): Boolean;
begin
  Result := RegID(O) >= 8;
end;

function MapBits(M: TAvxOpcodeMap): Byte;
begin
  case M of
    aom0F: Result := 1;
    aom0F38: Result := 2;
    aom0F3A: Result := 3;
  else
    raise EAvxError.Create('Invalid AVX opcode map');
  end;
end;

procedure EmitVsibModRM(var W: TAsmByteBuffer; RegVal: Byte; const M: TAvxMemory);
var
  ModV, BaseBits: Byte;
  V: TAvxVsibMemory;
begin
  if not M.IsVsib then raise EAvxError.Create('AVX VSIB operand required');
  V := M.Vsib;
  RegVal := RegVal and 7;
  if not V.HasBase then
  begin
    W.Put((RegVal shl 3) or 4);
    W.Put((Byte(V.Scale) shl 6) or ((V.IndexID and 7) shl 3) or 5);
    W.PutInt32(V.Disp);
    Exit;
  end;
  BaseBits := Byte(V.Base) and 7;
  if V.Disp = 0 then
  begin
    ModV := 0;
    if (V.Base = ridRBP) or (V.Base = ridR13) then ModV := 1;
  end
  else if (V.Disp >= -128) and (V.Disp <= 127) then ModV := 1 else ModV := 2;
  W.Put((ModV shl 6) or (RegVal shl 3) or 4);
  W.Put((Byte(V.Scale) shl 6) or ((V.IndexID and 7) shl 3) or BaseBits);
  case ModV of
    1: W.Put(Byte(V.Disp));
    2: W.PutInt32(V.Disp);
  end;
end;

procedure EmitModRM(var W: TAsmByteBuffer; RegVal: Byte; const RM: TAvxOperand);
var
  ModV, RmVal, ScaleBits, IndexBits, BaseBits: Byte;
  M: TMemory;
  HasSib: Boolean;
begin
  RegVal := RegVal and 7;
  if RM.Kind in [aokXmmReg, aokYmmReg, aokGprReg] then
  begin
    W.Put($C0 or (RegVal shl 3) or RegField(RM));
    Exit;
  end;
  if RM.Kind <> aokMem then raise EAvxError.Create('AVX r/m operand required');
  if RM.Mem.IsVsib then
  begin
    EmitVsibModRM(W, RegVal, RM.Mem);
    Exit;
  end;
  M := RM.Mem.Address;
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

procedure VexExtensions(const D: TAvxEncodingDescriptor; const Operands: array of TAvxOperand; out R, X, B: Boolean; out Vvvv: Byte);
var
  O: TAvxOperand;
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
    if O.Kind in [aokXmmReg, aokYmmReg, aokGprReg] then
      B := RegExtended(O)
    else if O.Kind = aokMem then
    begin
      if O.Mem.IsVsib then
      begin
        B := O.Mem.Vsib.HasBase and (Ord(O.Mem.Vsib.Base) >= 8);
        X := O.Mem.Vsib.IndexID >= 8;
      end
      else
      begin
        M := O.Mem.Address;
        if not M.IsRipRelative then
        begin
          B := Ord(M.Base) >= 8;
          X := M.HasIndex and (Ord(M.Index) >= 8);
        end;
      end;
    end;
  end;
  if D.VvvvOperandIdx >= 0 then Vvvv := (not RegID(Operands[D.VvvvOperandIdx])) and $0F;
end;

procedure EmitVex(var W: TAsmByteBuffer; const D: TAvxEncodingDescriptor; const Operands: array of TAvxOperand);
var
  R, X, B: Boolean;
  Vvvv, P2, P3: Byte;
begin
  VexExtensions(D, Operands, R, X, B, Vvvv);
  if (D.OpcodeMap = aom0F) and (D.VexW = 0) and not X and not B then
  begin
    W.Put($C5);
    P2 := 0;
    if not R then P2 := P2 or $80;
    P2 := P2 or (Vvvv shl 3) or ((D.VexL and 1) shl 2) or (D.VexPP and 3);
    W.Put(P2);
    Exit;
  end;
  W.Put($C4);
  P2 := MapBits(D.OpcodeMap);
  if not R then P2 := P2 or $80;
  if not X then P2 := P2 or $40;
  if not B then P2 := P2 or $20;
  W.Put(P2);
  P3 := ((D.VexW and 1) shl 7) or (Vvvv shl 3) or ((D.VexL and 1) shl 2) or (D.VexPP and 3);
  W.Put(P3);
end;

class function TAvxInstructionEncoder.Encode(Builder: TAsmBuilder; const Mnemonic: string; const Operands: array of TAvxOperand): Integer;
var
  D: PAvxEncodingDescriptor;
  W: TAsmByteBuffer;
  Bytes: TBytes;
begin
  if Builder = nil then raise EArgumentNilException.Create('Builder');
  Result := SelectForm(Mnemonic, Operands);
  D := TAvxInstructionDb.Form(Result);
  W.Init(32);
  EmitVex(W, D^, Operands);
  W.Put(D^.Opcode);
  if D^.ModRmOperandIdx >= 0 then
  begin
    if D^.ModRegOperandIdx >= 0 then EmitModRM(W, RegField(Operands[D^.ModRegOperandIdx]), Operands[D^.ModRmOperandIdx])
    else if D^.ModRegFixed >= 0 then EmitModRM(W, Byte(D^.ModRegFixed), Operands[D^.ModRmOperandIdx])
    else raise EAvxError.Create('AVX ModRM reg field is not defined');
  end;
  if D^.ImmediateOperandIdx >= 0 then
  begin
    if D^.FormTag = aefRVMS then
      W.Put((RegID(Operands[D^.ImmediateOperandIdx]) and $0F) shl 4)
    else
      W.Put(Byte(Operands[D^.ImmediateOperandIdx].Imm));
  end;
  Bytes := W.Finish;
  Builder.EmitBytes(Bytes);
end;

end.
