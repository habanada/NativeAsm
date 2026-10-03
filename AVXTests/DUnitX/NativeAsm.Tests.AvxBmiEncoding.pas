unit NativeAsm.Tests.AvxBmiEncoding;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TAvxBmiEncodingTests = class
  public
    [Test] procedure CanonicalVexAndRegisterExtensionMatrix;
    [Test] procedure MemoryAddressingBoundaryMatrix;
    [Test] procedure GprScalarAndInsertExtractMatrix;
    [Test] procedure MaskedGatherAndSpecialEncodingMatrix;
    [Test] procedure CompletedVexSpecialFormsMatrix;
    [Test] procedure BmiGoldenMatrix;
    [Test] procedure PublicApiCompositionMatrix;
  end;

implementation

uses
  NativeAsm.Types,
  NativeAsm.Builder,
  NativeAsm.Simd.Types,
  NativeAsm.Avx.Types,
  NativeAsm.Avx,
  NativeAsm.Bmi,
  NativeAsm.Tests.SimdSupport;

procedure TAvxBmiEncodingTests.CanonicalVexAndRegisterExtensionMatrix;
begin
  CheckAvxHex('vaddps-xmm-basic', 'vaddps', [AvxOp(XMM0), AvxOp(XMM1), AvxOp(XMM2)], 'C5 F0 58 C2');
  CheckAvxHex('vaddps-r-only-vex2', 'vaddps', [AvxOp(XMM8), AvxOp(XMM1), AvxOp(XMM2)], 'C5 70 58 C2');
  CheckAvxHex('vaddps-b-requires-vex3', 'vaddps', [AvxOp(XMM0), AvxOp(XMM1), AvxOp(XMM8)], 'C4 C1 70 58 C0');
  CheckAvxHex('vaddps-xmm15-xmm0-xmm7', 'vaddps', [AvxOp(XMM15), AvxOp(XMM0), AvxOp(XMM7)], 'C5 78 58 FF');
  CheckAvxHex('vaddps-xmm7-xmm15-xmm0', 'vaddps', [AvxOp(XMM7), AvxOp(XMM15), AvxOp(XMM0)], 'C5 80 58 F8');
  CheckAvxHex('vaddps-ymm15-ymm0-ymm7', 'vaddps', [AvxOp(YMM15), AvxOp(YMM0), AvxOp(YMM7)], 'C5 7C 58 FF');
  CheckAvxHex('vaddps-ymm7-ymm15-ymm0', 'vaddps', [AvxOp(YMM7), AvxOp(YMM15), AvxOp(YMM0)], 'C5 84 58 F8');
  CheckAvxHex('vpaddd-xmm15', 'vpaddd', [AvxOp(XMM15), AvxOp(XMM0), AvxOp(XMM7)], 'C5 79 FE FF');
  CheckAvxHex('vpaddd-ymm15', 'vpaddd', [AvxOp(YMM15), AvxOp(YMM0), AvxOp(YMM7)], 'C5 7D FE FF');
  CheckAvxHex('vpslld-xmm15-imm31', 'vpslld', [AvxOp(XMM15), AvxOp(XMM14), AvxOp(31)], 'C4 C1 01 72 F6 1F');
  CheckAvxHex('vpslld-ymm15-imm31', 'vpslld', [AvxOp(YMM15), AvxOp(YMM14), AvxOp(31)], 'C4 C1 05 72 F6 1F');
  CheckAvxHex('vpermq-ymm15', 'vpermq', [AvxOp(YMM15), AvxOp(YMM14), AvxOp($1B)], 'C4 43 FD 00 FE 1B');
  CheckAvxHex('vpbroadcastd-ymm15', 'vpbroadcastd', [AvxOp(YMM15), AvxOp(TAvxMemory.Create(ridR15, 4, ams32))], 'C4 42 7D 58 7F 04');
  CheckAvxHex('vblendvps-high-mask', 'vblendvps', [AvxOp(XMM15), AvxOp(XMM14), AvxOp(XMM13), AvxOp(XMM12)], 'C4 43 09 4A FD C0');
  CheckAvxHex('vblendvpd-high-mask', 'vblendvpd', [AvxOp(YMM15), AvxOp(YMM14), AvxOp(YMM13), AvxOp(YMM12)], 'C4 43 0D 4B FD C0');
  CheckAvxHex('vpblendvb-high-mask', 'vpblendvb', [AvxOp(YMM15), AvxOp(YMM14), AvxOp(YMM13), AvxOp(YMM12)], 'C4 43 0D 4C FD C0');
  CheckAvxHex('vpabsd-xmm15', 'vpabsd', [AvxOp(XMM15), AvxOp(XMM14)], 'C4 42 79 1E FE');
  CheckAvxHex('vpabsd-ymm15-mem', 'vpabsd', [AvxOp(YMM15), AvxOp(YmmWordPtr(ridR15, 64))], 'C4 42 7D 1E 7F 40');
  CheckAvxHex('vmovups-ymm15', 'vmovups', [AvxOp(YMM15), AvxOp(YmmWordPtr(ridR15, 32))], 'C4 41 7C 10 7F 20');
  CheckAvxHex('vmovupd-store-ymm15', 'vmovupd', [AvxOp(YmmWordPtr(ridR15, 64)), AvxOp(YMM15)], 'C4 41 7D 11 7F 40');
