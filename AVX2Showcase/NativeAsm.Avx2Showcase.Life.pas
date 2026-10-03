unit NativeAsm.Avx2Showcase.Life;

interface

uses
  System.SysUtils,
  NativeAsm.Builder,
  NativeAsm.Extensions;

type
  TLifeBoard = record
    Width: Integer;
    Height: Integer;
    Stride: Integer;
    Cells: TBytes;
  end;

  TAvx2LifeEngine = class
  private
    FWidth: Integer;
    FHeight: Integer;
    FStride: Integer;
    FRowCode: TExecutableCode;
    function BuildRowCode: TExecutableCode;
  public
    constructor Create(AWidth, AHeight: Integer);
    destructor Destroy; override;
    function NewBoard: TLifeBoard;
    procedure SeedDeterministic(var Board: TLifeBoard; Seed: Cardinal; Density: Byte);
    procedure StepAvx2(const Current: TLifeBoard; var Next: TLifeBoard);
    procedure StepScalar(const Current: TLifeBoard; var Next: TLifeBoard);
    procedure RunAvx2(var Board: TLifeBoard; Generations: Integer);
    procedure RunScalar(var Board: TLifeBoard; Generations: Integer);
  end;

function BoardsEqual(const A, B: TLifeBoard): Boolean;
function LiveCount(const Board: TLifeBoard): UInt64;
procedure SaveLifeBmp24(const FileName: string; const Board: TLifeBoard);

implementation

uses
  System.Classes,
  NativeAsm.Types,
  NativeAsm.Avx.Types,
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
    Size: Cardinal;
    Width: Integer;
    Height: Integer;
    Planes: Word;
    BitCount: Word;
    Compression: Cardinal;
    ImageSize: Cardinal;
    XPelsPerMeter: Integer;
    YPelsPerMeter: Integer;
    ColorsUsed: Cardinal;
    ColorsImportant: Cardinal;
  end;

function NextState(var State: Cardinal): Cardinal;
begin
  State := Cardinal((UInt64(State) * UInt64(1664525) + UInt64(1013904223)) and UInt64($FFFFFFFF));
  Result := State;
end;

constructor TAvx2LifeEngine.Create(AWidth, AHeight: Integer);
begin
  inherited Create;
  if (AWidth <= 0) or (AHeight <= 0) or ((AWidth and 31) <> 0) then
    raise EArgumentException.Create('Game of Life width must be a positive multiple of 32');
  FWidth := AWidth;
  FHeight := AHeight;
  FStride := AWidth + 2;
  FRowCode := BuildRowCode;
end;

destructor TAvx2LifeEngine.Destroy;
begin
  FRowCode.Free;
  inherited Destroy;
end;

function TAvx2LifeEngine.BuildRowCode: TExecutableCode;
var
  B: TAsmBuilder;
  X: Integer;
begin
  B := TAsmBuilder.New;
  try
    B.Vpcmpeqb(YMM4, YMM4, YMM4)
     .Vpxor(YMM3, YMM3, YMM3)
     .Vpsubb(YMM5, YMM3, YMM4)
     .Vpaddb(YMM4, YMM5, YMM5)
     .Vpaddb(YMM3, YMM4, YMM5);
    X := 0;
    while X < FWidth do
    begin
      B.Vmovdqu(YMM0, YmmWordPtr(ridRCX, X - 1))
       .Vpaddb(YMM0, YMM0, YmmWordPtr(ridRCX, X))
       .Vpaddb(YMM0, YMM0, YmmWordPtr(ridRCX, X + 1))
       .Vpaddb(YMM0, YMM0, YmmWordPtr(ridRDX, X - 1))
       .Vpaddb(YMM0, YMM0, YmmWordPtr(ridRDX, X + 1))
       .Vpaddb(YMM0, YMM0, YmmWordPtr(ridR8, X - 1))
       .Vpaddb(YMM0, YMM0, YmmWordPtr(ridR8, X))
       .Vpaddb(YMM0, YMM0, YmmWordPtr(ridR8, X + 1))
       .Vmovdqu(YMM1, YmmWordPtr(ridRDX, X))
       .Vpcmpeqb(YMM2, YMM0, YMM3)
       .Vpcmpeqb(YMM0, YMM0, YMM4)
       .Vpand(YMM0, YMM0, YMM1)
       .Vpor(YMM2, YMM2, YMM0)
       .Vpand(YMM2, YMM2, YMM5)
       .Vmovdqu(YmmWordPtr(ridR9, X), YMM2);
      Inc(X, 32);
    end;
    B.Vzeroupper.Ret;
    Result := TExecutableCode.Create(B.Build);
  finally
    B.Free;
  end;
end;

function TAvx2LifeEngine.NewBoard: TLifeBoard;
begin
  Result.Width := FWidth;
  Result.Height := FHeight;
  Result.Stride := FStride;
  SetLength(Result.Cells, FStride * (FHeight + 2));
  FillChar(Result.Cells[0], Length(Result.Cells), 0);
end;

procedure TAvx2LifeEngine.SeedDeterministic(var Board: TLifeBoard; Seed: Cardinal; Density: Byte);
var
  X, Y: Integer;
  State: Cardinal;
begin
  if (Board.Width <> FWidth) or (Board.Height <> FHeight) or (Board.Stride <> FStride) then
    raise EArgumentException.Create('Board dimensions do not match engine');
  FillChar(Board.Cells[0], Length(Board.Cells), 0);
  State := Seed;
  for Y := 1 to FHeight do
    for X := 1 to FWidth do
      if Byte(NextState(State) shr 24) < Density then
        Board.Cells[Y * FStride + X] := 1;
