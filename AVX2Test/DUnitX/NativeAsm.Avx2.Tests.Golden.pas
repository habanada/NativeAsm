unit NativeAsm.Avx2.Tests.Golden;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TAvx2GoldenTests = class
  public
    [Test] procedure ArithmeticAndSaturation;
    [Test] procedure MinMaxMultiplyAndMadd;
    [Test] procedure ShiftPermuteShufflePack;
    [Test] procedure ExtendBroadcastMaskGather;
    [Test] procedure HighRegistersAndAddressing;
  end;

implementation

uses
  NativeAsm.Types,
  NativeAsm.Simd.Types,
  NativeAsm.Avx.Types,
  NativeAsm.Avx,
  NativeAsm.Avx2.Tests.Support;

procedure TAvx2GoldenTests.ArithmeticAndSaturation;
begin
  CheckAvx2Hex('vpaddb ymm0,ymm1,ymm2', 'vpaddb', [AvxOp(YMM0), AvxOp(YMM1), AvxOp(YMM2)], 'C5 F5 FC C2');
  CheckAvx2Hex('vpaddw ymm3,ymm4,ymm5', 'vpaddw', [AvxOp(YMM3), AvxOp(YMM4), AvxOp(YMM5)], 'C5 DD FD DD');
  CheckAvx2Hex('vpaddd ymm6,ymm7,ymm0', 'vpaddd', [AvxOp(YMM6), AvxOp(YMM7), AvxOp(YMM0)], 'C5 C5 FE F0');
  CheckAvx2Hex('vpaddq ymm1,ymm2,ymm3', 'vpaddq', [AvxOp(YMM1), AvxOp(YMM2), AvxOp(YMM3)], 'C5 ED D4 CB');
  CheckAvx2Hex('vpaddsb ymm0,ymm1,ymm2', 'vpaddsb', [AvxOp(YMM0), AvxOp(YMM1), AvxOp(YMM2)], 'C5 F5 EC C2');
  CheckAvx2Hex('vpaddsw ymm3,ymm4,ymm5', 'vpaddsw', [AvxOp(YMM3), AvxOp(YMM4), AvxOp(YMM5)], 'C5 DD ED DD');
  CheckAvx2Hex('vpaddusb ymm6,ymm7,ymm0', 'vpaddusb', [AvxOp(YMM6), AvxOp(YMM7), AvxOp(YMM0)], 'C5 C5 DC F0');
  CheckAvx2Hex('vpaddusw ymm1,ymm2,ymm3', 'vpaddusw', [AvxOp(YMM1), AvxOp(YMM2), AvxOp(YMM3)], 'C5 ED DD CB');
  CheckAvx2Hex('vpsubb ymm0,ymm1,ymm2', 'vpsubb', [AvxOp(YMM0), AvxOp(YMM1), AvxOp(YMM2)], 'C5 F5 F8 C2');
  CheckAvx2Hex('vpsubw ymm3,ymm4,ymm5', 'vpsubw', [AvxOp(YMM3), AvxOp(YMM4), AvxOp(YMM5)], 'C5 DD F9 DD');
  CheckAvx2Hex('vpsubd ymm6,ymm7,ymm0', 'vpsubd', [AvxOp(YMM6), AvxOp(YMM7), AvxOp(YMM0)], 'C5 C5 FA F0');
  CheckAvx2Hex('vpsubq ymm1,ymm2,ymm3', 'vpsubq', [AvxOp(YMM1), AvxOp(YMM2), AvxOp(YMM3)], 'C5 ED FB CB');
  CheckAvx2Hex('vpsubsb ymm0,ymm1,ymm2', 'vpsubsb', [AvxOp(YMM0), AvxOp(YMM1), AvxOp(YMM2)], 'C5 F5 E8 C2');
  CheckAvx2Hex('vpsubsw ymm3,ymm4,ymm5', 'vpsubsw', [AvxOp(YMM3), AvxOp(YMM4), AvxOp(YMM5)], 'C5 DD E9 DD');
  CheckAvx2Hex('vpsubusb ymm6,ymm7,ymm0', 'vpsubusb', [AvxOp(YMM6), AvxOp(YMM7), AvxOp(YMM0)], 'C5 C5 D8 F0');
  CheckAvx2Hex('vpsubusw ymm1,ymm2,ymm3', 'vpsubusw', [AvxOp(YMM1), AvxOp(YMM2), AvxOp(YMM3)], 'C5 ED D9 CB');
