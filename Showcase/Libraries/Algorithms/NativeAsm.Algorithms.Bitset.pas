{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
unit NativeAsm.Algorithms.Bitset;

interface

uses
  System.SysUtils,
  NativeAsm.Types,
  NativeAsm.Builder,
  NativeAsm.Extensions,
  NativeAsm.CpuFeatures;

type
  TBitsetLogicMode = (blmAuto, blmScalar, blmSse2);
  TBitsetCountMode = (bcmAuto, bcmScalar, bcmPopcnt);
  TBitsetScanMode = (bsmAuto, bsmBsf, bsmTzcnt);

  TBitsetJit = class
  private type
    TLogicOp = (loAnd, loOr, loXor);
  private
    FAndCode: TExecutableCode;
    FOrCode: TExecutableCode;
    FXorCode: TExecutableCode;
    FInvertCode: TExecutableCode;
    FCountCode: TExecutableCode;
    FScanCode: TExecutableCode;
    FLogicMode: TBitsetLogicMode;
    FCountMode: TBitsetCountMode;
    FScanMode: TBitsetScanMode;
    class function ResolveLogicMode(Mode: TBitsetLogicMode): TBitsetLogicMode; static;
    class function ResolveCountMode(Mode: TBitsetCountMode): TBitsetCountMode; static;
    class function ResolveScanMode(Mode: TBitsetScanMode): TBitsetScanMode; static;
    class function BuildBinaryKernel(Op: TLogicOp; Mode: TBitsetLogicMode): TExecutableCode; static;
    class function BuildInvertKernel(Mode: TBitsetLogicMode): TExecutableCode; static;
    class function BuildCountKernel(Mode: TBitsetCountMode): TExecutableCode; static;
    class function BuildScanKernel(Mode: TBitsetScanMode): TExecutableCode; static;
    class procedure ValidateBuffer(Buffer: Pointer; QWordCount: NativeUInt); static;
  public
    constructor Create(LogicMode: TBitsetLogicMode = blmAuto; CountMode: TBitsetCountMode = bcmAuto; ScanMode: TBitsetScanMode = bsmAuto);
    destructor Destroy; override;
    procedure AndBits(Dest, A, B: Pointer; QWordCount: NativeUInt);
    procedure OrBits(Dest, A, B: Pointer; QWordCount: NativeUInt);
    procedure XorBits(Dest, A, B: Pointer; QWordCount: NativeUInt);
    procedure Invert(Dest, A: Pointer; QWordCount: NativeUInt);
    function PopCount(A: Pointer; QWordCount: NativeUInt): UInt64;
    function FindFirstSet(A: Pointer; QWordCount: NativeUInt): NativeInt;
    function FindNextSet(A: Pointer; QWordCount: NativeUInt; StartBit: NativeUInt): NativeInt;
    property LogicMode: TBitsetLogicMode read FLogicMode;
    property CountMode: TBitsetCountMode read FCountMode;
    property ScanMode: TBitsetScanMode read FScanMode;
  end;

implementation

uses
  NativeAsm.Simd,
  NativeAsm.Simd.Types;

class procedure TBitsetJit.ValidateBuffer(Buffer: Pointer; QWordCount: NativeUInt);
begin
  if (Buffer = nil) and (QWordCount <> 0) then raise EArgumentNilException.Create('Buffer');
end;

class function TBitsetJit.ResolveLogicMode(Mode: TBitsetLogicMode): TBitsetLogicMode;
begin
  case Mode of
    blmAuto: if TCpuFeatures.Supports(cfSSE2) then Result := blmSse2 else Result := blmScalar;
    blmScalar: Result := blmScalar;
    blmSse2:
      begin
        if not TCpuFeatures.Supports(cfSSE2) then raise EInvalidOp.Create('SSE2 is not available on this CPU');
        Result := blmSse2;
      end;
  else
    raise EArgumentException.Create('Invalid bitset logic mode');
  end;
end;

class function TBitsetJit.ResolveCountMode(Mode: TBitsetCountMode): TBitsetCountMode;
begin
  case Mode of
    bcmAuto: if TCpuFeatures.Supports(cfPOPCNT) then Result := bcmPopcnt else Result := bcmScalar;
    bcmScalar: Result := bcmScalar;
    bcmPopcnt:
      begin
        if not TCpuFeatures.Supports(cfPOPCNT) then raise EInvalidOp.Create('POPCNT is not available on this CPU');
        Result := bcmPopcnt;
      end;
  else
    raise EArgumentException.Create('Invalid bitset count mode');
  end;
end;

class function TBitsetJit.ResolveScanMode(Mode: TBitsetScanMode): TBitsetScanMode;
begin
  case Mode of
    bsmAuto: if TCpuFeatures.Supports(cfBMI1) then Result := bsmTzcnt else Result := bsmBsf;
    bsmBsf: Result := bsmBsf;
    bsmTzcnt:
      begin
        if not TCpuFeatures.Supports(cfBMI1) then raise EInvalidOp.Create('BMI1 is not available on this CPU');
        Result := bsmTzcnt;
      end;
  else
    raise EArgumentException.Create('Invalid bitset scan mode');
  end;
end;

class function TBitsetJit.BuildBinaryKernel(Op: TLogicOp; Mode: TBitsetLogicMode): TExecutableCode;
var
  Builder: TAsmBuilder;
  LVectorLoop, LScalarLoop, LTail, LDone: TLabel;
begin
  Builder := TAsmBuilder.Create;
  try
    LScalarLoop := Builder.NewLabel;
    LTail := Builder.NewLabel;
    LDone := Builder.NewLabel;
    if Mode = blmSse2 then
    begin
      LVectorLoop := Builder.NewLabel;
      Builder.Cmp(R9, 2).J(cond_JB, LTail);
      Builder.Bind(LVectorLoop);
      Builder.Movdqu(XMM0, NativeAsm.Simd.Types.OWordPtr(ridRDX)).Movdqu(XMM1, NativeAsm.Simd.Types.OWordPtr(ridR8));
      case Op of
        loAnd: Builder.Pand(XMM0, XMM1);
        loOr: Builder.Por(XMM0, XMM1);
        loXor: Builder.Pxor(XMM0, XMM1);
      end;
      Builder.Movdqu(NativeAsm.Simd.Types.OWordPtr(ridRCX), XMM0).Add(RCX, 16).Add(RDX, 16).Add(R8, 16).Sub(R9, 2).Cmp(R9, 2).J(cond_JAE, LVectorLoop);
      Builder.Bind(LTail).Test(R9, R9).J(cond_JE, LDone);
      Builder.Mov(RAX, QWordPtr(ridRDX));
      case Op of
        loAnd: Builder.And_(RAX, QWordPtr(ridR8));
        loOr: Builder.Or_(RAX, QWordPtr(ridR8));
        loXor: Builder.Xor_(RAX, QWordPtr(ridR8));
      end;
      Builder.Mov(QWordPtr(ridRCX), RAX).J(cond_JMP, LDone);
    end
    else
    begin
      Builder.Test(R9, R9).J(cond_JE, LDone).Bind(LScalarLoop).Mov(RAX, QWordPtr(ridRDX));
      case Op of
        loAnd: Builder.And_(RAX, QWordPtr(ridR8));
        loOr: Builder.Or_(RAX, QWordPtr(ridR8));
        loXor: Builder.Xor_(RAX, QWordPtr(ridR8));
      end;
      Builder.Mov(QWordPtr(ridRCX), RAX).Add(RCX, 8).Add(RDX, 8).Add(R8, 8).Dec_(R9).J(cond_JNE, LScalarLoop);
    end;
    Builder.Bind(LDone).Ret;
    Result := TExecutableCode.FromBuilder(Builder);
  finally
    Builder.Free;
  end;
end;

class function TBitsetJit.BuildInvertKernel(Mode: TBitsetLogicMode): TExecutableCode;
var
  Builder: TAsmBuilder;
  LVectorLoop, LScalarLoop, LTail, LDone: TLabel;
begin
  Builder := TAsmBuilder.Create;
  try
    LScalarLoop := Builder.NewLabel;
    LTail := Builder.NewLabel;
    LDone := Builder.NewLabel;
    if Mode = blmSse2 then
    begin
      LVectorLoop := Builder.NewLabel;
      Builder.Pcmpeqb(XMM1, XMM1).Cmp(R8, 2).J(cond_JB, LTail);
      Builder.Bind(LVectorLoop);
      Builder.Movdqu(XMM0, NativeAsm.Simd.Types.OWordPtr(ridRDX)).Pxor(XMM0, XMM1).Movdqu(NativeAsm.Simd.Types.OWordPtr(ridRCX), XMM0);
      Builder.Add(RCX, 16).Add(RDX, 16).Sub(R8, 2).Cmp(R8, 2).J(cond_JAE, LVectorLoop);
      Builder.Bind(LTail).Test(R8, R8).J(cond_JE, LDone).Mov(RAX, QWordPtr(ridRDX)).Not_(RAX).Mov(QWordPtr(ridRCX), RAX).J(cond_JMP, LDone);
    end
    else
    begin
      Builder.Test(R8, R8).J(cond_JE, LDone).Bind(LScalarLoop).Mov(RAX, QWordPtr(ridRDX)).Not_(RAX).Mov(QWordPtr(ridRCX), RAX);
      Builder.Add(RCX, 8).Add(RDX, 8).Dec_(R8).J(cond_JNE, LScalarLoop);
    end;
    Builder.Bind(LDone).Ret;
    Result := TExecutableCode.FromBuilder(Builder);
  finally
    Builder.Free;
  end;
end;

class function TBitsetJit.BuildCountKernel(Mode: TBitsetCountMode): TExecutableCode;
var
  Builder: TAsmBuilder;
  LLoop, LDone: TLabel;
begin
  Builder := TAsmBuilder.Create;
  try
    LLoop := Builder.NewLabel;
    LDone := Builder.NewLabel;
    Builder.Xor_(R8, R8).Test(RDX, RDX).J(cond_JE, LDone).Bind(LLoop).Mov(R9, QWordPtr(ridRCX));
    if Mode = bcmPopcnt then
      Builder.Popcnt(R9, R9)
    else
    begin
      Builder.Mov(R10, R9).Shr_(R10, 1).Mov(R11, Int64($5555555555555555)).And_(R10, R11).Sub(R9, R10);
      Builder.Mov(R10, R9).Shr_(R10, 2).Mov(R11, Int64($3333333333333333)).And_(R9, R11).And_(R10, R11).Add(R9, R10);
      Builder.Mov(R10, R9).Shr_(R10, 4).Add(R9, R10).Mov(R11, Int64($0F0F0F0F0F0F0F0F)).And_(R9, R11);
      Builder.Mov(R11, Int64($0101010101010101)).Imul(R9, R11).Shr_(R9, 56);
    end;
    Builder.Add(R8, R9).Add(RCX, 8).Dec_(RDX).J(cond_JNE, LLoop).Bind(LDone).Mov(RAX, R8).Ret;
    Result := TExecutableCode.FromBuilder(Builder);
  finally
    Builder.Free;
  end;
end;

class function TBitsetJit.BuildScanKernel(Mode: TBitsetScanMode): TExecutableCode;
var
  Builder: TAsmBuilder;
  LLoop, LFound, LNotFound: TLabel;
begin
  Builder := TAsmBuilder.Create;
  try
    LLoop := Builder.NewLabel;
    LFound := Builder.NewLabel;
    LNotFound := Builder.NewLabel;
    Builder.Mov(RAX, RCX).Mov(R9, R8).Shr_(R9, 6).Cmp(R9, RDX).J(cond_JAE, LNotFound);
    Builder.Mov(ECX, R8D).And_(ECX, 63).Mov(R11, TMemory.CreateSib(ridRAX, ridR9, s8, 0, sz64));
    Builder.Mov(R10, -1).Shl_(R10, CL).And_(R11, R10).Test(R11, R11).J(cond_JNE, LFound);
    Builder.Inc_(R9).Bind(LLoop).Cmp(R9, RDX).J(cond_JAE, LNotFound).Mov(R11, TMemory.CreateSib(ridRAX, ridR9, s8, 0, sz64)).Test(R11, R11).J(cond_JNE, LFound).Inc_(R9).J(cond_JMP, LLoop);
    Builder.Bind(LFound);
    if Mode = bsmTzcnt then Builder.Tzcnt(R11, R11) else Builder.Bsf(R11, R11);
    Builder.Shl_(R9, 6).Add(R11, R9).Mov(RAX, R11).Ret;
    Builder.Bind(LNotFound).Mov(RAX, -1).Ret;
    Result := TExecutableCode.FromBuilder(Builder);
  finally
    Builder.Free;
  end;
end;

constructor TBitsetJit.Create(LogicMode: TBitsetLogicMode; CountMode: TBitsetCountMode; ScanMode: TBitsetScanMode);
begin
  inherited Create;
  FLogicMode := ResolveLogicMode(LogicMode);
  FCountMode := ResolveCountMode(CountMode);
  FScanMode := ResolveScanMode(ScanMode);
  FAndCode := BuildBinaryKernel(loAnd, FLogicMode);
  FOrCode := BuildBinaryKernel(loOr, FLogicMode);
  FXorCode := BuildBinaryKernel(loXor, FLogicMode);
  FInvertCode := BuildInvertKernel(FLogicMode);
  FCountCode := BuildCountKernel(FCountMode);
  FScanCode := BuildScanKernel(FScanMode);
end;

destructor TBitsetJit.Destroy;
begin
  FScanCode.Free;
  FCountCode.Free;
  FInvertCode.Free;
  FXorCode.Free;
  FOrCode.Free;
  FAndCode.Free;
  inherited;
end;

procedure TBitsetJit.AndBits(Dest, A, B: Pointer; QWordCount: NativeUInt);
begin
  ValidateBuffer(Dest, QWordCount);
  ValidateBuffer(A, QWordCount);
  ValidateBuffer(B, QWordCount);
  FAndCode.Run(UInt64(NativeUInt(Dest)), UInt64(NativeUInt(A)), UInt64(NativeUInt(B)), UInt64(QWordCount));
end;

procedure TBitsetJit.OrBits(Dest, A, B: Pointer; QWordCount: NativeUInt);
begin
  ValidateBuffer(Dest, QWordCount);
  ValidateBuffer(A, QWordCount);
  ValidateBuffer(B, QWordCount);
  FOrCode.Run(UInt64(NativeUInt(Dest)), UInt64(NativeUInt(A)), UInt64(NativeUInt(B)), UInt64(QWordCount));
end;

procedure TBitsetJit.XorBits(Dest, A, B: Pointer; QWordCount: NativeUInt);
begin
  ValidateBuffer(Dest, QWordCount);
  ValidateBuffer(A, QWordCount);
  ValidateBuffer(B, QWordCount);
  FXorCode.Run(UInt64(NativeUInt(Dest)), UInt64(NativeUInt(A)), UInt64(NativeUInt(B)), UInt64(QWordCount));
end;

procedure TBitsetJit.Invert(Dest, A: Pointer; QWordCount: NativeUInt);
begin
  ValidateBuffer(Dest, QWordCount);
  ValidateBuffer(A, QWordCount);
  FInvertCode.Run(UInt64(NativeUInt(Dest)), UInt64(NativeUInt(A)), UInt64(QWordCount));
end;

function TBitsetJit.PopCount(A: Pointer; QWordCount: NativeUInt): UInt64;
begin
  ValidateBuffer(A, QWordCount);
  Result := FCountCode.Run(UInt64(NativeUInt(A)), UInt64(QWordCount));
end;

function TBitsetJit.FindFirstSet(A: Pointer; QWordCount: NativeUInt): NativeInt;
begin
  Result := FindNextSet(A, QWordCount, 0);
end;

function TBitsetJit.FindNextSet(A: Pointer; QWordCount: NativeUInt; StartBit: NativeUInt): NativeInt;
begin
  ValidateBuffer(A, QWordCount);
  Result := NativeInt(Int64(FScanCode.Run(UInt64(NativeUInt(A)), UInt64(QWordCount), UInt64(StartBit))));
end;

end.
