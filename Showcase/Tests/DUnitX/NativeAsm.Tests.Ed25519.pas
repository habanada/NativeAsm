{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
unit NativeAsm.Tests.Ed25519;

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  NativeAsm.BigInt.Types,
  NativeAsm.Ecc.Types,
  NativeAsm.Ecc.Field25519,
  NativeAsm.Ecc.Ed25519,
  NativeAsm.Tests.Ecc.Common;

type
  [TestFixture]
  TEd25519Tests = class
  public
    [Test] procedure BasePointEncoding;
    [Test] procedure KnownPointMultiples;
    [Test] procedure PointAddAndDouble;
    [Test] procedure ScalarZeroIsIdentity;
    [Test] procedure Rfc8032PublicKeyTest1Scalar;
    [Test] procedure WideScalarReduction;
    [Test] procedure DecodeRejectsNonCanonical;
    [Test] procedure DecodeRejectsNegativeZero;
  end;

implementation

procedure TEd25519Tests.BasePointEncoding;
var
  C: TEd25519Curve;
  G, D: TEd25519AffinePoint;
  B: TX25519Bytes;
begin
  C := TEd25519Curve.Create;
  try
    G := C.Generator; Assert.IsTrue(C.PointIsOnCurve(G)); C.EncodePoint(G, B); TEccTestUtil.AssertX25519('5866666666666666666666666666666666666666666666666666666666666666', B); Assert.IsTrue(C.DecodePoint(B, D)); TEccTestUtil.AssertUInt256('216936D3CD6E53FEC0A4E231FDD6DC5C692CC7609525A7B2C9562D608F25D51A', D.X, 'x'); TEccTestUtil.AssertUInt256('6666666666666666666666666666666666666666666666666666666666666658', D.Y, 'y');
  finally
    C.Free;
  end;
end;

procedure TEd25519Tests.KnownPointMultiples;
var
  C: TEd25519Curve;
  S: TUInt256;
  R: TEd25519AffinePoint;
  B: TX25519Bytes;
begin
  C := TEd25519Curve.Create;
  try
    S := TEccTestUtil.UInt256('2'); C.ScalarBaseMultiply(S, R); C.EncodePoint(R, B); TEccTestUtil.AssertX25519('c9a3f86aae465f0e56513864510f3997561fa2c9e85ea21dc2292309f3cd6022', B, '2B');
    S := TEccTestUtil.UInt256('3'); C.ScalarBaseMultiply(S, R); C.EncodePoint(R, B); TEccTestUtil.AssertX25519('d4b4f5784868c3020403246717ec169ff79e26608ea126a1ab69ee77d1b16712', B, '3B');
    S := TEccTestUtil.UInt256('7'); C.ScalarBaseMultiply(S, R); C.EncodePoint(R, B); TEccTestUtil.AssertX25519('b862409fb5c4c4123df2abf7462b88f041ad36dd6864ce872fd5472be363c5b1', B, '7B');
  finally
    C.Free;
  end;
end;

procedure TEd25519Tests.PointAddAndDouble;
var
  C: TEd25519Curve;
  G, A, D: TEd25519AffinePoint;
  BA, BD: TX25519Bytes;
begin
  C := TEd25519Curve.Create;
  try
    G := C.Generator; C.PointAdd(G, G, A); C.PointDouble(G, D); C.EncodePoint(A, BA); C.EncodePoint(D, BD); Assert.AreEqual(TEccTestUtil.X25519ToHex(BA), TEccTestUtil.X25519ToHex(BD)); TEccTestUtil.AssertX25519('c9a3f86aae465f0e56513864510f3997561fa2c9e85ea21dc2292309f3cd6022', BA);
  finally
    C.Free;
  end;
end;

procedure TEd25519Tests.ScalarZeroIsIdentity;
var
  C: TEd25519Curve;
  S: TUInt256;
  R: TEd25519AffinePoint;
  B: TX25519Bytes;
begin
  FillChar(S, SizeOf(S), 0); C := TEd25519Curve.Create;
  try
    C.ScalarBaseMultiply(S, R); Assert.IsTrue(C.IsIdentity(R)); C.EncodePoint(R, B); TEccTestUtil.AssertX25519('0100000000000000000000000000000000000000000000000000000000000000', B);
  finally
    C.Free;
  end;
end;

procedure TEd25519Tests.Rfc8032PublicKeyTest1Scalar;
var
  C: TEd25519Curve;
  H, Enc: TX25519Bytes;
  S: TUInt256;
  R: TEd25519AffinePoint;
begin
  H := TEccTestUtil.X25519Bytes('307c83864f2833cb427a2ef1c00a013cfdff2768d980c0a3a520f006904de94f'); C := TEd25519Curve.Create;
  try
    C.Field.ScalarReduceBytesLE(H, S); C.ScalarBaseMultiply(S, R); C.EncodePoint(R, Enc); TEccTestUtil.AssertX25519('d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a', Enc);
  finally
    C.Free;
  end;
end;

procedure TEd25519Tests.WideScalarReduction;
var
  F: TField25519;
  B: TEccBytes64;
  R: TUInt256;
  I: Integer;
begin
  for I := 0 to 63 do B[I] := Byte(I); F := TField25519.Create;
  try
    F.ScalarReduce64LE(B, R); TEccTestUtil.AssertUInt256('0572D0E474B5E0DA7A932112C3D46159CCE628540DB62350A0372DF082623C7A', R);
  finally
    F.Free;
  end;
end;

procedure TEd25519Tests.DecodeRejectsNonCanonical;
var
  C: TEd25519Curve;
  B: TX25519Bytes;
  P: TEd25519AffinePoint;
begin
  FillChar(B, SizeOf(B), $FF); B[31] := $7F; C := TEd25519Curve.Create;
  try
    Assert.IsFalse(C.DecodePoint(B, P));
  finally
    C.Free;
  end;
end;

procedure TEd25519Tests.DecodeRejectsNegativeZero;
var
  C: TEd25519Curve;
  B: TX25519Bytes;
  P: TEd25519AffinePoint;
begin
  FillChar(B, SizeOf(B), 0); B[0] := 1; B[31] := $80; C := TEd25519Curve.Create;
  try
    Assert.IsFalse(C.DecodePoint(B, P));
  finally
    C.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TEd25519Tests);

end.
