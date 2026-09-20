{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
unit NativeAsm.Algorithms.Levenshtein;

interface

uses
  System.SysUtils,
  NativeAsm.Types,
  NativeAsm.Builder,
  NativeAsm.Extensions;

type
  TLevenshteinJit = class
  private type
    TContext = packed record
      A: UInt64;
      ALen: UInt64;
      B: UInt64;
      BLen: UInt64;
      Row: UInt64;
    end;
  private
    FCode: TExecutableCode;
    FRow: TArray<Cardinal>;
    class function BuildKernel: TExecutableCode; static;
    procedure EnsureRow(ALength: Integer);
  public
    constructor Create;
    destructor Destroy; override;
    function Distance(const A, B: string): Cardinal;
    function Distances(const Needle: string; const Candidates: array of string): TArray<Cardinal>;
    function FindBest(const Needle: string; const Candidates: array of string; out Distance: Cardinal): Integer;
  end;

implementation

class function TLevenshteinJit.BuildKernel: TExecutableCode;
const
  OffsetA = 0;
  OffsetALen = 8;
  OffsetB = 16;
  OffsetBLen = 24;
  OffsetRow = 32;
var
  B: TAsmBuilder;
  LInit, LOuter, LInner, LEmptyA, LEmptyB, LDone: TLabel;
begin
  B := TAsmBuilder.Create;
  try
    LInit := B.NewLabel;
    LOuter := B.NewLabel;
    LInner := B.NewLabel;
    LEmptyA := B.NewLabel;
    LEmptyB := B.NewLabel;
    LDone := B.NewLabel;

    B.Push(RBP).Push(RBX).Push(RSI).Push(RDI).Push(R12).Push(R13).Push(R14).Push(R15);
    B.Mov(RSI, QWordPtr(ridRCX, OffsetA));
    B.Mov(R12, QWordPtr(ridRCX, OffsetALen));
    B.Mov(RDI, QWordPtr(ridRCX, OffsetB));
    B.Mov(R13, QWordPtr(ridRCX, OffsetBLen));
    B.Mov(R14, QWordPtr(ridRCX, OffsetRow));
    B.Test(R12, R12).J(cond_JE, LEmptyA);
    B.Test(R13, R13).J(cond_JE, LEmptyB);

    B.Mov(R8, R14).Mov(EAX, 1).Mov(R10, R12);
    B.Bind(LInit);
    B.Mov(DWordPtr(ridR8), EAX).Add(R8, 4).Inc_(EAX).Dec_(R10).J(cond_JNE, LInit);

    B.Xor_(EBX, EBX);
    B.Bind(LOuter);
    B.Movzx(EDX, WordPtr(ridRDI)).Add(RDI, 2).Mov(R15D, EBX).Inc_(EBX).Mov(EAX, EBX);
    B.Mov(R8, RSI).Mov(R9, R14).Mov(R10, R12);

    B.Bind(LInner);
    B.Movzx(ECX, WordPtr(ridR8)).Xor_(R11D, R11D).Cmp(ECX, EDX).Setcc(cond_JNE, R11B).Add(R11D, R15D);
    B.Mov(ECX, DWordPtr(ridR9)).Mov(EBP, R11D);
    B.Mov(R11D, EAX).Inc_(R11D).Cmp(EBP, R11D).Cmov(cond_JA, EBP, R11D);
    B.Mov(R11D, ECX).Inc_(R11D).Cmp(EBP, R11D).Cmov(cond_JA, EBP, R11D);
    B.Mov(DWordPtr(ridR9), EBP).Mov(R15D, ECX).Mov(EAX, EBP);
    B.Add(R8, 2).Add(R9, 4).Dec_(R10).J(cond_JNE, LInner);
    B.Dec_(R13).J(cond_JNE, LOuter).J(cond_JMP, LDone);

    B.Bind(LEmptyA).Mov(RAX, R13).J(cond_JMP, LDone);
    B.Bind(LEmptyB).Mov(RAX, R12);

    B.Bind(LDone);
    B.Pop(R15).Pop(R14).Pop(R13).Pop(R12).Pop(RDI).Pop(RSI).Pop(RBX).Pop(RBP).Ret;
    Result := TExecutableCode.FromBuilder(B);
  finally
    B.Free;
  end;
end;

constructor TLevenshteinJit.Create;
begin
  inherited Create;
  FCode := BuildKernel;
end;

destructor TLevenshteinJit.Destroy;
begin
  FCode.Free;
  inherited;
end;

procedure TLevenshteinJit.EnsureRow(ALength: Integer);
begin
  if Length(FRow) < ALength then SetLength(FRow, ALength);
end;

function TLevenshteinJit.Distance(const A, B: string): Cardinal;
var
  PA, PB, PTemp: PChar;
  LA, LB, LTemp: Integer;
  Ctx: TContext;
begin
  LA := Length(A);
  LB := Length(B);
  if LA = 0 then Exit(Cardinal(LB));
  if LB = 0 then Exit(Cardinal(LA));

  PA := PChar(A);
  PB := PChar(B);
  while (LA > 0) and (LB > 0) and (PA^ = PB^) do
  begin
    Inc(PA);
    Inc(PB);
    Dec(LA);
    Dec(LB);
  end;
  while (LA > 0) and (LB > 0) and (PA[LA - 1] = PB[LB - 1]) do
  begin
    Dec(LA);
    Dec(LB);
  end;
  if LA = 0 then Exit(Cardinal(LB));
  if LB = 0 then Exit(Cardinal(LA));

  if LA > LB then
  begin
    PTemp := PA;
    PA := PB;
    PB := PTemp;
    LTemp := LA;
    LA := LB;
    LB := LTemp;
  end;

  EnsureRow(LA);
  Ctx.A := UInt64(NativeUInt(PA));
  Ctx.ALen := UInt64(LA);
  Ctx.B := UInt64(NativeUInt(PB));
  Ctx.BLen := UInt64(LB);
  Ctx.Row := UInt64(NativeUInt(@FRow[0]));
  Result := Cardinal(FCode.Run(UInt64(NativeUInt(@Ctx))));
end;

function TLevenshteinJit.Distances(const Needle: string; const Candidates: array of string): TArray<Cardinal>;
var
  I: Integer;
begin
  SetLength(Result, Length(Candidates));
  for I := 0 to High(Candidates) do Result[I] := Distance(Needle, Candidates[I]);
end;

function TLevenshteinJit.FindBest(const Needle: string; const Candidates: array of string; out Distance: Cardinal): Integer;
var
  I: Integer;
  D: Cardinal;
begin
  Result := -1;
  Distance := High(Cardinal);
  for I := 0 to High(Candidates) do
  begin
    D := Self.Distance(Needle, Candidates[I]);
    if D < Distance then
    begin
      Distance := D;
      Result := I;
      if D = 0 then Exit;
    end;
  end;
end;

end.
