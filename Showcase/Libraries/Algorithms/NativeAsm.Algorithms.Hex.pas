{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
unit NativeAsm.Algorithms.Hex;

interface

uses
  System.SysUtils,
  NativeAsm.Types,
  NativeAsm.Builder,
  NativeAsm.Extensions,
  NativeAsm.CpuFeatures;

type
  THexMode = (hmAuto, hmScalar, hmSsse3);

  THexJit = class
  private type
    TByte16 = array[0..15] of Byte;
    TByte256 = array[0..255] of Byte;
  private
    FEncodeCode: TExecutableCode;
    FDecodeCode: TExecutableCode;
    FHexUpper: TByte16;
    FMask0F: TByte16;
    FDecodeMin: TByte16;
    FDecodeMax: TByte16;
    FDecodeOffset: TByte16;
    FPackMul: TByte16;
    FDecodeTable: TByte256;
    FMode: THexMode;
    procedure BuildConstants;
    function BuildEncodeKernel: TExecutableCode;
    function BuildDecodeKernel: TExecutableCode;
    class function ResolveMode(Mode: THexMode): THexMode; static;
    class procedure ValidateBuffer(Buffer: Pointer; Length: NativeUInt; const Name: string); static;
  public
    constructor Create(Mode: THexMode = hmAuto);
    destructor Destroy; override;
    procedure Encode(Source: Pointer; Length: NativeUInt; Dest: Pointer); overload;
    function Encode(const Data: TBytes): TBytes; overload;
    function TryDecode(Source: Pointer; Length: NativeUInt; Dest: Pointer; out InvalidIndex: NativeInt): Boolean; overload;
    function TryDecode(const Hex: TBytes; out Data: TBytes; out InvalidIndex: NativeInt): Boolean; overload;
    property Mode: THexMode read FMode;
  end;

implementation

uses
  NativeAsm.Simd,
  NativeAsm.Simd.Types;

class procedure THexJit.ValidateBuffer(Buffer: Pointer; Length: NativeUInt; const Name: string);
begin
  if (Buffer = nil) and (Length <> 0) then raise EArgumentNilException.Create(Name);
end;

class function THexJit.ResolveMode(Mode: THexMode): THexMode;
begin
  case Mode of
    hmAuto: if TCpuFeatures.Supports(cfSSSE3) then Result := hmSsse3 else Result := hmScalar;
    hmScalar: Result := hmScalar;
    hmSsse3:
      begin
        if not TCpuFeatures.Supports(cfSSSE3) then raise EInvalidOp.Create('SSSE3 is not available on this CPU');
        Result := hmSsse3;
      end;
  else
    raise EArgumentException.Create('Invalid hex mode');
  end;
end;

procedure THexJit.BuildConstants;
var
  I: Integer;
begin
  for I := 0 to 15 do
  begin
    if I < 10 then FHexUpper[I] := Byte(Ord('0') + I) else FHexUpper[I] := Byte(Ord('A') + I - 10);
    FMask0F[I] := $0F;
    FDecodeMin[I] := $7F;
    FDecodeMax[I] := 0;
    FDecodeOffset[I] := 0;
    if (I and 1) = 0 then FPackMul[I] := 16 else FPackMul[I] := 1;
  end;
  FDecodeMin[3] := 0;
  FDecodeMax[3] := 9;
  FDecodeMin[4] := 1;
  FDecodeMax[4] := 6;
  FDecodeOffset[4] := 9;
  FDecodeMin[6] := 1;
  FDecodeMax[6] := 6;
  FDecodeOffset[6] := 9;
  for I := 0 to 255 do FDecodeTable[I] := $FF;
  for I := 0 to 9 do FDecodeTable[Ord('0') + I] := Byte(I);
  for I := 0 to 5 do
  begin
    FDecodeTable[Ord('A') + I] := Byte(I + 10);
    FDecodeTable[Ord('a') + I] := Byte(I + 10);
  end;
end;

function THexJit.BuildEncodeKernel: TExecutableCode;
var
  Builder: TAsmBuilder;
  LVectorLoop, LScalarLoop, LTail, LDone: TLabel;
begin
  Builder := TAsmBuilder.Create;
  try
    LScalarLoop := Builder.NewLabel;
    LTail := Builder.NewLabel;
    LDone := Builder.NewLabel;
    Builder.Mov(R9, Int64(NativeUInt(@FHexUpper[0])));
    if FMode = hmSsse3 then
    begin
      LVectorLoop := Builder.NewLabel;
      Builder.Mov(R10, Int64(NativeUInt(@FMask0F[0]))).Movdqu(XMM4, NativeAsm.Simd.Types.OWordPtr(ridR10)).Movdqu(XMM5, NativeAsm.Simd.Types.OWordPtr(ridR9));
      Builder.Cmp(RDX, 16).J(cond_JB, LTail).Bind(LVectorLoop);
      Builder.Movdqu(XMM0, NativeAsm.Simd.Types.OWordPtr(ridRCX)).Movdqa(XMM1, XMM0).Pand(XMM0, XMM4).Psrlw(XMM1, 4).Pand(XMM1, XMM4);
      Builder.Movdqa(XMM2, XMM1).Punpcklbw(XMM2, XMM0).Punpckhbw(XMM1, XMM0);
      Builder.Movdqa(XMM3, XMM5).Pshufb(XMM3, XMM2).Movdqa(XMM2, XMM5).Pshufb(XMM2, XMM1);
      Builder.Movdqu(NativeAsm.Simd.Types.OWordPtr(ridR8), XMM3).Movdqu(NativeAsm.Simd.Types.OWordPtr(ridR8, 16), XMM2);
      Builder.Add(RCX, 16).Add(R8, 32).Sub(RDX, 16).Cmp(RDX, 16).J(cond_JAE, LVectorLoop);
      Builder.Bind(LTail).Test(RDX, RDX).J(cond_JE, LDone).Bind(LScalarLoop);
    end
    else
      Builder.Test(RDX, RDX).J(cond_JE, LDone).Bind(LScalarLoop);
    Builder.Movzx(EAX, BytePtr(ridRCX)).Mov(R10D, EAX).Shr_(R10D, 4).And_(EAX, $0F);
    Builder.Movzx(R10D, TMemory.CreateSib(ridR9, ridR10, s1, 0, sz8)).Mov(BytePtr(ridR8), R10B);
    Builder.Movzx(EAX, TMemory.CreateSib(ridR9, ridRAX, s1, 0, sz8)).Mov(BytePtr(ridR8, 1), AL);
    Builder.Inc_(RCX).Add(R8, 2).Dec_(RDX).J(cond_JNE, LScalarLoop).Bind(LDone).Ret;
    Result := TExecutableCode.FromBuilder(Builder);
  finally
    Builder.Free;
  end;
end;

function THexJit.BuildDecodeKernel: TExecutableCode;
var
  Builder: TAsmBuilder;
  LVectorLoop, LScalarLoop, LTail, LVectorInvalid, LInvalid0, LInvalid1, LDone: TLabel;
begin
  Builder := TAsmBuilder.Create;
  try
    LScalarLoop := Builder.NewLabel;
    LTail := Builder.NewLabel;
    LVectorInvalid := Builder.NewLabel;
    LInvalid0 := Builder.NewLabel;
    LInvalid1 := Builder.NewLabel;
    LDone := Builder.NewLabel;
    Builder.Mov(R9, RCX);
    if FMode = hmSsse3 then
    begin
      LVectorLoop := Builder.NewLabel;
      Builder.Mov(R10, Int64(NativeUInt(@FMask0F[0]))).Movdqu(XMM5, NativeAsm.Simd.Types.OWordPtr(ridR10));
      Builder.Cmp(RDX, 16).J(cond_JB, LTail).Bind(LVectorLoop);
      Builder.Movdqu(XMM0, NativeAsm.Simd.Types.OWordPtr(ridRCX)).Movdqa(XMM1, XMM0).Psrlw(XMM1, 4).Pand(XMM1, XMM5).Pand(XMM0, XMM5).Movdqa(XMM2, XMM0);
      Builder.Mov(R10, Int64(NativeUInt(@FDecodeMin[0]))).Movdqu(XMM3, NativeAsm.Simd.Types.OWordPtr(ridR10)).Pshufb(XMM3, XMM1);
      Builder.Mov(R10, Int64(NativeUInt(@FDecodeMax[0]))).Movdqu(XMM4, NativeAsm.Simd.Types.OWordPtr(ridR10)).Pshufb(XMM4, XMM1);
      Builder.Movdqa(XMM0, XMM3).Pcmpgtb(XMM0, XMM2).Movdqa(XMM3, XMM2).Pcmpgtb(XMM3, XMM4).Por(XMM0, XMM3).Pmovmskb(EAX, XMM0).Test(EAX, EAX).J(cond_JNE, LVectorInvalid);
      Builder.Mov(R10, Int64(NativeUInt(@FDecodeOffset[0]))).Movdqu(XMM3, NativeAsm.Simd.Types.OWordPtr(ridR10)).Pshufb(XMM3, XMM1).Paddb(XMM2, XMM3);
      Builder.Mov(R10, Int64(NativeUInt(@FPackMul[0]))).Movdqu(XMM3, NativeAsm.Simd.Types.OWordPtr(ridR10)).Pmaddubsw(XMM2, XMM3).Pxor(XMM3, XMM3).Packuswb(XMM2, XMM3).Movq(QWordPtr(ridR8), XMM2);
      Builder.Add(RCX, 16).Add(R8, 8).Sub(RDX, 16).Cmp(RDX, 16).J(cond_JAE, LVectorLoop);
      Builder.Bind(LTail);
    end;
    Builder.Mov(R10, Int64(NativeUInt(@FDecodeTable[0]))).Test(RDX, RDX).J(cond_JE, LDone).Bind(LScalarLoop);
    Builder.Movzx(EAX, BytePtr(ridRCX)).Movzx(EAX, TMemory.CreateSib(ridR10, ridRAX, s1, 0, sz8)).Cmp(EAX, $FF).J(cond_JE, LInvalid0);
    Builder.Movzx(R11D, BytePtr(ridRCX, 1)).Movzx(R11D, TMemory.CreateSib(ridR10, ridR11, s1, 0, sz8)).Cmp(R11D, $FF).J(cond_JE, LInvalid1);
    Builder.Shl_(EAX, 4).Or_(EAX, R11D).Mov(BytePtr(ridR8), AL).Add(RCX, 2).Inc_(R8).Sub(RDX, 2).J(cond_JNE, LScalarLoop).J(cond_JMP, LDone);
    if FMode = hmSsse3 then
      Builder.Bind(LVectorInvalid).Bsf(R10D, EAX).Sub(RCX, R9).Add(R10, RCX).Mov(RAX, R10).Ret;
    Builder.Bind(LInvalid0).Sub(RCX, R9).Mov(RAX, RCX).Ret;
    Builder.Bind(LInvalid1).Sub(RCX, R9).Mov(RAX, RCX).Inc_(RAX).Ret;
    Builder.Bind(LDone).Mov(RAX, -1).Ret;
    Result := TExecutableCode.FromBuilder(Builder);
  finally
    Builder.Free;
  end;
end;

constructor THexJit.Create(Mode: THexMode);
begin
  inherited Create;
  FMode := ResolveMode(Mode);
  BuildConstants;
  FEncodeCode := BuildEncodeKernel;
  FDecodeCode := BuildDecodeKernel;
end;

destructor THexJit.Destroy;
begin
  FDecodeCode.Free;
  FEncodeCode.Free;
  inherited;
end;

procedure THexJit.Encode(Source: Pointer; Length: NativeUInt; Dest: Pointer);
begin
  ValidateBuffer(Source, Length, 'Source');
  ValidateBuffer(Dest, Length, 'Dest');
  FEncodeCode.Run(UInt64(NativeUInt(Source)), UInt64(Length), UInt64(NativeUInt(Dest)));
end;

function THexJit.Encode(const Data: TBytes): TBytes;
var
  Count: NativeUInt;
begin
  Count := NativeUInt(Length(Data));
  if Count > NativeUInt(MaxInt div 2) then raise ERangeError.Create('Hex output exceeds Delphi array limits');
  SetLength(Result, Integer(Count * 2));
  if Count <> 0 then Encode(@Data[0], Count, @Result[0]);
end;

function THexJit.TryDecode(Source: Pointer; Length: NativeUInt; Dest: Pointer; out InvalidIndex: NativeInt): Boolean;
var
  R: Int64;
begin
  ValidateBuffer(Source, Length, 'Source');
  if (Length and 1) <> 0 then
  begin
    InvalidIndex := NativeInt(Length - 1);
    Exit(False);
  end;
  ValidateBuffer(Dest, Length shr 1, 'Dest');
  R := Int64(FDecodeCode.Run(UInt64(NativeUInt(Source)), UInt64(Length), UInt64(NativeUInt(Dest))));
  InvalidIndex := NativeInt(R);
  Result := R < 0;
end;

function THexJit.TryDecode(const Hex: TBytes; out Data: TBytes; out InvalidIndex: NativeInt): Boolean;
var
  Count: Integer;
begin
  Count := Length(Hex);
  if (Count and 1) <> 0 then
  begin
    SetLength(Data, 0);
    InvalidIndex := Count - 1;
    Exit(False);
  end;
  SetLength(Data, Count div 2);
  if Count = 0 then
  begin
    InvalidIndex := -1;
    Exit(True);
  end;
  Result := TryDecode(@Hex[0], NativeUInt(Count), @Data[0], InvalidIndex);
  if not Result then SetLength(Data, 0);
end;

end.