end;

procedure TAvx2LifeEngine.StepAvx2(const Current: TLifeBoard; var Next: TLifeBoard);
var
  Y: Integer;
  TopPtr, MidPtr, BottomPtr, OutPtr: PByte;
begin
  if (Current.Width <> FWidth) or (Next.Width <> FWidth) or (Current.Height <> FHeight) or (Next.Height <> FHeight) then
    raise EArgumentException.Create('Board dimensions do not match engine');
  for Y := 1 to FHeight do
  begin
    TopPtr := @Current.Cells[(Y - 1) * FStride + 1];
    MidPtr := @Current.Cells[Y * FStride + 1];
    BottomPtr := @Current.Cells[(Y + 1) * FStride + 1];
    OutPtr := @Next.Cells[Y * FStride + 1];
    FRowCode.Run(UInt64(NativeUInt(TopPtr)), UInt64(NativeUInt(MidPtr)), UInt64(NativeUInt(BottomPtr)), UInt64(NativeUInt(OutPtr)));
  end;
end;

procedure TAvx2LifeEngine.StepScalar(const Current: TLifeBoard; var Next: TLifeBoard);
var
  X, Y, N, Base: Integer;
  Alive: Byte;
begin
  for Y := 1 to FHeight do
  begin
    Base := Y * FStride;
    for X := 1 to FWidth do
    begin
      N := Current.Cells[Base - FStride + X - 1] + Current.Cells[Base - FStride + X] + Current.Cells[Base - FStride + X + 1] +
           Current.Cells[Base + X - 1] + Current.Cells[Base + X + 1] +
           Current.Cells[Base + FStride + X - 1] + Current.Cells[Base + FStride + X] + Current.Cells[Base + FStride + X + 1];
      Alive := Current.Cells[Base + X];
      if (N = 3) or ((N = 2) and (Alive <> 0)) then Next.Cells[Base + X] := 1 else Next.Cells[Base + X] := 0;
    end;
  end;
end;

procedure TAvx2LifeEngine.RunAvx2(var Board: TLifeBoard; Generations: Integer);
var
  Next, Temp: TLifeBoard;
  I: Integer;
begin
  Next := NewBoard;
  for I := 1 to Generations do
  begin
    StepAvx2(Board, Next);
    Temp := Board;
    Board := Next;
    Next := Temp;
  end;
end;

procedure TAvx2LifeEngine.RunScalar(var Board: TLifeBoard; Generations: Integer);
var
  Next, Temp: TLifeBoard;
  I: Integer;
begin
  Next := NewBoard;
  for I := 1 to Generations do
  begin
    StepScalar(Board, Next);
    Temp := Board;
    Board := Next;
    Next := Temp;
  end;
end;

function BoardsEqual(const A, B: TLifeBoard): Boolean;
var
  X, Y: Integer;
begin
  if (A.Width <> B.Width) or (A.Height <> B.Height) then Exit(False);
  for Y := 1 to A.Height do
    for X := 1 to A.Width do
      if A.Cells[Y * A.Stride + X] <> B.Cells[Y * B.Stride + X] then Exit(False);
  Result := True;
end;

function LiveCount(const Board: TLifeBoard): UInt64;
var
  X, Y: Integer;
begin
  Result := 0;
  for Y := 1 to Board.Height do
    for X := 1 to Board.Width do
      Inc(Result, Board.Cells[Y * Board.Stride + X]);
end;

procedure SaveLifeBmp24(const FileName: string; const Board: TLifeBoard);
var
  Stream: TFileStream;
  FH: TBmpFileHeader;
  IH: TBmpInfoHeader;
  Row: TBytes;
  RowBytes, Padding, X, Y, P: Integer;
  Alive: Boolean;
begin
  RowBytes := Board.Width * 3;
  Padding := (4 - (RowBytes and 3)) and 3;
  FillChar(FH, SizeOf(FH), 0);
  FillChar(IH, SizeOf(IH), 0);
  FH.Signature := $4D42;
  FH.PixelOffset := SizeOf(FH) + SizeOf(IH);
  FH.FileSize := FH.PixelOffset + Cardinal((RowBytes + Padding) * Board.Height);
  IH.Size := SizeOf(IH);
  IH.Width := Board.Width;
  IH.Height := Board.Height;
  IH.Planes := 1;
  IH.BitCount := 24;
  IH.ImageSize := Cardinal((RowBytes + Padding) * Board.Height);
  SetLength(Row, RowBytes + Padding);
  Stream := TFileStream.Create(FileName, fmCreate);
  try
    Stream.WriteBuffer(FH, SizeOf(FH));
    Stream.WriteBuffer(IH, SizeOf(IH));
    for Y := Board.Height downto 1 do
    begin
      FillChar(Row[0], Length(Row), 0);
      P := 0;
      for X := 1 to Board.Width do
      begin
        Alive := Board.Cells[Y * Board.Stride + X] <> 0;
        if Alive then
        begin
          Row[P] := 255;
          Row[P + 1] := 230;
          Row[P + 2] := 64;
        end
        else
        begin
          Row[P] := 20;
          Row[P + 1] := 8;
          Row[P + 2] := 3;
        end;
        Inc(P, 3);
      end;
      Stream.WriteBuffer(Row[0], Length(Row));
    end;
  finally
    Stream.Free;
  end;
end;

end.
