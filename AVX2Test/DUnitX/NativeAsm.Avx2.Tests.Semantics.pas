unit NativeAsm.Avx2.Tests.Semantics;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TAvx2SemanticTests = class
  public
    [Test] procedure WrapAddSubDwordAndQword;
    [Test] procedure SaturatingBytes;
    [Test] procedure SaturatingWords;
    [Test] procedure SignedUnsignedMinMax;
    [Test] procedure MultiplyAndMadd;
    [Test] procedure VariableDwordShifts;
    [Test] procedure VariableQwordShifts;
    [Test] procedure PermuteAndShuffle;
    [Test] procedure PackUnpackLaneSemantics;
    [Test] procedure SignZeroExtendAndBroadcast;
    [Test] procedure MaskedMemoryLoadStore;
    [Test] procedure IntegerGatherFamilies;
    [Test] procedure FloatGatherFamilies;
  end;

implementation

uses
  System.SysUtils,
  NativeAsm.Types,
  NativeAsm.Builder,
  NativeAsm.Extensions,
  NativeAsm.Simd.Types,
  NativeAsm.Avx.Types,
  NativeAsm.Avx.Encoder,
  NativeAsm.Avx,
  NativeAsm.Avx2.Tests.Support;

procedure RunBinaryYmm(const Mnemonic: string; A, BData, Output: Pointer);
var
  Builder: TAsmBuilder;
  Exe: TExecutableCode;
begin
  Builder := TAsmBuilder.New;
  try
    Builder.Vmovdqu(YMM0, YmmWordPtr(ridRCX)).Vmovdqu(YMM1, YmmWordPtr(ridRDX));
    TAvxInstructionEncoder.Encode(Builder, Mnemonic, [AvxOp(YMM2), AvxOp(YMM0), AvxOp(YMM1)]);
    Builder.Vmovdqu(YmmWordPtr(ridR8), YMM2).Vzeroupper.Ret;
    Exe := TExecutableCode.Create(Builder.Build);
    try
      Exe.Run(UInt64(NativeUInt(A)), UInt64(NativeUInt(BData)), UInt64(NativeUInt(Output)));
    finally
      Exe.Free;
    end;
  finally
    Builder.Free;
  end;
end;


function ReadDwordAt(Base: Pointer; Index: Integer): Cardinal;
begin
  Result := PCardinal(NativeUInt(Base) + NativeUInt(Index) * SizeOf(Cardinal))^;
end;

function BitsToInt32(Value: Cardinal): Integer;
begin
  Move(Value, Result, SizeOf(Result));
end;

function Sar32(Value: Integer; Count: Cardinal): Integer;
var
  U: Cardinal;
begin
  if Count >= 32 then
  begin
    if Value < 0 then
      Exit(-1);
    Exit(0);
  end;
  if Count = 0 then
    Exit(Value);
  U := Cardinal(Value) shr Count;
  if Value < 0 then
    U := U or (Cardinal($FFFFFFFF) shl (32 - Count));
  Result := Integer(U);
end;

procedure TAvx2SemanticTests.WrapAddSubDwordAndQword;
var
  State: Cardinal;
  A32, B32, Out32: TUInt32x8;
  A64, B64, Out64: TUInt64x4;
  CaseIndex, I: Integer;
begin
  if not Avx2Available then begin Assert.IsTrue(True, 'AVX2 unavailable'); Exit; end;
  State := $C001D00D;
  for CaseIndex := 0 to 63 do
  begin
    for I := 0 to 7 do
    begin
      A32[I] := NextRandom(State);
      B32[I] := NextRandom(State);
    end;
    RunBinaryYmm('vpaddd', @A32[0], @B32[0], @Out32[0]);
    for I := 0 to 7 do
      Assert.AreEqual(Cardinal((UInt64(A32[I]) + UInt64(B32[I])) and $FFFFFFFF), Out32[I], 'VPADDD case ' + IntToStr(CaseIndex) + ' lane ' + IntToStr(I));
    RunBinaryYmm('vpsubd', @A32[0], @B32[0], @Out32[0]);
    for I := 0 to 7 do
      Assert.AreEqual(Cardinal((UInt64(A32[I]) + (UInt64(1) shl 32) - UInt64(B32[I])) and $FFFFFFFF), Out32[I], 'VPSUBD case ' + IntToStr(CaseIndex) + ' lane ' + IntToStr(I));
  end;
  State := $2468ACE1;
  for CaseIndex := 0 to 63 do
  begin
    for I := 0 to 3 do
    begin
      A64[I] := (UInt64(NextRandom(State)) or (UInt64(NextRandom(State)) shl 32)) and $1FFFFFFFFFFFFFFF;
      B64[I] := (UInt64(NextRandom(State)) or (UInt64(NextRandom(State)) shl 32)) and $0FFFFFFFFFFFFFFF;
      if A64[I] < B64[I] then A64[I] := A64[I] + B64[I];
    end;
    RunBinaryYmm('vpaddq', @A64[0], @B64[0], @Out64[0]);
    for I := 0 to 3 do
      Assert.IsTrue(Out64[I] = A64[I] + B64[I], 'VPADDQ case ' + IntToStr(CaseIndex) + ' lane ' + IntToStr(I));
    RunBinaryYmm('vpsubq', @A64[0], @B64[0], @Out64[0]);
    for I := 0 to 3 do
      Assert.IsTrue(Out64[I] = A64[I] - B64[I], 'VPSUBQ case ' + IntToStr(CaseIndex) + ' lane ' + IntToStr(I));
  end;
