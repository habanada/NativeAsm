unit NativeAsm.AvxShowcase.FaceDetection;

interface

uses
  System.SysUtils,
  System.Classes,
  NativeAsm.Extensions;

type
  TBgr24 = packed record
    B: Byte;
    G: Byte;
    R: Byte;
  end;

  TFaceDetection = packed record
    Confidence: Integer;
    X: Integer;
    Y: Integer;
    Width: Integer;
    Height: Integer;
    Landmarks: array[0..9] of Integer;
  end;

  TFaceDetections = array of TFaceDetection;

  TBgr24Image = class sealed
  private
    FWidth: Integer;
    FHeight: Integer;
    FStride: Integer;
    FPixels: TBytes;
    function PixelOffset(X, Y: Integer): Integer;
  public
    constructor Create(AWidth, AHeight: Integer);
    class function LoadBmp24(const FileName: string): TBgr24Image; static;
    procedure SaveBmp24(const FileName: string);
    procedure Clear(B, G, R: Byte);
    procedure SetPixel(X, Y: Integer; B, G, R: Byte);
    function GetPixel(X, Y: Integer): TBgr24;
    function Data: PByte;
    procedure DrawDetections(const Faces: TFaceDetections);
    property Width: Integer read FWidth;
    property Height: Integer read FHeight;
    property Stride: Integer read FStride;
  end;

  THaarStageKernel = class sealed
  private
    FCode: TExecutableCode;
    FParams: TArray<Single>;
    FWeakCount: Integer;
  public
    constructor Create(const Thresholds, LeftValues, RightValues: TArray<Single>; StageThreshold: Single);
    destructor Destroy; override;
    function Evaluate(const Features: TArray<Single>): Byte;
    property WeakCount: Integer read FWeakCount;
  end;

  TNativeAsmFaceDetector = class sealed
  public
    class function HardwareSupported: Boolean; static;
    class function DefaultCascadePath: string; static;
    class function DetectBitmap24(const InputFileName, CascadeFileName, OutputFileName: string; out Faces: TFaceDetections): Integer; static;
    class function VerifyStageKernel: Boolean; static;
  end;

implementation

uses
  System.IOUtils,
  System.Math,
  System.Generics.Collections,
  System.StrUtils,
  NativeAsm.Types,
  NativeAsm.Builder,
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

  THaarRect = record
    X: Integer;
    Y: Integer;
    W: Integer;
    H: Integer;
    Weight: Single;
  end;

  THaarFeature = record
    Rects: TArray<THaarRect>;
  end;

  THaarWeak = record
    FeatureIndex: Integer;
    Threshold: Single;
    LeftValue: Single;
    RightValue: Single;
  end;

  THaarStage = record
    Threshold: Single;
    Weaks: TArray<THaarWeak>;
    Kernel: THaarStageKernel;
  end;

  THaarCascade = class sealed
  private
    FWidth: Integer;
    FHeight: Integer;
    FFeatures: TArray<THaarFeature>;
    FStages: TArray<THaarStage>;
    class function FloatText(const S: string): Single; static;
    class function SplitTokens(const S: string): TArray<string>; static;
  public
    destructor Destroy; override;
    class function Load(const FileName: string): THaarCascade; static;
    property Width: Integer read FWidth;
    property Height: Integer read FHeight;
  end;

  TIntegralImage = record
    Width: Integer;
    Height: Integer;
    Sum: TArray<Double>;
    SqSum: TArray<Double>;
    function Index(X, Y: Integer): Integer;
    function RectSum(X, Y, W, H: Integer): Double;
    function RectSqSum(X, Y, W, H: Integer): Double;
  end;

  TCandidate8 = record
    Count: Integer;
    X: array[0..7] of Integer;
    Y: array[0..7] of Integer;
    ActiveMask: Byte;
  end;

function TBgr24Image.PixelOffset(X, Y: Integer): Integer;
begin
  if (X < 0) or (X >= FWidth) or (Y < 0) or (Y >= FHeight) then
    raise EArgumentOutOfRangeException.Create('pixel coordinate outside image');
  Result := Y * FStride + X * 3;
end;