end;

procedure TAvxBmiEncodingTests.MemoryAddressingBoundaryMatrix;
begin
  CheckAvxHex('vmovdqu-rax', 'vmovdqu', [AvxOp(XMM0), AvxOp(XmmWordPtr(ridRAX))], 'C5 FA 6F 00');
  CheckAvxHex('vmovdqu-rbp-zero', 'vmovdqu', [AvxOp(XMM0), AvxOp(XmmWordPtr(ridRBP))], 'C5 FA 6F 45 00');
  CheckAvxHex('vmovdqu-r13-zero', 'vmovdqu', [AvxOp(XMM0), AvxOp(XmmWordPtr(ridR13))], 'C4 C1 7A 6F 45 00');
  CheckAvxHex('vmovdqu-rsp', 'vmovdqu', [AvxOp(XMM0), AvxOp(XmmWordPtr(ridRSP))], 'C5 FA 6F 04 24');
  CheckAvxHex('vmovdqu-r12', 'vmovdqu', [AvxOp(XMM0), AvxOp(XmmWordPtr(ridR12))], 'C4 C1 7A 6F 04 24');
  CheckAvxHex('vmovdqu-disp127', 'vmovdqu', [AvxOp(XMM0), AvxOp(XmmWordPtr(ridRAX, 127))], 'C5 FA 6F 40 7F');
  CheckAvxHex('vmovdqu-disp128', 'vmovdqu', [AvxOp(XMM0), AvxOp(XmmWordPtr(ridRAX, 128))], 'C5 FA 6F 80 80 00 00 00');
  CheckAvxHex('vmovdqu-disp-minus128', 'vmovdqu', [AvxOp(XMM0), AvxOp(XmmWordPtr(ridRAX, -128))], 'C5 FA 6F 40 80');
  CheckAvxHex('vmovdqu-disp-minus129', 'vmovdqu', [AvxOp(XMM0), AvxOp(XmmWordPtr(ridRAX, -129))], 'C5 FA 6F 80 7F FF FF FF');
  CheckAvxHex('vmovdqu-sib-scale1', 'vmovdqu', [AvxOp(XMM0), AvxOp(XmmWordPtrSib(ridR12, ridR13, s1, 0))], 'C4 81 7A 6F 04 2C');
  CheckAvxHex('vmovdqu-sib-scale2', 'vmovdqu', [AvxOp(XMM0), AvxOp(XmmWordPtrSib(ridR12, ridR13, s2, 1))], 'C4 81 7A 6F 44 6C 01');
  CheckAvxHex('vmovdqu-sib-scale4', 'vmovdqu', [AvxOp(XMM0), AvxOp(XmmWordPtrSib(ridR12, ridR13, s4, 127))], 'C4 81 7A 6F 44 AC 7F');
  CheckAvxHex('vmovdqu-sib-scale8', 'vmovdqu', [AvxOp(XMM0), AvxOp(XmmWordPtrSib(ridR12, ridR13, s8, 128))], 'C4 81 7A 6F 84 EC 80 00 00 00');
  CheckAvxHex('vmovdqu-rip', 'vmovdqu', [AvxOp(XMM0), AvxOp(XmmWordPtrRip($12345678))], 'C5 FA 6F 05 78 56 34 12');
  CheckAvxHex('vaddps-r15-zero', 'vaddps', [AvxOp(YMM15), AvxOp(YMM14), AvxOp(YmmWordPtr(ridR15))], 'C4 41 0C 58 3F');
  CheckAvxHex('vaddps-r15-disp127', 'vaddps', [AvxOp(YMM15), AvxOp(YMM14), AvxOp(YmmWordPtr(ridR15, 127))], 'C4 41 0C 58 7F 7F');
  CheckAvxHex('vaddps-r15-disp128', 'vaddps', [AvxOp(YMM15), AvxOp(YMM14), AvxOp(YmmWordPtr(ridR15, 128))], 'C4 41 0C 58 BF 80 00 00 00');
  CheckAvxHex('vmovaps-xmm15-disp127', 'vmovaps', [AvxOp(XMM15), AvxOp(XmmWordPtr(ridR15, 127))], 'C4 41 78 28 7F 7F');
  CheckAvxHex('vmovaps-store-xmm15-disp128', 'vmovaps', [AvxOp(XmmWordPtr(ridR15, 128)), AvxOp(XMM15)], 'C4 41 78 29 BF 80 00 00 00');
  CheckAvxHex('vmovaps-ymm-sib-minus128', 'vmovaps', [AvxOp(YMM15), AvxOp(YmmWordPtrSib(ridR12, ridR13, s8, -128))], 'C4 01 7C 28 7C EC 80');
  CheckAvxHex('vmovaps-store-ymm-sib129', 'vmovaps', [AvxOp(YmmWordPtrSib(ridR12, ridR13, s8, 129)), AvxOp(YMM15)], 'C4 01 7C 29 BC EC 81 00 00 00');