end;

procedure TAvx2GoldenTests.MinMaxMultiplyAndMadd;
begin
  CheckAvx2Hex('vpmaxsb ymm0,ymm1,ymm2', 'vpmaxsb', [AvxOp(YMM0), AvxOp(YMM1), AvxOp(YMM2)], 'C4 E2 75 3C C2');
  CheckAvx2Hex('vpmaxsd ymm3,ymm4,ymm5', 'vpmaxsd', [AvxOp(YMM3), AvxOp(YMM4), AvxOp(YMM5)], 'C4 E2 5D 3D DD');
  CheckAvx2Hex('vpmaxsw ymm6,ymm7,ymm0', 'vpmaxsw', [AvxOp(YMM6), AvxOp(YMM7), AvxOp(YMM0)], 'C5 C5 EE F0');
  CheckAvx2Hex('vpmaxub ymm1,ymm2,ymm3', 'vpmaxub', [AvxOp(YMM1), AvxOp(YMM2), AvxOp(YMM3)], 'C5 ED DE CB');
  CheckAvx2Hex('vpmaxud ymm4,ymm5,ymm6', 'vpmaxud', [AvxOp(YMM4), AvxOp(YMM5), AvxOp(YMM6)], 'C4 E2 55 3F E6');
  CheckAvx2Hex('vpmaxuw ymm7,ymm0,ymm1', 'vpmaxuw', [AvxOp(YMM7), AvxOp(YMM0), AvxOp(YMM1)], 'C4 E2 7D 3E F9');
  CheckAvx2Hex('vpminsb ymm0,ymm1,ymm2', 'vpminsb', [AvxOp(YMM0), AvxOp(YMM1), AvxOp(YMM2)], 'C4 E2 75 38 C2');
  CheckAvx2Hex('vpminsd ymm3,ymm4,ymm5', 'vpminsd', [AvxOp(YMM3), AvxOp(YMM4), AvxOp(YMM5)], 'C4 E2 5D 39 DD');
  CheckAvx2Hex('vpminsw ymm6,ymm7,ymm0', 'vpminsw', [AvxOp(YMM6), AvxOp(YMM7), AvxOp(YMM0)], 'C5 C5 EA F0');
  CheckAvx2Hex('vpminub ymm1,ymm2,ymm3', 'vpminub', [AvxOp(YMM1), AvxOp(YMM2), AvxOp(YMM3)], 'C5 ED DA CB');
  CheckAvx2Hex('vpminud ymm4,ymm5,ymm6', 'vpminud', [AvxOp(YMM4), AvxOp(YMM5), AvxOp(YMM6)], 'C4 E2 55 3B E6');
  CheckAvx2Hex('vpminuw ymm7,ymm0,ymm1', 'vpminuw', [AvxOp(YMM7), AvxOp(YMM0), AvxOp(YMM1)], 'C4 E2 7D 3A F9');
  CheckAvx2Hex('vpmulld ymm0,ymm1,ymm2', 'vpmulld', [AvxOp(YMM0), AvxOp(YMM1), AvxOp(YMM2)], 'C4 E2 75 40 C2');
  CheckAvx2Hex('vpmuldq ymm3,ymm4,ymm5', 'vpmuldq', [AvxOp(YMM3), AvxOp(YMM4), AvxOp(YMM5)], 'C4 E2 5D 28 DD');
  CheckAvx2Hex('vpmuludq ymm6,ymm7,ymm0', 'vpmuludq', [AvxOp(YMM6), AvxOp(YMM7), AvxOp(YMM0)], 'C5 C5 F4 F0');
  CheckAvx2Hex('vpmaddwd ymm1,ymm2,ymm3', 'vpmaddwd', [AvxOp(YMM1), AvxOp(YMM2), AvxOp(YMM3)], 'C5 ED F5 CB');
  CheckAvx2Hex('vpmaddubsw ymm4,ymm5,ymm6', 'vpmaddubsw', [AvxOp(YMM4), AvxOp(YMM5), AvxOp(YMM6)], 'C4 E2 55 04 E6');
end;

