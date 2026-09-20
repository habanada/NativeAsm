{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
program StaticDbRegression;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  NativeAsm.Types,
  NativeAsm.Builder,
  NativeAsm.InstructionDB;

procedure AssertBytes(const Name: string; const Actual: TBytes;
  const Expected: array of Byte);
var
  I: Integer;
begin
  if Length(Actual) <> Length(Expected) then
    raise Exception.CreateFmt('%s: length %d <> expected %d',
      [Name, Length(Actual), Length(Expected)]);
  for I := 0 to High(Expected) do
    if Actual[I] <> Expected[I] then
      raise Exception.CreateFmt('%s: byte[%d]=$%.2x <> expected $%.2x',
        [Name, I, Actual[I], Expected[I]]);
end;

procedure Check(const Name: string; B: TAsmBuilder;
  const Expected: array of Byte);
begin
  try
    AssertBytes(Name, B.Build, Expected);
  finally
    B.Free;
  end;
end;

procedure TestCanonicalEncodings;
var
  B: TAsmBuilder;
  L: TLabel;
begin
  Check('mov rax,rbx', TAsmBuilder.New.Mov(RAX, RBX),
    [$48, $8B, $C3]);
  Check('mov rax,1', TAsmBuilder.New.Mov(RAX, 1),
    [$48, $C7, $C0, $01, $00, $00, $00]);

  // Small immediate prefers 83 /0 ib over the longer accumulator alternative.
  Check('add rax,1', TAsmBuilder.New.Add(RAX, 1),
    [$48, $83, $C0, $01]);
  // A larger immediate makes the accumulator opcode one byte shorter than 81 /0.
  Check('add rax,imm32', TAsmBuilder.New.Add(RAX, $12345678),
    [$48, $05, $78, $56, $34, $12]);

  Check('adc rax,rdx', TAsmBuilder.New.Adc(RAX, RDX),
    [$48, $13, $C2]);
  Check('sbb r9,r10', TAsmBuilder.New.Sbb(R9, R10),
    [$4D, $1B, $CA]);
  Check('mul r8', TAsmBuilder.New.Mul(R8),
    [$49, $F7, $E0]);

  Check('xchg rax,rcx', TAsmBuilder.New.Xchg(RAX, RCX),
    [$48, $91]);
  Check('shl rax,1', TAsmBuilder.New.Shl_(RAX, 1),
    [$48, $D1, $E0]);
  Check('shl rax,2', TAsmBuilder.New.Shl_(RAX, 2),
    [$48, $C1, $E0, $02]);

  Check('setz r8b', TAsmBuilder.New.Setcc(cond_JE, R8B),
    [$41, $0F, $94, $C0]);
  Check('push r8', TAsmBuilder.New.Push(R8),
    [$41, $50]);
  Check('pop r8', TAsmBuilder.New.Pop(R8),
    [$41, $58]);

  Check('movzx rax,word [rcx]',
    TAsmBuilder.New.Movzx(RAX, WordPtr(ridRCX)),
    [$48, $0F, $B7, $01]);
  Check('lea ax,[rcx]',
    TAsmBuilder.New.Lea(AX, TMemory.Create(ridRCX)),
    [$66, $8D, $01]);

  Check('lfence', TAsmBuilder.New.Lfence,
    [$0F, $AE, $E8]);
  Check('rdtscp', TAsmBuilder.New.Rdtscp,
    [$0F, $01, $F9]);
  Check('ret 16', TAsmBuilder.New.Ret(16),
    [$C2, $10, $00]);

  B := TAsmBuilder.New;
  try
    L := B.NewLabel;
    B.J(cond_JE, L).Nop.Bind(L);
    AssertBytes('jz rel32 fixup', B.Build,
      [$0F, $84, $01, $00, $00, $00, $90]);
  finally
    B.Free;
  end;
end;

procedure TestFailClosedValidation;
var
  B: TAsmBuilder;
  Raised: Boolean;
begin
  // Source DB has no MOVZX r16,r/m16 form. Failure must happen before emission.
  B := TAsmBuilder.New;
  try
    Raised := False;
    try
      B.Movzx(AX, WordPtr(ridRCX));
    except
      on E: EArgumentException do Raised := True;
    end;
    if not Raised then
      raise Exception.Create('movzx ax,word [rcx] unexpectedly accepted');
    if B.CodeSize <> 0 then
      raise Exception.Create('movzx validation emitted partial bytes');
  finally
    B.Free;
  end;

  // Immediate-only memory operations must not infer qword from an unsized mem.
  B := TAsmBuilder.New;
  try
    Raised := False;
    try
      B.Add(TMemory.Create(ridRCX), 1);
    except
      on E: EArgumentException do Raised := True;
    end;
    if not Raised then
      raise Exception.Create('add [rcx],1 unexpectedly inferred a memory size');
    if B.CodeSize <> 0 then
      raise Exception.Create('unsized add validation emitted partial bytes');
  finally
    B.Free;
  end;
end;

begin
  try
    TInstructionDb.ValidateGeneratedDb;
    TestCanonicalEncodings;
    TestFailClosedValidation;
    Writeln('StaticDbRegression: OK');
  except
    on E: Exception do
    begin
      Writeln(E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
