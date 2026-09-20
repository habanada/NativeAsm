{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
unit NativeAsm.Crypto.ChaCha20;

interface

uses
  System.SysUtils,
  NativeAsm.Types,
  NativeAsm.Builder,
  NativeAsm.Extensions,
  NativeAsm.CpuFeatures;

type
  TChaCha20Key = array[0..31] of Byte;
  TChaCha20Nonce = array[0..11] of Byte;
  TChaCha20Mode = (ccmAuto, ccmScalar, ccmSse2);


//IETF-ChaCha20- 256-Bit-Key, 32-Bit-Counter &  96-Bit-Nonce
  TChaCha20Jit = class
  private type
    TContext = packed record
      State: array[0..15] of Cardinal;
      Work: array[0..15] of Cardinal;
      Source: Pointer;
      Dest: Pointer;
      Blocks: NativeUInt;
    end;
  private
    FCode: TExecutableCode;
    FMode: TChaCha20Mode;
    class function BuildScalarKernel: TExecutableCode; static;
    class function BuildSse2Kernel: TExecutableCode; static;
    class function ResolveMode(Mode: TChaCha20Mode): TChaCha20Mode; static;
    class procedure InitContext(var Ctx: TContext; const Key: TChaCha20Key; const Nonce: TChaCha20Nonce; Counter: Cardinal); static;
    procedure ProcessBlocks(var Ctx: TContext; Source, Dest: Pointer; Blocks: NativeUInt);
  public
    constructor Create(Mode: TChaCha20Mode = ccmAuto);
    destructor Destroy; override;
    procedure XorKeyStream(Source, Dest: Pointer; Length: NativeUInt; const Key: TChaCha20Key; const Nonce: TChaCha20Nonce; Counter: Cardinal = 0); overload;
    function XorKeyStream(const Data: TBytes; const Key: TChaCha20Key; const Nonce: TChaCha20Nonce; Counter: Cardinal = 0): TBytes; overload;
    procedure Generate(Dest: Pointer; Length: NativeUInt; const Key: TChaCha20Key; const Nonce: TChaCha20Nonce; Counter: Cardinal = 0); overload;
    function Generate(Length: NativeUInt; const Key: TChaCha20Key; const Nonce: TChaCha20Nonce; Counter: Cardinal = 0): TBytes; overload;
    class function IsSse2Available: Boolean; static;
    property Mode: TChaCha20Mode read FMode;
  end;

implementation

uses
  NativeAsm.Simd,
  NativeAsm.Simd.Types;

const
  C0 = Cardinal($61707865);
  C1 = Cardinal($3320646E);
  C2 = Cardinal($79622D32);
  C3 = Cardinal($6B206574);
  StateOffset = 0;
  WorkOffset = 64;
  SourceOffset = 128;
  DestOffset = 136;
  BlocksOffset = 144;

procedure EmitScalarQuarterRound(B: TAsmBuilder; A, Bb, C, D: Integer);
var
  OA, OB, OC, OD: Integer;
begin
  OA := WorkOffset + A * 4;
  OB := WorkOffset + Bb * 4;
  OC := WorkOffset + C * 4;
  OD := WorkOffset + D * 4;
  B.Mov(EAX, DWordPtr(ridR11, OA)).Add(EAX, DWordPtr(ridR11, OB)).Mov(DWordPtr(ridR11, OA), EAX);
  B.Mov(R10D, DWordPtr(ridR11, OD)).Xor_(R10D, EAX).Rol(R10D, 16).Mov(DWordPtr(ridR11, OD), R10D);
  B.Mov(EAX, DWordPtr(ridR11, OC)).Add(EAX, R10D).Mov(DWordPtr(ridR11, OC), EAX);
  B.Mov(R10D, DWordPtr(ridR11, OB)).Xor_(R10D, EAX).Rol(R10D, 12).Mov(DWordPtr(ridR11, OB), R10D);
  B.Mov(EAX, DWordPtr(ridR11, OA)).Add(EAX, R10D).Mov(DWordPtr(ridR11, OA), EAX);
  B.Mov(R10D, DWordPtr(ridR11, OD)).Xor_(R10D, EAX).Rol(R10D, 8).Mov(DWordPtr(ridR11, OD), R10D);
  B.Mov(EAX, DWordPtr(ridR11, OC)).Add(EAX, R10D).Mov(DWordPtr(ridR11, OC), EAX);
  B.Mov(R10D, DWordPtr(ridR11, OB)).Xor_(R10D, EAX).Rol(R10D, 7).Mov(DWordPtr(ridR11, OB), R10D);
end;

procedure EmitRotl32(B: TAsmBuilder; Reg, Temp: TSimdRegister; Bits: Integer);
begin
  B.Movdqa(Temp, Reg).Pslld(Reg, Bits).Psrld(Temp, 32 - Bits).Por(Reg, Temp);
end;

procedure EmitVectorQuarterRound(B: TAsmBuilder; A, Bb, C, D, Temp: TSimdRegister);
begin
  B.Paddd(A, Bb).Pxor(D, A);
  EmitRotl32(B, D, Temp, 16);
  B.Paddd(C, D).Pxor(Bb, C);
  EmitRotl32(B, Bb, Temp, 12);
  B.Paddd(A, Bb).Pxor(D, A);
  EmitRotl32(B, D, Temp, 8);
  B.Paddd(C, D).Pxor(Bb, C);
  EmitRotl32(B, Bb, Temp, 7);
end;

class function TChaCha20Jit.BuildScalarKernel: TExecutableCode;
var
  B: TAsmBuilder;
  LLoop, LDone: TLabel;
  I, R: Integer;
begin
  B := TAsmBuilder.Create;
  try
    LLoop := B.NewLabel;
    LDone := B.NewLabel;
    B.Mov(R11, RCX).Mov(RDX, QWordPtr(ridR11, SourceOffset)).Mov(R8, QWordPtr(ridR11, DestOffset)).Mov(R9, QWordPtr(ridR11, BlocksOffset));
    B.Test(R9, R9).J(cond_JE, LDone).Bind(LLoop);
    for I := 0 to 15 do B.Mov(EAX, DWordPtr(ridR11, StateOffset + I * 4)).Mov(DWordPtr(ridR11, WorkOffset + I * 4), EAX);
    for R := 0 to 9 do
    begin
      EmitScalarQuarterRound(B, 0, 4, 8, 12);
      EmitScalarQuarterRound(B, 1, 5, 9, 13);
      EmitScalarQuarterRound(B, 2, 6, 10, 14);
      EmitScalarQuarterRound(B, 3, 7, 11, 15);
      EmitScalarQuarterRound(B, 0, 5, 10, 15);
      EmitScalarQuarterRound(B, 1, 6, 11, 12);
      EmitScalarQuarterRound(B, 2, 7, 8, 13);
      EmitScalarQuarterRound(B, 3, 4, 9, 14);
    end;
    for I := 0 to 15 do
      B.Mov(EAX, DWordPtr(ridR11, WorkOffset + I * 4)).Add(EAX, DWordPtr(ridR11, StateOffset + I * 4)).Xor_(EAX, DWordPtr(ridRDX, I * 4)).Mov(DWordPtr(ridR8, I * 4), EAX);
    B.Add(RDX, 64).Add(R8, 64).Inc_(DWordPtr(ridR11, StateOffset + 48)).Dec_(R9).J(cond_JNE, LLoop);
    B.Bind(LDone).Ret;
    Result := TExecutableCode.FromBuilder(B);
  finally
    B.Free;
  end;
end;

class function TChaCha20Jit.BuildSse2Kernel: TExecutableCode;
var
  B: TAsmBuilder;
  LLoop, LDone: TLabel;
  R: Integer;
begin
  B := TAsmBuilder.Create;
  try
    LLoop := B.NewLabel;
    LDone := B.NewLabel;
    B.Mov(R11, RCX).Mov(RDX, QWordPtr(ridR11, SourceOffset)).Mov(R8, QWordPtr(ridR11, DestOffset)).Mov(R9, QWordPtr(ridR11, BlocksOffset));
    B.Test(R9, R9).J(cond_JE, LDone).Bind(LLoop);
    B.Movdqu(XMM0, NativeAsm.Simd.Types.OWordPtr(ridR11, StateOffset)).Movdqu(XMM1, NativeAsm.Simd.Types.OWordPtr(ridR11, StateOffset + 16));
    B.Movdqu(XMM2, NativeAsm.Simd.Types.OWordPtr(ridR11, StateOffset + 32)).Movdqu(XMM3, NativeAsm.Simd.Types.OWordPtr(ridR11, StateOffset + 48));
    for R := 0 to 9 do
    begin
      EmitVectorQuarterRound(B, XMM0, XMM1, XMM2, XMM3, XMM4);
      B.Pshufd(XMM1, XMM1, $39).Pshufd(XMM2, XMM2, $4E).Pshufd(XMM3, XMM3, $93);
      EmitVectorQuarterRound(B, XMM0, XMM1, XMM2, XMM3, XMM4);
      B.Pshufd(XMM1, XMM1, $93).Pshufd(XMM2, XMM2, $4E).Pshufd(XMM3, XMM3, $39);
    end;
    B.Movdqu(XMM4, NativeAsm.Simd.Types.OWordPtr(ridR11, StateOffset)).Paddd(XMM0, XMM4);
    B.Movdqu(XMM4, NativeAsm.Simd.Types.OWordPtr(ridR11, StateOffset + 16)).Paddd(XMM1, XMM4);
    B.Movdqu(XMM4, NativeAsm.Simd.Types.OWordPtr(ridR11, StateOffset + 32)).Paddd(XMM2, XMM4);
    B.Movdqu(XMM4, NativeAsm.Simd.Types.OWordPtr(ridR11, StateOffset + 48)).Paddd(XMM3, XMM4);
    B.Movdqu(XMM4, NativeAsm.Simd.Types.OWordPtr(ridRDX)).Pxor(XMM0, XMM4);
    B.Movdqu(XMM4, NativeAsm.Simd.Types.OWordPtr(ridRDX, 16)).Pxor(XMM1, XMM4);
    B.Movdqu(XMM4, NativeAsm.Simd.Types.OWordPtr(ridRDX, 32)).Pxor(XMM2, XMM4);
    B.Movdqu(XMM4, NativeAsm.Simd.Types.OWordPtr(ridRDX, 48)).Pxor(XMM3, XMM4);
    B.Movdqu(NativeAsm.Simd.Types.OWordPtr(ridR8), XMM0).Movdqu(NativeAsm.Simd.Types.OWordPtr(ridR8, 16), XMM1);
    B.Movdqu(NativeAsm.Simd.Types.OWordPtr(ridR8, 32), XMM2).Movdqu(NativeAsm.Simd.Types.OWordPtr(ridR8, 48), XMM3);
    B.Add(RDX, 64).Add(R8, 64).Inc_(DWordPtr(ridR11, StateOffset + 48)).Dec_(R9).J(cond_JNE, LLoop);
    B.Bind(LDone).Ret;
    Result := TExecutableCode.FromBuilder(B);
  finally
    B.Free;
  end;
end;

class function TChaCha20Jit.IsSse2Available: Boolean;
begin
  Result := TCpuFeatures.Supports(cfSSE2);
end;

class function TChaCha20Jit.ResolveMode(Mode: TChaCha20Mode): TChaCha20Mode;
begin
  case Mode of
    ccmAuto: if IsSse2Available then Result := ccmSse2 else Result := ccmScalar;
    ccmScalar: Result := ccmScalar;
    ccmSse2:
      begin
        if not IsSse2Available then raise EInvalidOp.Create('SSE2 is not available on this CPU');
        Result := ccmSse2;
      end;
  else
    raise EArgumentException.Create('Invalid ChaCha20 mode');
  end;
end;

class procedure TChaCha20Jit.InitContext(var Ctx: TContext; const Key: TChaCha20Key; const Nonce: TChaCha20Nonce; Counter: Cardinal);
begin
  FillChar(Ctx, SizeOf(Ctx), 0);
  Ctx.State[0] := C0;
  Ctx.State[1] := C1;
  Ctx.State[2] := C2;
  Ctx.State[3] := C3;
  Move(Key[0], Ctx.State[4], SizeOf(Key));
  Ctx.State[12] := Counter;
  Move(Nonce[0], Ctx.State[13], SizeOf(Nonce));
end;

constructor TChaCha20Jit.Create(Mode: TChaCha20Mode);
begin
  inherited Create;
  FMode := ResolveMode(Mode);
  if FMode = ccmSse2 then FCode := BuildSse2Kernel else FCode := BuildScalarKernel;
end;

destructor TChaCha20Jit.Destroy;
begin
  FCode.Free;
  inherited;
end;

procedure TChaCha20Jit.ProcessBlocks(var Ctx: TContext; Source, Dest: Pointer; Blocks: NativeUInt);
begin
  if Blocks = 0 then Exit;
  Ctx.Source := Source;
  Ctx.Dest := Dest;
  Ctx.Blocks := Blocks;
  FCode.Run(UInt64(NativeUInt(@Ctx)));
end;

procedure TChaCha20Jit.XorKeyStream(Source, Dest: Pointer; Length: NativeUInt; const Key: TChaCha20Key; const Nonce: TChaCha20Nonce; Counter: Cardinal);
var
  Ctx: TContext;
  Blocks, Tail, Needed: NativeUInt;
  ZeroBlock, Stream: array[0..63] of Byte;
  I: NativeUInt;
  SrcTail, DstTail: PByte;
begin
  if (Source = nil) and (Length <> 0) then raise EArgumentNilException.Create('Source');
  if (Dest = nil) and (Length <> 0) then raise EArgumentNilException.Create('Dest');
  if Length = 0 then Exit;
  Needed := Length div 64;
  if (Length and 63) <> 0 then Inc(Needed);
  if UInt64(Counter) + UInt64(Needed) > UInt64(High(Cardinal)) + 1 then raise ERangeError.Create('ChaCha20 counter overflow');
  InitContext(Ctx, Key, Nonce, Counter);
  try
    Blocks := Length div 64;
    Tail := Length mod 64;
    if Blocks <> 0 then ProcessBlocks(Ctx, Source, Dest, Blocks);
    if Tail <> 0 then
    begin
      FillChar(ZeroBlock, SizeOf(ZeroBlock), 0);
      ProcessBlocks(Ctx, @ZeroBlock[0], @Stream[0], 1);
      SrcTail := PByte(NativeUInt(Source) + Blocks * 64);
      DstTail := PByte(NativeUInt(Dest) + Blocks * 64);
      for I := 0 to Tail - 1 do DstTail[I] := SrcTail[I] xor Stream[I];
      FillChar(Stream, SizeOf(Stream), 0);
    end;
  finally
    FillChar(Ctx, SizeOf(Ctx), 0);
  end;
end;

function TChaCha20Jit.XorKeyStream(const Data: TBytes; const Key: TChaCha20Key; const Nonce: TChaCha20Nonce; Counter: Cardinal): TBytes;
begin
  SetLength(Result, Length(Data));
  if Length(Data) <> 0 then XorKeyStream(@Data[0], @Result[0], NativeUInt(Length(Data)), Key, Nonce, Counter);
end;

procedure TChaCha20Jit.Generate(Dest: Pointer; Length: NativeUInt; const Key: TChaCha20Key; const Nonce: TChaCha20Nonce; Counter: Cardinal);
var
  Ctx: TContext;
  Zeros: array[0..4095] of Byte;
  Stream: array[0..63] of Byte;
  Blocks, Chunk, Tail, Needed: NativeUInt;
  P: PByte;
begin
  if (Dest = nil) and (Length <> 0) then raise EArgumentNilException.Create('Dest');
  if Length = 0 then Exit;
  Needed := Length div 64;
  if (Length and 63) <> 0 then Inc(Needed);
  if UInt64(Counter) + UInt64(Needed) > UInt64(High(Cardinal)) + 1 then raise ERangeError.Create('ChaCha20 counter overflow');
  InitContext(Ctx, Key, Nonce, Counter);
  FillChar(Zeros, SizeOf(Zeros), 0);
  P := PByte(Dest);
  try
    Blocks := Length div 64;
    Tail := Length mod 64;
    while Blocks <> 0 do
    begin
      Chunk := Blocks;
      if Chunk > 64 then Chunk := 64;
      ProcessBlocks(Ctx, @Zeros[0], P, Chunk);
      P := PByte(NativeUInt(P) + Chunk * 64);
      Dec(Blocks, Chunk);
    end;
    if Tail <> 0 then
    begin
      ProcessBlocks(Ctx, @Zeros[0], @Stream[0], 1);
      Move(Stream[0], P^, NativeInt(Tail));
      FillChar(Stream, SizeOf(Stream), 0);
    end;
  finally
    FillChar(Ctx, SizeOf(Ctx), 0);
  end;
end;

function TChaCha20Jit.Generate(Length: NativeUInt; const Key: TChaCha20Key; const Nonce: TChaCha20Nonce; Counter: Cardinal): TBytes;
begin
  if Length > NativeUInt(High(Integer)) then raise ERangeError.Create('Requested ChaCha20 buffer is too large');
  SetLength(Result, Integer(Length));
  if Length <> 0 then Generate(@Result[0], Length, Key, Nonce, Counter);
end;

end.
