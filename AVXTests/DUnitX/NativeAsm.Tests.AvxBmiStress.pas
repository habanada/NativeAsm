unit NativeAsm.Tests.AvxBmiStress;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TAvxBmiStressTests = class
  public
    [Test] procedure AvxThreeRegisterCrossProduct;
    [Test] procedure AvxMemoryBaseAndDisplacementMatrix;
    [Test] procedure AvxVsibDistinctRegisterMatrix;
    [Test] procedure AvxIs4SelectorMatrix;
    [Test] procedure BmiThreeRegisterCrossProduct;
    [Test] procedure BmiRotateImmediateMatrix;
  end;

implementation

uses
  System.SysUtils,
  NativeAsm.Types,
  NativeAsm.Builder,
  NativeAsm.Simd.Types,
  NativeAsm.Avx.Types,
  NativeAsm.Avx.Encoder,
  NativeAsm.Bmi.Encoder,
  NativeAsm.Tests.SimdSupport;

procedure TAvxBmiStressTests.AvxThreeRegisterCrossProduct;
var
  D, S1, S2: Integer;
  B: TAsmBuilder;
  Code: TBytes;
begin
  B := TAsmBuilder.New;
  try
    for D := 0 to 15 do
      for S1 := 0 to 15 do
        for S2 := 0 to 15 do
        begin
          B.Reset;
          TAvxInstructionEncoder.Encode(B, 'vaddps', [AvxOp(XmmReg(D)), AvxOp(XmmReg(S1)), AvxOp(XmmReg(S2))]);
          Code := B.Build;
          Assert.IsTrue(Length(Code) > 0, Format('VADDPS XMM %d,%d,%d', [D, S1, S2]));
          if S2 < 8 then
            Assert.IsTrue(Code[0] = $C5, Format('VEX2 expected XMM %d,%d,%d', [D, S1, S2]))
          else
            Assert.IsTrue(Code[0] = $C4, Format('VEX3 expected XMM %d,%d,%d', [D, S1, S2]));

          B.Reset;
          TAvxInstructionEncoder.Encode(B, 'vaddps', [AvxOp(YmmReg(D)), AvxOp(YmmReg(S1)), AvxOp(YmmReg(S2))]);
          Code := B.Build;
          Assert.IsTrue(Length(Code) > 0, Format('VADDPS YMM %d,%d,%d', [D, S1, S2]));
          if S2 < 8 then
            Assert.IsTrue(Code[0] = $C5, Format('VEX2 expected YMM %d,%d,%d', [D, S1, S2]))
          else
            Assert.IsTrue(Code[0] = $C4, Format('VEX3 expected YMM %d,%d,%d', [D, S1, S2]));

          B.Reset;
          TAvxInstructionEncoder.Encode(B, 'vpaddd', [AvxOp(XmmReg(D)), AvxOp(XmmReg(S1)), AvxOp(XmmReg(S2))]);
          Assert.IsTrue(B.CodeSize > 0, Format('VPADDD XMM %d,%d,%d', [D, S1, S2]));

          B.Reset;
          TAvxInstructionEncoder.Encode(B, 'vpaddd', [AvxOp(YmmReg(D)), AvxOp(YmmReg(S1)), AvxOp(YmmReg(S2))]);
          Assert.IsTrue(B.CodeSize > 0, Format('VPADDD YMM %d,%d,%d', [D, S1, S2]));
        end;
  finally
    B.Free;
  end;
end;

procedure TAvxBmiStressTests.AvxMemoryBaseAndDisplacementMatrix;
const
  Displacements: array[0..8] of Integer = (-129, -128, -1, 0, 1, 126, 127, 128, $12345678);
var
  BaseID, DestID, IndexID, ScaleID, I: Integer;
  B: TAsmBuilder;
  M: TAvxMemory;
begin
  B := TAsmBuilder.New;
  try
    for BaseID := 0 to 15 do
      for DestID := 0 to 15 do
        for I := Low(Displacements) to High(Displacements) do
        begin
          M := TAvxMemory.Create(TRegID(BaseID), Displacements[I], ams128);
          B.Reset;
          TAvxInstructionEncoder.Encode(B, 'vmovdqu', [AvxOp(XmmReg(DestID)), AvxOp(M)]);
          Assert.IsTrue(B.CodeSize > 0, Format('VMOVDQU XMM base=%d dest=%d disp=%d', [BaseID, DestID, Displacements[I]]));

          M := TAvxMemory.Create(TRegID(BaseID), Displacements[I], ams256);
          B.Reset;
          TAvxInstructionEncoder.Encode(B, 'vmovdqu', [AvxOp(YmmReg(DestID)), AvxOp(M)]);
          Assert.IsTrue(B.CodeSize > 0, Format('VMOVDQU YMM base=%d dest=%d disp=%d', [BaseID, DestID, Displacements[I]]));
        end;

    for BaseID := 0 to 15 do
      for IndexID := 0 to 15 do
        if IndexID <> Ord(ridRSP) then
          for ScaleID := Ord(Low(TScale)) to Ord(High(TScale)) do
          begin
            M := TAvxMemory.CreateSib(TRegID(BaseID), TRegID(IndexID), TScale(ScaleID), 127, ams256);
            B.Reset;
            TAvxInstructionEncoder.Encode(B, 'vmovdqu', [AvxOp(YMM15), AvxOp(M)]);
            Assert.IsTrue(B.CodeSize > 0, Format('VMOVDQU SIB base=%d index=%d scale=%d', [BaseID, IndexID, ScaleID]));
          end;

    for I := Low(Displacements) to High(Displacements) do
    begin
      M := TAvxMemory.CreateRip(Displacements[I], ams128);
      B.Reset;
      TAvxInstructionEncoder.Encode(B, 'vmovdqu', [AvxOp(XMM0), AvxOp(M)]);
      Assert.IsTrue(B.CodeSize > 0, 'VMOVDQU RIP-relative disp=' + IntToStr(Displacements[I]));
    end;
  finally
    B.Free;
  end;