end;

procedure TAvx2SemanticTests.SaturatingBytes;
var
  State: Cardinal;
  AU, BU, OU: TUInt8x32;
  ASigned, BSigned, OSigned: TInt8x32;
  CaseIndex, I: Integer;
begin
  if not Avx2Available then begin Assert.IsTrue(True, 'AVX2 unavailable'); Exit; end;
  State := $13579BDF;
  for CaseIndex := 0 to 63 do
  begin
    for I := 0 to 31 do
    begin
      AU[I] := Byte(NextRandom(State) shr 24);
      BU[I] := Byte(NextRandom(State) shr 24);
      ASigned[I] := ShortInt(Integer(NextRandom(State) mod 256) - 128);
      BSigned[I] := ShortInt(Integer(NextRandom(State) mod 256) - 128);
    end;
    RunBinaryYmm('vpaddusb', @AU[0], @BU[0], @OU[0]);
    for I := 0 to 31 do Assert.AreEqual(SatU8(Integer(AU[I]) + Integer(BU[I])), OU[I], 'VPADDUSB');
    RunBinaryYmm('vpsubusb', @AU[0], @BU[0], @OU[0]);
    for I := 0 to 31 do Assert.AreEqual(SatU8(Integer(AU[I]) - Integer(BU[I])), OU[I], 'VPSUBUSB');
    RunBinaryYmm('vpaddsb', @ASigned[0], @BSigned[0], @OSigned[0]);
    for I := 0 to 31 do Assert.AreEqual(Integer(SatS8(Integer(ASigned[I]) + Integer(BSigned[I]))), Integer(OSigned[I]), 'VPADDSB');
    RunBinaryYmm('vpsubsb', @ASigned[0], @BSigned[0], @OSigned[0]);
    for I := 0 to 31 do Assert.AreEqual(Integer(SatS8(Integer(ASigned[I]) - Integer(BSigned[I]))), Integer(OSigned[I]), 'VPSUBSB');
  end;
end;

procedure TAvx2SemanticTests.SaturatingWords;
var
  State: Cardinal;
  AU, BU, OU: TUInt16x16;
  ASigned, BSigned, OSigned: TInt16x16;
  CaseIndex, I: Integer;
begin
  if not Avx2Available then begin Assert.IsTrue(True, 'AVX2 unavailable'); Exit; end;
  State := $89ABCDEF;
  for CaseIndex := 0 to 63 do
  begin
    for I := 0 to 15 do
    begin
      AU[I] := Word(NextRandom(State) shr 16);
      BU[I] := Word(NextRandom(State) shr 16);
      ASigned[I] := SmallInt(Integer(NextRandom(State) mod 65536) - 32768);
      BSigned[I] := SmallInt(Integer(NextRandom(State) mod 65536) - 32768);
    end;
    RunBinaryYmm('vpaddusw', @AU[0], @BU[0], @OU[0]);
    for I := 0 to 15 do Assert.AreEqual(SatU16(Integer(AU[I]) + Integer(BU[I])), OU[I], 'VPADDUSW');
    RunBinaryYmm('vpsubusw', @AU[0], @BU[0], @OU[0]);
    for I := 0 to 15 do Assert.AreEqual(SatU16(Integer(AU[I]) - Integer(BU[I])), OU[I], 'VPSUBUSW');
    RunBinaryYmm('vpaddsw', @ASigned[0], @BSigned[0], @OSigned[0]);
    for I := 0 to 15 do Assert.AreEqual(Integer(SatS16(Integer(ASigned[I]) + Integer(BSigned[I]))), Integer(OSigned[I]), 'VPADDSW');
    RunBinaryYmm('vpsubsw', @ASigned[0], @BSigned[0], @OSigned[0]);
    for I := 0 to 15 do Assert.AreEqual(Integer(SatS16(Integer(ASigned[I]) - Integer(BSigned[I]))), Integer(OSigned[I]), 'VPSUBSW');
  end;
