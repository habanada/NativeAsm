{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
unit NativeAsm.Tests.Levenshtein;

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  NativeAsm.Algorithms.Levenshtein;

type
  [TestFixture]
  TLevenshteinJitTests = class
  private
    function ReferenceDistance(const A, B: string): Cardinal;
    function ChangedString(const S: string; Changes, Seed: Integer): string;
  public
    [Test] procedure KnownDistances;
    [Test] procedure EmptyAndSingleCharacterCases;
    [Test] procedure DistanceIsSymmetric;
    [Test] procedure RepeatedCallsReuseInstance;
    [Test] procedure ScratchBufferCanGrowAndShrink;
    [Test] procedure DistancesReturnsEveryCandidate;
    [Test] procedure FindBestReturnsNearestCandidate;
    [Test] procedure FindBestHandlesEmptyCandidateSet;
    [Test] procedure LongStringsMatchReference;
    [Test] procedure TenLongCandidatesCanBeSearchedWithOneJit;
    [Test] procedure PrefixAndSuffixTrimmingPreservesDistance;
    [Test] procedure Utf16CodeUnitsMatchReference;
  end;

implementation

function TLevenshteinJitTests.ReferenceDistance(const A, B: string): Cardinal;
var
  Row: TArray<Cardinal>;
  I, J: Integer;
  Prev, Old, V, Candidate: Cardinal;
begin
  if Length(A) = 0 then Exit(Cardinal(Length(B)));
  if Length(B) = 0 then Exit(Cardinal(Length(A)));
  SetLength(Row, Length(A) + 1);
  for I := 0 to Length(A) do Row[I] := Cardinal(I);
  for J := 1 to Length(B) do
  begin
    Prev := Row[0];
    Row[0] := Cardinal(J);
    for I := 1 to Length(A) do
    begin
      Old := Row[I];
      if A[I] = B[J] then V := Prev else V := Prev + 1;
      Candidate := Old + 1;
      if Candidate < V then V := Candidate;
      Candidate := Row[I - 1] + 1;
      if Candidate < V then V := Candidate;
      Row[I] := V;
      Prev := Old;
    end;
  end;
  Result := Row[Length(A)];
end;

function TLevenshteinJitTests.ChangedString(const S: string; Changes, Seed: Integer): string;
var
  I, P: Integer;
begin
  Result := S;
  if Length(Result) = 0 then Exit;
  for I := 0 to Changes - 1 do
  begin
    P := 1 + ((Seed * 31 + I * 97) mod Length(Result));
    if Result[P] = 'Z' then Result[P] := 'Y' else Result[P] := 'Z';
  end;
end;

procedure TLevenshteinJitTests.KnownDistances;
var
  Jit: TLevenshteinJit;
begin
  Jit := TLevenshteinJit.Create;
  try
    Assert.IsTrue(Jit.Distance('kitten', 'sitting') = 3);
    Assert.IsTrue(Jit.Distance('flaw', 'lawn') = 2);
    Assert.IsTrue(Jit.Distance('gumbo', 'gambol') = 2);
    Assert.IsTrue(Jit.Distance('book', 'back') = 2);
    Assert.IsTrue(Jit.Distance('NativeASM', 'NativeASM') = 0);
  finally
    Jit.Free;
  end;
end;

procedure TLevenshteinJitTests.EmptyAndSingleCharacterCases;
var
  Jit: TLevenshteinJit;
begin
  Jit := TLevenshteinJit.Create;
  try
    Assert.IsTrue(Jit.Distance('', '') = 0);
    Assert.IsTrue(Jit.Distance('', 'abc') = 3);
    Assert.IsTrue(Jit.Distance('abc', '') = 3);
    Assert.IsTrue(Jit.Distance('a', 'a') = 0);
    Assert.IsTrue(Jit.Distance('a', 'b') = 1);
    Assert.IsTrue(Jit.Distance('a', 'ba') = 1);
    Assert.IsTrue(Jit.Distance('ab', 'a') = 1);
  finally
    Jit.Free;
  end;
end;

procedure TLevenshteinJitTests.DistanceIsSymmetric;
const
  Values: array[0..7] of string = ('', 'a', 'abc', 'abcd', 'axyd', 'NativeASM', 'Levenshtein', 'Delphi 12');
var
  Jit: TLevenshteinJit;
  I, K: Integer;
begin
  Jit := TLevenshteinJit.Create;
  try
    for I := Low(Values) to High(Values) do
      for K := Low(Values) to High(Values) do
        Assert.IsTrue(Jit.Distance(Values[I], Values[K]) = Jit.Distance(Values[K], Values[I]), IntToStr(I) + '/' + IntToStr(K));
  finally
    Jit.Free;
  end;
end;

procedure TLevenshteinJitTests.RepeatedCallsReuseInstance;
var
  Jit: TLevenshteinJit;
  I: Integer;
  A, B: string;
  Expected: Cardinal;
begin
  Jit := TLevenshteinJit.Create;
  try
    for I := 0 to 399 do
    begin
      A := StringOfChar(Char(Ord('a') + (I mod 4)), 32 + (I mod 97));
      B := ChangedString(A, 1 + (I mod 7), I);
      Expected := ReferenceDistance(A, B);
      Assert.IsTrue(Jit.Distance(A, B) = Expected, 'Iteration ' + IntToStr(I));
    end;
  finally
    Jit.Free;
  end;
end;

procedure TLevenshteinJitTests.ScratchBufferCanGrowAndShrink;
var
  Jit: TLevenshteinJit;
  A, B: string;
  I: Integer;
begin
  Jit := TLevenshteinJit.Create;
  try
    for I := 1 to 12 do
    begin
      A := StringOfChar('A', I * 113);
      B := ChangedString(A, I mod 9, I);
      Assert.IsTrue(Jit.Distance(A, B) = ReferenceDistance(A, B));
    end;
    for I := 12 downto 1 do
    begin
      A := StringOfChar('B', I * 61);
      B := ChangedString(A, I mod 5, I + 100);
      Assert.IsTrue(Jit.Distance(A, B) = ReferenceDistance(A, B));
    end;
  finally
    Jit.Free;
  end;
end;

procedure TLevenshteinJitTests.DistancesReturnsEveryCandidate;
var
  Jit: TLevenshteinJit;
  Candidates: TArray<string>;
  Distances: TArray<Cardinal>;
  I: Integer;
begin
  Candidates := TArray<string>.Create('nativeasm', 'native', 'asm', 'nativeasmx', 'NativeASM', 'nothing');
  Jit := TLevenshteinJit.Create;
  try
    Distances := Jit.Distances('nativeasm', Candidates);
    Assert.IsTrue(Length(Distances) = Length(Candidates));
    for I := 0 to High(Candidates) do Assert.IsTrue(Distances[I] = ReferenceDistance('nativeasm', Candidates[I]), IntToStr(I));
  finally
    Jit.Free;
  end;
end;

procedure TLevenshteinJitTests.FindBestReturnsNearestCandidate;
var
  Jit: TLevenshteinJit;
  Candidates: TArray<string>;
  Distance: Cardinal;
  Index: Integer;
begin
  Candidates := TArray<string>.Create('alpha', 'native', 'nativeasmx', 'nativeasm', 'assembler');
  Jit := TLevenshteinJit.Create;
  try
    Index := Jit.FindBest('nativeasm', Candidates, Distance);
    Assert.IsTrue(Index = 3);
    Assert.IsTrue(Distance = 0);
  finally
    Jit.Free;
  end;
end;

procedure TLevenshteinJitTests.FindBestHandlesEmptyCandidateSet;
var
  Jit: TLevenshteinJit;
  Candidates: TArray<string>;
  Distance: Cardinal;
  Index: Integer;
begin
  SetLength(Candidates, 0);
  Jit := TLevenshteinJit.Create;
  try
    Index := Jit.FindBest('nativeasm', Candidates, Distance);
    Assert.IsTrue(Index = -1);
    Assert.IsTrue(Distance = High(Cardinal));
  finally
    Jit.Free;
  end;
end;

procedure TLevenshteinJitTests.LongStringsMatchReference;
var
  Jit: TLevenshteinJit;
  A, B: string;
begin
  A := StringOfChar('A', 768) + StringOfChar('B', 768) + StringOfChar('C', 512);
  B := ChangedString(A, 23, 17);
  Jit := TLevenshteinJit.Create;
  try
    Assert.IsTrue(Jit.Distance(A, B) = ReferenceDistance(A, B));
  finally
    Jit.Free;
  end;
end;

procedure TLevenshteinJitTests.TenLongCandidatesCanBeSearchedWithOneJit;
var
  Jit: TLevenshteinJit;
  Needle: string;
  Candidates: TArray<string>;
  Distances: TArray<Cardinal>;
  Expected: array[0..9] of Cardinal;
  I, Changes, Index: Integer;
  BestDistance: Cardinal;
begin
  Needle := StringOfChar('A', 1024);
  SetLength(Candidates, 10);
  for I := 0 to 9 do
  begin
    if I = 6 then
    begin
      Candidates[I] := Needle;
      Expected[I] := 0;
    end
    else
    begin
      Changes := 1 + (I mod 5);
      Candidates[I] := ChangedString(Needle, Changes, I + 1);
      Expected[I] := Cardinal(Changes);
    end;
  end;
  Jit := TLevenshteinJit.Create;
  try
    Distances := Jit.Distances(Needle, Candidates);
    for I := 0 to 9 do Assert.IsTrue(Distances[I] = Expected[I], 'Candidate ' + IntToStr(I));
    Index := Jit.FindBest(Needle, Candidates, BestDistance);
    Assert.IsTrue(Index = 6);
    Assert.IsTrue(BestDistance = 0);
  finally
    Jit.Free;
  end;
end;

procedure TLevenshteinJitTests.PrefixAndSuffixTrimmingPreservesDistance;
var
  Jit: TLevenshteinJit;
  Prefix, Suffix, A, B: string;
begin
  Prefix := StringOfChar('P', 700);
  Suffix := StringOfChar('S', 700);
  A := Prefix + 'ABCDEFGHIJKLMN' + Suffix;
  B := Prefix + 'ABCDXFGHIYYLMN' + Suffix;
  Jit := TLevenshteinJit.Create;
  try
    Assert.IsTrue(Jit.Distance(A, B) = ReferenceDistance(A, B));
  finally
    Jit.Free;
  end;
end;

procedure TLevenshteinJitTests.Utf16CodeUnitsMatchReference;
var
  Jit: TLevenshteinJit;
  A, B: string;
begin
  A := 'A' + #$D83D#$DE00 + 'B' + #$D83D#$DE03 + 'C';
  B := 'A' + #$D83D#$DE01 + 'B' + #$D83D#$DE03 + 'D';
  Jit := TLevenshteinJit.Create;
  try
    Assert.IsTrue(Jit.Distance(A, B) = ReferenceDistance(A, B));
  finally
    Jit.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TLevenshteinJitTests);

end.