procedure TAvx2GoldenTests.ShiftPermuteShufflePack;
begin
  CheckAvx2Hex('vpsllvd ymm0,ymm1,ymm2', 'vpsllvd', [AvxOp(YMM0), AvxOp(YMM1), AvxOp(YMM2)], 'C4 E2 75 47 C2');
  CheckAvx2Hex('vpsrlvd ymm3,ymm4,ymm5', 'vpsrlvd', [AvxOp(YMM3), AvxOp(YMM4), AvxOp(YMM5)], 'C4 E2 5D 45 DD');
  CheckAvx2Hex('vpsravd ymm6,ymm7,ymm0', 'vpsravd', [AvxOp(YMM6), AvxOp(YMM7), AvxOp(YMM0)], 'C4 E2 45 46 F0');
  CheckAvx2Hex('vpsllvq ymm1,ymm2,ymm3', 'vpsllvq', [AvxOp(YMM1), AvxOp(YMM2), AvxOp(YMM3)], 'C4 E2 ED 47 CB');
  CheckAvx2Hex('vpsrlvq ymm4,ymm5,ymm6', 'vpsrlvq', [AvxOp(YMM4), AvxOp(YMM5), AvxOp(YMM6)], 'C4 E2 D5 45 E6');
  CheckAvx2Hex('vpermq ymm0,ymm1,1B', 'vpermq', [AvxOp(YMM0), AvxOp(YMM1), AvxOp($1B)], 'C4 E3 FD 00 C1 1B');
  CheckAvx2Hex('vpermd ymm2,ymm3,ymm4', 'vpermd', [AvxOp(YMM2), AvxOp(YMM3), AvxOp(YMM4)], 'C4 E2 65 36 D4');
  CheckAvx2Hex('vpermps ymm5,ymm6,ymm7', 'vpermps', [AvxOp(YMM5), AvxOp(YMM6), AvxOp(YMM7)], 'C4 E2 4D 16 EF');
  CheckAvx2Hex('vperm2i128 ymm0,ymm1,ymm2,31', 'vperm2i128', [AvxOp(YMM0), AvxOp(YMM1), AvxOp(YMM2), AvxOp($31)], 'C4 E3 75 46 C2 31');
  CheckAvx2Hex('vinserti128 ymm3,ymm4,xmm5,1', 'vinserti128', [AvxOp(YMM3), AvxOp(YMM4), AvxOp(XMM5), AvxOp(1)], 'C4 E3 5D 38 DD 01');
  CheckAvx2Hex('vextracti128 xmm6,ymm7,1', 'vextracti128', [AvxOp(XMM6), AvxOp(YMM7), AvxOp(1)], 'C4 E3 7D 39 FE 01');
  CheckAvx2Hex('vpshufb ymm0,ymm1,ymm2', 'vpshufb', [AvxOp(YMM0), AvxOp(YMM1), AvxOp(YMM2)], 'C4 E2 75 00 C2');
  CheckAvx2Hex('vpacksswb ymm3,ymm4,ymm5', 'vpacksswb', [AvxOp(YMM3), AvxOp(YMM4), AvxOp(YMM5)], 'C5 DD 63 DD');
  CheckAvx2Hex('vpackssdw ymm6,ymm7,ymm0', 'vpackssdw', [AvxOp(YMM6), AvxOp(YMM7), AvxOp(YMM0)], 'C5 C5 6B F0');
  CheckAvx2Hex('vpackuswb ymm1,ymm2,ymm3', 'vpackuswb', [AvxOp(YMM1), AvxOp(YMM2), AvxOp(YMM3)], 'C5 ED 67 CB');
  CheckAvx2Hex('vpackusdw ymm4,ymm5,ymm6', 'vpackusdw', [AvxOp(YMM4), AvxOp(YMM5), AvxOp(YMM6)], 'C4 E2 55 2B E6');
  CheckAvx2Hex('vpunpcklbw ymm0,ymm1,ymm2', 'vpunpcklbw', [AvxOp(YMM0), AvxOp(YMM1), AvxOp(YMM2)], 'C5 F5 60 C2');
  CheckAvx2Hex('vpunpckhbw ymm3,ymm4,ymm5', 'vpunpckhbw', [AvxOp(YMM3), AvxOp(YMM4), AvxOp(YMM5)], 'C5 DD 68 DD');
  CheckAvx2Hex('vpunpcklwd ymm6,ymm7,ymm0', 'vpunpcklwd', [AvxOp(YMM6), AvxOp(YMM7), AvxOp(YMM0)], 'C5 C5 61 F0');
  CheckAvx2Hex('vpunpckhwd ymm1,ymm2,ymm3', 'vpunpckhwd', [AvxOp(YMM1), AvxOp(YMM2), AvxOp(YMM3)], 'C5 ED 69 CB');
