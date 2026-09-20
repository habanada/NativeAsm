{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
unit NativeAsm.Strings;

interface

uses
  System.SysUtils,
  NativeAsm.Types,
  NativeAsm.Builder,
  NativeAsm.Extensions,
  NativeAsm.CpuFeatures;

type
  TNativeStringMode = (nsmAuto, nsmScalar, nsmSse2);

  TNativeStringJit = class
  private
    FLength8Code: TExecutableCode;
    FLength16Code: TExecutableCode;
    FMode: TNativeStringMode;
    class function ResolveMode(Mode: TNativeStringMode): TNativeStringMode; static;
    class function BuildLength8Kernel(Mode: TNativeStringMode): TExecutableCode; static;
    class function BuildLength16Kernel(Mode: TNativeStringMode): TExecutableCode; static;
  public
    constructor Create(Mode: TNativeStringMode = nsmAuto);
    destructor Destroy; override;
    function Length8(Value: PAnsiChar): NativeUInt;
    function Length16(Value: PWideChar): NativeUInt;
    property Mode: TNativeStringMode read FMode;
  end;

implementation

uses
  NativeAsm.Simd,
  NativeAsm.Simd.Types;

class function TNativeStringJit.ResolveMode(Mode: TNativeStringMode): TNativeStringMode;
begin
  case Mode of
    nsmAuto: if TCpuFeatures.Supports(cfSSE2) then Result := nsmSse2 else Result := nsmScalar;
    nsmScalar: Result := nsmScalar;
    nsmSse2:
      begin
        if not TCpuFeatures.Supports(cfSSE2) then raise EInvalidOp.Create('SSE2 is not available on this CPU');
        Result := nsmSse2;
      end;
  else
    raise EArgumentException.Create('Invalid string mode');
  end;
end;

class function TNativeStringJit.BuildLength8Kernel(Mode: TNativeStringMode): TExecutableCode;
var
  B: TAsmBuilder;
  LCheck, LScalar, LVectorFound, LScalarFound: TLabel;
begin
  B := TAsmBuilder.Create;
  try
    LCheck := B.NewLabel;
    LScalar := B.NewLabel;
    LVectorFound := B.NewLabel;
    LScalarFound := B.NewLabel;
    B.Mov(R9, RCX);
    if Mode = nsmSse2 then
    begin
      B.Pxor(XMM1, XMM1).Bind(LCheck).Mov(RAX, RCX).And_(EAX, $FFF).Cmp(EAX, $FF0).J(cond_JA, LScalar);
      B.Movdqu(XMM0, NativeAsm.Simd.Types.OWordPtr(ridRCX)).Pcmpeqb(XMM0, XMM1).Pmovmskb(EAX, XMM0).Test(EAX, EAX).J(cond_JNE, LVectorFound).Add(RCX, 16).J(cond_JMP, LCheck);
      B.Bind(LScalar).Cmp(BytePtr(ridRCX), 0).J(cond_JE, LScalarFound).Inc_(RCX).J(cond_JMP, LCheck);
      B.Bind(LVectorFound).Bsf(EAX, EAX).Sub(RCX, R9).Add(RAX, RCX).Ret;
    end
    else
    begin
      B.Bind(LScalar).Cmp(BytePtr(ridRCX), 0).J(cond_JE, LScalarFound).Inc_(RCX).J(cond_JMP, LScalar);
    end;
    B.Bind(LScalarFound).Sub(RCX, R9).Mov(RAX, RCX).Ret;
    Result := TExecutableCode.FromBuilder(B);
  finally
    B.Free;
  end;
end;

class function TNativeStringJit.BuildLength16Kernel(Mode: TNativeStringMode): TExecutableCode;
var
  B: TAsmBuilder;
  LCheck, LScalar, LVectorFound, LScalarFound: TLabel;
begin
  B := TAsmBuilder.Create;
  try
    LCheck := B.NewLabel;
    LScalar := B.NewLabel;
    LVectorFound := B.NewLabel;
    LScalarFound := B.NewLabel;
    B.Mov(R9, RCX);
    if Mode = nsmSse2 then
    begin
      B.Pxor(XMM1, XMM1).Bind(LCheck).Mov(RAX, RCX).And_(EAX, $FFF).Cmp(EAX, $FF0).J(cond_JA, LScalar);
      B.Movdqu(XMM0, NativeAsm.Simd.Types.OWordPtr(ridRCX)).Pcmpeqw(XMM0, XMM1).Pmovmskb(EAX, XMM0).Test(EAX, EAX).J(cond_JNE, LVectorFound).Add(RCX, 16).J(cond_JMP, LCheck);
      B.Bind(LScalar).Cmp(WordPtr(ridRCX), 0).J(cond_JE, LScalarFound).Add(RCX, 2).J(cond_JMP, LCheck);
      B.Bind(LVectorFound).Bsf(EAX, EAX).Shr_(EAX, 1).Sub(RCX, R9).Shr_(RCX, 1).Add(RAX, RCX).Ret;
    end
    else
    begin
      B.Bind(LScalar).Cmp(WordPtr(ridRCX), 0).J(cond_JE, LScalarFound).Add(RCX, 2).J(cond_JMP, LScalar);
    end;
    B.Bind(LScalarFound).Sub(RCX, R9).Shr_(RCX, 1).Mov(RAX, RCX).Ret;
    Result := TExecutableCode.FromBuilder(B);
  finally
    B.Free;
  end;
end;

constructor TNativeStringJit.Create(Mode: TNativeStringMode);
begin
  inherited Create;
  FMode := ResolveMode(Mode);
  FLength8Code := BuildLength8Kernel(FMode);
  FLength16Code := BuildLength16Kernel(FMode);
end;

destructor TNativeStringJit.Destroy;
begin
  FLength16Code.Free;
  FLength8Code.Free;
  inherited;
end;

function TNativeStringJit.Length8(Value: PAnsiChar): NativeUInt;
begin
  if Value = nil then raise EArgumentNilException.Create('Value');
  Result := NativeUInt(FLength8Code.Run(UInt64(NativeUInt(Value))));
end;

function TNativeStringJit.Length16(Value: PWideChar): NativeUInt;
begin
  if Value = nil then raise EArgumentNilException.Create('Value');
  Result := NativeUInt(FLength16Code.Run(UInt64(NativeUInt(Value))));
end;

end.