constructor TBgr24Image.Create(AWidth, AHeight: Integer);
begin
  inherited Create;
  if AWidth <= 0 then raise EArgumentOutOfRangeException.Create('width must be positive');
  if AHeight <= 0 then raise EArgumentOutOfRangeException.Create('height must be positive');
  if AWidth > MaxInt div 3 then raise EArgumentOutOfRangeException.Create('width is too large');
  FWidth := AWidth;
  FHeight := AHeight;
  FStride := AWidth * 3;
  if AHeight > MaxInt div FStride then raise EArgumentOutOfRangeException.Create('image is too large');
  SetLength(FPixels, FStride * FHeight);
end;

class function TBgr24Image.LoadBmp24(const FileName: string): TBgr24Image;
var
  Stream: TFileStream;
  FileHeader: TBmpFileHeader;
  InfoHeader: TBmpInfoHeader;
  FileStride, FileRow, TargetY: Integer;
  Row: TBytes;
begin
  Result := nil;
  Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
  try
    try
      if Stream.Size < SizeOf(FileHeader) + SizeOf(InfoHeader) then
        raise EInvalidOpException.Create('BMP file is too small');
      Stream.ReadBuffer(FileHeader, SizeOf(FileHeader));
      Stream.ReadBuffer(InfoHeader, SizeOf(InfoHeader));
      if FileHeader.Signature <> $4D42 then raise EInvalidOpException.Create('input is not a BMP file');
      if InfoHeader.HeaderSize < SizeOf(InfoHeader) then raise EInvalidOpException.Create('unsupported BMP info header');
      if InfoHeader.Planes <> 1 then raise EInvalidOpException.Create('unsupported BMP plane count');
      if InfoHeader.BitsPerPixel <> 24 then raise EInvalidOpException.Create('face showcase requires 24-bit BMP');
      if InfoHeader.Compression <> 0 then raise EInvalidOpException.Create('compressed BMP is not supported');
      if InfoHeader.Width <= 0 then raise EInvalidOpException.Create('invalid BMP width');
      if InfoHeader.Height = 0 then raise EInvalidOpException.Create('invalid BMP height');
      if FileHeader.PixelOffset >= Cardinal(Stream.Size) then raise EInvalidOpException.Create('invalid BMP pixel offset');

      Result := TBgr24Image.Create(InfoHeader.Width, Abs(InfoHeader.Height));
      FileStride := (Result.FWidth * 3 + 3) and not 3;
      SetLength(Row, FileStride);
      Stream.Position := FileHeader.PixelOffset;
      for FileRow := 0 to Result.FHeight - 1 do
      begin
        Stream.ReadBuffer(Row[0], FileStride);
        if InfoHeader.Height > 0 then TargetY := Result.FHeight - 1 - FileRow else TargetY := FileRow;
        Move(Row[0], Result.FPixels[TargetY * Result.FStride], Result.FStride);
      end;
    except
      Result.Free;
      raise;
    end;
  finally
    Stream.Free;
  end;
end;

procedure TBgr24Image.SaveBmp24(const FileName: string);
var
  FileHeader: TBmpFileHeader;
  InfoHeader: TBmpInfoHeader;
  Stream: TFileStream;
  FileStride, Y: Integer;
  Row: TBytes;
begin
  FileStride := (FWidth * 3 + 3) and not 3;
  FillChar(FileHeader, SizeOf(FileHeader), 0);
  FillChar(InfoHeader, SizeOf(InfoHeader), 0);
  FileHeader.Signature := $4D42;
  FileHeader.PixelOffset := SizeOf(FileHeader) + SizeOf(InfoHeader);
  FileHeader.FileSize := FileHeader.PixelOffset + Cardinal(FileStride * FHeight);
  InfoHeader.HeaderSize := SizeOf(InfoHeader);
  InfoHeader.Width := FWidth;
  InfoHeader.Height := FHeight;
  InfoHeader.Planes := 1;
  InfoHeader.BitsPerPixel := 24;
  InfoHeader.ImageSize := Cardinal(FileStride * FHeight);
  SetLength(Row, FileStride);
  Stream := TFileStream.Create(FileName, fmCreate);
  try
    Stream.WriteBuffer(FileHeader, SizeOf(FileHeader));
    Stream.WriteBuffer(InfoHeader, SizeOf(InfoHeader));
    for Y := FHeight - 1 downto 0 do
    begin
      FillChar(Row[0], FileStride, 0);
      Move(FPixels[Y * FStride], Row[0], FStride);
      Stream.WriteBuffer(Row[0], FileStride);
    end;
  finally
    Stream.Free;
  end;
