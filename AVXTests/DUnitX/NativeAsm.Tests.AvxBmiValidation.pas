unit NativeAsm.Tests.AvxBmiValidation;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TAvxBmiValidationTests = class
  public
    [Test] procedure CoreWidthMemoryAndImmediateRejects;
    [Test] procedure GprScalarInsertExtractRejects;
    [Test] procedure MaskedGatherVsibRejects;
    [Test] procedure SpecialFormRejects;
    [Test] procedure CompletedVexRejects;
    [Test] procedure InvalidRegisterAndVsibConstructionRejects;
    [Test] procedure FailedAvxEncodingIsAtomic;
    [Test] procedure BmiRejectMatrixAndAtomicity;
  end;

implementation

uses
  System.SysUtils,
  NativeAsm.Types,
  NativeAsm.Builder,
  NativeAsm.Simd.Types,
  NativeAsm.Avx.Types,
  NativeAsm.Tests.SimdSupport;

procedure TAvxBmiValidationTests.CoreWidthMemoryAndImmediateRejects;
begin
  ExpectAvxReject('mixed vector widths', 'vaddps', [AvxOp(YMM0), AvxOp(XMM1), AvxOp(YMM2)]);
  ExpectAvxReject('wrong memory width', 'vpaddd', [AvxOp(YMM0), AvxOp(YMM1), AvxOp(XmmWordPtr(ridRCX))]);
  ExpectAvxReject('MMX as XMM', 'vaddps', [AvxOp(MM0), AvxOp(XMM1), AvxOp(XMM2)]);
  ExpectAvxReject('imm8 below range', 'vshufps', [AvxOp(YMM0), AvxOp(YMM1), AvxOp(YMM2), AvxOp(-129)]);
  ExpectAvxReject('imm8 above range', 'vshufps', [AvxOp(YMM0), AvxOp(YMM1), AvxOp(YMM2), AvxOp(256)]);
  ExpectAvxReject('shift variable count in YMM', 'vpslld', [AvxOp(YMM0), AvxOp(YMM1), AvxOp(YMM2)]);
  ExpectAvxReject('shift count m256', 'vpslld', [AvxOp(YMM0), AvxOp(YMM1), AvxOp(YmmWordPtr(ridRCX))]);
  ExpectAvxReject('FMA mixed widths', 'vfmadd231ps', [AvxOp(YMM0), AvxOp(XMM1), AvxOp(YMM2)]);
  ExpectAvxReject('FMA wrong memory width', 'vfmadd231pd', [AvxOp(YMM0), AvxOp(YMM1), AvxOp(XmmWordPtr(ridRCX))]);
  ExpectAvxReject('VFMSUB mixed widths', 'vfmsub231ps', [AvxOp(YMM0), AvxOp(XMM1), AvxOp(YMM2)]);
  ExpectAvxReject('VFNMADD wrong memory width', 'vfnmadd231pd', [AvxOp(YMM0), AvxOp(YMM1), AvxOp(XmmWordPtr(ridRCX))]);
  ExpectAvxReject('VFNMSUB mixed widths', 'vfnmsub231ps', [AvxOp(XMM0), AvxOp(YMM1), AvxOp(XMM2)]);
  ExpectAvxReject('vextracti128 YMM destination', 'vextracti128', [AvxOp(YMM0), AvxOp(YMM1), AvxOp(1)]);
  ExpectAvxReject('vpermq XMM destination', 'vpermq', [AvxOp(XMM0), AvxOp(XMM1), AvxOp($1B)]);
  ExpectAvxReject('vpsllvq mixed widths', 'vpsllvq', [AvxOp(YMM0), AvxOp(YMM1), AvxOp(XMM2)]);
  ExpectAvxReject('vbroadcasti128 m256', 'vbroadcasti128', [AvxOp(YMM0), AvxOp(YmmWordPtr(ridRCX))]);
  ExpectAvxReject('vbroadcastf128 m256', 'vbroadcastf128', [AvxOp(YMM0), AvxOp(YmmWordPtr(ridRCX))]);
  ExpectAvxReject('vextractf128 YMM destination', 'vextractf128', [AvxOp(YMM0), AvxOp(YMM1), AvxOp(1)]);
  ExpectAvxReject('vpalignr imm above range', 'vpalignr', [AvxOp(YMM0), AvxOp(YMM1), AvxOp(YMM2), AvxOp(256)]);
  ExpectAvxReject('FMA addsub mixed widths', 'vfmaddsub231ps', [AvxOp(YMM0), AvxOp(XMM1), AvxOp(YMM2)]);
end;

