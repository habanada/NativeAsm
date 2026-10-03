program NativeAsmBmiAudit;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  NativeAsm.Types,
  NativeAsm.Builder,
  NativeAsm.Extensions,
  NativeAsm.Simd.Types,
  NativeAsm.Avx.Types,
  NativeAsm.Bmi.Db,
  NativeAsm.Bmi.Encoder,
  NativeAsm.Bmi.Cpu,
  NativeAsm.Bmi;

var
  GPass, GFail, GSkip: Integer;

function Op(const R: TRegister): TOperand; overload;
begin
  Result := R;
end;

function Op(const M: TMemory): TOperand; overload;
begin
  Result := M;
end;

function Op(I: Integer): TOperand; overload;
begin
  Result := I;
end;

function BytesText(const Data: TBytes): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(Data) do
  begin
    if I > 0 then Result := Result + ' ';
    Result := Result + IntToHex(Data[I], 2);
  end;
end;

function ExpectedText(const Data: array of Byte): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(Data) do
  begin
    if I > 0 then Result := Result + ' ';
    Result := Result + IntToHex(Data[I], 2);
  end;
end;

function SameBytes(const Actual: TBytes; const Expected: array of Byte): Boolean;
var
  I: Integer;
begin
  Result := Length(Actual) = Length(Expected);
  if not Result then Exit;
  for I := 0 to High(Expected) do
    if Actual[I] <> Expected[I] then Exit(False);
end;

procedure CheckEnc(const Desc, Mnemonic: string; const Operands: array of TOperand; const Expected: array of Byte);
var
  B: TAsmBuilder;
  FormIndex: Integer;
  Actual: TBytes;
begin
  try
    FormIndex := TBmiInstructionEncoder.SelectForm(Mnemonic, Operands);
    B := TAsmBuilder.New;
    try
      TBmiInstructionEncoder.Encode(B, Mnemonic, Operands);
      Actual := B.Build;
    finally
      B.Free;
    end;
    if not SameBytes(Actual, Expected) then
    begin
      Inc(GFail);
      Writeln('FAIL ', Desc);
      Writeln('  FORM     ', FormIndex, ' ', TBmiInstructionDb.SourceSignature(FormIndex));
      Writeln('  SOURCE   ', TBmiInstructionDb.SourceEncoding(FormIndex));
      Writeln('  ACTUAL   ', BytesText(Actual));
      Writeln('  EXPECTED ', ExpectedText(Expected));
      Exit;
    end;
    Inc(GPass);
    Writeln('PASS ', Desc);
    Writeln('  FORM     ', FormIndex, ' ', TBmiInstructionDb.SourceSignature(FormIndex));
    Writeln('  SOURCE   ', TBmiInstructionDb.SourceEncoding(FormIndex));
    Writeln('  BYTES    ', BytesText(Actual));
  except
    on E: Exception do
    begin
      Inc(GFail);
      Writeln('FAIL ', Desc, ': ', E.ClassName, ': ', E.Message);
    end;
  end;
end;

procedure CheckReject(const Desc, Mnemonic: string; const Operands: array of TOperand);
begin
  try
    TBmiInstructionEncoder.SelectForm(Mnemonic, Operands);
    Inc(GFail);
    Writeln('FAIL ', Desc, ': unexpectedly accepted');
  except
    on E: EBmiError do
    begin
      Inc(GPass);
      Writeln('PASS ', Desc, ': rejected: ', E.Message);
    end;
    on E: Exception do
    begin
      Inc(GFail);
      Writeln('FAIL ', Desc, ': wrong exception ', E.ClassName, ': ', E.Message);
    end;
  end;
end;

procedure CheckHelperComposition;
var
  B: TAsmBuilder;
  Actual: TBytes;
begin
  B := TAsmBuilder.New;
  try
    B.Tzcnt(RAX, RCX).Vaddps(YMM0, YMM1, YMM2).Andn(RAX, RAX, RDX).Ret;
    Actual := B.Build;
    if SameBytes(Actual, [$F3, $48, $0F, $BC, $C1, $C5, $F4, $58, $C2, $C4, $E2, $F8, $F2, $C2, $C3]) then
    begin
      Inc(GPass);
      Writeln('PASS helper composition SIMD -> AVX -> BMI');
      Writeln('  BYTES    ', BytesText(Actual));
    end
    else
    begin
      Inc(GFail);
      Writeln('FAIL helper composition SIMD -> AVX -> BMI');
      Writeln('  ACTUAL   ', BytesText(Actual));
      Writeln('  EXPECTED F3 48 0F BC C1 C5 F4 58 C2 C4 E2 F8 F2 C2 C3');
    end;
  finally
    B.Free;
  end;
