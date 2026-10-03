unit NativeAsm.AvxShowcase.Tests;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TAvxShowcaseTests = class
  public
    [Test] procedure FftImpulseSpectrumIsFlat;
    [Test] procedure FftMatchesScalarDft;
    [Test] procedure FftComplexToneMatchesScalarDft;
    [Test] procedure TransposeMatchesScalar;
    [Test] procedure TransposeRoundTripIsIdentity;
    [Test] procedure MandelbrotMatchesScalarReference;
    [Test] procedure MandelbrotNonMultipleOfEightWidthMatchesScalar;
    [Test] procedure MandelbrotBitmapWriterProducesValid24BitBmp;
    [Test] procedure PolynomialHornerFmaMatchesDoubleReference;
    [Test] procedure PolynomialFmaExactSimpleCases;
    [Test] procedure FloatMinMaxClampSpecialMatrixIsBitExact;
    [Test] procedure FloatNaNAndSignedZeroSemanticsAreExplicit;
    [Test] procedure FaceBitmapRoundTripAndOverlay;
    [Test] procedure FaceAvxStageKernelMatchesScalar;
  end;

implementation

uses
  System.SysUtils,
  System.Math,
  System.IOUtils,
  NativeAsm.AvxShowcase.Types,
  NativeAsm.AvxShowcase.Fft,
  NativeAsm.AvxShowcase.Transpose,
  NativeAsm.AvxShowcase.Mandelbrot,
  NativeAsm.AvxShowcase.Polynomial,
  NativeAsm.AvxShowcase.FloatEdgeCases,
  NativeAsm.AvxShowcase.FaceDetection;

procedure TAvxShowcaseTests.FftImpulseSpectrumIsFlat;
begin
  if not TNativeAsmFft8.IsSupported then
  begin
    Assert.IsTrue(not TNativeAsmFft8.IsSupported);
    Exit;
  end;
  Assert.IsTrue(TNativeAsmFft8.VerifyImpulseFlat, 'FFT impulse spectrum must be flat');
end;

procedure TAvxShowcaseTests.FftMatchesScalarDft;
var
  Input: TComplex8;
  I: Integer;
begin
  if not TNativeAsmFft8.IsSupported then
  begin
    Assert.IsTrue(not TNativeAsmFft8.IsSupported);
    Exit;
  end;
  for I := 0 to 7 do
  begin
    Input[I].Re := Sin((I + 1) * 0.37) + I * 0.125;
    Input[I].Im := Cos((I + 1) * 0.19) - I * 0.0625;
  end;
  Assert.IsTrue(TNativeAsmFft8.VerifyAgainstScalar(Input), 'FFT must match scalar DFT');
end;

procedure TAvxShowcaseTests.FftComplexToneMatchesScalarDft;
var
  Input: TComplex8;
  I: Integer;
  Angle: Double;
begin
  if not TNativeAsmFft8.IsSupported then
  begin
    Assert.IsTrue(not TNativeAsmFft8.IsSupported);
    Exit;
  end;
  for I := 0 to 7 do
  begin
    Angle := 2.0 * Pi * 3.0 * I / 8.0;
    Input[I].Re := Cos(Angle);
    Input[I].Im := Sin(Angle);
  end;
  Assert.IsTrue(TNativeAsmFft8.VerifyAgainstScalar(Input), 'complex tone FFT must match scalar DFT');
end;

procedure TAvxShowcaseTests.TransposeMatchesScalar;
var
  Input: TMatrix8x8;
  Row, Col: Integer;
begin
  if not TNativeAsmTranspose8.IsSupported then
  begin
    Assert.IsTrue(not TNativeAsmTranspose8.IsSupported);
    Exit;
  end;
  for Row := 0 to 7 do
    for Col := 0 to 7 do
      Input[Row, Col] := Row * 100 + Col * 3 + 0.25;
  Assert.IsTrue(TNativeAsmTranspose8.VerifyAgainstScalar(Input), 'AVX transpose must match scalar transpose');
end;

procedure TAvxShowcaseTests.TransposeRoundTripIsIdentity;
var
  Input: TMatrix8x8;
  Row, Col: Integer;
begin
  if not TNativeAsmTranspose8.IsSupported then
  begin
    Assert.IsTrue(not TNativeAsmTranspose8.IsSupported);
    Exit;
  end;
  for Row := 0 to 7 do
    for Col := 0 to 7 do
      Input[Row, Col] := (Row - 4) * 17.0 + (Col - 3) * 0.5;
  Assert.IsTrue(TNativeAsmTranspose8.VerifyRoundTrip(Input), 'transpose round trip must be identity');
end;

procedure TAvxShowcaseTests.MandelbrotMatchesScalarReference;
var
  View: TMandelbrotView;
begin
  if not TNativeAsmMandelbrot.IsSupported then
  begin
    Assert.IsTrue(not TNativeAsmMandelbrot.IsSupported);
    Exit;
  end;
  View := TMandelbrotView.Create(-2.2, 0.8, -1.2, 1.2, 64, 40, 96);
  Assert.IsTrue(TNativeAsmMandelbrot.VerifyAgainstScalar(View), 'Mandelbrot pixels must match scalar reference');