end;

procedure TAvx2SemanticTests.SignedUnsignedMinMax;
var
  State: Cardinal;
  ASigned, BSigned, OSigned: TInt32x8;
  AU, BU, OU: TUInt32x8;
  CaseIndex, I: Integer;
  ExpectedS: Integer;
  ExpectedU: Cardinal;
begin
  if not Avx2Available then begin Assert.IsTrue(True, 'AVX2 unavailable'); Exit; end;
  State := $DEADBEEF;
  for CaseIndex := 0 to 63 do
  begin
    for I := 0 to 7 do
    begin
      ASigned[I] := BitsToInt32(NextRandom(State));
      BSigned[I] := BitsToInt32(NextRandom(State));
      AU[I] := NextRandom(State);
      BU[I] := NextRandom(State);
    end;
    RunBinaryYmm('vpminsd', @ASigned[0], @BSigned[0], @OSigned[0]);
    for I := 0 to 7 do begin if ASigned[I] < BSigned[I] then ExpectedS := ASigned[I] else ExpectedS := BSigned[I]; Assert.AreEqual(ExpectedS, OSigned[I], 'VPMINSD'); end;
    RunBinaryYmm('vpmaxsd', @ASigned[0], @BSigned[0], @OSigned[0]);
    for I := 0 to 7 do begin if ASigned[I] > BSigned[I] then ExpectedS := ASigned[I] else ExpectedS := BSigned[I]; Assert.AreEqual(ExpectedS, OSigned[I], 'VPMAXSD'); end;
    RunBinaryYmm('vpminud', @AU[0], @BU[0], @OU[0]);
    for I := 0 to 7 do begin if AU[I] < BU[I] then ExpectedU := AU[I] else ExpectedU := BU[I]; Assert.AreEqual(ExpectedU, OU[I], 'VPMINUD'); end;
    RunBinaryYmm('vpmaxud', @AU[0], @BU[0], @OU[0]);
    for I := 0 to 7 do begin if AU[I] > BU[I] then ExpectedU := AU[I] else ExpectedU := BU[I]; Assert.AreEqual(ExpectedU, OU[I], 'VPMAXUD'); end;
  end;
end;

procedure TAvx2SemanticTests.MultiplyAndMadd;
var
  A32, B32, O32: TInt32x8;
  AU32, BU32: TUInt32x8;
  A16, B16: TInt16x16;
  AUB: TUInt8x32;
  BSB: TInt8x32;
  OW: TInt16x16;
  O64: TInt64x4;
  OU64: TUInt64x4;
  State: Cardinal;
  CaseIndex, I, PairValue: Integer;
  Expected64: Int64;
begin
  if not Avx2Available then begin Assert.IsTrue(True, 'AVX2 unavailable'); Exit; end;
  State := $0BADF00D;
  for CaseIndex := 0 to 63 do
  begin
    for I := 0 to 7 do
    begin
      A32[I] := Integer(NextRandom(State) mod 80001) - 40000;
      B32[I] := Integer(NextRandom(State) mod 80001) - 40000;
    end;
    RunBinaryYmm('vpmulld', @A32[0], @B32[0], @O32[0]);
    for I := 0 to 7 do Assert.AreEqual(A32[I] * B32[I], O32[I], 'VPMULLD');
    RunBinaryYmm('vpmuldq', @A32[0], @B32[0], @O64[0]);
    for I := 0 to 3 do begin Expected64 := Int64(A32[I * 2]) * Int64(B32[I * 2]); Assert.IsTrue(O64[I] = Expected64, 'VPMULDQ'); end;
    for I := 0 to 7 do begin AU32[I] := NextRandom(State); BU32[I] := NextRandom(State); end;
    RunBinaryYmm('vpmuludq', @AU32[0], @BU32[0], @OU64[0]);
    for I := 0 to 3 do Assert.IsTrue(OU64[I] = UInt64(AU32[I * 2]) * UInt64(BU32[I * 2]), 'VPMULUDQ');
    for I := 0 to 15 do
    begin
      A16[I] := SmallInt(Integer(NextRandom(State) mod 40001) - 20000);
      B16[I] := SmallInt(Integer(NextRandom(State) mod 40001) - 20000);
    end;
    RunBinaryYmm('vpmaddwd', @A16[0], @B16[0], @O32[0]);
    for I := 0 to 7 do Assert.AreEqual(Integer(A16[I * 2]) * Integer(B16[I * 2]) + Integer(A16[I * 2 + 1]) * Integer(B16[I * 2 + 1]), O32[I], 'VPMADDWD');
    for I := 0 to 31 do begin AUB[I] := Byte(NextRandom(State) shr 24); BSB[I] := ShortInt(Integer(NextRandom(State) mod 256) - 128); end;
    RunBinaryYmm('vpmaddubsw', @AUB[0], @BSB[0], @OW[0]);
    for I := 0 to 15 do begin PairValue := Integer(AUB[I * 2]) * Integer(BSB[I * 2]) + Integer(AUB[I * 2 + 1]) * Integer(BSB[I * 2 + 1]); Assert.AreEqual(Integer(SatS16(PairValue)), Integer(OW[I]), 'VPMADDUBSW'); end;
  end;