end;

procedure TAvxBmiEncodingTests.GprScalarAndInsertExtractMatrix;
begin
  CheckAvxHex('vmovd-xmm15-r15d', 'vmovd', [AvxOp(XMM15), AvxOp(R15D)], 'C4 41 79 6E FF');
  CheckAvxHex('vmovd-r15d-xmm15', 'vmovd', [AvxOp(R15D), AvxOp(XMM15)], 'C4 41 79 7E FF');
  CheckAvxHex('vmovq-xmm15-r15', 'vmovq', [AvxOp(XMM15), AvxOp(R15)], 'C4 41 F9 6E FF');
  CheckAvxHex('vmovq-r15-xmm15', 'vmovq', [AvxOp(R15), AvxOp(XMM15)], 'C4 41 F9 7E FF');
  CheckAvxHex('vpinsrb-high', 'vpinsrb', [AvxOp(XMM15), AvxOp(XMM14), AvxOp(R13D), AvxOp(7)], 'C4 43 09 20 FD 07');
  CheckAvxHex('vpextrb-high', 'vpextrb', [AvxOp(R13D), AvxOp(XMM15), AvxOp(7)], 'C4 43 79 14 FD 07');
  CheckAvxHex('vpinsrq-high', 'vpinsrq', [AvxOp(XMM15), AvxOp(XMM14), AvxOp(R13), AvxOp(1)], 'C4 43 89 22 FD 01');
  CheckAvxHex('vpextrq-high', 'vpextrq', [AvxOp(R13), AvxOp(XMM15), AvxOp(1)], 'C4 43 F9 16 FD 01');
  CheckAvxHex('vcvtsi2ss-high-r64', 'vcvtsi2ss', [AvxOp(XMM15), AvxOp(XMM14), AvxOp(R13)], 'C4 41 8A 2A FD');
  CheckAvxHex('vcvttss2si-high-r64', 'vcvttss2si', [AvxOp(R13), AvxOp(XMM15)], 'C4 41 FA 2C EF');
  CheckAvxHex('vmovss-high-merge', 'vmovss', [AvxOp(XMM15), AvxOp(XMM14), AvxOp(XMM13)], 'C4 41 0A 10 FD');
  CheckAvxHex('vmovsd-high-merge', 'vmovsd', [AvxOp(XMM15), AvxOp(XMM14), AvxOp(XMM13)], 'C4 41 0B 10 FD');
  CheckAvxHex('vaddss-basic', 'vaddss', [AvxOp(XMM0), AvxOp(XMM1), AvxOp(XMM2)], 'C5 F2 58 C2');
  CheckAvxHex('vaddsd-high-memory', 'vaddsd', [AvxOp(XMM8), AvxOp(XMM9), AvxOp(TAvxMemory.Create(ridR12, 32, ams64))], 'C4 41 33 58 44 24 20');
  CheckAvxHex('vextractps-high', 'vextractps', [AvxOp(R10D), AvxOp(XMM11), AvxOp(2)], 'C4 43 79 17 DA 02');
  CheckAvxHex('vpinsrw-high', 'vpinsrw', [AvxOp(XMM8), AvxOp(XMM9), AvxOp(R10D), AvxOp(5)], 'C4 41 31 C4 C2 05');
  CheckAvxHex('vpextrw-high', 'vpextrw', [AvxOp(R10D), AvxOp(XMM11), AvxOp(4)], 'C4 41 79 C5 D3 04');
  CheckAvxHex('vmovmskps-ymm-high', 'vmovmskps', [AvxOp(R9D), AvxOp(YMM8)], 'C4 41 7C 50 C8');
  CheckAvxHex('vpmovmskb-ymm-high', 'vpmovmskb', [AvxOp(R9D), AvxOp(YMM8)], 'C4 41 7D D7 C8');
