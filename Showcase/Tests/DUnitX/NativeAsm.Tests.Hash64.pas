{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
unit NativeAsm.Tests.Hash64;

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  NativeAsm.Algorithms.Hash64;

type
  [TestFixture]
  THash64Tests = class
  private
    class function ReferenceHash(const Data: TBytes; Initial: UInt64): UInt64; static;
    class function ReferenceMix(Value: UInt64): UInt64; static;
  public
    [Test] procedure Fnv1aKnownVectors;
    [Test] procedure StreamingMatchesSinglePass;
    [Test] procedure MixMatchesReference;
    [Test] procedure EmptyBufferUsesInitialValue;
    [Test] procedure NonEmptyNilIsRejected;
  end;

implementation

class function THash64Tests.ReferenceHash(const Data: TBytes; Initial: UInt64): UInt64;
var
  I: Integer;
begin
  Result := Initial;
  for I := 0 to High(Data) do
  begin
    Result := Result xor Data[I];
    Result := Result * THash64Jit.Fnv1aPrime;
  end;
end;

class function THash64Tests.ReferenceMix(Value: UInt64): UInt64;
begin
  Result := Value;
  Result := (Result xor (Result shr 30)) * UInt64($BF58476D1CE4E5B9);
  Result := (Result xor (Result shr 27)) * UInt64($94D049BB133111EB);
  Result := Result xor (Result shr 31);
end;

procedure THash64Tests.Fnv1aKnownVectors;
var
  Jit: THash64Jit;
begin
  Jit := THash64Jit.Create;
  try
    Assert.IsTrue(Jit.Hash(TEncoding.ASCII.GetBytes('')) = UInt64($CBF29CE484222325));
    Assert.IsTrue(Jit.Hash(TEncoding.ASCII.GetBytes('a')) = UInt64($AF63DC4C8601EC8C));
    Assert.IsTrue(Jit.Hash(TEncoding.ASCII.GetBytes('foobar')) = UInt64($85944171F73967E8));
    Assert.IsTrue(Jit.Hash(TEncoding.ASCII.GetBytes('hello')) = UInt64($A430D84680AABD0B));
  finally
    Jit.Free;
  end;
end;

procedure THash64Tests.StreamingMatchesSinglePass;
var
  Jit: THash64Jit;
  A, B, All: TBytes;
  H: UInt64;
begin
  A := TEncoding.ASCII.GetBytes('NativeAsm ');
  B := TEncoding.ASCII.GetBytes('streaming hash');
  All := TEncoding.ASCII.GetBytes('NativeAsm streaming hash');
  Jit := THash64Jit.Create;
  try
    H := Jit.Hash(A);
    H := Jit.Hash(B, H);
    Assert.IsTrue(H = Jit.Hash(All));
  finally
    Jit.Free;
  end;
end;

procedure THash64Tests.MixMatchesReference;
const
  Values: array[0..5] of UInt64 = (0, 1, $FFFFFFFFFFFFFFFF, $0123456789ABCDEF, $9E3779B97F4A7C15, $CBF29CE484222325);
var
  Jit: THash64Jit;
  I: Integer;
begin
  Jit := THash64Jit.Create;
  try
    for I := 0 to High(Values) do Assert.IsTrue(Jit.Mix(Values[I]) = ReferenceMix(Values[I]), IntToStr(I));
  finally
    Jit.Free;
  end;
end;

procedure THash64Tests.EmptyBufferUsesInitialValue;
var
  Jit: THash64Jit;
begin
  Jit := THash64Jit.Create;
  try
    Assert.IsTrue(Jit.Hash(nil, 0, $123456789ABCDEF0) = UInt64($123456789ABCDEF0));
  finally
    Jit.Free;
  end;
end;

procedure THash64Tests.NonEmptyNilIsRejected;
var
  Jit: THash64Jit;
  Raised: Boolean;
begin
  Jit := THash64Jit.Create;
  try
    Raised := False;
    try
      Jit.Hash(nil, 1);
    except
      on E: EArgumentNilException do Raised := True;
    end;
    Assert.IsTrue(Raised);
  finally
    Jit.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(THash64Tests);

end.
