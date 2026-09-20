{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
unit NativeAsm.Disassembler;

{$ALIGN ON}
{$MINENUMSIZE 4}
{$RTTI EXPLICIT METHODS([]) PROPERTIES([]) FIELDS([])}
{$WEAKLINKRTTI ON}

interface

uses
  System.SysUtils,
  System.Classes,
  NativeAsm.InstructionDB;

type
  TNativeAsmDisasmInstruction = record
    Address: NativeUInt;
    Offset: Integer;
    Size: Integer;
    Bytes: TBytes;
    Mnemonic: string;
    Text: string;
    OperandText: string;
    FormIndex: Integer;
    SourceSignature: string;
    SourceEncoding: string;
    NativeSupport: TNativeSupport;
    NativeRestriction: TNativeRestriction;
    NativeCanonicalization: TNativeCanonicalization;
    HasTarget: Boolean;
    TargetAddress: NativeUInt;
    CandidateCount: Integer;
    IsData: Boolean;
  end;

  TNativeAsmDisassembler = class sealed
  public
    class function DecodeOne(const Code: TBytes; BaseAddress: NativeUInt; Offset: Integer; out Info: TNativeAsmDisasmInstruction): Boolean; static;
    class function DecodeAll(const Code: TBytes; BaseAddress: NativeUInt = 0): TArray<TNativeAsmDisasmInstruction>; static;
    class function FormatInstruction(const Info: TNativeAsmDisasmInstruction; ShowAddress: Boolean = True; ShowBytes: Boolean = True): string; static;
    class function FormatAll(const Code: TBytes; BaseAddress: NativeUInt = 0): string; static;
  end;

implementation

type
  TDecodePrefix = record
    Has66: Boolean;
    Has67: Boolean;
    HasF0: Boolean;
    HasF2: Boolean;
    HasF3: Boolean;
    Rex: Byte;
    Next: Integer;
  end;

  TDecodedRM = record
    Present: Boolean;
    IsRegister: Boolean;
    ModValue: Byte;
    RegField: Integer;
    RmField: Integer;
    HasSib: Boolean;
    HasBase: Boolean;
    HasIndex: Boolean;
    BaseReg: Integer;
    IndexReg: Integer;
    Scale: Integer;
    Disp: Int64;
    RipRelative: Boolean;
    EndPos: Integer;
  end;

  TDecodeCandidate = record
    FormIndex: Integer;
    Prefix: TDecodePrefix;
    OpcodePos: Integer;
    OpcodeByte: Byte;
    RM: TDecodedRM;
    ImmPos: Integer;
    EndPos: Integer;
    Score: Integer;
  end;

function DecodePrefixes(const Code: TBytes; Start: Integer): TDecodePrefix;
var B: Byte;
begin
  Result := Default(TDecodePrefix);
  Result.Next := Start;
  while Result.Next < Length(Code) do
  begin
    B := Code[Result.Next];
    case B of
      $66: Result.Has66 := True;
      $67: Result.Has67 := True;
      $F0: Result.HasF0 := True;
      $F2: Result.HasF2 := True;
      $F3: Result.HasF3 := True;
      $40..$4F: Result.Rex := B;
    else
      Exit;
    end;
    Inc(Result.Next);
  end;
end;

function ReadUnsigned(const Code: TBytes; Pos, Count: Integer; out Value: UInt64): Boolean;
var I: Integer;
begin
  Result := False;
  Value := 0;
  if (Count < 0) or (Pos < 0) or (Pos + Count > Length(Code)) then Exit;
  for I := 0 to Count - 1 do Value := Value or (UInt64(Code[Pos + I]) shl (I * 8));
  Result := True;
end;

function ReadSigned(const Code: TBytes; Pos, Count: Integer; out Value: Int64): Boolean;
var
  U: UInt64;
  B: Byte;
  W: Word;
  C: Cardinal;
  S8: ShortInt;
  S16: SmallInt;
  S32: Integer;
begin
  Result := ReadUnsigned(Code, Pos, Count, U);
  if not Result then Exit;
  case Count of
    1: begin B := Byte(U); Move(B, S8, SizeOf(S8)); Value := S8; end;
    2: begin W := Word(U); Move(W, S16, SizeOf(S16)); Value := S16; end;
    4: begin C := Cardinal(U); Move(C, S32, SizeOf(S32)); Value := S32; end;
    8: Move(U, Value, SizeOf(Value));
  else
    Value := Int64(U);
  end;
end;

function RelativeAddress(BaseAddress: NativeUInt; EndOffset: Integer; Delta: Int64): NativeUInt;
begin
  Result := BaseAddress + NativeUInt(EndOffset);
  if Delta < 0 then Result := Result - NativeUInt(-Delta) else Result := Result + NativeUInt(Delta);
end;

function ParseRM(const Code: TBytes; Pos: Integer; Rex: Byte; out RM: TDecodedRM): Boolean;
var M, RawRm, RawIndex, RawBase, DispSize: Integer; D: Int64;
begin
  Result := False;
  RM := Default(TDecodedRM);
  if Pos >= Length(Code) then Exit;
  M := Code[Pos];
  RM.Present := True;
  RM.ModValue := Byte(M shr 6);
  RM.RegField := ((M shr 3) and 7) or (((Rex shr 2) and 1) shl 3);
  RawRm := M and 7;
  RM.RmField := RawRm or ((Rex and 1) shl 3);
  Inc(Pos);
  if RM.ModValue = 3 then
  begin
    RM.IsRegister := True;
    RM.EndPos := Pos;
    Exit(True);
  end;
  DispSize := 0;
  if RawRm = 4 then
  begin
    if Pos >= Length(Code) then Exit;
    M := Code[Pos];
    Inc(Pos);
    RM.HasSib := True;
    RM.Scale := 1 shl (M shr 6);
    RawIndex := (M shr 3) and 7;
    RawBase := M and 7;
    if not ((RawIndex = 4) and ((Rex and 2) = 0)) then
    begin
      RM.HasIndex := True;
      RM.IndexReg := RawIndex or (((Rex shr 1) and 1) shl 3);
    end;
    if (RM.ModValue = 0) and (RawBase = 5) then DispSize := 4
    else begin RM.HasBase := True; RM.BaseReg := RawBase or ((Rex and 1) shl 3); end;
  end
  else if (RM.ModValue = 0) and (RawRm = 5) then
  begin
    RM.RipRelative := True;
    DispSize := 4;
  end
  else
  begin
    RM.HasBase := True;
    RM.BaseReg := RM.RmField;
  end;
  if RM.ModValue = 1 then DispSize := 1 else if RM.ModValue = 2 then DispSize := 4;
  if DispSize > 0 then
  begin
    if not ReadSigned(Code, Pos, DispSize, D) then Exit;
    RM.Disp := D;
    Inc(Pos, DispSize);
  end;
  RM.EndPos := Pos;
  Result := True;
end;

function MapOpcodeAt(const Code: TBytes; Pos: Integer; out Map: TOpcodeMap; out OpcodePos: Integer): Boolean;
begin
  Result := False;
  if Pos >= Length(Code) then Exit;
  if Code[Pos] <> $0F then begin Map := omPrimary; OpcodePos := Pos; Exit(True); end;
  Inc(Pos);
  if Pos >= Length(Code) then Exit;
  if Code[Pos] = $38 then begin Map := om0F38; Inc(Pos); end
  else if Code[Pos] = $3A then begin Map := om0F3A; Inc(Pos); end
  else Map := om0F;
  if Pos >= Length(Code) then Exit;
  OpcodePos := Pos;
  Result := True;
end;

function FormNeeds66(const D: TEncodingDescriptor): Boolean;
begin
  Result := D.Raw66 or (D.MandatoryPrefix = mp66) or (D.Legacy66Policy = p66ForceOperandSize) or (D.Legacy66Policy = p66MandatoryOpcode) or ((D.Legacy66Policy = p66ByResolvedGpWidth) and (D.ExpandedWidth = 16)) or (D.NativeCanonicalization = ncLea16Uses66);
end;

function FormNeeds67(const D: TEncodingDescriptor): Boolean;
begin
  Result := D.Raw67 and (D.NativeCanonicalization <> ncLea16Uses66);
end;

function OptionalF2Allowed(const D: TEncodingDescriptor): Boolean;
begin
  Result := (D.AllowedOptionsMask and (DB_AO_REPNE or DB_AO_BND)) <> 0;
end;

function OptionalF3Allowed(const D: TEncodingDescriptor): Boolean;
begin
  Result := (D.AllowedOptionsMask and (DB_AO_REP or DB_AO_REP_IGNORE)) <> 0;
end;

function OperandShapeMatches(FormIndex: Integer; const D: TEncodingDescriptor; const RM: TDecodedRM; Rex: Byte): Boolean;
var I: Integer; Spec: PDbOperandSpec;
begin
  Result := True;
  for I := 0 to D.OperandCount - 1 do
  begin
    Spec := TInstructionDb.Operand(FormIndex, I);
    if (Rex <> 0) and (Spec^.RegClass = rcGp8Hi) then Exit(False);
    if I = D.ModRegOperandIdx then
    begin
      if (Spec^.Kinds and DB_OK_REG) = 0 then Exit(False);
      Continue;
    end;
    if I = D.ModRmOperandIdx then
    begin
      if RM.IsRegister then
      begin
        if (Spec^.Kinds and DB_OK_REG) = 0 then Exit(False);
      end
      else if (Spec^.Kinds and DB_OK_MEM) = 0 then Exit(False);
      Continue;
    end;
    if I = D.OpcodeRegOperandIdx then
    begin
      if (Spec^.Kinds and DB_OK_REG) = 0 then Exit(False);
      Continue;
    end;
    if I = D.ImmediateOperandIdx then
    begin
      if (Spec^.Kinds and DB_OK_IMM) = 0 then Exit(False);
      Continue;
    end;
    if I = D.FixupOperandIdx then
    begin
      if (Spec^.Kinds and DB_OK_REL) = 0 then Exit(False);
      Continue;
    end;
  end;
end;

function TryDecodeForm(const Code: TBytes; FormIndex: Integer; const Prefix: TDecodePrefix; Map: TOpcodeMap; OpcodePos: Integer; out C: TDecodeCandidate): Boolean;
var D: PEncodingDescriptor; Op: Byte; Pos, FixBytes: Integer; ForceW: Boolean;
begin
  Result := False;
  C := Default(TDecodeCandidate);
  D := TInstructionDb.Form(FormIndex);
  if D^.OpcodeMap <> Map then Exit;
  if Prefix.HasF0 and ((D^.AllowedOptionsMask and (DB_AO_LOCK or DB_AO_ILOCK or DB_AO_XACQUIRE or DB_AO_XRELEASE)) = 0) then Exit;
  if Prefix.HasF2 then
  begin
    if (D^.MandatoryPrefix <> mpF2) and not OptionalF2Allowed(D^) then Exit;
  end
  else if D^.MandatoryPrefix = mpF2 then Exit;
  if Prefix.HasF3 then
  begin
    if (D^.MandatoryPrefix <> mpF3) and not OptionalF3Allowed(D^) then Exit;
  end
  else if D^.MandatoryPrefix = mpF3 then Exit;
  if Prefix.Has66 <> FormNeeds66(D^) then Exit;
  if Prefix.Has67 <> FormNeeds67(D^) then Exit;
  ForceW := (D^.RexWPolicy = rwForce) or ((D^.RexWPolicy = rwByResolvedGpWidth) and (D^.ExpandedWidth = 64));
  if ((Prefix.Rex and $08) <> 0) <> ForceW then Exit;
  Op := Code[OpcodePos];
  if D^.OpcodePlusReg then begin if (Op and $F8) <> (D^.Opcode and $F8) then Exit; end
  else if Op <> D^.Opcode then Exit;
  Pos := OpcodePos + 1;
  if D^.ModRMKind <> mkNone then
  begin
    if Pos >= Length(Code) then Exit;
    if (D^.ModRMKind = mkFixedRegField) and (((Code[Pos] shr 3) and 7) <> D^.FixedRegValue) then Exit;
    if (D^.ModRMKind = mkIgnoredRegCanonicalZero) and (((Code[Pos] shr 3) and 7) <> 0) then Exit;
    if (D^.ModRMKind = mkFixedByte) and (Code[Pos] <> D^.FixedModRMByte) then Exit;
    if not ParseRM(Code, Pos, Prefix.Rex, C.RM) then Exit;
    if not OperandShapeMatches(FormIndex, D^, C.RM, Prefix.Rex) then Exit;
    Pos := C.RM.EndPos;
  end
  else if not OperandShapeMatches(FormIndex, D^, C.RM, Prefix.Rex) then Exit;
  C.ImmPos := Pos;
  if D^.HasFixup then
  begin
    case D^.FixupKind of
      dfkRelative8: FixBytes := 1;
      dfkRelative32: FixBytes := 4;
    else
      FixBytes := 0;
    end;
    Inc(Pos, FixBytes);
  end
  else Inc(Pos, D^.ImmediateBytes);
  if Pos > Length(Code) then Exit;
  C.FormIndex := FormIndex;
  C.Prefix := Prefix;
  C.OpcodePos := OpcodePos;
  C.OpcodeByte := Op;
  C.EndPos := Pos;
  C.Score := 0;
  case D^.NativeSupport of
    nsSupported: Inc(C.Score, 8);
    nsPartial: Inc(C.Score, 4);
    nsSourceOnly: Inc(C.Score, 2);
  end;
  if not D^.SourceAlt then Inc(C.Score, 2);
  if D^.ExpandedWidth <> 0 then Inc(C.Score);
  if D^.ModRMKind = mkFixedByte then Inc(C.Score, 4);
  Result := True;
end;

function RegName(Index: Integer; RegClass: TDbRegClass; Rex: Byte): string;
const
  R64: array[0..15] of string = ('rax','rcx','rdx','rbx','rsp','rbp','rsi','rdi','r8','r9','r10','r11','r12','r13','r14','r15');
  R32: array[0..15] of string = ('eax','ecx','edx','ebx','esp','ebp','esi','edi','r8d','r9d','r10d','r11d','r12d','r13d','r14d','r15d');
  R16: array[0..15] of string = ('ax','cx','dx','bx','sp','bp','si','di','r8w','r9w','r10w','r11w','r12w','r13w','r14w','r15w');
  R8L: array[0..15] of string = ('al','cl','dl','bl','spl','bpl','sil','dil','r8b','r9b','r10b','r11b','r12b','r13b','r14b','r15b');
  R8H: array[0..7] of string = ('al','cl','dl','bl','ah','ch','dh','bh');
begin
  if (Index < 0) or (Index > 15) then Exit('?');
  case RegClass of
    rcGp16: Result := R16[Index];
    rcGp32: Result := R32[Index];
    rcGp64: Result := R64[Index];
    rcGp8Lo: Result := R8L[Index];
    rcGp8Hi: if Index <= 7 then Result := R8H[Index] else Result := '?';
    rcGp8Any: if (Rex = 0) and (Index >= 4) and (Index <= 7) then Result := R8H[Index] else Result := R8L[Index];
  else
    Result := R64[Index];
  end;
end;

function MemSizeName(MemClass: TDbMemClass): string;
begin
  case MemClass of
    mc8: Result := 'byte ptr ';
    mc16: Result := 'word ptr ';
    mc32: Result := 'dword ptr ';
    mc64: Result := 'qword ptr ';
  else
    Result := '';
  end;
end;

function SignedHex(Value: Int64): string;
begin
  if Value < 0 then Result := '-$' + IntToHex(UInt64(-(Value + 1)) + 1, 1) else Result := '+$' + IntToHex(UInt64(Value), 1);
end;

function FormatMemory(const RM: TDecodedRM; MemClass: TDbMemClass): string;
var S: string;
begin
  S := '';
  if RM.RipRelative then S := 'rip'
  else if RM.HasBase then S := RegName(RM.BaseReg, rcGp64, $40);
  if RM.HasIndex then
  begin
    if S <> '' then S := S + '+';
    S := S + RegName(RM.IndexReg, rcGp64, $40);
    if RM.Scale <> 1 then S := S + '*' + IntToStr(RM.Scale);
  end;
  if RM.Disp <> 0 then
  begin
    if S = '' then
    begin
      if RM.Disp < 0 then S := '-$' + IntToHex(UInt64(-(RM.Disp + 1)) + 1, 1) else S := '$' + IntToHex(UInt64(RM.Disp), 1);
    end
    else S := S + SignedHex(RM.Disp);
  end;
  if S = '' then S := '0';
  Result := MemSizeName(MemClass) + '[' + S + ']';
end;

function ImmediateText(const Code: TBytes; Pos, Count: Integer; Kind: TImmKind): string;
var U: UInt64; S: Int64;
begin
  if not ReadUnsigned(Code, Pos, Count, U) then Exit('?');
  if Kind in [ikSigned8, ikSigned32] then
  begin
    if not ReadSigned(Code, Pos, Count, S) then Exit('?');
    if S < 0 then Exit('-$' + IntToHex(UInt64(-(S + 1)) + 1, 1));
  end;
  Result := '$' + IntToHex(U, 1);
end;

function FormatDecodedOperand(const Code: TBytes; BaseAddress: NativeUInt; const C: TDecodeCandidate; OperandIndex: Integer): string;
var D: PEncodingDescriptor; Spec: PDbOperandSpec; RegIndex, Count: Integer; Rel: Int64; Target: NativeUInt;
begin
  D := TInstructionDb.Form(C.FormIndex);
  Spec := TInstructionDb.Operand(C.FormIndex, OperandIndex);
  if (Spec^.FixedFlags and DB_FO_HAS_REG) <> 0 then Exit(RegName(Spec^.FixedRegID, Spec^.RegClass, C.Prefix.Rex));
  if OperandIndex = D^.ModRegOperandIdx then Exit(RegName(C.RM.RegField, Spec^.RegClass, C.Prefix.Rex));
  if OperandIndex = D^.ModRmOperandIdx then
  begin
    if C.RM.IsRegister then Exit(RegName(C.RM.RmField, Spec^.RegClass, C.Prefix.Rex));
    Exit(FormatMemory(C.RM, Spec^.MemClass));
  end;
  if OperandIndex = D^.OpcodeRegOperandIdx then
  begin
    RegIndex := (C.OpcodeByte and 7) or ((C.Prefix.Rex and 1) shl 3);
    Exit(RegName(RegIndex, Spec^.RegClass, C.Prefix.Rex));
  end;
  if OperandIndex = D^.ImmediateOperandIdx then Exit(ImmediateText(Code, C.ImmPos, D^.ImmediateBytes, D^.ImmKind));
  if OperandIndex = D^.FixupOperandIdx then
  begin
    case D^.FixupKind of
      dfkRelative8: Count := 1;
      dfkRelative32: Count := 4;
    else
      Count := 0;
    end;
    if not ReadSigned(Code, C.ImmPos, Count, Rel) then Exit('?');
    Target := RelativeAddress(BaseAddress, C.EndPos, Rel);
    Exit('$' + IntToHex(Int64(Target), SizeOf(Pointer) * 2));
  end;
  if (Spec^.FixedFlags and DB_FO_HAS_IMMEDIATE) <> 0 then Exit('$' + IntToHex(Spec^.FixedImm, 1));
  Result := '?';
end;

function FormatPrefixText(const C: TDecodeCandidate; const D: TEncodingDescriptor): string;
begin
  Result := '';
  if C.Prefix.HasF0 then Result := 'lock ';
  if C.Prefix.HasF2 and (D.MandatoryPrefix <> mpF2) then Result := Result + 'repne ';
  if C.Prefix.HasF3 and (D.MandatoryPrefix <> mpF3) then Result := Result + 'rep ';
end;

function FormatDecodedText(const Code: TBytes; BaseAddress: NativeUInt; const C: TDecodeCandidate; out OperandText: string): string;
var D: PEncodingDescriptor; Spec: PDbOperandSpec; I: Integer; Operand, PrefixText: string;
begin
  D := TInstructionDb.Form(C.FormIndex);
  OperandText := '';
  for I := 0 to D^.OperandCount - 1 do
  begin
    Spec := TInstructionDb.Operand(C.FormIndex, I);
    if (Spec^.FixedFlags and DB_FO_IS_IMPLICIT) <> 0 then Continue;
    Operand := FormatDecodedOperand(Code, BaseAddress, C, I);
    if OperandText = '' then OperandText := Operand else OperandText := OperandText + ', ' + Operand;
  end;
  PrefixText := FormatPrefixText(C, D^);
  Result := PrefixText + LowerCase(TInstructionDb.MnemonicName(D^.MnemonicIndex));
  if OperandText <> '' then Result := Result + ' ' + OperandText;
end;

class function TNativeAsmDisassembler.DecodeOne(const Code: TBytes; BaseAddress: NativeUInt; Offset: Integer; out Info: TNativeAsmDisasmInstruction): Boolean;
var Prefix: TDecodePrefix; Map: TOpcodeMap; OpcodePos, I, N, Candidates: Integer; C, Best: TDecodeCandidate; D: PEncodingDescriptor; Rel: Int64;
begin
  Info := Default(TNativeAsmDisasmInstruction);
  Info.FormIndex := -1;
  Result := False;
  if (Offset < 0) or (Offset >= Length(Code)) then Exit;
  Prefix := DecodePrefixes(Code, Offset);
  if not MapOpcodeAt(Code, Prefix.Next, Map, OpcodePos) then
  begin
    Info.Address := BaseAddress + NativeUInt(Offset);
    Info.Offset := Offset;
    Info.Size := 1;
    Info.Mnemonic := 'db';
    Info.Text := 'db $' + IntToHex(Code[Offset], 2);
    Info.IsData := True;
    SetLength(Info.Bytes, 1);
    Info.Bytes[0] := Code[Offset];
    Exit(True);
  end;
  Best.FormIndex := -1;
  Best.Score := Low(Integer);
  Candidates := 0;
  for I := 0 to TInstructionDb.FormCount - 1 do
    if TryDecodeForm(Code, I, Prefix, Map, OpcodePos, C) then
    begin
      Inc(Candidates);
      if C.Score > Best.Score then Best := C;
    end;
  if Best.FormIndex < 0 then
  begin
    Info.Address := BaseAddress + NativeUInt(Offset);
    Info.Offset := Offset;
    Info.Size := 1;
    Info.Mnemonic := 'db';
    Info.Text := 'db $' + IntToHex(Code[Offset], 2);
    Info.IsData := True;
    SetLength(Info.Bytes, 1);
    Info.Bytes[0] := Code[Offset];
    Exit(True);
  end;
  D := TInstructionDb.Form(Best.FormIndex);
  Info.Address := BaseAddress + NativeUInt(Offset);
  Info.Offset := Offset;
  Info.Size := Best.EndPos - Offset;
  Info.Mnemonic := LowerCase(TInstructionDb.MnemonicName(D^.MnemonicIndex));
  Info.Text := FormatDecodedText(Code, BaseAddress, Best, Info.OperandText);
  Info.FormIndex := Best.FormIndex;
  Info.SourceSignature := TInstructionDb.SourceSignature(Best.FormIndex);
  Info.SourceEncoding := TInstructionDb.SourceEncoding(Best.FormIndex);
  Info.NativeSupport := D^.NativeSupport;
  Info.NativeRestriction := D^.NativeRestriction;
  Info.NativeCanonicalization := D^.NativeCanonicalization;
  Info.CandidateCount := Candidates;
  if D^.HasFixup then
  begin
    case D^.FixupKind of
      dfkRelative8: N := 1;
      dfkRelative32: N := 4;
    else
      N := 0;
    end;
    if ReadSigned(Code, Best.ImmPos, N, Rel) then
    begin
      Info.HasTarget := True;
      Info.TargetAddress := RelativeAddress(BaseAddress, Best.EndPos, Rel);
    end;
  end;
  N := Info.Size;
  SetLength(Info.Bytes, N);
  if N > 0 then Move(Code[Offset], Info.Bytes[0], N);
  Result := True;
end;

class function TNativeAsmDisassembler.DecodeAll(const Code: TBytes; BaseAddress: NativeUInt): TArray<TNativeAsmDisasmInstruction>;
var Offset, N: Integer; Info: TNativeAsmDisasmInstruction;
begin
  SetLength(Result, 0);
  Offset := 0;
  while Offset < Length(Code) do
  begin
    if not DecodeOne(Code, BaseAddress, Offset, Info) then Break;
    N := Length(Result);
    SetLength(Result, N + 1);
    Result[N] := Info;
    if Info.Size <= 0 then Break;
    Inc(Offset, Info.Size);
  end;
end;

function BytesText(const Bytes: TBytes): string;
var I: Integer;
begin
  Result := '';
  for I := 0 to High(Bytes) do
  begin
    if Result <> '' then Result := Result + ' ';
    Result := Result + IntToHex(Bytes[I], 2);
  end;
end;

class function TNativeAsmDisassembler.FormatInstruction(const Info: TNativeAsmDisasmInstruction; ShowAddress, ShowBytes: Boolean): string;
var B: string;
begin
  Result := '+$' + IntToHex(Info.Offset, 4) + '  ';
  if ShowAddress then Result := Result + '$' + IntToHex(Int64(Info.Address), SizeOf(Pointer) * 2) + '  ';
  if ShowBytes then
  begin
    B := BytesText(Info.Bytes);
    Result := Result + B;
    if Length(B) < 35 then Result := Result + StringOfChar(' ', 35 - Length(B)) else Result := Result + ' ';
  end;
  Result := Result + Info.Text;
end;

class function TNativeAsmDisassembler.FormatAll(const Code: TBytes; BaseAddress: NativeUInt): string;
var SB: TStringBuilder; Items: TArray<TNativeAsmDisasmInstruction>; I: Integer;
begin
  Items := DecodeAll(Code, BaseAddress);
  SB := TStringBuilder.Create;
  try
    for I := 0 to High(Items) do SB.AppendLine(FormatInstruction(Items[I]));
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

end.