end;

procedure TAvxBmiEncodingTests.MaskedGatherAndSpecialEncodingMatrix;
begin
  CheckAvxHex('vmaskmovps-load', 'vmaskmovps', [AvxOp(XMM8), AvxOp(XMM9), AvxOp(XmmWordPtr(ridR12, 32))], 'C4 42 31 2C 44 24 20');
  CheckAvxHex('vmaskmovps-store', 'vmaskmovps', [AvxOp(XmmWordPtr(ridR12, 32)), AvxOp(XMM9), AvxOp(XMM10)], 'C4 42 31 2E 54 24 20');
  CheckAvxHex('vpmaskmovq-store-ymm-high', 'vpmaskmovq', [AvxOp(YmmWordPtr(ridR13, 64)), AvxOp(YMM15), AvxOp(YMM14)], 'C4 42 85 8E 75 40');
  CheckAvxHex('vpgatherdd-standard', 'vpgatherdd', [AvxOp(YMM0), AvxOp(Vm32y(ridRCX, YMM4, s4, 16)), AvxOp(YMM2)], 'C4 E2 6D 90 44 A1 10');
  CheckAvxHex('vpgatherdd-r13-zero', 'vpgatherdd', [AvxOp(YMM0), AvxOp(Vm32y(ridR13, YMM4, s4, 0)), AvxOp(YMM2)], 'C4 C2 6D 90 44 A5 00');
  CheckAvxHex('vpgatherdd-no-base', 'vpgatherdd', [AvxOp(YMM0), AvxOp(Vm32yNoBase(YMM4, s4, $12345678)), AvxOp(YMM2)], 'C4 E2 6D 90 04 A5 78 56 34 12');
  CheckAvxHex('vpgatherdd-high-all', 'vpgatherdd', [AvxOp(YMM15), AvxOp(Vm32y(ridR12, YMM13, s4, 32)), AvxOp(YMM14)], 'C4 02 0D 90 7C AC 20');
  CheckAvxHex('vgatherdpd-high', 'vgatherdpd', [AvxOp(YMM10), AvxOp(Vm32x(ridR13, XMM14, s8, 64)), AvxOp(YMM11)], 'C4 02 A5 92 54 F5 40');
  CheckAvxHex('vgatherqps-high', 'vgatherqps', [AvxOp(XMM10), AvxOp(Vm64y(ridR13, YMM14, s8, 64)), AvxOp(XMM11)], 'C4 02 25 93 54 F5 40');
  CheckAvxHex('vldmxcsr-unspecified', 'vldmxcsr', [AvxOp(TMemory.Create(ridRCX))], 'C5 F8 AE 11');
  CheckAvxHex('vstmxcsr-r13', 'vstmxcsr', [AvxOp(DWordPtr(ridR13, 16))], 'C4 C1 78 AE 5D 10');
  CheckAvxHex('vpcmpistri-high-memory', 'vpcmpistri', [AvxOp(XMM15), AvxOp(XmmWordPtr(ridR15, 16)), AvxOp($0C)], 'C4 43 79 63 7F 10 0C');
  CheckAvxHex('vmaskmovdqu-high', 'vmaskmovdqu', [AvxOp(XMM8), AvxOp(XMM9)], 'C4 41 79 F7 C1');