end;

procedure TAvxShowcaseTests.MandelbrotNonMultipleOfEightWidthMatchesScalar;
var
  View: TMandelbrotView;
begin
  if not TNativeAsmMandelbrot.IsSupported then
  begin
    Assert.IsTrue(not TNativeAsmMandelbrot.IsSupported);
    Exit;
  end;
  View := TMandelbrotView.Create(-1.95, 0.55, -0.95, 0.95, 73, 29, 72);
  Assert.IsTrue(TNativeAsmMandelbrot.VerifyAgainstScalar(View), 'Mandelbrot tail pixels must match scalar reference');
end;

procedure TAvxShowcaseTests.MandelbrotBitmapWriterProducesValid24BitBmp;
var
  View: TMandelbrotView;
  Pixels: TMandelbrotPixels;
  FileName: string;
  Data: TBytes;
  Width, Height, FileSize: Cardinal;
begin
  if not TNativeAsmMandelbrot.IsSupported then
  begin
    Assert.IsTrue(not TNativeAsmMandelbrot.IsSupported);
    Exit;
  end;

  View := TMandelbrotView.Create(-2.0, 0.6, -1.0, 1.0, 17, 11, 32);
  TNativeAsmMandelbrot.Render(View, Pixels);
  FileName := TPath.GetTempFileName;
  try
    TNativeAsmMandelbrot.SaveBitmap(View, Pixels, FileName);
    Data := TFile.ReadAllBytes(FileName);
    Assert.IsTrue(Length(Data) >= 54, 'BMP must contain file and info headers');
    Assert.IsTrue((Data[0] = Ord('B')) and (Data[1] = Ord('M')), 'BMP signature must be BM');
    FileSize := Cardinal(Data[2]) or (Cardinal(Data[3]) shl 8) or (Cardinal(Data[4]) shl 16) or (Cardinal(Data[5]) shl 24);
    Width := Cardinal(Data[18]) or (Cardinal(Data[19]) shl 8) or (Cardinal(Data[20]) shl 16) or (Cardinal(Data[21]) shl 24);
    Height := Cardinal(Data[22]) or (Cardinal(Data[23]) shl 8) or (Cardinal(Data[24]) shl 16) or (Cardinal(Data[25]) shl 24);
    Assert.IsTrue(FileSize = Cardinal(Length(Data)), 'BMP header file size must match actual file size');
    Assert.IsTrue(Width = Cardinal(View.Width), 'BMP width must match view');
    Assert.IsTrue(Height = Cardinal(View.Height), 'BMP height must match view');
    Assert.IsTrue((Data[28] = 24) and (Data[29] = 0), 'BMP must be 24-bit');
  finally
    DeleteFile(FileName);
  end;
end;


procedure TAvxShowcaseTests.PolynomialHornerFmaMatchesDoubleReference;
var
  X: TSingle8;
  C: TPolynomial8;
  I: Integer;
begin
  if not TNativeAsmPolynomial.IsSupported then
  begin
    Assert.IsTrue(not TNativeAsmPolynomial.IsSupported);
    Exit;
  end;

  for I := 0 to 7 do X[I] := -1.75 + I * 0.5;
  C[0] := 0.125;
  C[1] := -1.25;
  C[2] := 2.5;
  C[3] := -3.75;
  C[4] := 1.0625;
  C[5] := 0.3125;
  C[6] := -0.03125;
  C[7] := 0.0078125;
  Assert.IsTrue(TNativeAsmPolynomial.Verify(X, C, 2.0E-5), 'FMA Horner polynomial must match Double reference');
  Assert.IsTrue(TNativeAsmPolynomial.MaxRelativeError(X, C) < 2.0E-5, 'FMA Horner relative error must stay bounded');
end;

procedure TAvxShowcaseTests.PolynomialFmaExactSimpleCases;
var
  X, Y: TSingle8;
  C: TPolynomial8;
  I: Integer;
begin
  if not TNativeAsmPolynomial.IsSupported then
  begin
    Assert.IsTrue(not TNativeAsmPolynomial.IsSupported);
    Exit;
  end;

  FillChar(C, SizeOf(C), 0);
  C[0] := 3.0;
  C[1] := 2.0;
  C[2] := 1.0;
  for I := 0 to 7 do X[I] := I - 3;
  TNativeAsmPolynomial.Evaluate(X, C, Y);
  for I := 0 to 7 do
    Assert.IsTrue(Y[I] = X[I] * X[I] + 2.0 * X[I] + 3.0, Format('exact polynomial lane %d', [I]));
end;

procedure TAvxShowcaseTests.FloatMinMaxClampSpecialMatrixIsBitExact;
var
  Failure: string;
begin
  if not TNativeAsmFloatEdgeCases.IsSupported then
  begin
    Assert.IsTrue(not TNativeAsmFloatEdgeCases.IsSupported);
    Exit;
  end;
  Assert.IsTrue(TNativeAsmFloatEdgeCases.VerifySpecialMatrix(Failure), Failure);