end;

procedure TBgr24Image.Clear(B, G, R: Byte);
var
  X, Y, P: Integer;
begin
  for Y := 0 to FHeight - 1 do
    for X := 0 to FWidth - 1 do
    begin
      P := Y * FStride + X * 3;
      FPixels[P] := B;
      FPixels[P + 1] := G;
      FPixels[P + 2] := R;
    end;
end;

procedure TBgr24Image.SetPixel(X, Y: Integer; B, G, R: Byte);
var
  P: Integer;
begin
  if (X < 0) or (X >= FWidth) or (Y < 0) or (Y >= FHeight) then Exit;
  P := Y * FStride + X * 3;
  FPixels[P] := B;
  FPixels[P + 1] := G;
  FPixels[P + 2] := R;
end;

function TBgr24Image.GetPixel(X, Y: Integer): TBgr24;
var
  P: Integer;
begin
  P := PixelOffset(X, Y);
  Result.B := FPixels[P];
  Result.G := FPixels[P + 1];
  Result.R := FPixels[P + 2];
end;

function TBgr24Image.Data: PByte;
begin
  if Length(FPixels) = 0 then Exit(nil);
  Result := @FPixels[0];
end;

procedure DrawRect(Image: TBgr24Image; X, Y, W, H: Integer; B, G, R: Byte);
var
  I, T: Integer;
begin
  for T := 0 to 2 do
  begin
    for I := X to X + W - 1 do
    begin
      Image.SetPixel(I, Y + T, B, G, R);
      Image.SetPixel(I, Y + H - 1 - T, B, G, R);
    end;
    for I := Y to Y + H - 1 do
    begin
      Image.SetPixel(X + T, I, B, G, R);
      Image.SetPixel(X + W - 1 - T, I, B, G, R);
    end;
  end;
end;

procedure TBgr24Image.DrawDetections(const Faces: TFaceDetections);
var
  I: Integer;
begin
  for I := 0 to High(Faces) do
    DrawRect(Self, Faces[I].X, Faces[I].Y, Faces[I].Width, Faces[I].Height, 32, 255, 32);
end;

constructor THaarStageKernel.Create(const Thresholds, LeftValues, RightValues: TArray<Single>; StageThreshold: Single);
var
  B: TAsmBuilder;
  I, P: Integer;
begin
  inherited Create;
  if (Length(Thresholds) = 0) or (Length(Thresholds) <> Length(LeftValues)) or (Length(Thresholds) <> Length(RightValues)) then
    raise EArgumentException.Create('invalid stage parameters');
  FWeakCount := Length(Thresholds);
  SetLength(FParams, FWeakCount * 3 + 1);
  for I := 0 to FWeakCount - 1 do
  begin
    P := I * 3;
    FParams[P] := Thresholds[I];
    FParams[P + 1] := LeftValues[I];
    FParams[P + 2] := RightValues[I];
  end;
  FParams[FWeakCount * 3] := StageThreshold;

  B := TAsmBuilder.New;
  try
    B.Vxorps(YMM0, YMM0, YMM0);
    for I := 0 to FWeakCount - 1 do
    begin
      P := I * 3 * SizeOf(Single);
      B.Vmovups(YMM1, YmmWordPtr(ridRCX, I * 8 * SizeOf(Single)));
      B.Vbroadcastss(YMM2, DWordPtr(ridRDX, P));
      B.Vcmpps(YMM3, YMM1, YMM2, $01);
      B.Vbroadcastss(YMM4, DWordPtr(ridRDX, P + SizeOf(Single)));
      B.Vbroadcastss(YMM5, DWordPtr(ridRDX, P + 2 * SizeOf(Single)));
      B.Vandps(YMM4, YMM4, YMM3);
      B.Vandnps(YMM3, YMM3, YMM5);
      B.Vorps(YMM4, YMM4, YMM3);
      B.Vaddps(YMM0, YMM0, YMM4);
    end;
    B.Vbroadcastss(YMM1, DWordPtr(ridRDX, FWeakCount * 3 * SizeOf(Single)));
    B.Vcmpps(YMM0, YMM0, YMM1, $1D);
    B.Vmovmskps(EAX, YMM0);
    B.Vzeroupper.Ret;
    FCode := TExecutableCode.Create(B.Build);
  finally
    B.Free;
  end;
