{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
unit NativeAsm.Tests.Poly1305;

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  NativeAsm.Crypto.Poly1305;

type
  [TestFixture]
  TPoly1305Tests = class
  private
    class function HexToBytes(const S: string): TBytes; static;
    class function TagHex(const Tag: TPoly1305Tag): string; static;
    class procedure LoadKey(const S: string; out Key: TPoly1305Key); static;
  public
    [Test] procedure RfcVector;
    [Test] procedure EmptyMessageReturnsPad;
    [Test] procedure StreamingMatchesSinglePass;
    [Test] procedure BoundarySplitsMatch;
    [Test] procedure EqualTagsDetectsDifference;
    [Test] procedure UpdateAfterFinalIsRejected;
    [Test] procedure FinalTwiceIsRejected;
  end;

implementation

class function TPoly1305Tests.HexToBytes(const S: string): TBytes;
var
  I: Integer;
begin
  SetLength(Result, Length(S) div 2);
  for I := 0 to High(Result) do Result[I] := Byte(StrToInt('$' + Copy(S, I * 2 + 1, 2)));
end;

class function TPoly1305Tests.TagHex(const Tag: TPoly1305Tag): string;
const
  Digits: string = '0123456789abcdef';
var
  I: Integer;
begin
  SetLength(Result, 32);
  for I := 0 to 15 do
  begin
    Result[I * 2 + 1] := Digits[(Tag[I] shr 4) + 1];
    Result[I * 2 + 2] := Digits[(Tag[I] and $F) + 1];
  end;
end;

class procedure TPoly1305Tests.LoadKey(const S: string; out Key: TPoly1305Key);
var
  B: TBytes;
begin
  B := HexToBytes(S);
  Assert.IsTrue(Length(B) = SizeOf(Key));
  Move(B[0], Key[0], SizeOf(Key));
end;

procedure TPoly1305Tests.RfcVector;
var
  Jit: TPoly1305Jit;
  Key: TPoly1305Key;
  Data: TBytes;
  Tag: TPoly1305Tag;
begin
  LoadKey('85d6be7857556d337f4452fe42d506a80103808afb0db2fd4abff6af4149f51b', Key);
  Data := TEncoding.ASCII.GetBytes('Cryptographic Forum Research Group');
  Jit := TPoly1305Jit.Create;
  try
    Tag := Jit.Compute(Data, Key);
    Assert.IsTrue(TagHex(Tag) = 'a8061dc1305136c6c22b8baf0c0127a9');
  finally
    Jit.Free;
  end;
end;

procedure TPoly1305Tests.EmptyMessageReturnsPad;
var
  Jit: TPoly1305Jit;
  Key: TPoly1305Key;
  Tag: TPoly1305Tag;
begin
  LoadKey('000000000000000000000000000000000102030405060708090a0b0c0d0e0f10', Key);
  Jit := TPoly1305Jit.Create;
  try
    Tag := Jit.Compute(nil, 0, Key);
    Assert.IsTrue(TagHex(Tag) = '0102030405060708090a0b0c0d0e0f10');
  finally
    Jit.Free;
  end;
end;

procedure TPoly1305Tests.StreamingMatchesSinglePass;
var
  Jit: TPoly1305Jit;
  Key: TPoly1305Key;
  Data: TBytes;
  A, B: TPoly1305Tag;
  State: TPoly1305State;
  I: Integer;
begin
  for I := 0 to 31 do Key[I] := Byte(I * 7 + 3);
  SetLength(Data, 4099);
  for I := 0 to High(Data) do Data[I] := Byte((I * 41 + 9) and $FF);
  Jit := TPoly1305Jit.Create;
  try
    A := Jit.Compute(Data, Key);
    Jit.Init(State, Key);
    Jit.Update(State, @Data[0], 1);
    Jit.Update(State, @Data[1], 15);
    Jit.Update(State, @Data[16], 17);
    Jit.Update(State, @Data[33], 1024);
    Jit.Update(State, @Data[1057], NativeUInt(Length(Data) - 1057));
    Jit.Final(State, B);
    Assert.IsTrue(TPoly1305Jit.EqualTags(A, B));
  finally
    FillChar(State, SizeOf(State), 0);
    Jit.Free;
  end;
end;

procedure TPoly1305Tests.BoundarySplitsMatch;
const
  Lengths: array[0..12] of Integer = (0, 1, 15, 16, 17, 31, 32, 33, 63, 64, 65, 255, 257);
var
  Jit: TPoly1305Jit;
  Key: TPoly1305Key;
  Data: TBytes;
  A, B: TPoly1305Tag;
  State: TPoly1305State;
  I, J, N, Split: Integer;
begin
  for I := 0 to 31 do Key[I] := Byte(I + 17);
  Jit := TPoly1305Jit.Create;
  try
    for J := Low(Lengths) to High(Lengths) do
    begin
      N := Lengths[J];
      SetLength(Data, N);
      for I := 0 to N - 1 do Data[I] := Byte((I * 19 + N) and $FF);
      A := Jit.Compute(Data, Key);
      Jit.Init(State, Key);
      Split := N div 2;
      if Split <> 0 then Jit.Update(State, @Data[0], NativeUInt(Split));
      if N - Split <> 0 then Jit.Update(State, @Data[Split], NativeUInt(N - Split));
      Jit.Final(State, B);
      Assert.IsTrue(TPoly1305Jit.EqualTags(A, B), 'Length ' + IntToStr(N));
    end;
  finally
    FillChar(State, SizeOf(State), 0);
    Jit.Free;
  end;
end;

procedure TPoly1305Tests.EqualTagsDetectsDifference;
var
  A, B: TPoly1305Tag;
begin
  FillChar(A, SizeOf(A), $5A);
  B := A;
  Assert.IsTrue(TPoly1305Jit.EqualTags(A, B));
  B[9] := B[9] xor $80;
  Assert.IsTrue(not TPoly1305Jit.EqualTags(A, B));
end;

procedure TPoly1305Tests.UpdateAfterFinalIsRejected;
var
  Jit: TPoly1305Jit;
  Key: TPoly1305Key;
  State: TPoly1305State;
  Tag: TPoly1305Tag;
  B: Byte;
  Raised: Boolean;
begin
  FillChar(Key, SizeOf(Key), 0);
  B := 1;
  Jit := TPoly1305Jit.Create;
  try
    Jit.Init(State, Key);
    Jit.Final(State, Tag);
    Raised := False;
    try
      Jit.Update(State, @B, 1);
    except
      on E: EInvalidOp do Raised := True;
    end;
    Assert.IsTrue(Raised);
  finally
    FillChar(State, SizeOf(State), 0);
    Jit.Free;
  end;
end;

procedure TPoly1305Tests.FinalTwiceIsRejected;
var
  Jit: TPoly1305Jit;
  Key: TPoly1305Key;
  State: TPoly1305State;
  Tag: TPoly1305Tag;
  Raised: Boolean;
begin
  FillChar(Key, SizeOf(Key), 0);
  Jit := TPoly1305Jit.Create;
  try
    Jit.Init(State, Key);
    Jit.Final(State, Tag);
    Raised := False;
    try
      Jit.Final(State, Tag);
    except
      on E: EInvalidOp do Raised := True;
    end;
    Assert.IsTrue(Raised);
  finally
    FillChar(State, SizeOf(State), 0);
    Jit.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TPoly1305Tests);

end.
