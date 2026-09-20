{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
unit NativeAsm.Tests.AhoCorasick;

interface

uses
  System.SysUtils,
  System.StrUtils,
  DUnitX.TestFramework,
  NativeAsm.Practical.AhoCorasick;

type
  [TestFixture]
  TAhoCorasickJitTests = class
  private
    class function HasMatch(const Matches: TArray<TAhoMatch>; PatternIndex, StartIndex, EndIndex: Integer): Boolean; static;
    class function NaiveCount(const Patterns: array of string; const Text: string): UInt64; static;
    class function NextRandom(var State: Cardinal): Cardinal; static;
    class function RandomString(var State: Cardinal; Len, Alphabet: Integer): string; static;
  public
    [Test] procedure ClassicFailureLinksAndOutputs;
    [Test] procedure OverlappingMatchesAreAllReported;
    [Test] procedure DuplicatePatternsRemainDistinct;
    [Test] procedure EmptyPatternIsRejected;
    [Test] procedure MoreThan64PatternsIsRejected;
    [Test] procedure AutoSimdModeIsActiveForTenPatterns;
    [Test] procedure AutoSelectsBestAvailableSimdPath;
    [Test] procedure Sse2RootScanSkipsLongNonCandidateRuns;
    [Test] procedure ScalarFallbackHandlesMoreThanSixteenRootCharacters;
    [Test] procedure RepeatedSearchesReuseTheSameJit;
    [Test] procedure MatchBufferGrowsPastInitialCapacity;
    [Test] procedure FindFirstContainsAndCountAgree;
    [Test] procedure Utf16IndexesFollowDelphiCodeUnits;
    [Test] procedure TenLongPatternsCanBeSearchedRepeatedly;
    [Test] procedure RandomTextsMatchNaiveReferenceCounts;
    [Test] procedure SixtyFourPatternOutputMaskWorksAtHighestBit;
    [Test] procedure EmptyPatternSetProducesNoMatches;
  end;

implementation

class function TAhoCorasickJitTests.HasMatch(const Matches: TArray<TAhoMatch>; PatternIndex, StartIndex, EndIndex: Integer): Boolean;
var
  M: TAhoMatch;
begin
  for M in Matches do
    if (M.PatternIndex = PatternIndex) and (M.StartIndex = StartIndex) and (M.EndIndex = EndIndex) then Exit(True);
  Result := False;
end;

class function TAhoCorasickJitTests.NaiveCount(const Patterns: array of string; const Text: string): UInt64;
var
  I, P: Integer;
begin
  Result := 0;
  for I := 0 to High(Patterns) do
  begin
    P := 1;
    while P <= Length(Text) do
    begin
      P := PosEx(Patterns[I], Text, P);
      if P = 0 then Break;
      Inc(Result);
      Inc(P);
    end;
  end;
end;

class function TAhoCorasickJitTests.NextRandom(var State: Cardinal): Cardinal;
begin
  State := State * 1664525 + 1013904223;
  Result := State;
end;

class function TAhoCorasickJitTests.RandomString(var State: Cardinal; Len, Alphabet: Integer): string;
var
  I: Integer;
begin
  SetLength(Result, Len);
  for I := 1 to Len do Result[I] := Char(Ord('a') + Integer(NextRandom(State) mod Cardinal(Alphabet)));
end;

procedure TAhoCorasickJitTests.ClassicFailureLinksAndOutputs;
var
  Jit: TAhoCorasickJit;
  Matches: TArray<TAhoMatch>;
begin
  Jit := TAhoCorasickJit.Create(['he', 'she', 'his', 'hers']);
  try
    Matches := Jit.FindAll('ushers');
    Assert.IsTrue(Length(Matches) = 3);
    Assert.IsTrue(HasMatch(Matches, 1, 2, 4));
    Assert.IsTrue(HasMatch(Matches, 0, 3, 4));
    Assert.IsTrue(HasMatch(Matches, 3, 3, 6));
  finally
    Jit.Free;
  end;
end;

procedure TAhoCorasickJitTests.OverlappingMatchesAreAllReported;
var
  Jit: TAhoCorasickJit;
  Matches: TArray<TAhoMatch>;
begin
  Jit := TAhoCorasickJit.Create(['a', 'aa', 'aaa']);
  try
    Matches := Jit.FindAll('aaaa');
    Assert.IsTrue(Length(Matches) = 9);
    Assert.IsTrue(HasMatch(Matches, 0, 1, 1));
    Assert.IsTrue(HasMatch(Matches, 1, 1, 2));
    Assert.IsTrue(HasMatch(Matches, 2, 1, 3));
    Assert.IsTrue(HasMatch(Matches, 2, 2, 4));
  finally
    Jit.Free;
  end;
end;

procedure TAhoCorasickJitTests.DuplicatePatternsRemainDistinct;
var
  Jit: TAhoCorasickJit;
  Matches: TArray<TAhoMatch>;
begin
  Jit := TAhoCorasickJit.Create(['aba', 'aba']);
  try
    Matches := Jit.FindAll('ababa');
    Assert.IsTrue(Length(Matches) = 4);
    Assert.IsTrue(HasMatch(Matches, 0, 1, 3));
    Assert.IsTrue(HasMatch(Matches, 1, 1, 3));
    Assert.IsTrue(HasMatch(Matches, 0, 3, 5));
    Assert.IsTrue(HasMatch(Matches, 1, 3, 5));
  finally
    Jit.Free;
  end;
end;

procedure TAhoCorasickJitTests.EmptyPatternIsRejected;
var
  Jit: TAhoCorasickJit;
begin
  Jit := nil;
  try
    try
      Jit := TAhoCorasickJit.Create(['abc', '']);
      Assert.Fail('Expected EArgumentException');
    except
      on E: EArgumentException do Assert.IsTrue(Pos('empty', LowerCase(E.Message)) > 0);
    end;
  finally
    Jit.Free;
  end;
end;

procedure TAhoCorasickJitTests.MoreThan64PatternsIsRejected;
var
  Patterns: TArray<string>;
  I: Integer;
  Jit: TAhoCorasickJit;
begin
  SetLength(Patterns, 65);
  for I := 0 to High(Patterns) do Patterns[I] := 'p' + IntToStr(I);
  Jit := nil;
  try
    try
      Jit := TAhoCorasickJit.Create(Patterns);
      Assert.Fail('Expected EArgumentOutOfRangeException');
    except
      on E: EArgumentOutOfRangeException do Assert.IsTrue(Pos('64', E.Message) > 0);
    end;
  finally
    Jit.Free;
  end;
end;

procedure TAhoCorasickJitTests.AutoSimdModeIsActiveForTenPatterns;
var
  Patterns: TArray<string>;
  I: Integer;
  Jit: TAhoCorasickJit;
begin
  SetLength(Patterns, 10);
  for I := 0 to 9 do Patterns[I] := Char(Ord('A') + I) + StringOfChar(Char(Ord('a') + I), 31);
  Jit := TAhoCorasickJit.Create(Patterns);
  try
    Assert.IsTrue(Jit.UsesSimdRootScan);
    Assert.IsTrue(Jit.PatternCount = 10);
    Assert.IsTrue(Jit.AlphabetSize >= 10);
    Assert.IsTrue(Jit.StateCount > 10);
  finally
    Jit.Free;
  end;
end;

procedure TAhoCorasickJitTests.AutoSelectsBestAvailableSimdPath;
var
  Jit: TAhoCorasickJit;
begin
  Jit := TAhoCorasickJit.Create(['alpha', 'beta', 'gamma']);
  try
    if TAhoCorasickJit.IsSse42Available then Assert.IsTrue(Jit.SimdMode = smSse42) else Assert.IsTrue(Jit.SimdMode = smSse2);
  finally
    Jit.Free;
  end;
end;

procedure TAhoCorasickJitTests.Sse2RootScanSkipsLongNonCandidateRuns;
var
  Patterns: TArray<string>;
  Text: string;
  Jit: TAhoCorasickJit;
  Matches: TArray<TAhoMatch>;
begin
  Patterns := TArray<string>.Create('AlphaNeedle', 'BetaNeedle', 'GammaNeedle', 'DeltaNeedle');
  Text := StringOfChar('x', 8192) + 'GammaNeedle' + StringOfChar('x', 4096) + 'AlphaNeedle';
  Jit := TAhoCorasickJit.Create(Patterns, smSse2);
  try
    Assert.IsTrue(Jit.UsesSimdRootScan);
    Assert.IsTrue(Jit.SimdMode = smSse2);
    Matches := Jit.FindAll(Text);
    Assert.IsTrue(Length(Matches) = 2);
    Assert.IsTrue(HasMatch(Matches, 2, 8193, 8203));
    Assert.IsTrue(HasMatch(Matches, 0, 12300, 12310));
  finally
    Jit.Free;
  end;
end;

procedure TAhoCorasickJitTests.ScalarFallbackHandlesMoreThanSixteenRootCharacters;
var
  Patterns: TArray<string>;
  I: Integer;
  Jit: TAhoCorasickJit;
  Matches: TArray<TAhoMatch>;
begin
  SetLength(Patterns, 17);
  for I := 0 to 16 do Patterns[I] := Char($0100 + I) + 'needle';
  Jit := TAhoCorasickJit.Create(Patterns);
  try
    Assert.IsFalse(Jit.UsesSimdRootScan);
    Matches := Jit.FindAll('xx' + Patterns[16] + 'yy');
    Assert.IsTrue(Length(Matches) = 1);
    Assert.IsTrue(Matches[0].PatternIndex = 16);
    Assert.IsTrue(Matches[0].StartIndex = 3);
  finally
    Jit.Free;
  end;
end;

procedure TAhoCorasickJitTests.RepeatedSearchesReuseTheSameJit;
var
  Jit: TAhoCorasickJit;
  I: Integer;
  Text: string;
begin
  Jit := TAhoCorasickJit.Create(['native', 'asm', 'jit', 'builder', 'encoder']);
  try
    for I := 0 to 299 do
    begin
      Text := StringOfChar('x', I mod 73) + 'native' + StringOfChar('y', I mod 41) + 'jit';
      Assert.IsTrue(Jit.CountMatches(Text) = 2, 'Iteration ' + IntToStr(I));
    end;
  finally
    Jit.Free;
  end;
end;

procedure TAhoCorasickJitTests.MatchBufferGrowsPastInitialCapacity;
var
  Jit: TAhoCorasickJit;
  Matches: TArray<TAhoMatch>;
begin
  Jit := TAhoCorasickJit.Create(['a', 'aa']);
  try
    Matches := Jit.FindAll(StringOfChar('a', 512));
    Assert.IsTrue(Length(Matches) = 1023);
    Assert.IsTrue(Jit.CountMatches(StringOfChar('a', 512)) = 1023);
  finally
    Jit.Free;
  end;
end;

procedure TAhoCorasickJitTests.FindFirstContainsAndCountAgree;
var
  Jit: TAhoCorasickJit;
  M: TAhoMatch;
  Text: string;
begin
  Jit := TAhoCorasickJit.Create(['alpha', 'beta', 'gamma']);
  try
    Text := StringOfChar('x', 100) + 'beta' + StringOfChar('x', 20) + 'alpha';
    Assert.IsTrue(Jit.Contains(Text));
    Assert.IsTrue(Jit.CountMatches(Text) = 2);
    Assert.IsTrue(Jit.FindFirst(Text, M));
    Assert.IsTrue(M.PatternIndex = 1);
    Assert.IsTrue(M.StartIndex = 101);
    Assert.IsFalse(Jit.Contains(StringOfChar('x', 500)));
    Assert.IsFalse(Jit.FindFirst('', M));
  finally
    Jit.Free;
  end;
end;

procedure TAhoCorasickJitTests.Utf16IndexesFollowDelphiCodeUnits;
var
  Emoji, Text: string;
  Jit: TAhoCorasickJit;
  Matches: TArray<TAhoMatch>;
begin
  Emoji := #$D83D#$DE00;
  Text := 'A' + Emoji + 'B' + Emoji + 'C';
  Jit := TAhoCorasickJit.Create([Emoji, 'B' + Emoji]);
  try
    Matches := Jit.FindAll(Text);
    Assert.IsTrue(Length(Matches) = 3);
    Assert.IsTrue(HasMatch(Matches, 0, 2, 3));
    Assert.IsTrue(HasMatch(Matches, 1, 4, 6));
    Assert.IsTrue(HasMatch(Matches, 0, 5, 6));
  finally
    Jit.Free;
  end;
end;

procedure TAhoCorasickJitTests.TenLongPatternsCanBeSearchedRepeatedly;
var
  Patterns: TArray<string>;
  Text: string;
  Jit: TAhoCorasickJit;
  Matches: TArray<TAhoMatch>;
  I, K: Integer;
begin
  SetLength(Patterns, 10);
  for I := 0 to 9 do Patterns[I] := Char(Ord('A') + I) + StringOfChar(Char(Ord('k') + I), 255);
  Text := StringOfChar('x', 4096) + Patterns[2] + StringOfChar('x', 2048) + Patterns[7] + StringOfChar('x', 1024);
  Jit := TAhoCorasickJit.Create(Patterns);
  try
    Assert.IsTrue(Jit.UsesSimdRootScan);
    for K := 0 to 39 do
    begin
      Matches := Jit.FindAll(Text);
      Assert.IsTrue(Length(Matches) = 2, 'Iteration ' + IntToStr(K));
      Assert.IsTrue(HasMatch(Matches, 2, 4097, 4352));
      Assert.IsTrue(HasMatch(Matches, 7, 6401, 6656));
    end;
  finally
    Jit.Free;
  end;
end;

procedure TAhoCorasickJitTests.RandomTextsMatchNaiveReferenceCounts;
var
  Patterns: TArray<string>;
  State: Cardinal;
  Jit: TAhoCorasickJit;
  Text: string;
  I: Integer;
  Expected, Actual: UInt64;
begin
  State := $C001D00D;
  SetLength(Patterns, 10);
  for I := 0 to 9 do Patterns[I] := RandomString(State, 2 + Integer(NextRandom(State) mod 7), 4);
  Jit := TAhoCorasickJit.Create(Patterns);
  try
    Assert.IsTrue(Jit.UsesSimdRootScan);
    for I := 0 to 199 do
    begin
      Text := RandomString(State, 16 + Integer(NextRandom(State) mod 240), 6);
      Expected := NaiveCount(Patterns, Text);
      Actual := Jit.CountMatches(Text);
      Assert.IsTrue(Actual = Expected, 'Iteration ' + IntToStr(I) + ': ' + UIntToStr(Actual) + '/' + UIntToStr(Expected));
    end;
  finally
    Jit.Free;
  end;
end;

procedure TAhoCorasickJitTests.SixtyFourPatternOutputMaskWorksAtHighestBit;
var
  Patterns: TArray<string>;
  I: Integer;
  Jit: TAhoCorasickJit;
  Matches: TArray<TAhoMatch>;
begin
  SetLength(Patterns, 64);
  for I := 0 to 63 do Patterns[I] := 'prefix_' + IntToStr(I) + '_suffix';
  Jit := TAhoCorasickJit.Create(Patterns);
  try
    Matches := Jit.FindAll('xx' + Patterns[63] + 'yy');
    Assert.IsTrue(HasMatch(Matches, 63, 3, 2 + Length(Patterns[63])));
  finally
    Jit.Free;
  end;
end;

procedure TAhoCorasickJitTests.EmptyPatternSetProducesNoMatches;
var
  Patterns: TArray<string>;
  Jit: TAhoCorasickJit;
  Matches: TArray<TAhoMatch>;
begin
  SetLength(Patterns, 0);
  Jit := TAhoCorasickJit.Create(Patterns);
  try
    Matches := Jit.FindAll(StringOfChar('x', 1024));
    Assert.IsTrue(Length(Matches) = 0);
    Assert.IsTrue(Jit.CountMatches('anything') = 0);
    Assert.IsFalse(Jit.Contains('anything'));
    Assert.IsFalse(Jit.UsesSimdRootScan);
  finally
    Jit.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TAhoCorasickJitTests);

end.