end;

procedure TAvxBmiEncodingTests.CompletedVexSpecialFormsMatrix;
begin
  CheckAvxHex('vmovhlps', 'vmovhlps', [AvxOp(XMM0), AvxOp(XMM1), AvxOp(XMM2)], 'C5 F0 12 C2');
  CheckAvxHex('vmovlhps-high', 'vmovlhps', [AvxOp(XMM8), AvxOp(XMM9), AvxOp(XMM10)], 'C4 41 30 16 C2');
  CheckAvxHex('vmovhps-high-memory', 'vmovhps', [AvxOp(XMM15), AvxOp(XMM14), AvxOp(QWordPtr(ridR13, 8))], 'C4 41 08 16 7D 08');
  CheckAvxHex('vmovlpd-high-store', 'vmovlpd', [AvxOp(QWordPtr(ridR13, 16)), AvxOp(XMM15)], 'C4 41 79 13 7D 10');
  CheckAvxHex('vmovntdqa-high', 'vmovntdqa', [AvxOp(YMM15), AvxOp(YmmWordPtr(ridR13, 32))], 'C4 42 7D 2A 7D 20');
  CheckAvxHex('vpcmpestri-reg', 'vpcmpestri', [AvxOp(XMM0), AvxOp(XMM1), AvxOp($08)], 'C4 E3 79 61 C1 08');
  CheckAvxHex('vpcmpestrm-memory', 'vpcmpestrm', [AvxOp(XMM10), AvxOp(XmmWordPtr(ridR13, 48)), AvxOp($18)], 'C4 43 79 60 55 30 18');
  CheckAvxHex('vpcmpistrm-reg', 'vpcmpistrm', [AvxOp(XMM6), AvxOp(XMM7), AvxOp($0C)], 'C4 E3 79 62 F7 0C');
  CheckAvxHex('vmovups-xmm-corrected', 'vmovups', [AvxOp(XMM0), AvxOp(XMM1)], 'C5 F8 10 C1');
  CheckAvxHex('vmovupd-xmm-corrected', 'vmovupd', [AvxOp(XMM0), AvxOp(XMM1)], 'C5 F9 10 C1');
  CheckAvxHex('vpabsd-corrected', 'vpabsd', [AvxOp(XMM0), AvxOp(XMM1)], 'C4 E2 79 1E C1');
  CheckAvxHex('vbroadcastf128-high', 'vbroadcastf128', [AvxOp(YMM8), AvxOp(XmmWordPtr(ridR12, 32))], 'C4 42 7D 1A 44 24 20');
  CheckAvxHex('vextractf128-high', 'vextractf128', [AvxOp(XmmWordPtr(ridR12, 32)), AvxOp(YMM9), AvxOp($1B)], 'C4 43 7D 19 4C 24 20 1B');
  CheckAvxHex('vfmadd231pd', 'vfmadd231pd', [AvxOp(YMM0), AvxOp(YMM1), AvxOp(YMM2)], 'C4 E2 F5 B8 C2');
  CheckAvxHex('vfnmsub213pd-high', 'vfnmsub213pd', [AvxOp(YMM0), AvxOp(YMM8), AvxOp(YMM9)], 'C4 C2 BD AE C1');
end;

