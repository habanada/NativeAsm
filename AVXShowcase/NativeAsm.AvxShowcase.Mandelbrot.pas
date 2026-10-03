unit NativeAsm.AvxShowcase.Mandelbrot;

interface

uses
  NativeAsm.Extensions,
  NativeAsm.AvxShowcase.Types;

type
  TNativeAsmMandelbrot = class sealed
  private
    class function Kernel: TExecutableCode; static;
  public
    class function IsSupported: Boolean; static;
    class procedure Render(const View: TMandelbrotView; out Pixels: TMandelbrotPixels); static;
    class procedure ScalarReference(const View: TMandelbrotView; out Pixels: TMandelbrotPixels); static;
    class function VerifyAgainstScalar(const View: TMandelbrotView): Boolean; static;
    class procedure SaveBitmap(const View: TMandelbrotView; const Pixels: TMandelbrotPixels; const FileName: string); static;
    class function ToAscii(const View: TMandelbrotView; const Pixels: TMandelbrotPixels): string; static;
  end;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.Math,
  NativeAsm.Types,
  NativeAsm.Builder,
  NativeAsm.Simd.Types,
  NativeAsm.Avx.Types,
  NativeAsm.Avx.Cpu,
  NativeAsm.Avx;


type
  TBmpFileHeader = packed record
    Signature: Word;
    FileSize: Cardinal;
    Reserved1: Word;
    Reserved2: Word;
    PixelOffset: Cardinal;
  end;

  TBmpInfoHeader = packed record
    HeaderSize: Cardinal;
    Width: LongInt;
    Height: LongInt;
    Planes: Word;
    BitsPerPixel: Word;
    Compression: Cardinal;
    ImageSize: Cardinal;
    XPelsPerMeter: LongInt;
    YPelsPerMeter: LongInt;
    ColorsUsed: Cardinal;
    ColorsImportant: Cardinal;
  end;

type
  TMandelbrotBlock = packed record
    CX: TSingle8;
    CY: Single;
    Four: Single;
    Two: Single;
    One: Single;
    MaxIterations: Cardinal;
    Output: TCardinal8;
  end;

const
  OFS_CX = 0;
  OFS_CY = 32;
  OFS_FOUR = 36;
  OFS_TWO = 40;
  OFS_ONE = 44;
  OFS_MAXITER = 48;
  OFS_OUTPUT = 52;
  CAsciiRamp = ' .:-=+*#%@';

var
  GMandelbrotKernel: TExecutableCode;

function BuildMandelbrotKernel: TExecutableCode;
var
  B: TAsmBuilder;
  LLoop, LDone: TLabel;