end;

procedure TAvx2SemanticTests.VariableDwordShifts;
var
  A, Counts, O: TUInt32x8;
  ASigned, OSigned: TInt32x8;
  State: Cardinal;
  CaseIndex, I: Integer;
  C: Cardinal;
begin
  if not Avx2Available then begin Assert.IsTrue(True, 'AVX2 unavailable'); Exit; end;
  State := $55AA55AA;
  for CaseIndex := 0 to 63 do
  begin
    for I := 0 to 7 do
    begin
      A[I] := NextRandom(State);
      ASigned[I] := Integer(A[I]);
      Counts[I] := NextRandom(State) mod 40;
    end;
    RunBinaryYmm('vpsllvd', @A[0], @Counts[0], @O[0]);
    for I := 0 to 7 do begin C := Counts[I]; if C >= 32 then Assert.AreEqual(Cardinal(0), O[I], 'VPSLLVD') else Assert.AreEqual(Cardinal(A[I] shl C), O[I], 'VPSLLVD'); end;
    RunBinaryYmm('vpsrlvd', @A[0], @Counts[0], @O[0]);
    for I := 0 to 7 do begin C := Counts[I]; if C >= 32 then Assert.AreEqual(Cardinal(0), O[I], 'VPSRLVD') else Assert.AreEqual(Cardinal(A[I] shr C), O[I], 'VPSRLVD'); end;
    RunBinaryYmm('vpsravd', @ASigned[0], @Counts[0], @OSigned[0]);
    for I := 0 to 7 do Assert.AreEqual(Sar32(ASigned[I], Counts[I]), OSigned[I], 'VPSRAVD');
  end;
end;

procedure TAvx2SemanticTests.VariableQwordShifts;
var
  A, Counts, O: TUInt64x4;
  State: Cardinal;
  CaseIndex, I: Integer;
  C: UInt64;
begin
  if not Avx2Available then begin Assert.IsTrue(True, 'AVX2 unavailable'); Exit; end;
  State := $11223344;
  for CaseIndex := 0 to 63 do
  begin
    for I := 0 to 3 do
    begin
      A[I] := UInt64(NextRandom(State)) or (UInt64(NextRandom(State)) shl 32);
      Counts[I] := NextRandom(State) mod 72;
    end;
    RunBinaryYmm('vpsllvq', @A[0], @Counts[0], @O[0]);
    for I := 0 to 3 do begin C := Counts[I]; if C >= 64 then Assert.IsTrue(O[I] = 0, 'VPSLLVQ') else Assert.IsTrue(O[I] = (A[I] shl C), 'VPSLLVQ'); end;
    RunBinaryYmm('vpsrlvq', @A[0], @Counts[0], @O[0]);
    for I := 0 to 3 do begin C := Counts[I]; if C >= 64 then Assert.IsTrue(O[I] = 0, 'VPSRLVQ') else Assert.IsTrue(O[I] = (A[I] shr C), 'VPSRLVQ'); end;
  end;
end;

procedure TAvx2SemanticTests.PermuteAndShuffle;
var
  Data, Index, OutD: TUInt32x8;
  Bytes, Mask, OutB: TUInt8x32;
  Builder: TAsmBuilder;
  Exe: TExecutableCode;
  I: Integer;
