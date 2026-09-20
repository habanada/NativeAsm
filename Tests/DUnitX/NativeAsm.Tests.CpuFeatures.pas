{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
unit NativeAsm.Tests.CpuFeatures;

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  NativeAsm.CpuFeatures;

type
  [TestFixture]
  TCpuFeaturesTests = class
  private
    function ExpectedSupport(Feature: TCpuFeature): Boolean;
  public
    [Test] procedure FeatureNamesAreExact;
    [Test] procedure FeatureNamesAreUnique;
    [Test] procedure EveryFeatureMatchesDirectCpuid;
    [Test] procedure RepeatedQueriesAreStable;
    [Test] procedure QueryOrderDoesNotChangeResults;
  end;

implementation

function TCpuFeaturesTests.ExpectedSupport(Feature: TCpuFeature): Boolean;
var
  R: System.TCPUIDRec;
begin
  Result := False;
  case Feature of
    cfAES, cfSSE2, cfSSSE3, cfSSE42, cfPOPCNT, cfPCLMULQDQ:
      begin
        R := System.GetCPUID(0);
        if R.EAX < 1 then Exit;
        R := System.GetCPUID(1);
        case Feature of
          cfAES: Result := (R.ECX and $02000000) <> 0;
          cfSSE2: Result := (R.EDX and $04000000) <> 0;
          cfSSSE3: Result := (R.ECX and $00000200) <> 0;
          cfSSE42: Result := (R.ECX and $00100000) <> 0;
          cfPOPCNT: Result := (R.ECX and $00800000) <> 0;
          cfPCLMULQDQ: Result := (R.ECX and $00000002) <> 0;
        end;
      end;
    cfSHA, cfBMI1:
      begin
        R := System.GetCPUID(0);
        if R.EAX < 7 then Exit;
        R := System.GetCPUID(7, 0);
        if Feature = cfSHA then Result := (R.EBX and $20000000) <> 0 else Result := (R.EBX and $00000008) <> 0;
      end;
    cfLZCNT:
      begin
        R := System.GetCPUID($80000000);
        if R.EAX < $80000001 then Exit;
        R := System.GetCPUID($80000001);
        Result := (R.ECX and $00000020) <> 0;
      end;
  end;
end;

procedure TCpuFeaturesTests.FeatureNamesAreExact;
begin
  Assert.IsTrue(TCpuFeatures.Name(cfAES) = 'AES');
  Assert.IsTrue(TCpuFeatures.Name(cfSHA) = 'SHA');
  Assert.IsTrue(TCpuFeatures.Name(cfLZCNT) = 'LZCNT');
  Assert.IsTrue(TCpuFeatures.Name(cfBMI1) = 'BMI1');
  Assert.IsTrue(TCpuFeatures.Name(cfSSE2) = 'SSE2');
  Assert.IsTrue(TCpuFeatures.Name(cfSSSE3) = 'SSSE3');
  Assert.IsTrue(TCpuFeatures.Name(cfSSE42) = 'SSE4.2');
  Assert.IsTrue(TCpuFeatures.Name(cfPOPCNT) = 'POPCNT');
  Assert.IsTrue(TCpuFeatures.Name(cfPCLMULQDQ) = 'PCLMULQDQ');
end;

procedure TCpuFeaturesTests.FeatureNamesAreUnique;
var
  A, B: TCpuFeature;
begin
  for A := Low(TCpuFeature) to High(TCpuFeature) do
    for B := Low(TCpuFeature) to High(TCpuFeature) do
      if A <> B then Assert.IsTrue(not SameText(TCpuFeatures.Name(A), TCpuFeatures.Name(B)), TCpuFeatures.Name(A) + ' duplicates ' + TCpuFeatures.Name(B));
end;

procedure TCpuFeaturesTests.EveryFeatureMatchesDirectCpuid;
var
  Feature: TCpuFeature;
begin
  for Feature := Low(TCpuFeature) to High(TCpuFeature) do
    Assert.IsTrue(TCpuFeatures.Supports(Feature) = ExpectedSupport(Feature), 'CPUID mismatch for ' + TCpuFeatures.Name(Feature));
end;

procedure TCpuFeaturesTests.RepeatedQueriesAreStable;
var
  Feature: TCpuFeature;
  Expected: Boolean;
  I: Integer;
begin
  for Feature := Low(TCpuFeature) to High(TCpuFeature) do
  begin
    Expected := TCpuFeatures.Supports(Feature);
    for I := 1 to 512 do Assert.IsTrue(TCpuFeatures.Supports(Feature) = Expected, 'Unstable result for ' + TCpuFeatures.Name(Feature));
  end;
end;

procedure TCpuFeaturesTests.QueryOrderDoesNotChangeResults;
var
  Expected: array[TCpuFeature] of Boolean;
  Feature: TCpuFeature;
  I: Integer;
begin
  for Feature := Low(TCpuFeature) to High(TCpuFeature) do Expected[Feature] := TCpuFeatures.Supports(Feature);
  for I := 1 to 128 do
    for Feature := High(TCpuFeature) downto Low(TCpuFeature) do Assert.IsTrue(TCpuFeatures.Supports(Feature) = Expected[Feature]);
end;

initialization
  TDUnitX.RegisterTestFixture(TCpuFeaturesTests);

end.