end;

function PdepRef(Src, Mask: UInt64): UInt64;
var
  MaskBit, SrcBit: UInt64;
begin
  Result := 0;
  MaskBit := 1;
  SrcBit := 1;
  while MaskBit <> 0 do
  begin
    if (Mask and MaskBit) <> 0 then
    begin
      if (Src and SrcBit) <> 0 then Result := Result or MaskBit;
      SrcBit := SrcBit shl 1;
    end;
    MaskBit := MaskBit shl 1;
  end;
end;

function YesNo(Value: Boolean): string;
begin
  if Value then Result := 'YES' else Result := 'NO';
end;

procedure CheckRuntimeBmi1;
var
  Status: TBmiCpuStatus;
  B: TAsmBuilder;
  Exe: TExecutableCode;
  Actual: TBytes;
  A, C, R, Expected: UInt64;
begin
  Status := TBmiCpuFeatures.Query;
  Writeln('BMI1 runtime capability');
  Writeln('  CPU BMI1 ', YesNo(Status.CpuBmi1));
  if not Status.CpuBmi1 then
  begin
    Inc(GSkip);
    Writeln('SKIP BMI1 runtime andn: BMI1 execution is not available');
    Exit;
  end;
  A := $0123456789ABCDEF;
  C := $0F0F0F0F0F0F0F0F;
  Expected := (not A) and C;
  B := TAsmBuilder.New;
  try
    B.Andn(RAX, RCX, RDX).Ret;
    Actual := B.Build;
    if not SameBytes(Actual, [$C4, $E2, $F0, $F2, $C2, $C3]) then
    begin
      Inc(GFail);
      Writeln('FAIL BMI1 runtime kernel encoding');
      Writeln('  ACTUAL   ', BytesText(Actual));
      Writeln('  EXPECTED C4 E2 F0 F2 C2 C3');
      Exit;
    end;
    Exe := TExecutableCode.Create(Actual);
    try
      R := Exe.Run(A, C);
    finally
      Exe.Free;
    end;
  finally
    B.Free;
  end;
  if R = Expected then
  begin
    Inc(GPass);
    Writeln('PASS BMI1 runtime andn r64');
  end
  else
  begin
    Inc(GFail);
    Writeln('FAIL BMI1 runtime andn r64: actual=', IntToHex(R, 16), ' expected=', IntToHex(Expected, 16));
  end;
end;

procedure CheckRuntimeBmi2;
var
  Status: TBmiCpuStatus;
  B: TAsmBuilder;
  Exe: TExecutableCode;
  Actual: TBytes;
  Src, Mask, R, Expected: UInt64;
begin
  Status := TBmiCpuFeatures.Query;
  Writeln('BMI2 runtime capability');
  Writeln('  CPU BMI2 ', YesNo(Status.CpuBmi2));
  if not Status.CpuBmi2 then
  begin
    Inc(GSkip);
    Writeln('SKIP BMI2 runtime pdep: BMI2 execution is not available');
    Exit;
  end;
  Src := $000000000000000B;
  Mask := $0000000000000055;
  Expected := PdepRef(Src, Mask);
  B := TAsmBuilder.New;
  try
    B.Pdep(RAX, RCX, RDX).Ret;
    Actual := B.Build;
    if not SameBytes(Actual, [$C4, $E2, $F3, $F5, $C2, $C3]) then
    begin
      Inc(GFail);
      Writeln('FAIL BMI2 runtime kernel encoding');
      Writeln('  ACTUAL   ', BytesText(Actual));
      Writeln('  EXPECTED C4 E2 F3 F5 C2 C3');
      Exit;
    end;
    Exe := TExecutableCode.Create(Actual);
    try
      R := Exe.Run(Src, Mask);
    finally
      Exe.Free;
    end;
  finally
    B.Free;
  end;
  if R = Expected then
  begin
    Inc(GPass);
    Writeln('PASS BMI2 runtime pdep r64');
  end
  else
  begin
    Inc(GFail);
    Writeln('FAIL BMI2 runtime pdep r64: actual=', IntToHex(R, 16), ' expected=', IntToHex(Expected, 16));
  end;
end;