begin
  if not Avx2Available then begin Assert.IsTrue(True, 'AVX2 unavailable'); Exit; end;
  for I := 0 to 7 do begin Data[I] := 100 + I * 11; Index[I] := Cardinal(7 - I); end;
  Builder := TAsmBuilder.New;
  try
    Builder.Vmovdqu(YMM0, YmmWordPtr(ridRCX)).Vmovdqu(YMM1, YmmWordPtr(ridRDX)).Vpermd(YMM2, YMM1, YMM0).Vmovdqu(YmmWordPtr(ridR8), YMM2).Vzeroupper.Ret;
    Exe := TExecutableCode.Create(Builder.Build);
    try Exe.Run(UInt64(NativeUInt(@Data[0])), UInt64(NativeUInt(@Index[0])), UInt64(NativeUInt(@OutD[0]))); finally Exe.Free; end;
  finally
    Builder.Free;
  end;
  for I := 0 to 7 do Assert.AreEqual(Data[7 - I], OutD[I], 'VPERMD reverse');

  for I := 0 to 31 do begin Bytes[I] := Byte(I + 1); Mask[I] := Byte(15 - (I and 15)); end;
  Mask[3] := $80;
  Mask[19] := $FF;
  RunBinaryYmm('vpshufb', @Bytes[0], @Mask[0], @OutB[0]);
  for I := 0 to 31 do
  begin
    if (Mask[I] and $80) <> 0 then Assert.AreEqual(Byte(0), OutB[I], 'VPSHUFB zero')
    else Assert.AreEqual(Bytes[(I and $10) + (Mask[I] and $0F)], OutB[I], 'VPSHUFB lane');
  end;
end;

procedure TAvx2SemanticTests.PackUnpackLaneSemantics;
var
  AWord, BWord: TInt16x16;
  OutPacked: TInt8x32;
  AByte, BByte, OutByte: TUInt8x32;
  I, Lane, BaseWord, BaseByte: Integer;
begin
  if not Avx2Available then begin Assert.IsTrue(True, 'AVX2 unavailable'); Exit; end;
  for I := 0 to 15 do
  begin
    AWord[I] := SmallInt(I * 90 - 700);
    BWord[I] := SmallInt(700 - I * 75);
  end;
  RunBinaryYmm('vpacksswb', @AWord[0], @BWord[0], @OutPacked[0]);
  for Lane := 0 to 1 do
  begin
    BaseWord := Lane * 8;
    BaseByte := Lane * 16;
    for I := 0 to 7 do
    begin
      Assert.AreEqual(Integer(SatS8(AWord[BaseWord + I])), Integer(OutPacked[BaseByte + I]), 'VPACKSSWB A');
      Assert.AreEqual(Integer(SatS8(BWord[BaseWord + I])), Integer(OutPacked[BaseByte + 8 + I]), 'VPACKSSWB B');
    end;
  end;
  RunBinaryYmm('vpackuswb', @AWord[0], @BWord[0], @OutByte[0]);
  for Lane := 0 to 1 do
  begin
    BaseWord := Lane * 8;
    BaseByte := Lane * 16;
    for I := 0 to 7 do
    begin
      Assert.AreEqual(SatU8(AWord[BaseWord + I]), OutByte[BaseByte + I], 'VPACKUSWB A');
      Assert.AreEqual(SatU8(BWord[BaseWord + I]), OutByte[BaseByte + 8 + I], 'VPACKUSWB B');
    end;
  end;
  for I := 0 to 31 do
  begin
    AByte[I] := Byte(I);
    BByte[I] := Byte(200 + (I mod 40));
  end;
  RunBinaryYmm('vpunpcklbw', @AByte[0], @BByte[0], @OutByte[0]);
  for Lane := 0 to 1 do
  begin
    BaseByte := Lane * 16;
    for I := 0 to 7 do
    begin
      Assert.AreEqual(AByte[BaseByte + I], OutByte[BaseByte + I * 2], 'VPUNPCKLBW A');
      Assert.AreEqual(BByte[BaseByte + I], OutByte[BaseByte + I * 2 + 1], 'VPUNPCKLBW B');
    end;
  end;
end;

procedure TAvx2SemanticTests.SignZeroExtendAndBroadcast;
type
  TBytes16 = array[0..15] of Byte;
  TSBytes16 = array[0..15] of ShortInt;
var
  U: TBytes16;
  S: TSBytes16;
  UW: TUInt16x16;
  SW: TInt16x16;
  OutB: TUInt8x32;
  Builder: TAsmBuilder;
  Exe: TExecutableCode;
  I: Integer;
