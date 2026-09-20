{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
unit NativeAsm.BigInt.Jit;

interface

uses
  System.SysUtils,
  NativeAsm.Types,
  NativeAsm.Builder,
  NativeAsm.Extensions,
  NativeAsm.BigInt.Types;

type
  TBigIntJit = class
  private
    FLimbs: NativeUInt;
    FZeroCode: TExecutableCode;
    FAddCode: TExecutableCode;
    FSubCode: TExecutableCode;
    FCompareCode: TExecutableCode;
    FEqualCode: TExecutableCode;
    FIsZeroCode: TExecutableCode;
    FSelectCode: TExecutableCode;
    FSwapCode: TExecutableCode;
    FMulWordCode: TExecutableCode;
    FAddMulWordCode: TExecutableCode;
    FMulWideCode: TExecutableCode;
    class function BuildZeroKernel(Limbs: NativeUInt): TExecutableCode; static;
    class function BuildAddKernel(Limbs: NativeUInt): TExecutableCode; static;
    class function BuildSubKernel(Limbs: NativeUInt): TExecutableCode; static;
    class function BuildCompareKernel(Limbs: NativeUInt): TExecutableCode; static;
    class function BuildEqualKernel(Limbs: NativeUInt): TExecutableCode; static;
    class function BuildIsZeroKernel(Limbs: NativeUInt): TExecutableCode; static;
    class function BuildSelectKernel(Limbs: NativeUInt): TExecutableCode; static;
    class function BuildSwapKernel(Limbs: NativeUInt): TExecutableCode; static;
    class function BuildMulWordKernel(Limbs: NativeUInt; AddExisting: Boolean): TExecutableCode; static;
    class function BuildMulWideKernel(Limbs: NativeUInt): TExecutableCode; static;
    class function RangesOverlap(A: Pointer; ABytes: NativeUInt; B: Pointer; BBytes: NativeUInt): Boolean; static;
    procedure CheckValuePtr(P: Pointer; const Name: string); inline;
  public
    constructor Create(Limbs: NativeUInt);
    destructor Destroy; override;
    procedure Zero(Dst: PBigIntLimb);
    function Add(Dst, A, B: PBigIntLimb): UInt64;
    function Sub(Dst, A, B: PBigIntLimb): UInt64;
    function CompareCT(A, B: PBigIntLimb): Integer;
    function EqualCT(A, B: PBigIntLimb): UInt64;
    function IsZeroCT(A: PBigIntLimb): UInt64;
    procedure SelectCT(Dst, A, B: PBigIntLimb; ChooseA: UInt64);
    procedure SwapCT(A, B: PBigIntLimb; DoSwap: UInt64);
    function MulWord(Dst, A: PBigIntLimb; WordValue: UInt64): UInt64;
    function AddMulWord(Dst, A: PBigIntLimb; WordValue: UInt64): UInt64;
    procedure MulWide(Dst, A, B: PBigIntLimb);
    procedure SquareWide(Dst, A: PBigIntLimb);
    property Limbs: NativeUInt read FLimbs;
  end;

implementation

class function TBigIntJit.BuildZeroKernel(Limbs: NativeUInt): TExecutableCode;
var
  B: TAsmBuilder;
  I: NativeUInt;
begin
  B := TAsmBuilder.Create;
  try
    B.Xor_(RAX, RAX);
    for I := 0 to Limbs - 1 do B.Mov(QWordPtr(ridRCX, Integer(I * 8)), RAX);
    B.Ret;
    Result := TExecutableCode.FromBuilder(B);
  finally
    B.Free;
  end;
end;

class function TBigIntJit.BuildAddKernel(Limbs: NativeUInt): TExecutableCode;
var
  B: TAsmBuilder;
  I: NativeUInt;
begin
  B := TAsmBuilder.Create;
  try
    B.Mov(RAX, QWordPtr(ridRDX)).Add(RAX, QWordPtr(ridR8)).Mov(QWordPtr(ridRCX), RAX);
    for I := 1 to Limbs - 1 do B.Mov(RAX, QWordPtr(ridRDX, Integer(I * 8))).Adc(RAX, QWordPtr(ridR8, Integer(I * 8))).Mov(QWordPtr(ridRCX, Integer(I * 8)), RAX);
    B.Mov(R9, 0).Setcc(cond_JB, R9B).Mov(RAX, R9).Ret;
    Result := TExecutableCode.FromBuilder(B);
  finally
    B.Free;
  end;
end;

class function TBigIntJit.BuildSubKernel(Limbs: NativeUInt): TExecutableCode;
var
  B: TAsmBuilder;
  I: NativeUInt;
begin
  B := TAsmBuilder.Create;
  try
    B.Mov(RAX, QWordPtr(ridRDX)).Sub(RAX, QWordPtr(ridR8)).Mov(QWordPtr(ridRCX), RAX);
    for I := 1 to Limbs - 1 do B.Mov(RAX, QWordPtr(ridRDX, Integer(I * 8))).Sbb(RAX, QWordPtr(ridR8, Integer(I * 8))).Mov(QWordPtr(ridRCX, Integer(I * 8)), RAX);
    B.Mov(R9, 0).Setcc(cond_JB, R9B).Mov(RAX, R9).Ret;
    Result := TExecutableCode.FromBuilder(B);
  finally
    B.Free;
  end;
end;

class function TBigIntJit.BuildCompareKernel(Limbs: NativeUInt): TExecutableCode;
var
  B: TAsmBuilder;
  I: NativeUInt;
begin
  B := TAsmBuilder.Create;
  try
    B.Mov(R9, QWordPtr(ridRCX)).Xor_(R9, QWordPtr(ridRDX));
    for I := 1 to Limbs - 1 do B.Mov(RAX, QWordPtr(ridRCX, Integer(I * 8))).Xor_(RAX, QWordPtr(ridRDX, Integer(I * 8))).Or_(R9, RAX);
    B.Mov(RAX, QWordPtr(ridRCX)).Sub(RAX, QWordPtr(ridRDX));
    for I := 1 to Limbs - 1 do B.Mov(RAX, QWordPtr(ridRCX, Integer(I * 8))).Sbb(RAX, QWordPtr(ridRDX, Integer(I * 8)));
    B.Mov(R10, 0).Setcc(cond_JB, R10B).Test(R9, R9).Mov(R11, 0).Setcc(cond_JNE, R11B).Shl_(R10, 1).Sub(R11, R10).Mov(RAX, R11).Ret;
    Result := TExecutableCode.FromBuilder(B);
  finally
    B.Free;
  end;
end;

class function TBigIntJit.BuildEqualKernel(Limbs: NativeUInt): TExecutableCode;
var
  B: TAsmBuilder;
  I: NativeUInt;
begin
  B := TAsmBuilder.Create;
  try
    B.Mov(R9, QWordPtr(ridRCX)).Xor_(R9, QWordPtr(ridRDX));
    for I := 1 to Limbs - 1 do B.Mov(RAX, QWordPtr(ridRCX, Integer(I * 8))).Xor_(RAX, QWordPtr(ridRDX, Integer(I * 8))).Or_(R9, RAX);
    B.Test(R9, R9).Mov(RAX, 0).Setcc(cond_JE, AL).Ret;
    Result := TExecutableCode.FromBuilder(B);
  finally
    B.Free;
  end;
end;

class function TBigIntJit.BuildIsZeroKernel(Limbs: NativeUInt): TExecutableCode;
var
  B: TAsmBuilder;
  I: NativeUInt;
begin
  B := TAsmBuilder.Create;
  try
    B.Mov(R9, QWordPtr(ridRCX));
    for I := 1 to Limbs - 1 do B.Or_(R9, QWordPtr(ridRCX, Integer(I * 8)));
    B.Test(R9, R9).Mov(RAX, 0).Setcc(cond_JE, AL).Ret;
    Result := TExecutableCode.FromBuilder(B);
  finally
    B.Free;
  end;
end;

class function TBigIntJit.BuildSelectKernel(Limbs: NativeUInt): TExecutableCode;
var
  B: TAsmBuilder;
  I: NativeUInt;
begin
  B := TAsmBuilder.Create;
  try
    B.Test(R9, R9).Mov(R11, 0).Setcc(cond_JNE, R11B).Neg(R11);
    for I := 0 to Limbs - 1 do
    begin
      B.Mov(RAX, QWordPtr(ridR8, Integer(I * 8))).Mov(R10, QWordPtr(ridRDX, Integer(I * 8))).Xor_(R10, RAX).And_(R10, R11).Xor_(RAX, R10).Mov(QWordPtr(ridRCX, Integer(I * 8)), RAX);
    end;
    B.Ret;
    Result := TExecutableCode.FromBuilder(B);
  finally
    B.Free;
  end;
end;

class function TBigIntJit.BuildSwapKernel(Limbs: NativeUInt): TExecutableCode;
var
  B: TAsmBuilder;
  I: NativeUInt;
begin
  B := TAsmBuilder.Create;
  try
    B.Test(R8, R8).Mov(R11, 0).Setcc(cond_JNE, R11B).Neg(R11);
    for I := 0 to Limbs - 1 do
    begin
      B.Mov(RAX, QWordPtr(ridRCX, Integer(I * 8))).Mov(R9, QWordPtr(ridRDX, Integer(I * 8))).Mov(R10, RAX).Xor_(R10, R9).And_(R10, R11).Xor_(RAX, R10).Xor_(R9, R10).Mov(QWordPtr(ridRCX, Integer(I * 8)), RAX).Mov(QWordPtr(ridRDX, Integer(I * 8)), R9);
    end;
    B.Ret;
    Result := TExecutableCode.FromBuilder(B);
  finally
    B.Free;
  end;
end;

class function TBigIntJit.BuildMulWordKernel(Limbs: NativeUInt; AddExisting: Boolean): TExecutableCode;
var
  B: TAsmBuilder;
  I: NativeUInt;
begin
  B := TAsmBuilder.Create;
  try
    B.Mov(R10, RCX).Mov(R11, RDX).Xor_(R9, R9);
    for I := 0 to Limbs - 1 do
    begin
      B.Mov(RAX, QWordPtr(ridR11, Integer(I * 8))).Mul(R8);
      if AddExisting then B.Add(RAX, QWordPtr(ridR10, Integer(I * 8))).Adc(RDX, 0);
      B.Add(RAX, R9).Adc(RDX, 0).Mov(QWordPtr(ridR10, Integer(I * 8)), RAX).Mov(R9, RDX);
    end;
    B.Mov(RAX, R9).Ret;
    Result := TExecutableCode.FromBuilder(B);
  finally
    B.Free;
  end;
end;

class function TBigIntJit.BuildMulWideKernel(Limbs: NativeUInt): TExecutableCode;
var
  B: TAsmBuilder;
  I, J: NativeUInt;
  LLoop: TLabel;
begin
  B := TAsmBuilder.Create;
  try
    B.Mov(R10, RCX).Mov(R11, RDX).Xor_(RAX, RAX);
    for I := 0 to Limbs * 2 - 1 do B.Mov(QWordPtr(ridR10, Integer(I * 8)), RAX);
    if Limbs <= 9 then
    begin
      for I := 0 to Limbs - 1 do
      begin
        B.Xor_(R9, R9);
        for J := 0 to Limbs - 1 do
        begin
          B.Mov(RAX, QWordPtr(ridR11, Integer(J * 8))).Mul(QWordPtr(ridR8, Integer(I * 8))).Add(RAX, QWordPtr(ridR10, Integer((I + J) * 8))).Adc(RDX, 0).Add(RAX, R9).Adc(RDX, 0).Mov(QWordPtr(ridR10, Integer((I + J) * 8)), RAX).Mov(R9, RDX);
        end;
        B.Mov(QWordPtr(ridR10, Integer((I + Limbs) * 8)), R9);
      end;
    end
    else
    begin
      B.Sub(RSP, 16).Mov(QWordPtr(ridRSP), R11).Mov(QWordPtr(ridRSP, 8), R10);
      for I := 0 to Limbs - 1 do
      begin
        B.Mov(R11, QWordPtr(ridRSP)).Mov(R10, QWordPtr(ridRSP, 8));
        if I <> 0 then B.Add(R10, Int64(I * 8));
        B.Mov(RCX, Int64(Limbs)).Xor_(R9, R9);
        LLoop := B.NewLabel;
        B.Bind(LLoop).Mov(RAX, QWordPtr(ridR11)).Mul(QWordPtr(ridR8, Integer(I * 8))).Add(RAX, QWordPtr(ridR10)).Adc(RDX, 0).Add(RAX, R9).Adc(RDX, 0).Mov(QWordPtr(ridR10), RAX).Mov(R9, RDX).Add(R11, 8).Add(R10, 8).Dec_(RCX).J(cond_JNE, LLoop).Mov(QWordPtr(ridR10), R9);
      end;
      B.Add(RSP, 16);
    end;
    B.Ret;
    Result := TExecutableCode.FromBuilder(B);
  finally
    B.Free;
  end;
end;

class function TBigIntJit.RangesOverlap(A: Pointer; ABytes: NativeUInt; B: Pointer; BBytes: NativeUInt): Boolean;
var
  A0, A1, B0, B1: NativeUInt;
begin
  if (ABytes = 0) or (BBytes = 0) then Exit(False);
  A0 := NativeUInt(A); B0 := NativeUInt(B);
  if (A0 > High(NativeUInt) - ABytes) or (B0 > High(NativeUInt) - BBytes) then Exit(True);
  A1 := A0 + ABytes; B1 := B0 + BBytes;
  Result := (A0 < B1) and (B0 < A1);
end;

procedure TBigIntJit.CheckValuePtr(P: Pointer; const Name: string);
begin
  if P = nil then raise EArgumentNilException.Create(Name);
end;

constructor TBigIntJit.Create(Limbs: NativeUInt);
begin
  inherited Create;
  if (Limbs = 0) or (Limbs > BigIntMaxRecommendedLimbs) then raise EArgumentOutOfRangeException.Create('Limbs');
  FLimbs := Limbs;
  FZeroCode := BuildZeroKernel(Limbs);
  FAddCode := BuildAddKernel(Limbs);
  FSubCode := BuildSubKernel(Limbs);
  FCompareCode := BuildCompareKernel(Limbs);
  FEqualCode := BuildEqualKernel(Limbs);
  FIsZeroCode := BuildIsZeroKernel(Limbs);
  FSelectCode := BuildSelectKernel(Limbs);
  FSwapCode := BuildSwapKernel(Limbs);
  FMulWordCode := BuildMulWordKernel(Limbs, False);
  FAddMulWordCode := BuildMulWordKernel(Limbs, True);
  FMulWideCode := BuildMulWideKernel(Limbs);
end;

destructor TBigIntJit.Destroy;
begin
  FMulWideCode.Free;
  FAddMulWordCode.Free;
  FMulWordCode.Free;
  FSwapCode.Free;
  FSelectCode.Free;
  FIsZeroCode.Free;
  FEqualCode.Free;
  FCompareCode.Free;
  FSubCode.Free;
  FAddCode.Free;
  FZeroCode.Free;
  inherited;
end;

procedure TBigIntJit.Zero(Dst: PBigIntLimb);
begin
  CheckValuePtr(Dst, 'Dst');
  FZeroCode.Run(UInt64(NativeUInt(Dst)));
end;

function TBigIntJit.Add(Dst, A, B: PBigIntLimb): UInt64;
begin
  CheckValuePtr(Dst, 'Dst'); CheckValuePtr(A, 'A'); CheckValuePtr(B, 'B');
  Result := FAddCode.Run(UInt64(NativeUInt(Dst)), UInt64(NativeUInt(A)), UInt64(NativeUInt(B)));
end;

function TBigIntJit.Sub(Dst, A, B: PBigIntLimb): UInt64;
begin
  CheckValuePtr(Dst, 'Dst'); CheckValuePtr(A, 'A'); CheckValuePtr(B, 'B');
  Result := FSubCode.Run(UInt64(NativeUInt(Dst)), UInt64(NativeUInt(A)), UInt64(NativeUInt(B)));
end;

function TBigIntJit.CompareCT(A, B: PBigIntLimb): Integer;
begin
  CheckValuePtr(A, 'A'); CheckValuePtr(B, 'B');
  Result := Integer(Int64(FCompareCode.Run(UInt64(NativeUInt(A)), UInt64(NativeUInt(B)))));
end;

function TBigIntJit.EqualCT(A, B: PBigIntLimb): UInt64;
begin
  CheckValuePtr(A, 'A'); CheckValuePtr(B, 'B');
  Result := FEqualCode.Run(UInt64(NativeUInt(A)), UInt64(NativeUInt(B)));
end;

function TBigIntJit.IsZeroCT(A: PBigIntLimb): UInt64;
begin
  CheckValuePtr(A, 'A');
  Result := FIsZeroCode.Run(UInt64(NativeUInt(A)));
end;

procedure TBigIntJit.SelectCT(Dst, A, B: PBigIntLimb; ChooseA: UInt64);
begin
  CheckValuePtr(Dst, 'Dst'); CheckValuePtr(A, 'A'); CheckValuePtr(B, 'B');
  FSelectCode.Run(UInt64(NativeUInt(Dst)), UInt64(NativeUInt(A)), UInt64(NativeUInt(B)), ChooseA);
end;


procedure TBigIntJit.SwapCT(A, B: PBigIntLimb; DoSwap: UInt64);
begin
  CheckValuePtr(A, 'A'); CheckValuePtr(B, 'B');
  FSwapCode.Run(UInt64(NativeUInt(A)), UInt64(NativeUInt(B)), DoSwap);
end;

function TBigIntJit.MulWord(Dst, A: PBigIntLimb; WordValue: UInt64): UInt64;
begin
  CheckValuePtr(Dst, 'Dst'); CheckValuePtr(A, 'A');
  Result := FMulWordCode.Run(UInt64(NativeUInt(Dst)), UInt64(NativeUInt(A)), WordValue);
end;

function TBigIntJit.AddMulWord(Dst, A: PBigIntLimb; WordValue: UInt64): UInt64;
begin
  CheckValuePtr(Dst, 'Dst'); CheckValuePtr(A, 'A');
  Result := FAddMulWordCode.Run(UInt64(NativeUInt(Dst)), UInt64(NativeUInt(A)), WordValue);
end;

procedure TBigIntJit.MulWide(Dst, A, B: PBigIntLimb);
var
  Bytes: NativeUInt;
begin
  CheckValuePtr(Dst, 'Dst'); CheckValuePtr(A, 'A'); CheckValuePtr(B, 'B');
  Bytes := FLimbs * SizeOf(UInt64);
  if RangesOverlap(Dst, Bytes * 2, A, Bytes) or RangesOverlap(Dst, Bytes * 2, B, Bytes) then raise EArgumentException.Create('MulWide destination overlaps input');
  FMulWideCode.Run(UInt64(NativeUInt(Dst)), UInt64(NativeUInt(A)), UInt64(NativeUInt(B)));
end;

procedure TBigIntJit.SquareWide(Dst, A: PBigIntLimb);
begin
  MulWide(Dst, A, A);
end;

end.