procedure TAvxBmiValidationTests.GprScalarInsertExtractRejects;
begin
  ExpectAvxReject('vaddss m64', 'vaddss', [AvxOp(XMM0), AvxOp(XMM1), AvxOp(QWordPtr(ridRCX))]);
  ExpectAvxReject('vaddsd YMM destination', 'vaddsd', [AvxOp(YMM0), AvxOp(XMM1), AvxOp(XMM2)]);
  ExpectAvxReject('vbroadcastss m64', 'vbroadcastss', [AvxOp(YMM0), AvxOp(QWordPtr(ridRCX))]);
  ExpectAvxReject('vpmovsxbq ymm m64', 'vpmovsxbq', [AvxOp(YMM0), AvxOp(QWordPtr(ridRCX))]);
  ExpectAvxReject('scalar FMA YMM destination', 'vfmadd132ss', [AvxOp(YMM0), AvxOp(XMM1), AvxOp(XMM2)]);
  ExpectAvxReject('vmovd r64 destination', 'vmovd', [AvxOp(RAX), AvxOp(XMM0)]);
  ExpectAvxReject('vmovq r32 source', 'vmovq', [AvxOp(XMM0), AvxOp(EAX)]);
  ExpectAvxReject('vmovd m64 source', 'vmovd', [AvxOp(XMM0), AvxOp(QWordPtr(ridRCX))]);
  ExpectAvxReject('vpinsrb r64 source', 'vpinsrb', [AvxOp(XMM0), AvxOp(XMM1), AvxOp(RAX), AvxOp(0)]);
  ExpectAvxReject('vpinsrq r32 source', 'vpinsrq', [AvxOp(XMM0), AvxOp(XMM1), AvxOp(EAX), AvxOp(0)]);
  ExpectAvxReject('vpextrd r64 destination', 'vpextrd', [AvxOp(RAX), AvxOp(XMM0), AvxOp(0)]);
  ExpectAvxReject('vpextrq m32 destination', 'vpextrq', [AvxOp(DWordPtr(ridRCX)), AvxOp(XMM0), AvxOp(0)]);
  ExpectAvxReject('vpinsrd YMM destination', 'vpinsrd', [AvxOp(YMM0), AvxOp(XMM1), AvxOp(EAX), AvxOp(0)]);
  ExpectAvxReject('vextractps m64 destination', 'vextractps', [AvxOp(QWordPtr(ridRCX)), AvxOp(XMM0), AvxOp(0)]);
  ExpectAvxReject('vpinsrw r64 source', 'vpinsrw', [AvxOp(XMM0), AvxOp(XMM1), AvxOp(RAX), AvxOp(0)]);
  ExpectAvxReject('vpextrw m32 destination', 'vpextrw', [AvxOp(DWordPtr(ridRCX)), AvxOp(XMM0), AvxOp(0)]);
  ExpectAvxReject('vmovmskps memory source', 'vmovmskps', [AvxOp(EAX), AvxOp(XmmWordPtr(ridRCX))]);
  ExpectAvxReject('vpmovmskb memory source', 'vpmovmskb', [AvxOp(EAX), AvxOp(XmmWordPtr(ridRCX))]);
  ExpectAvxReject('vcvtsi2ss m16', 'vcvtsi2ss', [AvxOp(XMM0), AvxOp(XMM1), AvxOp(WordPtr(ridRCX))]);
  ExpectAvxReject('vcvtss2si m64', 'vcvtss2si', [AvxOp(RAX), AvxOp(QWordPtr(ridRCX))]);
  ExpectAvxReject('vcvtsd2si m32', 'vcvtsd2si', [AvxOp(EAX), AvxOp(DWordPtr(ridRCX))]);
end;

procedure TAvxBmiValidationTests.MaskedGatherVsibRejects;
begin
  ExpectAvxReject('vmaskmovps mismatched mask', 'vmaskmovps', [AvxOp(YMM0), AvxOp(XMM1), AvxOp(YmmWordPtr(ridRCX))]);
  ExpectAvxReject('vmaskmovpd wrong memory', 'vmaskmovpd', [AvxOp(YMM0), AvxOp(YMM1), AvxOp(XmmWordPtr(ridRCX))]);
  ExpectAvxReject('vpmaskmovd mismatched data', 'vpmaskmovd', [AvxOp(YmmWordPtr(ridRCX)), AvxOp(YMM1), AvxOp(XMM2)]);
  ExpectAvxReject('vpmaskmovq wrong memory', 'vpmaskmovq', [AvxOp(XMM0), AvxOp(XMM1), AvxOp(YmmWordPtr(ridRCX))]);
  ExpectAvxReject('gather regular memory', 'vpgatherdd', [AvxOp(YMM0), AvxOp(YmmWordPtr(ridRCX)), AvxOp(YMM2)]);
  ExpectAvxReject('gather wrong index vector width', 'vpgatherdd', [AvxOp(YMM0), AvxOp(Vm32x(ridRCX, XMM1, s4)), AvxOp(YMM2)]);
  ExpectAvxReject('gather wrong index element width', 'vpgatherdd', [AvxOp(YMM0), AvxOp(Vm64y(ridRCX, YMM1, s4)), AvxOp(YMM2)]);
  ExpectAvxReject('gather destination index alias', 'vpgatherdd', [AvxOp(YMM1), AvxOp(Vm32y(ridRCX, YMM1, s4)), AvxOp(YMM2)]);
  ExpectAvxReject('gather destination mask alias', 'vpgatherdd', [AvxOp(YMM0), AvxOp(Vm32y(ridRCX, YMM1, s4)), AvxOp(YMM0)]);
  ExpectAvxReject('gather mask index alias', 'vpgatherdd', [AvxOp(YMM0), AvxOp(Vm32y(ridRCX, YMM1, s4)), AvxOp(YMM1)]);
