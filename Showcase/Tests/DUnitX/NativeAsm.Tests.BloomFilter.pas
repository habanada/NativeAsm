{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
unit NativeAsm.Tests.BloomFilter;

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  NativeAsm.Algorithms.BloomFilter;

type
  [TestFixture]
  TBloomFilterTests = class
  public
    [Test] procedure AddedValuesAreContained;
    [Test] procedure ClearRemovesMembership;
    [Test] procedure EmptyValueIsSupported;
    [Test] procedure BitCountRoundsToWordBoundary;
    [Test] procedure InvalidConstructorArgumentsAreRejected;
  end;

implementation

procedure TBloomFilterTests.AddedValuesAreContained;
const
  Values: array[0..5] of string = ('alpha', 'beta', 'gamma', 'delta', 'NativeAsm', 'BloomFilter');
var
  Filter: TBloomFilter;
  Data: TBytes;
  I: Integer;
begin
  Filter := TBloomFilter.Create(1 shl 16, 7);
  try
    for I := 0 to High(Values) do
    begin
      Data := TEncoding.UTF8.GetBytes(Values[I]);
      Filter.Add(Data);
    end;
    for I := 0 to High(Values) do
    begin
      Data := TEncoding.UTF8.GetBytes(Values[I]);
      Assert.IsTrue(Filter.Contains(Data), Values[I]);
    end;
  finally
    Filter.Free;
  end;
end;

procedure TBloomFilterTests.ClearRemovesMembership;
var
  Filter: TBloomFilter;
  Data: TBytes;
begin
  Data := TEncoding.ASCII.GetBytes('NativeAsm');
  Filter := TBloomFilter.Create(4096, 5);
  try
    Filter.Add(Data);
    Assert.IsTrue(Filter.Contains(Data));
    Filter.Clear;
    Assert.IsTrue(not Filter.Contains(Data));
  finally
    Filter.Free;
  end;
end;

procedure TBloomFilterTests.EmptyValueIsSupported;
var
  Filter: TBloomFilter;
  Data: TBytes;
begin
  SetLength(Data, 0);
  Filter := TBloomFilter.Create(1024, 4);
  try
    Assert.IsTrue(not Filter.Contains(Data));
    Filter.Add(Data);
    Assert.IsTrue(Filter.Contains(Data));
  finally
    Filter.Free;
  end;
end;

procedure TBloomFilterTests.BitCountRoundsToWordBoundary;
var
  Filter: TBloomFilter;
begin
  Filter := TBloomFilter.Create(65, 3);
  try
    Assert.IsTrue(Filter.BitCount = 128);
    Assert.IsTrue(Filter.HashCount = 3);
  finally
    Filter.Free;
  end;
end;

procedure TBloomFilterTests.InvalidConstructorArgumentsAreRejected;
var
  Raised: Boolean;
  Filter: TBloomFilter;
begin
  Raised := False;
  try
    Filter := TBloomFilter.Create(0, 3);
    Filter.Free;
  except
    on E: EArgumentOutOfRangeException do Raised := True;
  end;
  Assert.IsTrue(Raised);
  Raised := False;
  try
    Filter := TBloomFilter.Create(1024, 0);
    Filter.Free;
  except
    on E: EArgumentOutOfRangeException do Raised := True;
  end;
  Assert.IsTrue(Raised);
end;

initialization
  TDUnitX.RegisterTestFixture(TBloomFilterTests);

end.