begin
  if not Avx2Available then begin Assert.IsTrue(True, 'AVX2 unavailable'); Exit; end;
  for I := 0 to 15 do begin U[I] := Byte(I * 17); S[I] := ShortInt(I * 13 - 96); end;
  Builder := TAsmBuilder.New;
  try
    Builder.Vpmovzxbw(YMM0, XmmWordPtr(ridRCX)).Vmovdqu(YmmWordPtr(ridRDX), YMM0).Vzeroupper.Ret;
    Exe := TExecutableCode.Create(Builder.Build);
    try Exe.Run(UInt64(NativeUInt(@U[0])), UInt64(NativeUInt(@UW[0]))); finally Exe.Free; end;
  finally Builder.Free; end;
  for I := 0 to 15 do Assert.AreEqual(Word(U[I]), UW[I], 'VPMOVZXBW');

  Builder := TAsmBuilder.New;
  try
    Builder.Vpmovsxbw(YMM0, XmmWordPtr(ridRCX)).Vmovdqu(YmmWordPtr(ridRDX), YMM0).Vzeroupper.Ret;
    Exe := TExecutableCode.Create(Builder.Build);
    try Exe.Run(UInt64(NativeUInt(@S[0])), UInt64(NativeUInt(@SW[0]))); finally Exe.Free; end;
  finally Builder.Free; end;
  for I := 0 to 15 do Assert.AreEqual(Integer(S[I]), Integer(SW[I]), 'VPMOVSXBW');

  U[0] := $A5;
  Builder := TAsmBuilder.New;
  try
    Builder.Vpbroadcastb(YMM0, BytePtr(ridRCX)).Vmovdqu(YmmWordPtr(ridRDX), YMM0).Vzeroupper.Ret;
    Exe := TExecutableCode.Create(Builder.Build);
    try Exe.Run(UInt64(NativeUInt(@U[0])), UInt64(NativeUInt(@OutB[0]))); finally Exe.Free; end;
  finally Builder.Free; end;
  for I := 0 to 31 do Assert.AreEqual(Byte($A5), OutB[I], 'VPBROADCASTB');
end;

procedure TAvx2SemanticTests.MaskedMemoryLoadStore;
var
  Source, Loaded, Stored: TUInt32x8;
  Mask: TInt32x8;
  Builder: TAsmBuilder;
  Exe: TExecutableCode;
  I: Integer;
begin
  if not Avx2Available then begin Assert.IsTrue(True, 'AVX2 unavailable'); Exit; end;
  for I := 0 to 7 do begin Source[I] := 1000 + I; Mask[I] := 0; if (I and 1) = 0 then Mask[I] := Low(Integer); Loaded[I] := $CCCCCCCC; Stored[I] := $AAAAAAAA; end;
  Builder := TAsmBuilder.New;
  try
    Builder.Vmovdqu(YMM1, YmmWordPtr(ridRDX)).Vpmaskmovd(YMM0, YMM1, YmmWordPtr(ridRCX)).Vmovdqu(YmmWordPtr(ridR8), YMM0).Vzeroupper.Ret;
    Exe := TExecutableCode.Create(Builder.Build);
    try Exe.Run(UInt64(NativeUInt(@Source[0])), UInt64(NativeUInt(@Mask[0])), UInt64(NativeUInt(@Loaded[0]))); finally Exe.Free; end;
  finally Builder.Free; end;
  for I := 0 to 7 do if (I and 1) = 0 then Assert.AreEqual(Source[I], Loaded[I], 'VPMASKMOVD load selected') else Assert.AreEqual(Cardinal(0), Loaded[I], 'VPMASKMOVD load zero');

  Builder := TAsmBuilder.New;
  try
    Builder.Vmovdqu(YMM0, YmmWordPtr(ridRCX)).Vmovdqu(YMM1, YmmWordPtr(ridRDX)).Vpmaskmovd(YmmWordPtr(ridR8), YMM1, YMM0).Vzeroupper.Ret;
    Exe := TExecutableCode.Create(Builder.Build);
    try Exe.Run(UInt64(NativeUInt(@Source[0])), UInt64(NativeUInt(@Mask[0])), UInt64(NativeUInt(@Stored[0]))); finally Exe.Free; end;
  finally Builder.Free; end;
  for I := 0 to 7 do if (I and 1) = 0 then Assert.AreEqual(Source[I], Stored[I], 'VPMASKMOVD store selected') else Assert.AreEqual(Cardinal($AAAAAAAA), Stored[I], 'VPMASKMOVD store preserved');
end;

procedure TAvx2SemanticTests.IntegerGatherFamilies;
type
  TSource64 = array[0..31] of UInt64;
  TIndices32x8 = array[0..7] of Integer;
  TIndices64x4 = array[0..3] of Int64;
