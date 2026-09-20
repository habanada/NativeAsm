{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
program NativeAsmCryptoDemo;

{$APPTYPE CONSOLE}
{$ALIGN ON}
{$MINENUMSIZE 4}

uses
  System.SysUtils,
  System.Classes,
  System.Hash,
  Winapi.Windows,
  NativeAsm.Builder,
  NativeAsm.JitAlloc,
  NativeAsm.Extensions,
  NativeAsm.Simd,
  NativeAsm.Simd.Types,
  NativeAsm.Types;

const
  cSaltSize  = 16;
  cKeySize   = 16;
  cBlockSize = 16;
  cSchedSize = 176;
  cRcon: array[0..9] of Byte = ($01, $02, $04, $08, $10, $20, $40, $80, $1B, $36);
  cSha256K: array[0..63] of Cardinal = (
    $428A2F98, $71374491, $B5C0FBCF, $E9B5DBA5,
    $3956C25B, $59F111F1, $923F82A4, $AB1C5ED5,
    $D807AA98, $12835B01, $243185BE, $550C7DC3,
    $72BE5D74, $80DEB1FE, $9BDC06A7, $C19BF174,
    $E49B69C1, $EFBE4786, $0FC19DC6, $240CA1CC,
    $2DE92C6F, $4A7484AA, $5CB0A9DC, $76F988DA,
    $983E5152, $A831C66D, $B00327C8, $BF597FC7,
    $C6E00BF3, $D5A79147, $06CA6351, $14292967,
    $27B70A85, $2E1B2138, $4D2C6DFC, $53380D13,
    $650A7354, $766A0ABB, $81C2C92E, $92722C85,
    $A2BFE8A1, $A81A664B, $C24B8B70, $C76C51A3,
    $D192E819, $D6990624, $F40E3585, $106AA070,
    $19A4C116, $1E376C08, $2748774C, $34B0BCB5,
    $391C0CB3, $4ED8AA4A, $5B9CCA4F, $682E6FF3,
    $748F82EE, $78A5636F, $84C87814, $8CC70208,
    $90BEFFFA, $A4506CEB, $BEF9A3F7, $C67178F2);
  cSha256ShuffleMask: array[0..15] of Byte = (
    $03, $02, $01, $00, $07, $06, $05, $04,
    $0B, $0A, $09, $08, $0F, $0E, $0D, $0C);
  cSha256Init: array[0..7] of Cardinal = (
    $6A09E667, $BB67AE85, $3C6EF372, $A54FF53A,
    $510E527F, $9B05688C, $1F83D9AB, $5BE0CD19);

type
  TBlock = array[0..cBlockSize - 1] of Byte;
  TSchedule = array[0..cSchedSize - 1] of Byte;
  TShaBlock = array[0..63] of Byte;
  TShaState = array[0..7] of Cardinal;

function RtlGenRandom(Buffer: Pointer; RandomBufferLength: ULONG): Boolean; stdcall;
  external 'advapi32.dll' name 'SystemFunction036';

function PtrU(P: Pointer): UInt64; inline;
begin
  Result := UInt64(NativeUInt(P));
end;

procedure SecureRandom(out Block: TBlock);
begin
  if not RtlGenRandom(@Block[0], SizeOf(Block)) then
    raise Exception.Create('RtlGenRandom fehlgeschlagen');
end;

procedure IncBlock(var C: TBlock);
begin
  Inc(PUInt64(@C[0])^);
  if PUInt64(@C[0])^ = 0 then
    Inc(PUInt64(@C[8])^);
end;

procedure EmitShaRounds(B: TAsmBuilder; const Msg: TSimdRegister; KOffset: Integer);
begin
  B.Movdqa(XMM0, Msg)
   .Movdqu(XMM3, OWordPtr(ridR8, KOffset))
   .Paddd(XMM0, XMM3)
   .Sha256rnds2(XMM2, XMM1)
   .Pshufd(XMM0, XMM0, $0E)
   .Sha256rnds2(XMM1, XMM2);
end;

procedure EmitShaSchedule(B: TAsmBuilder; const Dest, High, Prev: TSimdRegister);
begin
  B.Movdqa(XMM3, High)
   .Palignr(XMM3, Prev, 4)
   .Paddd(Dest, XMM3)
   .Sha256msg2(Dest, High);
end;

function BuildSha256CompressJit: TExecutableCode;
var
  B: TAsmBuilder;
begin
  B := TAsmBuilder.New;
  try
    B.Sub(RSP, 64)
     .Movdqu(OWordPtr(ridRSP, 0), XMM6)
     .Movdqu(OWordPtr(ridRSP, 16), XMM7)
     .Movdqu(OWordPtr(ridRSP, 32), XMM8)
     .Movdqu(OWordPtr(ridRSP, 48), XMM9)
     .Movdqu(XMM3, OWordPtr(ridRCX, 0))
     .Movdqu(XMM2, OWordPtr(ridRCX, 16))
     .Pshufd(XMM3, XMM3, $B1)
     .Pshufd(XMM2, XMM2, $1B)
     .Movdqa(XMM1, XMM3)
     .Palignr(XMM1, XMM2, 8)
     .Pblendw(XMM2, XMM3, $F0)
     .Movdqa(XMM8, XMM1)
     .Movdqa(XMM9, XMM2)
     .Movdqu(XMM4, OWordPtr(ridRDX, 0))
     .Movdqu(XMM3, OWordPtr(ridR9))
     .Pshufb(XMM4, XMM3);
    EmitShaRounds(B, XMM4, 0);
    B.Movdqu(XMM5, OWordPtr(ridRDX, 16))
     .Movdqu(XMM3, OWordPtr(ridR9))
     .Pshufb(XMM5, XMM3);
    EmitShaRounds(B, XMM5, 16);
    B.Sha256msg1(XMM4, XMM5)
     .Movdqu(XMM6, OWordPtr(ridRDX, 32))
     .Movdqu(XMM3, OWordPtr(ridR9))
     .Pshufb(XMM6, XMM3);
    EmitShaRounds(B, XMM6, 32);
    B.Sha256msg1(XMM5, XMM6)
     .Movdqu(XMM7, OWordPtr(ridRDX, 48))
     .Movdqu(XMM3, OWordPtr(ridR9))
     .Pshufb(XMM7, XMM3);
    EmitShaRounds(B, XMM7, 48);
    EmitShaSchedule(B, XMM4, XMM7, XMM6);
    B.Sha256msg1(XMM6, XMM7);
    EmitShaRounds(B, XMM4, 64);
    EmitShaSchedule(B, XMM5, XMM4, XMM7);
    B.Sha256msg1(XMM7, XMM4);
    EmitShaRounds(B, XMM5, 80);
    EmitShaSchedule(B, XMM6, XMM5, XMM4);
    B.Sha256msg1(XMM4, XMM5);
    EmitShaRounds(B, XMM6, 96);
    EmitShaSchedule(B, XMM7, XMM6, XMM5);
    B.Sha256msg1(XMM5, XMM6);
    EmitShaRounds(B, XMM7, 112);
    EmitShaSchedule(B, XMM4, XMM7, XMM6);
    B.Sha256msg1(XMM6, XMM7);
    EmitShaRounds(B, XMM4, 128);
    EmitShaSchedule(B, XMM5, XMM4, XMM7);
    B.Sha256msg1(XMM7, XMM4);
    EmitShaRounds(B, XMM5, 144);
    EmitShaSchedule(B, XMM6, XMM5, XMM4);
    B.Sha256msg1(XMM4, XMM5);
    EmitShaRounds(B, XMM6, 160);
    EmitShaSchedule(B, XMM7, XMM6, XMM5);
    B.Sha256msg1(XMM5, XMM6);
    EmitShaRounds(B, XMM7, 176);
    EmitShaSchedule(B, XMM4, XMM7, XMM6);
    B.Sha256msg1(XMM6, XMM7);
    EmitShaRounds(B, XMM4, 192);
    EmitShaSchedule(B, XMM5, XMM4, XMM7);
    B.Sha256msg1(XMM7, XMM4);
    EmitShaRounds(B, XMM5, 208);
    EmitShaSchedule(B, XMM6, XMM5, XMM4);
    EmitShaRounds(B, XMM6, 224);
    EmitShaSchedule(B, XMM7, XMM6, XMM5);
    EmitShaRounds(B, XMM7, 240);
    B.Paddd(XMM1, XMM8)
     .Paddd(XMM2, XMM9)
     .Pshufd(XMM3, XMM1, $1B)
     .Pshufd(XMM2, XMM2, $B1)
     .Movdqa(XMM1, XMM3)
     .Pblendw(XMM1, XMM2, $F0)
     .Palignr(XMM2, XMM3, 8)
     .Movdqu(OWordPtr(ridRCX, 0), XMM1)
     .Movdqu(OWordPtr(ridRCX, 16), XMM2)
     .Movdqu(XMM6, OWordPtr(ridRSP, 0))
     .Movdqu(XMM7, OWordPtr(ridRSP, 16))
     .Movdqu(XMM8, OWordPtr(ridRSP, 32))
     .Movdqu(XMM9, OWordPtr(ridRSP, 48))
     .Add(RSP, 64)
     .Ret;
    Result := TExecutableCode.FromBuilder(B);
  finally
    B.Free;
  end;
end;

procedure Sha256Compress(Exe: TExecutableCode; var State: TShaState; Block: Pointer);
begin
  Exe.Run(PtrU(@State[0]), PtrU(Block), PtrU(@cSha256K[0]), PtrU(@cSha256ShuffleMask[0]));
end;

procedure StoreBitLength(var Block: TShaBlock; BitLength: UInt64);
var
  I: Integer;
begin
  for I := 0 to 7 do
    Block[63 - I] := Byte(BitLength shr (I * 8));
end;

function Sha256Jit(Exe: TExecutableCode; const Data: TBytes): TBytes;
var
  State: TShaState;
  Tail: TShaBlock;
  Offset, Remaining, I: Integer;
  BitLength: UInt64;
begin
  Move(cSha256Init[0], State[0], SizeOf(State));
  Offset := 0;
  while Length(Data) - Offset >= SizeOf(Tail) do
  begin
    Sha256Compress(Exe, State, @Data[Offset]);
    Inc(Offset, SizeOf(Tail));
  end;
  FillChar(Tail, SizeOf(Tail), 0);
  Remaining := Length(Data) - Offset;
  if Remaining > 0 then
    Move(Data[Offset], Tail[0], Remaining);
  Tail[Remaining] := $80;
  BitLength := UInt64(Length(Data)) * 8;
  if Remaining >= 56 then
  begin
    Sha256Compress(Exe, State, @Tail[0]);
    FillChar(Tail, SizeOf(Tail), 0);
  end;
  StoreBitLength(Tail, BitLength);
  Sha256Compress(Exe, State, @Tail[0]);
  SetLength(Result, 32);
  for I := 0 to 7 do
  begin
    Result[I * 4 + 0] := Byte(State[I] shr 24);
    Result[I * 4 + 1] := Byte(State[I] shr 16);
    Result[I * 4 + 2] := Byte(State[I] shr 8);
    Result[I * 4 + 3] := Byte(State[I]);
  end;
end;

procedure VerifySha256Jit(Exe: TExecutableCode);
var
  Data, Expected, Actual: TBytes;
begin
  Data := TEncoding.ASCII.GetBytes('abc');
  Expected := THashSHA2.GetHashBytes('abc');
  Actual := Sha256Jit(Exe, Data);
  if (Length(Expected) <> Length(Actual)) or not CompareMem(@Expected[0], @Actual[0], Length(Expected)) then
    raise Exception.Create('SHA-256 JIT self-test fehlgeschlagen');
end;

function DeriveKey(ShaExe: TExecutableCode; const Salt: TBlock; const Password: string): TBlock;
var
  Combined: TBytes;
  PWBytes: TBytes;
  Digest: TBytes;
begin
  PWBytes := TEncoding.UTF8.GetBytes(Password);
  SetLength(Combined, cSaltSize + Length(PWBytes));
  Move(Salt[0], Combined[0], cSaltSize);
  if Length(PWBytes) > 0 then
    Move(PWBytes[0], Combined[cSaltSize], Length(PWBytes));
  Digest := Sha256Jit(ShaExe, Combined);
  Move(Digest[0], Result[0], cKeySize);
end;

function BuildExpandKeyJit: TExecutableCode;
var
  B: TAsmBuilder;
  I: Integer;
begin
  B := TAsmBuilder.New;
  try
    B.Movdqu(XMM0, OWordPtr(ridRCX))
     .Movdqu(OWordPtr(ridRDX), XMM0);
    for I := 0 to 9 do
    begin
      B.Aeskeygenassist(XMM2, XMM0, cRcon[I])
       .Pshufd(XMM2, XMM2, $FF)
       .Movdqa(XMM3, XMM0)
       .Pslldq(XMM3, 4)
       .Pxor(XMM0, XMM3)
       .Pslldq(XMM3, 4)
       .Pxor(XMM0, XMM3)
       .Pslldq(XMM3, 4)
       .Pxor(XMM0, XMM3)
       .Pxor(XMM0, XMM2)
       .Movdqu(OWordPtr(ridRDX, (I + 1) * cBlockSize), XMM0);
    end;
    B.Ret;
    Result := TExecutableCode.FromBuilder(B);
  finally
    B.Free;
  end;
end;

function BuildGenKeystreamJit: TExecutableCode;
var
  B: TAsmBuilder;
  I: Integer;
begin
  B := TAsmBuilder.New;
  try
    B.Movdqu(XMM0, OWordPtr(ridRDX))
     .Pxor(XMM0, OWordPtr(ridRCX));
    for I := 1 to 9 do
      B.Aesenc(XMM0, OWordPtr(ridRCX, I * cBlockSize));
    B.Aesenclast(XMM0, OWordPtr(ridRCX, 10 * cBlockSize))
     .Movdqu(OWordPtr(ridR8), XMM0)
     .Ret;
    Result := TExecutableCode.FromBuilder(B);
  finally
    B.Free;
  end;
end;

procedure ExpandKey(Exe: TExecutableCode; const Key: TBlock; out Sched: TSchedule);
begin
  Exe.Run(PtrU(@Key[0]), PtrU(@Sched[0]));
end;

procedure ProcessStream(InStream, OutStream: TStream; const Sched: TSchedule;
  const InitCounter: TBlock; GenKSExe: TExecutableCode);
var
  Counter, KS, Buf: TBlock;
  Read, I: Integer;
begin
  Counter := InitCounter;
  Read := InStream.Read(Buf[0], cBlockSize);
  while Read > 0 do
  begin
    GenKSExe.Run(PtrU(@Sched[0]), PtrU(@Counter[0]), PtrU(@KS[0]));
    for I := 0 to Read - 1 do
      Buf[I] := Buf[I] xor KS[I];
    OutStream.WriteBuffer(Buf[0], Read);
    IncBlock(Counter);
    Read := InStream.Read(Buf[0], cBlockSize);
  end;
end;

procedure Encrypt(const InputPath, OutputPath, Password: string;
  ExpandExe, GenKSExe, ShaExe: TExecutableCode);
var
  InStream, OutStream: TFileStream;
  Salt, Nonce, Key: TBlock;
  Sched: TSchedule;
begin
  SecureRandom(Salt);
  SecureRandom(Nonce);
  Key := DeriveKey(ShaExe, Salt, Password);
  ExpandKey(ExpandExe, Key, Sched);
  InStream := TFileStream.Create(InputPath, fmOpenRead or fmShareDenyWrite);
  try
    OutStream := TFileStream.Create(OutputPath, fmCreate);
    try
      OutStream.WriteBuffer(Salt[0], cSaltSize);
      OutStream.WriteBuffer(Nonce[0], cBlockSize);
      ProcessStream(InStream, OutStream, Sched, Nonce, GenKSExe);
    finally
      OutStream.Free;
    end;
  finally
    InStream.Free;
  end;
end;

procedure Decrypt(const InputPath, OutputPath, Password: string;
  ExpandExe, GenKSExe, ShaExe: TExecutableCode);
var
  InStream, OutStream: TFileStream;
  Salt, Nonce, Key: TBlock;
  Sched: TSchedule;
begin
  InStream := TFileStream.Create(InputPath, fmOpenRead or fmShareDenyWrite);
  try
    if InStream.Size < cSaltSize + cBlockSize then
      raise Exception.Create('Datei zu klein: kein gueltiger Dateiheader');
    InStream.ReadBuffer(Salt[0], cSaltSize);
    InStream.ReadBuffer(Nonce[0], cBlockSize);
    Key := DeriveKey(ShaExe, Salt, Password);
    ExpandKey(ExpandExe, Key, Sched);
    OutStream := TFileStream.Create(OutputPath, fmCreate);
    try
      ProcessStream(InStream, OutStream, Sched, Nonce, GenKSExe);
    finally
      OutStream.Free;
    end;
  finally
    InStream.Free;
  end;
end;

var
  ExpandExe, GenKSExe, ShaExe: TExecutableCode;
  Mode: Char;
begin
  try
    if ParamCount < 4 then
    begin
      WriteLn('Verwendung: NativeAsmCryptoDemo e|d <Eingabe> <Ausgabe> <Passwort>');
      WriteLn('  e = verschluesseln');
      WriteLn('  d = entschluesseln');
      Halt(1);
    end;
    Mode := LowerCase(ParamStr(1))[1];
    WriteLn('NativeAsm AES-128-CTR + SHA-256 SHA-NI Demo');
    WriteLn('JIT-Kompilierung von SHA-256, AES-Key-Expansion und Keystream...');
    ShaExe := BuildSha256CompressJit;
    try
      VerifySha256Jit(ShaExe);
      WriteLn('SHA-256 JIT self-test: PASS');
      ExpandExe := BuildExpandKeyJit;
      try
        GenKSExe := BuildGenKeystreamJit;
        try
          case Mode of
            'e':
              begin
                WriteLn('Verschluessle: ', ParamStr(2), ' -> ', ParamStr(3));
                Encrypt(ParamStr(2), ParamStr(3), ParamStr(4), ExpandExe, GenKSExe, ShaExe);
              end;
            'd':
              begin
                WriteLn('Entschluessle: ', ParamStr(2), ' -> ', ParamStr(3));
                Decrypt(ParamStr(2), ParamStr(3), ParamStr(4), ExpandExe, GenKSExe, ShaExe);
              end;
          else
            WriteLn('Unbekannter Modus: ', ParamStr(1), ' (e oder d erwartet)');
            Halt(1);
          end;
          WriteLn('Fertig: ', ParamStr(3));
        finally
          GenKSExe.Free;
        end;
      finally
        ExpandExe.Free;
      end;
    finally
      ShaExe.Free;
    end;
  except
    on E: Exception do
    begin
      WriteLn('Fehler: ', E.Message);
      Halt(2);
    end;
  end;
end.

