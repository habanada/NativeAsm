{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
unit NativeAsm.Tests.BigInt;

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  NativeAsm.BigInt.Types,
  NativeAsm.BigInt.Core,
  NativeAsm.BigInt.Jit,
  NativeAsm.BigInt,
  NativeAsm.BigInt.Montgomery,
  NativeAsm.BigInt.Fields;

type
  [TestFixture]
  TBigIntTests = class
  private
    class function HexLimbs(const S: string; Limbs: NativeUInt): TBigIntLimbs; static;
    class function LimbsToHex(const Value: TBigIntLimbs; TrimLeadingZeroes: Boolean = True): string; static;
    class function HexBytes(const S: string): TBytes; static;
    class procedure AssertLimbs(const Expected, Actual: TBigIntLimbs; const Msg: string = ''); static;
    class function Next64(var State: UInt64): UInt64; static;
    class procedure FillRandom(var Value: TBigIntLimbs; var State: UInt64); static;
  public
    [Test] procedure Fixed256KnownVector;
    [Test] procedure ImportExportRoundTrip;
    [Test] procedure HexConversionKnownVectors;
    [Test] procedure ShiftAndBitPrimitives;
    [Test] procedure JitWidthsMatchReference;
    [Test] procedure ConstantTimePrimitives;
    [Test] procedure MulWordMatchesReference;
    [Test] procedure MontgomerySecp256k1KnownVectors;
    [Test] procedure MontgomeryRandomAgainstBigNat;
    [Test] procedure Montgomery2048KnownVector;
    [Test] procedure MontgomeryAllFieldWidths;
    [Test] procedure MontgomeryExtendedKnownVectors;
    [Test] procedure MontgomeryRsaLoopWidths;
    [Test] procedure ModularAddSubBoundaries;
    [Test] procedure ContextSnapshotsAreIsolated;
    [Test] procedure PowAndPrimeInverse;
    [Test] procedure NamedPrimeConstants;
    [Test] procedure BigNatDivisionAndGcd;
    [Test] procedure BigNatModularSetupMath;
    [Test] procedure ApiBoundaryChecks;
  end;

implementation

class function TBigIntTests.HexLimbs(const S: string; Limbs: NativeUInt): TBigIntLimbs;
var
  T: string;
  I: Integer;
  NibbleIndex, LimbIndex, Shift: NativeUInt;
  C: Char;
  V: UInt64;
begin
  T := Trim(S);
  if (Length(T) >= 2) and (T[1] = '0') and ((T[2] = 'x') or (T[2] = 'X')) then Delete(T, 1, 2);
  if T = '' then T := '0';
  if NativeUInt(Length(T)) > Limbs * 16 then raise ERangeError.Create('Hex value too large');
  SetLength(Result, Limbs);
  if Limbs <> 0 then FillChar(Result[0], Limbs * SizeOf(UInt64), 0);
  for I := 1 to Length(T) do
  begin
    C := T[Length(T) - I + 1];
    case C of
      '0'..'9': V := Ord(C) - Ord('0');
      'a'..'f': V := Ord(C) - Ord('a') + 10;
      'A'..'F': V := Ord(C) - Ord('A') + 10;
    else
      raise EConvertError.Create('hex');
    end;
    NibbleIndex := NativeUInt(I - 1);
    LimbIndex := NibbleIndex div 16;
    Shift := (NibbleIndex and 15) * 4;
    Result[LimbIndex] := Result[LimbIndex] or (V shl Shift);
  end;
end;

class function TBigIntTests.LimbsToHex(const Value: TBigIntLimbs; TrimLeadingZeroes: Boolean): string;
var
  I, First: Integer;
begin
  if Length(Value) = 0 then Exit('0');
  Result := '';
  for I := High(Value) downto 0 do Result := Result + IntToHex(Value[I], 16);
  if TrimLeadingZeroes then
  begin
    First := 1;
    while (First < Length(Result)) and (Result[First] = '0') do Inc(First);
    if First > 1 then Delete(Result, 1, First - 1);
  end;
end;

class function TBigIntTests.HexBytes(const S: string): TBytes;
var
  T: string;
  I, N, V1, V2: Integer;
  function Nibble(C: Char): Integer;
  begin
    case C of
      '0'..'9': Result := Ord(C) - Ord('0');
      'a'..'f': Result := Ord(C) - Ord('a') + 10;
      'A'..'F': Result := Ord(C) - Ord('A') + 10;
    else
      raise EConvertError.Create('hex');
    end;
  end;
begin
  T := S;
  if Odd(Length(T)) then T := '0' + T;
  N := Length(T) div 2;
  SetLength(Result, N);
  for I := 0 to N - 1 do
  begin
    V1 := Nibble(T[I * 2 + 1]); V2 := Nibble(T[I * 2 + 2]);
    Result[I] := Byte((V1 shl 4) or V2);
  end;
end;

class procedure TBigIntTests.AssertLimbs(const Expected, Actual: TBigIntLimbs; const Msg: string);
var
  I: Integer;
begin
  Assert.AreEqual(Length(Expected), Length(Actual), Msg + ' length');
  for I := 0 to High(Expected) do Assert.IsTrue(Expected[I] = Actual[I], Msg + ' limb ' + IntToStr(I) + ' expected=' + IntToHex(Expected[I], 16) + ' actual=' + IntToHex(Actual[I], 16));
end;

class function TBigIntTests.Next64(var State: UInt64): UInt64;
begin
  State := State xor (State shl 13);
  State := State xor (State shr 7);
  State := State xor (State shl 17);
  Result := State;
end;

class procedure TBigIntTests.FillRandom(var Value: TBigIntLimbs; var State: UInt64);
var
  I: Integer;
begin
  for I := 0 to High(Value) do Value[I] := Next64(State);
end;

procedure TBigIntTests.Fixed256KnownVector;
const
  AHex = 'AD238EB15729ED8F42A940D54669C8BD4FCD9E3CF64BA7EC0C0532C46503C151';
  BHex = '96DC3FE14FBF429FB669F3455344557827D02EBEAD9D9375BC039C3F029A5B8D';
  SumHex = '43FFCE92A6E9302EF913341A99AE1E35779DCCFBA3E93B61C808CF03679E1CDE';
  SubHex = '16474ED0076AAAEF8C3F4D8FF325734527FD6F7E48AE147650019685626965C4';
  MulHex = '6607CB5EABC6DB2A64F0C286900C81E4A0CCEDCF1E66A330BFDC795692925AFAEB86027C20BA207E79DA8E1DEC084E8521353287F98CA4B9708480C7E583449D';
var
  A, B, R, E, W, EW: TBigIntLimbs;
  J: TBigIntJit;
  Carry, Borrow: UInt64;
begin
  A := HexLimbs(AHex, 4); B := HexLimbs(BHex, 4); SetLength(R, 4);
  J := TBigIntJit.Create(4);
  try
    Carry := J.Add(@R[0], @A[0], @B[0]); E := HexLimbs(SumHex, 4); AssertLimbs(E, R, 'add'); Assert.IsTrue(Carry = 1);
    TBigIntCore.Sub(@R[0], @A[0], @B[0], 4); E := HexLimbs(SubHex, 4); AssertLimbs(E, R, 'sub core');
    Borrow := J.Sub(@R[0], @A[0], @B[0]); AssertLimbs(E, R, 'sub jit'); Assert.IsTrue(Borrow = 0);
    SetLength(W, 8); J.MulWide(@W[0], @A[0], @B[0]); EW := HexLimbs(MulHex, 8); AssertLimbs(EW, W, 'mul');
  finally
    J.Free;
  end;
end;

procedure TBigIntTests.ImportExportRoundTrip;
const
  Sizes: array[0..9] of Integer = (1, 7, 8, 9, 15, 31, 32, 33, 56, 66);
var
  Data, OutData: TBytes;
  L: TBigIntLimbs;
  I, J, N: Integer;
begin
  for J := Low(Sizes) to High(Sizes) do
  begin
    SetLength(Data, Sizes[J]);
    for I := 0 to High(Data) do Data[I] := Byte((I * 37 + Sizes[J] * 11) and $FF);
    N := (Length(Data) + 7) div 8; SetLength(L, N); SetLength(OutData, Length(Data));
    TBigIntCore.ImportBytes(@L[0], N, @Data[0], Length(Data), bieBigEndian);
    TBigIntCore.ExportBytes(@L[0], N, @OutData[0], Length(OutData), bieBigEndian);
    Assert.IsTrue(CompareMem(@Data[0], @OutData[0], Length(Data)), 'big endian size ' + IntToStr(Sizes[J]));
    FillChar(L[0], Length(L) * SizeOf(UInt64), 0); FillChar(OutData[0], Length(OutData), 0);
    TBigIntCore.ImportBytes(@L[0], N, @Data[0], Length(Data), bieLittleEndian);
    TBigIntCore.ExportBytes(@L[0], N, @OutData[0], Length(OutData), bieLittleEndian);
    Assert.IsTrue(CompareMem(@Data[0], @OutData[0], Length(Data)), 'little endian size ' + IntToStr(Sizes[J]));
  end;
  TBigIntCore.ImportBytes(nil, 0, nil, 0, bieBigEndian);
  TBigIntCore.ExportBytes(nil, 0, nil, 0, bieLittleEndian);
end;

procedure TBigIntTests.HexConversionKnownVectors;
const
  Hex256 = '0123456789ABCDEFFEDCBA98765432100F0E0D0C0B0A09080706050403020100';
  HexShort = '0x00000000000000ABCDEF';
var
  Expected, Actual: TBigIntLimbs;
begin
  Expected := HexLimbs(Hex256, 4); Actual := TBigIntCore.FromHex(Hex256, 4); AssertLimbs(Expected, Actual, 'fromhex 256');
  Assert.AreEqual(LimbsToHex(Expected), TBigIntCore.ToHex(@Expected[0], Length(Expected)), 'tohex 256 trimmed');
  Assert.AreEqual(LimbsToHex(Expected, False), TBigIntCore.ToHex(@Expected[0], Length(Expected), False), 'tohex 256 fixed');
  Expected := HexLimbs(HexShort, 2); Actual := TBigIntCore.FromHex(HexShort, 2); AssertLimbs(Expected, Actual, 'fromhex short');
  Assert.AreEqual(LimbsToHex(Expected), TBigIntCore.ToHex(@Expected[0], Length(Expected)), 'tohex short trimmed');
  Assert.AreEqual(LimbsToHex(Expected, False), TBigIntCore.ToHex(@Expected[0], Length(Expected), False), 'tohex short fixed');
  Expected := HexLimbs('0', 1); Actual := TBigIntCore.FromHex('0', 1); AssertLimbs(Expected, Actual, 'fromhex zero');
  Assert.AreEqual('0', TBigIntCore.ToHex(@Expected[0], Length(Expected)), 'tohex zero');
end;

procedure TBigIntTests.ShiftAndBitPrimitives;
const
  AHex = '0123456789ABCDEFFEDCBA98765432100F0E0D0C0B0A09080706050403020100';
  L64Hex = 'FEDCBA98765432100F0E0D0C0B0A090807060504030201000000000000000000';
  L65Hex = 'FDB97530ECA864201E1C1A18161412100E0C0A08060402000000000000000000';
  R64Hex = '00000000000000000123456789ABCDEFFEDCBA98765432100F0E0D0C0B0A0908';
  R65Hex = '00000000000000000091A2B3C4D5E6F7FF6E5D4C3B2A19080787068605850484';
var
  A, R, E, Z: TBigIntLimbs;
begin
  A := HexLimbs(AHex, 4); SetLength(R, 4); SetLength(Z, 4);
  TBigIntCore.ShiftLeft(@R[0], @A[0], 4, 64); E := HexLimbs(L64Hex, 4); AssertLimbs(E, R, 'shl64');
  TBigIntCore.ShiftLeft(@R[0], @A[0], 4, 65); E := HexLimbs(L65Hex, 4); AssertLimbs(E, R, 'shl65');
  TBigIntCore.ShiftRight(@R[0], @A[0], 4, 64); E := HexLimbs(R64Hex, 4); AssertLimbs(E, R, 'shr64');
  TBigIntCore.ShiftRight(@R[0], @A[0], 4, 65); E := HexLimbs(R65Hex, 4); AssertLimbs(E, R, 'shr65');
  Move(A[0], R[0], 4 * SizeOf(UInt64)); TBigIntCore.ShiftLeft(@R[0], @R[0], 4, 1); TBigIntCore.ShiftRight(@R[0], @R[0], 4, 1); AssertLimbs(A, R, 'in-place shift');
  Assert.IsTrue(TBigIntCore.GetBit(@A[0], 4, 0) = 0);
  TBigIntCore.SetBit(@Z[0], 4, 255); Assert.IsTrue(TBigIntCore.GetBit(@Z[0], 4, 255) = 1); Assert.AreEqual(NativeUInt(256), TBigIntCore.BitLength(@Z[0], 4));
  TBigIntCore.ShiftLeft(@R[0], @A[0], 4, 256); Assert.IsTrue(TBigIntCore.IsZero(@R[0], 4));
  TBigIntCore.ShiftRight(@R[0], @A[0], 4, 256); Assert.IsTrue(TBigIntCore.IsZero(@R[0], 4));
end;

procedure TBigIntTests.JitWidthsMatchReference;
const
  Widths: array[0..7] of Integer = (4, 6, 7, 8, 9, 32, 48, 64);
var
  W, Round: Integer;
  N: NativeUInt;
  State, C1, C2, B1, B2: UInt64;
  A, B, EJ, AJ, ER, AR, EW, AW: TBigIntLimbs;
  J: TBigIntJit;
begin
  State := $D3A2646CAB3487F1;
  for W := Low(Widths) to High(Widths) do
  begin
    N := Widths[W];
    SetLength(A, N); SetLength(B, N); SetLength(EJ, N); SetLength(AJ, N); SetLength(ER, N); SetLength(AR, N); SetLength(EW, N * 2); SetLength(AW, N * 2);
    J := TBigIntJit.Create(N);
    try
      for Round := 0 to 3 do
      begin
        FillRandom(A, State); FillRandom(B, State);
        C1 := TBigIntCore.Add(@ER[0], @A[0], @B[0], N); C2 := J.Add(@EJ[0], @A[0], @B[0]); AssertLimbs(ER, EJ, 'width add'); Assert.IsTrue(C1 = C2);
        B1 := TBigIntCore.Sub(@AR[0], @A[0], @B[0], N); B2 := J.Sub(@AJ[0], @A[0], @B[0]); AssertLimbs(AR, AJ, 'width sub'); Assert.IsTrue(B1 = B2);
        TBigIntCore.MulWide(@EW[0], @A[0], @B[0], N); J.MulWide(@AW[0], @A[0], @B[0]); AssertLimbs(EW, AW, 'width mul');
        Assert.AreEqual(TBigIntCore.Compare(@A[0], @B[0], N), J.CompareCT(@A[0], @B[0]));
      end;
    finally
      J.Free;
    end;
  end;
end;

procedure TBigIntTests.ConstantTimePrimitives;
var
  A, B, R, Z: TBigIntLimbs;
  J: TBigIntJit;
begin
  A := HexLimbs('123456789ABCDEF00112233445566778899AABBCCDDEEFF00123456789ABCDEF', 4);
  B := HexLimbs('223456789ABCDEF00112233445566778899AABBCCDDEEFF00123456789ABCDEF', 4);
  SetLength(R, 4); SetLength(Z, 4);
  J := TBigIntJit.Create(4);
  try
    Assert.AreEqual(-1, J.CompareCT(@A[0], @B[0]));
    Assert.IsTrue(J.EqualCT(@A[0], @A[0]) = 1);
    Assert.IsTrue(J.EqualCT(@A[0], @B[0]) = 0);
    Assert.IsTrue(J.IsZeroCT(@Z[0]) = 1);
    J.SelectCT(@R[0], @A[0], @B[0], 1); AssertLimbs(A, R, 'select A');
    J.SelectCT(@R[0], @A[0], @B[0], 2); AssertLimbs(A, R, 'select nonzero');
    J.SelectCT(@R[0], @A[0], @B[0], 0); AssertLimbs(B, R, 'select B');
    J.SwapCT(@A[0], @B[0], 0); Assert.IsTrue(J.CompareCT(@A[0], @B[0]) = -1);
    J.SwapCT(@A[0], @B[0], 3); Assert.IsTrue(J.CompareCT(@A[0], @B[0]) = 1);
    J.SwapCT(@A[0], @B[0], 1); Assert.IsTrue(J.CompareCT(@A[0], @B[0]) = -1);
    Move(A[0], R[0], 4 * SizeOf(UInt64)); J.Add(@R[0], @R[0], @B[0]);
    TBigIntCore.Add(@Z[0], @A[0], @B[0], 4); AssertLimbs(Z, R, 'alias add');
    Move(A[0], R[0], 4 * SizeOf(UInt64)); J.Sub(@R[0], @R[0], @B[0]);
    TBigIntCore.Sub(@Z[0], @A[0], @B[0], 4); AssertLimbs(Z, R, 'alias sub');
  finally
    J.Free;
  end;
end;

procedure TBigIntTests.MulWordMatchesReference;
var
  A, E, R, D1, D2: TBigIntLimbs;
  State, W, C1, C2: UInt64;
  J: TBigIntJit;
  I: Integer;
begin
  State := $1234FEDCBA987654; SetLength(A, 9); SetLength(E, 9); SetLength(R, 9); SetLength(D1, 9); SetLength(D2, 9);
  J := TBigIntJit.Create(9);
  try
    for I := 0 to 31 do
    begin
      FillRandom(A, State); FillRandom(D1, State); Move(D1[0], D2[0], 9 * SizeOf(UInt64)); W := Next64(State);
      C1 := TBigIntCore.MulWord(@E[0], @A[0], W, 9); C2 := J.MulWord(@R[0], @A[0], W); AssertLimbs(E, R, 'mulword'); Assert.IsTrue(C1 = C2);
      C1 := TBigIntCore.AddMulWord(@D1[0], @A[0], W, 9); C2 := J.AddMulWord(@D2[0], @A[0], W); AssertLimbs(D1, D2, 'addmulword'); Assert.IsTrue(C1 = C2);
    end;
  finally
    J.Free;
  end;
end;

procedure TBigIntTests.MontgomerySecp256k1KnownVectors;
const
  AHex = 'AD238EB15729ED8F42A940D54669C8BD4FCD9E3CF64BA7EC0C0532C46503C151';
  BHex = '96DC3FE14FBF429FB669F3455344557827D02EBEAD9D9375BC039C3F029A5B8D';
  MontHex = '831F5C7F905BFF1E287CADB7C0EA79470DB81DB2920A12AC66ACA72845806C78';
  EncHex = '1BDD805CE9ACE092AE5A36AF0984B8BA86048E9402C10E9EF1FE14B148123247';
  ProductHex = 'FB0C01F417954FD044BD738E4C90F5DDEDB3692BBF1DEB1CA189BD90A9D56ADB';
var
  N, A, B, R, E, AM, BM, PM: TBigIntLimbs;
  C: TMontgomeryContext;
begin
  N := TPrimeFieldFactory.Modulus(pfSecp256k1); A := HexLimbs(AHex, 4); B := HexLimbs(BHex, 4);
  SetLength(R, 4); SetLength(AM, 4); SetLength(BM, 4); SetLength(PM, 4);
  C := TMontgomeryContext.Create(N);
  try
    C.MontMul(@R[0], @A[0], @B[0]); E := HexLimbs(MontHex, 4); AssertLimbs(E, R, 'mont');
    C.Encode(@AM[0], @A[0]); E := HexLimbs(EncHex, 4); AssertLimbs(E, AM, 'encode');
    Move(A[0], R[0], 4 * SizeOf(UInt64)); C.Encode(@R[0], @R[0]); AssertLimbs(E, R, 'encode alias');
    C.Encode(@BM[0], @B[0]); C.MontMul(@PM[0], @AM[0], @BM[0]); C.Decode(@R[0], @PM[0]); E := HexLimbs(ProductHex, 4); AssertLimbs(E, R, 'normal product');
    C.MontMul(@AM[0], @AM[0], @BM[0]); C.Decode(@R[0], @AM[0]); AssertLimbs(E, R, 'mont alias');
  finally
    C.Free;
  end;
end;

procedure TBigIntTests.MontgomeryRandomAgainstBigNat;
var
  N, A, B, AM, BM, PM, R, Ref: TBigIntLimbs;
  C: TMontgomeryContext;
  NA, NB, NN, NP, NR: TBigNat;
  State: UInt64;
  I: Integer;
begin
  N := TPrimeFieldFactory.Modulus(pfSecp256k1); SetLength(A, 4); SetLength(B, 4); SetLength(AM, 4); SetLength(BM, 4); SetLength(PM, 4); SetLength(R, 4);
  C := TMontgomeryContext.Create(N); State := $A5D917C03B41E27F;
  try
    for I := 0 to 19 do
    begin
      FillRandom(A, State); FillRandom(B, State);
      if TBigIntCore.Compare(@A[0], @N[0], 4) >= 0 then TBigIntCore.Sub(@A[0], @A[0], @N[0], 4);
      if TBigIntCore.Compare(@B[0], @N[0], 4) >= 0 then TBigIntCore.Sub(@B[0], @B[0], @N[0], 4);
      C.Encode(@AM[0], @A[0]); C.Encode(@BM[0], @B[0]); C.MontMul(@PM[0], @AM[0], @BM[0]); C.Decode(@R[0], @PM[0]);
      NA := TBigNat.Create(A); NB := TBigNat.Create(B); NN := TBigNat.Create(N); NP := nil; NR := nil;
      try
        NP := TBigNat.Multiply(NA, NB); NR := TBigNat.Modulo(NP, NN); Ref := NR.Limbs; SetLength(Ref, 4); AssertLimbs(Ref, R, 'random mont');
      finally
        NR.Free; NP.Free; NN.Free; NB.Free; NA.Free;
      end;
    end;
  finally
    C.Free;
  end;
end;

procedure TBigIntTests.Montgomery2048KnownVector;
const
  NHex = 'BE091458C331A8A93F25B706EDD70E48D7CD644AC74F33D19300D3AC9B9AE053C3A40DA9975CDD4546B5FA36E3251A83E394ED8529E4D71F3D3A431800F689E6ABDC2A53D957E83B7E31E899569A861EBD68A4912F04EE3501D4D8FE90D93B0533B07F71C75C349A2C4A222AE6F5508083FB08EA221D5616272BF6E0D7C1980B5B728008895909566C19D76CD99B96AF191354044D8A1AB2616FCDFDB698CADAA9A487AE106128EBF75C12955729A5A23E82E2DF9060D544F36A88A2C325689CB51501F48050908ADD54A89B24062AA880485D275A75DA75FB668044A8CB08DEBB7A97B048B7DD7F6F1670338DA8C4C9DF0FD1538528F09762CFA3EBA3947425';
  AHex = '3D8D56A187CD1CF899A9FBCC4B2E8C2D93A90CC54527E7D3931C1DE3B1BDBBD9C2CA4697A8F3B08FC425FE365AE95459B4805B236057FB1059714722E23626AB81B84D496030F49E628279EB38AD6714ABDB7FCD57D0C9090490A324536DE7A82387736D6FE73B5C7D24BE2A4BA5EFFCC3F743C6AA79E51AE82B02826AEBE0C4E96ABDC13EFE4C553F8562219D37B4F452E21F9622F8813932076556DBF376AB0B80BFC36411F0D1365CD7ED1B634F8276622F9B4AEDACBDB63CD21E69CD988DEB59141B04307CC65FDD1700C39F4019663910C5937925DDDE1488685E0DB66CBF849DB4E137BFC7DBD0ABED201C81DE548CB9688916930CC716122BCACAA9BF';
  BHex = 'BDFD7CE865274D86FD7471FC30ACD3A5DDD920974FFE52338211FE41D9A9E390292C6997A6AB4EBDF61B1BCFB3F43354A2C9417899F668246B024033D215411108B5D95F8E2F2992E24065D4931B10DE204CE9798F0982DBA5A05647060CAA13C664F624718D20A9101A1E218D746B16F7328A21C18F65E8B640EDE5271C77399EBAA05F1661A8A0BF40DD4963FF706E44838A0E14DF66BCF4927C28C91FF439858EA48465199B71C6619411028FA7BEA947FC9D0F336D72808CC0C2C30E0CAAA1156E52270BD7FCA60FCF5702568B323D2F4A1D1451E81386D1ADEC9C20162E9CD129168979612A22CF739C08AA0ED6BACA939A557DC168E4CDC16D56E3E4BE';
  MHex = '516842EA5D8D8D1D7A97C0CDE193F38AFFC08586B25089675FCDA70F5B273465E1671E3FB045DFEE784CD04ABD549884126E618D4FDEB78D0DC192F881AEC03E2606FE29E387CAED5D496C9E6E378E9D102939D33926AA1441694E898AB9F13137062A05F5D23FC6FFEDC1DA82303ED22B3D55827EB2BA139894781008CF700B748CF991739B3FCCE2CBA58C06695D5E8702A157988A629D4F1CD19B90365D75B1F778AC861380015B06637A15456D7CBE5B719BF08ADB324BBB23F714D3646127C801D0F68511FF4284260ACF70CF48717017C868B69777038E0668144076AA95FD93BD357D58AC9AFBB8AA916692BBCFECA4C55A779640C8B8D025AF5F3F82';
var
  N, A, B, R, E: TBigIntLimbs;
  C: TMontgomeryContext;
begin
  N := HexLimbs(NHex, 32); A := HexLimbs(AHex, 32); B := HexLimbs(BHex, 32); SetLength(R, 32); E := HexLimbs(MHex, 32);
  C := TMontgomeryContext.Create(N);
  try
    C.MontMul(@R[0], @A[0], @B[0]); AssertLimbs(E, R, 'mont2048');
  finally
    C.Free;
  end;
end;


procedure TBigIntTests.MontgomeryAllFieldWidths;
const
  Fields: array[0..5] of TPrimeFieldId = (pfSecp256k1, pfP256, pfP384, pfP521, pfCurve25519, pfCurve448);
var
  N, A, B, S, AM, BM, PM, R, E: TBigIntLimbs;
  C: TMontgomeryContext;
  F, L: Integer;
begin
  for F := Low(Fields) to High(Fields) do
  begin
    N := TPrimeFieldFactory.Modulus(Fields[F]); L := Length(N);
    SetLength(A, L); SetLength(B, L); SetLength(S, L); SetLength(AM, L); SetLength(BM, L); SetLength(PM, L); SetLength(R, L); SetLength(E, L);
    Move(N[0], A[0], L * SizeOf(UInt64)); Move(N[0], B[0], L * SizeOf(UInt64));
    S[0] := 3; TBigIntCore.Sub(@A[0], @A[0], @S[0], L);
    FillChar(S[0], L * SizeOf(UInt64), 0); S[0] := 5; TBigIntCore.Sub(@B[0], @B[0], @S[0], L);
    E[0] := 15;
    C := TMontgomeryContext.Create(N);
    try
      C.Encode(@AM[0], @A[0]); C.Encode(@BM[0], @B[0]); C.MontMul(@PM[0], @AM[0], @BM[0]); C.Decode(@R[0], @PM[0]);
      AssertLimbs(E, R, 'field mont ' + IntToStr(F));
      FillChar(R[0], L * SizeOf(UInt64), 0); C.Decode(@R[0], @AM[0]); AssertLimbs(A, R, 'field decode ' + IntToStr(F));
    finally
      C.Free;
    end;
  end;
end;

procedure TBigIntTests.MontgomeryExtendedKnownVectors;
  procedure Check(Id: TPrimeFieldId; const AHex, BHex, DirectHex, ProductHex: string);
  var
    N, A, B, R, E, AM, BM, PM: TBigIntLimbs;
    C: TMontgomeryContext;
    L: Integer;
  begin
    N := TPrimeFieldFactory.Modulus(Id); L := Length(N); A := HexLimbs(AHex, L); B := HexLimbs(BHex, L); SetLength(R, L); SetLength(AM, L); SetLength(BM, L); SetLength(PM, L);
    C := TMontgomeryContext.Create(N);
    try
      C.MontMul(@R[0], @A[0], @B[0]); E := HexLimbs(DirectHex, L); AssertLimbs(E, R, 'direct mont');
      C.Encode(@AM[0], @A[0]); C.Encode(@BM[0], @B[0]); C.MontMul(@PM[0], @AM[0], @BM[0]); C.Decode(@R[0], @PM[0]); E := HexLimbs(ProductHex, L); AssertLimbs(E, R, 'encoded product');
    finally
      C.Free;
    end;
  end;
begin
  Check(pfCurve448,
    'DCD4563F700B1889C2D69C91ACCEF6A43D76553570621F11581DCE38DD5BE77AD29D37C46067AA4DF730225CB2EBC37823D22D6DF2445E14',
    'F6A809A89C75CB507339168DD0F3795005347003A536DA6F94E480C4CF4F89241B138E87102B74080C40A5D146EC9F1BF2D96AC8541B3D81',
    '203E4B8C6AC3392CF4BFC8896C06BA3CCB4EF47287762B54B73C904E4BD6BF91F31931E18BDBBE1E507B4B305543910FED8FA785E8B0ED31',
    '8C5356AAC89FA43B755B4F312888BFA9EBE179F4FC7BFE2F572A0DCD6C150B1E5DDC6B0E809B86A7BC82056D209285827505D2DA9FED7D7F');
  Check(pfP521,
    'D426357434D5D6CC3B50BE9F69E3B768BC1D9F2A9B56D0604E6EF7612839A9762BB1FB88DE6EEE3BFD822EF7DC78B87AAFAB4D6AFC2E20B9BA4BC754416D4F843B',
    'EB1C65B11EF74DB6FFCE35FF785B981F376C8EA362F7323DF3998224577270EDA7B6554C3304AB2F1E36686877312475B2F72277C565C54B6BAB18BBDBF9EBF21A',
    '1FD1EC7AE460F30B8167FE8CAB0B4C7C55C0072BEAE8AAFF6C71809AF3464BC95D28F25A21F7E6792A1DBA270F9B760A1AE45EE7CDA6B233C9136E47712C6DCD18D',
    '5C0B3FF465585A63E2AE00395F574557FB638C04D79A325E4AE94792D10FBF33C950EDD1387CDBB050D722F73E6D35919E489B723B89636E68C6FF47B1EB9183CC');
end;

procedure TBigIntTests.MontgomeryRsaLoopWidths;
const
  Widths: array[0..2] of Integer = (32, 48, 64);
var
  N, A, B, S, AM, BM, PM, R, E: TBigIntLimbs;
  C: TMontgomeryContext;
  I, J, L: Integer;
  State: UInt64;
begin
  for I := Low(Widths) to High(Widths) do
  begin
    L := Widths[I]; SetLength(N, L); SetLength(A, L); SetLength(B, L); SetLength(S, L); SetLength(AM, L); SetLength(BM, L); SetLength(PM, L); SetLength(R, L); SetLength(E, L);
    State := UInt64($D1B54A32D192ED03) xor UInt64(L);
    for J := 0 to L - 1 do N[J] := Next64(State);
    N[0] := N[0] or 1; N[L - 1] := N[L - 1] or UInt64($8000000000000000);
    Move(N[0], A[0], L * SizeOf(UInt64)); Move(N[0], B[0], L * SizeOf(UInt64));
    S[0] := $12345; TBigIntCore.Sub(@A[0], @A[0], @S[0], L);
    FillChar(S[0], L * SizeOf(UInt64), 0); S[0] := $FEDCB; TBigIntCore.Sub(@B[0], @B[0], @S[0], L);
    E[0] := UInt64($12345) * UInt64($FEDCB);
    C := TMontgomeryContext.Create(N);
    try
      C.Encode(@AM[0], @A[0]); C.Encode(@BM[0], @B[0]); C.MontMul(@PM[0], @AM[0], @BM[0]); C.Decode(@R[0], @PM[0]);
      AssertLimbs(E, R, 'rsa loop width ' + IntToStr(L * 64));
    finally
      C.Free;
    end;
  end;
end;

procedure TBigIntTests.ModularAddSubBoundaries;
var
  N, A, B, R, E, S: TBigIntLimbs;
  C: TMontgomeryContext;
begin
  N := TPrimeFieldFactory.Modulus(pfSecp256k1); SetLength(A, 4); SetLength(B, 4); SetLength(R, 4); SetLength(E, 4); SetLength(S, 4);
  Move(N[0], A[0], 4 * SizeOf(UInt64)); S[0] := 3; TBigIntCore.Sub(@A[0], @A[0], @S[0], 4); B[0] := 5; E[0] := 2;
  C := TMontgomeryContext.Create(N);
  try
    C.AddMod(@R[0], @A[0], @B[0]); AssertLimbs(E, R, 'mod add wrap');
    FillChar(A[0], 4 * SizeOf(UInt64), 0); A[0] := 2; FillChar(E[0], 4 * SizeOf(UInt64), 0); Move(N[0], E[0], 4 * SizeOf(UInt64)); FillChar(S[0], 4 * SizeOf(UInt64), 0); S[0] := 3; TBigIntCore.Sub(@E[0], @E[0], @S[0], 4);
    C.SubMod(@R[0], @A[0], @B[0]); AssertLimbs(E, R, 'mod sub wrap');
  finally
    C.Free;
  end;
end;

procedure TBigIntTests.ContextSnapshotsAreIsolated;
var
  N, CopyN, A, R: TBigIntLimbs;
  C: TMontgomeryContext;
begin
  N := TPrimeFieldFactory.Modulus(pfSecp256k1); C := TMontgomeryContext.Create(N);
  try
    CopyN := C.Modulus; CopyN[0] := 1;
    N := C.Modulus; Assert.AreEqual('FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F', LimbsToHex(N));
    SetLength(A, C.Limbs); SetLength(R, C.Limbs); A[0] := 1; C.Encode(@R[0], @A[0]);
    Assert.IsFalse(TBigIntCore.IsZero(@R[0], C.Limbs));
  finally
    C.Free;
  end;
end;

procedure TBigIntTests.PowAndPrimeInverse;
const
  AHex = 'AD238EB15729ED8F42A940D54669C8BD4FCD9E3CF64BA7EC0C0532C46503C151';
  PowHex = '4BF978F57E7BE0B35F45312FF7885F132AF60DD1D0CC661615885009C4ED401F';
  InvHex = 'D9160DC11661C3E09319FF2EB248FA2F44113417E28FA9754D3EC7720D2EAE3F';
var
  N, A, R, E: TBigIntLimbs;
  Exp: TBytes;
  C: TMontgomeryContext;
begin
  N := TPrimeFieldFactory.Modulus(pfSecp256k1); A := HexLimbs(AHex, 4); SetLength(R, 4); Exp := HexBytes('123456789ABCDEF0123456789');
  C := TMontgomeryContext.Create(N);
  try
    C.PowCT(@R[0], @A[0], @Exp[0], Length(Exp)); E := HexLimbs(PowHex, 4); AssertLimbs(E, R, 'powct');
    C.PowVar(@R[0], @A[0], @Exp[0], Length(Exp)); AssertLimbs(E, R, 'powvar');
    C.InversePrimeCT(@R[0], @A[0]); E := HexLimbs(InvHex, 4); AssertLimbs(E, R, 'inverse');
  finally
    C.Free;
  end;
end;

procedure TBigIntTests.NamedPrimeConstants;
var
  N: TBigIntLimbs;
begin
  N := TPrimeFieldFactory.Modulus(pfSecp256k1); Assert.AreEqual('FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F', LimbsToHex(N));
  N := TPrimeFieldFactory.Modulus(pfP256); Assert.AreEqual('FFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF', LimbsToHex(N));
  N := TPrimeFieldFactory.Modulus(pfP384); Assert.AreEqual('FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFFFF0000000000000000FFFFFFFF', LimbsToHex(N));
  N := TPrimeFieldFactory.Modulus(pfP521); Assert.AreEqual('1' + StringOfChar('F', 130), LimbsToHex(N));
  N := TPrimeFieldFactory.Modulus(pfCurve25519); Assert.AreEqual('7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFED', LimbsToHex(N));
  N := TPrimeFieldFactory.Modulus(pfCurve448); Assert.AreEqual('FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF', LimbsToHex(N));
end;

procedure TBigIntTests.BigNatDivisionAndGcd;
var
  A, B, Q, R, G, Check, Product, G1, G2: TBigNat;
begin
  A := TBigNat.FromHex('123456789ABCDEF0123456789ABCDEF00112233445566778899AABBCCDDEEFF');
  B := TBigNat.FromHex('FEDCBA98765432100123456789');
  Q := nil; R := nil; G := nil; Check := nil; Product := nil; G1 := nil; G2 := nil;
  try
    TBigNat.DivMod(A, B, Q, R);
    Product := TBigNat.Multiply(Q, B);
    Check := TBigNat.Add(Product, R);
    Assert.AreEqual(A.ToHex, Check.ToHex);
    Check.Free; Check := nil; Product.Free; Product := nil;
    G1 := TBigNat.FromHex('123456789ABCDEF0'); G2 := TBigNat.FromHex('1111111111111110');
    G := TBigNat.Gcd(G1, G2);
    Assert.AreEqual('F0', G.ToHex);
  finally
    G2.Free; G1.Free; Product.Free; Check.Free; G.Free; R.Free; Q.Free; B.Free; A.Free;
  end;
end;


procedure TBigIntTests.BigNatModularSetupMath;
var
  A, M, Inv, B, E, P, L1, L2, L: TBigNat;
begin
  A := TBigNat.FromHex('11'); M := TBigNat.FromHex('C30'); Inv := nil; B := nil; E := nil; P := nil; L1 := nil; L2 := nil; L := nil;
  try
    Inv := TBigNat.ModInverse(A, M); Assert.AreEqual('AC1', Inv.ToHex);
    B := TBigNat.FromHex('4'); E := TBigNat.FromHex('D'); M.Free; M := TBigNat.FromHex('1F1');
    P := TBigNat.ModPow(B, E, M); Assert.AreEqual('1BD', P.ToHex);
    L1 := TBigNat.FromHex('3C'); L2 := TBigNat.FromHex('30'); L := TBigNat.Lcm(L1, L2); Assert.AreEqual('F0', L.ToHex);
  finally
    L.Free; L2.Free; L1.Free; P.Free; E.Free; B.Free; Inv.Free; M.Free; A.Free;
  end;
end;


procedure TBigIntTests.ApiBoundaryChecks;
var
  A, B, W, N: TBigIntLimbs;
  J: TBigIntJit;
  C: TMontgomeryContext;
  X: TBigNat;
  Raised: Boolean;
begin
  Raised := False;
  try
    J := TBigIntJit.Create(BigIntMaxRecommendedLimbs + 1);
    J.Free;
  except
    on EArgumentOutOfRangeException do Raised := True;
  end;
  Assert.IsTrue(Raised, 'JIT width > 4096 bits must be rejected');

  SetLength(A, 4); SetLength(B, 4); SetLength(W, 8); A[0] := 3; B[0] := 5;
  Raised := False;
  try
    TBigIntCore.MulWide(@W[0], @W[0], @B[0], 4);
  except
    on EArgumentException do Raised := True;
  end;
  Assert.IsTrue(Raised, 'reference MulWide overlap must be rejected');

  J := TBigIntJit.Create(4);
  try
    Raised := False;
    try
      J.MulWide(@W[0], @W[0], @B[0]);
    except
      on EArgumentException do Raised := True;
    end;
    Assert.IsTrue(Raised, 'JIT MulWide overlap must be rejected');
  finally
    J.Free;
  end;

  SetLength(N, BigIntMaxRecommendedLimbs + 1); N[0] := 3; N[High(N)] := 1; C := nil; Raised := False;
  try
    try
      C := TMontgomeryContext.Create(N);
    except
      on EArgumentOutOfRangeException do Raised := True;
    end;
  finally
    C.Free;
  end;
  Assert.IsTrue(Raised, 'Montgomery width > 4096 bits must be rejected');

  X := TBigNat.FromHex('1');
  try
    Raised := False;
    try
      X.ToBytesBE(-1);
    except
      on EArgumentOutOfRangeException do Raised := True;
    end;
    Assert.IsTrue(Raised, 'negative MinBytes must be rejected');
  finally
    X.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TBigIntTests);

end.