var
  Source: TSource64;
  Idx32: TIndices32x8;
  Idx64: TIndices64x4;
  Out32: TUInt32x8;
  Out64: TUInt64x4;
  Builder: TAsmBuilder;
  Exe: TExecutableCode;
  I: Integer;
begin
  if not Avx2Available then begin Assert.IsTrue(True, 'AVX2 unavailable'); Exit; end;
  for I := 0 to 31 do Source[I] := (UInt64(1) shl 32) + UInt64(I) * UInt64($101010101);
  Idx32[0] := 7; Idx32[1] := 0; Idx32[2] := 14; Idx32[3] := 3; Idx32[4] := 9; Idx32[5] := 2; Idx32[6] := 15; Idx32[7] := 5;
  Builder := TAsmBuilder.New;
  try
    Builder.Vmovdqu(YMM1, YmmWordPtr(ridRDX)).Vpcmpeqd(YMM2, YMM2, YMM2).Vpgatherdd(YMM0, Vm32y(ridRCX, YMM1, s4), YMM2).Vmovdqu(YmmWordPtr(ridR8), YMM0).Vzeroupper.Ret;
    Exe := TExecutableCode.Create(Builder.Build);
    try Exe.Run(UInt64(NativeUInt(@Source[0])), UInt64(NativeUInt(@Idx32[0])), UInt64(NativeUInt(@Out32[0]))); finally Exe.Free; end;
  finally Builder.Free; end;
  for I := 0 to 7 do Assert.AreEqual(ReadDwordAt(@Source[0], Idx32[I]), Out32[I], 'VPGATHERDD');

  Idx32[0] := 6; Idx32[1] := 1; Idx32[2] := 10; Idx32[3] := 3;
  Builder := TAsmBuilder.New;
  try
    Builder.Vmovdqu(XMM1, XmmWordPtr(ridRDX)).Vpcmpeqq(YMM2, YMM2, YMM2).Vpgatherdq(YMM0, Vm32x(ridRCX, XMM1, s8), YMM2).Vmovdqu(YmmWordPtr(ridR8), YMM0).Vzeroupper.Ret;
    Exe := TExecutableCode.Create(Builder.Build);
    try Exe.Run(UInt64(NativeUInt(@Source[0])), UInt64(NativeUInt(@Idx32[0])), UInt64(NativeUInt(@Out64[0]))); finally Exe.Free; end;
  finally Builder.Free; end;
  for I := 0 to 3 do Assert.IsTrue(Out64[I] = Source[Idx32[I]], 'VPGATHERDQ');

  for I := 0 to 3 do Idx64[I] := I * 3 + 1;
  Builder := TAsmBuilder.New;
  try
    Builder.Vmovdqu(YMM1, YmmWordPtr(ridRDX)).Vpcmpeqd(XMM2, XMM2, XMM2).Vpgatherqd(XMM0, Vm64y(ridRCX, YMM1, s4), XMM2).Vmovdqu(XmmWordPtr(ridR8), XMM0).Vzeroupper.Ret;
    Exe := TExecutableCode.Create(Builder.Build);
    try Exe.Run(UInt64(NativeUInt(@Source[0])), UInt64(NativeUInt(@Idx64[0])), UInt64(NativeUInt(@Out32[0]))); finally Exe.Free; end;
  finally Builder.Free; end;
  for I := 0 to 3 do Assert.AreEqual(ReadDwordAt(@Source[0], Integer(Idx64[I])), Out32[I], 'VPGATHERQD');

  Builder := TAsmBuilder.New;
  try
    Builder.Vmovdqu(YMM1, YmmWordPtr(ridRDX)).Vpcmpeqq(YMM2, YMM2, YMM2).Vpgatherqq(YMM0, Vm64y(ridRCX, YMM1, s8), YMM2).Vmovdqu(YmmWordPtr(ridR8), YMM0).Vzeroupper.Ret;
    Exe := TExecutableCode.Create(Builder.Build);
    try Exe.Run(UInt64(NativeUInt(@Source[0])), UInt64(NativeUInt(@Idx64[0])), UInt64(NativeUInt(@Out64[0]))); finally Exe.Free; end;
  finally Builder.Free; end;
  for I := 0 to 3 do Assert.IsTrue(Out64[I] = Source[Idx64[I]], 'VPGATHERQQ');
end;