begin
  B := TAsmBuilder.New;
  try
    LLoop := B.NewLabel;
    LDone := B.NewLabel;
    B.Sub(RSP, 128);
    B.Vmovdqu(XmmWordPtr(ridRSP, 0), XMM6);
    B.Vmovdqu(XmmWordPtr(ridRSP, 16), XMM7);
    B.Vmovdqu(XmmWordPtr(ridRSP, 32), XMM8);
    B.Vmovdqu(XmmWordPtr(ridRSP, 48), XMM9);
    B.Vmovdqu(XmmWordPtr(ridRSP, 64), XMM10);
    B.Vmovdqu(XmmWordPtr(ridRSP, 80), XMM11);
    B.Vmovdqu(XmmWordPtr(ridRSP, 96), XMM12);
    B.Vmovdqu(XmmWordPtr(ridRSP, 112), XMM13);
    B.Vmovups(YMM0, YmmWordPtr(ridRCX, OFS_CX));
    B.Vbroadcastss(YMM1, DWordPtr(ridRCX, OFS_CY));
    B.Vbroadcastss(YMM5, DWordPtr(ridRCX, OFS_FOUR));
    B.Vbroadcastss(YMM6, DWordPtr(ridRCX, OFS_TWO));
    B.Vbroadcastss(YMM7, DWordPtr(ridRCX, OFS_ONE));
    B.Vxorps(YMM2, YMM2, YMM2);
    B.Vxorps(YMM3, YMM3, YMM3);
    B.Vxorps(YMM4, YMM4, YMM4);
    B.Vcmpps(YMM13, YMM2, YMM2, $00);
    B.Mov(R10D, DWordPtr(ridRCX, OFS_MAXITER));
    B.Xor_(R11D, R11D);
    B.Bind(LLoop);
    B.Vmulps(YMM8, YMM2, YMM2);
    B.Vmulps(YMM9, YMM3, YMM3);
    B.Vmulps(YMM10, YMM2, YMM3);
    B.Vmulps(YMM10, YMM10, YMM6);
    B.Vaddps(YMM10, YMM10, YMM1);
    B.Vsubps(YMM11, YMM8, YMM9);
    B.Vaddps(YMM11, YMM11, YMM0);
    B.Vmulps(YMM12, YMM11, YMM11);
    B.Vmulps(YMM8, YMM10, YMM10);
    B.Vaddps(YMM12, YMM12, YMM8);
    B.Vcmpps(YMM12, YMM12, YMM5, $02);
    B.Vandps(YMM13, YMM13, YMM12);
    B.Vandps(YMM12, YMM13, YMM7);
    B.Vaddps(YMM4, YMM4, YMM12);
    B.Vmovaps(YMM2, YMM11);
    B.Vmovaps(YMM3, YMM10);
    B.Vmovmskps(EAX, YMM13);
    B.Test(EAX, EAX).J(cond_JE, LDone);
    B.Inc_(R11D).Cmp(R11D, R10D).J(cond_JB, LLoop);
    B.Bind(LDone);
    B.Vcvttps2dq(YMM4, YMM4);
    B.Vmovdqu(YmmWordPtr(ridRCX, OFS_OUTPUT), YMM4);
    B.Vmovdqu(XMM6, XmmWordPtr(ridRSP, 0));
    B.Vmovdqu(XMM7, XmmWordPtr(ridRSP, 16));
    B.Vmovdqu(XMM8, XmmWordPtr(ridRSP, 32));
    B.Vmovdqu(XMM9, XmmWordPtr(ridRSP, 48));
    B.Vmovdqu(XMM10, XmmWordPtr(ridRSP, 64));
    B.Vmovdqu(XMM11, XmmWordPtr(ridRSP, 80));
    B.Vmovdqu(XMM12, XmmWordPtr(ridRSP, 96));
    B.Vmovdqu(XMM13, XmmWordPtr(ridRSP, 112));
    B.Add(RSP, 128);
    B.Vzeroupper.Ret;
    Result := TExecutableCode.Create(B.Build);
  finally
    B.Free;
  end;
end;

class function TNativeAsmMandelbrot.Kernel: TExecutableCode;
begin
  if GMandelbrotKernel = nil then GMandelbrotKernel := BuildMandelbrotKernel;
  Result := GMandelbrotKernel;
end;

class function TNativeAsmMandelbrot.IsSupported: Boolean;
begin
  Result := TAvxCpuFeatures.SupportsAvx;
end;

class procedure TNativeAsmMandelbrot.Render(const View: TMandelbrotView; out Pixels: TMandelbrotPixels);
var
  Block: TMandelbrotBlock;
  Exe: TExecutableCode;
  X, Y, Lane, PixelIndex: Integer;
  StepX, StepY, CY: Single;
