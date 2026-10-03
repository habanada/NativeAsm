program NativeAsmAvxShowcase;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.IOUtils,
  System.Diagnostics,
  NativeAsm.Avx.Cpu,
  NativeAsm.AvxShowcase.Types in 'NativeAsm.AvxShowcase.Types.pas',
  NativeAsm.AvxShowcase.Fft in 'NativeAsm.AvxShowcase.Fft.pas',
  NativeAsm.AvxShowcase.Transpose in 'NativeAsm.AvxShowcase.Transpose.pas',
  NativeAsm.AvxShowcase.Mandelbrot in 'NativeAsm.AvxShowcase.Mandelbrot.pas',
  NativeAsm.AvxShowcase.Polynomial in 'NativeAsm.AvxShowcase.Polynomial.pas',
  NativeAsm.AvxShowcase.FloatEdgeCases in 'NativeAsm.AvxShowcase.FloatEdgeCases.pas',
  NativeAsm.AvxShowcase.FaceDetection in 'NativeAsm.AvxShowcase.FaceDetection.pas';

procedure PrintFft;
var
  Input, Output, Reference: TComplex8;
  I: Integer;
begin
  Writeln('=== FFT8 / FMA ===');
  Writeln('VFMADD231PS VFMSUB231PS VSHUFPS VPERM2F128 VADDPS VSUBPS');
  if not TNativeAsmFft8.IsSupported then
  begin
    Writeln('SKIP: AVX+FMA not usable on this machine');
    Writeln;
    Exit;
  end;

  FillChar(Input, SizeOf(Input), 0);
  Input[0].Re := 1.0;
  TNativeAsmFft8.Execute(Input, Output);
  Writeln('Impulse FFT:');
  for I := 0 to 7 do
    Writeln(Format('  bin %d  %10.6f  %10.6fi', [I, Output[I].Re, Output[I].Im]));
  if not TNativeAsmFft8.VerifyImpulseFlat then raise Exception.Create('FFT impulse verification failed');

  for I := 0 to 7 do
  begin
    Input[I].Re := Sin((I + 1) * 0.37) + I * 0.125;
    Input[I].Im := Cos((I + 1) * 0.19) - I * 0.0625;
  end;
  TNativeAsmFft8.Execute(Input, Output);
  TNativeAsmFft8.ScalarReference(Input, Reference);
  if not TNativeAsmFft8.VerifyAgainstScalar(Input) then raise Exception.Create('FFT scalar verification failed');
  Writeln('Scalar DFT cross-check: PASS');
  Writeln;
end;

procedure PrintTranspose;
var
  Input, Output, RoundTrip: TMatrix8x8;
  Row, Col: Integer;
begin
  Writeln('=== 8x8 Transpose / Cross-Lane ===');
  Writeln('VUNPCKLPS VUNPCKHPS VSHUFPS VPERM2F128 VINSERTF128 VEXTRACTF128');
  if not TNativeAsmTranspose8.IsSupported then
  begin
    Writeln('SKIP: AVX not usable on this machine');
    Writeln;
    Exit;
  end;

  for Row := 0 to 7 do
    for Col := 0 to 7 do
      Input[Row, Col] := Row * 10 + Col;

  TNativeAsmTranspose8.Execute(Input, Output);
  TNativeAsmTranspose8.Execute(Output, RoundTrip);
  if not TNativeAsmTranspose8.VerifyAgainstScalar(Input) then raise Exception.Create('Transpose scalar verification failed');
  if not TNativeAsmTranspose8.VerifyRoundTrip(Input) then raise Exception.Create('Transpose round-trip verification failed');

  Writeln('First three transposed rows:');
  for Row := 0 to 2 do
  begin
    Write('  ');
    for Col := 0 to 7 do Write(Format('%6.0f', [Output[Row, Col]]));
    Writeln;
  end;
  Writeln('Transpose(Transpose(M)) = M: PASS');
  Writeln;
end;

procedure PrintMandelbrot;
var
  VerifyView, BitmapView: TMandelbrotView;
  Pixels: TMandelbrotPixels;
  BitmapPath: string;
  Timer: TStopwatch;
  MegaPixelsPerSecond: Double;
begin
  Writeln('=== Mandelbrot / Compare + Mask ===');
  Writeln('VCMPPS VMOVMSKPS VMULPS VADDPS VBROADCASTSS VANDPS VCVTTPS2DQ');
  if not TNativeAsmMandelbrot.IsSupported then
  begin
    Writeln('SKIP: AVX not usable on this machine');
    Writeln;
    Exit;
  end;

  VerifyView := TMandelbrotView.Create(-2.25, 0.75, -1.15, 1.15, 80, 28, 96);
  if not TNativeAsmMandelbrot.VerifyAgainstScalar(VerifyView) then raise Exception.Create('Mandelbrot scalar verification failed');
  Writeln('Pixel-for-pixel scalar cross-check: PASS');

  BitmapView := TMandelbrotView.Create(-2.2, 0.8, -0.84375, 0.84375, 1920, 1080, 384);
  Writeln(Format('Rendering %dx%d AVX Mandelbrot bitmap...', [BitmapView.Width, BitmapView.Height]));
  Timer := TStopwatch.StartNew;
  TNativeAsmMandelbrot.Render(BitmapView, Pixels);
  Timer.Stop;
  if Timer.ElapsedMilliseconds > 0 then
    MegaPixelsPerSecond := (BitmapView.Width * BitmapView.Height / 1000000.0) / (Timer.ElapsedMilliseconds / 1000.0)
  else
    MegaPixelsPerSecond := 0.0;
  Writeln(Format('AVX render: %d ms  (%.2f Mpixel/s)', [Timer.ElapsedMilliseconds, MegaPixelsPerSecond]));
  BitmapPath := TPath.Combine(ExtractFilePath(ParamStr(0)), 'NativeAsm-Mandelbrot-1920x1080.bmp');
  TNativeAsmMandelbrot.SaveBitmap(BitmapView, Pixels, BitmapPath);
  Writeln('Bitmap: ', BitmapPath);
  Writeln;