procedure TAvx2SemanticTests.FloatGatherFamilies;
type
  TSingle32 = array[0..31] of Single;
  TDouble32 = array[0..31] of Double;
  TIndices32x8 = array[0..7] of Integer;
  TIndices64x4 = array[0..3] of Int64;
  TSingle8 = array[0..7] of Single;
  TDouble4 = array[0..3] of Double;
var
  FS: TSingle32;
  DS: TDouble32;
  I32: TIndices32x8;
  I64: TIndices64x4;
  FO: TSingle8;
  DO_: TDouble4;
  Builder: TAsmBuilder;
  Exe: TExecutableCode;
  I: Integer;
begin
  if not Avx2Available then begin Assert.IsTrue(True, 'AVX2 unavailable'); Exit; end;
  for I := 0 to 31 do begin FS[I] := I * 1.25 + 0.5; DS[I] := I * 2.5 + 0.25; end;
  I32[0] := 7; I32[1] := 0; I32[2] := 14; I32[3] := 3; I32[4] := 9; I32[5] := 2; I32[6] := 15; I32[7] := 5;
  Builder := TAsmBuilder.New;
  try
    Builder.Vmovdqu(YMM1, YmmWordPtr(ridRDX)).Vpcmpeqd(YMM2, YMM2, YMM2).Vgatherdps(YMM0, Vm32y(ridRCX, YMM1, s4), YMM2).Vmovups(YmmWordPtr(ridR8), YMM0).Vzeroupper.Ret;
    Exe := TExecutableCode.Create(Builder.Build);
    try Exe.Run(UInt64(NativeUInt(@FS[0])), UInt64(NativeUInt(@I32[0])), UInt64(NativeUInt(@FO[0]))); finally Exe.Free; end;
  finally Builder.Free; end;
  for I := 0 to 7 do Assert.IsTrue(FO[I] = FS[I32[I]], 'VGATHERDPS');

  I32[0] := 6; I32[1] := 1; I32[2] := 10; I32[3] := 3;
  Builder := TAsmBuilder.New;
  try
    Builder.Vmovdqu(XMM1, XmmWordPtr(ridRDX)).Vpcmpeqq(YMM2, YMM2, YMM2).Vgatherdpd(YMM0, Vm32x(ridRCX, XMM1, s8), YMM2).Vmovupd(YmmWordPtr(ridR8), YMM0).Vzeroupper.Ret;
    Exe := TExecutableCode.Create(Builder.Build);
    try Exe.Run(UInt64(NativeUInt(@DS[0])), UInt64(NativeUInt(@I32[0])), UInt64(NativeUInt(@DO_[0]))); finally Exe.Free; end;
  finally Builder.Free; end;
  for I := 0 to 3 do Assert.IsTrue(DO_[I] = DS[I32[I]], 'VGATHERDPD');

  for I := 0 to 3 do I64[I] := I * 3 + 1;
  Builder := TAsmBuilder.New;
  try
    Builder.Vmovdqu(YMM1, YmmWordPtr(ridRDX)).Vpcmpeqd(XMM2, XMM2, XMM2).Vgatherqps(XMM0, Vm64y(ridRCX, YMM1, s4), XMM2).Vmovups(XmmWordPtr(ridR8), XMM0).Vzeroupper.Ret;
    Exe := TExecutableCode.Create(Builder.Build);
    try Exe.Run(UInt64(NativeUInt(@FS[0])), UInt64(NativeUInt(@I64[0])), UInt64(NativeUInt(@FO[0]))); finally Exe.Free; end;
  finally Builder.Free; end;
  for I := 0 to 3 do Assert.IsTrue(FO[I] = FS[Integer(I64[I])], 'VGATHERQPS');

  Builder := TAsmBuilder.New;
  try
    Builder.Vmovdqu(YMM1, YmmWordPtr(ridRDX)).Vpcmpeqq(YMM2, YMM2, YMM2).Vgatherqpd(YMM0, Vm64y(ridRCX, YMM1, s8), YMM2).Vmovupd(YmmWordPtr(ridR8), YMM0).Vzeroupper.Ret;
    Exe := TExecutableCode.Create(Builder.Build);
    try Exe.Run(UInt64(NativeUInt(@DS[0])), UInt64(NativeUInt(@I64[0])), UInt64(NativeUInt(@DO_[0]))); finally Exe.Free; end;
  finally Builder.Free; end;
  for I := 0 to 3 do Assert.IsTrue(DO_[I] = DS[Integer(I64[I])], 'VGATHERQPD');
end;

initialization
  TDUnitX.RegisterTestFixture(TAvx2SemanticTests);

end.
