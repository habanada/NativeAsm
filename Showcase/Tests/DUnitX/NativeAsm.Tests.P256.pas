{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
unit NativeAsm.Tests.P256;

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  NativeAsm.BigInt.Types,
  NativeAsm.Ecc.Types,
  NativeAsm.Ecc.P256,
  NativeAsm.Tests.Ecc.Common;

type
  [TestFixture]
  TP256Tests = class
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

procedure TP256Tests.DomainParametersAndEncoding;
var
  C: TP256Curve;
  G, D: TEccAffinePoint256;
  B: TBytes;
begin
  C := TP256Curve.Create;
  try
    G := C.Generator; Assert.IsTrue(C.PointIsOnCurve(G)); TEccTestUtil.AssertPoint('6B17D1F2E12C4247F8BCE6E563A440F277037D812DEB33A0F4A13945D898C296', '4FE342E2FE1A7F9B8EE7EB4A7C0F9E162BCE33576B315ECECBB6406837BF51F5', G);
    B := C.EncodePointCompressed(G); TEccTestUtil.AssertBytes('036B17D1F2E12C4247F8BCE6E563A440F277037D812DEB33A0F4A13945D898C296', B, 'compressed'); Assert.IsTrue(C.DecodePoint(@B[0], Length(B), D)); TEccTestUtil.AssertPoint(TEccTestUtil.ToHex(G.X), TEccTestUtil.ToHex(G.Y), D, 'decode compressed');
    B := C.EncodePointUncompressed(G); TEccTestUtil.AssertBytes('046B17D1F2E12C4247F8BCE6E563A440F277037D812DEB33A0F4A13945D898C2964FE342E2FE1A7F9B8EE7EB4A7C0F9E162BCE33576B315ECECBB6406837BF51F5', B, 'uncompressed'); Assert.IsTrue(C.DecodePoint(@B[0], Length(B), D));
  finally
    C.Free;
  end;
end;

procedure TP256Tests.KnownPointMultiples;
var
  C: TP256Curve;
  S: TUInt256;
  R: TEccAffinePoint256;
begin
  C := TP256Curve.Create;
  try
    S := TEccTestUtil.UInt256('2'); C.ScalarBaseMultiply(S, R); TEccTestUtil.AssertPoint('7CF27B188D034F7E8A52380304B51AC3C08969E277F21B35A60B48FC47669978', '07775510DB8ED040293D9AC69F7430DBBA7DADE63CE982299E04B79D227873D1', R, '2G');
    S := TEccTestUtil.UInt256('3'); C.ScalarBaseMultiply(S, R); TEccTestUtil.AssertPoint('5ECBE4D1A6330A44C8F7EF951D4BF165E6C6B721EFADA985FB41661BC6E7FD6C', '8734640C4998FF7E374B06CE1A64A2ECD82AB036384FB83D9A79B127A27D5032', R, '3G');
    S := TEccTestUtil.UInt256('7'); C.ScalarBaseMultiply(S, R); TEccTestUtil.AssertPoint('8E533B6FA0BF7B4625BB30667C01FB607EF9F8B8A80FEF5B300628703187B2A3', '73EB1DBDE03318366D069F83A6F5900053C73633CB041B21C55E1A86C1F400B4', R, '7G');
  finally
    C.Free;
  end;
end;

procedure TP256Tests.PointAddAndDouble;
var
  C: TP256Curve;
  G, A, D: TEccAffinePoint256;
begin
  C := TP256Curve.Create;
  try
    G := C.Generator; C.PointAdd(G, G, A); C.PointDouble(G, D); TEccTestUtil.AssertPoint('7CF27B188D034F7E8A52380304B51AC3C08969E277F21B35A60B48FC47669978', '07775510DB8ED040293D9AC69F7430DBBA7DADE63CE982299E04B79D227873D1', A); Assert.AreEqual(TEccTestUtil.ToHex(A.X), TEccTestUtil.ToHex(D.X)); Assert.AreEqual(TEccTestUtil.ToHex(A.Y), TEccTestUtil.ToHex(D.Y));
  finally
    C.Free;
  end;
end;

procedure TP256Tests.PointAddInverseAndInfinity;
var
  C: TP256Curve;
  G, N, R, I: TEccAffinePoint256;
begin
  C := TP256Curve.Create;
  try
    G := C.Generator; N := G; C.FieldNegate(N.Y, G.Y); C.PointAdd(G, N, R); Assert.IsTrue(R.Infinity); FillChar(I, SizeOf(I), 0); I.Infinity := True; C.PointAdd(G, I, R); TEccTestUtil.AssertPoint(TEccTestUtil.ToHex(G.X), TEccTestUtil.ToHex(G.Y), R); C.PointAdd(I, G, R); TEccTestUtil.AssertPoint(TEccTestUtil.ToHex(G.X), TEccTestUtil.ToHex(G.Y), R);
  finally
    C.Free;
  end;
end;

procedure TP256Tests.LargeScalarVector;
var
  C: TP256Curve;
  S: TUInt256;
  R: TEccAffinePoint256;
begin
  S := TEccTestUtil.UInt256('000123456789ABCDEF123456789ABCDEF123456789ABCDEF123456789ABCDEF'); C := TP256Curve.Create;
  try
    C.ScalarBaseMultiply(S, R); TEccTestUtil.AssertPoint('92DE4F405A649285EC3B013ACE003BF616D9A53805CB0A997271761522A30396', '57A1E4F9050A9B7946E8446895ABD6CDBB42DE0750F638E07B2B3D3DCF2B6225', R);
  finally
    C.Free;
  end;
end;

procedure TP256Tests.FieldArithmetic;
var
  C: TP256Curve;
  A, B, R, T: TUInt256;
begin
  A := TEccTestUtil.UInt256('0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF'); B := TEccTestUtil.UInt256('0FEDCBA9876543210FEDCBA9876543210FEDCBA9876543210FEDCBA987654321'); C := TP256Curve.Create;
  try
    C.FieldAdd(R, A, B); TEccTestUtil.AssertUInt256('1111111111111110111111111111111011111111111111101111111111111110', R, 'add');
    C.FieldSub(R, A, B); TEccTestUtil.AssertUInt256('F13579BD02468ACEF13579BE02468ACDF13579BF02468ACDF13579BE02468ACD', R, 'sub');
    C.FieldMul(R, A, B); TEccTestUtil.AssertUInt256('175E0FB4CFBE38A55F2F1809043CD2B48A801BD53C02492164D2810A05C7A841', R, 'mul');
    C.FieldInverse(R, A); TEccTestUtil.AssertUInt256('DE81EB370AF1F92CC7B6D08F0A124A1EC6DE1A033B9B93DE117B5254F0490691', R, 'inv'); C.FieldMul(T, A, R); TEccTestUtil.AssertUInt256('0000000000000000000000000000000000000000000000000000000000000001', T, 'inverse product');
  finally
    C.Free;
  end;
end;

procedure TP256Tests.ScalarArithmetic;
var
  C: TP256Curve;
  A, B, R, T: TUInt256;
begin
  A := TEccTestUtil.UInt256('0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF'); B := TEccTestUtil.UInt256('0FEDCBA9876543210FEDCBA9876543210FEDCBA9876543210FEDCBA987654321'); C := TP256Curve.Create;
  try
    C.ScalarAdd(R, A, B); TEccTestUtil.AssertUInt256('1111111111111110111111111111111011111111111111101111111111111110', R, 'add');
    C.ScalarSub(R, A, B); TEccTestUtil.AssertUInt256('F13579BD02468ACEF13579BE02468ACDAE1C746BA95E2952E4EF4480FEA9B01F', R, 'sub');
    C.ScalarMul(R, A, B); TEccTestUtil.AssertUInt256('88533A1CC91863C1FE969ADB91A2E056C83F6B6D466C0C10B5D6A13B720531AD', R, 'mul');
    C.ScalarInverse(R, A); TEccTestUtil.AssertUInt256('1359162EDE91207CCAEA1DE94AFC63C1DB5A967C1E6E21F91EF9F077F20A46B6', R, 'inv'); C.ScalarMul(T, A, R); TEccTestUtil.AssertUInt256('0000000000000000000000000000000000000000000000000000000000000001', T, 'inverse product');
  finally
    C.Free;
  end;
end;

procedure TP256Tests.ScalarBoundaries;
var
  C: TP256Curve;
  N, Nm1, One: TUInt256;
  R: TEccAffinePoint256;
  Raised: Boolean;
begin
  C := TP256Curve.Create;
  try
    N := C.ScalarOrder; One := TEccTestUtil.UInt256('1'); C.ScalarNegate(Nm1, One); Assert.IsTrue(C.ScalarIsCanonical(Nm1)); Assert.IsFalse(C.ScalarIsCanonical(N)); C.ScalarBaseMultiply(Nm1, R); TEccTestUtil.AssertPoint('6B17D1F2E12C4247F8BCE6E563A440F277037D812DEB33A0F4A13945D898C296', 'B01CBD1C01E58065711814B583F061E9D431CCA994CEA1313449BF97C840AE0A', R, '(n-1)G');
    Raised := False; try C.ScalarBaseMultiply(N, R); except on E: EArgumentException do Raised := True; end; Assert.IsTrue(Raised);
    FillChar(One, SizeOf(One), 0); C.ScalarBaseMultiply(One, R); Assert.IsTrue(R.Infinity);
  finally
    C.Free;
  end;
end;

procedure TP256Tests.PointDecodeRejectsInvalid;
var
  C: TP256Curve;
  B: TBytes;
  P: TEccAffinePoint256;
begin
  C := TP256Curve.Create;
  try
    B := TEccTestUtil.HexBytes('026B17D1F2E12C4247F8BCE6E563A440F277037D812DEB33A0F4A13945D898C298'); Assert.IsFalse(C.DecodePoint(@B[0], Length(B), P)); B[0] := 5; Assert.IsFalse(C.DecodePoint(@B[0], Length(B), P));
  finally
    C.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TP256Tests);

end.