end;


procedure PrintPolynomial;
var
  X, Y, Reference: TSingle8;
  C: TPolynomial8;
  I: Integer;
  Error: Double;
begin
  Writeln('=== Polynomial / Horner + FMA ===');
  Writeln('VBROADCASTSS VFMADD213PS VMOVUPS');
  if not TNativeAsmPolynomial.IsSupported then
  begin
    Writeln('SKIP: AVX+FMA not usable on this machine');
    Writeln;
    Exit;
  end;

  X[0] := -2.0;
  X[1] := -1.5;
  X[2] := -1.0;
  X[3] := -0.5;
  X[4] := 0.0;
  X[5] := 0.5;
  X[6] := 1.0;
  X[7] := 2.0;
  C[0] := 1.0;
  C[1] := -2.0;
  C[2] := 0.5;
  C[3] := 3.0;
  C[4] := -1.25;
  C[5] := 0.75;
  C[6] := -0.125;
  C[7] := 0.03125;

  TNativeAsmPolynomial.Evaluate(X, C, Y);
  TNativeAsmPolynomial.ScalarReference(X, C, Reference);
  if not TNativeAsmPolynomial.Verify(X, C) then raise Exception.Create('polynomial scalar verification failed');
  Error := TNativeAsmPolynomial.MaxRelativeError(X, C);
  for I := 0 to 7 do
    Writeln(Format('  x=%7.3f  AVX=%12.6f  ref=%12.6f', [X[I], Y[I], Reference[I]]));
  Writeln(Format('Double-Horner cross-check: PASS  max relative error %.3e', [Error]));
  Writeln;
end;

procedure PrintFloatEdgeCases;
var
  Failure: string;
begin
  Writeln('=== Float edge cases / Min Max Clamp NaN Inf ===');
  Writeln('VMINPS VMAXPS VCMPPS');
  if not TNativeAsmFloatEdgeCases.IsSupported then
  begin
    Writeln('SKIP: AVX not usable on this machine');
    Writeln;
    Exit;
  end;
  if not TNativeAsmFloatEdgeCases.VerifySpecialMatrix(Failure) then
    raise Exception.Create('special-float matrix failed: ' + Failure);
  Writeln('100 pair bit-exact matrix: PASS');
  Writeln('Signed zero, infinity, qNaN payload, ordered/unordered masks: PASS');
  Writeln;
end;

procedure PrintFaceDetection;
var
  InputFile, OutputFile, CascadeFile: string;
  Faces: TFaceDetections;
  Count, I: Integer;
  Timer: TStopwatch;
begin
  Writeln('=== Face Detection / NativeASM AVX HAAR ===');
  Writeln('VCMPPS VANDPS VANDNPS VORPS VADDPS VMOVMSKPS');
  if ParamCount < 1 then
  begin
    Writeln('Optional: NativeAsmAvxShowcase.exe <24-bit-face.bmp> [cascade.xml]');
    Writeln('Default model: ', TNativeAsmFaceDetector.DefaultCascadePath);
    if FileExists(TNativeAsmFaceDetector.DefaultCascadePath) then Writeln('Cascade: READY')
    else Writeln('Cascade: missing; run AVXShowcase\FaceModel\fetch_model.ps1');
    Writeln;
    Exit;
  end;

  if not TNativeAsmFaceDetector.HardwareSupported then
  begin
    Writeln('SKIP: AVX not usable on this machine');
    Writeln;
    Exit;
  end;
  InputFile := ExpandFileName(ParamStr(1));
  if ParamCount >= 2 then CascadeFile := ExpandFileName(ParamStr(2))
  else CascadeFile := TNativeAsmFaceDetector.DefaultCascadePath;
  if not FileExists(InputFile) then raise Exception.CreateFmt('input file not found: %s', [InputFile]);
  if not FileExists(CascadeFile) then raise Exception.CreateFmt('cascade not found: %s', [CascadeFile]);
  if not TNativeAsmFaceDetector.VerifyStageKernel then raise Exception.Create('AVX HAAR stage self-test failed');

  OutputFile := ChangeFileExt(InputFile, '.faces.bmp');
  Timer := TStopwatch.StartNew;
  Count := TNativeAsmFaceDetector.DetectBitmap24(InputFile, CascadeFile, OutputFile, Faces);
  Timer.Stop;
  Writeln(Format('Faces: %d  time: %d ms', [Count, Timer.ElapsedMilliseconds]));
  for I := 0 to High(Faces) do
    Writeln(Format('  #%d box=[%d,%d %dx%d]', [I + 1, Faces[I].X, Faces[I].Y, Faces[I].Width, Faces[I].Height]));
  Writeln('Output: ', OutputFile);
  Writeln;
end;

var
  Status: TAvxCpuStatus;
begin
  try
    Status := TAvxCpuFeatures.Query;
    Writeln('NativeASM AVX Showcase');
    Writeln(Format('AVX=%s AVX2=%s FMA=%s XCR0=$%x', [BoolToStr(Status.AvxUsable, True), BoolToStr(Status.Avx2Usable, True), BoolToStr(Status.FmaUsable, True), Status.Xcr0]));
    Writeln;
    PrintFft;
    PrintTranspose;
    PrintMandelbrot;
    PrintPolynomial;
    PrintFloatEdgeCases;
    PrintFaceDetection;
    Writeln('All supported showcase verifications passed.');
  except
    on E: Exception do
    begin
      Writeln;
      Writeln('ERROR: ', E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
