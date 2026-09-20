{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
unit NativeAsm.Practical.AhoCorasick;

interface

uses
  System.SysUtils,
  System.Math,
  System.Generics.Collections,
  NativeAsm.Types,
  NativeAsm.Builder,
  NativeAsm.Extensions,
  NativeAsm.CpuFeatures;

type
  TAhoSimdMode = (smAuto, smScalar, smSse2, smSse42);

  TAhoMatch = record
    PatternIndex: Integer;
    StartIndex: Integer;
    EndIndex: Integer;
  end;

  TAhoCorasickJit = class
  private type
    TRawMatch = packed record
      PatternIndex: Cardinal;
      EndIndex: Cardinal;
    end;

    TBuildState = record
      FirstEdge: Integer;
      Fail: Integer;
      OutputMask: UInt64;
    end;

    TBuildEdge = record
      Ch: Word;
      NextState: Integer;
      NextEdge: Integer;
    end;
  private
    FPatterns: TArray<string>;
    FPatternLengths: TArray<Integer>;
    FCharClass: TArray<Word>;
    FNext: TArray<Integer>;
    FOutputs: TArray<UInt64>;
    FRootVectorStorage: TBytes;
    FRootVectors: Pointer;
    FRawMatches: TArray<TRawMatch>;
    FCodeAll: TExecutableCode;
    FCodeFirst: TExecutableCode;
    FStateCount: Integer;
    FAlphabetSize: Integer;
    FStride: Integer;
    FRootCount: Integer;
    FRequestedSimdMode: TAhoSimdMode;
    FActiveSimdMode: TAhoSimdMode;
    FUsesSimdRootScan: Boolean;
    FUsesSse42RootScan: Boolean;
    class function FindEdge(const States: TList<TBuildState>; const Edges: TList<TBuildEdge>; State: Integer; Ch: Word): Integer; static;
    procedure BuildAutomaton;
    procedure BuildRootVectors(const RootChars: TArray<Word>);
    function BuildKernel(StopAfterFirst: Boolean): TExecutableCode;
    procedure EnsureRawCapacity(Count: Integer);
    function MakeMatch(const Raw: TRawMatch): TAhoMatch;
    function GetPatternCount: Integer;
    function GetPattern(Index: Integer): string;
  public
    constructor Create(const Patterns: array of string; SimdMode: TAhoSimdMode = smAuto);
    destructor Destroy; override;
    function FindAll(const Text: string): TArray<TAhoMatch>;
    function FindFirst(const Text: string; out Match: TAhoMatch): Boolean;
    function Contains(const Text: string): Boolean;
    function CountMatches(const Text: string): UInt64;
    class function IsSse42Available: Boolean; static;
    property PatternCount: Integer read GetPatternCount;
    property Patterns[Index: Integer]: string read GetPattern;
    property StateCount: Integer read FStateCount;
    property AlphabetSize: Integer read FAlphabetSize;
    property UsesSimdRootScan: Boolean read FUsesSimdRootScan;
    property UsesSse42RootScan: Boolean read FUsesSse42RootScan;
    property SimdMode: TAhoSimdMode read FActiveSimdMode;
  end;

implementation

uses
  NativeAsm.Simd,
  NativeAsm.Simd.Types;

class function TAhoCorasickJit.FindEdge(const States: TList<TBuildState>; const Edges: TList<TBuildEdge>; State: Integer; Ch: Word): Integer;
var
  I: Integer;
  E: TBuildEdge;
begin
  I := States[State].FirstEdge;
  while I >= 0 do
  begin
    E := Edges[I];
    if E.Ch = Ch then Exit(E.NextState);
    I := E.NextEdge;
  end;
  Result := -1;
end;

class function TAhoCorasickJit.IsSse42Available: Boolean;
begin
  Result := TCpuFeatures.Supports(cfSSE42);
end;

procedure TAhoCorasickJit.BuildRootVectors(const RootChars: TArray<Word>);
var
  I, J: Integer;
  P: PWord;
  A: NativeUInt;
begin
  FRootCount := Length(RootChars);
  FActiveSimdMode := smScalar;
  FUsesSimdRootScan := False;
  FUsesSse42RootScan := False;
  FRootVectors := nil;
  SetLength(FRootVectorStorage, 0);
  if (FRootCount = 0) or (FRootCount > 16) or (FRequestedSimdMode = smScalar) then Exit;
  case FRequestedSimdMode of
    smAuto: if IsSse42Available then FActiveSimdMode := smSse42 else FActiveSimdMode := smSse2;
    smSse2: FActiveSimdMode := smSse2;
    smSse42:
      begin
        if not IsSse42Available then raise EInvalidOp.Create('SSE4.2 is not available on this CPU');
        FActiveSimdMode := smSse42;
      end;
  end;
  FUsesSimdRootScan := FActiveSimdMode <> smScalar;
  FUsesSse42RootScan := FActiveSimdMode = smSse42;
  if FUsesSse42RootScan then SetLength(FRootVectorStorage, 32 + 15) else SetLength(FRootVectorStorage, FRootCount * 16 + 15);
  A := (NativeUInt(@FRootVectorStorage[0]) + 15) and not NativeUInt(15);
  FRootVectors := Pointer(A);
  P := PWord(FRootVectors);
  if FUsesSse42RootScan then
  begin
    for I := 0 to 15 do
    begin
      if I < FRootCount then P^ := RootChars[I] else P^ := 0;
      Inc(P);
    end;
  end
  else
    for I := 0 to FRootCount - 1 do
      for J := 0 to 7 do
      begin
        P^ := RootChars[I];
        Inc(P);
      end;
end;

procedure TAhoCorasickJit.BuildAutomaton;
var
  States: TList<TBuildState>;
  Edges: TList<TBuildEdge>;
  Alphabet: TList<Word>;
  RootChars: TList<Word>;
  Queue: TQueue<Integer>;
  Order: TList<Integer>;
  S, ChildState: TBuildState;
  E: TBuildEdge;
  I, J, State, NextState, EdgeIndex, R, F, Target, ClassID: Integer;
  Ch: Word;
  TableCount: Int64;
begin
  States := TList<TBuildState>.Create;
  Edges := TList<TBuildEdge>.Create;
  Alphabet := TList<Word>.Create;
  RootChars := TList<Word>.Create;
  Queue := TQueue<Integer>.Create;
  Order := TList<Integer>.Create;
  try
    SetLength(FCharClass, 65536);
    S.FirstEdge := -1;
    S.Fail := 0;
    S.OutputMask := 0;
    States.Add(S);

    for I := 0 to High(FPatterns) do
    begin
      if FPatterns[I] = '' then raise EArgumentException.CreateFmt('Pattern %d is empty', [I]);
      FPatternLengths[I] := Length(FPatterns[I]);
      State := 0;
      for J := 1 to Length(FPatterns[I]) do
      begin
        Ch := Ord(FPatterns[I][J]);
        if FCharClass[Ch] = 0 then
        begin
          FCharClass[Ch] := High(Word);
          Alphabet.Add(Ch);
        end;
        NextState := FindEdge(States, Edges, State, Ch);
        if NextState < 0 then
        begin
          S.FirstEdge := -1;
          S.Fail := 0;
          S.OutputMask := 0;
          NextState := States.Count;
          States.Add(S);
          E.Ch := Ch;
          E.NextState := NextState;
          E.NextEdge := States[State].FirstEdge;
          Edges.Add(E);
          S := States[State];
          S.FirstEdge := Edges.Count - 1;
          States[State] := S;
        end;
        State := NextState;
      end;
      S := States[State];
      S.OutputMask := S.OutputMask or (UInt64(1) shl I);
      States[State] := S;
    end;

    if Alphabet.Count > High(Word) then raise ERangeError.Create('Aho-Corasick alphabet exceeds 65535 UTF-16 code units');
    for I := 0 to Alphabet.Count - 1 do FCharClass[Alphabet[I]] := Word(I + 1);
    FAlphabetSize := Alphabet.Count;
    FStride := FAlphabetSize + 1;

    Order.Add(0);
    EdgeIndex := States[0].FirstEdge;
    while EdgeIndex >= 0 do
    begin
      E := Edges[EdgeIndex];
      ChildState := States[E.NextState];
      ChildState.Fail := 0;
      States[E.NextState] := ChildState;
      Queue.Enqueue(E.NextState);
      RootChars.Add(E.Ch);
      EdgeIndex := E.NextEdge;
    end;

    while Queue.Count > 0 do
    begin
      R := Queue.Dequeue;
      Order.Add(R);
      EdgeIndex := States[R].FirstEdge;
      while EdgeIndex >= 0 do
      begin
        E := Edges[EdgeIndex];
        F := States[R].Fail;
        Target := FindEdge(States, Edges, F, E.Ch);
        while (F <> 0) and (Target < 0) do
        begin
          F := States[F].Fail;
          Target := FindEdge(States, Edges, F, E.Ch);
        end;
        if Target < 0 then Target := FindEdge(States, Edges, 0, E.Ch);
        if Target < 0 then Target := 0;
        ChildState := States[E.NextState];
        ChildState.Fail := Target;
        ChildState.OutputMask := ChildState.OutputMask or States[Target].OutputMask;
        States[E.NextState] := ChildState;
        Queue.Enqueue(E.NextState);
        EdgeIndex := E.NextEdge;
      end;
    end;

    FStateCount := States.Count;
    TableCount := Int64(FStateCount) * Int64(FStride);
    if TableCount > MaxInt then raise ERangeError.Create('Aho-Corasick transition table exceeds Delphi array limits');
    if TableCount * SizeOf(Integer) > Int64(512) * 1024 * 1024 then raise ERangeError.Create('Aho-Corasick transition table would exceed 512 MB');
    SetLength(FNext, Integer(TableCount));
    SetLength(FOutputs, FStateCount);
    for I := 0 to FStateCount - 1 do FOutputs[I] := States[I].OutputMask;

    EdgeIndex := States[0].FirstEdge;
    while EdgeIndex >= 0 do
    begin
      E := Edges[EdgeIndex];
      ClassID := FCharClass[E.Ch];
      FNext[ClassID] := E.NextState;
      EdgeIndex := E.NextEdge;
    end;

    for I := 1 to Order.Count - 1 do
    begin
      State := Order[I];
      F := States[State].Fail;
      Move(FNext[F * FStride], FNext[State * FStride], FStride * SizeOf(Integer));
      EdgeIndex := States[State].FirstEdge;
      while EdgeIndex >= 0 do
      begin
        E := Edges[EdgeIndex];
        ClassID := FCharClass[E.Ch];
        FNext[State * FStride + ClassID] := E.NextState;
        EdgeIndex := E.NextEdge;
      end;
    end;

    BuildRootVectors(RootChars.ToArray);
  finally
    Order.Free;
    Queue.Free;
    RootChars.Free;
    Alphabet.Free;
    Edges.Free;
    States.Free;
  end;
end;

function TAhoCorasickJit.BuildKernel(StopAfterFirst: Boolean): TExecutableCode;
var
  B: TAsmBuilder;
  LLoop, LScalar, LRootCompare, LRootFound, LAfterOutputs, LOutputLoop, LSkipWrite, LDone: TLabel;
begin
  B := TAsmBuilder.Create;
  try
    LLoop := B.NewLabel;
    LScalar := B.NewLabel;
    LRootCompare := B.NewLabel;
    LRootFound := B.NewLabel;
    LAfterOutputs := B.NewLabel;
    LOutputLoop := B.NewLabel;
    LSkipWrite := B.NewLabel;
    LDone := B.NewLabel;

    B.Push(RBX).Push(RBP).Push(RSI).Push(RDI).Push(R12).Push(R13).Push(R14).Push(R15);
    B.Mov(RDI, RCX).Mov(ESI, EDX).Xor_(EBP, EBP).Xor_(R10D, R10D).Xor_(R11, R11);
    B.Mov(R12, Int64(NativeUInt(@FCharClass[0])));
    B.Mov(R13, Int64(NativeUInt(@FNext[0])));
    B.Mov(R14, Int64(NativeUInt(@FOutputs[0])));
    if FUsesSimdRootScan then B.Mov(R15, Int64(NativeUInt(FRootVectors)));
    B.Test(ESI, ESI).J(cond_JE, LDone);

    B.Bind(LLoop);
    if FUsesSimdRootScan then
    begin
      B.Cmp(R10D, 0).J(cond_JNE, LScalar);
      B.Cmp(ESI, 8).J(cond_JB, LScalar);
      if FUsesSse42RootScan then
      begin
        B.Movdqu(XMM1, NativeAsm.Simd.Types.OWordPtr(ridRDI));
        B.Movdqu(XMM0, NativeAsm.Simd.Types.OWordPtr(ridR15));
        B.Mov(EAX, Min(FRootCount, 8)).Mov(EDX, 8);
        B.Pcmpestri(XMM0, XMM1, 1);
        if FRootCount > 8 then
        begin
          B.Mov(R10D, ECX);
          B.Movdqu(XMM0, NativeAsm.Simd.Types.OWordPtr(ridR15, $10));
          B.Mov(EAX, FRootCount - 8).Mov(EDX, 8);
          B.Pcmpestri(XMM0, XMM1, 1);
          B.Cmp(ECX, R10D).Cmov(cond_JB, R10D, ECX).Mov(ECX, R10D).Xor_(R10D, R10D);
        end;
        B.Cmp(ECX, 8).J(cond_JB, LRootFound);
      end
      else
      begin
        B.Movdqu(XMM0, NativeAsm.Simd.Types.OWordPtr(ridRDI));
        B.Pxor(XMM1, XMM1);
        B.Mov(RCX, R15).Mov(EDX, FRootCount);
        B.Bind(LRootCompare);
        B.Movdqu(XMM2, NativeAsm.Simd.Types.OWordPtr(ridRCX));
        B.Movdqa(XMM3, XMM0);
        B.Pcmpeqw(XMM3, XMM2);
        B.Por(XMM1, XMM3);
        B.Add(RCX, 16).Dec_(EDX).J(cond_JNE, LRootCompare);
        B.Pmovmskb(EAX, XMM1);
        B.Test(EAX, EAX).J(cond_JNE, LRootFound);
      end;
      B.Add(RDI, 16).Add(EBP, 8).Sub(ESI, 8).Test(ESI, ESI).J(cond_JNE, LLoop).J(cond_JMP, LDone);
      B.Bind(LRootFound);
      if FUsesSse42RootScan then B.Mov(EAX, ECX) else B.Bsf(EAX, EAX).Shr_(EAX, 1);
      B.Lea(RDI, TMemory.CreateSib(ridRDI, ridRAX, s2)).Add(EBP, EAX).Sub(ESI, EAX);
    end;

    B.Bind(LScalar);
    B.Movzx(EAX, WordPtr(ridRDI));
    B.Movzx(ECX, TMemory.CreateSib(ridR12, ridRAX, s2, 0, sz16));
    B.Mov(EAX, R10D).Imul(EAX, EAX, FStride).Add(EAX, ECX);
    B.Mov(R10D, TMemory.CreateSib(ridR13, ridRAX, s4, 0, sz32));
    B.Mov(RBX, QWordPtrSib(ridR14, ridR10, s8));
    B.Test(RBX, RBX).J(cond_JE, LAfterOutputs);

    B.Bind(LOutputLoop);
    B.Bsf(RAX, RBX);
    B.Cmp(R11, R9).J(cond_JAE, LSkipWrite);
    B.Mov(DWordPtr(ridR8), EAX).Mov(DWordPtr(ridR8, 4), EBP).Add(R8, 8);
    B.Bind(LSkipWrite);
    B.Inc_(R11);
    if StopAfterFirst then B.J(cond_JMP, LDone);
    B.Mov(RCX, RBX).Dec_(RCX).And_(RBX, RCX).Test(RBX, RBX).J(cond_JNE, LOutputLoop);

    B.Bind(LAfterOutputs);
    B.Add(RDI, 2).Inc_(EBP).Dec_(ESI).J(cond_JNE, LLoop);

    B.Bind(LDone);
    B.Mov(RAX, R11);
    B.Pop(R15).Pop(R14).Pop(R13).Pop(R12).Pop(RDI).Pop(RSI).Pop(RBP).Pop(RBX).Ret;
    Result := TExecutableCode.FromBuilder(B);
  finally
    B.Free;
  end;
end;

constructor TAhoCorasickJit.Create(const Patterns: array of string; SimdMode: TAhoSimdMode);
var
  I: Integer;
begin
  inherited Create;
  FRequestedSimdMode := SimdMode;
  if Length(Patterns) > 64 then raise EArgumentOutOfRangeException.Create('Aho-Corasick JIT supports at most 64 patterns');
  SetLength(FPatterns, Length(Patterns));
  SetLength(FPatternLengths, Length(Patterns));
  for I := 0 to High(Patterns) do FPatterns[I] := Patterns[I];
  BuildAutomaton;
  FCodeAll := BuildKernel(False);
  FCodeFirst := BuildKernel(True);
end;

destructor TAhoCorasickJit.Destroy;
begin
  FCodeFirst.Free;
  FCodeAll.Free;
  inherited;
end;

procedure TAhoCorasickJit.EnsureRawCapacity(Count: Integer);
begin
  if Length(FRawMatches) < Count then SetLength(FRawMatches, Count);
end;

function TAhoCorasickJit.MakeMatch(const Raw: TRawMatch): TAhoMatch;
var
  P: Integer;
begin
  P := Integer(Raw.PatternIndex);
  Result.PatternIndex := P;
  Result.EndIndex := Integer(Raw.EndIndex) + 1;
  Result.StartIndex := Result.EndIndex - FPatternLengths[P] + 1;
end;

function TAhoCorasickJit.FindAll(const Text: string): TArray<TAhoMatch>;
var
  Total, Total2: UInt64;
  I: Integer;
  P: Pointer;
begin
  if Text = '' then
  begin
    SetLength(Result, 0);
    Exit;
  end;
  EnsureRawCapacity(64);
  P := @FRawMatches[0];
  Total := FCodeAll.Run(UInt64(NativeUInt(PChar(Text))), UInt64(Length(Text)), UInt64(NativeUInt(P)), UInt64(Length(FRawMatches)));
  if Total > UInt64(MaxInt) then raise ERangeError.Create('Aho-Corasick match count exceeds Delphi array limits');
  if Total > UInt64(Length(FRawMatches)) then
  begin
    EnsureRawCapacity(Integer(Total));
    P := @FRawMatches[0];
    Total2 := FCodeAll.Run(UInt64(NativeUInt(PChar(Text))), UInt64(Length(Text)), UInt64(NativeUInt(P)), UInt64(Length(FRawMatches)));
    if Total2 <> Total then raise EInvalidOp.Create('Aho-Corasick JIT returned an unstable match count');
  end;
  SetLength(Result, Integer(Total));
  for I := 0 to High(Result) do Result[I] := MakeMatch(FRawMatches[I]);
end;

function TAhoCorasickJit.FindFirst(const Text: string; out Match: TAhoMatch): Boolean;
var
  Raw: TRawMatch;
  Count: UInt64;
begin
  Match := Default(TAhoMatch);
  if Text = '' then Exit(False);
  Count := FCodeFirst.Run(UInt64(NativeUInt(PChar(Text))), UInt64(Length(Text)), UInt64(NativeUInt(@Raw)), 1);
  Result := Count <> 0;
  if Result then Match := MakeMatch(Raw);
end;

function TAhoCorasickJit.Contains(const Text: string): Boolean;
begin
  if Text = '' then Exit(False);
  Result := FCodeFirst.Run(UInt64(NativeUInt(PChar(Text))), UInt64(Length(Text)), 0, 0) <> 0;
end;

function TAhoCorasickJit.CountMatches(const Text: string): UInt64;
begin
  if Text = '' then Exit(0);
  Result := FCodeAll.Run(UInt64(NativeUInt(PChar(Text))), UInt64(Length(Text)), 0, 0);
end;

function TAhoCorasickJit.GetPatternCount: Integer;
begin
  Result := Length(FPatterns);
end;

function TAhoCorasickJit.GetPattern(Index: Integer): string;
begin
  if (Index < 0) or (Index >= Length(FPatterns)) then raise EArgumentOutOfRangeException.CreateFmt('Pattern index %d is out of range', [Index]);
  Result := FPatterns[Index];
end;

end.
