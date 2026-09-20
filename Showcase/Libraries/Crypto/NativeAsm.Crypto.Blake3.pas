{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
unit NativeAsm.Crypto.Blake3;

interface

uses
  System.SysUtils,
  NativeAsm.Types,
  NativeAsm.Builder,
  NativeAsm.Extensions,
  NativeAsm.CpuFeatures;

type
  TBlake3Digest = array[0..31] of Byte;
  TBlake3Mode = (b3mAuto, b3mScalar, b3mSse2, b3mSsse3);

//unkeyed BLAKE3-Hashf 256-Bit
  TBlake3Jit = class
  private type
    TCv = array[0..7] of Cardinal;
    TFourCvs = array[0..3] of TCv;
    TCvStack = array[0..63] of TCv;
    TBlockWords = array[0..15] of Cardinal;
    TOutWords = array[0..15] of Cardinal;
    TCompressContext = packed record
      Cv: TCv;
      Block: TBlockWords;
      Params: array[0..3] of Cardinal;
      OutWords: TOutWords;
    end;
    TOutput = record
      Cv: TCv;
      Block: TBlockWords;
      Counter: UInt64;
      BlockLen: Cardinal;
      Flags: Cardinal;
    end;
  private
    FCompressCode: TExecutableCode;
    FParallelCode: TExecutableCode;
    FMode: TBlake3Mode;
    class function BuildRowKernel(UseSsse3: Boolean): TExecutableCode; static;
    class function BuildParallelKernel(UseSsse3: Boolean): TExecutableCode; static;
    class function ResolveMode(Mode: TBlake3Mode): TBlake3Mode; static;
    class procedure CompressScalar(const Cv: TCv; const Block: TBlockWords; Counter: UInt64; BlockLen, Flags: Cardinal; out OutWords: TOutWords); static;
    procedure Compress(const Cv: TCv; const Block: TBlockWords; Counter: UInt64; BlockLen, Flags: Cardinal; out OutWords: TOutWords);
    procedure CompressChunks4(P: Pointer; FirstCounter: UInt64; out Cvs: TFourCvs);
    class procedure LoadBlock(P: Pointer; Length: Cardinal; out Block: TBlockWords); static;
    function ChunkOutput(P: Pointer; Length: NativeUInt; ChunkCounter: UInt64): TOutput;
    function ParentOutput(const Left, Right: TCv): TOutput;
    function OutputCv(const Value: TOutput): TCv;
    procedure PushChunkCv(var Stack: TCvStack; var StackCount: Integer; const Value: TCv; TotalChunks: UInt64);
  public
    constructor Create(Mode: TBlake3Mode = b3mAuto);
    destructor Destroy; override;
    function Compute(Buffer: Pointer; Length: NativeUInt): TBlake3Digest; overload;
    function Compute(const Data: TBytes): TBlake3Digest; overload;
    class function IsSse2Available: Boolean; static;
    class function IsSsse3Available: Boolean; static;
    property Mode: TBlake3Mode read FMode;
  end;

implementation

uses
  NativeAsm.Simd,
  NativeAsm.Simd.Types;

{$Q-}

const
  Blake3IV: array[0..7] of Cardinal = ($6A09E667, $BB67AE85, $3C6EF372, $A54FF53A, $510E527F, $9B05688C, $1F83D9AB, $5BE0CD19);
  MsgPermutation: array[0..15] of Byte = (2, 6, 3, 10, 7, 0, 4, 13, 1, 11, 12, 5, 9, 14, 15, 8);
  RotateMasks: array[0..31] of Byte = (2,3,0,1,6,7,4,5,10,11,8,9,14,15,12,13,1,2,3,0,5,6,7,4,9,10,11,8,13,14,15,12);
  FlagChunkStart = Cardinal(1);
  FlagChunkEnd = Cardinal(2);
  FlagParent = Cardinal(4);
  FlagRoot = Cardinal(8);
  CvOffset = 0;
  BlockOffset = 32;
  ParamsOffset = 96;
  OutOffset = 112;
  ParallelSaveBase = 0;
  ParallelMessageBase = 160;
  ParallelV15Offset = 416;
  ParallelSpill14Offset = 432;
  ParallelCounterLowOffset = 448;
  ParallelCounterHighOffset = 464;
  ParallelStackSize = 480;

function Ror32(Value: Cardinal; Bits: Integer): Cardinal; inline;
begin
  Result := (Value shr Bits) or (Value shl (32 - Bits));
end;

procedure GScalar(var A, B, C, D: Cardinal; X, Y: Cardinal); inline;
begin
  A := A + B + X; D := Ror32(D xor A, 16);
  C := C + D; B := Ror32(B xor C, 12);
  A := A + B + Y; D := Ror32(D xor A, 8);
  C := C + D; B := Ror32(B xor C, 7);
end;

function StateReg(Index: Integer): TSimdRegister;
begin
  case Index of
    0: Result := XMM0;
    1: Result := XMM1;
    2: Result := XMM2;
    3: Result := XMM3;
    4: Result := XMM4;
    5: Result := XMM5;
    6: Result := XMM6;
    7: Result := XMM7;
    8: Result := XMM8;
    9: Result := XMM9;
    10: Result := XMM10;
    11: Result := XMM11;
    12: Result := XMM12;
    13: Result := XMM13;
    14: Result := XMM14;
  else
    raise EArgumentException.Create('BLAKE3 state register');
  end;
end;

procedure EmitRor32(B: TAsmBuilder; Reg, Temp: TSimdRegister; Bits: Integer; UseSsse3: Boolean);
begin
  if Bits = 16 then
  begin
    if UseSsse3 then B.Movdqu(Temp, NativeAsm.Simd.Types.OWordPtr(ridRAX)).Pshufb(Reg, Temp)
    else B.Pshuflw(Reg, Reg, $B1).Pshufhw(Reg, Reg, $B1);
    Exit;
  end;
  if (Bits = 8) and UseSsse3 then
  begin
    B.Movdqu(Temp, NativeAsm.Simd.Types.OWordPtr(ridRAX, 16)).Pshufb(Reg, Temp);
    Exit;
  end;
  B.Movdqa(Temp, Reg).Psrld(Reg, Bits).Pslld(Temp, 32 - Bits).Por(Reg, Temp);
end;

procedure EmitG(B: TAsmBuilder; UseSsse3: Boolean);
begin
  B.Paddd(XMM0, XMM1).Paddd(XMM0, XMM6).Pxor(XMM3, XMM0);
  EmitRor32(B, XMM3, XMM4, 16, UseSsse3);
  B.Paddd(XMM2, XMM3).Pxor(XMM1, XMM2);
  EmitRor32(B, XMM1, XMM4, 12, UseSsse3);
  B.Paddd(XMM0, XMM1).Paddd(XMM0, XMM7).Pxor(XMM3, XMM0);
  EmitRor32(B, XMM3, XMM4, 8, UseSsse3);
  B.Paddd(XMM2, XMM3).Pxor(XMM1, XMM2);
  EmitRor32(B, XMM1, XMM4, 7, UseSsse3);
end;

procedure EmitMessageVector(B: TAsmBuilder; Dest: TSimdRegister; I0, I1, I2, I3: Integer);
begin
  B.Movd(Dest, DWordPtr(ridRCX, BlockOffset + I0 * 4));
  B.Movd(XMM4, DWordPtr(ridRCX, BlockOffset + I1 * 4)).Punpckldq(Dest, XMM4);
  B.Movd(XMM4, DWordPtr(ridRCX, BlockOffset + I2 * 4)).Movd(XMM5, DWordPtr(ridRCX, BlockOffset + I3 * 4)).Punpckldq(XMM4, XMM5).Punpcklqdq(Dest, XMM4);
end;

procedure EmitTransposeMessageGroup(B: TAsmBuilder; InputOffset, WordBase: Integer);
begin
  B.Movdqu(XMM8, NativeAsm.Simd.Types.OWordPtr(ridRCX, InputOffset));
  B.Movdqu(XMM9, NativeAsm.Simd.Types.OWordPtr(ridR9, InputOffset));
  B.Movdqu(XMM10, NativeAsm.Simd.Types.OWordPtr(ridR10, InputOffset));
  B.Movdqu(XMM11, NativeAsm.Simd.Types.OWordPtr(ridR11, InputOffset));
  B.Movdqa(XMM12, XMM8).Punpckldq(XMM12, XMM9);
  B.Movdqa(XMM13, XMM8).Punpckhdq(XMM13, XMM9);
  B.Movdqa(XMM14, XMM10).Punpckldq(XMM14, XMM11);
  B.Movdqa(XMM15, XMM10).Punpckhdq(XMM15, XMM11);
  B.Movdqa(XMM8, XMM12).Punpcklqdq(XMM8, XMM14);
  B.Movdqa(XMM9, XMM12).Punpckhqdq(XMM9, XMM14);
  B.Movdqa(XMM10, XMM13).Punpcklqdq(XMM10, XMM15);
  B.Movdqa(XMM11, XMM13).Punpckhqdq(XMM11, XMM15);
  B.Movdqu(NativeAsm.Simd.Types.OWordPtr(ridRSP, ParallelMessageBase + (WordBase + 0) * 16), XMM8);
  B.Movdqu(NativeAsm.Simd.Types.OWordPtr(ridRSP, ParallelMessageBase + (WordBase + 1) * 16), XMM9);
  B.Movdqu(NativeAsm.Simd.Types.OWordPtr(ridRSP, ParallelMessageBase + (WordBase + 2) * 16), XMM10);
  B.Movdqu(NativeAsm.Simd.Types.OWordPtr(ridRSP, ParallelMessageBase + (WordBase + 3) * 16), XMM11);
end;

procedure EmitParallelG(B: TAsmBuilder; AIndex, BIndex, CIndex, DIndex, XIndex, YIndex: Integer; UseSsse3: Boolean);
var
  AReg, BReg, CReg, DReg, Temp: TSimdRegister;
  SpecialD: Boolean;
begin
  SpecialD := DIndex = 15;
  AReg := StateReg(AIndex);
  BReg := StateReg(BIndex);
  CReg := StateReg(CIndex);
  if SpecialD then
  begin
    B.Movdqu(NativeAsm.Simd.Types.OWordPtr(ridRSP, ParallelSpill14Offset), XMM14);
    B.Movdqu(XMM15, NativeAsm.Simd.Types.OWordPtr(ridRSP, ParallelV15Offset));
    DReg := XMM15;
    Temp := XMM14;
  end
  else
  begin
    DReg := StateReg(DIndex);
    Temp := XMM15;
  end;
  B.Paddd(AReg, BReg).Movdqu(Temp, NativeAsm.Simd.Types.OWordPtr(ridRSP, ParallelMessageBase + XIndex * 16)).Paddd(AReg, Temp).Pxor(DReg, AReg);
  EmitRor32(B, DReg, Temp, 16, UseSsse3);
  B.Paddd(CReg, DReg).Pxor(BReg, CReg);
  EmitRor32(B, BReg, Temp, 12, UseSsse3);
  B.Paddd(AReg, BReg).Movdqu(Temp, NativeAsm.Simd.Types.OWordPtr(ridRSP, ParallelMessageBase + YIndex * 16)).Paddd(AReg, Temp).Pxor(DReg, AReg);
  EmitRor32(B, DReg, Temp, 8, UseSsse3);
  B.Paddd(CReg, DReg).Pxor(BReg, CReg);
  EmitRor32(B, BReg, Temp, 7, UseSsse3);
  if SpecialD then
  begin
    B.Movdqu(NativeAsm.Simd.Types.OWordPtr(ridRSP, ParallelV15Offset), XMM15);
    B.Movdqu(XMM14, NativeAsm.Simd.Types.OWordPtr(ridRSP, ParallelSpill14Offset));
  end;
end;

procedure EmitStoreCvGroup(B: TAsmBuilder; S0, S1, S2, S3: TSimdRegister; OutputOffset: Integer);
begin
  B.Movdqa(XMM8, S0).Punpckldq(XMM8, S1);
  B.Movdqa(XMM9, S0).Punpckhdq(XMM9, S1);
  B.Movdqa(XMM10, S2).Punpckldq(XMM10, S3);
  B.Movdqa(XMM11, S2).Punpckhdq(XMM11, S3);
  B.Movdqa(XMM12, XMM8).Punpcklqdq(XMM12, XMM10);
  B.Movdqa(XMM13, XMM8).Punpckhqdq(XMM13, XMM10);
  B.Movdqa(XMM14, XMM9).Punpcklqdq(XMM14, XMM11);
  B.Movdqa(XMM15, XMM9).Punpckhqdq(XMM15, XMM11);
  B.Movdqu(NativeAsm.Simd.Types.OWordPtr(ridR8, OutputOffset + 0 * 32), XMM12);
  B.Movdqu(NativeAsm.Simd.Types.OWordPtr(ridR8, OutputOffset + 1 * 32), XMM13);
  B.Movdqu(NativeAsm.Simd.Types.OWordPtr(ridR8, OutputOffset + 2 * 32), XMM14);
  B.Movdqu(NativeAsm.Simd.Types.OWordPtr(ridR8, OutputOffset + 3 * 32), XMM15);
end;

class function TBlake3Jit.BuildRowKernel(UseSsse3: Boolean): TExecutableCode;
var
  B: TAsmBuilder;
  Schedule, NextSchedule: array[0..15] of Byte;
  R, I: Integer;
begin
  B := TAsmBuilder.Create;
  try
    B.Sub(RSP, 32).Movdqu(NativeAsm.Simd.Types.OWordPtr(ridRSP), XMM6).Movdqu(NativeAsm.Simd.Types.OWordPtr(ridRSP, 16), XMM7);
    B.Movdqu(XMM0, NativeAsm.Simd.Types.OWordPtr(ridRCX, CvOffset)).Movdqu(XMM1, NativeAsm.Simd.Types.OWordPtr(ridRCX, CvOffset + 16));
    B.Mov(RAX, Int64(NativeUInt(@Blake3IV[0]))).Movdqu(XMM2, NativeAsm.Simd.Types.OWordPtr(ridRAX)).Movdqu(XMM3, NativeAsm.Simd.Types.OWordPtr(ridRCX, ParamsOffset));
    if UseSsse3 then B.Mov(RAX, Int64(NativeUInt(@RotateMasks[0])));
    for I := 0 to 15 do Schedule[I] := I;
    for R := 0 to 6 do
    begin
      EmitMessageVector(B, XMM6, Schedule[0], Schedule[2], Schedule[4], Schedule[6]);
      EmitMessageVector(B, XMM7, Schedule[1], Schedule[3], Schedule[5], Schedule[7]);
      EmitG(B, UseSsse3);
      B.Pshufd(XMM1, XMM1, $39).Pshufd(XMM2, XMM2, $4E).Pshufd(XMM3, XMM3, $93);
      EmitMessageVector(B, XMM6, Schedule[8], Schedule[10], Schedule[12], Schedule[14]);
      EmitMessageVector(B, XMM7, Schedule[9], Schedule[11], Schedule[13], Schedule[15]);
      EmitG(B, UseSsse3);
      B.Pshufd(XMM1, XMM1, $93).Pshufd(XMM2, XMM2, $4E).Pshufd(XMM3, XMM3, $39);
      for I := 0 to 15 do NextSchedule[I] := Schedule[MsgPermutation[I]];
      Move(NextSchedule[0], Schedule[0], SizeOf(Schedule));
    end;
    B.Movdqa(XMM4, XMM0).Pxor(XMM4, XMM2).Movdqu(NativeAsm.Simd.Types.OWordPtr(ridRCX, OutOffset), XMM4);
    B.Movdqa(XMM5, XMM1).Pxor(XMM5, XMM3).Movdqu(NativeAsm.Simd.Types.OWordPtr(ridRCX, OutOffset + 16), XMM5);
    B.Movdqu(XMM6, NativeAsm.Simd.Types.OWordPtr(ridRCX, CvOffset)).Pxor(XMM2, XMM6).Movdqu(NativeAsm.Simd.Types.OWordPtr(ridRCX, OutOffset + 32), XMM2);
    B.Movdqu(XMM7, NativeAsm.Simd.Types.OWordPtr(ridRCX, CvOffset + 16)).Pxor(XMM3, XMM7).Movdqu(NativeAsm.Simd.Types.OWordPtr(ridRCX, OutOffset + 48), XMM3);
    B.Movdqu(XMM6, NativeAsm.Simd.Types.OWordPtr(ridRSP)).Movdqu(XMM7, NativeAsm.Simd.Types.OWordPtr(ridRSP, 16)).Add(RSP, 32).Ret;
    Result := TExecutableCode.FromBuilder(B);
  finally
    B.Free;
  end;
end;

class function TBlake3Jit.BuildParallelKernel(UseSsse3: Boolean): TExecutableCode;
var
  B: TAsmBuilder;
  LLoop, LCheckLast, LFlagsReady, LDone: TLabel;
  Schedule, NextSchedule: array[0..15] of Byte;
  R, I: Integer;
begin
  B := TAsmBuilder.Create;
  try
    LLoop := B.NewLabel;
    LCheckLast := B.NewLabel;
    LFlagsReady := B.NewLabel;
    LDone := B.NewLabel;
    B.Sub(RSP, ParallelStackSize);
    B.Movdqu(NativeAsm.Simd.Types.OWordPtr(ridRSP, ParallelSaveBase + 0), XMM6);
    B.Movdqu(NativeAsm.Simd.Types.OWordPtr(ridRSP, ParallelSaveBase + 16), XMM7);
    B.Movdqu(NativeAsm.Simd.Types.OWordPtr(ridRSP, ParallelSaveBase + 32), XMM8);
    B.Movdqu(NativeAsm.Simd.Types.OWordPtr(ridRSP, ParallelSaveBase + 48), XMM9);
    B.Movdqu(NativeAsm.Simd.Types.OWordPtr(ridRSP, ParallelSaveBase + 64), XMM10);
    B.Movdqu(NativeAsm.Simd.Types.OWordPtr(ridRSP, ParallelSaveBase + 80), XMM11);
    B.Movdqu(NativeAsm.Simd.Types.OWordPtr(ridRSP, ParallelSaveBase + 96), XMM12);
    B.Movdqu(NativeAsm.Simd.Types.OWordPtr(ridRSP, ParallelSaveBase + 112), XMM13);
    B.Movdqu(NativeAsm.Simd.Types.OWordPtr(ridRSP, ParallelSaveBase + 128), XMM14);
    B.Movdqu(NativeAsm.Simd.Types.OWordPtr(ridRSP, ParallelSaveBase + 144), XMM15);
    for I := 0 to 3 do
    begin
      B.Mov(RAX, RDX);
      if I <> 0 then B.Add(RAX, I);
      B.Mov(DWordPtr(ridRSP, ParallelCounterLowOffset + I * 4), EAX).Shr_(RAX, 32).Mov(DWordPtr(ridRSP, ParallelCounterHighOffset + I * 4), EAX);
    end;
    B.Mov(R9, RCX).Mov(R10, RCX).Mov(R11, RCX).Add(R9, 1024).Add(R10, 2048).Add(R11, 3072);
    B.Mov(RAX, Int64(NativeUInt(@Blake3IV[0]))).Movdqu(XMM8, NativeAsm.Simd.Types.OWordPtr(ridRAX));
    B.Pshufd(XMM0, XMM8, $00).Pshufd(XMM1, XMM8, $55).Pshufd(XMM2, XMM8, $AA).Pshufd(XMM3, XMM8, $FF);
    B.Movdqu(XMM8, NativeAsm.Simd.Types.OWordPtr(ridRAX, 16));
    B.Pshufd(XMM4, XMM8, $00).Pshufd(XMM5, XMM8, $55).Pshufd(XMM6, XMM8, $AA).Pshufd(XMM7, XMM8, $FF);
    B.Xor_(EDX, EDX).Bind(LLoop);
    EmitTransposeMessageGroup(B, 0, 0);
    EmitTransposeMessageGroup(B, 16, 4);
    EmitTransposeMessageGroup(B, 32, 8);
    EmitTransposeMessageGroup(B, 48, 12);
    B.Mov(RAX, Int64(NativeUInt(@Blake3IV[0]))).Movdqu(XMM15, NativeAsm.Simd.Types.OWordPtr(ridRAX));
    B.Pshufd(XMM8, XMM15, $00).Pshufd(XMM9, XMM15, $55).Pshufd(XMM10, XMM15, $AA).Pshufd(XMM11, XMM15, $FF);
    B.Movdqu(XMM12, NativeAsm.Simd.Types.OWordPtr(ridRSP, ParallelCounterLowOffset));
    B.Movdqu(XMM13, NativeAsm.Simd.Types.OWordPtr(ridRSP, ParallelCounterHighOffset));
    B.Mov(EAX, 64).Movd(XMM14, EAX).Pshufd(XMM14, XMM14, $00);
    B.Xor_(EAX, EAX).Cmp(EDX, 0).J(cond_JNE, LCheckLast).Mov(EAX, 1).J(cond_JMP, LFlagsReady);
    B.Bind(LCheckLast).Cmp(EDX, 15).J(cond_JNE, LFlagsReady).Mov(EAX, 2);
    B.Bind(LFlagsReady).Movd(XMM15, EAX).Pshufd(XMM15, XMM15, $00).Movdqu(NativeAsm.Simd.Types.OWordPtr(ridRSP, ParallelV15Offset), XMM15);
    if UseSsse3 then B.Mov(RAX, Int64(NativeUInt(@RotateMasks[0])));
    for I := 0 to 15 do Schedule[I] := I;
    for R := 0 to 6 do
    begin
      EmitParallelG(B, 0, 4, 8, 12, Schedule[0], Schedule[1], UseSsse3);
      EmitParallelG(B, 1, 5, 9, 13, Schedule[2], Schedule[3], UseSsse3);
      EmitParallelG(B, 2, 6, 10, 14, Schedule[4], Schedule[5], UseSsse3);
      EmitParallelG(B, 3, 7, 11, 15, Schedule[6], Schedule[7], UseSsse3);
      EmitParallelG(B, 0, 5, 10, 15, Schedule[8], Schedule[9], UseSsse3);
      EmitParallelG(B, 1, 6, 11, 12, Schedule[10], Schedule[11], UseSsse3);
      EmitParallelG(B, 2, 7, 8, 13, Schedule[12], Schedule[13], UseSsse3);
      EmitParallelG(B, 3, 4, 9, 14, Schedule[14], Schedule[15], UseSsse3);
      for I := 0 to 15 do NextSchedule[I] := Schedule[MsgPermutation[I]];
      Move(NextSchedule[0], Schedule[0], SizeOf(Schedule));
    end;
    B.Pxor(XMM0, XMM8).Pxor(XMM1, XMM9).Pxor(XMM2, XMM10).Pxor(XMM3, XMM11);
    B.Pxor(XMM4, XMM12).Pxor(XMM5, XMM13).Pxor(XMM6, XMM14).Movdqu(XMM15, NativeAsm.Simd.Types.OWordPtr(ridRSP, ParallelV15Offset)).Pxor(XMM7, XMM15);
    B.Add(RCX, 64).Add(R9, 64).Add(R10, 64).Add(R11, 64).Inc_(EDX).Cmp(EDX, 16).J(cond_JNE, LLoop).J(cond_JMP, LDone);
    B.Bind(LDone);
    EmitStoreCvGroup(B, XMM0, XMM1, XMM2, XMM3, 0);
    EmitStoreCvGroup(B, XMM4, XMM5, XMM6, XMM7, 16);
    B.Movdqu(XMM6, NativeAsm.Simd.Types.OWordPtr(ridRSP, ParallelSaveBase + 0));
    B.Movdqu(XMM7, NativeAsm.Simd.Types.OWordPtr(ridRSP, ParallelSaveBase + 16));
    B.Movdqu(XMM8, NativeAsm.Simd.Types.OWordPtr(ridRSP, ParallelSaveBase + 32));
    B.Movdqu(XMM9, NativeAsm.Simd.Types.OWordPtr(ridRSP, ParallelSaveBase + 48));
    B.Movdqu(XMM10, NativeAsm.Simd.Types.OWordPtr(ridRSP, ParallelSaveBase + 64));
    B.Movdqu(XMM11, NativeAsm.Simd.Types.OWordPtr(ridRSP, ParallelSaveBase + 80));
    B.Movdqu(XMM12, NativeAsm.Simd.Types.OWordPtr(ridRSP, ParallelSaveBase + 96));
    B.Movdqu(XMM13, NativeAsm.Simd.Types.OWordPtr(ridRSP, ParallelSaveBase + 112));
    B.Movdqu(XMM14, NativeAsm.Simd.Types.OWordPtr(ridRSP, ParallelSaveBase + 128));
    B.Movdqu(XMM15, NativeAsm.Simd.Types.OWordPtr(ridRSP, ParallelSaveBase + 144));
    B.Add(RSP, ParallelStackSize).Ret;
    Result := TExecutableCode.FromBuilder(B);
  finally
    B.Free;
  end;
end;

class procedure TBlake3Jit.CompressScalar(const Cv: TCv; const Block: TBlockWords; Counter: UInt64; BlockLen, Flags: Cardinal; out OutWords: TOutWords);
var
  V: array[0..15] of Cardinal;
  M, N: TBlockWords;
  R, I: Integer;
begin
  for I := 0 to 7 do V[I] := Cv[I];
  V[8] := Blake3IV[0]; V[9] := Blake3IV[1]; V[10] := Blake3IV[2]; V[11] := Blake3IV[3];
  V[12] := Cardinal(Counter); V[13] := Cardinal(Counter shr 32); V[14] := BlockLen; V[15] := Flags;
  M := Block;
  for R := 0 to 6 do
  begin
    GScalar(V[0], V[4], V[8], V[12], M[0], M[1]);
    GScalar(V[1], V[5], V[9], V[13], M[2], M[3]);
    GScalar(V[2], V[6], V[10], V[14], M[4], M[5]);
    GScalar(V[3], V[7], V[11], V[15], M[6], M[7]);
    GScalar(V[0], V[5], V[10], V[15], M[8], M[9]);
    GScalar(V[1], V[6], V[11], V[12], M[10], M[11]);
    GScalar(V[2], V[7], V[8], V[13], M[12], M[13]);
    GScalar(V[3], V[4], V[9], V[14], M[14], M[15]);
    if R <> 6 then
    begin
      for I := 0 to 15 do N[I] := M[MsgPermutation[I]];
      M := N;
    end;
  end;
  for I := 0 to 7 do
  begin
    OutWords[I] := V[I] xor V[I + 8];
    OutWords[I + 8] := V[I + 8] xor Cv[I];
  end;
end;

class function TBlake3Jit.IsSse2Available: Boolean;
begin
  Result := TCpuFeatures.Supports(cfSSE2);
end;

class function TBlake3Jit.IsSsse3Available: Boolean;
begin
  Result := TCpuFeatures.Supports(cfSSSE3);
end;

class function TBlake3Jit.ResolveMode(Mode: TBlake3Mode): TBlake3Mode;
begin
  case Mode of
    b3mAuto:
      if IsSsse3Available then Result := b3mSsse3
      else if IsSse2Available then Result := b3mSse2
      else Result := b3mScalar;
    b3mScalar: Result := b3mScalar;
    b3mSse2:
      begin
        if not IsSse2Available then raise EInvalidOp.Create('SSE2 is not available on this CPU');
        Result := b3mSse2;
      end;
    b3mSsse3:
      begin
        if not IsSsse3Available then raise EInvalidOp.Create('SSSE3 is not available on this CPU');
        Result := b3mSsse3;
      end;
  else
    raise EArgumentException.Create('Invalid BLAKE3 mode');
  end;
end;

constructor TBlake3Jit.Create(Mode: TBlake3Mode);
begin
  inherited Create;
  FMode := ResolveMode(Mode);
  case FMode of
    b3mSse2:
      begin
        FCompressCode := BuildRowKernel(False);
        FParallelCode := BuildParallelKernel(False);
      end;
    b3mSsse3:
      begin
        FCompressCode := BuildRowKernel(True);
        FParallelCode := BuildParallelKernel(True);
      end;
  end;
end;

destructor TBlake3Jit.Destroy;
begin
  FParallelCode.Free;
  FCompressCode.Free;
  inherited;
end;

procedure TBlake3Jit.Compress(const Cv: TCv; const Block: TBlockWords; Counter: UInt64; BlockLen, Flags: Cardinal; out OutWords: TOutWords);
var
  Ctx: TCompressContext;
begin
  if FMode = b3mScalar then
  begin
    CompressScalar(Cv, Block, Counter, BlockLen, Flags, OutWords);
    Exit;
  end;
  Ctx.Cv := Cv;
  Ctx.Block := Block;
  Ctx.Params[0] := Cardinal(Counter);
  Ctx.Params[1] := Cardinal(Counter shr 32);
  Ctx.Params[2] := BlockLen;
  Ctx.Params[3] := Flags;
  FCompressCode.Run(UInt64(NativeUInt(@Ctx)));
  OutWords := Ctx.OutWords;
  FillChar(Ctx, SizeOf(Ctx), 0);
end;

procedure TBlake3Jit.CompressChunks4(P: Pointer; FirstCounter: UInt64; out Cvs: TFourCvs);
begin
  FParallelCode.Run(UInt64(NativeUInt(P)), FirstCounter, UInt64(NativeUInt(@Cvs[0])));
end;

class procedure TBlake3Jit.LoadBlock(P: Pointer; Length: Cardinal; out Block: TBlockWords);
begin
  FillChar(Block, SizeOf(Block), 0);
  if Length <> 0 then Move(P^, Block[0], NativeInt(Length));
end;

function TBlake3Jit.ChunkOutput(P: Pointer; Length: NativeUInt; ChunkCounter: UInt64): TOutput;
var
  Cv: TCv;
  Words: TOutWords;
  Block: TBlockWords;
  BlockCount, Index: NativeUInt;
  BlockLen: Cardinal;
  Flags: Cardinal;
  Cur: PByte;
begin
  Move(Blake3IV[0], Cv[0], SizeOf(Cv));
  if Length = 0 then BlockCount := 1 else BlockCount := 1 + (Length - 1) div 64;
  Cur := PByte(P);
  for Index := 0 to BlockCount - 1 do
  begin
    if Length >= 64 then BlockLen := 64 else BlockLen := Cardinal(Length);
    LoadBlock(Cur, BlockLen, Block);
    Flags := 0;
    if Index = 0 then Flags := Flags or FlagChunkStart;
    if Index = BlockCount - 1 then
    begin
      Flags := Flags or FlagChunkEnd;
      Result.Cv := Cv;
      Result.Block := Block;
      Result.Counter := ChunkCounter;
      Result.BlockLen := BlockLen;
      Result.Flags := Flags;
      Exit;
    end;
    Compress(Cv, Block, ChunkCounter, BlockLen, Flags, Words);
    Move(Words[0], Cv[0], SizeOf(Cv));
    Cur := PByte(NativeUInt(Cur) + 64);
    Dec(Length, 64);
  end;
end;

function TBlake3Jit.OutputCv(const Value: TOutput): TCv;
var
  Words: TOutWords;
begin
  Compress(Value.Cv, Value.Block, Value.Counter, Value.BlockLen, Value.Flags, Words);
  Move(Words[0], Result[0], SizeOf(Result));
end;

function TBlake3Jit.ParentOutput(const Left, Right: TCv): TOutput;
begin
  Move(Blake3IV[0], Result.Cv[0], SizeOf(Result.Cv));
  Move(Left[0], Result.Block[0], SizeOf(Left));
  Move(Right[0], Result.Block[8], SizeOf(Right));
  Result.Counter := 0;
  Result.BlockLen := 64;
  Result.Flags := FlagParent;
end;

procedure TBlake3Jit.PushChunkCv(var Stack: TCvStack; var StackCount: Integer; const Value: TCv; TotalChunks: UInt64);
var
  Cv, Left: TCv;
  Output: TOutput;
begin
  Cv := Value;
  while (TotalChunks and 1) = 0 do
  begin
    Dec(StackCount);
    Left := Stack[StackCount];
    Output := ParentOutput(Left, Cv);
    Cv := OutputCv(Output);
    TotalChunks := TotalChunks shr 1;
  end;
  Stack[StackCount] := Cv;
  Inc(StackCount);
end;

function TBlake3Jit.Compute(Buffer: Pointer; Length: NativeUInt): TBlake3Digest;
var
  Stack: TCvStack;
  FourCvs: TFourCvs;
  StackCount: Integer;
  ChunkCount, ChunkIndex, Remaining: UInt64;
  P: PByte;
  Output: TOutput;
  Cv: TCv;
  Words: TOutWords;
  ChunkLen: NativeUInt;
  I: Integer;
begin
  if (Buffer = nil) and (Length <> 0) then raise EArgumentNilException.Create('Buffer');
  if Length = 0 then ChunkCount := 1 else ChunkCount := 1 + (UInt64(Length) - 1) div 1024;
  StackCount := 0;
  P := PByte(Buffer);
  Remaining := Length;
  ChunkIndex := 0;
  if FMode <> b3mScalar then
    while ChunkIndex + 4 <= ChunkCount - 1 do
    begin
      CompressChunks4(P, ChunkIndex, FourCvs);
      for I := 0 to 3 do PushChunkCv(Stack, StackCount, FourCvs[I], ChunkIndex + UInt64(I) + 1);
      Inc(ChunkIndex, 4);
      P := PByte(NativeUInt(P) + 4096);
      Dec(Remaining, 4096);
    end;
  while ChunkIndex < ChunkCount - 1 do
  begin
    Output := ChunkOutput(P, 1024, ChunkIndex);
    Cv := OutputCv(Output);
    PushChunkCv(Stack, StackCount, Cv, ChunkIndex + 1);
    Inc(ChunkIndex);
    P := PByte(NativeUInt(P) + 1024);
    Dec(Remaining, 1024);
  end;
  ChunkLen := NativeUInt(Remaining);
  Output := ChunkOutput(P, ChunkLen, ChunkIndex);
  while StackCount <> 0 do
  begin
    Cv := OutputCv(Output);
    Dec(StackCount);
    Output := ParentOutput(Stack[StackCount], Cv);
  end;
  Compress(Output.Cv, Output.Block, 0, Output.BlockLen, Output.Flags or FlagRoot, Words);
  Move(Words[0], Result[0], SizeOf(Result));
end;

function TBlake3Jit.Compute(const Data: TBytes): TBlake3Digest;
begin
  if Length(Data) = 0 then Result := Compute(nil, 0) else Result := Compute(@Data[0], NativeUInt(Length(Data)));
end;

end.
