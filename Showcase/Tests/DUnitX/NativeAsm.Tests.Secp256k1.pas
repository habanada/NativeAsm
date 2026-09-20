{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
unit NativeAsm.Tests.Secp256k1;

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  NativeAsm.BigInt.Types,
  NativeAsm.Ecc.Types,
  NativeAsm.Ecc.Secp256k1,
  NativeAsm.Tests.Ecc.Common;

type
  [TestFixture]
  TSecp256k1Tests = class
  public
    [Test] procedure DomainParametersAndEncoding;
    [Test] procedure KnownPointMultiples;
    [Test] procedure PointAddAndDouble;
    [Test] procedure PointAddInverseAndInfinity;
    [Test] procedure LargeScalarVector;
    [Test] procedure FieldArithmetic;
    [Test] procedure ScalarArithmetic;
    [Test] procedure ScalarBoundaries;
    [Test] procedure PointDecodeRejectsInvalid;
  end;

implementation

procedure TSecp256k1Tests.DomainParametersAndEncoding;
var
  C: TSecp256k1Curve;
  G, D: TEccAffinePoint256;
  B: TBytes;
begin
  C := TSecp256k1Curve.Create;
  try
    G := C.Generator; Assert.IsTrue(C.PointIsOnCurve(G)); TEccTestUtil.AssertPoint('79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798', '483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8', G);
    B := C.EncodePointCompressed(G); TEccTestUtil.AssertBytes('0279BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798', B, 'compressed'); Assert.IsTrue(C.DecodePoint(@B[0], Length(B), D)); TEccTestUtil.AssertPoint(TEccTestUtil.ToHex(G.X), TEccTestUtil.ToHex(G.Y), D, 'decode compressed');
    B := C.EncodePointUncompressed(G); TEccTestUtil.AssertBytes('0479BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8', B, 'uncompressed'); Assert.IsTrue(C.DecodePoint(@B[0], Length(B), D));
  finally
    C.Free;
  end;
end;

procedure TSecp256k1Tests.KnownPointMultiples;
var
  C: TSecp256k1Curve;
  S: TUInt256;
  R: TEccAffinePoint256;
begin
  C := TSecp256k1Curve.Create;
  try
    S := TEccTestUtil.UInt256('2'); C.ScalarBaseMultiply(S, R); TEccTestUtil.AssertPoint('C6047F9441ED7D6D3045406E95C07CD85C778E4B8CEF3CA7ABAC09B95C709EE5', '1AE168FEA63DC339A3C58419466CEAEEF7F632653266D0E1236431A950CFE52A', R, '2G');
    S := TEccTestUtil.UInt256('3'); C.ScalarBaseMultiply(S, R); TEccTestUtil.AssertPoint('F9308A019258C31049344F85F89D5229B531C845836F99B08601F113BCE036F9', '388F7B0F632DE8140FE337E62A37F3566500A99934C2231B6CB9FD7584B8E672', R, '3G');
    S := TEccTestUtil.UInt256('7'); C.ScalarBaseMultiply(S, R); TEccTestUtil.AssertPoint('5CBDF0646E5DB4EAA398F365F2EA7A0E3D419B7E0330E39CE92BDDEDCAC4F9BC', '6AEBCA40BA255960A3178D6D861A54DBA813D0B813FDE7B5A5082628087264DA', R, '7G');
  finally
    C.Free;
  end;
end;

procedure TSecp256k1Tests.PointAddAndDouble;
var
  C: TSecp256k1Curve;
  G, A, D: TEccAffinePoint256;
begin
  C := TSecp256k1Curve.Create;
  try
    G := C.Generator; C.PointAdd(G, G, A); C.PointDouble(G, D); TEccTestUtil.AssertPoint('C6047F9441ED7D6D3045406E95C07CD85C778E4B8CEF3CA7ABAC09B95C709EE5', '1AE168FEA63DC339A3C58419466CEAEEF7F632653266D0E1236431A950CFE52A', A); Assert.AreEqual(TEccTestUtil.ToHex(A.X), TEccTestUtil.ToHex(D.X)); Assert.AreEqual(TEccTestUtil.ToHex(A.Y), TEccTestUtil.ToHex(D.Y));
  finally
    C.Free;
  end;
end;

procedure TSecp256k1Tests.PointAddInverseAndInfinity;
var
  C: TSecp256k1Curve;
  G, N, R, I: TEccAffinePoint256;
begin
  C := TSecp256k1Curve.Create;
  try
    G := C.Generator; N := G; C.FieldNegate(N.Y, G.Y); C.PointAdd(G, N, R); Assert.IsTrue(R.Infinity); FillChar(I, SizeOf(I), 0); I.Infinity := True; C.PointAdd(G, I, R); TEccTestUtil.AssertPoint(TEccTestUtil.ToHex(G.X), TEccTestUtil.ToHex(G.Y), R); C.PointAdd(I, G, R); TEccTestUtil.AssertPoint(TEccTestUtil.ToHex(G.X), TEccTestUtil.ToHex(G.Y), R);
  finally
    C.Free;
  end;
end;

procedure TSecp256k1Tests.LargeScalarVector;
var
  C: TSecp256k1Curve;
  S: TUInt256;
  R: TEccAffinePoint256;
begin
  S := TEccTestUtil.UInt256('000123456789ABCDEF123456789ABCDEF123456789ABCDEF123456789ABCDEF'); C := TSecp256k1Curve.Create;
  try
    C.ScalarBaseMultiply(S, R); TEccTestUtil.AssertPoint('B16FB8AD81355A14322355966EFC4270F8E9DEFBAB8814B2DC4F6B27D92BBCFF', '628617D757C9C2AB7B507613CADF833461DB5A983FE64715B44D59826FD126CF', R);
  finally
    C.Free;
  end;
end;

procedure TSecp256k1Tests.FieldArithmetic;
var
  C: TSecp256k1Curve;
  A, B, R, T: TUInt256;
begin
  A := TEccTestUtil.UInt256('0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF'); B := TEccTestUtil.UInt256('0FEDCBA9876543210FEDCBA9876543210FEDCBA9876543210FEDCBA987654321'); C := TSecp256k1Curve.Create;
  try
    C.FieldAdd(R, A, B); TEccTestUtil.AssertUInt256('1111111111111110111111111111111011111111111111101111111111111110', R, 'add');
    C.FieldSub(R, A, B); TEccTestUtil.AssertUInt256('F13579BE02468ACDF13579BE02468ACDF13579BE02468ACDF13579BD024686FD', R, 'sub');
    C.FieldMul(R, A, B); TEccTestUtil.AssertUInt256('D8C644419C8C50984E1E06F7BC8EBDB3C375C9ADDC912ACF38DFAC03B8D5F33C', R, 'mul');
    C.FieldInverse(R, A); TEccTestUtil.AssertUInt256('F37164D6FF61ED527289824F2AAC8343CA55B3C9EEABE44CD6379ACBC0BA895D', R, 'inv'); C.FieldMul(T, A, R); TEccTestUtil.AssertUInt256('0000000000000000000000000000000000000000000000000000000000000001', T, 'inverse product');
  finally
    C.Free;
  end;
end;

procedure TSecp256k1Tests.ScalarArithmetic;
var
  C: TSecp256k1Curve;
  A, B, R, T: TUInt256;
begin
  A := TEccTestUtil.UInt256('0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF'); B := TEccTestUtil.UInt256('0FEDCBA9876543210FEDCBA9876543210FEDCBA9876543210FEDCBA987654321'); C := TSecp256k1Curve.Create;
  try
    C.ScalarAdd(R, A, B); TEccTestUtil.AssertUInt256('1111111111111110111111111111111011111111111111101111111111111110', R, 'add');
    C.ScalarSub(R, A, B); TEccTestUtil.AssertUInt256('F13579BE02468ACDF13579BE02468ACCABE456A4B18F2B09B107D84AD27CCC0F', R, 'sub');
    C.ScalarMul(R, A, B); TEccTestUtil.AssertUInt256('7A5393281D581EAC38AA0B5B7A460397C7D88905869E45FF93F80A9AB4DF6E66', R, 'mul');
    C.ScalarInverse(R, A); TEccTestUtil.AssertUInt256('2B359DE5CFB5937A5610D565DCEAEF2A760CEEAEC96E68140757F0C8371534E0', R, 'inv'); C.ScalarMul(T, A, R); TEccTestUtil.AssertUInt256('0000000000000000000000000000000000000000000000000000000000000001', T, 'inverse product');
  finally
    C.Free;
  end;
end;

procedure TSecp256k1Tests.ScalarBoundaries;
var
  C: TSecp256k1Curve;
  N, Nm1, One: TUInt256;
  R: TEccAffinePoint256;
  Raised: Boolean;
begin
  C := TSecp256k1Curve.Create;
  try
    N := C.ScalarOrder; One := TEccTestUtil.UInt256('1'); C.ScalarNegate(Nm1, One); Assert.IsTrue(C.ScalarIsCanonical(Nm1)); Assert.IsFalse(C.ScalarIsCanonical(N)); C.ScalarBaseMultiply(Nm1, R); TEccTestUtil.AssertPoint('79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798', 'B7C52588D95C3B9AA25B0403F1EEF75702E84BB7597AABE663B82F6F04EF2777', R, '(n-1)G');
    Raised := False; try C.ScalarBaseMultiply(N, R); except on E: EArgumentException do Raised := True; end; Assert.IsTrue(Raised);
    FillChar(One, SizeOf(One), 0); C.ScalarBaseMultiply(One, R); Assert.IsTrue(R.Infinity);
  finally
    C.Free;
  end;
end;

procedure TSecp256k1Tests.PointDecodeRejectsInvalid;
var
  C: TSecp256k1Curve;
  B: TBytes;
  P: TEccAffinePoint256;
begin
  C := TSecp256k1Curve.Create;
  try
    B := TEccTestUtil.HexBytes('0279BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F8179C'); Assert.IsFalse(C.DecodePoint(@B[0], Length(B), P)); B[0] := 5; Assert.IsFalse(C.DecodePoint(@B[0], Length(B), P));
  finally
    C.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TSecp256k1Tests);

end.