end;

procedure TAvxBmiValidationTests.SpecialFormRejects;
begin
  ExpectAvxReject('vmovhlps YMM destination', 'vmovhlps', [AvxOp(YMM0), AvxOp(XMM1), AvxOp(XMM2)]);
  ExpectAvxReject('vmovhpd m32 load', 'vmovhpd', [AvxOp(XMM0), AvxOp(XMM1), AvxOp(DWordPtr(ridRCX))]);
  ExpectAvxReject('vmovlps m128 store', 'vmovlps', [AvxOp(XmmWordPtr(ridRCX)), AvxOp(XMM0)]);
  ExpectAvxReject('vmovntdqa register source', 'vmovntdqa', [AvxOp(XMM0), AvxOp(XMM1)]);
  ExpectAvxReject('vmovntdqa XMM m256', 'vmovntdqa', [AvxOp(XMM0), AvxOp(YmmWordPtr(ridRCX))]);
  ExpectAvxReject('vmovss YMM destination', 'vmovss', [AvxOp(YMM0), AvxOp(XMM1), AvxOp(XMM2)]);
  ExpectAvxReject('vmovsd m32 load', 'vmovsd', [AvxOp(XMM0), AvxOp(DWordPtr(ridRCX))]);
  ExpectAvxReject('vmovss m64 store', 'vmovss', [AvxOp(QWordPtr(ridRCX)), AvxOp(XMM0)]);
  ExpectAvxReject('vmovsd two registers', 'vmovsd', [AvxOp(XMM0), AvxOp(XMM1)]);
  ExpectAvxReject('vldmxcsr register', 'vldmxcsr', [AvxOp(XMM0)]);
  ExpectAvxReject('vstmxcsr m64', 'vstmxcsr', [AvxOp(QWordPtr(ridRCX))]);
  ExpectAvxReject('vldmxcsr VSIB', 'vldmxcsr', [AvxOp(Vm32x(ridRCX, XMM1))]);
  ExpectAvxReject('vblendvps mixed data width', 'vblendvps', [AvxOp(YMM0), AvxOp(YMM1), AvxOp(XMM2), AvxOp(YMM3)]);
  ExpectAvxReject('vblendvpd wrong memory', 'vblendvpd', [AvxOp(YMM0), AvxOp(YMM1), AvxOp(XmmWordPtr(ridRCX)), AvxOp(YMM3)]);
  ExpectAvxReject('vblendvps GPR selector', 'vblendvps', [AvxOp(XMM0), AvxOp(XMM1), AvxOp(XMM2), AvxOp(EAX)]);
  ExpectAvxReject('vpblendvb selector width', 'vpblendvb', [AvxOp(YMM0), AvxOp(YMM1), AvxOp(YMM2), AvxOp(XMM3)]);
end;

procedure TAvxBmiValidationTests.CompletedVexRejects;
begin
  ExpectAvxReject('vpcmpestri YMM first', 'vpcmpestri', [AvxOp(YMM0), AvxOp(XMM1), AvxOp($08)]);
  ExpectAvxReject('vpcmpestrm m256', 'vpcmpestrm', [AvxOp(XMM0), AvxOp(YmmWordPtr(ridRCX)), AvxOp($08)]);
  ExpectAvxReject('vpcmpistri imm above range', 'vpcmpistri', [AvxOp(XMM0), AvxOp(XMM1), AvxOp(256)]);
  ExpectAvxReject('explicit PCMP implicit operands', 'vpcmpestri', [AvxOp(XMM0), AvxOp(XMM1), AvxOp($08), AvxOp(EAX), AvxOp(EDX)]);
  ExpectAvxReject('vmovups m64', 'vmovups', [AvxOp(XMM0), AvxOp(QWordPtr(ridRCX))]);
  ExpectAvxReject('vmovupd YMM m128', 'vmovupd', [AvxOp(YMM0), AvxOp(XmmWordPtr(ridRCX))]);
  ExpectAvxReject('vpabsd XMM m256', 'vpabsd', [AvxOp(XMM0), AvxOp(YmmWordPtr(ridRCX))]);
  ExpectAvxReject('vmaskmovdqu YMM', 'vmaskmovdqu', [AvxOp(YMM0), AvxOp(YMM1)]);
  ExpectAvxReject('vmaskmovdqu explicit memory', 'vmaskmovdqu', [AvxOp(XMM0), AvxOp(XMM1), AvxOp(XmmWordPtr(ridRDI))]);
  ExpectAvxReject('unknown mnemonic', 'vdefinitelynotreal', [AvxOp(XMM0)]);
  ExpectAvxReject('wrong operand count', 'vaddps', [AvxOp(XMM0), AvxOp(XMM1)]);