end;

procedure TAvx2GoldenTests.ExtendBroadcastMaskGather;
begin
  CheckAvx2Hex('vpmovzxbw ymm0,xmm1', 'vpmovzxbw', [AvxOp(YMM0), AvxOp(XMM1)], 'C4 E2 7D 30 C1');
  CheckAvx2Hex('vpmovsxbw ymm2,xmm3', 'vpmovsxbw', [AvxOp(YMM2), AvxOp(XMM3)], 'C4 E2 7D 20 D3');
  CheckAvx2Hex('vpmovzxbd ymm4,xmm5', 'vpmovzxbd', [AvxOp(YMM4), AvxOp(XMM5)], 'C4 E2 7D 31 E5');
  CheckAvx2Hex('vpmovsxbd ymm6,xmm7', 'vpmovsxbd', [AvxOp(YMM6), AvxOp(XMM7)], 'C4 E2 7D 21 F7');
  CheckAvx2Hex('vpbroadcastb ymm0,xmm1', 'vpbroadcastb', [AvxOp(YMM0), AvxOp(XMM1)], 'C4 E2 7D 78 C1');
  CheckAvx2Hex('vpbroadcastw ymm2,xmm3', 'vpbroadcastw', [AvxOp(YMM2), AvxOp(XMM3)], 'C4 E2 7D 79 D3');
  CheckAvx2Hex('vpbroadcastd ymm4,xmm5', 'vpbroadcastd', [AvxOp(YMM4), AvxOp(XMM5)], 'C4 E2 7D 58 E5');
  CheckAvx2Hex('vpbroadcastq ymm6,xmm7', 'vpbroadcastq', [AvxOp(YMM6), AvxOp(XMM7)], 'C4 E2 7D 59 F7');
  CheckAvx2Hex('vpmaskmovd ymm0,ymm1,[rcx+32]', 'vpmaskmovd', [AvxOp(YMM0), AvxOp(YMM1), AvxOp(YmmWordPtr(ridRCX, 32))], 'C4 E2 75 8C 41 20');
  CheckAvx2Hex('vpmaskmovq [r12+64],ymm2,ymm3', 'vpmaskmovq', [AvxOp(YmmWordPtr(ridR12, 64)), AvxOp(YMM2), AvxOp(YMM3)], 'C4 C2 ED 8E 5C 24 40');
  CheckAvx2Hex('vpgatherdd ymm0,[rcx+ymm1*4],ymm2', 'vpgatherdd', [AvxOp(YMM0), AvxOp(Vm32y(ridRCX, YMM1, s4)), AvxOp(YMM2)], 'C4 E2 6D 90 04 89');
  CheckAvx2Hex('vpgatherdq ymm3,[rdx+xmm4*4],ymm5', 'vpgatherdq', [AvxOp(YMM3), AvxOp(Vm32x(ridRDX, XMM4, s4)), AvxOp(YMM5)], 'C4 E2 D5 90 1C A2');
  CheckAvx2Hex('vpgatherqd xmm0,[r8+xmm1*8],xmm2', 'vpgatherqd', [AvxOp(XMM0), AvxOp(Vm64x(ridR8, XMM1, s8)), AvxOp(XMM2)], 'C4 C2 69 91 04 C8');
  CheckAvx2Hex('vpgatherqq ymm3,[r9+ymm4*8],ymm5', 'vpgatherqq', [AvxOp(YMM3), AvxOp(Vm64y(ridR9, YMM4, s8)), AvxOp(YMM5)], 'C4 C2 D5 91 1C E1');
end;

