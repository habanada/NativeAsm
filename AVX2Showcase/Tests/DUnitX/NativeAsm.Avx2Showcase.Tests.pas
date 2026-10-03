unit NativeAsm.Avx2Showcase.Tests;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TAvx2ShowcaseTests = class
  public
    [Test] procedure LifeOneGenerationMatchesScalar;
    [Test] procedure LifeThirtyTwoGenerationsMatchScalar;
    [Test] procedure LifeAvx2IsDeterministic;
    [Test] procedure LifeBmpWriterProducesValid24BitBmp;
  end;

implementation

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  NativeAsm.Avx.Cpu,
  NativeAsm.Avx2Showcase.Life;

function CloneBoard(const Source: TLifeBoard): TLifeBoard;
begin
  Result.Width := Source.Width;
  Result.Height := Source.Height;
  Result.Stride := Source.Stride;
  SetLength(Result.Cells, Length(Source.Cells));
  if Length(Source.Cells) > 0 then Move(Source.Cells[0], Result.Cells[0], Length(Source.Cells));
end;

procedure TAvx2ShowcaseTests.LifeOneGenerationMatchesScalar;
var
  Engine: TAvx2LifeEngine;
  A, B: TLifeBoard;
begin
  if not TAvxCpuFeatures.SupportsAvx2 then begin Assert.IsTrue(True, 'AVX2 unavailable'); Exit; end;
  Engine := TAvx2LifeEngine.Create(96, 64);
  try
    A := Engine.NewBoard;
    Engine.SeedDeterministic(A, $10203040, 57);
    B := CloneBoard(A);
    Engine.RunScalar(A, 1);
    Engine.RunAvx2(B, 1);
    Assert.IsTrue(BoardsEqual(A, B));
  finally
    Engine.Free;
  end;
end;

procedure TAvx2ShowcaseTests.LifeThirtyTwoGenerationsMatchScalar;
var
  Engine: TAvx2LifeEngine;
  A, B: TLifeBoard;
begin
  if not TAvxCpuFeatures.SupportsAvx2 then begin Assert.IsTrue(True, 'AVX2 unavailable'); Exit; end;
  Engine := TAvx2LifeEngine.Create(96, 64);
  try
    A := Engine.NewBoard;
    Engine.SeedDeterministic(A, $55667788, 49);
    B := CloneBoard(A);
    Engine.RunScalar(A, 32);
    Engine.RunAvx2(B, 32);
    Assert.IsTrue(BoardsEqual(A, B));
  finally
    Engine.Free;
  end;
end;

procedure TAvx2ShowcaseTests.LifeAvx2IsDeterministic;
var
  Engine: TAvx2LifeEngine;
  A, B: TLifeBoard;
begin
  if not TAvxCpuFeatures.SupportsAvx2 then begin Assert.IsTrue(True, 'AVX2 unavailable'); Exit; end;
  Engine := TAvx2LifeEngine.Create(128, 96);
  try
    A := Engine.NewBoard;
    Engine.SeedDeterministic(A, $CAFEBABE, 52);
    B := CloneBoard(A);
    Engine.RunAvx2(A, 48);
    Engine.RunAvx2(B, 48);
    Assert.IsTrue(BoardsEqual(A, B));
    Assert.IsTrue(LiveCount(A) = LiveCount(B));
  finally
    Engine.Free;
  end;
end;

procedure TAvx2ShowcaseTests.LifeBmpWriterProducesValid24BitBmp;
var
  Engine: TAvx2LifeEngine;
  Board: TLifeBoard;
  FileName: string;
  Stream: TFileStream;
  Header: array[0..53] of Byte;
  FileSize: Cardinal;
  Width, Height: Integer;
  BitCount: Word;
begin
  Engine := TAvx2LifeEngine.Create(64, 32);
  try
    Board := Engine.NewBoard;
    Engine.SeedDeterministic(Board, $31415926, 64);
    FileName := TPath.Combine(TPath.GetTempPath, 'NativeAsmAvx2LifeTest.bmp');
    SaveLifeBmp24(FileName, Board);
    Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
    try
      Assert.IsTrue(Stream.Size >= 54);
      Stream.ReadBuffer(Header[0], SizeOf(Header));
      Assert.IsTrue((Header[0] = Ord('B')) and (Header[1] = Ord('M')));
      Move(Header[2], FileSize, SizeOf(FileSize));
      Move(Header[18], Width, SizeOf(Width));
      Move(Header[22], Height, SizeOf(Height));
      Move(Header[28], BitCount, SizeOf(BitCount));
      Assert.IsTrue(FileSize = Cardinal(Stream.Size));
      Assert.AreEqual(64, Width);
      Assert.AreEqual(32, Height);
      Assert.AreEqual(24, Integer(BitCount));
    finally
      Stream.Free;
    end;
    TFile.Delete(FileName);
  finally
    Engine.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TAvx2ShowcaseTests);

end.
