{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
unit NativeAsm.Algorithms.Base64;

interface

uses
  System.SysUtils,
  NativeAsm.Types,
  NativeAsm.Builder,
  NativeAsm.Extensions,
  NativeAsm.CpuFeatures;

type
  TBase64Mode = (b64mAuto, b64mScalar, b64mSsse3);

  TBase64Jit = class
  private type
    TByte16 = array[0..15] of Byte;
    TByte256 = array[0..255] of Byte;
  private
    FEncodeCode: TExecutableCode;
    FDecodeCode: TExecutableCode;
    FAlphabet: array[0..63] of Byte;
    FDecodeTable: TByte256;
    FEncShuffle: TByte16;
    FEncMaskA: TByte16;
    FEncMulHi: TByte16;
    FEncMaskB: TByte16;
    FEncMulLo: TByte16;
    FEncLut: TByte16;
    FEnc51: TByte16;
    FEnc25: TByte16;
    FDecMask2F: TByte16;
    FDecLutLo: TByte16;
    FDecLutHi: TByte16;
    FDecRoll: TByte16;
    FDecSlash: TByte16;
    FDecMul1: TByte16;
    FDecMul2: TByte16;
    FDecShuffle: TByte16;
    FMode: TBase64Mode;
    procedure BuildConstants;
    function BuildEncodeKernel: TExecutableCode;
    function BuildDecodeKernel: TExecutableCode;
    class function ResolveMode(Mode: TBase64Mode): TBase64Mode; static;
    class procedure ValidateBuffer(Buffer: Pointer; Length: NativeUInt; const Name: string); static;
    class function EncodedLength(Length: NativeUInt): NativeUInt; static;
    class function DecodedLengthFromPadding(Source: Pointer; Length: NativeUInt): NativeUInt; static;
  public
    constructor Create(Mode: TBase64Mode = b64mAuto);
    destructor Destroy; override;
    procedure Encode(Source: Pointer; Length: NativeUInt; Dest: Pointer); overload;
    function Encode(const Data: TBytes): TBytes; overload;
    function TryDecode(Source: Pointer; Length: NativeUInt; Dest: Pointer; out DecodedLength: NativeUInt; out InvalidIndex: NativeInt): Boolean; overload;
    function TryDecode(const Text: TBytes; out Data: TBytes; out InvalidIndex: NativeInt): Boolean; overload;
    property Mode: TBase64Mode read FMode;
  end;

implementation

uses
  NativeAsm.Simd,
  NativeAsm.Simd.Types;

class procedure TBase64Jit.ValidateBuffer(Buffer: Pointer; Length: NativeUInt; const Name: string);
begin
  if (Buffer = nil) and (Length <> 0) then raise EArgumentNilException.Create(Name);
end;

class function TBase64Jit.ResolveMode(Mode: TBase64Mode): TBase64Mode;
begin
  case Mode of
    b64mAuto: if TCpuFeatures.Supports(cfSSSE3) then Result := b64mSsse3 else Result := b64mScalar;
    b64mScalar: Result := b64mScalar;
    b64mSsse3:
      begin
        if not TCpuFeatures.Supports(cfSSSE3) then raise EInvalidOp.Create('SSSE3 is not available on this CPU');
        Result := b64mSsse3;
      end;
  else
    raise EArgumentException.Create('Invalid Base64 mode');
  end;
end;

class function TBase64Jit.EncodedLength(Length: NativeUInt): NativeUInt;
var
  Groups: NativeUInt;
begin
  Groups := Length div 3;
  if (Length mod 3) <> 0 then Inc(Groups);
  if Groups > High(NativeUInt) div 4 then raise ERangeError.Create('Base64 output size overflow');
  Result := Groups * 4;
end;

class function TBase64Jit.DecodedLengthFromPadding(Source: Pointer; Length: NativeUInt): NativeUInt;
var
  P: PByte;
begin
  if Length = 0 then Exit(0);
  P := Source;
  Result := (Length div 4) * 3;
  if P[Length - 1] = Ord('=') then
  begin
    Dec(Result);
    if P[Length - 2] = Ord('=') then Dec(Result);
  end;
end;

procedure TBase64Jit.BuildConstants;
const
  Alphabet: AnsiString = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
  EncShuffle: TByte16 = (1,0,2,1,4,3,5,4,7,6,8,7,10,9,11,10);
  EncLut: TByte16 = (65,71,252,252,252,252,252,252,252,252,252,252,237,240,0,0);
  DecLutLo: TByte16 = ($15,$11,$11,$11,$11,$11,$11,$11,$11,$11,$13,$1A,$1B,$1B,$1B,$1A);
  DecLutHi: TByte16 = ($10,$10,$01,$02,$04,$08,$04,$08,$10,$10,$10,$10,$10,$10,$10,$10);
  DecRoll: TByte16 = (0,16,19,4,191,191,185,185,0,0,0,0,0,0,0,0);
  DecShuffle: TByte16 = (2,1,0,6,5,4,10,9,8,14,13,12,$80,$80,$80,$80);
var
  I: Integer;
begin
  for I := 0 to 63 do FAlphabet[I] := Byte(Ord(Alphabet[I + 1]));
  for I := 0 to 255 do FDecodeTable[I] := $FF;
  for I := 0 to 63 do FDecodeTable[FAlphabet[I]] := Byte(I);
  for I := 0 to 15 do
  begin
    FEncShuffle[I] := EncShuffle[I];
    FEncLut[I] := EncLut[I];
    FDecLutLo[I] := DecLutLo[I];
    FDecLutHi[I] := DecLutHi[I];
    FDecRoll[I] := DecRoll[I];
    FDecShuffle[I] := DecShuffle[I];
    FEnc51[I] := 51;
    FEnc25[I] := 25;
    FDecMask2F[I] := $2F;
    FDecSlash[I] := Ord('/');
    case I and 3 of
      0: begin FEncMaskA[I] := $00; FEncMaskB[I] := $F0; FEncMulHi[I] := $40; FEncMulLo[I] := $10; FDecMul1[I] := $40; FDecMul2[I] := $00; end;
      1: begin FEncMaskA[I] := $FC; FEncMaskB[I] := $03; FEncMulHi[I] := $00; FEncMulLo[I] := $00; FDecMul1[I] := $01; FDecMul2[I] := $10; end;
      2: begin FEncMaskA[I] := $C0; FEncMaskB[I] := $3F; FEncMulHi[I] := $00; FEncMulLo[I] := $00; FDecMul1[I] := $40; FDecMul2[I] := $01; end;
      3: begin FEncMaskA[I] := $0F; FEncMaskB[I] := $00; FEncMulHi[I] := $04; FEncMulLo[I] := $01; FDecMul1[I] := $01; FDecMul2[I] := $00; end;
    end;
  end;
end;

function TBase64Jit.BuildEncodeKernel: TExecutableCode;
var
  B: TAsmBuilder;
  LVectorLoop, LScalarCheck, LScalarLoop, LTail1, LTail2, LDone: TLabel;
begin
  B := TAsmBuilder.Create;
  try
    LScalarCheck := B.NewLabel;
    LScalarLoop := B.NewLabel;
    LTail1 := B.NewLabel;
    LTail2 := B.NewLabel;
    LDone := B.NewLabel;
    B.Mov(R9, Int64(NativeUInt(@FAlphabet[0])));
    if FMode = b64mSsse3 then
    begin
      LVectorLoop := B.NewLabel;
      B.Cmp(RDX, 15).J(cond_JBE, LScalarCheck).Bind(LVectorLoop);
      B.Movdqu(XMM0, NativeAsm.Simd.Types.OWordPtr(ridRCX));
      B.Mov(R10, Int64(NativeUInt(@FEncShuffle[0]))).Movdqu(XMM3, NativeAsm.Simd.Types.OWordPtr(ridR10)).Pshufb(XMM0, XMM3);
      B.Movdqa(XMM1, XMM0).Mov(R10, Int64(NativeUInt(@FEncMaskA[0]))).Movdqu(XMM3, NativeAsm.Simd.Types.OWordPtr(ridR10)).Pand(XMM1, XMM3);
      B.Mov(R10, Int64(NativeUInt(@FEncMulHi[0]))).Movdqu(XMM3, NativeAsm.Simd.Types.OWordPtr(ridR10)).Pmulhuw(XMM1, XMM3);
      B.Movdqa(XMM2, XMM0).Mov(R10, Int64(NativeUInt(@FEncMaskB[0]))).Movdqu(XMM3, NativeAsm.Simd.Types.OWordPtr(ridR10)).Pand(XMM2, XMM3);
      B.Mov(R10, Int64(NativeUInt(@FEncMulLo[0]))).Movdqu(XMM3, NativeAsm.Simd.Types.OWordPtr(ridR10)).Pmullw(XMM2, XMM3).Por(XMM1, XMM2);
      B.Movdqa(XMM0, XMM1).Mov(R10, Int64(NativeUInt(@FEnc51[0]))).Movdqu(XMM3, NativeAsm.Simd.Types.OWordPtr(ridR10)).Psubusb(XMM0, XMM3);
      B.Movdqa(XMM2, XMM1).Mov(R10, Int64(NativeUInt(@FEnc25[0]))).Movdqu(XMM3, NativeAsm.Simd.Types.OWordPtr(ridR10)).Pcmpgtb(XMM2, XMM3).Psubb(XMM0, XMM2);
      B.Mov(R10, Int64(NativeUInt(@FEncLut[0]))).Movdqu(XMM2, NativeAsm.Simd.Types.OWordPtr(ridR10)).Pshufb(XMM2, XMM0).Paddb(XMM1, XMM2);
      B.Movdqu(NativeAsm.Simd.Types.OWordPtr(ridR8), XMM1).Add(RCX, 12).Add(R8, 16).Sub(RDX, 12).Cmp(RDX, 15).J(cond_JA, LVectorLoop);
    end;
    B.Bind(LScalarCheck).Cmp(RDX, 3).J(cond_JB, LTail1).Bind(LScalarLoop);
    B.Movzx(R10D, BytePtr(ridRCX)).Mov(EAX, R10D).Shr_(EAX, 2).Movzx(EAX, TMemory.CreateSib(ridR9, ridRAX, s1, 0, sz8)).Mov(BytePtr(ridR8), AL);
    B.Movzx(R11D, BytePtr(ridRCX, 1)).And_(R10D, 3).Shl_(R10D, 4).Mov(EAX, R11D).Shr_(EAX, 4).Or_(R10D, EAX).Movzx(EAX, TMemory.CreateSib(ridR9, ridR10, s1, 0, sz8)).Mov(BytePtr(ridR8, 1), AL);
    B.Movzx(R10D, BytePtr(ridRCX, 2)).And_(R11D, $0F).Shl_(R11D, 2).Mov(EAX, R10D).Shr_(EAX, 6).Or_(R11D, EAX).Movzx(EAX, TMemory.CreateSib(ridR9, ridR11, s1, 0, sz8)).Mov(BytePtr(ridR8, 2), AL);
    B.And_(R10D, $3F).Movzx(EAX, TMemory.CreateSib(ridR9, ridR10, s1, 0, sz8)).Mov(BytePtr(ridR8, 3), AL);
    B.Add(RCX, 3).Add(R8, 4).Sub(RDX, 3).Cmp(RDX, 3).J(cond_JAE, LScalarLoop);
    B.Bind(LTail1).Test(RDX, RDX).J(cond_JE, LDone).Cmp(RDX, 1).J(cond_JNE, LTail2);
    B.Movzx(R10D, BytePtr(ridRCX)).Mov(EAX, R10D).Shr_(EAX, 2).Movzx(EAX, TMemory.CreateSib(ridR9, ridRAX, s1, 0, sz8)).Mov(BytePtr(ridR8), AL);
    B.And_(R10D, 3).Shl_(R10D, 4).Movzx(EAX, TMemory.CreateSib(ridR9, ridR10, s1, 0, sz8)).Mov(BytePtr(ridR8, 1), AL).Mov(EAX, Ord('=')).Mov(BytePtr(ridR8, 2), AL).Mov(BytePtr(ridR8, 3), AL).J(cond_JMP, LDone);
    B.Bind(LTail2);
    B.Movzx(R10D, BytePtr(ridRCX)).Mov(EAX, R10D).Shr_(EAX, 2).Movzx(EAX, TMemory.CreateSib(ridR9, ridRAX, s1, 0, sz8)).Mov(BytePtr(ridR8), AL);
    B.Movzx(R11D, BytePtr(ridRCX, 1)).And_(R10D, 3).Shl_(R10D, 4).Mov(EAX, R11D).Shr_(EAX, 4).Or_(R10D, EAX).Movzx(EAX, TMemory.CreateSib(ridR9, ridR10, s1, 0, sz8)).Mov(BytePtr(ridR8, 1), AL);
    B.And_(R11D, $0F).Shl_(R11D, 2).Movzx(EAX, TMemory.CreateSib(ridR9, ridR11, s1, 0, sz8)).Mov(BytePtr(ridR8, 2), AL).Mov(EAX, Ord('=')).Mov(BytePtr(ridR8, 3), AL);
    B.Bind(LDone).Ret;
    Result := TExecutableCode.FromBuilder(B);
  finally
    B.Free;
  end;
end;

function TBase64Jit.BuildDecodeKernel: TExecutableCode;
var
  B: TAsmBuilder;
  LVectorLoop, LVectorInvalid, LScalarStart, LScalarLoop, LFinal, LTwoPad, LOnePad, LSuccess: TLabel;
  LInvalid0, LInvalid1, LInvalid2, LInvalid3: TLabel;
begin
  B := TAsmBuilder.Create;
  try
    LVectorInvalid := B.NewLabel;
    LScalarStart := B.NewLabel;
    LScalarLoop := B.NewLabel;
    LFinal := B.NewLabel;
    LTwoPad := B.NewLabel;
    LOnePad := B.NewLabel;
    LSuccess := B.NewLabel;
    LInvalid0 := B.NewLabel;
    LInvalid1 := B.NewLabel;
    LInvalid2 := B.NewLabel;
    LInvalid3 := B.NewLabel;
    B.Test(RDX, RDX).J(cond_JE, LSuccess);
    if FMode = b64mSsse3 then
    begin
      LVectorLoop := B.NewLabel;
      B.Cmp(RDX, 16).J(cond_JBE, LScalarStart).Bind(LVectorLoop);
      B.Movdqu(XMM0, NativeAsm.Simd.Types.OWordPtr(ridRCX)).Movdqa(XMM1, XMM0).Psrld(XMM1, 4);
      B.Mov(R10, Int64(NativeUInt(@FDecMask2F[0]))).Movdqu(XMM5, NativeAsm.Simd.Types.OWordPtr(ridR10)).Pand(XMM1, XMM5).Movdqa(XMM2, XMM0).Pand(XMM2, XMM5);
      B.Mov(R10, Int64(NativeUInt(@FDecLutHi[0]))).Movdqu(XMM3, NativeAsm.Simd.Types.OWordPtr(ridR10)).Pshufb(XMM3, XMM1);
      B.Mov(R10, Int64(NativeUInt(@FDecLutLo[0]))).Movdqu(XMM4, NativeAsm.Simd.Types.OWordPtr(ridR10)).Pshufb(XMM4, XMM2).Pand(XMM4, XMM3).Pxor(XMM5, XMM5).Pcmpgtb(XMM4, XMM5).Pmovmskb(EAX, XMM4).Test(EAX, EAX).J(cond_JNE, LVectorInvalid);
      B.Movdqa(XMM2, XMM0).Mov(R10, Int64(NativeUInt(@FDecSlash[0]))).Movdqu(XMM5, NativeAsm.Simd.Types.OWordPtr(ridR10)).Pcmpeqb(XMM2, XMM5).Paddb(XMM2, XMM1);
      B.Mov(R10, Int64(NativeUInt(@FDecRoll[0]))).Movdqu(XMM3, NativeAsm.Simd.Types.OWordPtr(ridR10)).Pshufb(XMM3, XMM2).Paddb(XMM0, XMM3);
      B.Mov(R10, Int64(NativeUInt(@FDecMul1[0]))).Movdqu(XMM3, NativeAsm.Simd.Types.OWordPtr(ridR10)).Pmaddubsw(XMM0, XMM3);
      B.Mov(R10, Int64(NativeUInt(@FDecMul2[0]))).Movdqu(XMM3, NativeAsm.Simd.Types.OWordPtr(ridR10)).Pmaddwd(XMM0, XMM3);
      B.Mov(R10, Int64(NativeUInt(@FDecShuffle[0]))).Movdqu(XMM3, NativeAsm.Simd.Types.OWordPtr(ridR10)).Pshufb(XMM0, XMM3);
      B.Movq(QWordPtr(ridR8), XMM0).Psrldq(XMM0, 8).Movd(DWordPtr(ridR8, 8), XMM0);
      B.Add(RCX, 16).Add(R8, 12).Sub(RDX, 16).Cmp(RDX, 16).J(cond_JA, LVectorLoop).J(cond_JMP, LScalarStart);
      B.Bind(LVectorInvalid).Bsf(R11D, EAX).Mov(RAX, RCX).Add(RAX, R11).Ret;
    end;
    B.Bind(LScalarStart).Mov(R10, Int64(NativeUInt(@FDecodeTable[0]))).Cmp(RDX, 4).J(cond_JE, LFinal).Bind(LScalarLoop);
    B.Movzx(EAX, BytePtr(ridRCX)).Movzx(R11D, TMemory.CreateSib(ridR10, ridRAX, s1, 0, sz8)).Cmp(R11D, 63).J(cond_JA, LInvalid0);
    B.Movzx(EAX, BytePtr(ridRCX, 1)).Movzx(R9D, TMemory.CreateSib(ridR10, ridRAX, s1, 0, sz8)).Cmp(R9D, 63).J(cond_JA, LInvalid1);
    B.Mov(EAX, R11D).Shl_(EAX, 2).Mov(R11D, R9D).Shr_(R11D, 4).Or_(EAX, R11D).Mov(BytePtr(ridR8), AL);
    B.Movzx(EAX, BytePtr(ridRCX, 2)).Movzx(R11D, TMemory.CreateSib(ridR10, ridRAX, s1, 0, sz8)).Cmp(R11D, 63).J(cond_JA, LInvalid2);
    B.Mov(EAX, R9D).And_(EAX, $0F).Shl_(EAX, 4).Mov(R9D, R11D).Shr_(R9D, 2).Or_(EAX, R9D).Mov(BytePtr(ridR8, 1), AL);
    B.Movzx(EAX, BytePtr(ridRCX, 3)).Movzx(R9D, TMemory.CreateSib(ridR10, ridRAX, s1, 0, sz8)).Cmp(R9D, 63).J(cond_JA, LInvalid3);
    B.Mov(EAX, R11D).And_(EAX, 3).Shl_(EAX, 6).Or_(EAX, R9D).Mov(BytePtr(ridR8, 2), AL);
    B.Add(RCX, 4).Add(R8, 3).Sub(RDX, 4).Cmp(RDX, 4).J(cond_JA, LScalarLoop).J(cond_JMP, LFinal);
    B.Bind(LFinal);
    B.Movzx(EAX, BytePtr(ridRCX)).Movzx(R11D, TMemory.CreateSib(ridR10, ridRAX, s1, 0, sz8)).Cmp(R11D, 63).J(cond_JA, LInvalid0);
    B.Movzx(EAX, BytePtr(ridRCX, 1)).Movzx(R9D, TMemory.CreateSib(ridR10, ridRAX, s1, 0, sz8)).Cmp(R9D, 63).J(cond_JA, LInvalid1);
    B.Mov(EAX, R11D).Shl_(EAX, 2).Mov(R11D, R9D).Shr_(R11D, 4).Or_(EAX, R11D).Mov(BytePtr(ridR8), AL);
    B.Cmp(BytePtr(ridRCX, 2), Ord('=')).J(cond_JE, LTwoPad);
    B.Movzx(EAX, BytePtr(ridRCX, 2)).Movzx(R11D, TMemory.CreateSib(ridR10, ridRAX, s1, 0, sz8)).Cmp(R11D, 63).J(cond_JA, LInvalid2);
    B.Mov(EAX, R9D).And_(EAX, $0F).Shl_(EAX, 4).Mov(R9D, R11D).Shr_(R9D, 2).Or_(EAX, R9D).Mov(BytePtr(ridR8, 1), AL);
    B.Cmp(BytePtr(ridRCX, 3), Ord('=')).J(cond_JE, LOnePad);
    B.Movzx(EAX, BytePtr(ridRCX, 3)).Movzx(R9D, TMemory.CreateSib(ridR10, ridRAX, s1, 0, sz8)).Cmp(R9D, 63).J(cond_JA, LInvalid3);
    B.Mov(EAX, R11D).And_(EAX, 3).Shl_(EAX, 6).Or_(EAX, R9D).Mov(BytePtr(ridR8, 2), AL).J(cond_JMP, LSuccess);
    B.Bind(LTwoPad).Cmp(BytePtr(ridRCX, 3), Ord('=')).J(cond_JNE, LInvalid2).Test(R9D, $0F).J(cond_JNE, LInvalid1).J(cond_JMP, LSuccess);
    B.Bind(LOnePad).Test(R11D, 3).J(cond_JNE, LInvalid2).J(cond_JMP, LSuccess);
    B.Bind(LInvalid0).Mov(RAX, RCX).Ret;
    B.Bind(LInvalid1).Mov(RAX, RCX).Add(RAX, 1).Ret;
    B.Bind(LInvalid2).Mov(RAX, RCX).Add(RAX, 2).Ret;
    B.Bind(LInvalid3).Mov(RAX, RCX).Add(RAX, 3).Ret;
    B.Bind(LSuccess).Xor_(EAX, EAX).Ret;
    Result := TExecutableCode.FromBuilder(B);
  finally
    B.Free;
  end;
end;

constructor TBase64Jit.Create(Mode: TBase64Mode);
begin
  inherited Create;
  FMode := ResolveMode(Mode);
  BuildConstants;
  FEncodeCode := BuildEncodeKernel;
  FDecodeCode := BuildDecodeKernel;
end;

destructor TBase64Jit.Destroy;
begin
  FDecodeCode.Free;
  FEncodeCode.Free;
  inherited;
end;

procedure TBase64Jit.Encode(Source: Pointer; Length: NativeUInt; Dest: Pointer);
var
  OutLength: NativeUInt;
begin
  ValidateBuffer(Source, Length, 'Source');
  OutLength := EncodedLength(Length);
  ValidateBuffer(Dest, OutLength, 'Dest');
  if Length <> 0 then FEncodeCode.Run(UInt64(NativeUInt(Source)), UInt64(Length), UInt64(NativeUInt(Dest)));
end;

function TBase64Jit.Encode(const Data: TBytes): TBytes;
var
  Count, OutLength: NativeUInt;
begin
  Count := NativeUInt(Length(Data));
  OutLength := EncodedLength(Count);
  if OutLength > NativeUInt(MaxInt) then raise ERangeError.Create('Base64 output exceeds Delphi array limits');
  SetLength(Result, Integer(OutLength));
  if Count <> 0 then Encode(@Data[0], Count, @Result[0]);
end;

function TBase64Jit.TryDecode(Source: Pointer; Length: NativeUInt; Dest: Pointer; out DecodedLength: NativeUInt; out InvalidIndex: NativeInt): Boolean;
var
  ErrorPtr: NativeUInt;
  MaxLength: NativeUInt;
begin
  DecodedLength := 0;
  InvalidIndex := -1;
  ValidateBuffer(Source, Length, 'Source');
  if Length > NativeUInt(High(NativeInt)) then raise ERangeError.Create('Base64 input exceeds index range');
  if (Length and 3) <> 0 then
  begin
    InvalidIndex := NativeInt(Length);
    Exit(False);
  end;
  if Length = 0 then Exit(True);
  MaxLength := (Length div 4) * 3;
  ValidateBuffer(Dest, MaxLength, 'Dest');
  ErrorPtr := NativeUInt(FDecodeCode.Run(UInt64(NativeUInt(Source)), UInt64(Length), UInt64(NativeUInt(Dest))));
  if ErrorPtr <> 0 then
  begin
    InvalidIndex := NativeInt(ErrorPtr - NativeUInt(Source));
    Exit(False);
  end;
  DecodedLength := DecodedLengthFromPadding(Source, Length);
  Result := True;
end;

function TBase64Jit.TryDecode(const Text: TBytes; out Data: TBytes; out InvalidIndex: NativeInt): Boolean;
var
  Count, DecodedLength, MaxLength: NativeUInt;
begin
  Count := NativeUInt(Length(Text));
  if (Count and 3) <> 0 then
  begin
    SetLength(Data, 0);
    InvalidIndex := NativeInt(Count);
    Exit(False);
  end;
  MaxLength := (Count div 4) * 3;
  if MaxLength > NativeUInt(MaxInt) then raise ERangeError.Create('Base64 output exceeds Delphi array limits');
  SetLength(Data, Integer(MaxLength));
  if Count = 0 then
  begin
    InvalidIndex := -1;
    Exit(True);
  end;
  Result := TryDecode(@Text[0], Count, @Data[0], DecodedLength, InvalidIndex);
  if Result then SetLength(Data, Integer(DecodedLength)) else SetLength(Data, 0);
end;

end.
