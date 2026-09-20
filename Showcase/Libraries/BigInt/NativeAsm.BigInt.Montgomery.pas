{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
unit NativeAsm.BigInt.Montgomery;

interface

uses
  System.SysUtils,
  NativeAsm.Types,
  NativeAsm.Builder,
  NativeAsm.Extensions,
  NativeAsm.BigInt.Types,
  NativeAsm.BigInt.Core,
  NativeAsm.BigInt.Jit;

type
  TMontgomeryContext = class
  private
    FLimbs: NativeUInt;
    FModulus: TBigIntLimbs;
    FN0Inv: UInt64;
    FR2: TBigIntLimbs;
    FOneMont: TBigIntLimbs;
    FOne: TBigIntLimbs;
    FKernel: TBigIntJit;
    FMulCode: TExecutableCode;
    class function ComputeN0Inv(N0: UInt64): UInt64; static;
    class function BuildMulKernel(Limbs: NativeUInt; N0Inv: UInt64): TExecutableCode; static;
    class function BitsToInt64(Value: UInt64): Int64; static;
    procedure BuildR2;
    procedure CheckPtr(P: Pointer; const Name: string); inline;
    function GetModulus: TBigIntLimbs;
    function GetR2: TBigIntLimbs;
    function GetOneMont: TBigIntLimbs;
  public
    constructor Create(const Modulus: TBigIntLimbs);
    destructor Destroy; override;
    procedure MontMul(Dst, A, B: PBigIntLimb);
    procedure MontSquare(Dst, A: PBigIntLimb);
    procedure Encode(Dst, A: PBigIntLimb);
    procedure Decode(Dst, A: PBigIntLimb);
    procedure AddMod(Dst, A, B, Scratch0, Scratch1: PBigIntLimb); overload;
    procedure AddMod(Dst, A, B: PBigIntLimb); overload;
    procedure SubMod(Dst, A, B, Scratch0, Scratch1: PBigIntLimb); overload;
    procedure SubMod(Dst, A, B: PBigIntLimb); overload;
    procedure PowCT(Dst, Base: PBigIntLimb; ExponentBE: Pointer; ExponentBytes: NativeUInt);
    procedure PowVar(Dst, Base: PBigIntLimb; ExponentBE: Pointer; ExponentBytes: NativeUInt);
    procedure InversePrimeCT(Dst, A: PBigIntLimb);
    function IsCanonical(A: PBigIntLimb): Boolean;
    property Limbs: NativeUInt read FLimbs;
    property N0Inv: UInt64 read FN0Inv;
    property Kernel: TBigIntJit read FKernel;
    property Modulus: TBigIntLimbs read GetModulus;
    property R2: TBigIntLimbs read GetR2;
    property OneMont: TBigIntLimbs read GetOneMont;
  end;

implementation

{$Q-}
{$R-}

class function TMontgomeryContext.BitsToInt64(Value: UInt64): Int64;
begin
  Move(Value, Result, SizeOf(Result));
end;

class function TMontgomeryContext.ComputeN0Inv(N0: UInt64): UInt64;
var
  X: UInt64;
  I: Integer;
begin
  if (N0 and 1) = 0 then raise EArgumentException.Create('Modulus must be odd');
  X := 1;
  for I := 0 to 5 do X := X * (UInt64(2) - N0 * X);
  Result := UInt64(0) - X;
end;

class function TMontgomeryContext.BuildMulKernel(Limbs: NativeUInt; N0Inv: UInt64): TExecutableCode;
var
  B: TAsmBuilder;
  I, J: NativeUInt;
  ScratchBytes, StackBytes: Integer;
  LOuter, LMul, LRed, LShift: TLabel;

  procedure EmitAddCarryToTop(BaseReg: TRegID);
  begin
    B.Mov(RAX, QWordPtr(BaseReg, Integer(Limbs * 8))).Add(RAX, R9).Mov(QWordPtr(BaseReg, Integer(Limbs * 8)), RAX).Mov(RAX, QWordPtr(BaseReg, Integer((Limbs + 1) * 8))).Adc(RAX, 0).Mov(QWordPtr(BaseReg, Integer((Limbs + 1) * 8)), RAX);
  end;

  procedure EmitFinalReduce(BaseReg: TRegID);
  var
    K: NativeUInt;
  begin
    B.Mov(RAX, QWordPtr(BaseReg)).Sub(RAX, QWordPtr(ridR15)).Mov(QWordPtr(ridR12), RAX);
    for K := 1 to Limbs - 1 do B.Mov(RAX, QWordPtr(BaseReg, Integer(K * 8))).Sbb(RAX, QWordPtr(ridR15, Integer(K * 8))).Mov(QWordPtr(ridR12, Integer(K * 8)), RAX);
    B.Mov(R8, 0).Setcc(cond_JB, R8B).Mov(R9, QWordPtr(BaseReg, Integer(Limbs * 8))).Test(R9, R9).Mov(R10, 0).Setcc(cond_JE, R10B).And_(R8, R10).Neg(R8);
    for K := 0 to Limbs - 1 do B.Mov(RAX, QWordPtr(ridR12, Integer(K * 8))).Mov(R9, QWordPtr(BaseReg, Integer(K * 8))).Xor_(R9, RAX).And_(R9, R8).Xor_(RAX, R9).Mov(QWordPtr(ridR12, Integer(K * 8)), RAX);
  end;

begin
  B := TAsmBuilder.Create;
  try
    ScratchBytes := Integer((Limbs + 2) * 8);
    StackBytes := (ScratchBytes + 15) and not 15;
    if Limbs <= 9 then
    begin
      B.Push(R12).Push(R13).Push(R14).Push(R15).Mov(R12, RCX).Mov(R13, RDX).Mov(R14, R8).Mov(R15, R9).Sub(RSP, StackBytes).Xor_(RAX, RAX);
      for I := 0 to Limbs + 1 do B.Mov(QWordPtr(ridRSP, Integer(I * 8)), RAX);
      for I := 0 to Limbs - 1 do
      begin
        B.Mov(R8, QWordPtr(ridR14, Integer(I * 8))).Xor_(R9, R9);
        for J := 0 to Limbs - 1 do B.Mov(RAX, QWordPtr(ridR13, Integer(J * 8))).Mul(R8).Add(RAX, QWordPtr(ridRSP, Integer(J * 8))).Adc(RDX, 0).Add(RAX, R9).Adc(RDX, 0).Mov(QWordPtr(ridRSP, Integer(J * 8)), RAX).Mov(R9, RDX);
        EmitAddCarryToTop(ridRSP);
        B.Mov(RAX, QWordPtr(ridRSP)).Mov(R10, BitsToInt64(N0Inv)).Mul(R10).Mov(R8, RAX).Xor_(R9, R9);
        for J := 0 to Limbs - 1 do B.Mov(RAX, QWordPtr(ridR15, Integer(J * 8))).Mul(R8).Add(RAX, QWordPtr(ridRSP, Integer(J * 8))).Adc(RDX, 0).Add(RAX, R9).Adc(RDX, 0).Mov(QWordPtr(ridRSP, Integer(J * 8)), RAX).Mov(R9, RDX);
        EmitAddCarryToTop(ridRSP);
        for J := 0 to Limbs do B.Mov(RAX, QWordPtr(ridRSP, Integer((J + 1) * 8))).Mov(QWordPtr(ridRSP, Integer(J * 8)), RAX);
        B.Xor_(RAX, RAX).Mov(QWordPtr(ridRSP, Integer((Limbs + 1) * 8)), RAX);
      end;
      EmitFinalReduce(ridRSP);
      B.Add(RSP, StackBytes).Pop(R15).Pop(R14).Pop(R13).Pop(R12).Ret;
    end
    else
    begin
      B.Push(RBX).Push(RSI).Push(RDI).Push(R12).Push(R13).Push(R14).Push(R15).Mov(R12, RCX).Mov(R13, RDX).Mov(R14, R8).Mov(R15, R9).Sub(RSP, StackBytes).Mov(RSI, RSP).Xor_(RAX, RAX);
      for I := 0 to Limbs + 1 do B.Mov(QWordPtr(ridRSI, Integer(I * 8)), RAX);
      B.Mov(RBX, Int64(Limbs));
      LOuter := B.NewLabel;
      B.Bind(LOuter).Mov(R8, QWordPtr(ridR14)).Xor_(R9, R9).Mov(R10, R13).Mov(R11, RSI).Mov(RDI, Int64(Limbs));
      LMul := B.NewLabel;
      B.Bind(LMul).Mov(RAX, QWordPtr(ridR10)).Mul(R8).Add(RAX, QWordPtr(ridR11)).Adc(RDX, 0).Add(RAX, R9).Adc(RDX, 0).Mov(QWordPtr(ridR11), RAX).Mov(R9, RDX).Add(R10, 8).Add(R11, 8).Dec_(RDI).J(cond_JNE, LMul);
      EmitAddCarryToTop(ridRSI);
      B.Mov(RAX, QWordPtr(ridRSI)).Mov(R10, BitsToInt64(N0Inv)).Mul(R10).Mov(R8, RAX).Xor_(R9, R9).Mov(R10, R15).Mov(R11, RSI).Mov(RDI, Int64(Limbs));
      LRed := B.NewLabel;
      B.Bind(LRed).Mov(RAX, QWordPtr(ridR10)).Mul(R8).Add(RAX, QWordPtr(ridR11)).Adc(RDX, 0).Add(RAX, R9).Adc(RDX, 0).Mov(QWordPtr(ridR11), RAX).Mov(R9, RDX).Add(R10, 8).Add(R11, 8).Dec_(RDI).J(cond_JNE, LRed);
      EmitAddCarryToTop(ridRSI);
      B.Mov(R11, RSI).Mov(RDI, Int64(Limbs + 1));
      LShift := B.NewLabel;
      B.Bind(LShift).Mov(RAX, QWordPtr(ridR11, 8)).Mov(QWordPtr(ridR11), RAX).Add(R11, 8).Dec_(RDI).J(cond_JNE, LShift).Xor_(RAX, RAX).Mov(QWordPtr(ridRSI, Integer((Limbs + 1) * 8)), RAX).Add(R14, 8).Dec_(RBX).J(cond_JNE, LOuter);
      EmitFinalReduce(ridRSI);
      B.Add(RSP, StackBytes).Pop(R15).Pop(R14).Pop(R13).Pop(R12).Pop(RDI).Pop(RSI).Pop(RBX).Ret;
    end;
    Result := TExecutableCode.FromBuilder(B);
  finally
    B.Free;
  end;
end;

procedure TMontgomeryContext.CheckPtr(P: Pointer; const Name: string);
begin
  if P = nil then raise EArgumentNilException.Create(Name);
end;

function TMontgomeryContext.GetModulus: TBigIntLimbs;
begin
  SetLength(Result, Length(FModulus));
  if Length(Result) <> 0 then Move(FModulus[0], Result[0], Length(Result) * SizeOf(UInt64));
end;

function TMontgomeryContext.GetR2: TBigIntLimbs;
begin
  SetLength(Result, Length(FR2));
  if Length(Result) <> 0 then Move(FR2[0], Result[0], Length(Result) * SizeOf(UInt64));
end;

function TMontgomeryContext.GetOneMont: TBigIntLimbs;
begin
  SetLength(Result, Length(FOneMont));
  if Length(Result) <> 0 then Move(FOneMont[0], Result[0], Length(Result) * SizeOf(UInt64));
end;

procedure TMontgomeryContext.BuildR2;
var
  Temp: TBigIntLimbs;
  I, Count: NativeUInt;
  Carry: UInt64;
begin
  SetLength(FR2, FLimbs);
  SetLength(Temp, FLimbs);
  FR2[0] := 1;
  Count := FLimbs * 128;
  for I := 1 to Count do
  begin
    Carry := TBigIntCore.Add(@Temp[0], @FR2[0], @FR2[0], FLimbs);
    if (Carry <> 0) or (TBigIntCore.Compare(@Temp[0], @FModulus[0], FLimbs) >= 0) then TBigIntCore.Sub(@Temp[0], @Temp[0], @FModulus[0], FLimbs);
    Move(Temp[0], FR2[0], FLimbs * SizeOf(UInt64));
  end;
  FillChar(Temp[0], Length(Temp) * SizeOf(UInt64), 0);
end;

constructor TMontgomeryContext.Create(const Modulus: TBigIntLimbs);
var
  N: NativeInt;
begin
  inherited Create;
  N := Length(Modulus);
  while (N > 0) and (Modulus[N - 1] = 0) do Dec(N);
  if N = 0 then raise EArgumentException.Create('Modulus is zero');
  if NativeUInt(N) > BigIntMaxRecommendedLimbs then raise EArgumentOutOfRangeException.Create('Modulus');
  if (Modulus[0] and 1) = 0 then raise EArgumentException.Create('Modulus must be odd');
  if (N = 1) and (Modulus[0] <= 1) then raise EArgumentException.Create('Modulus must be greater than one');
  FLimbs := NativeUInt(N);
  SetLength(FModulus, N);
  Move(Modulus[0], FModulus[0], N * SizeOf(UInt64));
  FN0Inv := ComputeN0Inv(FModulus[0]);
  BuildR2;
  FKernel := TBigIntJit.Create(FLimbs);
  FMulCode := BuildMulKernel(FLimbs, FN0Inv);
  SetLength(FOne, FLimbs); FOne[0] := 1;
  SetLength(FOneMont, FLimbs);
  MontMul(@FOneMont[0], @FOne[0], @FR2[0]);
end;

destructor TMontgomeryContext.Destroy;
begin
  if FKernel <> nil then
  begin
    if Length(FOneMont) <> 0 then FKernel.Zero(@FOneMont[0]);
    if Length(FR2) <> 0 then FKernel.Zero(@FR2[0]);
    if Length(FOne) <> 0 then FKernel.Zero(@FOne[0]);
  end;
  FMulCode.Free;
  FKernel.Free;
  inherited;
end;

procedure TMontgomeryContext.MontMul(Dst, A, B: PBigIntLimb);
begin
  CheckPtr(Dst, 'Dst'); CheckPtr(A, 'A'); CheckPtr(B, 'B');
  FMulCode.Run(UInt64(NativeUInt(Dst)), UInt64(NativeUInt(A)), UInt64(NativeUInt(B)), UInt64(NativeUInt(@FModulus[0])));
end;

procedure TMontgomeryContext.MontSquare(Dst, A: PBigIntLimb);
begin
  MontMul(Dst, A, A);
end;

procedure TMontgomeryContext.Encode(Dst, A: PBigIntLimb);
begin
  MontMul(Dst, A, @FR2[0]);
end;

procedure TMontgomeryContext.Decode(Dst, A: PBigIntLimb);
begin
  MontMul(Dst, A, @FOne[0]);
end;

procedure TMontgomeryContext.AddMod(Dst, A, B, Scratch0, Scratch1: PBigIntLimb);
var
  Carry, Borrow, ChooseReduced: UInt64;
begin
  CheckPtr(Dst, 'Dst'); CheckPtr(A, 'A'); CheckPtr(B, 'B'); CheckPtr(Scratch0, 'Scratch0'); CheckPtr(Scratch1, 'Scratch1');
  Carry := FKernel.Add(Scratch0, A, B);
  Borrow := FKernel.Sub(Scratch1, Scratch0, @FModulus[0]);
  ChooseReduced := (Carry or (Borrow xor 1)) and 1;
  FKernel.SelectCT(Dst, Scratch1, Scratch0, ChooseReduced);
end;

procedure TMontgomeryContext.AddMod(Dst, A, B: PBigIntLimb);
var
  S0, S1: TBigIntLimbs;
begin
  SetLength(S0, FLimbs); SetLength(S1, FLimbs);
  try
    AddMod(Dst, A, B, @S0[0], @S1[0]);
  finally
    FKernel.Zero(@S0[0]); FKernel.Zero(@S1[0]);
  end;
end;

procedure TMontgomeryContext.SubMod(Dst, A, B, Scratch0, Scratch1: PBigIntLimb);
var
  Borrow: UInt64;
begin
  CheckPtr(Dst, 'Dst'); CheckPtr(A, 'A'); CheckPtr(B, 'B'); CheckPtr(Scratch0, 'Scratch0'); CheckPtr(Scratch1, 'Scratch1');
  Borrow := FKernel.Sub(Scratch0, A, B);
  FKernel.Add(Scratch1, Scratch0, @FModulus[0]);
  FKernel.SelectCT(Dst, Scratch1, Scratch0, Borrow);
end;

procedure TMontgomeryContext.SubMod(Dst, A, B: PBigIntLimb);
var
  S0, S1: TBigIntLimbs;
begin
  SetLength(S0, FLimbs); SetLength(S1, FLimbs);
  try
    SubMod(Dst, A, B, @S0[0], @S1[0]);
  finally
    FKernel.Zero(@S0[0]); FKernel.Zero(@S1[0]);
  end;
end;

procedure TMontgomeryContext.PowCT(Dst, Base: PBigIntLimb; ExponentBE: Pointer; ExponentBytes: NativeUInt);
var
  BaseM, Acc, Sq, Product: TBigIntLimbs;
  P: PByte;
  I: NativeUInt;
  Bit: Integer;
  Choice: UInt64;
begin
  CheckPtr(Dst, 'Dst'); CheckPtr(Base, 'Base');
  if (ExponentBE = nil) and (ExponentBytes <> 0) then raise EArgumentNilException.Create('ExponentBE');
  SetLength(BaseM, FLimbs); SetLength(Acc, FLimbs); SetLength(Sq, FLimbs); SetLength(Product, FLimbs);
  try
    Encode(@BaseM[0], Base);
    Move(FOneMont[0], Acc[0], FLimbs * SizeOf(UInt64));
    P := PByte(ExponentBE);
    if ExponentBytes <> 0 then
    for I := 0 to ExponentBytes - 1 do
      for Bit := 7 downto 0 do
      begin
        MontSquare(@Sq[0], @Acc[0]);
        MontMul(@Product[0], @Sq[0], @BaseM[0]);
        Choice := (P[I] shr Bit) and 1;
        FKernel.SelectCT(@Acc[0], @Product[0], @Sq[0], Choice);
      end;
    Decode(Dst, @Acc[0]);
  finally
    FKernel.Zero(@BaseM[0]); FKernel.Zero(@Acc[0]); FKernel.Zero(@Sq[0]); FKernel.Zero(@Product[0]);
  end;
end;

procedure TMontgomeryContext.PowVar(Dst, Base: PBigIntLimb; ExponentBE: Pointer; ExponentBytes: NativeUInt);
var
  BaseM, Acc, Temp: TBigIntLimbs;
  P: PByte;
  I: NativeUInt;
  Bit: Integer;
begin
  CheckPtr(Dst, 'Dst'); CheckPtr(Base, 'Base');
  if (ExponentBE = nil) and (ExponentBytes <> 0) then raise EArgumentNilException.Create('ExponentBE');
  SetLength(BaseM, FLimbs); SetLength(Acc, FLimbs); SetLength(Temp, FLimbs);
  try
    Encode(@BaseM[0], Base);
    Move(FOneMont[0], Acc[0], FLimbs * SizeOf(UInt64));
    P := PByte(ExponentBE);
    if ExponentBytes <> 0 then
    for I := 0 to ExponentBytes - 1 do
      for Bit := 7 downto 0 do
      begin
        MontSquare(@Temp[0], @Acc[0]);
        Move(Temp[0], Acc[0], FLimbs * SizeOf(UInt64));
        if ((P[I] shr Bit) and 1) <> 0 then
        begin
          MontMul(@Temp[0], @Acc[0], @BaseM[0]);
          Move(Temp[0], Acc[0], FLimbs * SizeOf(UInt64));
        end;
      end;
    Decode(Dst, @Acc[0]);
  finally
    FKernel.Zero(@BaseM[0]); FKernel.Zero(@Acc[0]); FKernel.Zero(@Temp[0]);
  end;
end;

procedure TMontgomeryContext.InversePrimeCT(Dst, A: PBigIntLimb);
var
  Exp, Two: TBigIntLimbs;
  Bytes: TBytes;
begin
  CheckPtr(Dst, 'Dst'); CheckPtr(A, 'A');
  if FKernel.IsZeroCT(A) <> 0 then raise EArgumentException.Create('Zero has no multiplicative inverse');
  SetLength(Exp, FLimbs); SetLength(Two, FLimbs); Two[0] := 2; SetLength(Bytes, FLimbs * 8);
  try
    FKernel.Sub(@Exp[0], @FModulus[0], @Two[0]);
    TBigIntCore.ExportBytes(@Exp[0], FLimbs, @Bytes[0], Length(Bytes), bieBigEndian);
    PowCT(Dst, A, @Bytes[0], Length(Bytes));
  finally
    FKernel.Zero(@Exp[0]); FKernel.Zero(@Two[0]); FillChar(Bytes[0], Length(Bytes), 0);
  end;
end;

function TMontgomeryContext.IsCanonical(A: PBigIntLimb): Boolean;
begin
  CheckPtr(A, 'A');
  Result := TBigIntCore.Compare(A, @FModulus[0], FLimbs) < 0;
end;

end.