end;

procedure TAvxShowcaseTests.FloatNaNAndSignedZeroSemanticsAreExplicit;
var
  Block: TFloatEdgeBlock;
  I: Integer;
begin
  if not TNativeAsmFloatEdgeCases.IsSupported then
  begin
    Assert.IsTrue(not TNativeAsmFloatEdgeCases.IsSupported);
    Exit;
  end;

  FillChar(Block, SizeOf(Block), 0);
  Block.A[0] := SingleFromBits($00000000);
  Block.B[0] := SingleFromBits($80000000);
  Block.A[1] := SingleFromBits($80000000);
  Block.B[1] := SingleFromBits($00000000);
  Block.A[2] := SingleFromBits($7FC12345);
  Block.B[2] := 2.0;
  Block.A[3] := 2.0;
  Block.B[3] := SingleFromBits($7FC54321);
  for I := 0 to 7 do
  begin
    Block.Lo[I] := -1.0;
    Block.Hi[I] := 1.0;
  end;
  TNativeAsmFloatEdgeCases.Evaluate(Block);
  Assert.IsTrue(SingleBits(Block.MinOut[0]) = $80000000, 'VMINPS +0,-0 must return second operand -0');
  Assert.IsTrue(SingleBits(Block.MaxOut[0]) = $80000000, 'VMAXPS +0,-0 must return second operand -0');
  Assert.IsTrue(SingleBits(Block.MinOut[1]) = $00000000, 'VMINPS -0,+0 must return second operand +0');
  Assert.IsTrue(SingleBits(Block.MaxOut[1]) = $00000000, 'VMAXPS -0,+0 must return second operand +0');
  Assert.IsTrue(SingleBits(Block.MinOut[2]) = $40000000, 'NaN in first operand must select second operand');
  Assert.IsTrue(SingleBits(Block.MaxOut[2]) = $40000000, 'NaN in first operand must select second operand');
  Assert.IsTrue(SingleBits(Block.MinOut[3]) = $7FC54321, 'NaN payload in second operand must propagate');
  Assert.IsTrue(SingleBits(Block.MaxOut[3]) = $7FC54321, 'NaN payload in second operand must propagate');
  Assert.IsTrue(Block.UnorderedMask[2] = $FFFFFFFF, 'NaN comparison must be unordered');
  Assert.IsTrue(Block.OrderedMask[2] = 0, 'NaN comparison must not be ordered');
end;

procedure TAvxShowcaseTests.FaceBitmapRoundTripAndOverlay;
var
  Image, Loaded: TBgr24Image;
  Faces: TFaceDetections;
  FileName: string;
  Pixel: TBgr24;
begin
  Image := TBgr24Image.Create(37, 23);
  try
    Image.Clear(12, 34, 56);
    SetLength(Faces, 1);
    Faces[0].Confidence := 99;
    Faces[0].X := 5;
    Faces[0].Y := 4;
    Faces[0].Width := 20;
    Faces[0].Height := 14;
    Faces[0].Landmarks[0] := 10;
    Faces[0].Landmarks[1] := 9;
    Faces[0].Landmarks[2] := 19;
    Faces[0].Landmarks[3] := 9;
    Faces[0].Landmarks[4] := 15;
    Faces[0].Landmarks[5] := 12;
    Faces[0].Landmarks[6] := 11;
    Faces[0].Landmarks[7] := 15;
    Faces[0].Landmarks[8] := 19;
    Faces[0].Landmarks[9] := 15;
    Image.DrawDetections(Faces);
    Pixel := Image.GetPixel(5, 4);
    Assert.IsTrue((Pixel.B = 0) and (Pixel.G = 255) and (Pixel.R = 0), 'face rectangle must be green');

    FileName := TPath.GetTempFileName;
    try
      Image.SaveBmp24(FileName);
      Loaded := TBgr24Image.LoadBmp24(FileName);
      try
        Assert.IsTrue(Loaded.Width = 37, 'round-trip width');
        Assert.IsTrue(Loaded.Height = 23, 'round-trip height');
        Pixel := Loaded.GetPixel(5, 4);
        Assert.IsTrue((Pixel.B = 0) and (Pixel.G = 255) and (Pixel.R = 0), 'overlay pixel must survive BMP round trip');
      finally
        Loaded.Free;
      end;
    finally
      DeleteFile(FileName);
    end;
  finally
    Image.Free;
  end;
end;

procedure TAvxShowcaseTests.FaceAvxStageKernelMatchesScalar;
begin
  if not TNativeAsmFaceDetector.HardwareSupported then
  begin
    Assert.IsTrue(not TNativeAsmFaceDetector.HardwareSupported);
    Exit;
  end;
  Assert.IsTrue(TNativeAsmFaceDetector.VerifyStageKernel, '8-lane AVX HAAR stage kernel must match scalar stage evaluation');
end;

initialization
  TDUnitX.RegisterTestFixture(TAvxShowcaseTests);

end.