end;

procedure TAvxBmiStressTests.AvxVsibDistinctRegisterMatrix;
var
  DestID, IndexID, MaskID, BaseID, Disp: Integer;
  B: TAsmBuilder;
begin
  B := TAsmBuilder.New;
  try
    for DestID := 0 to 15 do
      for IndexID := 0 to 15 do
        for MaskID := 0 to 15 do
          if (DestID <> IndexID) and (DestID <> MaskID) and (IndexID <> MaskID) then
          begin
            BaseID := (DestID + IndexID + MaskID) and 15;
            case (DestID + IndexID + MaskID) mod 3 of
              0: Disp := 0;
              1: Disp := 127;
            else
              Disp := 128;
            end;
            B.Reset;
            TAvxInstructionEncoder.Encode(B, 'vpgatherdd', [AvxOp(YmmReg(DestID)), AvxOp(Vm32y(TRegID(BaseID), YmmReg(IndexID), s4, Disp)), AvxOp(YmmReg(MaskID))]);
            Assert.IsTrue(B.CodeSize > 0, Format('VPGATHERDD d=%d i=%d m=%d b=%d', [DestID, IndexID, MaskID, BaseID]));
          end;
  finally
    B.Free;
  end;
end;

procedure TAvxBmiStressTests.AvxIs4SelectorMatrix;
var
  DestID, SelectorID: Integer;
  B: TAsmBuilder;
begin
  B := TAsmBuilder.New;
  try
    for DestID := 0 to 15 do
      for SelectorID := 0 to 15 do
      begin
        B.Reset;
        TAvxInstructionEncoder.Encode(B, 'vblendvps', [AvxOp(YmmReg(DestID)), AvxOp(YMM1), AvxOp(YMM2), AvxOp(YmmReg(SelectorID))]);
        Assert.IsTrue(B.CodeSize > 0, Format('VBLENDVPS d=%d selector=%d', [DestID, SelectorID]));

        B.Reset;
        TAvxInstructionEncoder.Encode(B, 'vpblendvb', [AvxOp(XmmReg(DestID)), AvxOp(XMM1), AvxOp(XMM2), AvxOp(XmmReg(SelectorID))]);
        Assert.IsTrue(B.CodeSize > 0, Format('VPBLENDVB d=%d selector=%d', [DestID, SelectorID]));
      end;
  finally
    B.Free;
  end;
end;

procedure TAvxBmiStressTests.BmiThreeRegisterCrossProduct;
var
  D, S1, S2: Integer;
  B: TAsmBuilder;
  Code: TBytes;
begin
  B := TAsmBuilder.New;
  try
    for D := 0 to 15 do
      for S1 := 0 to 15 do
        for S2 := 0 to 15 do
        begin
          B.Reset;
          TBmiInstructionEncoder.Encode(B, 'andn', [BmiOp(Gpr64(D)), BmiOp(Gpr64(S1)), BmiOp(Gpr64(S2))]);
          Code := B.Build;
          Assert.IsTrue((Length(Code) > 0) and (Code[0] = $C4), Format('ANDN %d,%d,%d', [D, S1, S2]));

          B.Reset;
          TBmiInstructionEncoder.Encode(B, 'pdep', [BmiOp(Gpr64(D)), BmiOp(Gpr64(S1)), BmiOp(Gpr64(S2))]);
          Code := B.Build;
          Assert.IsTrue((Length(Code) > 0) and (Code[0] = $C4), Format('PDEP %d,%d,%d', [D, S1, S2]));
        end;
  finally
    B.Free;
  end;
end;

procedure TAvxBmiStressTests.BmiRotateImmediateMatrix;
const
  Immediates: array[0..5] of Integer = (0, 1, 7, 31, 63, 255);
var
  D, S, I: Integer;
  B: TAsmBuilder;
begin
  B := TAsmBuilder.New;
  try
    for D := 0 to 15 do
      for S := 0 to 15 do
        for I := Low(Immediates) to High(Immediates) do
        begin
          B.Reset;
          TBmiInstructionEncoder.Encode(B, 'rorx', [BmiOp(Gpr64(D)), BmiOp(Gpr64(S)), BmiOp(Immediates[I])]);
          Assert.IsTrue(B.CodeSize > 0, Format('RORX d=%d s=%d imm=%d', [D, S, Immediates[I]]));
        end;
  finally
    B.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TAvxBmiStressTests);

end.