procedure TAvx2GoldenTests.HighRegistersAndAddressing;
begin
  CheckAvx2Hex('vpaddd ymm8,ymm9,ymm10', 'vpaddd', [AvxOp(YMM8), AvxOp(YMM9), AvxOp(YMM10)], 'C4 41 35 FE C2');
  CheckAvx2Hex('vpshufb ymm15,ymm14,ymm13', 'vpshufb', [AvxOp(YMM15), AvxOp(YMM14), AvxOp(YMM13)], 'C4 42 0D 00 FD');
  CheckAvx2Hex('vpermd ymm12,ymm11,ymm10', 'vpermd', [AvxOp(YMM12), AvxOp(YMM11), AvxOp(YMM10)], 'C4 42 25 36 E2');
  CheckAvx2Hex('vpsllvd ymm9,ymm8,ymm15', 'vpsllvd', [AvxOp(YMM9), AvxOp(YMM8), AvxOp(YMM15)], 'C4 42 3D 47 CF');
  CheckAvx2Hex('vpmulld ymm13,ymm14,ymm15', 'vpmulld', [AvxOp(YMM13), AvxOp(YMM14), AvxOp(YMM15)], 'C4 42 0D 40 EF');
  CheckAvx2Hex('vpmaxud ymm15,ymm8,ymm9', 'vpmaxud', [AvxOp(YMM15), AvxOp(YMM8), AvxOp(YMM9)], 'C4 42 3D 3F F9');
  CheckAvx2Hex('vpmovzxbw ymm12,xmm13', 'vpmovzxbw', [AvxOp(YMM12), AvxOp(XMM13)], 'C4 42 7D 30 E5');
  CheckAvx2Hex('vpbroadcastd ymm14,[r13+127]', 'vpbroadcastd', [AvxOp(YMM14), AvxOp(DWordPtr(ridR13, 127))], 'C4 42 7D 58 75 7F');
  CheckAvx2Hex('vpaddd ymm0,ymm1,[r13]', 'vpaddd', [AvxOp(YMM0), AvxOp(YMM1), AvxOp(YmmWordPtr(ridR13))], 'C4 C1 75 FE 45 00');
  CheckAvx2Hex('vpaddd ymm0,ymm1,[rbp]', 'vpaddd', [AvxOp(YMM0), AvxOp(YMM1), AvxOp(YmmWordPtr(ridRBP))], 'C5 F5 FE 45 00');
  CheckAvx2Hex('vpaddd ymm0,ymm1,[rsp+128]', 'vpaddd', [AvxOp(YMM0), AvxOp(YMM1), AvxOp(YmmWordPtr(ridRSP, 128))], 'C5 F5 FE 84 24 80 00 00 00');
  CheckAvx2Hex('vpaddd ymm0,ymm1,[r12-129]', 'vpaddd', [AvxOp(YMM0), AvxOp(YMM1), AvxOp(YmmWordPtr(ridR12, -129))], 'C4 C1 75 FE 84 24 7F FF FF FF');
  CheckAvx2Hex('vpmaskmovd ymm8,ymm9,[r12+32]', 'vpmaskmovd', [AvxOp(YMM8), AvxOp(YMM9), AvxOp(YmmWordPtr(ridR12, 32))], 'C4 42 35 8C 44 24 20');
  CheckAvx2Hex('vpmaskmovq [r13+64],ymm10,ymm11', 'vpmaskmovq', [AvxOp(YmmWordPtr(ridR13, 64)), AvxOp(YMM10), AvxOp(YMM11)], 'C4 42 AD 8E 5D 40');
  CheckAvx2Hex('vpgatherdd ymm8,[r12+ymm9*4+32],ymm10', 'vpgatherdd', [AvxOp(YMM8), AvxOp(Vm32y(ridR12, YMM9, s4, 32)), AvxOp(YMM10)], 'C4 02 2D 90 44 8C 20');
  CheckAvx2Hex('vpgatherdq ymm11,[r13+xmm12*8+64],ymm14', 'vpgatherdq', [AvxOp(YMM11), AvxOp(Vm32x(ridR13, XMM12, s8, 64)), AvxOp(YMM14)], 'C4 02 8D 90 5C E5 40');
  CheckAvx2Hex('vpgatherqd xmm8,[r12+xmm9*4+32],xmm10', 'vpgatherqd', [AvxOp(XMM8), AvxOp(Vm64x(ridR12, XMM9, s4, 32)), AvxOp(XMM10)], 'C4 02 29 91 44 8C 20');
  CheckAvx2Hex('vpgatherqq ymm11,[r13+ymm12*8+64],ymm14', 'vpgatherqq', [AvxOp(YMM11), AvxOp(Vm64y(ridR13, YMM12, s8, 64)), AvxOp(YMM14)], 'C4 02 8D 91 5C E5 40');
end;

initialization
  TDUnitX.RegisterTestFixture(TAvx2GoldenTests);

end.
