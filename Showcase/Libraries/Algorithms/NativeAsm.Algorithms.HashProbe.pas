{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
unit NativeAsm.Algorithms.HashProbe;

interface

uses
  System.SysUtils,
  NativeAsm.Types,
  NativeAsm.Builder,
  NativeAsm.Extensions,
  NativeAsm.CpuFeatures;

type
  THashProbeMode = (hpmAuto, hpmScalar, hpmSse2, hpmSse2Bmi1);

  THashProbeJit = class
  private
    FMatchCode: TExecutableCode;
    FFindCode: TExecutableCode;
    FMode: THashProbeMode;
    class procedure EmitScalarMask(B: TAsmBuilder); static;
    class procedure EmitSse2Mask(B: TAsmBuilder); static;
    class function BuildMatchKernel(Mode: THashProbeMode): TExecutableCode; static;
    class function BuildFindKernel(Mode: THashProbeMode): TExecutableCode; static;
    class function ResolveMode(Mode: THashProbeMode): THashProbeMode; static;
  public
    constructor Create(Mode: THashProbeMode = hpmAuto);
    destructor Destroy; override;
    function MatchTag16(Control: Pointer; Tag: Byte): Word;
    function FindFirstTag16(Control: Pointer; Tag: Byte): Integer;
    property Mode: THashProbeMode read FMode;
  end;

implementation

uses
  NativeAsm.Simd,
  NativeAsm.Simd.Types;

class procedure THashProbeJit.EmitScalarMask(B: TAsmBuilder);
var
  LLoop: TLabel;
begin
  LLoop := B.NewLabel;
  B.Mov(R8, RCX).Xor_(EAX, EAX).Xor_(ECX, ECX);
  B.Bind(LLoop);
  B.Movzx(R10D, BytePtr(ridR8)).Xor_(R11D, R11D).Cmp(R10D, EDX).Setcc(cond_JE, R11B).Shl_(R11D, CL).Or_(EAX, R11D);
  B.Inc_(R8).Inc_(ECX).Cmp(ECX, 16).J(cond_JB, LLoop);
end;

class procedure THashProbeJit.EmitSse2Mask(B: TAsmBuilder);
begin
  B.Mov(EAX, EDX).Imul(EAX, EAX, $01010101);
  B.Movd(XMM1, EAX).Pshufd(XMM1, XMM1, 0);
  B.Movdqu(XMM0, NativeAsm.Simd.Types.OWordPtr(ridRCX)).Pcmpeqb(XMM0, XMM1).Pmovmskb(EAX, XMM0);
end;

class function THashProbeJit.BuildMatchKernel(Mode: THashProbeMode): TExecutableCode;
var
  B: TAsmBuilder;
begin
  B := TAsmBuilder.Create;
  try
    if Mode = hpmScalar then EmitScalarMask(B) else EmitSse2Mask(B);
    B.Ret;
    Result := TExecutableCode.FromBuilder(B);
  finally
    B.Free;
  end;
end;

class function THashProbeJit.BuildFindKernel(Mode: THashProbeMode): TExecutableCode;
var
  B: TAsmBuilder;
  LNotFound: TLabel;
begin
  B := TAsmBuilder.Create;
  try
    LNotFound := B.NewLabel;
    if Mode = hpmScalar then EmitScalarMask(B) else EmitSse2Mask(B);
    B.Test(EAX, EAX).J(cond_JE, LNotFound);
    if Mode = hpmSse2Bmi1 then B.Tzcnt(EAX, EAX) else B.Bsf(EAX, EAX);
    B.Ret.Bind(LNotFound).Mov(EAX, -1).Ret;
    Result := TExecutableCode.FromBuilder(B);
  finally
    B.Free;
  end;
end;

class function THashProbeJit.ResolveMode(Mode: THashProbeMode): THashProbeMode;
var
  HasSse2, HasBmi1: Boolean;
begin
  HasSse2 := TCpuFeatures.Supports(cfSSE2);
  HasBmi1 := TCpuFeatures.Supports(cfBMI1);
  case Mode of
    hpmAuto:
      if HasSse2 and HasBmi1 then Result := hpmSse2Bmi1 else if HasSse2 then Result := hpmSse2 else Result := hpmScalar;
    hpmScalar: Result := hpmScalar;
    hpmSse2:
      begin
        if not HasSse2 then raise EInvalidOp.Create('SSE2 is not available on this CPU');
        Result := hpmSse2;
      end;
    hpmSse2Bmi1:
      begin
        if not HasSse2 then raise EInvalidOp.Create('SSE2 is not available on this CPU');
        if not HasBmi1 then raise EInvalidOp.Create('BMI1 is not available on this CPU');
        Result := hpmSse2Bmi1;
      end;
  else
    raise EArgumentException.Create('Invalid hash probe mode');
  end;
end;

constructor THashProbeJit.Create(Mode: THashProbeMode);
begin
  inherited Create;
  FMode := ResolveMode(Mode);
  FMatchCode := BuildMatchKernel(FMode);
  FFindCode := BuildFindKernel(FMode);
end;

destructor THashProbeJit.Destroy;
begin
  FFindCode.Free;
  FMatchCode.Free;
  inherited;
end;

function THashProbeJit.MatchTag16(Control: Pointer; Tag: Byte): Word;
begin
  if Control = nil then raise EArgumentNilException.Create('Control');
  Result := Word(Cardinal(FMatchCode.Run(UInt64(NativeUInt(Control)), UInt64(Tag))) and $FFFF);
end;

function THashProbeJit.FindFirstTag16(Control: Pointer; Tag: Byte): Integer;
begin
  if Control = nil then raise EArgumentNilException.Create('Control');
  Result := Integer(Cardinal(FFindCode.Run(UInt64(NativeUInt(Control)), UInt64(Tag))));
end;

end.
