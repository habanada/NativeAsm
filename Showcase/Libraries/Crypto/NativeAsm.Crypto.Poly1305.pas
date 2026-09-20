{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
unit NativeAsm.Crypto.Poly1305;

interface

uses
  System.SysUtils,
  NativeAsm.Types,
  NativeAsm.Builder,
  NativeAsm.Extensions;

type
  TPoly1305Key = array[0..31] of Byte;
  TPoly1305Tag = array[0..15] of Byte;

  TPoly1305State = packed record
    R: array[0..4] of UInt64;
    S: array[0..4] of UInt64;
    H: array[0..4] of UInt64;
    D: array[0..4] of UInt64;
    Pad: array[0..3] of Cardinal;
    Buffer: array[0..15] of Byte;
    BufferLen: NativeUInt;
    Finalized: Byte;
  end;

  TPoly1305Jit = class
  private
    FBlockCode: TExecutableCode;
    class function BuildBlockKernel: TExecutableCode; static;
    class function Load32LE(P: PByte): Cardinal; static;
    procedure ProcessBlocks(var State: TPoly1305State; Data: Pointer; BlockCount: NativeUInt; HiBit: UInt64);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Init(var State: TPoly1305State; const Key: TPoly1305Key);
    procedure Update(var State: TPoly1305State; Buffer: Pointer; Length: NativeUInt);
    procedure Final(var State: TPoly1305State; out Tag: TPoly1305Tag);
    function Compute(Buffer: Pointer; Length: NativeUInt; const Key: TPoly1305Key): TPoly1305Tag; overload;
    function Compute(const Data: TBytes; const Key: TPoly1305Key): TPoly1305Tag; overload;
    class function EqualTags(const A, B: TPoly1305Tag): Boolean; static;
  end;

implementation

const
  Mask26 = UInt64($3FFFFFF);
  ROffset = 0;
  SOffset = 40;
  HOffset = 80;
  DOffset = 120;
  PadOffset = 160;

function FactorOffset(DIndex, HIndex: Integer): Integer;
var
  RIndex: Integer;
begin
  RIndex := DIndex - HIndex;
  if RIndex < 0 then Inc(RIndex, 5);
  if HIndex <= DIndex then Result := ROffset + RIndex * 8 else Result := SOffset + RIndex * 8;
end;

procedure EmitProductSum(B: TAsmBuilder; DIndex: Integer);
var
  I: Integer;
begin
  B.Xor_(RBX, RBX);
  for I := 0 to 4 do
  begin
    B.Mov(RAX, QWordPtr(ridR12, HOffset + I * 8)).Mov(R10, QWordPtr(ridR12, FactorOffset(DIndex, I))).Imul(RAX, R10).Add(RBX, RAX);
  end;
  B.Mov(QWordPtr(ridR12, DOffset + DIndex * 8), RBX);
end;

class function TPoly1305Jit.BuildBlockKernel: TExecutableCode;
var
  B: TAsmBuilder;
  LLoop, LDone: TLabel;
  I: Integer;
begin
  B := TAsmBuilder.Create;
  try
    LLoop := B.NewLabel;
    LDone := B.NewLabel;
    B.Push(RBX).Push(R12).Push(R13).Push(R14).Push(R15);
    B.Mov(R12, RCX).Mov(R13, RDX).Mov(R14, R8).Mov(R15, R9).Test(R14, R14).J(cond_JE, LDone).Bind(LLoop);

    B.Mov(EAX, DWordPtr(ridR13)).And_(RAX, Int64(Mask26)).Add(RAX, QWordPtr(ridR12, HOffset)).Mov(QWordPtr(ridR12, HOffset), RAX);
    B.Mov(EAX, DWordPtr(ridR13)).Shr_(RAX, 26).Mov(R10D, DWordPtr(ridR13, 4)).Shl_(R10, 6).Or_(RAX, R10).And_(RAX, Int64(Mask26)).Add(RAX, QWordPtr(ridR12, HOffset + 8)).Mov(QWordPtr(ridR12, HOffset + 8), RAX);
    B.Mov(EAX, DWordPtr(ridR13, 4)).Shr_(RAX, 20).Mov(R10D, DWordPtr(ridR13, 8)).Shl_(R10, 12).Or_(RAX, R10).And_(RAX, Int64(Mask26)).Add(RAX, QWordPtr(ridR12, HOffset + 16)).Mov(QWordPtr(ridR12, HOffset + 16), RAX);
    B.Mov(EAX, DWordPtr(ridR13, 8)).Shr_(RAX, 14).Mov(R10D, DWordPtr(ridR13, 12)).Shl_(R10, 18).Or_(RAX, R10).And_(RAX, Int64(Mask26)).Add(RAX, QWordPtr(ridR12, HOffset + 24)).Mov(QWordPtr(ridR12, HOffset + 24), RAX);
    B.Mov(EAX, DWordPtr(ridR13, 12)).Shr_(RAX, 8).Or_(RAX, R15).Add(RAX, QWordPtr(ridR12, HOffset + 32)).Mov(QWordPtr(ridR12, HOffset + 32), RAX);

    for I := 0 to 4 do EmitProductSum(B, I);

    B.Mov(RAX, QWordPtr(ridR12, DOffset)).Mov(R10, RAX).Shr_(R10, 26).And_(RAX, Int64(Mask26)).Mov(QWordPtr(ridR12, HOffset), RAX);
    B.Mov(RAX, QWordPtr(ridR12, DOffset + 8)).Add(RAX, R10).Mov(R10, RAX).Shr_(R10, 26).And_(RAX, Int64(Mask26)).Mov(QWordPtr(ridR12, HOffset + 8), RAX);
    B.Mov(RAX, QWordPtr(ridR12, DOffset + 16)).Add(RAX, R10).Mov(R10, RAX).Shr_(R10, 26).And_(RAX, Int64(Mask26)).Mov(QWordPtr(ridR12, HOffset + 16), RAX);
    B.Mov(RAX, QWordPtr(ridR12, DOffset + 24)).Add(RAX, R10).Mov(R10, RAX).Shr_(R10, 26).And_(RAX, Int64(Mask26)).Mov(QWordPtr(ridR12, HOffset + 24), RAX);
    B.Mov(RAX, QWordPtr(ridR12, DOffset + 32)).Add(RAX, R10).Mov(R10, RAX).Shr_(R10, 26).And_(RAX, Int64(Mask26)).Mov(QWordPtr(ridR12, HOffset + 32), RAX);
    B.Imul(R10, R10, 5).Add(R10, QWordPtr(ridR12, HOffset)).Mov(RAX, R10).Shr_(R10, 26).And_(RAX, Int64(Mask26)).Mov(QWordPtr(ridR12, HOffset), RAX);
    B.Add(R10, QWordPtr(ridR12, HOffset + 8)).Mov(QWordPtr(ridR12, HOffset + 8), R10);

    B.Add(R13, 16).Dec_(R14).J(cond_JNE, LLoop);
    B.Bind(LDone).Pop(R15).Pop(R14).Pop(R13).Pop(R12).Pop(RBX).Ret;
    Result := TExecutableCode.FromBuilder(B);
  finally
    B.Free;
  end;
end;

class function TPoly1305Jit.Load32LE(P: PByte): Cardinal;
begin
  Move(P^, Result, SizeOf(Result));
end;

constructor TPoly1305Jit.Create;
begin
  inherited Create;
  FBlockCode := BuildBlockKernel;
end;

destructor TPoly1305Jit.Destroy;
begin
  FBlockCode.Free;
  inherited;
end;

procedure TPoly1305Jit.ProcessBlocks(var State: TPoly1305State; Data: Pointer; BlockCount: NativeUInt; HiBit: UInt64);
begin
  if BlockCount = 0 then Exit;
  FBlockCode.Run(UInt64(NativeUInt(@State)), UInt64(NativeUInt(Data)), UInt64(BlockCount), HiBit);
end;

procedure TPoly1305Jit.Init(var State: TPoly1305State; const Key: TPoly1305Key);
var
  P: PByte;
begin
  FillChar(State, SizeOf(State), 0);
  P := PByte(@Key[0]);
  State.R[0] := UInt64(Load32LE(P)) and $3FFFFFF;
  State.R[1] := UInt64(Load32LE(PByte(NativeUInt(P) + 3)) shr 2) and $3FFFF03;
  State.R[2] := UInt64(Load32LE(PByte(NativeUInt(P) + 6)) shr 4) and $3FFC0FF;
  State.R[3] := UInt64(Load32LE(PByte(NativeUInt(P) + 9)) shr 6) and $3F03FFF;
  State.R[4] := UInt64(Load32LE(PByte(NativeUInt(P) + 12)) shr 8) and $00FFFFF;
  State.S[0] := State.R[0];
  State.S[1] := State.R[1] * 5;
  State.S[2] := State.R[2] * 5;
  State.S[3] := State.R[3] * 5;
  State.S[4] := State.R[4] * 5;
  State.Pad[0] := Load32LE(PByte(NativeUInt(P) + 16));
  State.Pad[1] := Load32LE(PByte(NativeUInt(P) + 20));
  State.Pad[2] := Load32LE(PByte(NativeUInt(P) + 24));
  State.Pad[3] := Load32LE(PByte(NativeUInt(P) + 28));
end;

procedure TPoly1305Jit.Update(var State: TPoly1305State; Buffer: Pointer; Length: NativeUInt);
var
  P: PByte;
  Need, Blocks: NativeUInt;
begin
  if State.Finalized <> 0 then raise EInvalidOp.Create('Poly1305 state is finalized');
  if (Buffer = nil) and (Length <> 0) then raise EArgumentNilException.Create('Buffer');
  if Length = 0 then Exit;
  P := PByte(Buffer);
  if State.BufferLen <> 0 then
  begin
    Need := 16 - State.BufferLen;
    if Need > Length then Need := Length;
    Move(P^, State.Buffer[Integer(State.BufferLen)], NativeInt(Need));
    Inc(State.BufferLen, Need);
    P := PByte(NativeUInt(P) + Need);
    Dec(Length, Need);
    if State.BufferLen = 16 then
    begin
      ProcessBlocks(State, @State.Buffer[0], 1, UInt64(1) shl 24);
      State.BufferLen := 0;
    end;
  end;
  Blocks := Length div 16;
  if Blocks <> 0 then
  begin
    ProcessBlocks(State, P, Blocks, UInt64(1) shl 24);
    P := PByte(NativeUInt(P) + Blocks * 16);
    Dec(Length, Blocks * 16);
  end;
  if Length <> 0 then
  begin
    Move(P^, State.Buffer[0], NativeInt(Length));
    State.BufferLen := Length;
  end;
end;

procedure TPoly1305Jit.Final(var State: TPoly1305State; out Tag: TPoly1305Tag);
var
  I: Integer;
  C, F: UInt64;
  H0, H1, H2, H3, H4: UInt64;
  G0, G1, G2, G3, G4: UInt64;
  Words: array[0..3] of Cardinal;
begin
  if State.Finalized <> 0 then raise EInvalidOp.Create('Poly1305 state is finalized');
  if State.BufferLen <> 0 then
  begin
    State.Buffer[Integer(State.BufferLen)] := 1;
    for I := Integer(State.BufferLen) + 1 to 15 do State.Buffer[I] := 0;
    ProcessBlocks(State, @State.Buffer[0], 1, 0);
  end;
  H0 := State.H[0]; H1 := State.H[1]; H2 := State.H[2]; H3 := State.H[3]; H4 := State.H[4];
  C := H1 shr 26; H1 := H1 and Mask26; H2 := H2 + C;
  C := H2 shr 26; H2 := H2 and Mask26; H3 := H3 + C;
  C := H3 shr 26; H3 := H3 and Mask26; H4 := H4 + C;
  C := H4 shr 26; H4 := H4 and Mask26; H0 := H0 + C * 5;
  C := H0 shr 26; H0 := H0 and Mask26; H1 := H1 + C;
  G0 := H0 + 5; C := G0 shr 26; G0 := G0 and Mask26;
  G1 := H1 + C; C := G1 shr 26; G1 := G1 and Mask26;
  G2 := H2 + C; C := G2 shr 26; G2 := G2 and Mask26;
  G3 := H3 + C; C := G3 shr 26; G3 := G3 and Mask26;
  G4 := H4 + C;
  if G4 >= (UInt64(1) shl 26) then
  begin
    H0 := G0; H1 := G1; H2 := G2; H3 := G3; H4 := G4 - (UInt64(1) shl 26);
  end;
  F := UInt64(Cardinal(H0 or (H1 shl 26))) + State.Pad[0]; Words[0] := Cardinal(F); C := F shr 32;
  F := UInt64(Cardinal((H1 shr 6) or (H2 shl 20))) + State.Pad[1] + C; Words[1] := Cardinal(F); C := F shr 32;
  F := UInt64(Cardinal((H2 shr 12) or (H3 shl 14))) + State.Pad[2] + C; Words[2] := Cardinal(F); C := F shr 32;
  F := UInt64(Cardinal((H3 shr 18) or (H4 shl 8))) + State.Pad[3] + C; Words[3] := Cardinal(F);
  Move(Words[0], Tag[0], SizeOf(Tag));
  State.Finalized := 1;
  FillChar(State.R, SizeOf(State.R), 0);
  FillChar(State.S, SizeOf(State.S), 0);
  FillChar(State.H, SizeOf(State.H), 0);
  FillChar(State.D, SizeOf(State.D), 0);
  FillChar(State.Pad, SizeOf(State.Pad), 0);
  FillChar(State.Buffer, SizeOf(State.Buffer), 0);
  State.BufferLen := 0;
end;

function TPoly1305Jit.Compute(Buffer: Pointer; Length: NativeUInt; const Key: TPoly1305Key): TPoly1305Tag;
var
  State: TPoly1305State;
begin
  Init(State, Key);
  try
    Update(State, Buffer, Length);
    Final(State, Result);
  finally
    FillChar(State, SizeOf(State), 0);
  end;
end;

function TPoly1305Jit.Compute(const Data: TBytes; const Key: TPoly1305Key): TPoly1305Tag;
begin
  if Length(Data) = 0 then Result := Compute(nil, 0, Key) else Result := Compute(@Data[0], NativeUInt(Length(Data)), Key);
end;

class function TPoly1305Jit.EqualTags(const A, B: TPoly1305Tag): Boolean;
var
  I: Integer;
  Diff: Byte;
begin
  Diff := 0;
  for I := 0 to High(A) do Diff := Diff or (A[I] xor B[I]);
  Result := Diff = 0;
end;

end.
