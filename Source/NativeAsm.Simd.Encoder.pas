{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
unit NativeAsm.Simd.Encoder;

{$ALIGN ON}
{$MINENUMSIZE 4}

interface

uses
  NativeAsm.Builder,
  NativeAsm.Simd.Types;

type
  TSimdInstructionEncoder = class sealed
  public
    class function Encode(Builder: TAsmBuilder; const Mnemonic: string; const Operands: array of TSimdOperand): Integer; static;
    class function SelectForm(const Mnemonic: string; const Operands: array of TSimdOperand): Integer; static;
  end;

implementation

uses
  System.SysUtils,
  NativeAsm.Types,
  NativeAsm.Simd.Db;

type
  TOperandMap = array[0..7] of ShortInt;

  TSimdWriter = record
    Data: TBytes;
    Count: Integer;
    procedure Init;
    procedure Put(B: Byte);
    procedure PutInt32(V: Integer);
    function Finish: TBytes;
  end;

procedure TSimdWriter.Init;
begin
  SetLength(Data, 32);
  Count := 0;
end;

procedure TSimdWriter.Put(B: Byte);
begin
  if Count >= Length(Data) then SetLength(Data, Length(Data) * 2);
  Data[Count] := B;
  Inc(Count);
end;

procedure TSimdWriter.PutInt32(V: Integer);
var
  U: Cardinal absolute V;
begin
  Put(Byte(U));
  Put(Byte(U shr 8));
  Put(Byte(U shr 16));
  Put(Byte(U shr 24));
end;

function TSimdWriter.Finish: TBytes;
begin
  SetLength(Data, Count);
  Result := Data;
end;

function MemMatches(C: TSimdDbMemClass; S: TSimdMemSize): Boolean;
begin
  if S = smsUnspecified then Exit(C <> smcNone);
  case C of
    smcAny: Result := True;
    smc8: Result := S = sms8;
    smc16: Result := S = sms16;
    smc32: Result := S = sms32;
    smc64: Result := S = sms64;
    smc128: Result := S = sms128;
  else
    Result := False;
  end;
end;

function RegMatches(C: TSimdDbRegClass; const O: TSimdOperand): Boolean;
begin
  Result := False;
  case O.Kind of
    sokSimdReg:
      case C of
        srcXmm: Result := (O.SimdReg.Kind = srkXmm) and O.SimdReg.IsValid;
        srcMm: Result := (O.SimdReg.Kind = srkMm) and O.SimdReg.IsValid;
      end;
    sokGpReg:
      case C of
        srcGp8: Result := O.GpReg.RegType in [rt8, rt8High];
        srcGp16: Result := O.GpReg.RegType = rt16;
        srcGp32: Result := O.GpReg.RegType = rt32;
        srcGp64: Result := O.GpReg.RegType = rt64;
      end;
  end;
end;

function MatchOperand(const Spec: TSimdDbOperandSpec; const O: TSimdOperand): Boolean;
begin
  case O.Kind of
    sokSimdReg, sokGpReg: Result := ((Spec.Kinds and SIMD_OK_REG) <> 0) and RegMatches(Spec.RegClass, O);
    sokMem: Result := ((Spec.Kinds and SIMD_OK_MEM) <> 0) and MemMatches(Spec.MemClass, O.Mem.Size);
    sokImm: Result := ((Spec.Kinds and SIMD_OK_IMM) <> 0) and (Spec.ImmBytes = 1) and (O.Imm >= -128) and (O.Imm <= 255);
  else
    Result := False;
  end;
end;

function BuildMap(FormIndex: Integer; const Operands: array of TSimdOperand; out Map: TOperandMap): Boolean;
var
  D: PSimdEncodingDescriptor;
  I, A: Integer;
  S: PSimdDbOperandSpec;
begin
  for I := Low(Map) to High(Map) do Map[I] := -1;
  D := TSimdInstructionDb.Form(FormIndex);
  if D^.OperandCount > Length(Map) then Exit(False);
  A := 0;
  for I := 0 to D^.OperandCount - 1 do
  begin
    S := TSimdInstructionDb.Operand(FormIndex, I);
    if S^.Implicit then Continue;
    if A >= Length(Operands) then Exit(False);
    if not MatchOperand(S^, Operands[A]) then Exit(False);
    Map[I] := A;
    Inc(A);
  end;
  Result := A = Length(Operands);
end;

function ScoreForm(FormIndex: Integer; const Operands: array of TSimdOperand; const Map: TOperandMap): Integer;
var
  D: PSimdEncodingDescriptor;
  I, A: Integer;
  S: PSimdDbOperandSpec;
begin
  Result := 0;
  D := TSimdInstructionDb.Form(FormIndex);
  for I := 0 to D^.OperandCount - 1 do
  begin
    A := Map[I];
    if A < 0 then Continue;
    S := TSimdInstructionDb.Operand(FormIndex, I);
    if Operands[A].Kind = sokMem then
    begin
      if Operands[A].Mem.Size = smsUnspecified then Inc(Result) else Inc(Result, 16);
      if S^.MemClass = smcAny then Inc(Result);
    end
    else
      Inc(Result, 8);
  end;
end;

class function TSimdInstructionEncoder.SelectForm(const Mnemonic: string; const Operands: array of TSimdOperand): Integer;
var
  M, I, F, S, BestScore: Integer;
  Map: TOperandMap;
begin
  M := TSimdInstructionDb.MnemonicIndexOf(Mnemonic);
  if M < 0 then raise ESimdError.CreateFmt('Unsupported SIMD mnemonic: %s', [Mnemonic]);
  Result := -1;
  BestScore := Low(Integer);
  for I := 0 to TSimdInstructionDb.MnemonicFormCount(M) - 1 do
  begin
    F := TSimdInstructionDb.MnemonicFormIndex(M, I);
    if not BuildMap(F, Operands, Map) then Continue;
    S := ScoreForm(F, Operands, Map);
    if S > BestScore then
    begin
      BestScore := S;
      Result := F;
    end;
  end;
  if Result < 0 then raise ESimdError.CreateFmt('No SIMD encoding form matches %s with %d operand(s)', [Mnemonic, Length(Operands)]);
end;

function RegID(const O: TSimdOperand): Byte;
begin
  case O.Kind of
    sokSimdReg: Result := O.SimdReg.ID;
    sokGpReg: Result := Byte(O.GpReg.ID);
  else
    raise ESimdError.Create('SIMD register operand required');
  end;
end;

function RegField(const O: TSimdOperand): Byte;
begin
  if O.Kind = sokGpReg then Result := O.GpReg.ModRMField else Result := RegID(O) and 7;
end;

function IsExtendedReg(const O: TSimdOperand): Boolean;
begin
  case O.Kind of
    sokSimdReg: Result := O.SimdReg.IsExtended;
    sokGpReg: Result := O.GpReg.IsExtended;
  else
    Result := False;
  end;
end;

function IsHigh8(const O: TSimdOperand): Boolean;
begin
  Result := (O.Kind = sokGpReg) and (O.GpReg.RegType = rt8High);
end;

procedure EmitModRM(var W: TSimdWriter; RegVal: Byte; const RM: TSimdOperand);
var
  ModV, RmVal, ScaleBits, IndexBits, BaseBits: Byte;
  M: TMemory;
  HasSib: Boolean;
begin
  RegVal := RegVal and 7;
  if RM.Kind in [sokSimdReg, sokGpReg] then
  begin
    W.Put($C0 or (RegVal shl 3) or RegField(RM));
    Exit;
  end;
  if RM.Kind <> sokMem then raise ESimdError.Create('SIMD r/m operand required');
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

procedure EmitRex(var W: TSimdWriter; const D: TSimdEncodingDescriptor; const Operands: array of TSimdOperand; const Map: TOperandMap);
var
  Rex: Byte;
  Need, High8: Boolean;
  A: Integer;
  O: TSimdOperand;
  M: TMemory;
begin
  Rex := $40;
  Need := False;
  High8 := False;
  if D.RexW then begin Rex := Rex or $08; Need := True; end;
  if D.ModRegOperandIdx >= 0 then
  begin
    A := Map[D.ModRegOperandIdx];
    if A >= 0 then
    begin
      O := Operands[A];
      High8 := High8 or IsHigh8(O);
      if IsExtendedReg(O) then begin Rex := Rex or $04; Need := True; end;
    end;
  end;
  if D.ModRmOperandIdx >= 0 then
  begin
    A := Map[D.ModRmOperandIdx];
    if A >= 0 then
    begin
      O := Operands[A];
      High8 := High8 or IsHigh8(O);
      if O.Kind in [sokSimdReg, sokGpReg] then
      begin
        if IsExtendedReg(O) then begin Rex := Rex or $01; Need := True; end;
      end
      else if O.Kind = sokMem then
      begin
        M := O.Mem.Address;
        if not M.IsRipRelative then
        begin
          if Ord(M.Base) >= 8 then begin Rex := Rex or $01; Need := True; end;
          if M.HasIndex and (Ord(M.Index) >= 8) then begin Rex := Rex or $02; Need := True; end;
        end;
      end;
    end;
  end;
  if High8 and Need then raise ESimdError.Create('High-byte GPR cannot be encoded with REX');
  if Need then W.Put(Rex);
end;

procedure EmitMap(var W: TSimdWriter; M: TSimdOpcodeMap);
begin
  case M of
    som0F: W.Put($0F);
    som0F38: begin W.Put($0F); W.Put($38); end;
    som0F3A: begin W.Put($0F); W.Put($3A); end;
  end;
end;

class function TSimdInstructionEncoder.Encode(Builder: TAsmBuilder; const Mnemonic: string; const Operands: array of TSimdOperand): Integer;
var
  D: PSimdEncodingDescriptor;
  Map: TOperandMap;
  W: TSimdWriter;
  A: Integer;
  O: TSimdOperand;
  Bytes: TBytes;

  procedure EmitImm(SourceIndex: Integer);
  var
    Actual: Integer;
  begin
    if SourceIndex < 0 then Exit;
    Actual := Map[SourceIndex];
    if Actual < 0 then raise ESimdError.Create('SIMD immediate mapping failed');
    W.Put(Byte(Operands[Actual].Imm));
  end;

begin
  if Builder = nil then raise EArgumentNilException.Create('Builder');
  Result := SelectForm(Mnemonic, Operands);
  if not BuildMap(Result, Operands, Map) then raise ESimdError.Create('SIMD operand mapping failed');
  D := TSimdInstructionDb.Form(Result);
  W.Init;
  if D^.Prefix1 <> 0 then W.Put(D^.Prefix1);
  if D^.Prefix2 <> 0 then W.Put(D^.Prefix2);
  EmitRex(W, D^, Operands, Map);
  EmitMap(W, D^.OpcodeMap);
  W.Put(D^.Opcode);
  case D^.ModRMKind of
    smkFixedByte: W.Put(D^.FixedModRMByte);
    smkFixedReg:
      begin
        A := Map[D^.ModRmOperandIdx];
        if A < 0 then raise ESimdError.Create('SIMD fixed ModRM mapping failed');
        EmitModRM(W, D^.FixedRegValue, Operands[A]);
      end;
    smkOperands:
      begin
        A := Map[D^.ModRegOperandIdx];
        if A < 0 then raise ESimdError.Create('SIMD ModRM reg mapping failed');
        O := Operands[A];
        A := Map[D^.ModRmOperandIdx];
        if A < 0 then raise ESimdError.Create('SIMD ModRM r/m mapping failed');
        EmitModRM(W, RegField(O), Operands[A]);
      end;
  end;
  EmitImm(D^.Immediate0OperandIdx);
  EmitImm(D^.Immediate1OperandIdx);
  Bytes := W.Finish;
  Builder.EmitBytes(Bytes);
end;

end.