procedure TAvxBmiEncodingTests.BmiGoldenMatrix;
begin
  CheckBmiHex('andn-basic', 'andn', [BmiOp(RAX), BmiOp(RCX), BmiOp(RDX)], 'C4 E2 F0 F2 C2');
  CheckBmiHex('andn-high', 'andn', [BmiOp(R15), BmiOp(R14), BmiOp(R13)], 'C4 42 88 F2 FD');
  CheckBmiHex('bextr-sib', 'bextr', [BmiOp(RAX), BmiOp(TMemory.CreateSib(ridR12, ridR13, s4, 64, sz64)), BmiOp(RDX)], 'C4 82 E8 F7 44 AC 40');
  CheckBmiHex('blsi-high', 'blsi', [BmiOp(R8), BmiOp(R9)], 'C4 C2 B8 F3 D9');
  CheckBmiHex('blsmsk-memory', 'blsmsk', [BmiOp(EAX), BmiOp(DWordPtr(ridRCX, 16))], 'C4 E2 78 F3 51 10');
  CheckBmiHex('blsr-high32', 'blsr', [BmiOp(R10D), BmiOp(R11D)], 'C4 C2 28 F3 CB');
  CheckBmiHex('bzhi-basic', 'bzhi', [BmiOp(RAX), BmiOp(RCX), BmiOp(RDX)], 'C4 E2 E8 F5 C1');
  CheckBmiHex('mulx-high', 'mulx', [BmiOp(RAX), BmiOp(RCX), BmiOp(R8)], 'C4 C2 F3 F6 C0');
  CheckBmiHex('pdep-basic', 'pdep', [BmiOp(RAX), BmiOp(RCX), BmiOp(RDX)], 'C4 E2 F3 F5 C2');
  CheckBmiHex('pdep-high', 'pdep', [BmiOp(R15), BmiOp(R14), BmiOp(R13)], 'C4 42 8B F5 FD');
  CheckBmiHex('pext-high', 'pext', [BmiOp(R15), BmiOp(R14), BmiOp(R13)], 'C4 42 8A F5 FD');
  CheckBmiHex('rorx-memory', 'rorx', [BmiOp(RAX), BmiOp(QWordPtr(ridR13, 64)), BmiOp(7)], 'C4 C3 FB F0 45 40 07');
  CheckBmiHex('rorx-high63', 'rorx', [BmiOp(R15), BmiOp(R14), BmiOp(63)], 'C4 43 FB F0 FE 3F');
  CheckBmiHex('sarx-high', 'sarx', [BmiOp(R15), BmiOp(R14), BmiOp(R13)], 'C4 42 92 F7 FE');
  CheckBmiHex('shlx-high', 'shlx', [BmiOp(R15), BmiOp(R14), BmiOp(R13)], 'C4 42 91 F7 FE');
  CheckBmiHex('shrx-high', 'shrx', [BmiOp(R15), BmiOp(R14), BmiOp(R13)], 'C4 42 93 F7 FE');
end;

procedure TAvxBmiEncodingTests.PublicApiCompositionMatrix;
begin
  CheckBuilderHex('public-core-chain', TAsmBuilder.New.Vaddps(YMM0, YMM1, YMM2).Vpaddd(YMM3, YMM4, YMM5).Vzeroupper.Ret,
    'C5 F4 58 C2 C5 DD FE DD C5 F8 77 C3');
  CheckBuilderHex('public-gpr-chain', TAsmBuilder.New.Vmovd(XMM15, R15D).Vmovd(R15D, XMM15).Vmovq(XMM14, R14).Vmovq(R14, XMM14),
    'C4 41 79 6E FF C4 41 79 7E FF C4 41 F9 6E F6 C4 41 F9 7E F6');
  CheckBuilderHex('public-gather-chain', TAsmBuilder.New.Vgatherdps(YMM8, Vm32y(ridR12, YMM13, s4, 32), YMM9).Vpgatherdq(YMM10, Vm32x(ridR13, XMM14, s8, 64), YMM11),
    'C4 02 35 92 44 AC 20 C4 02 A5 90 54 F5 40');
  CheckBuilderHex('public-special-chain', TAsmBuilder.New.Vldmxcsr(TMemory.Create(ridRCX)).Vstmxcsr(DWordPtr(ridR12, 8)).Vblendvps(XMM15, XMM14, XMM13, XMM12).Vpcmpistri(XMM15, XmmWordPtr(ridR15, 16), $0C),
    'C5 F8 AE 11 C4 C1 78 AE 5C 24 08 C4 43 09 4A FD C0 C4 43 79 63 7F 10 0C');
  CheckBuilderHex('public-bmi-chain', TAsmBuilder.New.Andn(R15, R14, R13).Pdep(R15, R14, R13).Rorx(R15, R14, 63),
    'C4 42 88 F2 FD C4 42 8B F5 FD C4 43 FB F0 FE 3F');
  CheckBuilderHex('public-helper-chain', TAsmBuilder.New.Tzcnt(RAX, RCX).Vaddps(YMM0, YMM1, YMM2).Andn(RAX, RAX, RDX).Ret,
    'F3 48 0F BC C1 C5 F4 58 C2 C4 E2 F8 F2 C2 C3');
end;

initialization
  TDUnitX.RegisterTestFixture(TAvxBmiEncodingTests);

end.
