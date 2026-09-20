{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
unit NativeAsm.Tests.Field25519;

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  NativeAsm.BigInt.Types,
  NativeAsm.Ecc.Types,
  NativeAsm.Ecc.Field25519,
  NativeAsm.Tests.Ecc.Common;

type
  [TestFixture]
  TField25519Tests = class
  public
    [Test] procedure FieldKnownVectors;
    [Test] procedure ScalarKnownVectors;
    [Test] procedure Rfc7748Vector1;
    [Test] procedure Rfc7748Vector2;
    [Test] procedure Rfc7748EcdhVector;
    [Test] procedure Rfc7748Iterated1And1000;
    [Test] procedure NonCanonicalUIsAccepted;
    [Test] procedure LowOrderCheckedRejectsZero;
  end;

implementation

procedure TField25519Tests.FieldKnownVectors;
var
  F: TField25519;
  A, B, R, T: TUInt256;
begin
  A := TEccTestUtil.UInt256('123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0');
  B := TEccTestUtil.UInt256('0FEDCBA9876543210FEDCBA9876543210FEDCBA9876543210FEDCBA987654321');
  F := TField25519.Create;
  try
    F.FieldAdd(R, A, B); TEccTestUtil.AssertUInt256('2222222222222211222222222222221122222222222222112222222222222211', R, 'add');
    F.FieldMul(R, A, B); TEccTestUtil.AssertUInt256('374C6C5B5DB7AD57D322DB4097232896EEF94A25D08EA3D60ACFB90B09FA1F13', R, 'mul');
    F.FieldInverse(R, A); TEccTestUtil.AssertUInt256('20156A6E8A59F1CE84CF3FE6BB3704486EE3CE441547929141DCF6BE16377745', R, 'inv');
    F.FieldMul(T, A, R); TEccTestUtil.AssertUInt256('0000000000000000000000000000000000000000000000000000000000000001', T, 'inverse product');
  finally
    F.Free;
  end;
end;

procedure TField25519Tests.ScalarKnownVectors;
var
  F: TField25519;
  A, B, R, T: TUInt256;
begin
  A := TEccTestUtil.UInt256('0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF');
  B := TEccTestUtil.UInt256('0FEDCBA9876543210FEDCBA9876543210FEDCBA9876543210FEDCBA987654321');
  F := TField25519.Create;
  try
    F.ScalarAdd(R, A, B); TEccTestUtil.AssertUInt256('0111111111111110111111111111110FFC3217326E197439B8FEADF6B41B3D23', R, 'add');
    F.ScalarMul(R, A, B); TEccTestUtil.AssertUInt256('08E727E8ED54E7D1E9DAAB69447142134A6302AC045BD797FD22396ECBA8E182', R, 'mul');
    F.ScalarInverse(R, A); TEccTestUtil.AssertUInt256('0DF129F4C628FE6ADDCF9D8B83EBDF2AC73F997B636E3251533D6172B8D7F668', R, 'inv');
    F.ScalarMul(T, A, R); TEccTestUtil.AssertUInt256('0000000000000000000000000000000000000000000000000000000000000001', T, 'inverse product');
  finally
    F.Free;
  end;
end;

procedure TField25519Tests.Rfc7748Vector1;
var
  F: TField25519;
  K, U, R: TX25519Bytes;
begin
  K := TEccTestUtil.X25519Bytes('a546e36bf0527c9d3b16154b82465edd62144c0ac1fc5a18506a2244ba449ac4'); U := TEccTestUtil.X25519Bytes('e6db6867583030db3594c1a424b15f7c726624ec26b3353b10a903a6d0ab1c4c'); F := TField25519.Create;
  try
    F.X25519(K, U, R); TEccTestUtil.AssertX25519('c3da55379de9c6908e94ea4df28d084f32eccf03491c71f754b4075577a28552', R);
  finally
    F.Free;
  end;
end;

procedure TField25519Tests.Rfc7748Vector2;
var
  F: TField25519;
  K, U, R: TX25519Bytes;
begin
  K := TEccTestUtil.X25519Bytes('4b66e9d4d1b4673c5ad22691957d6af5c11b6421e0ea01d42ca4169e7918ba0d'); U := TEccTestUtil.X25519Bytes('e5210f12786811d3f4b7959d0538ae2c31dbe7106fc03c3efc4cd549c715a493'); F := TField25519.Create;
  try
    F.X25519(K, U, R); TEccTestUtil.AssertX25519('95cbde9476e8907d7aade45cb4b873f88b595a68799fa152e6f8f7647aac7957', R);
  finally
    F.Free;
  end;
end;

procedure TField25519Tests.Rfc7748EcdhVector;
var
  F: TField25519;
  A, B, APub, BPub, S1, S2: TX25519Bytes;
begin
  A := TEccTestUtil.X25519Bytes('77076d0a7318a57d3c16c17251b26645df4c2f87ebc0992ab177fba51db92c2a'); B := TEccTestUtil.X25519Bytes('5dab087e624a8a4b79e17f8b83800ee66f3bb1292618b6fd1c2f8b27ff88e0eb'); F := TField25519.Create;
  try
    F.X25519Base(A, APub); F.X25519Base(B, BPub); TEccTestUtil.AssertX25519('8520f0098930a754748b7ddcb43ef75a0dbf3a0d26381af4eba4a98eaa9b4e6a', APub, 'alice'); TEccTestUtil.AssertX25519('de9edb7d7b7dc1b4d35b61c2ece435373f8343c85b78674dadfc7e146f882b4f', BPub, 'bob');
    F.X25519(A, BPub, S1); F.X25519(B, APub, S2); TEccTestUtil.AssertX25519('4a5d9d5ba4ce2de1728e3bf480350f25e07e21c947d19e3376f09b3c1e161742', S1, 'shared'); Assert.AreEqual(TEccTestUtil.X25519ToHex(S1), TEccTestUtil.X25519ToHex(S2));
  finally
    F.Free;
  end;
end;

procedure TField25519Tests.Rfc7748Iterated1And1000;
var
  F: TField25519;
  K, U, OldK, R: TX25519Bytes;
  I: Integer;
begin
  FillChar(K, SizeOf(K), 0); K[0] := 9; U := K; F := TField25519.Create;
  try
    for I := 1 to 1000 do
    begin
      OldK := K; F.X25519(K, U, R); K := R; U := OldK;
      if I = 1 then TEccTestUtil.AssertX25519('422c8e7a6227d7bca1350b3e2bb7279f7897b87bb6854b783c60e80311ae3079', K, 'iteration 1');
    end;
    TEccTestUtil.AssertX25519('684cf59ba83309552800ef566f2f4d3c1c3887c49360e3875f2eb94d99532c51', K, 'iteration 1000');
  finally
    F.Free;
  end;
end;

procedure TField25519Tests.NonCanonicalUIsAccepted;
var
  F: TField25519;
  K, U1, U2, R1, R2: TX25519Bytes;
begin
  FillChar(K, SizeOf(K), $42); FillChar(U1, SizeOf(U1), 0); U1[0] := 5; U2 := U1; U2[31] := $80; F := TField25519.Create;
  try
    F.X25519(K, U1, R1); F.X25519(K, U2, R2); Assert.AreEqual(TEccTestUtil.X25519ToHex(R1), TEccTestUtil.X25519ToHex(R2));
  finally
    F.Free;
  end;
end;

procedure TField25519Tests.LowOrderCheckedRejectsZero;
var
  F: TField25519;
  K, U, R: TX25519Bytes;
begin
  FillChar(K, SizeOf(K), $55); FillChar(U, SizeOf(U), 0); F := TField25519.Create;
  try
    Assert.IsFalse(F.X25519Checked(K, U, R)); TEccTestUtil.AssertX25519('0000000000000000000000000000000000000000000000000000000000000000', R);
  finally
    F.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TField25519Tests);

end.
