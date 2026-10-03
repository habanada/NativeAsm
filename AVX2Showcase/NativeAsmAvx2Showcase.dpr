program NativeAsmAvx2Showcase;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Diagnostics,
  NativeAsm.Avx.Cpu,
  NativeAsm.Avx2Showcase.Life in 'NativeAsm.Avx2Showcase.Life.pas';

function CloneBoard(const Source: TLifeBoard): TLifeBoard;
begin
  Result.Width := Source.Width;
  Result.Height := Source.Height;
  Result.Stride := Source.Stride;
  SetLength(Result.Cells, Length(Source.Cells));
  if Length(Source.Cells) > 0 then Move(Source.Cells[0], Result.Cells[0], Length(Source.Cells));
end;

var
  Status: TAvxCpuStatus;
  VerifyEngine: TAvx2LifeEngine;
  BigEngine: TAvx2LifeEngine;
  ScalarBoard, AvxBoard, BigBoard: TLifeBoard;
  Timer: TStopwatch;
  OutputFile: string;
  CellsProcessed: Double;
begin
  try
    Status := TAvxCpuFeatures.Query;
    Writeln('NativeASM AVX2 Showcase');
    Writeln('AVX=', Status.AvxUsable, ' AVX2=', Status.Avx2Usable, ' FMA=', Status.FmaUsable, ' XCR0=$', IntToHex(Status.Xcr0, 2));
    Writeln;
    if not Status.Avx2Usable then
    begin
      Writeln('AVX2 is not available on this CPU/OS state.');
      Halt(2);
    end;

    Writeln('=== AVX2 Integer Cellular Automaton ===');
    Writeln('VPADDB VPCMPEQB VPAND VPOR VMOVDQU');
    Writeln('32 cells are updated in parallel per YMM block.');
    Writeln;

    VerifyEngine := TAvx2LifeEngine.Create(96, 64);
    try
      ScalarBoard := VerifyEngine.NewBoard;
      VerifyEngine.SeedDeterministic(ScalarBoard, $12345678, 52);
      AvxBoard := CloneBoard(ScalarBoard);
      VerifyEngine.RunScalar(ScalarBoard, 32);
      VerifyEngine.RunAvx2(AvxBoard, 32);
      if not BoardsEqual(ScalarBoard, AvxBoard) then
        raise Exception.Create('AVX2 Game of Life scalar verification failed');
      Writeln('96x64, 32 generations scalar cross-check: PASS');
      Writeln('Live cells after verification: ', LiveCount(AvxBoard));
    finally
      VerifyEngine.Free;
    end;

    Writeln;
    Writeln('Rendering 1024x768, 160 generations...');
    BigEngine := TAvx2LifeEngine.Create(1024, 768);
    try
      BigBoard := BigEngine.NewBoard;
      BigEngine.SeedDeterministic(BigBoard, $A5C31E27, 50);
      Timer := TStopwatch.StartNew;
      BigEngine.RunAvx2(BigBoard, 160);
      Timer.Stop;
      CellsProcessed := 1024.0 * 768.0 * 160.0;
      Writeln('AVX2 evolution: ', Timer.ElapsedMilliseconds, ' ms  (', FormatFloat('0.00', CellsProcessed / 1000000.0 / (Timer.ElapsedMilliseconds / 1000.0)), ' Mcell/s)');
      Writeln('Live cells: ', LiveCount(BigBoard));
      OutputFile := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) + 'NativeAsm-AVX2-Life-1024x768.bmp';
      SaveLifeBmp24(OutputFile, BigBoard);
      Writeln('Bitmap: ', OutputFile);
    finally
      BigEngine.Free;
    end;

    Writeln;
    Writeln('AVX2 showcase verification passed.');
  except
    on E: Exception do
    begin
      Writeln('ERROR: ', E.ClassName, ': ', E.Message);
      System.ExitCode := 1;
    end;
  end;
end.
