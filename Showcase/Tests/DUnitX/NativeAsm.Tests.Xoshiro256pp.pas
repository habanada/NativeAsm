{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
unit NativeAsm.Tests.Xoshiro256pp;

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  NativeAsm.CpuFeatures,
  NativeAsm.Random.Xoshiro256pp;

type
  [TestFixture]
  TXoshiro256ppTests = class
  public
    [Test] procedure SeedOneKnownSequence;
    [Test] procedure JumpKnownState;
    [Test] procedure FillMatchesRepeatedNext;
    [Test] procedure ZeroCountPreservesState;
    [Test] procedure ParallelMatchesTwoJumpSeparatedScalarStreams;
    [Test] procedure NilDestinationIsRejected;
  end;

implementation

procedure TXoshiro256ppTests.SeedOneKnownSequence;
const
  Expected: array[0..7] of UInt64 = ($CFC5D07F6F03C29B, $BF424132963FE08D, $19A37D5757AAF520, $BF08119F05CD56D6, $2F47184B86186FA4, $97299FCAE7202345, $FCA3C79508F41507, $85FEA5C90363F221);
var
  Jit: TXoshiro256ppJit;
  State: TXoshiro256ppState;
  I: Integer;
begin
  TXoshiro256ppJit.SeedState(State, 1);
  Jit := TXoshiro256ppJit.Create;
  try
    for I := Low(Expected) to High(Expected) do Assert.IsTrue(Jit.NextUInt64(State) = Expected[I], 'Index ' + IntToStr(I));
  finally
    Jit.Free;
  end;
end;

procedure TXoshiro256ppTests.JumpKnownState;
const
  Expected: array[0..3] of UInt64 = ($53D630076A137DED, $ED07F666882EDFC6, $963EC9617B0BDBD3, $84B96906E4B2569A);
var
  State: TXoshiro256ppState;
  I: Integer;
begin
  TXoshiro256ppJit.SeedState(State, 1);
  TXoshiro256ppJit.Jump(State);
  for I := 0 to 3 do Assert.IsTrue(State[I] = Expected[I], 'State ' + IntToStr(I));
end;

procedure TXoshiro256ppTests.FillMatchesRepeatedNext;
var
  Jit: TXoshiro256ppJit;
  A, B: TXoshiro256ppState;
  Bulk, Single: array[0..255] of UInt64;
  I: Integer;
begin
  TXoshiro256ppJit.SeedState(A, $123456789ABCDEF0);
  B := A;
  Jit := TXoshiro256ppJit.Create;
  try
    Jit.Fill(A, @Bulk[0], Length(Bulk));
    for I := 0 to High(Single) do Single[I] := Jit.NextUInt64(B);
    for I := 0 to High(Bulk) do Assert.IsTrue(Bulk[I] = Single[I], 'Index ' + IntToStr(I));
    for I := 0 to 3 do Assert.IsTrue(A[I] = B[I], 'State ' + IntToStr(I));
  finally
    Jit.Free;
  end;
end;

procedure TXoshiro256ppTests.ZeroCountPreservesState;
var
  Jit: TXoshiro256ppJit;
  A, B: TXoshiro256ppState;
begin
  TXoshiro256ppJit.SeedState(A, 42);
  B := A;
  Jit := TXoshiro256ppJit.Create;
  try
    Jit.Fill(A, nil, 0);
    Assert.IsTrue((A[0] = B[0]) and (A[1] = B[1]) and (A[2] = B[2]) and (A[3] = B[3]));
  finally
    Jit.Free;
  end;
end;

procedure TXoshiro256ppTests.ParallelMatchesTwoJumpSeparatedScalarStreams;
var
  Scalar: TXoshiro256ppJit;
  Parallel: TXoshiro256ppParallelJit;
  A, B: TXoshiro256ppState;
  PState: TXoshiro256ppParallelState;
  PA, PB: array[0..127] of UInt64;
  Interleaved: array[0..255] of UInt64;
  I: Integer;
begin
  if not TCpuFeatures.Supports(cfSSE2) then Exit;
  TXoshiro256ppJit.SeedState(A, $CAFEBABE12345678);
  B := A;
  TXoshiro256ppJit.Jump(B);
  TXoshiro256ppParallelJit.SeedState(PState, $CAFEBABE12345678);
  Scalar := TXoshiro256ppJit.Create;
  Parallel := TXoshiro256ppParallelJit.Create;
  try
    Scalar.Fill(A, @PA[0], Length(PA));
    Scalar.Fill(B, @PB[0], Length(PB));
    Parallel.FillInterleaved(PState, @Interleaved[0], Length(PA));
    for I := 0 to High(PA) do
    begin
      Assert.IsTrue(Interleaved[I * 2] = PA[I], 'Lane 0 index ' + IntToStr(I));
      Assert.IsTrue(Interleaved[I * 2 + 1] = PB[I], 'Lane 1 index ' + IntToStr(I));
    end;
  finally
    Parallel.Free;
    Scalar.Free;
  end;
end;

procedure TXoshiro256ppTests.NilDestinationIsRejected;
var
  Jit: TXoshiro256ppJit;
  State: TXoshiro256ppState;
  Raised: Boolean;
begin
  TXoshiro256ppJit.SeedState(State, 1);
  Jit := TXoshiro256ppJit.Create;
  try
    Raised := False;
    try
      Jit.Fill(State, nil, 1);
    except
      on E: EArgumentNilException do Raised := True;
    end;
    Assert.IsTrue(Raised);
  finally
    Jit.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TXoshiro256ppTests);

end.