begin
  if not IsSupported then raise ENotSupportedException.Create('Mandelbrot showcase requires AVX');
  SetLength(Pixels, View.Width * View.Height);
  StepX := (View.MaxX - View.MinX) / View.Width;
  StepY := (View.MaxY - View.MinY) / View.Height;
  Exe := Kernel;

  for Y := 0 to View.Height - 1 do
  begin
    CY := View.MinY + (Y + 0.5) * StepY;
    X := 0;
    while X < View.Width do
    begin
      FillChar(Block, SizeOf(Block), 0);
      Block.CY := CY;
      Block.Four := 4.0;
      Block.Two := 2.0;
      Block.One := 1.0;
      Block.MaxIterations := View.MaxIterations;
      for Lane := 0 to 7 do
        Block.CX[Lane] := View.MinX + (X + Lane + 0.5) * StepX;
      Exe.Run(UInt64(NativeUInt(@Block)));
      for Lane := 0 to 7 do
      begin
        if X + Lane >= View.Width then Break;
        PixelIndex := Y * View.Width + X + Lane;
        Pixels[PixelIndex] := Block.Output[Lane];
      end;
      Inc(X, 8);
    end;
  end;
end;

class procedure TNativeAsmMandelbrot.ScalarReference(const View: TMandelbrotView; out Pixels: TMandelbrotPixels);
var
  X, Y, PixelIndex: Integer;
  Iter: Cardinal;
  StepX, StepY, CX, CY, ZX, ZY, ZX2, ZY2, NewX, NewY, Product, MagX, MagY, Mag: Single;
begin
  SetLength(Pixels, View.Width * View.Height);
  StepX := (View.MaxX - View.MinX) / View.Width;
  StepY := (View.MaxY - View.MinY) / View.Height;
  for Y := 0 to View.Height - 1 do
  begin
    CY := View.MinY + (Y + 0.5) * StepY;
    for X := 0 to View.Width - 1 do
    begin
      CX := View.MinX + (X + 0.5) * StepX;
      ZX := 0.0;
      ZY := 0.0;
      Iter := 0;
      while Iter < View.MaxIterations do
      begin
        ZX2 := ZX * ZX;
        ZY2 := ZY * ZY;
        Product := ZX * ZY;
        Product := Product * 2.0;
        NewY := Product + CY;
        NewX := ZX2 - ZY2;
        NewX := NewX + CX;
        MagX := NewX * NewX;
        MagY := NewY * NewY;
        Mag := MagX + MagY;
        ZX := NewX;
        ZY := NewY;
        if not (Mag <= 4.0) then Break;
        Inc(Iter);
      end;
      PixelIndex := Y * View.Width + X;
      Pixels[PixelIndex] := Iter;
    end;
  end;
end;

class function TNativeAsmMandelbrot.VerifyAgainstScalar(const View: TMandelbrotView): Boolean;
var
  Actual, Expected: TMandelbrotPixels;
  I: Integer;
begin
  Render(View, Actual);
  ScalarReference(View, Expected);
  if Length(Actual) <> Length(Expected) then Exit(False);
  Result := True;
  for I := 0 to High(Actual) do
    if Actual[I] <> Expected[I] then Exit(False);
end;

class procedure TNativeAsmMandelbrot.SaveBitmap(const View: TMandelbrotView; const Pixels: TMandelbrotPixels; const FileName: string);
var
  FileHeader: TBmpFileHeader;
  InfoHeader: TBmpInfoHeader;
  Stream: TFileStream;
  Row: TBytes;
  RowStride, X, Y, Offset, Shade, Segment: Integer;
  V: Cardinal;
  R, G, B: Byte;
  Dir: string;

  procedure ColorForIteration(AIteration: Cardinal; out AR, AG, AB: Byte);
  begin
    if AIteration >= View.MaxIterations then
    begin
      AR := 0;
      AG := 0;
      AB := 0;
      Exit;
    end;

    if AIteration = 0 then Shade := 0
    else Shade := Round(255.0 * Ln(AIteration + 1.0) / Ln(View.MaxIterations + 1.0));

    if Shade < 64 then
    begin
      AR := Byte(2 + Shade div 4);
      AG := Byte(8 + Shade);
      AB := Byte(32 + Shade * 3);
    end
    else if Shade < 128 then
    begin
      Segment := Shade - 64;
      AR := 18;
      AG := Byte(72 + Segment * 2);
      AB := Byte(220 + Segment div 2);
    end
    else if Shade < 192 then
    begin
      Segment := Shade - 128;
      AR := Byte(20 + Segment * 3);
      AG := Byte(200 - Segment);
      AB := Byte(240 - Segment * 3);
    end
    else
    begin
      Segment := Shade - 192;
      AR := Byte(210 + Segment * 45 div 63);
      AG := Byte(137 + Segment * 108 div 63);
      AB := Byte(50 + Segment * 150 div 63);
    end;
  end;

