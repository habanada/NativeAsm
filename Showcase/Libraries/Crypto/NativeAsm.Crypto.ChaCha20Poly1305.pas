{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
unit NativeAsm.Crypto.ChaCha20Poly1305;

interface

uses
  System.SysUtils,
  NativeAsm.Crypto.ChaCha20,
  NativeAsm.Crypto.Poly1305;

type
  TChaCha20Poly1305Jit = class
  private
    FChaCha: TChaCha20Jit;
    FPoly: TPoly1305Jit;
    procedure BuildPolyKey(const Key: TChaCha20Key; const Nonce: TChaCha20Nonce; out PolyKey: TPoly1305Key);
    procedure ComputeTag(Cipher: Pointer; CipherLength: NativeUInt; AAD: Pointer; AADLength: NativeUInt; const PolyKey: TPoly1305Key; out Tag: TPoly1305Tag);
  public
    constructor Create(ChaChaMode: TChaCha20Mode = ccmAuto);
    destructor Destroy; override;
    procedure Encrypt(Plain: Pointer; PlainLength: NativeUInt; AAD: Pointer; AADLength: NativeUInt; Cipher: Pointer; const Key: TChaCha20Key; const Nonce: TChaCha20Nonce; out Tag: TPoly1305Tag); overload;
    function Encrypt(const Plain, AAD: TBytes; const Key: TChaCha20Key; const Nonce: TChaCha20Nonce; out Tag: TPoly1305Tag): TBytes; overload;
    function Decrypt(Cipher: Pointer; CipherLength: NativeUInt; AAD: Pointer; AADLength: NativeUInt; Plain: Pointer; const Key: TChaCha20Key; const Nonce: TChaCha20Nonce; const Tag: TPoly1305Tag): Boolean; overload;
    function Decrypt(const Cipher, AAD: TBytes; const Key: TChaCha20Key; const Nonce: TChaCha20Nonce; const Tag: TPoly1305Tag; out Plain: TBytes): Boolean; overload;
  end;

implementation

constructor TChaCha20Poly1305Jit.Create(ChaChaMode: TChaCha20Mode);
begin
  inherited Create;
  FChaCha := TChaCha20Jit.Create(ChaChaMode);
  FPoly := TPoly1305Jit.Create;
end;

destructor TChaCha20Poly1305Jit.Destroy;
begin
  FPoly.Free;
  FChaCha.Free;
  inherited;
end;

procedure TChaCha20Poly1305Jit.BuildPolyKey(const Key: TChaCha20Key; const Nonce: TChaCha20Nonce; out PolyKey: TPoly1305Key);
var
  Block: array[0..63] of Byte;
begin
  FChaCha.Generate(@Block[0], SizeOf(Block), Key, Nonce, 0);
  Move(Block[0], PolyKey[0], SizeOf(PolyKey));
  FillChar(Block, SizeOf(Block), 0);
end;

procedure TChaCha20Poly1305Jit.ComputeTag(Cipher: Pointer; CipherLength: NativeUInt; AAD: Pointer; AADLength: NativeUInt; const PolyKey: TPoly1305Key; out Tag: TPoly1305Tag);
var
  State: TPoly1305State;
  Zeros: array[0..15] of Byte;
  Lengths: array[0..1] of UInt64;
  Pad: NativeUInt;
begin
  FillChar(Zeros, SizeOf(Zeros), 0);
  FPoly.Init(State, PolyKey);
  try
    FPoly.Update(State, AAD, AADLength);
    Pad := (16 - (AADLength and 15)) and 15;
    if Pad <> 0 then FPoly.Update(State, @Zeros[0], Pad);
    FPoly.Update(State, Cipher, CipherLength);
    Pad := (16 - (CipherLength and 15)) and 15;
    if Pad <> 0 then FPoly.Update(State, @Zeros[0], Pad);
    Lengths[0] := UInt64(AADLength);
    Lengths[1] := UInt64(CipherLength);
    FPoly.Update(State, @Lengths[0], SizeOf(Lengths));
    FPoly.Final(State, Tag);
  finally
    FillChar(State, SizeOf(State), 0);
    FillChar(Lengths, SizeOf(Lengths), 0);
  end;
end;

procedure TChaCha20Poly1305Jit.Encrypt(Plain: Pointer; PlainLength: NativeUInt; AAD: Pointer; AADLength: NativeUInt; Cipher: Pointer; const Key: TChaCha20Key; const Nonce: TChaCha20Nonce; out Tag: TPoly1305Tag);
var
  PolyKey: TPoly1305Key;
begin
  if (Plain = nil) and (PlainLength <> 0) then raise EArgumentNilException.Create('Plain');
  if (AAD = nil) and (AADLength <> 0) then raise EArgumentNilException.Create('AAD');
  if (Cipher = nil) and (PlainLength <> 0) then raise EArgumentNilException.Create('Cipher');
  BuildPolyKey(Key, Nonce, PolyKey);
  try
    FChaCha.XorKeyStream(Plain, Cipher, PlainLength, Key, Nonce, 1);
    ComputeTag(Cipher, PlainLength, AAD, AADLength, PolyKey, Tag);
  finally
    FillChar(PolyKey, SizeOf(PolyKey), 0);
  end;
end;

function TChaCha20Poly1305Jit.Encrypt(const Plain, AAD: TBytes; const Key: TChaCha20Key; const Nonce: TChaCha20Nonce; out Tag: TPoly1305Tag): TBytes;
var
  PPlain, PAad, PCipher: Pointer;
begin
  SetLength(Result, Length(Plain));
  if Length(Plain) = 0 then begin PPlain := nil; PCipher := nil; end else begin PPlain := @Plain[0]; PCipher := @Result[0]; end;
  if Length(AAD) = 0 then PAad := nil else PAad := @AAD[0];
  Encrypt(PPlain, NativeUInt(Length(Plain)), PAad, NativeUInt(Length(AAD)), PCipher, Key, Nonce, Tag);
end;

function TChaCha20Poly1305Jit.Decrypt(Cipher: Pointer; CipherLength: NativeUInt; AAD: Pointer; AADLength: NativeUInt; Plain: Pointer; const Key: TChaCha20Key; const Nonce: TChaCha20Nonce; const Tag: TPoly1305Tag): Boolean;
var
  PolyKey: TPoly1305Key;
  Expected: TPoly1305Tag;
begin
  if (Cipher = nil) and (CipherLength <> 0) then raise EArgumentNilException.Create('Cipher');
  if (AAD = nil) and (AADLength <> 0) then raise EArgumentNilException.Create('AAD');
  if (Plain = nil) and (CipherLength <> 0) then raise EArgumentNilException.Create('Plain');
  BuildPolyKey(Key, Nonce, PolyKey);
  try
    ComputeTag(Cipher, CipherLength, AAD, AADLength, PolyKey, Expected);
    Result := TPoly1305Jit.EqualTags(Expected, Tag);
    if Result then FChaCha.XorKeyStream(Cipher, Plain, CipherLength, Key, Nonce, 1);
  finally
    FillChar(Expected, SizeOf(Expected), 0);
    FillChar(PolyKey, SizeOf(PolyKey), 0);
  end;
end;

function TChaCha20Poly1305Jit.Decrypt(const Cipher, AAD: TBytes; const Key: TChaCha20Key; const Nonce: TChaCha20Nonce; const Tag: TPoly1305Tag; out Plain: TBytes): Boolean;
var
  PCipher, PAad, PPlain: Pointer;
begin
  SetLength(Plain, Length(Cipher));
  if Length(Cipher) = 0 then begin PCipher := nil; PPlain := nil; end else begin PCipher := @Cipher[0]; PPlain := @Plain[0]; end;
  if Length(AAD) = 0 then PAad := nil else PAad := @AAD[0];
  Result := Decrypt(PCipher, NativeUInt(Length(Cipher)), PAad, NativeUInt(Length(AAD)), PPlain, Key, Nonce, Tag);
  if not Result then SetLength(Plain, 0);
end;

end.
