{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
unit NativeAsm.Random.Xoshiro256pp;

interface

uses
  System.SysUtils,
  NativeAsm.Types,
  NativeAsm.Builder,
  NativeAsm.Extensions,
  NativeAsm.CpuFeatures;

type
  TXoshiro256ppState = array[0..3] of UInt64;

  TXoshiro256ppParallelState = packed record
    S0: array[0..1] of UInt64;
    S1: array[0..1] of UInt64;
    S2: array[0..1] of UInt64;
    S3: array[0..1] of UInt64;
  end;

  TXoshiro256ppJit = class
  private
    FFillCode: TExecutableCode;
    class function BuildFillKernel: TExecutableCode; static;
    class function SplitMix64(var Seed: UInt64): UInt64; static;
    class function StepReference(var State: TXoshiro256ppState): UInt64; static;
  public
    constructor Create;
    destructor Destroy; override;
    class procedure SeedState(var State: TXoshiro256ppState; Seed: UInt64); static;
    class procedure Jump(var State: TXoshiro256ppState); static;
    function NextUInt64(var State: TXoshiro256ppState): UInt64;
    procedure Fill(var State: TXoshiro256ppState; Dest: Pointer; Count: NativeUInt);
  end;

  TXoshiro256ppParallelJit = class
  private
    FFillCode: TExecutableCode;
    class function BuildFillKernel: TExecutableCode; static;
  public
    constructor Create;
    destructor Destroy; override;
    class procedure SeedState(var State: TXoshiro256ppParallelState; Seed: UInt64); static;
    procedure FillInterleaved(var State: TXoshiro256ppParallelState; Dest: Pointer; PairCount: NativeUInt);
  end;

implementation

uses
  NativeAsm.Simd,
  NativeAsm.Simd.Types;

{$Q-}

const
  JumpTable: array[0..3] of UInt64 = ($180EC6D33CFD0ABA, $D5A61266F0C9392C, $A9582618E03FC9AA, $39ABDC4529B1661C);

function Rotl64(Value: UInt64; Bits: Integer): UInt64; inline;
begin
  Result := (Value shl Bits) or (Value shr (64 - Bits));
end;

class function TXoshiro256ppJit.BuildFillKernel: TExecutableCode;
var
  B: TAsmBuilder;
  LLoop, LDone: TLabel;
begin
  B := TAsmBuilder.Create;
  try
    LLoop := B.NewLabel;
    LDone := B.NewLabel;
    B.Push(RBX).Push(RSI).Push(RDI).Push(R12).Push(R13).Push(R14).Push(R15);
    B.Mov(R12, RCX).Mov(R13, RDX).Mov(R14, R8).Mov(RBX, QWordPtr(ridR12)).Mov(RSI, QWordPtr(ridR12, 8)).Mov(RDI, QWordPtr(ridR12, 16)).Mov(R15, QWordPtr(ridR12, 24));
    B.Test(R14, R14).J(cond_JE, LDone).Bind(LLoop);
    B.Mov(RAX, RBX).Add(RAX, R15).Rol(RAX, 23).Add(RAX, RBX).Mov(QWordPtr(ridR13), RAX);
    B.Mov(R10, RSI).Shl_(R10, 17).Xor_(RDI, RBX).Xor_(R15, RSI).Xor_(RSI, RDI).Xor_(RBX, R15).Xor_(RDI, R10).Rol(R15, 45);
    B.Add(R13, 8).Dec_(R14).J(cond_JNE, LLoop);
    B.Bind(LDone).Mov(QWordPtr(ridR12), RBX).Mov(QWordPtr(ridR12, 8), RSI).Mov(QWordPtr(ridR12, 16), RDI).Mov(QWordPtr(ridR12, 24), R15);
    B.Pop(R15).Pop(R14).Pop(R13).Pop(R12).Pop(RDI).Pop(RSI).Pop(RBX).Ret;
    Result := TExecutableCode.FromBuilder(B);
  finally
    B.Free;
  end;
end;

class function TXoshiro256ppJit.SplitMix64(var Seed: UInt64): UInt64;
var
  Z: UInt64;
begin
  Seed := Seed + $9E3779B97F4A7C15;
  Z := Seed;
  Z := (Z xor (Z shr 30)) * $BF58476D1CE4E5B9;
  Z := (Z xor (Z shr 27)) * $94D049BB133111EB;
  Result := Z xor (Z shr 31);
end;

class function TXoshiro256ppJit.StepReference(var State: TXoshiro256ppState): UInt64;
var
  T: UInt64;
begin
  Result := Rotl64(State[0] + State[3], 23) + State[0];
  T := State[1] shl 17;
  State[2] := State[2] xor State[0];
  State[3] := State[3] xor State[1];
  State[1] := State[1] xor State[2];
  State[0] := State[0] xor State[3];
  State[2] := State[2] xor T;
  State[3] := Rotl64(State[3], 45);
end;

constructor TXoshiro256ppJit.Create;
begin
  inherited Create;
  FFillCode := BuildFillKernel;
end;

destructor TXoshiro256ppJit.Destroy;
begin
  FFillCode.Free;
  inherited;
end;

class procedure TXoshiro256ppJit.SeedState(var State: TXoshiro256ppState; Seed: UInt64);
var
  I: Integer;
begin
  for I := 0 to 3 do State[I] := SplitMix64(Seed);
end;

class procedure TXoshiro256ppJit.Jump(var State: TXoshiro256ppState);
var
  S: TXoshiro256ppState;
  I, B: Integer;
begin
  FillChar(S, SizeOf(S), 0);
  for I := 0 to 3 do
    for B := 0 to 63 do
    begin
      if (JumpTable[I] and (UInt64(1) shl B)) <> 0 then
      begin
        S[0] := S[0] xor State[0]; S[1] := S[1] xor State[1]; S[2] := S[2] xor State[2]; S[3] := S[3] xor State[3];
      end;
      StepReference(State);
    end;
  State := S;
end;

function TXoshiro256ppJit.NextUInt64(var State: TXoshiro256ppState): UInt64;
begin
  FFillCode.Run(UInt64(NativeUInt(@State)), UInt64(NativeUInt(@Result)), 1);
end;

procedure TXoshiro256ppJit.Fill(var State: TXoshiro256ppState; Dest: Pointer; Count: NativeUInt);
begin
  if (Dest = nil) and (Count <> 0) then raise EArgumentNilException.Create('Dest');
  if Count <> 0 then FFillCode.Run(UInt64(NativeUInt(@State)), UInt64(NativeUInt(Dest)), UInt64(Count));
end;

class function TXoshiro256ppParallelJit.BuildFillKernel: TExecutableCode;
var
  B: TAsmBuilder;
  LLoop, LDone: TLabel;
begin
  B := TAsmBuilder.Create;
  try
    LLoop := B.NewLabel;
    LDone := B.NewLabel;
    B.Movdqu(XMM0, NativeAsm.Simd.Types.OWordPtr(ridRCX)).Movdqu(XMM1, NativeAsm.Simd.Types.OWordPtr(ridRCX, 16));
    B.Movdqu(XMM2, NativeAsm.Simd.Types.OWordPtr(ridRCX, 32)).Movdqu(XMM3, NativeAsm.Simd.Types.OWordPtr(ridRCX, 48));
    B.Test(R8, R8).J(cond_JE, LDone).Bind(LLoop);
    B.Movdqa(XMM4, XMM0).Paddq(XMM4, XMM3).Movdqa(XMM5, XMM4).Psllq(XMM4, 23).Psrlq(XMM5, 41).Por(XMM4, XMM5).Paddq(XMM4, XMM0).Movdqu(NativeAsm.Simd.Types.OWordPtr(ridRDX), XMM4);
    B.Movdqa(XMM5, XMM1).Psllq(XMM5, 17).Pxor(XMM2, XMM0).Pxor(XMM3, XMM1).Pxor(XMM1, XMM2).Pxor(XMM0, XMM3).Pxor(XMM2, XMM5);
    B.Movdqa(XMM4, XMM3).Psllq(XMM3, 45).Psrlq(XMM4, 19).Por(XMM3, XMM4);
    B.Add(RDX, 16).Dec_(R8).J(cond_JNE, LLoop);
    B.Bind(LDone).Movdqu(NativeAsm.Simd.Types.OWordPtr(ridRCX), XMM0).Movdqu(NativeAsm.Simd.Types.OWordPtr(ridRCX, 16), XMM1);
    B.Movdqu(NativeAsm.Simd.Types.OWordPtr(ridRCX, 32), XMM2).Movdqu(NativeAsm.Simd.Types.OWordPtr(ridRCX, 48), XMM3).Ret;
    Result := TExecutableCode.FromBuilder(B);
  finally
    B.Free;
  end;
end;

constructor TXoshiro256ppParallelJit.Create;
begin
  inherited Create;
  if not TCpuFeatures.Supports(cfSSE2) then raise EInvalidOp.Create('SSE2 is not available on this CPU');
  FFillCode := BuildFillKernel;
end;

destructor TXoshiro256ppParallelJit.Destroy;
begin
  FFillCode.Free;
  inherited;
end;

class procedure TXoshiro256ppParallelJit.SeedState(var State: TXoshiro256ppParallelState; Seed: UInt64);
var
  A, B: TXoshiro256ppState;
begin
  TXoshiro256ppJit.SeedState(A, Seed);
  B := A;
  TXoshiro256ppJit.Jump(B);
  State.S0[0] := A[0]; State.S0[1] := B[0];
  State.S1[0] := A[1]; State.S1[1] := B[1];
  State.S2[0] := A[2]; State.S2[1] := B[2];
  State.S3[0] := A[3]; State.S3[1] := B[3];
end;

procedure TXoshiro256ppParallelJit.FillInterleaved(var State: TXoshiro256ppParallelState; Dest: Pointer; PairCount: NativeUInt);
begin
  if (Dest = nil) and (PairCount <> 0) then raise EArgumentNilException.Create('Dest');
  if PairCount <> 0 then FFillCode.Run(UInt64(NativeUInt(@State)), UInt64(NativeUInt(Dest)), UInt64(PairCount));
end;

end.