begin
  if Length(Pixels) <> View.Width * View.Height then raise EArgumentException.Create('pixel count does not match view');
  if FileName = '' then raise EArgumentException.Create('file name must not be empty');

  RowStride := ((View.Width * 3 + 3) div 4) * 4;
  FillChar(FileHeader, SizeOf(FileHeader), 0);
  FillChar(InfoHeader, SizeOf(InfoHeader), 0);

  FileHeader.Signature := $4D42;
  FileHeader.PixelOffset := SizeOf(FileHeader) + SizeOf(InfoHeader);
  FileHeader.FileSize := FileHeader.PixelOffset + Cardinal(RowStride * View.Height);

  InfoHeader.HeaderSize := SizeOf(InfoHeader);
  InfoHeader.Width := View.Width;
  InfoHeader.Height := View.Height;
  InfoHeader.Planes := 1;
  InfoHeader.BitsPerPixel := 24;
  InfoHeader.Compression := 0;
  InfoHeader.ImageSize := Cardinal(RowStride * View.Height);
  InfoHeader.XPelsPerMeter := 3780;
  InfoHeader.YPelsPerMeter := 3780;

  Dir := ExtractFileDir(FileName);
  if Dir <> '' then ForceDirectories(Dir);
  Stream := TFileStream.Create(FileName, fmCreate);
  try
    Stream.WriteBuffer(FileHeader, SizeOf(FileHeader));
    Stream.WriteBuffer(InfoHeader, SizeOf(InfoHeader));
    SetLength(Row, RowStride);
    for Y := 0 to View.Height - 1 do
    begin
      FillChar(Row[0], RowStride, 0);
      for X := 0 to View.Width - 1 do
      begin
        V := Pixels[Y * View.Width + X];
        ColorForIteration(V, R, G, B);
        Offset := X * 3;
        Row[Offset] := B;
        Row[Offset + 1] := G;
        Row[Offset + 2] := R;
      end;
      Stream.WriteBuffer(Row[0], RowStride);
    end;
  finally
    Stream.Free;
  end;
end;

class function TNativeAsmMandelbrot.ToAscii(const View: TMandelbrotView; const Pixels: TMandelbrotPixels): string;
var
  S: TStringBuilder;
  X, Y, Index, RampIndex: Integer;
  V: Cardinal;
begin
  if Length(Pixels) <> View.Width * View.Height then raise EArgumentException.Create('pixel count does not match view');
  S := TStringBuilder.Create(View.Height * (View.Width + 2));
  try
    for Y := 0 to View.Height - 1 do
    begin
      for X := 0 to View.Width - 1 do
      begin
        Index := Y * View.Width + X;
        V := Pixels[Index];
        if V >= View.MaxIterations then RampIndex := Length(CAsciiRamp)
        else RampIndex := 1 + Integer((UInt64(V) * UInt64(Length(CAsciiRamp) - 1)) div View.MaxIterations);
        S.Append(CAsciiRamp[RampIndex]);
      end;
      S.AppendLine;
    end;
    Result := S.ToString;
  finally
    S.Free;
  end;
end;

initialization
  GMandelbrotKernel := nil;

finalization
  GMandelbrotKernel.Free;

end.