end;

procedure TAvxBmiValidationTests.InvalidRegisterAndVsibConstructionRejects;
var
  BadXmm: TSimdRegister;
  BadYmm: TAvxYmmRegister;
  Raised: Boolean;
begin
  BadXmm := XmmReg(16);
  BadYmm := YmmReg(16);
  ExpectAvxReject('invalid XMM id', 'vaddps', [AvxOp(BadXmm), AvxOp(XMM1), AvxOp(XMM2)]);
  ExpectAvxReject('invalid YMM id', 'vaddps', [AvxOp(BadYmm), AvxOp(YMM1), AvxOp(YMM2)]);
  Raised := False;
  try TAvxMemory.CreateVsib(ridRIP, XMM1, s4, 0, ams32); except on E: EArgumentException do Raised := True; end;
  Assert.IsTrue(Raised);
  Raised := False;
  try TAvxMemory.CreateVsib(ridRCX, BadXmm, s4, 0, ams32); except on E: EArgumentException do Raised := True; end;
  Assert.IsTrue(Raised);
  Raised := False;
  try TAvxMemory.CreateVsib(ridRCX, BadYmm, s4, 0, ams32); except on E: EArgumentException do Raised := True; end;
  Assert.IsTrue(Raised);
  Raised := False;
  try TAvxMemory.CreateVsib(ridRCX, XMM1, s4, 0, ams128); except on E: EArgumentException do Raised := True; end;
  Assert.IsTrue(Raised);
end;

procedure TAvxBmiValidationTests.FailedAvxEncodingIsAtomic;
begin
  ExpectAvxAtomicReject('atomic width reject', 'vaddps', [AvxOp(YMM0), AvxOp(XMM1), AvxOp(YMM2)]);
  ExpectAvxAtomicReject('atomic immediate reject', 'vshufps', [AvxOp(XMM0), AvxOp(XMM1), AvxOp(XMM2), AvxOp(256)]);
  ExpectAvxAtomicReject('atomic gather alias reject', 'vpgatherdd', [AvxOp(YMM0), AvxOp(Vm32y(ridRCX, YMM1, s4)), AvxOp(YMM1)]);
  ExpectAvxAtomicReject('atomic implicit memory reject', 'vmaskmovdqu', [AvxOp(XMM0), AvxOp(XMM1), AvxOp(XmmWordPtr(ridRDI))]);
  ExpectAvxAtomicReject('atomic unknown mnemonic', 'vnotreal', [AvxOp(XMM0)]);
end;

procedure TAvxBmiValidationTests.BmiRejectMatrixAndAtomicity;
begin
  ExpectBmiReject('BMI mixed widths', 'andn', [BmiOp(RAX), BmiOp(ECX), BmiOp(RDX)]);
  ExpectBmiReject('BMI wrong memory width', 'andn', [BmiOp(RAX), BmiOp(RCX), BmiOp(DWordPtr(ridRDX))]);
  ExpectBmiReject('BMI 16 bit', 'blsi', [BmiOp(AX), BmiOp(CX)]);
  ExpectBmiReject('BMI imm below range', 'rorx', [BmiOp(RAX), BmiOp(RCX), BmiOp(-129)]);
  ExpectBmiReject('BMI imm above range', 'rorx', [BmiOp(RAX), BmiOp(RCX), BmiOp(256)]);
  ExpectBmiReject('MULX mixed widths', 'mulx', [BmiOp(RAX), BmiOp(ECX), BmiOp(R8)]);
  ExpectBmiReject('BMI unknown mnemonic', 'notbmi', [BmiOp(RAX)]);
  ExpectBmiAtomicReject('BMI atomic mixed widths', 'andn', [BmiOp(RAX), BmiOp(ECX), BmiOp(RDX)]);
  ExpectBmiAtomicReject('BMI atomic immediate', 'rorx', [BmiOp(RAX), BmiOp(RCX), BmiOp(256)]);
  ExpectBmiAtomicReject('BMI atomic unknown', 'notbmi', [BmiOp(RAX)]);
end;

initialization
  TDUnitX.RegisterTestFixture(TAvxBmiValidationTests);

end.