procedure Run;
begin
  Writeln('NativeASM BMI1/BMI2 audit');
  Writeln('DB SHA-256: ', TBmiInstructionDb.SourceSha256);
  Writeln('VEX Forms: ', TBmiInstructionDb.FormCount, '  Mnemonics: ', TBmiInstructionDb.MnemonicCount);
  Writeln('Existing BMI1 TZCNT remains in NativeAsm.BitManip');
  Writeln;

  CheckEnc('andn rax,rcx,rdx', 'andn', [Op(RAX), Op(RCX), Op(RDX)], [$C4, $E2, $F0, $F2, $C2]);
  CheckEnc('andn r8d,r9d,[r12+32]', 'andn', [Op(R8D), Op(R9D), Op(DWordPtr(ridR12, 32))], [$C4, $42, $30, $F2, $44, $24, $20]);
  CheckEnc('bextr rax,[r12+r13*4+64],rdx', 'bextr', [Op(RAX), Op(TMemory.CreateSib(ridR12, ridR13, s4, 64, sz64)), Op(RDX)], [$C4, $82, $E8, $F7, $44, $AC, $40]);
  CheckEnc('blsi r8,r9', 'blsi', [Op(R8), Op(R9)], [$C4, $C2, $B8, $F3, $D9]);
  CheckEnc('blsmsk eax,[rcx+16]', 'blsmsk', [Op(EAX), Op(DWordPtr(ridRCX, 16))], [$C4, $E2, $78, $F3, $51, $10]);
  CheckEnc('blsr r10d,r11d', 'blsr', [Op(R10D), Op(R11D)], [$C4, $C2, $28, $F3, $CB]);
  CheckEnc('bzhi rax,rcx,rdx', 'bzhi', [Op(RAX), Op(RCX), Op(RDX)], [$C4, $E2, $E8, $F5, $C1]);
  CheckEnc('mulx rax,rcx,r8', 'mulx', [Op(RAX), Op(RCX), Op(R8)], [$C4, $C2, $F3, $F6, $C0]);
  CheckEnc('pdep rax,rcx,rdx', 'pdep', [Op(RAX), Op(RCX), Op(RDX)], [$C4, $E2, $F3, $F5, $C2]);
  CheckEnc('pext r8d,r9d,[r12+32]', 'pext', [Op(R8D), Op(R9D), Op(DWordPtr(ridR12, 32))], [$C4, $42, $32, $F5, $44, $24, $20]);
  CheckEnc('rorx rax,[r13+64],07', 'rorx', [Op(RAX), Op(QWordPtr(ridR13, 64)), Op($07)], [$C4, $C3, $FB, $F0, $45, $40, $07]);
  CheckEnc('rorx r8d,r9d,1F', 'rorx', [Op(R8D), Op(R9D), Op($1F)], [$C4, $43, $7B, $F0, $C1, $1F]);
  CheckEnc('sarx rax,rcx,rdx', 'sarx', [Op(RAX), Op(RCX), Op(RDX)], [$C4, $E2, $EA, $F7, $C1]);
  CheckEnc('shlx r8d,r9d,r10d', 'shlx', [Op(R8D), Op(R9D), Op(R10D)], [$C4, $42, $29, $F7, $C1]);
  CheckEnc('shrx r11,r12,r13', 'shrx', [Op(R11), Op(R12), Op(R13)], [$C4, $42, $93, $F7, $DC]);

  CheckReject('reject BMI mixed register widths', 'andn', [Op(RAX), Op(ECX), Op(RDX)]);
  CheckReject('reject BMI wrong memory width', 'andn', [Op(RAX), Op(RCX), Op(DWordPtr(ridRDX))]);
  CheckReject('reject BMI 16-bit register', 'blsi', [Op(AX), Op(CX)]);
  CheckReject('reject BMI2 imm8 below range', 'rorx', [Op(RAX), Op(RCX), Op(-129)]);
  CheckReject('reject BMI2 imm8 above range', 'rorx', [Op(RAX), Op(RCX), Op(256)]);
  CheckReject('reject MULX mixed widths', 'mulx', [Op(RAX), Op(ECX), Op(R8)]);

  CheckHelperComposition;
  Writeln;
  CheckRuntimeBmi1;
  Writeln;
  CheckRuntimeBmi2;

  Writeln;
  Writeln('PASS=', GPass, ' FAIL=', GFail, ' SKIP=', GSkip);
  if GFail <> 0 then ExitCode := 1;
end;

begin
  try
    Run;
  except
    on E: Exception do
    begin
      Writeln(E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