end;

destructor THaarStageKernel.Destroy;
begin
  FCode.Free;
  inherited;
end;

function THaarStageKernel.Evaluate(const Features: TArray<Single>): Byte;
var
  R: UInt64;
begin
  if Length(Features) <> FWeakCount * 8 then
    raise EArgumentException.Create('stage feature matrix has invalid size');
  if Length(Features) = 0 then Exit(0);
  R := FCode.Run(UInt64(NativeUInt(@Features[0])), UInt64(NativeUInt(@FParams[0])));
  Result := Byte(R and $FF);
end;

class function THaarCascade.FloatText(const S: string): Single;
var
  FS: TFormatSettings;
begin
  FS := TFormatSettings.Create('en-US');
  Result := StrToFloat(Trim(S), FS);
end;

class function THaarCascade.SplitTokens(const S: string): TArray<string>;
var
  L: TStringList;
  I: Integer;
begin
  L := TStringList.Create;
  try
    L.StrictDelimiter := True;
    L.Delimiter := ' ';
    L.DelimitedText := StringReplace(StringReplace(Trim(S), #13, ' ', [rfReplaceAll]), #10, ' ', [rfReplaceAll]);
    I := L.Count - 1;
    while I >= 0 do
    begin
      if Trim(L[I]) = '' then L.Delete(I);
      Dec(I);
    end;
    SetLength(Result, L.Count);
    for I := 0 to L.Count - 1 do Result[I] := L[I];
  finally
    L.Free;
  end;
end;

destructor THaarCascade.Destroy;
var
  I: Integer;
begin
  for I := 0 to High(FStages) do FStages[I].Kernel.Free;
  inherited;
end;

function TryElementContent(const S, Name: string; StartPos: Integer; out Content: string): Boolean;
var
  OpenPrefix, CloseTag: string;
  OpenPos, NameEnd, OpenEnd, ClosePos: Integer;
  C: Char;
begin
  Result := False;
  Content := '';
  OpenPrefix := '<' + Name;
  OpenPos := PosEx(OpenPrefix, S, StartPos);
  while OpenPos > 0 do
  begin
    NameEnd := OpenPos + Length(OpenPrefix);
    if NameEnd > Length(S) then Exit;
    C := S[NameEnd];
    if (C = '>') or CharInSet(C, [#9, #10, #13, ' ']) then Break;
    OpenPos := PosEx(OpenPrefix, S, OpenPos + 1);
  end;
  if OpenPos = 0 then Exit;
  OpenEnd := PosEx('>', S, NameEnd);
  if OpenEnd = 0 then raise EInvalidOpException.CreateFmt('unterminated <%s> element', [Name]);
  CloseTag := '</' + Name + '>';
  ClosePos := PosEx(CloseTag, S, OpenEnd + 1);
  if ClosePos = 0 then raise EInvalidOpException.CreateFmt('missing </%s> element', [Name]);
  Content := Copy(S, OpenEnd + 1, ClosePos - OpenEnd - 1);
  Result := True;
end;

function ElementContent(const S, Name: string): string;
begin
  if not TryElementContent(S, Name, 1, Result) then
    raise EInvalidOpException.CreateFmt('missing <%s> element', [Name]);
end;

function ElementText(const S, Name: string): string;
begin
  Result := Trim(ElementContent(S, Name));
end;

function TryElementText(const S, Name: string; out Value: string): Boolean;
begin
  Result := TryElementContent(S, Name, 1, Value);
  if Result then Value := Trim(Value);
end;

function DirectUnderscoreItems(const S: string): TArray<string>;
const
  OpenTag = '<_>';
  CloseTag = '</_>';
var
  P, NextOpen, NextClose, Depth, ItemStart, N: Integer;
begin
  SetLength(Result, 0);
  P := 1;
  Depth := 0;
  ItemStart := 0;
  while P <= Length(S) do
  begin
    NextOpen := PosEx(OpenTag, S, P);
    NextClose := PosEx(CloseTag, S, P);
    if (NextOpen = 0) and (NextClose = 0) then Break;
    if (NextOpen > 0) and ((NextClose = 0) or (NextOpen < NextClose)) then
    begin
      if Depth = 0 then ItemStart := NextOpen + Length(OpenTag);
      Inc(Depth);
      P := NextOpen + Length(OpenTag);
    end
    else
    begin
      if Depth <= 0 then raise EInvalidOpException.Create('unexpected </_> in cascade XML');
      Dec(Depth);
      if Depth = 0 then
      begin
        N := Length(Result);
        SetLength(Result, N + 1);
        Result[N] := Copy(S, ItemStart, NextClose - ItemStart);
      end;
      P := NextClose + Length(CloseTag);
    end;
  end;
  if Depth <> 0 then raise EInvalidOpException.Create('unterminated <_> in cascade XML');
end;

class function THaarCascade.Load(const FileName: string): THaarCascade;
var
  Xml, CascadeText, FeaturesText, StagesText, RectsText, WeaksText, TiltedText: string;
  FeatureItems, RectItems, StageItems, WeakItems: TArray<string>;
  FeatureIndex, I, J: Integer;
  Tokens: TArray<string>;
  Thresholds, LeftValues, RightValues: TArray<Single>;
  R: THaarRect;
begin
  Result := THaarCascade.Create;
  try
    Xml := TFile.ReadAllText(FileName, TEncoding.UTF8);
    CascadeText := ElementContent(Xml, 'cascade');
    if TryElementText(CascadeText, 'featureType', TiltedText) and (UpperCase(TiltedText) <> 'HAAR') then
      raise ENotSupportedException.Create('only OpenCV HAAR cascades are supported');
    Result.FWidth := StrToInt(ElementText(CascadeText, 'width'));
    Result.FHeight := StrToInt(ElementText(CascadeText, 'height'));

    FeaturesText := ElementContent(CascadeText, 'features');
    FeatureItems := DirectUnderscoreItems(FeaturesText);
    SetLength(Result.FFeatures, Length(FeatureItems));
    for I := 0 to High(FeatureItems) do
    begin
      if TryElementText(FeatureItems[I], 'tilted', TiltedText) and (TiltedText <> '0') then
        raise ENotSupportedException.Create('tilted HAAR features are not supported by this showcase');
      RectsText := ElementContent(FeatureItems[I], 'rects');
      RectItems := DirectUnderscoreItems(RectsText);
      SetLength(Result.FFeatures[I].Rects, Length(RectItems));
      for J := 0 to High(RectItems) do
      begin
        Tokens := SplitTokens(RectItems[J]);
        if Length(Tokens) <> 5 then raise EInvalidOpException.Create('invalid HAAR rectangle');
        R.X := StrToInt(Tokens[0]);
        R.Y := StrToInt(Tokens[1]);
        R.W := StrToInt(Tokens[2]);
        R.H := StrToInt(Tokens[3]);
        R.Weight := FloatText(Tokens[4]);
        Result.FFeatures[I].Rects[J] := R;
      end;
    end;

    StagesText := ElementContent(CascadeText, 'stages');
    StageItems := DirectUnderscoreItems(StagesText);
    SetLength(Result.FStages, Length(StageItems));
    for I := 0 to High(StageItems) do
    begin
      Result.FStages[I].Threshold := FloatText(ElementText(StageItems[I], 'stageThreshold'));
      WeaksText := ElementContent(StageItems[I], 'weakClassifiers');
      WeakItems := DirectUnderscoreItems(WeaksText);
      SetLength(Result.FStages[I].Weaks, Length(WeakItems));
      SetLength(Thresholds, Length(WeakItems));
      SetLength(LeftValues, Length(WeakItems));
      SetLength(RightValues, Length(WeakItems));
      for J := 0 to High(WeakItems) do
      begin
        Tokens := SplitTokens(ElementText(WeakItems[J], 'internalNodes'));
        if Length(Tokens) <> 4 then raise ENotSupportedException.Create('only depth-1 HAAR weak classifiers are supported');
        if (Tokens[0] <> '0') or (Tokens[1] <> '-1') then
          raise ENotSupportedException.Create('unsupported HAAR tree topology');
        FeatureIndex := StrToInt(Tokens[2]);
        if (FeatureIndex < 0) or (FeatureIndex >= Length(Result.FFeatures)) then
          raise EInvalidOpException.Create('HAAR feature index outside feature table');
        Result.FStages[I].Weaks[J].FeatureIndex := FeatureIndex;
        Result.FStages[I].Weaks[J].Threshold := FloatText(Tokens[3]);
        Tokens := SplitTokens(ElementText(WeakItems[J], 'leafValues'));
        if Length(Tokens) <> 2 then raise EInvalidOpException.Create('invalid HAAR leaf values');
        Result.FStages[I].Weaks[J].LeftValue := FloatText(Tokens[0]);
        Result.FStages[I].Weaks[J].RightValue := FloatText(Tokens[1]);
        Thresholds[J] := Result.FStages[I].Weaks[J].Threshold;
        LeftValues[J] := Result.FStages[I].Weaks[J].LeftValue;
        RightValues[J] := Result.FStages[I].Weaks[J].RightValue;
      end;
      Result.FStages[I].Kernel := THaarStageKernel.Create(Thresholds, LeftValues, RightValues, Result.FStages[I].Threshold);
    end;
  except
    Result.Free;
    raise;
  end;
end;

function TIntegralImage.Index(X, Y: Integer): Integer;
begin
  Result := Y * (Width + 1) + X;
end;

function TIntegralImage.RectSum(X, Y, W, H: Integer): Double;
var
  X2, Y2: Integer;
begin
  X2 := X + W;
  Y2 := Y + H;
  Result := Sum[Index(X2, Y2)] - Sum[Index(X, Y2)] - Sum[Index(X2, Y)] + Sum[Index(X, Y)];
end;

function TIntegralImage.RectSqSum(X, Y, W, H: Integer): Double;
var
  X2, Y2: Integer;
begin
  X2 := X + W;
  Y2 := Y + H;
  Result := SqSum[Index(X2, Y2)] - SqSum[Index(X, Y2)] - SqSum[Index(X2, Y)] + SqSum[Index(X, Y)];
end;

function BuildIntegral(Image: TBgr24Image): TIntegralImage;
var
  X, Y, P, I, Stride: Integer;
  Gray, RowSum, RowSq: Double;
begin
  Result.Width := Image.Width;
  Result.Height := Image.Height;
  Stride := Result.Width + 1;
  SetLength(Result.Sum, Stride * (Result.Height + 1));
  SetLength(Result.SqSum, Stride * (Result.Height + 1));
  for Y := 1 to Result.Height do
  begin
    RowSum := 0;
    RowSq := 0;
    for X := 1 to Result.Width do
    begin
      P := (Y - 1) * Image.Stride + (X - 1) * 3;
      Gray := Image.FPixels[P] * 0.114 + Image.FPixels[P + 1] * 0.587 + Image.FPixels[P + 2] * 0.299;
      RowSum := RowSum + Gray;
      RowSq := RowSq + Gray * Gray;
      I := Y * Stride + X;
      Result.Sum[I] := Result.Sum[I - Stride] + RowSum;
      Result.SqSum[I] := Result.SqSum[I - Stride] + RowSq;
    end;
  end;
end;

function ScaledRectSum(const Integral: TIntegralImage; BaseX, BaseY: Integer; Scale: Double; const R: THaarRect): Double;
var
  X, Y, W, H: Integer;
begin
  X := BaseX + Round(R.X * Scale);
  Y := BaseY + Round(R.Y * Scale);
  W := Max(1, Round(R.W * Scale));
  H := Max(1, Round(R.H * Scale));
  if X + W > Integral.Width then W := Integral.Width - X;
  if Y + H > Integral.Height then H := Integral.Height - Y;
  if (W <= 0) or (H <= 0) then Exit(0);
  Result := Integral.RectSum(X, Y, W, H) * R.Weight;
end;

function WindowVariance(const Integral: TIntegralImage; X, Y, W, H: Integer): Double;
var
  NX, NY, NW, NH: Integer;
  S, Q, A, V: Double;
begin
  NX := X + 1;
  NY := Y + 1;
  NW := Max(1, W - 2);
  NH := Max(1, H - 2);
  S := Integral.RectSum(NX, NY, NW, NH);
  Q := Integral.RectSqSum(NX, NY, NW, NH);
  A := NW * NH;
  V := Q * A - S * S;
  if V > 0 then Result := Sqrt(V) else Result := 1.0;
end;

function IoU(const A, B: TFaceDetection): Double;
var
  X1, Y1, X2, Y2, IW, IH: Integer;
  Inter, UnionArea: Double;
begin
  X1 := Max(A.X, B.X);
  Y1 := Max(A.Y, B.Y);
  X2 := Min(A.X + A.Width, B.X + B.Width);
  Y2 := Min(A.Y + A.Height, B.Y + B.Height);
  IW := Max(0, X2 - X1);
  IH := Max(0, Y2 - Y1);
  Inter := IW * IH;
  UnionArea := A.Width * A.Height + B.Width * B.Height - Inter;
  if UnionArea <= 0 then Exit(0);
  Result := Inter / UnionArea;
end;

procedure GroupDetections(const Raw: TFaceDetections; out Grouped: TFaceDetections);
var
  Used: TArray<Boolean>;
  I, J, Count, SX, SY, SW, SH, Score: Integer;
  D: TFaceDetection;
begin
  SetLength(Used, Length(Raw));
  SetLength(Grouped, 0);
  for I := 0 to High(Raw) do
  begin
    if Used[I] then Continue;
    SX := 0; SY := 0; SW := 0; SH := 0; Score := 0; Count := 0;
    for J := I to High(Raw) do
      if (not Used[J]) and (IoU(Raw[I], Raw[J]) >= 0.28) then
      begin
        Used[J] := True;
        Inc(SX, Raw[J].X);
        Inc(SY, Raw[J].Y);
        Inc(SW, Raw[J].Width);
        Inc(SH, Raw[J].Height);
        Inc(Score, Raw[J].Confidence);
        Inc(Count);
      end;
    if Count < 2 then Continue;
    FillChar(D, SizeOf(D), 0);
    D.X := SX div Count;
    D.Y := SY div Count;
    D.Width := SW div Count;
    D.Height := SH div Count;
    D.Confidence := Score div Count;
    SetLength(Grouped, Length(Grouped) + 1);
    Grouped[High(Grouped)] := D;
  end;
end;

function RunCascade(const Cascade: THaarCascade; const Integral: TIntegralImage; Image: TBgr24Image): TFaceDetections;
var
  Scale: Double;
  WinW, WinH, Step, X, Y, Lane, StageIndex, WeakIndex, RectIndex: Integer;
  Candidate: TCandidate8;
  Features: TArray<Single>;
  Variance: array[0..7] of Double;
  FeatureValue: Double;
  PassMask: Byte;
  Raw: TFaceDetections;
  Face: TFaceDetection;
  Weak: THaarWeak;
  Feature: THaarFeature;
begin
  SetLength(Raw, 0);
  Scale := 1.0;
  while True do
  begin
    WinW := Round(Cascade.Width * Scale);
    WinH := Round(Cascade.Height * Scale);
    if (WinW > Image.Width) or (WinH > Image.Height) then Break;
    Step := Max(2, Round(Scale * 2));
    Y := 0;
    while Y <= Image.Height - WinH do
    begin
      X := 0;
      while X <= Image.Width - WinW do
      begin
        Candidate.Count := 0;
        Candidate.ActiveMask := 0;
        for Lane := 0 to 7 do
        begin
          Candidate.X[Lane] := X + Lane * Step;
          Candidate.Y[Lane] := Y;
          if Candidate.X[Lane] <= Image.Width - WinW then
          begin
            Candidate.ActiveMask := Candidate.ActiveMask or (1 shl Lane);
            Inc(Candidate.Count);
            Variance[Lane] := WindowVariance(Integral, Candidate.X[Lane], Candidate.Y[Lane], WinW, WinH);
          end
          else
            Variance[Lane] := 1.0;
        end;
        if Candidate.ActiveMask = 0 then Break;
        PassMask := Candidate.ActiveMask;
        for StageIndex := 0 to High(Cascade.FStages) do
        begin
          SetLength(Features, Length(Cascade.FStages[StageIndex].Weaks) * 8);
          for WeakIndex := 0 to High(Cascade.FStages[StageIndex].Weaks) do
          begin
            Weak := Cascade.FStages[StageIndex].Weaks[WeakIndex];
            Feature := Cascade.FFeatures[Weak.FeatureIndex];
            for Lane := 0 to 7 do
            begin
              if (PassMask and (1 shl Lane)) = 0 then
              begin
                Features[WeakIndex * 8 + Lane] := 0;
                Continue;
              end;
              FeatureValue := 0;
              for RectIndex := 0 to High(Feature.Rects) do
                FeatureValue := FeatureValue + ScaledRectSum(Integral, Candidate.X[Lane], Candidate.Y[Lane], Scale, Feature.Rects[RectIndex]);
              Features[WeakIndex * 8 + Lane] := Single(FeatureValue / Variance[Lane]);
            end;
          end;
          PassMask := PassMask and Cascade.FStages[StageIndex].Kernel.Evaluate(Features);
          if PassMask = 0 then Break;
        end;
        if PassMask <> 0 then
          for Lane := 0 to 7 do
            if (PassMask and (1 shl Lane)) <> 0 then
            begin
              FillChar(Face, SizeOf(Face), 0);
              Face.X := Candidate.X[Lane];
              Face.Y := Candidate.Y[Lane];
              Face.Width := WinW;
              Face.Height := WinH;
              Face.Confidence := 1000 + Round(Scale * 100);
              SetLength(Raw, Length(Raw) + 1);
              Raw[High(Raw)] := Face;
            end;
        Inc(X, Step * 8);
      end;
      Inc(Y, Step);
    end;
    Scale := Scale * 1.18;
  end;
  GroupDetections(Raw, Result);
end;

class function TNativeAsmFaceDetector.HardwareSupported: Boolean;
begin
  Result := TAvxCpuFeatures.SupportsAvx;
end;

class function TNativeAsmFaceDetector.DefaultCascadePath: string;
var
  Candidate: string;
begin
  Candidate := TPath.Combine(ExtractFilePath(ParamStr(0)), 'haarcascade_frontalface_default.xml');
  if FileExists(Candidate) then Exit(Candidate);
  Candidate := ExpandFileName('haarcascade_frontalface_default.xml');
  Result := Candidate;
end;

class function TNativeAsmFaceDetector.DetectBitmap24(const InputFileName, CascadeFileName, OutputFileName: string; out Faces: TFaceDetections): Integer;
var
  Image: TBgr24Image;
  Cascade: THaarCascade;
  Integral: TIntegralImage;
begin
  if not HardwareSupported then raise ENotSupportedException.Create('face detector requires AVX');
  if not FileExists(CascadeFileName) then raise EFileNotFoundException.Create('HAAR cascade not found: ' + CascadeFileName);
  Image := TBgr24Image.LoadBmp24(InputFileName);
  try
    Cascade := THaarCascade.Load(CascadeFileName);
    try
      Integral := BuildIntegral(Image);
      Faces := RunCascade(Cascade, Integral, Image);
      Image.DrawDetections(Faces);
      Image.SaveBmp24(OutputFileName);
      Result := Length(Faces);
    finally
      Cascade.Free;
    end;
  finally
    Image.Free;
  end;
end;

class function TNativeAsmFaceDetector.VerifyStageKernel: Boolean;
var
  Thresholds, LeftValues, RightValues, Features: TArray<Single>;
  Kernel: THaarStageKernel;
  Lane, I: Integer;
  ExpectedMask, ActualMask: Byte;
  Score: Single;
begin
  SetLength(Thresholds, 4);
  SetLength(LeftValues, 4);
  SetLength(RightValues, 4);
  Thresholds[0] := 0.25; Thresholds[1] := -0.5; Thresholds[2] := 1.0; Thresholds[3] := 0.0;
  LeftValues[0] := -0.2; LeftValues[1] := 0.4; LeftValues[2] := -0.1; LeftValues[3] := 0.3;
  RightValues[0] := 0.6; RightValues[1] := -0.2; RightValues[2] := 0.5; RightValues[3] := -0.4;
  SetLength(Features, 32);
  for I := 0 to 3 do
    for Lane := 0 to 7 do
      Features[I * 8 + Lane] := (Lane - 3) * 0.35 + I * 0.22;
  Kernel := THaarStageKernel.Create(Thresholds, LeftValues, RightValues, 0.45);
  try
    ActualMask := Kernel.Evaluate(Features);
    ExpectedMask := 0;
    for Lane := 0 to 7 do
    begin
      Score := 0;
      for I := 0 to 3 do
        if Features[I * 8 + Lane] < Thresholds[I] then
          Score := Score + LeftValues[I]
        else
          Score := Score + RightValues[I];
      if Score >= 0.45 then ExpectedMask := ExpectedMask or (1 shl Lane);
    end;
    Result := ActualMask = ExpectedMask;
  finally
    Kernel.Free;
  end;
end;

end.
