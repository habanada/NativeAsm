{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
unit NativeAsm.Memory;

interface

uses
  System.SysUtils,
  NativeAsm.Types,
  NativeAsm.Builder,
  NativeAsm.Extensions,
  NativeAsm.CpuFeatures;

type
  TNativeMemoryMode = (nmmAuto, nmmScalar, nmmSse2);

  TNativeMemoryJit = class
  private
    FCompareCode: TExecutableCode;
    FFindByteCode: TExecutableCode;
    FFillCode: TExecutableCode;
    FCopyCode: TExecutableCode;
    FMode: TNativeMemoryMode;
    class function ResolveMode(Mode: TNativeMemoryMode): TNativeMemoryMode; static;
    class function BuildCompareKernel(Mode: TNativeMemoryMode): TExecutableCode; static;
    class function BuildFindByteKernel(Mode: TNativeMemoryMode): TExecutableCode; static;
    class function BuildFillKernel(Mode: TNativeMemoryMode): TExecutableCode; static;
    class function BuildCopyKernel(Mode: TNativeMemoryMode): TExecutableCode; static;
    class procedure ValidateBuffer(Buffer: Pointer; Length: NativeUInt; const Name: string); static;
  public
    constructor Create(Mode: TNativeMemoryMode = nmmAuto);
    destructor Destroy; override;
    function Compare(A, B: Pointer; Length: NativeUInt): Integer;
    function FindByte(Buffer: Pointer; Length: NativeUInt; Value: Byte): NativeInt;
    procedure Fill(Buffer: Pointer; Length: NativeUInt; Value: Byte);
    procedure Copy(Dest, Src: Pointer; Length: NativeUInt);
    property Mode: TNativeMemoryMode read FMode;
  end;

implementation

uses
  NativeAsm.Simd,
  NativeAsm.Simd.Types;

class procedure TNativeMemoryJit.ValidateBuffer(Buffer: Pointer; Length: NativeUInt; const Name: string);
begin
  if (Buffer = nil) and (Length <> 0) then raise EArgumentNilException.Create(Name);
end;

class function TNativeMemoryJit.ResolveMode(Mode: TNativeMemoryMode): TNativeMemoryMode;
begin
  case Mode of
    nmmAuto: if TCpuFeatures.Supports(cfSSE2) then Result := nmmSse2 else Result := nmmScalar;
    nmmScalar: Result := nmmScalar;
    nmmSse2:
      begin
        if not TCpuFeatures.Supports(cfSSE2) then raise EInvalidOp.Create('SSE2 is not available on this CPU');
        Result := nmmSse2;
      end;
  else
    raise EArgumentException.Create('Invalid memory mode');
  end;
end;

class function TNativeMemoryJit.BuildCompareKernel(Mode: TNativeMemoryMode): TExecutableCode;
var
  Builder: TAsmBuilder;
  LVectorLoop, LScalarLoop, LTail, LVectorDifference, LScalarDifference, LEqual: TLabel;
begin
  Builder := TAsmBuilder.Create;
  try
    LScalarLoop := Builder.NewLabel;
    LTail := Builder.NewLabel;
    LVectorDifference := Builder.NewLabel;
    LScalarDifference := Builder.NewLabel;
    LEqual := Builder.NewLabel;
    if Mode = nmmSse2 then
    begin
      LVectorLoop := Builder.NewLabel;
      Builder.Cmp(R8, 16).J(cond_JB, LTail).Bind(LVectorLoop);
      Builder.Movdqu(XMM0, NativeAsm.Simd.Types.OWordPtr(ridRCX)).Movdqu(XMM1, NativeAsm.Simd.Types.OWordPtr(ridRDX)).Pcmpeqb(XMM0, XMM1).Pmovmskb(EAX, XMM0);
      Builder.Cmp(EAX, $FFFF).J(cond_JNE, LVectorDifference).Add(RCX, 16).Add(RDX, 16).Sub(R8, 16).Cmp(R8, 16).J(cond_JAE, LVectorLoop);
      Builder.Bind(LTail).Test(R8, R8).J(cond_JE, LEqual).Bind(LScalarLoop);
      Builder.Movzx(EAX, BytePtr(ridRCX)).Movzx(R10D, BytePtr(ridRDX)).Cmp(EAX, R10D).J(cond_JNE, LScalarDifference);
      Builder.Inc_(RCX).Inc_(RDX).Dec_(R8).J(cond_JNE, LScalarLoop).J(cond_JMP, LEqual);
      Builder.Bind(LVectorDifference).Xor_(EAX, $FFFF).Bsf(R10D, EAX);
      Builder.Movzx(EAX, TMemory.CreateSib(ridRCX, ridR10, s1, 0, sz8)).Movzx(R11D, TMemory.CreateSib(ridRDX, ridR10, s1, 0, sz8)).Sub(EAX, R11D).Ret;
    end
    else
    begin
      Builder.Test(R8, R8).J(cond_JE, LEqual).Bind(LScalarLoop);
      Builder.Movzx(EAX, BytePtr(ridRCX)).Movzx(R10D, BytePtr(ridRDX)).Cmp(EAX, R10D).J(cond_JNE, LScalarDifference);
      Builder.Inc_(RCX).Inc_(RDX).Dec_(R8).J(cond_JNE, LScalarLoop).J(cond_JMP, LEqual);
    end;
    Builder.Bind(LScalarDifference).Sub(EAX, R10D).Ret;
    Builder.Bind(LEqual).Xor_(EAX, EAX).Ret;
    Result := TExecutableCode.FromBuilder(Builder);
  finally
    Builder.Free;
  end;
end;

class function TNativeMemoryJit.BuildFindByteKernel(Mode: TNativeMemoryMode): TExecutableCode;
var
  Builder: TAsmBuilder;
  LVectorLoop, LScalarLoop, LTail, LVectorFound, LScalarFound, LNotFound: TLabel;
begin
  Builder := TAsmBuilder.Create;
  try
    LScalarLoop := Builder.NewLabel;
    LTail := Builder.NewLabel;
    LVectorFound := Builder.NewLabel;
    LScalarFound := Builder.NewLabel;
    LNotFound := Builder.NewLabel;
    Builder.Mov(R9, RCX);
    if Mode = nmmSse2 then
    begin
      LVectorLoop := Builder.NewLabel;
      Builder.Mov(EAX, R8D).Imul(EAX, EAX, $01010101).Movd(XMM1, EAX).Pshufd(XMM1, XMM1, 0);
      Builder.Cmp(RDX, 16).J(cond_JB, LTail).Bind(LVectorLoop);
      Builder.Movdqu(XMM0, NativeAsm.Simd.Types.OWordPtr(ridRCX)).Pcmpeqb(XMM0, XMM1).Pmovmskb(EAX, XMM0).Test(EAX, EAX).J(cond_JNE, LVectorFound);
      Builder.Add(RCX, 16).Sub(RDX, 16).Cmp(RDX, 16).J(cond_JAE, LVectorLoop);
      Builder.Bind(LTail).Test(RDX, RDX).J(cond_JE, LNotFound).Bind(LScalarLoop);
    end
    else
      Builder.Test(RDX, RDX).J(cond_JE, LNotFound).Bind(LScalarLoop);
    Builder.Movzx(EAX, BytePtr(ridRCX)).Cmp(EAX, R8D).J(cond_JE, LScalarFound).Inc_(RCX).Dec_(RDX).J(cond_JNE, LScalarLoop).J(cond_JMP, LNotFound);
    if Mode = nmmSse2 then
    begin
      Builder.Bind(LVectorFound).Bsf(EAX, EAX).Sub(RCX, R9).Add(RAX, RCX).Ret;
    end;
    Builder.Bind(LScalarFound).Sub(RCX, R9).Mov(RAX, RCX).Ret;
    Builder.Bind(LNotFound).Mov(RAX, -1).Ret;
    Result := TExecutableCode.FromBuilder(Builder);
  finally
    Builder.Free;
  end;
end;

class function TNativeMemoryJit.BuildFillKernel(Mode: TNativeMemoryMode): TExecutableCode;
var
  Builder: TAsmBuilder;
  LVectorLoop, LScalarLoop, LTail, LDone: TLabel;
begin
  Builder := TAsmBuilder.Create;
  try
    LScalarLoop := Builder.NewLabel;
    LTail := Builder.NewLabel;
    LDone := Builder.NewLabel;
    if Mode = nmmSse2 then
    begin
      LVectorLoop := Builder.NewLabel;
      Builder.Mov(EAX, R8D).Imul(EAX, EAX, $01010101).Movd(XMM0, EAX).Pshufd(XMM0, XMM0, 0);
      Builder.Cmp(RDX, 16).J(cond_JB, LTail).Bind(LVectorLoop).Movdqu(NativeAsm.Simd.Types.OWordPtr(ridRCX), XMM0);
      Builder.Add(RCX, 16).Sub(RDX, 16).Cmp(RDX, 16).J(cond_JAE, LVectorLoop).Bind(LTail).Test(RDX, RDX).J(cond_JE, LDone).Bind(LScalarLoop);
    end
    else
      Builder.Test(RDX, RDX).J(cond_JE, LDone).Bind(LScalarLoop);
    Builder.Mov(BytePtr(ridRCX), R8B).Inc_(RCX).Dec_(RDX).J(cond_JNE, LScalarLoop).Bind(LDone).Ret;
    Result := TExecutableCode.FromBuilder(Builder);
  finally
    Builder.Free;
  end;
end;

class function TNativeMemoryJit.BuildCopyKernel(Mode: TNativeMemoryMode): TExecutableCode;
var
  Builder: TAsmBuilder;
  LVectorLoop, LQwordLoop, LByteLoop, LQwordCheck, LByteCheck, LDone: TLabel;
begin
  Builder := TAsmBuilder.Create;
  try
    LQwordLoop := Builder.NewLabel;
    LByteLoop := Builder.NewLabel;
    LQwordCheck := Builder.NewLabel;
    LByteCheck := Builder.NewLabel;
    LDone := Builder.NewLabel;
    if Mode = nmmSse2 then
    begin
      LVectorLoop := Builder.NewLabel;
      Builder.Cmp(R8, 16).J(cond_JB, LQwordCheck).Bind(LVectorLoop).Movdqu(XMM0, NativeAsm.Simd.Types.OWordPtr(ridRDX)).Movdqu(NativeAsm.Simd.Types.OWordPtr(ridRCX), XMM0);
      Builder.Add(RCX, 16).Add(RDX, 16).Sub(R8, 16).Cmp(R8, 16).J(cond_JAE, LVectorLoop);
    end;
    Builder.Bind(LQwordCheck).Cmp(R8, 8).J(cond_JB, LByteCheck).Bind(LQwordLoop).Mov(RAX, QWordPtr(ridRDX)).Mov(QWordPtr(ridRCX), RAX);
    Builder.Add(RCX, 8).Add(RDX, 8).Sub(R8, 8).Cmp(R8, 8).J(cond_JAE, LQwordLoop);
    Builder.Bind(LByteCheck).Test(R8, R8).J(cond_JE, LDone).Bind(LByteLoop).Mov(AL, BytePtr(ridRDX)).Mov(BytePtr(ridRCX), AL);
    Builder.Inc_(RCX).Inc_(RDX).Dec_(R8).J(cond_JNE, LByteLoop).Bind(LDone).Ret;
    Result := TExecutableCode.FromBuilder(Builder);
  finally
    Builder.Free;
  end;
end;

constructor TNativeMemoryJit.Create(Mode: TNativeMemoryMode);
begin
  inherited Create;
  FMode := ResolveMode(Mode);
  FCompareCode := BuildCompareKernel(FMode);
  FFindByteCode := BuildFindByteKernel(FMode);
  FFillCode := BuildFillKernel(FMode);
  FCopyCode := BuildCopyKernel(FMode);
end;

destructor TNativeMemoryJit.Destroy;
begin
  FCopyCode.Free;
  FFillCode.Free;
  FFindByteCode.Free;
  FCompareCode.Free;
  inherited;
end;

function TNativeMemoryJit.Compare(A, B: Pointer; Length: NativeUInt): Integer;
begin
  ValidateBuffer(A, Length, 'A');
  ValidateBuffer(B, Length, 'B');
  Result := Integer(Cardinal(FCompareCode.Run(UInt64(NativeUInt(A)), UInt64(NativeUInt(B)), UInt64(Length))));
end;

function TNativeMemoryJit.FindByte(Buffer: Pointer; Length: NativeUInt; Value: Byte): NativeInt;
begin
  ValidateBuffer(Buffer, Length, 'Buffer');
  Result := NativeInt(Int64(FFindByteCode.Run(UInt64(NativeUInt(Buffer)), UInt64(Length), UInt64(Value))));
end;

procedure TNativeMemoryJit.Fill(Buffer: Pointer; Length: NativeUInt; Value: Byte);
begin
  ValidateBuffer(Buffer, Length, 'Buffer');
  FFillCode.Run(UInt64(NativeUInt(Buffer)), UInt64(Length), UInt64(Value));
end;

procedure TNativeMemoryJit.Copy(Dest, Src: Pointer; Length: NativeUInt);
begin
  ValidateBuffer(Dest, Length, 'Dest');
  ValidateBuffer(Src, Length, 'Src');
  FCopyCode.Run(UInt64(NativeUInt(Dest)), UInt64(NativeUInt(Src)), UInt64(Length));
end;

end.
