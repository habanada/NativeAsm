program NativeAsmAvxAudit;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  NativeAsm.Types,
  NativeAsm.Builder,
  NativeAsm.Extensions,
  NativeAsm.Simd.Types,
  NativeAsm.Avx.Types,
  NativeAsm.Avx.Db,
  NativeAsm.Avx.Encoder,
  NativeAsm.Avx.Cpu,
  NativeAsm.Avx;

var
  GPass, GFail, GSkip: Integer;

function Op(const R: TSimdRegister): TAvxOperand; overload;
begin
  Result := R;
end;

function Op(const R: TAvxYmmRegister): TAvxOperand; overload;
begin
  Result := R;
end;

function Op(const R: TRegister): TAvxOperand; overload;
begin
  Result := R;
end;

function Op(const M: TAvxMemory): TAvxOperand; overload;
begin
  Result := M;
end;

function Op(const M: TMemory): TAvxOperand; overload;
begin
  Result := M;
end;

function Op(I: Integer): TAvxOperand; overload;
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

procedure CheckEnc(const Desc, Mnemonic: string; const Operands: array of TAvxOperand; const Expected: array of Byte);
var
  B: TAsmBuilder;
  FormIndex: Integer;
  Actual: TBytes;
begin
  try
    FormIndex := TAvxInstructionEncoder.SelectForm(Mnemonic, Operands);
    B := TAsmBuilder.New;
    try
      TAvxInstructionEncoder.Encode(B, Mnemonic, Operands);
      Actual := B.Build;
    finally
      B.Free;
    end;
    if not SameBytes(Actual, Expected) then
    begin
      Inc(GFail);
      Writeln('FAIL ', Desc);
      Writeln('  FORM     ', FormIndex, ' ', TAvxInstructionDb.SourceSignature(FormIndex));
      Writeln('  SOURCE   ', TAvxInstructionDb.SourceEncoding(FormIndex));
      Writeln('  ACTUAL   ', BytesText(Actual));
      Writeln('  EXPECTED ', ExpectedText(Expected));
      Exit;
    end;
    Inc(GPass);
    Writeln('PASS ', Desc);
    Writeln('  FORM     ', FormIndex, ' ', TAvxInstructionDb.SourceSignature(FormIndex));
    Writeln('  SOURCE   ', TAvxInstructionDb.SourceEncoding(FormIndex));
    Writeln('  BYTES    ', BytesText(Actual));
  except
    on E: Exception do
    begin
      Inc(GFail);
      Writeln('FAIL ', Desc, ': ', E.ClassName, ': ', E.Message);
    end;
  end;
end;

procedure CheckReject(const Desc, Mnemonic: string; const Operands: array of TAvxOperand);
begin
  try
    TAvxInstructionEncoder.SelectForm(Mnemonic, Operands);
    Inc(GFail);
    Writeln('FAIL ', Desc, ': unexpectedly accepted');
  except
    on E: EAvxError do
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

procedure CheckScaleEncoding;
begin
  if (Ord(s1) = 0) and (Ord(s2) = 1) and (Ord(s4) = 2) and (Ord(s8) = 3) then
  begin
    Inc(GPass);
    Writeln('PASS TScale SIB encoding values');
  end
  else
  begin
    Inc(GFail);
    Writeln('FAIL TScale SIB encoding values');
  end;
end;

procedure CheckPublicApi;
var
  B: TAsmBuilder;
  Actual: TBytes;
begin
  B := TAsmBuilder.New;
  try
    B.Mov(RAX, RCX).Vaddps(YMM0, YMM1, YMM2).Vzeroupper.Ret;
    Actual := B.Build;
    if SameBytes(Actual, [$48, $8B, $C1, $C5, $F4, $58, $C2, $C5, $F8, $77, $C3]) then
    begin
      Inc(GPass);
      Writeln('PASS mixed legacy/VEX public API');
      Writeln('  BYTES    ', BytesText(Actual));
    end
    else
    begin
      Inc(GFail);
      Writeln('FAIL mixed legacy/VEX public API');
      Writeln('  ACTUAL   ', BytesText(Actual));
      Writeln('  EXPECTED 48 8B C1 C5 F4 58 C2 C5 F8 77 C3');
    end;
  finally
    B.Free;
  end;
end;


function YesNo(Value: Boolean): string;
begin
  if Value then Result := 'YES' else Result := 'NO';
end;

procedure CheckRuntimeAvx;
type
  TSingle8 = array[0..7] of Single;
var
  Status: TAvxCpuStatus;
  A, C, OutV: TSingle8;
  B: TAsmBuilder;
  Exe: TExecutableCode;
  I: Integer;
  Ok: Boolean;
  Actual: TBytes;
begin
  Status := TAvxCpuFeatures.Query;
  Writeln('AVX runtime capability');
  Writeln('  CPU XSAVE ', YesNo(Status.CpuXsave));
  Writeln('  OSXSAVE   ', YesNo(Status.OsXsave));
  Writeln('  CPU AVX   ', YesNo(Status.CpuAvx));
  Writeln('  XCR0      ', IntToHex(Status.Xcr0, 16));
  Writeln('  XMM state ', YesNo(Status.XmmState));
  Writeln('  YMM state ', YesNo(Status.YmmState));
  Writeln('  AVX usable ', YesNo(Status.AvxUsable));
  if not Status.AvxUsable then
  begin
    Inc(GSkip);
    Writeln('SKIP AVX runtime vaddps: AVX execution is not available');
    Exit;
  end;

  for I := 0 to 7 do
  begin
    A[I] := I + 1;
    C[I] := (I + 1) * 10;
    OutV[I] := 0;
  end;

  B := TAsmBuilder.New;
  try
    B.Vmovdqu(YMM0, YmmWordPtr(ridRCX)).Vaddps(YMM0, YMM0, YmmWordPtr(ridRDX)).Vmovdqu(YmmWordPtr(ridR8), YMM0).Vzeroupper.Ret;
    Actual := B.Build;
    if not SameBytes(Actual, [$C5, $FE, $6F, $01, $C5, $FC, $58, $02, $C4, $C1, $7E, $7F, $00, $C5, $F8, $77, $C3]) then
    begin
      Inc(GFail);
      Writeln('FAIL AVX runtime kernel encoding');
      Writeln('  ACTUAL   ', BytesText(Actual));
      Writeln('  EXPECTED C5 FE 6F 01 C5 FC 58 02 C4 C1 7E 7F 00 C5 F8 77 C3');
      Exit;
    end;
    Exe := TExecutableCode.Create(Actual);
    try
      Exe.Run(UInt64(NativeUInt(@A[0])), UInt64(NativeUInt(@C[0])), UInt64(NativeUInt(@OutV[0])));
    finally
      Exe.Free;
    end;
  finally
    B.Free;
  end;

  Ok := True;
  for I := 0 to 7 do
    if OutV[I] <> A[I] + C[I] then
    begin
      Ok := False;
      Break;
    end;

  if Ok then
  begin
    Inc(GPass);
    Writeln('PASS AVX runtime vaddps ymm load/add/store');
  end
  else
  begin
    Inc(GFail);
    Writeln('FAIL AVX runtime vaddps ymm load/add/store at lane ', I, ': actual=', OutV[I]:0:6, ' expected=', (A[I] + C[I]):0:6);
  end;
end;

procedure CheckRuntimeAvx2;
type
  TInt8 = array[0..7] of Integer;
var
  Status: TAvxCpuStatus;
  A, C, OutV: TInt8;
  B: TAsmBuilder;
  Exe: TExecutableCode;
  I: Integer;
  Ok: Boolean;
  Actual: TBytes;
begin
  Status := TAvxCpuFeatures.Query;
  Writeln('AVX2 runtime capability');
  Writeln('  CPU AVX2  ', YesNo(Status.CpuAvx2));
  Writeln('  AVX2 usable ', YesNo(Status.Avx2Usable));
  if not Status.Avx2Usable then
  begin
    Inc(GSkip);
    Writeln('SKIP AVX2 runtime vpaddd: AVX2 execution is not available');
    Exit;
  end;

  for I := 0 to 7 do
  begin
    A[I] := I + 1;
    C[I] := (I + 1) * 100;
    OutV[I] := 0;
  end;

  B := TAsmBuilder.New;
  try
    B.Vmovdqu(YMM0, YmmWordPtr(ridRCX)).Vpaddd(YMM0, YMM0, YmmWordPtr(ridRDX)).Vmovdqu(YmmWordPtr(ridR8), YMM0).Vzeroupper.Ret;
    Actual := B.Build;
    if not SameBytes(Actual, [$C5, $FE, $6F, $01, $C5, $FD, $FE, $02, $C4, $C1, $7E, $7F, $00, $C5, $F8, $77, $C3]) then
    begin
      Inc(GFail);
      Writeln('FAIL AVX2 runtime kernel encoding');
      Writeln('  ACTUAL   ', BytesText(Actual));
      Writeln('  EXPECTED C5 FE 6F 01 C5 FD FE 02 C4 C1 7E 7F 00 C5 F8 77 C3');
      Exit;
    end;
    Exe := TExecutableCode.Create(Actual);
    try
      Exe.Run(UInt64(NativeUInt(@A[0])), UInt64(NativeUInt(@C[0])), UInt64(NativeUInt(@OutV[0])));
    finally
      Exe.Free;
    end;
  finally
    B.Free;
  end;

  Ok := True;
  for I := 0 to 7 do
    if OutV[I] <> A[I] + C[I] then
    begin
      Ok := False;
      Break;
    end;

  if Ok then
  begin
    Inc(GPass);
    Writeln('PASS AVX2 runtime vpaddd ymm load/add/store');
  end
  else
  begin
    Inc(GFail);
    Writeln('FAIL AVX2 runtime vpaddd ymm load/add/store at lane ', I, ': actual=', OutV[I], ' expected=', A[I] + C[I]);
  end;
end;


procedure CheckRuntimeAvx2Shift;
type
  TInt8 = array[0..7] of Integer;
var
  Status: TAvxCpuStatus;
  A, OutV: TInt8;
  B: TAsmBuilder;
  Exe: TExecutableCode;
  I: Integer;
  Ok: Boolean;
  Actual: TBytes;
begin
  Status := TAvxCpuFeatures.Query;
  if not Status.Avx2Usable then
  begin
    Inc(GSkip);
    Writeln('SKIP AVX2 runtime vpslld: AVX2 execution is not available');
    Exit;
  end;

  for I := 0 to 7 do
  begin
    A[I] := I + 1;
    OutV[I] := 0;
  end;

  B := TAsmBuilder.New;
  try
    B.Vmovdqu(YMM0, YmmWordPtr(ridRCX)).Vpslld(YMM0, YMM0, 3).Vmovdqu(YmmWordPtr(ridRDX), YMM0).Vzeroupper.Ret;
    Actual := B.Build;
    if not SameBytes(Actual, [$C5, $FE, $6F, $01, $C5, $FD, $72, $F0, $03, $C5, $FE, $7F, $02, $C5, $F8, $77, $C3]) then
    begin
      Inc(GFail);
      Writeln('FAIL AVX2 runtime vpslld kernel encoding');
      Writeln('  ACTUAL   ', BytesText(Actual));
      Writeln('  EXPECTED C5 FE 6F 01 C5 FD 72 F0 03 C5 FE 7F 02 C5 F8 77 C3');
      Exit;
    end;
    Exe := TExecutableCode.Create(Actual);
    try
      Exe.Run(UInt64(NativeUInt(@A[0])), UInt64(NativeUInt(@OutV[0])));
    finally
      Exe.Free;
    end;
  finally
    B.Free;
  end;

  Ok := True;
  for I := 0 to 7 do
    if OutV[I] <> A[I] shl 3 then
    begin
      Ok := False;
      Break;
    end;

  if Ok then
  begin
    Inc(GPass);
    Writeln('PASS AVX2 runtime vpslld ymm immediate');
  end
  else
  begin
    Inc(GFail);
    Writeln('FAIL AVX2 runtime vpslld ymm immediate at lane ', I, ': actual=', OutV[I], ' expected=', A[I] shl 3);
  end;
end;

procedure CheckRuntimeFma;
type
  TSingle8 = array[0..7] of Single;
var
  Status: TAvxCpuStatus;
  A, C, D, OutV: TSingle8;
  B: TAsmBuilder;
  Exe: TExecutableCode;
  I: Integer;
  Ok: Boolean;
  Actual: TBytes;
begin
  Status := TAvxCpuFeatures.Query;
  Writeln('FMA runtime capability');
  Writeln('  CPU FMA   ', YesNo(Status.CpuFma));
  Writeln('  FMA usable ', YesNo(Status.FmaUsable));
  if not Status.FmaUsable then
  begin
    Inc(GSkip);
    Writeln('SKIP FMA runtime vfmadd231ps: FMA execution is not available');
    Exit;
  end;

  for I := 0 to 7 do
  begin
    A[I] := I + 1;
    C[I] := (I + 1) * 2;
    D[I] := (I + 1) * 10;
    OutV[I] := 0;
  end;

  B := TAsmBuilder.New;
  try
    B.Vmovdqu(YMM0, YmmWordPtr(ridRCX)).Vmovdqu(YMM1, YmmWordPtr(ridRDX)).Vmovdqu(YMM2, YmmWordPtr(ridR8)).Vfmadd231ps(YMM2, YMM0, YMM1).Vmovdqu(YmmWordPtr(ridR9), YMM2).Vzeroupper.Ret;
    Actual := B.Build;
    if not SameBytes(Actual, [$C5, $FE, $6F, $01, $C5, $FE, $6F, $0A, $C4, $C1, $7E, $6F, $10, $C4, $E2, $7D, $B8, $D1, $C4, $C1, $7E, $7F, $11, $C5, $F8, $77, $C3]) then
    begin
      Inc(GFail);
      Writeln('FAIL FMA runtime kernel encoding');
      Writeln('  ACTUAL   ', BytesText(Actual));
      Writeln('  EXPECTED C5 FE 6F 01 C5 FE 6F 0A C4 C1 7E 6F 10 C4 E2 7D B8 D1 C4 C1 7E 7F 11 C5 F8 77 C3');
      Exit;
    end;
    Exe := TExecutableCode.Create(Actual);
    try
      Exe.Run(UInt64(NativeUInt(@A[0])), UInt64(NativeUInt(@C[0])), UInt64(NativeUInt(@D[0])), UInt64(NativeUInt(@OutV[0])));
    finally
      Exe.Free;
    end;
  finally
    B.Free;
  end;

  Ok := True;
  for I := 0 to 7 do
    if OutV[I] <> D[I] + A[I] * C[I] then
    begin
      Ok := False;
      Break;
    end;

  if Ok then
  begin
    Inc(GPass);
    Writeln('PASS FMA runtime vfmadd231ps ymm multiply/add/store');
  end
  else
  begin
    Inc(GFail);
    Writeln('FAIL FMA runtime vfmadd231ps at lane ', I, ': actual=', OutV[I]:0:6, ' expected=', (D[I] + A[I] * C[I]):0:6);
  end;
end;

procedure CheckRuntimeFmaExtended;
type
  TSingle8 = array[0..7] of Single;
var
  Status: TAvxCpuStatus;
  A, C, D, OutV: TSingle8;
  B: TAsmBuilder;
  Exe: TExecutableCode;
  I: Integer;
  Ok: Boolean;
  Actual: TBytes;

  procedure RunKernel(const Name: string; const ExpectedBytes: array of Byte; Kind: Integer);
  var
    J: Integer;
    FailLane: Integer;
  begin
    for J := 0 to 7 do OutV[J] := 0;
    B := TAsmBuilder.New;
    try
      B.Vmovdqu(YMM0, YmmWordPtr(ridRCX)).Vmovdqu(YMM1, YmmWordPtr(ridRDX)).Vmovdqu(YMM2, YmmWordPtr(ridR8));
      case Kind of
        0: B.Vfmsub231ps(YMM2, YMM0, YMM1);
        1: B.Vfnmadd231ps(YMM2, YMM0, YMM1);
        2: B.Vfnmsub231ps(YMM2, YMM0, YMM1);
      end;
      B.Vmovdqu(YmmWordPtr(ridR9), YMM2).Vzeroupper.Ret;
      Actual := B.Build;
      if not SameBytes(Actual, ExpectedBytes) then
      begin
        Inc(GFail);
        Writeln('FAIL FMA runtime ', Name, ' kernel encoding');
        Writeln('  ACTUAL   ', BytesText(Actual));
        Writeln('  EXPECTED ', ExpectedText(ExpectedBytes));
        Exit;
      end;
      Exe := TExecutableCode.Create(Actual);
      try
        Exe.Run(UInt64(NativeUInt(@A[0])), UInt64(NativeUInt(@C[0])), UInt64(NativeUInt(@D[0])), UInt64(NativeUInt(@OutV[0])));
      finally
        Exe.Free;
      end;
    finally
      B.Free;
    end;

    Ok := True;
    FailLane := -1;
    for J := 0 to 7 do
    begin
      case Kind of
        0: Ok := OutV[J] = A[J] * C[J] - D[J];
        1: Ok := OutV[J] = D[J] - A[J] * C[J];
        2: Ok := OutV[J] = -A[J] * C[J] - D[J];
      end;
      if not Ok then
      begin
        FailLane := J;
        Break;
      end;
    end;

    if Ok then
    begin
      Inc(GPass);
      Writeln('PASS FMA runtime ', Name, ' ymm');
    end
    else
    begin
      Inc(GFail);
      Writeln('FAIL FMA runtime ', Name, ' at lane ', FailLane, ': actual=', OutV[FailLane]:0:6);
    end;
  end;

begin
  Status := TAvxCpuFeatures.Query;
  if not Status.FmaUsable then
  begin
    Inc(GSkip, 3);
    Writeln('SKIP FMA runtime vfmsub231ps: FMA execution is not available');
    Writeln('SKIP FMA runtime vfnmadd231ps: FMA execution is not available');
    Writeln('SKIP FMA runtime vfnmsub231ps: FMA execution is not available');
    Exit;
  end;

  for I := 0 to 7 do
  begin
    A[I] := I + 1;
    C[I] := (I + 1) * 2;
    D[I] := (I + 1) * 10;
    OutV[I] := 0;
  end;

  RunKernel('vfmsub231ps', [$C5, $FE, $6F, $01, $C5, $FE, $6F, $0A, $C4, $C1, $7E, $6F, $10, $C4, $E2, $7D, $BA, $D1, $C4, $C1, $7E, $7F, $11, $C5, $F8, $77, $C3], 0);
  RunKernel('vfnmadd231ps', [$C5, $FE, $6F, $01, $C5, $FE, $6F, $0A, $C4, $C1, $7E, $6F, $10, $C4, $E2, $7D, $BC, $D1, $C4, $C1, $7E, $7F, $11, $C5, $F8, $77, $C3], 1);
  RunKernel('vfnmsub231ps', [$C5, $FE, $6F, $01, $C5, $FE, $6F, $0A, $C4, $C1, $7E, $6F, $10, $C4, $E2, $7D, $BE, $D1, $C4, $C1, $7E, $7F, $11, $C5, $F8, $77, $C3], 2);
end;

procedure CheckExpandedEncodings;
begin
  CheckEnc('vaddsubps ymm0,ymm1,ymm2', 'vaddsubps', [Op(YMM0), Op(YMM1), Op(YMM2)], [$C5, $F7, $D0, $C2]);
  CheckEnc('vandnpd xmm3,xmm4,xmm5', 'vandnpd', [Op(XMM3), Op(XMM4), Op(XMM5)], [$C5, $D9, $55, $DD]);
  CheckEnc('vblendps ymm6,ymm7,ymm8,A5', 'vblendps', [Op(YMM6), Op(YMM7), Op(YMM8), Op($A5)], [$C4, $C3, $45, $0C, $F0, $A5]);
  CheckEnc('vcmppd xmm9,xmm10,xmm11,1E', 'vcmppd', [Op(XMM9), Op(XMM10), Op(XMM11), Op($1E)], [$C4, $41, $29, $C2, $CB, $1E]);
  CheckEnc('vdpps ymm12,ymm13,ymm14,F1', 'vdpps', [Op(YMM12), Op(YMM13), Op(YMM14), Op($F1)], [$C4, $43, $15, $40, $E6, $F1]);
  CheckEnc('vhaddpd ymm0,ymm1,ymm2', 'vhaddpd', [Op(YMM0), Op(YMM1), Op(YMM2)], [$C5, $F5, $7C, $C2]);
  CheckEnc('vhsubps xmm3,xmm4,[r12+32]', 'vhsubps', [Op(XMM3), Op(XMM4), Op(XmmWordPtr(ridR12, 32))], [$C4, $C1, $5B, $7D, $5C, $24, $20]);
  CheckEnc('vlddqu ymm5,[r13+64]', 'vlddqu', [Op(YMM5), Op(YmmWordPtr(ridR13, 64))], [$C4, $C1, $7F, $F0, $6D, $40]);
  CheckEnc('vmovaps ymm8,[r12+r13*4+64]', 'vmovaps', [Op(YMM8), Op(YmmWordPtrSib(ridR12, ridR13, s4, 64))], [$C4, $01, $7C, $28, $44, $AC, $40]);
  CheckEnc('vmovapd [r14+32],ymm9', 'vmovapd', [Op(YmmWordPtr(ridR14, 32)), Op(YMM9)], [$C4, $41, $7D, $29, $4E, $20]);
  CheckEnc('vmovntdq [r15+64],ymm10', 'vmovntdq', [Op(YmmWordPtr(ridR15, 64)), Op(YMM10)], [$C4, $41, $7D, $E7, $57, $40]);
  CheckEnc('vmovshdup ymm11,ymm12', 'vmovshdup', [Op(YMM11), Op(YMM12)], [$C4, $41, $7E, $16, $DC]);
  CheckEnc('vpacksswb ymm0,ymm1,ymm2', 'vpacksswb', [Op(YMM0), Op(YMM1), Op(YMM2)], [$C5, $F5, $63, $C2]);
  CheckEnc('vpaddusb ymm3,ymm4,ymm5', 'vpaddusb', [Op(YMM3), Op(YMM4), Op(YMM5)], [$C5, $DD, $DC, $DD]);
  CheckEnc('vpavgw ymm6,ymm7,[r8+32]', 'vpavgw', [Op(YMM6), Op(YMM7), Op(YmmWordPtr(ridR8, 32))], [$C4, $C1, $45, $E3, $70, $20]);
  CheckEnc('vpmaxud ymm8,ymm9,ymm10', 'vpmaxud', [Op(YMM8), Op(YMM9), Op(YMM10)], [$C4, $42, $35, $3F, $C2]);
  CheckEnc('vpminsb xmm11,xmm12,xmm13', 'vpminsb', [Op(XMM11), Op(XMM12), Op(XMM13)], [$C4, $42, $19, $38, $DD]);
  CheckEnc('vpmaddubsw ymm14,ymm15,[r12+64]', 'vpmaddubsw', [Op(YMM14), Op(YMM15), Op(YmmWordPtr(ridR12, 64))], [$C4, $42, $05, $04, $74, $24, $40]);
  CheckEnc('vpmuludq ymm0,ymm1,ymm2', 'vpmuludq', [Op(YMM0), Op(YMM1), Op(YMM2)], [$C5, $F5, $F4, $C2]);
  CheckEnc('vpsadbw ymm3,ymm4,ymm5', 'vpsadbw', [Op(YMM3), Op(YMM4), Op(YMM5)], [$C5, $DD, $F6, $DD]);
  CheckEnc('vpshufhw ymm6,ymm7,1B', 'vpshufhw', [Op(YMM6), Op(YMM7), Op($1B)], [$C5, $FE, $70, $F7, $1B]);
  CheckEnc('vpsignw ymm8,ymm9,ymm10', 'vpsignw', [Op(YMM8), Op(YMM9), Op(YMM10)], [$C4, $42, $35, $09, $C2]);
  CheckEnc('vpsllq ymm11,ymm12,05', 'vpsllq', [Op(YMM11), Op(YMM12), Op($05)], [$C4, $C1, $25, $73, $F4, $05]);
  CheckEnc('vpsraw xmm13,xmm14,03', 'vpsraw', [Op(XMM13), Op(XMM14), Op($03)], [$C4, $C1, $11, $71, $E6, $03]);
  CheckEnc('vpsrldq ymm0,ymm1,04', 'vpsrldq', [Op(YMM0), Op(YMM1), Op($04)], [$C5, $FD, $73, $D9, $04]);
  CheckEnc('vpsubusb ymm2,ymm3,ymm4', 'vpsubusb', [Op(YMM2), Op(YMM3), Op(YMM4)], [$C5, $E5, $D8, $D4]);
  CheckEnc('vptest ymm5,ymm6', 'vptest', [Op(YMM5), Op(YMM6)], [$C4, $E2, $7D, $17, $EE]);
  CheckEnc('vpunpckhqdq ymm7,ymm8,ymm9', 'vpunpckhqdq', [Op(YMM7), Op(YMM8), Op(YMM9)], [$C4, $C1, $3D, $6D, $F9]);
  CheckEnc('vroundps ymm10,ymm11,03', 'vroundps', [Op(YMM10), Op(YMM11), Op($03)], [$C4, $43, $7D, $08, $D3, $03]);
  CheckEnc('vrsqrtps ymm12,[r13+32]', 'vrsqrtps', [Op(YMM12), Op(YmmWordPtr(ridR13, 32))], [$C4, $41, $7C, $52, $65, $20]);
  CheckEnc('vshufpd ymm14,ymm15,ymm8,05', 'vshufpd', [Op(YMM14), Op(YMM15), Op(YMM8), Op($05)], [$C4, $41, $05, $C6, $F0, $05]);
  CheckEnc('vtestps ymm0,[r12+32]', 'vtestps', [Op(YMM0), Op(YmmWordPtr(ridR12, 32))], [$C4, $C2, $7D, $0E, $44, $24, $20]);
  CheckEnc('vunpcklps ymm1,ymm2,ymm3', 'vunpcklps', [Op(YMM1), Op(YMM2), Op(YMM3)], [$C5, $EC, $14, $CB]);
  CheckEnc('vbroadcasti128 ymm4,[r14+64]', 'vbroadcasti128', [Op(YMM4), Op(XmmWordPtr(ridR14, 64))], [$C4, $C2, $7D, $5A, $66, $40]);
  CheckEnc('vextracti128 xmm5,ymm6,01', 'vextracti128', [Op(XMM5), Op(YMM6), Op($01)], [$C4, $E3, $7D, $39, $F5, $01]);
  CheckEnc('vinserti128 ymm7,ymm8,xmm9,01', 'vinserti128', [Op(YMM7), Op(YMM8), Op(XMM9), Op($01)], [$C4, $C3, $3D, $38, $F9, $01]);
  CheckEnc('vpblendd ymm10,ymm11,ymm12,A5', 'vpblendd', [Op(YMM10), Op(YMM11), Op(YMM12), Op($A5)], [$C4, $43, $25, $02, $D4, $A5]);
  CheckEnc('vperm2i128 ymm13,ymm14,ymm15,31', 'vperm2i128', [Op(YMM13), Op(YMM14), Op(YMM15), Op($31)], [$C4, $43, $0D, $46, $EF, $31]);
  CheckEnc('vpermd ymm0,ymm1,ymm2', 'vpermd', [Op(YMM0), Op(YMM1), Op(YMM2)], [$C4, $E2, $75, $36, $C2]);
  CheckEnc('vpermpd ymm3,ymm4,1B', 'vpermpd', [Op(YMM3), Op(YMM4), Op($1B)], [$C4, $E3, $FD, $01, $DC, $1B]);
  CheckEnc('vpermps ymm5,ymm6,ymm7', 'vpermps', [Op(YMM5), Op(YMM6), Op(YMM7)], [$C4, $E2, $4D, $16, $EF]);
  CheckEnc('vpermq ymm8,ymm9,4E', 'vpermq', [Op(YMM8), Op(YMM9), Op($4E)], [$C4, $43, $FD, $00, $C1, $4E]);
  CheckEnc('vpsllvd ymm10,ymm11,ymm12', 'vpsllvd', [Op(YMM10), Op(YMM11), Op(YMM12)], [$C4, $42, $25, $47, $D4]);
  CheckEnc('vpsllvq xmm13,xmm14,xmm15', 'vpsllvq', [Op(XMM13), Op(XMM14), Op(XMM15)], [$C4, $42, $89, $47, $EF]);
  CheckEnc('vpsravd ymm0,ymm1,[r8+32]', 'vpsravd', [Op(YMM0), Op(YMM1), Op(YmmWordPtr(ridR8, 32))], [$C4, $C2, $75, $46, $40, $20]);
  CheckEnc('vpsrlvd ymm2,ymm3,ymm4', 'vpsrlvd', [Op(YMM2), Op(YMM3), Op(YMM4)], [$C4, $E2, $65, $45, $D4]);
  CheckEnc('vpsrlvq ymm5,ymm6,ymm7', 'vpsrlvq', [Op(YMM5), Op(YMM6), Op(YMM7)], [$C4, $E2, $CD, $45, $EF]);
  CheckReject('reject vextracti128 YMM destination', 'vextracti128', [Op(YMM0), Op(YMM1), Op($01)]);
  CheckReject('reject vpermq XMM destination', 'vpermq', [Op(XMM0), Op(XMM1), Op($1B)]);
  CheckReject('reject vpsllvq mixed widths', 'vpsllvq', [Op(YMM0), Op(YMM1), Op(XMM2)]);
  CheckReject('reject vbroadcasti128 m256 source', 'vbroadcasti128', [Op(YMM0), Op(YmmWordPtr(ridRCX))]);
end;

procedure CheckExpandedEncodingsV9;
begin
  CheckEnc('vbroadcastf128 ymm8,[r12+32]', 'vbroadcastf128', [Op(YMM8), Op(XmmWordPtr(ridR12, 32))], [$C4, $42, $7D, $1A, $44, $24, $20]);
  CheckEnc('vextractf128 [r12+32],ymm9,1B', 'vextractf128', [Op(XmmWordPtr(ridR12, 32)), Op(YMM9), Op($1B)], [$C4, $43, $7D, $19, $4C, $24, $20, $1B]);
  CheckEnc('vfmaddsub132pd ymm8,ymm9,ymm10', 'vfmaddsub132pd', [Op(YMM8), Op(YMM9), Op(YMM10)], [$C4, $42, $B5, $96, $C2]);
  CheckEnc('vfmaddsub132ps ymm8,ymm9,ymm10', 'vfmaddsub132ps', [Op(YMM8), Op(YMM9), Op(YMM10)], [$C4, $42, $35, $96, $C2]);
  CheckEnc('vfmaddsub213pd ymm8,ymm9,ymm10', 'vfmaddsub213pd', [Op(YMM8), Op(YMM9), Op(YMM10)], [$C4, $42, $B5, $A6, $C2]);
  CheckEnc('vfmaddsub213ps ymm8,ymm9,ymm10', 'vfmaddsub213ps', [Op(YMM8), Op(YMM9), Op(YMM10)], [$C4, $42, $35, $A6, $C2]);
  CheckEnc('vfmaddsub231pd ymm8,ymm9,ymm10', 'vfmaddsub231pd', [Op(YMM8), Op(YMM9), Op(YMM10)], [$C4, $42, $B5, $B6, $C2]);
  CheckEnc('vfmaddsub231ps ymm8,ymm9,ymm10', 'vfmaddsub231ps', [Op(YMM8), Op(YMM9), Op(YMM10)], [$C4, $42, $35, $B6, $C2]);
  CheckEnc('vfmsubadd132pd ymm8,ymm9,ymm10', 'vfmsubadd132pd', [Op(YMM8), Op(YMM9), Op(YMM10)], [$C4, $42, $B5, $97, $C2]);
  CheckEnc('vfmsubadd132ps ymm8,ymm9,ymm10', 'vfmsubadd132ps', [Op(YMM8), Op(YMM9), Op(YMM10)], [$C4, $42, $35, $97, $C2]);
  CheckEnc('vfmsubadd213pd ymm8,ymm9,ymm10', 'vfmsubadd213pd', [Op(YMM8), Op(YMM9), Op(YMM10)], [$C4, $42, $B5, $A7, $C2]);
  CheckEnc('vfmsubadd213ps ymm8,ymm9,ymm10', 'vfmsubadd213ps', [Op(YMM8), Op(YMM9), Op(YMM10)], [$C4, $42, $35, $A7, $C2]);
  CheckEnc('vfmsubadd231pd ymm8,ymm9,ymm10', 'vfmsubadd231pd', [Op(YMM8), Op(YMM9), Op(YMM10)], [$C4, $42, $B5, $B7, $C2]);
  CheckEnc('vfmsubadd231ps ymm8,ymm9,ymm10', 'vfmsubadd231ps', [Op(YMM8), Op(YMM9), Op(YMM10)], [$C4, $42, $35, $B7, $C2]);
  CheckEnc('vinsertf128 ymm8,ymm9,xmm10,1B', 'vinsertf128', [Op(YMM8), Op(YMM9), Op(XMM10), Op($1B)], [$C4, $43, $35, $18, $C2, $1B]);
  CheckEnc('vmpsadbw ymm8,ymm9,ymm10,1B', 'vmpsadbw', [Op(YMM8), Op(YMM9), Op(YMM10), Op($1B)], [$C4, $43, $35, $42, $C2, $1B]);
  CheckEnc('vpabsb ymm8,ymm9', 'vpabsb', [Op(YMM8), Op(YMM9)], [$C4, $42, $7D, $1C, $C1]);
  CheckEnc('vpabsw ymm8,ymm9', 'vpabsw', [Op(YMM8), Op(YMM9)], [$C4, $42, $7D, $1D, $C1]);
  CheckEnc('vpalignr ymm8,ymm9,ymm10,1B', 'vpalignr', [Op(YMM8), Op(YMM9), Op(YMM10), Op($1B)], [$C4, $43, $35, $0F, $C2, $1B]);
  CheckEnc('vpandn ymm8,ymm9,ymm10', 'vpandn', [Op(YMM8), Op(YMM9), Op(YMM10)], [$C4, $41, $35, $DF, $C2]);
  CheckEnc('vpblendw ymm8,ymm9,ymm10,1B', 'vpblendw', [Op(YMM8), Op(YMM9), Op(YMM10), Op($1B)], [$C4, $43, $35, $0E, $C2, $1B]);
  CheckEnc('vpcmpeqq ymm8,ymm9,ymm10', 'vpcmpeqq', [Op(YMM8), Op(YMM9), Op(YMM10)], [$C4, $42, $35, $29, $C2]);
  CheckEnc('vpcmpgtq ymm8,ymm9,ymm10', 'vpcmpgtq', [Op(YMM8), Op(YMM9), Op(YMM10)], [$C4, $42, $35, $37, $C2]);
  CheckEnc('vperm2f128 ymm8,ymm9,ymm10,1B', 'vperm2f128', [Op(YMM8), Op(YMM9), Op(YMM10), Op($1B)], [$C4, $43, $35, $06, $C2, $1B]);
  CheckEnc('vpermilps ymm8,ymm9,1B', 'vpermilps', [Op(YMM8), Op(YMM9), Op($1B)], [$C4, $43, $7D, $04, $C1, $1B]);
  CheckEnc('vphaddd ymm8,ymm9,ymm10', 'vphaddd', [Op(YMM8), Op(YMM9), Op(YMM10)], [$C4, $42, $35, $02, $C2]);
  CheckEnc('vphaddsw ymm8,ymm9,ymm10', 'vphaddsw', [Op(YMM8), Op(YMM9), Op(YMM10)], [$C4, $42, $35, $03, $C2]);
  CheckEnc('vphaddw ymm8,ymm9,ymm10', 'vphaddw', [Op(YMM8), Op(YMM9), Op(YMM10)], [$C4, $42, $35, $01, $C2]);
  CheckEnc('vphsubd ymm8,ymm9,ymm10', 'vphsubd', [Op(YMM8), Op(YMM9), Op(YMM10)], [$C4, $42, $35, $06, $C2]);
  CheckEnc('vphsubsw ymm8,ymm9,ymm10', 'vphsubsw', [Op(YMM8), Op(YMM9), Op(YMM10)], [$C4, $42, $35, $07, $C2]);
  CheckEnc('vphsubw ymm8,ymm9,ymm10', 'vphsubw', [Op(YMM8), Op(YMM9), Op(YMM10)], [$C4, $42, $35, $05, $C2]);
  CheckEnc('vzeroall', 'vzeroall', [], [$C5, $FC, $77]);
  CheckReject('reject vbroadcastf128 m256 source', 'vbroadcastf128', [Op(YMM0), Op(YmmWordPtr(ridRCX))]);
  CheckReject('reject vextractf128 YMM destination', 'vextractf128', [Op(YMM0), Op(YMM1), Op($01)]);
  CheckReject('reject vpalignr imm8 above range', 'vpalignr', [Op(YMM0), Op(YMM1), Op(YMM2), Op(256)]);
  CheckReject('reject FMA addsub mixed vector widths', 'vfmaddsub231ps', [Op(YMM0), Op(XMM1), Op(YMM2)]);
end;

procedure CheckPublicApiV9;
var
  B: TAsmBuilder;
  Actual: TBytes;
begin
  B := TAsmBuilder.New;
  try
    B.Vpabsb(YMM8, YMM9).Vzeroall;
    Actual := B.Build;
    if SameBytes(Actual, [$C4, $42, $7D, $1C, $C1, $C5, $FC, $77]) then
    begin
      Inc(GPass);
      Writeln('PASS expanded AVX public API');
      Writeln('  BYTES    ', BytesText(Actual));
    end
    else
    begin
      Inc(GFail);
      Writeln('FAIL expanded AVX public API');
      Writeln('  ACTUAL   ', BytesText(Actual));
      Writeln('  EXPECTED C4 42 7D 1C C1 C5 FC 77');
    end;
  finally
    B.Free;
  end;
end;


procedure CheckExpandedEncodingsV10;
begin
  CheckEnc('vaddss xmm0,xmm1,xmm2', 'vaddss', [Op(XMM0), Op(XMM1), Op(XMM2)], [$C5, $F2, $58, $C2]);
  CheckEnc('vaddsd xmm8,xmm9,[r12+32]', 'vaddsd', [Op(XMM8), Op(XMM9), Op(QWordPtr(ridR12, 32))], [$C4, $41, $33, $58, $44, $24, $20]);
  CheckEnc('vcmpss xmm3,xmm4,[r13+16],1B', 'vcmpss', [Op(XMM3), Op(XMM4), Op(DWordPtr(ridR13, 16)), Op($1B)], [$C4, $C1, $5A, $C2, $5D, $10, $1B]);
  CheckEnc('vroundsd xmm5,xmm6,xmm7,03', 'vroundsd', [Op(XMM5), Op(XMM6), Op(XMM7), Op($03)], [$C4, $E3, $49, $0B, $EF, $03]);
  CheckEnc('vbroadcastss ymm0,[rcx+32]', 'vbroadcastss', [Op(YMM0), Op(DWordPtr(ridRCX, 32))], [$C4, $E2, $7D, $18, $41, $20]);
  CheckEnc('vbroadcastsd ymm1,xmm2', 'vbroadcastsd', [Op(YMM1), Op(XMM2)], [$C4, $E2, $7D, $19, $CA]);
  CheckEnc('vpbroadcastb ymm3,[r12+16]', 'vpbroadcastb', [Op(YMM3), Op(BytePtr(ridR12, 16))], [$C4, $C2, $7D, $78, $5C, $24, $10]);
  CheckEnc('vpbroadcastw xmm4,xmm5', 'vpbroadcastw', [Op(XMM4), Op(XMM5)], [$C4, $E2, $79, $79, $E5]);
  CheckEnc('vpbroadcastd ymm6,[r13+64]', 'vpbroadcastd', [Op(YMM6), Op(DWordPtr(ridR13, 64))], [$C4, $C2, $7D, $58, $75, $40]);
  CheckEnc('vpbroadcastq ymm7,xmm8', 'vpbroadcastq', [Op(YMM7), Op(XMM8)], [$C4, $C2, $7D, $59, $F8]);
  CheckEnc('vpmovsxbw ymm0,[rcx+32]', 'vpmovsxbw', [Op(YMM0), Op(XmmWordPtr(ridRCX, 32))], [$C4, $E2, $7D, $20, $41, $20]);
  CheckEnc('vpmovsxbd ymm1,[r12+16]', 'vpmovsxbd', [Op(YMM1), Op(QWordPtr(ridR12, 16))], [$C4, $C2, $7D, $21, $4C, $24, $10]);
  CheckEnc('vpmovsxbq ymm2,[r13+8]', 'vpmovsxbq', [Op(YMM2), Op(DWordPtr(ridR13, 8))], [$C4, $C2, $7D, $22, $55, $08]);
  CheckEnc('vpmovsxwd ymm3,[r14+32]', 'vpmovsxwd', [Op(YMM3), Op(XmmWordPtr(ridR14, 32))], [$C4, $C2, $7D, $23, $5E, $20]);
  CheckEnc('vpmovsxdq ymm4,xmm5', 'vpmovsxdq', [Op(YMM4), Op(XMM5)], [$C4, $E2, $7D, $25, $E5]);
  CheckEnc('vpmovzxbw ymm6,xmm7', 'vpmovzxbw', [Op(YMM6), Op(XMM7)], [$C4, $E2, $7D, $30, $F7]);
  CheckEnc('vpmovzxbd ymm8,[r12+24]', 'vpmovzxbd', [Op(YMM8), Op(QWordPtr(ridR12, 24))], [$C4, $42, $7D, $31, $44, $24, $18]);
  CheckEnc('vpmovzxbq ymm9,[r13+12]', 'vpmovzxbq', [Op(YMM9), Op(DWordPtr(ridR13, 12))], [$C4, $42, $7D, $32, $4D, $0C]);
  CheckEnc('vpmovzxwd ymm10,xmm11', 'vpmovzxwd', [Op(YMM10), Op(XMM11)], [$C4, $42, $7D, $33, $D3]);
  CheckEnc('vpmovzxdq ymm12,[r14+64]', 'vpmovzxdq', [Op(YMM12), Op(XmmWordPtr(ridR14, 64))], [$C4, $42, $7D, $35, $66, $40]);
  CheckEnc('vcvtdq2pd ymm0,xmm1', 'vcvtdq2pd', [Op(YMM0), Op(XMM1)], [$C5, $FE, $E6, $C1]);
  CheckEnc('vcvtdq2ps ymm2,ymm3', 'vcvtdq2ps', [Op(YMM2), Op(YMM3)], [$C5, $FC, $5B, $D3]);
  CheckEnc('vcvtpd2dq xmm4,ymm5', 'vcvtpd2dq', [Op(XMM4), Op(YMM5)], [$C5, $FF, $E6, $E5]);
  CheckEnc('vcvtpd2ps xmm6,ymm7', 'vcvtpd2ps', [Op(XMM6), Op(YMM7)], [$C5, $FD, $5A, $F7]);
  CheckEnc('vcvtps2pd ymm8,xmm9', 'vcvtps2pd', [Op(YMM8), Op(XMM9)], [$C4, $41, $7C, $5A, $C1]);
  CheckEnc('vcvttps2dq ymm10,ymm11', 'vcvttps2dq', [Op(YMM10), Op(YMM11)], [$C4, $41, $7E, $5B, $D3]);
  CheckEnc('vcvtsd2ss xmm12,xmm13,[r14+32]', 'vcvtsd2ss', [Op(XMM12), Op(XMM13), Op(QWordPtr(ridR14, 32))], [$C4, $41, $13, $5A, $66, $20]);
  CheckEnc('vcvtss2sd xmm0,xmm1,[r12+16]', 'vcvtss2sd', [Op(XMM0), Op(XMM1), Op(DWordPtr(ridR12, 16))], [$C4, $C1, $72, $5A, $44, $24, $10]);
  CheckEnc('vinsertps xmm2,xmm3,[r13+4],20', 'vinsertps', [Op(XMM2), Op(XMM3), Op(DWordPtr(ridR13, 4)), Op($20)], [$C4, $C3, $61, $21, $55, $04, $20]);
  CheckEnc('vrcpss xmm4,xmm5,[r14+8]', 'vrcpss', [Op(XMM4), Op(XMM5), Op(DWordPtr(ridR14, 8))], [$C4, $C1, $52, $53, $66, $08]);
  CheckEnc('vsqrtsd xmm6,xmm7,xmm8', 'vsqrtsd', [Op(XMM6), Op(XMM7), Op(XMM8)], [$C4, $C1, $43, $51, $F0]);
  CheckEnc('vucomiss xmm9,[r12+4]', 'vucomiss', [Op(XMM9), Op(DWordPtr(ridR12, 4))], [$C4, $41, $78, $2E, $4C, $24, $04]);
  CheckEnc('vfmadd132ss xmm10,xmm11,[r13+12]', 'vfmadd132ss', [Op(XMM10), Op(XMM11), Op(DWordPtr(ridR13, 12))], [$C4, $42, $21, $99, $55, $0C]);
  CheckEnc('vfnmsub231sd xmm12,xmm13,xmm14', 'vfnmsub231sd', [Op(XMM12), Op(XMM13), Op(XMM14)], [$C4, $42, $91, $BF, $E6]);
  CheckReject('reject vaddss m64 source', 'vaddss', [Op(XMM0), Op(XMM1), Op(QWordPtr(ridRCX))]);
  CheckReject('reject vaddsd YMM destination', 'vaddsd', [Op(YMM0), Op(XMM1), Op(XMM2)]);
  CheckReject('reject vbroadcastss m64 source', 'vbroadcastss', [Op(YMM0), Op(QWordPtr(ridRCX))]);
  CheckReject('reject vpmovsxbq ymm m64 source', 'vpmovsxbq', [Op(YMM0), Op(QWordPtr(ridRCX))]);
  CheckReject('reject scalar FMA YMM destination', 'vfmadd132ss', [Op(YMM0), Op(XMM1), Op(XMM2)]);
end;

procedure CheckPublicApiV10;
var
  B: TAsmBuilder;
  Actual: TBytes;
begin
  B := TAsmBuilder.New;
  try
    B.Vaddss(XMM0, XMM1, DWordPtr(ridRCX)).Vpbroadcastb(YMM2, BytePtr(ridRDX)).Vfnmsub231sd(XMM3, XMM4, XMM5);
    Actual := B.Build;
    if SameBytes(Actual, [$C5, $F2, $58, $01, $C4, $E2, $7D, $78, $12, $C4, $E2, $D9, $BF, $DD]) then
    begin
      Inc(GPass);
      Writeln('PASS scalar/broadcast AVX public API');
      Writeln('  BYTES    ', BytesText(Actual));
    end
    else
    begin
      Inc(GFail);
      Writeln('FAIL scalar/broadcast AVX public API');
      Writeln('  ACTUAL   ', BytesText(Actual));
      Writeln('  EXPECTED C5 F2 58 01 C4 E2 7D 78 12 C4 E2 D9 BF DD');
    end;
  finally
    B.Free;
  end;
end;

procedure CheckRuntimeScalarAvx;
type
  TSingle4 = array[0..3] of Single;
var
  Status: TAvxCpuStatus;
  A, OutV: TSingle4;
  Scalar: Single;
  B: TAsmBuilder;
  Exe: TExecutableCode;
  I: Integer;
  FailLane: Integer;
  Ok: Boolean;
  Expected: Single;
  Actual: TBytes;
begin
  Status := TAvxCpuFeatures.Query;
  if not Status.AvxUsable then
  begin
    Inc(GSkip);
    Writeln('SKIP AVX runtime vaddss: AVX execution is not available');
    Exit;
  end;

  for I := 0 to 3 do
  begin
    A[I] := I + 1;
    OutV[I] := 0;
  end;
  Scalar := 10;

  B := TAsmBuilder.New;
  try
    B.Vmovdqu(XMM0, XmmWordPtr(ridRCX)).Vaddss(XMM0, XMM0, DWordPtr(ridRDX)).Vmovdqu(XmmWordPtr(ridR8), XMM0).Vzeroupper.Ret;
    Actual := B.Build;
    if not SameBytes(Actual, [$C5, $FA, $6F, $01, $C5, $FA, $58, $02, $C4, $C1, $7A, $7F, $00, $C5, $F8, $77, $C3]) then
    begin
      Inc(GFail);
      Writeln('FAIL AVX runtime vaddss kernel encoding');
      Writeln('  ACTUAL   ', BytesText(Actual));
      Writeln('  EXPECTED C5 FA 6F 01 C5 FA 58 02 C4 C1 7A 7F 00 C5 F8 77 C3');
      Exit;
    end;
    Exe := TExecutableCode.Create(Actual);
    try
      Exe.Run(UInt64(NativeUInt(@A[0])), UInt64(NativeUInt(@Scalar)), UInt64(NativeUInt(@OutV[0])));
    finally
      Exe.Free;
    end;
  finally
    B.Free;
  end;

  Ok := True;
  FailLane := -1;
  for I := 0 to 3 do
  begin
    if I = 0 then Expected := A[I] + Scalar else Expected := A[I];
    if OutV[I] <> Expected then
    begin
      Ok := False;
      FailLane := I;
      Break;
    end;
  end;

  if Ok then
  begin
    Inc(GPass);
    Writeln('PASS AVX runtime vaddss scalar lane preserve');
  end
  else
  begin
    if FailLane = 0 then Expected := A[0] + Scalar else Expected := A[FailLane];
    Inc(GFail);
    Writeln('FAIL AVX runtime vaddss at lane ', FailLane, ': actual=', OutV[FailLane]:0:6, ' expected=', Expected:0:6);
  end;
end;

procedure CheckRuntimeAvx2Permute;
type
  TUInt64x4 = array[0..3] of UInt64;
var
  Status: TAvxCpuStatus;
  A, OutV: TUInt64x4;
  B: TAsmBuilder;
  Exe: TExecutableCode;
  I: Integer;
  FailLane: Integer;
  Ok: Boolean;
  Actual: TBytes;
begin
  Status := TAvxCpuFeatures.Query;
  if not Status.Avx2Usable then
  begin
    Inc(GSkip);
    Writeln('SKIP AVX2 runtime vpermq: AVX2 execution is not available');
    Exit;
  end;

  for I := 0 to 3 do
  begin
    A[I] := UInt64(I + 1);
    OutV[I] := 0;
  end;

  B := TAsmBuilder.New;
  try
    B.Vpermq(YMM0, YmmWordPtr(ridRCX), $1B).Vmovdqu(YmmWordPtr(ridRDX), YMM0).Vzeroupper.Ret;
    Actual := B.Build;
    if not SameBytes(Actual, [$C4, $E3, $FD, $00, $01, $1B, $C5, $FE, $7F, $02, $C5, $F8, $77, $C3]) then
    begin
      Inc(GFail);
      Writeln('FAIL AVX2 runtime vpermq kernel encoding');
      Writeln('  ACTUAL   ', BytesText(Actual));
      Writeln('  EXPECTED C4 E3 FD 00 01 1B C5 FE 7F 02 C5 F8 77 C3');
      Exit;
    end;
    Exe := TExecutableCode.Create(Actual);
    try
      Exe.Run(UInt64(NativeUInt(@A[0])), UInt64(NativeUInt(@OutV[0])));
    finally
      Exe.Free;
    end;
  finally
    B.Free;
  end;

  Ok := True;
  FailLane := -1;
  for I := 0 to 3 do
    if OutV[I] <> A[3 - I] then
    begin
      Ok := False;
      FailLane := I;
      Break;
    end;

  if Ok then
  begin
    Inc(GPass);
    Writeln('PASS AVX2 runtime vpermq ymm reverse lanes');
  end
  else
  begin
    Inc(GFail);
    Writeln('FAIL AVX2 runtime vpermq at lane ', FailLane, ': actual=', OutV[FailLane], ' expected=', A[3 - FailLane]);
  end;
end;

procedure CheckGprXmmEncodings;
begin
  CheckEnc('vmovd eax,xmm1', 'vmovd', [Op(EAX), Op(XMM1)], [$C5, $F9, $7E, $C8]);
  CheckEnc('vmovd xmm8,r9d', 'vmovd', [Op(XMM8), Op(R9D)], [$C4, $41, $79, $6E, $C1]);
  CheckEnc('vmovd [r12+32],xmm9', 'vmovd', [Op(DWordPtr(ridR12, 32)), Op(XMM9)], [$C4, $41, $79, $7E, $4C, $24, $20]);
  CheckEnc('vmovd xmm10,[r13+16]', 'vmovd', [Op(XMM10), Op(DWordPtr(ridR13, 16))], [$C4, $41, $79, $6E, $55, $10]);
  CheckEnc('vmovq rax,xmm1', 'vmovq', [Op(RAX), Op(XMM1)], [$C4, $E1, $F9, $7E, $C8]);
  CheckEnc('vmovq xmm8,r9', 'vmovq', [Op(XMM8), Op(R9)], [$C4, $41, $F9, $6E, $C1]);
  CheckEnc('vmovq xmm2,xmm3', 'vmovq', [Op(XMM2), Op(XMM3)], [$C5, $FA, $7E, $D3]);
  CheckEnc('vmovq xmm4,[r14+24]', 'vmovq', [Op(XMM4), Op(QWordPtr(ridR14, 24))], [$C4, $C1, $7A, $7E, $66, $18]);
  CheckReject('reject vmovd r64 destination', 'vmovd', [Op(RAX), Op(XMM0)]);
  CheckReject('reject vmovq r32 source', 'vmovq', [Op(XMM0), Op(EAX)]);
  CheckReject('reject vmovd m64 source', 'vmovd', [Op(XMM0), Op(QWordPtr(ridRCX))]);
end;

procedure CheckPublicApiGprXmm;
var
  B: TAsmBuilder;
  Actual: TBytes;
begin
  B := TAsmBuilder.New;
  try
    B.Vmovd(XMM0, ECX).Vmovd(EAX, XMM0).Vmovq(XMM1, RDX).Vmovq(RAX, XMM1);
    Actual := B.Build;
    if SameBytes(Actual, [$C5, $F9, $6E, $C1, $C5, $F9, $7E, $C0, $C4, $E1, $F9, $6E, $CA, $C4, $E1, $F9, $7E, $C8]) then
    begin
      Inc(GPass);
      Writeln('PASS GPR/XMM AVX public API');
      Writeln('  BYTES    ', BytesText(Actual));
    end
    else
    begin
      Inc(GFail);
      Writeln('FAIL GPR/XMM AVX public API');
      Writeln('  ACTUAL   ', BytesText(Actual));
      Writeln('  EXPECTED C5 F9 6E C1 C5 F9 7E C0 C4 E1 F9 6E CA C4 E1 F9 7E C8');
    end;
  finally
    B.Free;
  end;
end;

procedure CheckRuntimeGprXmm;
var
  Status: TAvxCpuStatus;
  B: TAsmBuilder;
  Exe: TExecutableCode;
  Actual: TBytes;
  V, R: UInt64;
begin
  Status := TAvxCpuFeatures.Query;
  if not Status.AvxUsable then
  begin
    Inc(GSkip);
    Writeln('SKIP AVX runtime vmovd/vmovq: AVX execution is not available');
    Exit;
  end;

  V := $FEDCBA9876543210;
  B := TAsmBuilder.New;
  try
    B.Vmovd(XMM0, ECX).Vmovd(EAX, XMM0).Ret;
    Actual := B.Build;
    if not SameBytes(Actual, [$C5, $F9, $6E, $C1, $C5, $F9, $7E, $C0, $C3]) then
    begin
      Inc(GFail);
      Writeln('FAIL AVX runtime vmovd kernel encoding');
      Exit;
    end;
    Exe := TExecutableCode.Create(Actual);
    try
      R := Exe.Run(V);
    finally
      Exe.Free;
    end;
  finally
    B.Free;
  end;
  if R = $0000000076543210 then begin Inc(GPass); Writeln('PASS AVX runtime vmovd GPR/XMM roundtrip'); end
  else begin Inc(GFail); Writeln('FAIL AVX runtime vmovd GPR/XMM roundtrip: ', IntToHex(R, 16)); end;

  B := TAsmBuilder.New;
  try
    B.Vmovq(XMM0, RCX).Vmovq(RAX, XMM0).Ret;
    Actual := B.Build;
    if not SameBytes(Actual, [$C4, $E1, $F9, $6E, $C1, $C4, $E1, $F9, $7E, $C0, $C3]) then
    begin
      Inc(GFail);
      Writeln('FAIL AVX runtime vmovq kernel encoding');
      Exit;
    end;
    Exe := TExecutableCode.Create(Actual);
    try
      R := Exe.Run(V);
    finally
      Exe.Free;
    end;
  finally
    B.Free;
  end;
  if R = V then begin Inc(GPass); Writeln('PASS AVX runtime vmovq GPR/XMM roundtrip'); end
  else begin Inc(GFail); Writeln('FAIL AVX runtime vmovq GPR/XMM roundtrip: ', IntToHex(R, 16)); end;
end;

procedure CheckInsertExtractEncodings;
begin
  CheckEnc('vpinsrb xmm0,xmm1,eax,03', 'vpinsrb', [Op(XMM0), Op(XMM1), Op(EAX), Op($03)], [$C4, $E3, $71, $20, $C0, $03]);
  CheckEnc('vpinsrb xmm8,xmm9,r10d,07', 'vpinsrb', [Op(XMM8), Op(XMM9), Op(R10D), Op($07)], [$C4, $43, $31, $20, $C2, $07]);
  CheckEnc('vpinsrd xmm2,xmm3,[r12+16],02', 'vpinsrd', [Op(XMM2), Op(XMM3), Op(DWordPtr(ridR12, 16)), Op($02)], [$C4, $C3, $61, $22, $54, $24, $10, $02]);
  CheckEnc('vpinsrq xmm10,xmm11,r13,01', 'vpinsrq', [Op(XMM10), Op(XMM11), Op(R13), Op($01)], [$C4, $43, $A1, $22, $D5, $01]);
  CheckEnc('vpextrb eax,xmm1,05', 'vpextrb', [Op(EAX), Op(XMM1), Op($05)], [$C4, $E3, $79, $14, $C8, $05]);
  CheckEnc('vpextrb [r12+7],xmm9,06', 'vpextrb', [Op(BytePtr(ridR12, 7)), Op(XMM9), Op($06)], [$C4, $43, $79, $14, $4C, $24, $07, $06]);
  CheckEnc('vpextrd r10d,xmm11,02', 'vpextrd', [Op(R10D), Op(XMM11), Op($02)], [$C4, $43, $79, $16, $DA, $02]);
  CheckEnc('vpextrd [r13+12],xmm14,01', 'vpextrd', [Op(DWordPtr(ridR13, 12)), Op(XMM14), Op($01)], [$C4, $43, $79, $16, $75, $0C, $01]);
  CheckEnc('vpextrq r9,xmm8,01', 'vpextrq', [Op(R9), Op(XMM8), Op($01)], [$C4, $43, $F9, $16, $C1, $01]);
  CheckEnc('vpextrq [r14+24],xmm15,00', 'vpextrq', [Op(QWordPtr(ridR14, 24)), Op(XMM15), Op($00)], [$C4, $43, $F9, $16, $7E, $18, $00]);
  CheckReject('reject vpinsrb r64 source', 'vpinsrb', [Op(XMM0), Op(XMM1), Op(RAX), Op(0)]);
  CheckReject('reject vpinsrq r32 source', 'vpinsrq', [Op(XMM0), Op(XMM1), Op(EAX), Op(0)]);
  CheckReject('reject vpextrd r64 destination', 'vpextrd', [Op(RAX), Op(XMM0), Op(0)]);
  CheckReject('reject vpextrq m32 destination', 'vpextrq', [Op(DWordPtr(ridRCX)), Op(XMM0), Op(0)]);
  CheckReject('reject vpinsrd YMM destination', 'vpinsrd', [Op(YMM0), Op(XMM1), Op(EAX), Op(0)]);
end;

procedure CheckPublicApiInsertExtract;
var
  B: TAsmBuilder;
  Actual: TBytes;
begin
  B := TAsmBuilder.New;
  try
    B.Vpinsrb(XMM0, XMM1, EAX, 3).Vpextrb(ECX, XMM0, 3).Vpinsrq(XMM8, XMM9, R10, 1).Vpextrq(R11, XMM8, 1);
    Actual := B.Build;
    if SameBytes(Actual, [$C4, $E3, $71, $20, $C0, $03, $C4, $E3, $79, $14, $C1, $03, $C4, $43, $B1, $22, $C2, $01, $C4, $43, $F9, $16, $C3, $01]) then
    begin
      Inc(GPass);
      Writeln('PASS insert/extract AVX public API');
      Writeln('  BYTES    ', BytesText(Actual));
    end
    else
    begin
      Inc(GFail);
      Writeln('FAIL insert/extract AVX public API');
      Writeln('  ACTUAL   ', BytesText(Actual));
      Writeln('  EXPECTED C4 E3 71 20 C0 03 C4 E3 79 14 C1 03 C4 43 B1 22 C2 01 C4 43 F9 16 C3 01');
    end;
  finally
    B.Free;
  end;
end;

procedure CheckRuntimeInsertExtract;
var
  Status: TAvxCpuStatus;
  B: TAsmBuilder;
  Exe: TExecutableCode;
  Actual: TBytes;
  R: UInt64;
begin
  Status := TAvxCpuFeatures.Query;
  if not Status.AvxUsable then
  begin
    Inc(GSkip);
    Writeln('SKIP AVX runtime insert/extract: AVX execution is not available');
    Exit;
  end;

  B := TAsmBuilder.New;
  try
    B.Vmovd(XMM0, ECX).Vpinsrb(XMM0, XMM0, EDX, 3).Vpextrb(EAX, XMM0, 3).Ret;
    Actual := B.Build;
    if not SameBytes(Actual, [$C5, $F9, $6E, $C1, $C4, $E3, $79, $20, $C2, $03, $C4, $E3, $79, $14, $C0, $03, $C3]) then
    begin
      Inc(GFail);
      Writeln('FAIL AVX runtime vpinsrb/vpextrb kernel encoding');
      Exit;
    end;
    Exe := TExecutableCode.Create(Actual);
    try
      R := Exe.Run($11223344, $AABBCCDD);
    finally
      Exe.Free;
    end;
  finally
    B.Free;
  end;
  if R = $DD then begin Inc(GPass); Writeln('PASS AVX runtime vpinsrb/vpextrb roundtrip'); end
  else begin Inc(GFail); Writeln('FAIL AVX runtime vpinsrb/vpextrb roundtrip: ', IntToHex(R, 16)); end;

  B := TAsmBuilder.New;
  try
    B.Vmovd(XMM0, ECX).Vpinsrd(XMM0, XMM0, EDX, 1).Vpextrd(EAX, XMM0, 1).Ret;
    Actual := B.Build;
    if not SameBytes(Actual, [$C5, $F9, $6E, $C1, $C4, $E3, $79, $22, $C2, $01, $C4, $E3, $79, $16, $C0, $01, $C3]) then
    begin
      Inc(GFail);
      Writeln('FAIL AVX runtime vpinsrd/vpextrd kernel encoding');
      Exit;
    end;
    Exe := TExecutableCode.Create(Actual);
    try
      R := Exe.Run($11223344, $AABBCCDD);
    finally
      Exe.Free;
    end;
  finally
    B.Free;
  end;
  if R = $00000000AABBCCDD then begin Inc(GPass); Writeln('PASS AVX runtime vpinsrd/vpextrd roundtrip'); end
  else begin Inc(GFail); Writeln('FAIL AVX runtime vpinsrd/vpextrd roundtrip: ', IntToHex(R, 16)); end;

  B := TAsmBuilder.New;
  try
    B.Vmovq(XMM0, RCX).Vpinsrq(XMM0, XMM0, RDX, 1).Vpextrq(RAX, XMM0, 1).Ret;
    Actual := B.Build;
    if not SameBytes(Actual, [$C4, $E1, $F9, $6E, $C1, $C4, $E3, $F9, $22, $C2, $01, $C4, $E3, $F9, $16, $C0, $01, $C3]) then
    begin
      Inc(GFail);
      Writeln('FAIL AVX runtime vpinsrq/vpextrq kernel encoding');
      Exit;
    end;
    Exe := TExecutableCode.Create(Actual);
    try
      R := Exe.Run($1122334455667788, $AABBCCDDEEFF0011);
    finally
      Exe.Free;
    end;
  finally
    B.Free;
  end;
  if R = $AABBCCDDEEFF0011 then begin Inc(GPass); Writeln('PASS AVX runtime vpinsrq/vpextrq roundtrip'); end
  else begin Inc(GFail); Writeln('FAIL AVX runtime vpinsrq/vpextrq roundtrip: ', IntToHex(R, 16)); end;
end;

procedure CheckPhase3Encodings;
begin
  CheckEnc('vextractps r10d,xmm11,02', 'vextractps', [Op(R10D), Op(XMM11), Op($02)], [$C4, $43, $79, $17, $DA, $02]);
  CheckEnc('vextractps [r12+20],xmm9,03', 'vextractps', [Op(DWordPtr(ridR12, 20)), Op(XMM9), Op($03)], [$C4, $43, $79, $17, $4C, $24, $14, $03]);
  CheckEnc('vpinsrw xmm8,xmm9,r10d,05', 'vpinsrw', [Op(XMM8), Op(XMM9), Op(R10D), Op($05)], [$C4, $41, $31, $C4, $C2, $05]);
  CheckEnc('vpinsrw xmm2,xmm3,[r13+6],07', 'vpinsrw', [Op(XMM2), Op(XMM3), Op(WordPtr(ridR13, 6)), Op($07)], [$C4, $C1, $61, $C4, $55, $06, $07]);
  CheckEnc('vpextrw r10d,xmm11,04', 'vpextrw', [Op(R10D), Op(XMM11), Op($04)], [$C4, $41, $79, $C5, $D3, $04]);
  CheckEnc('vpextrw [r12+10],xmm9,02', 'vpextrw', [Op(WordPtr(ridR12, 10)), Op(XMM9), Op($02)], [$C4, $43, $79, $15, $4C, $24, $0A, $02]);
  CheckEnc('vmovmskps r10d,xmm11', 'vmovmskps', [Op(R10D), Op(XMM11)], [$C4, $41, $78, $50, $D3]);
  CheckEnc('vmovmskps r9d,ymm8', 'vmovmskps', [Op(R9D), Op(YMM8)], [$C4, $41, $7C, $50, $C8]);
  CheckEnc('vmovmskpd r10d,xmm11', 'vmovmskpd', [Op(R10D), Op(XMM11)], [$C4, $41, $79, $50, $D3]);
  CheckEnc('vmovmskpd r9d,ymm8', 'vmovmskpd', [Op(R9D), Op(YMM8)], [$C4, $41, $7D, $50, $C8]);
  CheckEnc('vpmovmskb r10d,xmm11', 'vpmovmskb', [Op(R10D), Op(XMM11)], [$C4, $41, $79, $D7, $D3]);
  CheckEnc('vpmovmskb r9d,ymm8', 'vpmovmskb', [Op(R9D), Op(YMM8)], [$C4, $41, $7D, $D7, $C8]);
  CheckEnc('vcvtsi2ss xmm8,xmm9,r10d', 'vcvtsi2ss', [Op(XMM8), Op(XMM9), Op(R10D)], [$C4, $41, $32, $2A, $C2]);
  CheckEnc('vcvtsi2ss xmm8,xmm9,r10', 'vcvtsi2ss', [Op(XMM8), Op(XMM9), Op(R10)], [$C4, $41, $B2, $2A, $C2]);
  CheckEnc('vcvtsi2sd xmm10,xmm11,[r12+16] dword', 'vcvtsi2sd', [Op(XMM10), Op(XMM11), Op(DWordPtr(ridR12, 16))], [$C4, $41, $23, $2A, $54, $24, $10]);
  CheckEnc('vcvtsi2sd xmm10,xmm11,[r12+16] qword', 'vcvtsi2sd', [Op(XMM10), Op(XMM11), Op(QWordPtr(ridR12, 16))], [$C4, $41, $A3, $2A, $54, $24, $10]);
  CheckEnc('vcvtss2si r10d,xmm11', 'vcvtss2si', [Op(R10D), Op(XMM11)], [$C4, $41, $7A, $2D, $D3]);
  CheckEnc('vcvtss2si r10,xmm11', 'vcvtss2si', [Op(R10), Op(XMM11)], [$C4, $41, $FA, $2D, $D3]);
  CheckEnc('vcvtsd2si r9d,[r13+24]', 'vcvtsd2si', [Op(R9D), Op(QWordPtr(ridR13, 24))], [$C4, $41, $7B, $2D, $4D, $18]);
  CheckEnc('vcvtsd2si r9,[r13+24]', 'vcvtsd2si', [Op(R9), Op(QWordPtr(ridR13, 24))], [$C4, $41, $FB, $2D, $4D, $18]);
  CheckEnc('vcvttss2si r10d,[r12+12]', 'vcvttss2si', [Op(R10D), Op(DWordPtr(ridR12, 12))], [$C4, $41, $7A, $2C, $54, $24, $0C]);
  CheckEnc('vcvttss2si r10,xmm11', 'vcvttss2si', [Op(R10), Op(XMM11)], [$C4, $41, $FA, $2C, $D3]);
  CheckEnc('vcvttsd2si r9d,xmm8', 'vcvttsd2si', [Op(R9D), Op(XMM8)], [$C4, $41, $7B, $2C, $C8]);
  CheckEnc('vcvttsd2si r9,[r13+24]', 'vcvttsd2si', [Op(R9), Op(QWordPtr(ridR13, 24))], [$C4, $41, $FB, $2C, $4D, $18]);
  CheckReject('reject vextractps m64 destination', 'vextractps', [Op(QWordPtr(ridRCX)), Op(XMM0), Op(0)]);
  CheckReject('reject vpinsrw r64 source', 'vpinsrw', [Op(XMM0), Op(XMM1), Op(RAX), Op(0)]);
  CheckReject('reject vpextrw m32 destination', 'vpextrw', [Op(DWordPtr(ridRCX)), Op(XMM0), Op(0)]);
  CheckReject('reject vmovmskps memory source', 'vmovmskps', [Op(EAX), Op(XmmWordPtr(ridRCX))]);
  CheckReject('reject vpmovmskb memory source', 'vpmovmskb', [Op(EAX), Op(XmmWordPtr(ridRCX))]);
  CheckReject('reject vcvtsi2ss m16 source', 'vcvtsi2ss', [Op(XMM0), Op(XMM1), Op(WordPtr(ridRCX))]);
  CheckReject('reject vcvtss2si m64 source', 'vcvtss2si', [Op(RAX), Op(QWordPtr(ridRCX))]);
  CheckReject('reject vcvtsd2si m32 source', 'vcvtsd2si', [Op(EAX), Op(DWordPtr(ridRCX))]);
end;

procedure CheckPublicApiPhase3;
var
  B: TAsmBuilder;
  Actual: TBytes;
begin
  B := TAsmBuilder.New;
  try
    B.Vextractps(R10D, XMM11, 2).Vpinsrw(XMM8, XMM9, R10D, 5).Vpextrw(R9D, XMM8, 5).Vpmovmskb(EAX, XMM8).Vcvtsi2ss(XMM0, XMM1, ECX).Vcvttss2si(EAX, XMM0);
    Actual := B.Build;
    if SameBytes(Actual, [$C4, $43, $79, $17, $DA, $02, $C4, $41, $31, $C4, $C2, $05, $C4, $41, $79, $C5, $C8, $05, $C4, $C1, $79, $D7, $C0, $C5, $F2, $2A, $C1, $C5, $FA, $2C, $C0]) then
    begin
      Inc(GPass);
      Writeln('PASS phase3 GPR/AVX public API');
      Writeln('  BYTES    ', BytesText(Actual));
    end
    else
    begin
      Inc(GFail);
      Writeln('FAIL phase3 GPR/AVX public API');
      Writeln('  ACTUAL   ', BytesText(Actual));
      Writeln('  EXPECTED C4 43 79 17 DA 02 C4 41 31 C4 C2 05 C4 41 79 C5 C8 05 C4 C1 79 D7 C0 C5 F2 2A C1 C5 FA 2C C0');
    end;
  finally
    B.Free;
  end;
end;

procedure CheckRuntimePhase3;
var
  Status: TAvxCpuStatus;
  B: TAsmBuilder;
  Exe: TExecutableCode;
  Actual: TBytes;
  R: UInt64;

  procedure Run1(const Name: string; const ExpectedCode: array of Byte; Arg, Expected: UInt64);
  begin
    Actual := B.Build;
    if not SameBytes(Actual, ExpectedCode) then
    begin
      Inc(GFail);
      Writeln('FAIL ', Name, ' kernel encoding');
      Writeln('  ACTUAL   ', BytesText(Actual));
      Writeln('  EXPECTED ', ExpectedText(ExpectedCode));
      Exit;
    end;
    Exe := TExecutableCode.Create(Actual);
    try
      R := Exe.Run(Arg);
    finally
      Exe.Free;
    end;
    if R = Expected then begin Inc(GPass); Writeln('PASS ', Name); end
    else begin Inc(GFail); Writeln('FAIL ', Name, ': ', IntToHex(R, 16), ' expected=', IntToHex(Expected, 16)); end;
  end;

begin
  Status := TAvxCpuFeatures.Query;
  if not Status.AvxUsable then
  begin
    Inc(GSkip);
    Writeln('SKIP AVX runtime phase3: AVX execution is not available');
    Exit;
  end;

  B := TAsmBuilder.New;
  try
    B.Vmovd(XMM0, ECX).Vpinsrw(XMM0, XMM0, EDX, 1).Vpextrw(EAX, XMM0, 1).Ret;
    Actual := B.Build;
    if not SameBytes(Actual, [$C5, $F9, $6E, $C1, $C5, $F9, $C4, $C2, $01, $C5, $F9, $C5, $C0, $01, $C3]) then
    begin
      Inc(GFail);
      Writeln('FAIL AVX runtime vpinsrw/vpextrw kernel encoding');
    end
    else
    begin
      Exe := TExecutableCode.Create(Actual);
      try
        R := Exe.Run($11223344, $AABBCCDD);
      finally
        Exe.Free;
      end;
      if R = $CCDD then begin Inc(GPass); Writeln('PASS AVX runtime vpinsrw/vpextrw roundtrip'); end
      else begin Inc(GFail); Writeln('FAIL AVX runtime vpinsrw/vpextrw roundtrip: ', IntToHex(R, 16)); end;
    end;
  finally
    B.Free;
  end;

  B := TAsmBuilder.New;
  try
    B.Vmovd(XMM0, ECX).Vextractps(EAX, XMM0, 0).Ret;
    Run1('AVX runtime vextractps', [$C5, $F9, $6E, $C1, $C4, $E3, $79, $17, $C0, $00, $C3], $89ABCDEF, $89ABCDEF);
  finally
    B.Free;
  end;

  B := TAsmBuilder.New;
  try
    B.Vmovd(XMM0, ECX).Vpmovmskb(EAX, XMM0).Ret;
    Run1('AVX runtime vpmovmskb', [$C5, $F9, $6E, $C1, $C5, $F9, $D7, $C0, $C3], $80808080, $0F);
  finally
    B.Free;
  end;

  B := TAsmBuilder.New;
  try
    B.Vmovd(XMM0, ECX).Vmovmskps(EAX, XMM0).Ret;
    Run1('AVX runtime vmovmskps', [$C5, $F9, $6E, $C1, $C5, $F8, $50, $C0, $C3], $80000000, 1);
  finally
    B.Free;
  end;

  B := TAsmBuilder.New;
  try
    B.Vmovq(XMM0, RCX).Vmovmskpd(EAX, XMM0).Ret;
    Run1('AVX runtime vmovmskpd', [$C4, $E1, $F9, $6E, $C1, $C5, $F9, $50, $C0, $C3], $8000000000000000, 1);
  finally
    B.Free;
  end;

  B := TAsmBuilder.New;
  try
    B.Vcvtsi2ss(XMM0, XMM0, ECX).Vcvtss2si(EAX, XMM0).Ret;
    Run1('AVX runtime vcvtsi2ss/vcvtss2si', [$C5, $FA, $2A, $C1, $C5, $FA, $2D, $C0, $C3], 1234567, 1234567);
  finally
    B.Free;
  end;

  B := TAsmBuilder.New;
  try
    B.Vcvtsi2sd(XMM0, XMM0, RCX).Vcvttsd2si(RAX, XMM0).Ret;
    Run1('AVX runtime vcvtsi2sd/vcvttsd2si', [$C4, $E1, $FB, $2A, $C1, $C4, $E1, $FB, $2C, $C0, $C3], 1234567890123, 1234567890123);
  finally
    B.Free;
  end;
end;


procedure CheckPhase4Encodings;
begin
  CheckEnc('vmaskmovps xmm8,xmm9,[r12+32]', 'vmaskmovps', [Op(XMM8), Op(XMM9), Op(XmmWordPtr(ridR12, 32))], [$C4, $42, $31, $2C, $44, $24, $20]);
  CheckEnc('vmaskmovps [r12+32],xmm9,xmm10', 'vmaskmovps', [Op(XmmWordPtr(ridR12, 32)), Op(XMM9), Op(XMM10)], [$C4, $42, $31, $2E, $54, $24, $20]);
  CheckEnc('vmaskmovpd ymm8,ymm9,[r12+32]', 'vmaskmovpd', [Op(YMM8), Op(YMM9), Op(YmmWordPtr(ridR12, 32))], [$C4, $42, $35, $2D, $44, $24, $20]);
  CheckEnc('vmaskmovpd [r12+32],ymm9,ymm10', 'vmaskmovpd', [Op(YmmWordPtr(ridR12, 32)), Op(YMM9), Op(YMM10)], [$C4, $42, $35, $2F, $54, $24, $20]);
  CheckEnc('vpmaskmovd xmm8,xmm9,[r12+32]', 'vpmaskmovd', [Op(XMM8), Op(XMM9), Op(XmmWordPtr(ridR12, 32))], [$C4, $42, $31, $8C, $44, $24, $20]);
  CheckEnc('vpmaskmovd [r12+32],xmm9,xmm10', 'vpmaskmovd', [Op(XmmWordPtr(ridR12, 32)), Op(XMM9), Op(XMM10)], [$C4, $42, $31, $8E, $54, $24, $20]);
  CheckEnc('vpmaskmovd ymm8,ymm9,[r12+32]', 'vpmaskmovd', [Op(YMM8), Op(YMM9), Op(YmmWordPtr(ridR12, 32))], [$C4, $42, $35, $8C, $44, $24, $20]);
  CheckEnc('vpmaskmovd [r12+32],ymm9,ymm10', 'vpmaskmovd', [Op(YmmWordPtr(ridR12, 32)), Op(YMM9), Op(YMM10)], [$C4, $42, $35, $8E, $54, $24, $20]);
  CheckEnc('vpmaskmovq xmm8,xmm9,[r12+32]', 'vpmaskmovq', [Op(XMM8), Op(XMM9), Op(XmmWordPtr(ridR12, 32))], [$C4, $42, $B1, $8C, $44, $24, $20]);
  CheckEnc('vpmaskmovq [r12+32],xmm9,xmm10', 'vpmaskmovq', [Op(XmmWordPtr(ridR12, 32)), Op(XMM9), Op(XMM10)], [$C4, $42, $B1, $8E, $54, $24, $20]);
  CheckEnc('vpmaskmovq ymm8,ymm9,[r12+32]', 'vpmaskmovq', [Op(YMM8), Op(YMM9), Op(YmmWordPtr(ridR12, 32))], [$C4, $42, $B5, $8C, $44, $24, $20]);
  CheckEnc('vpmaskmovq [r12+32],ymm9,ymm10', 'vpmaskmovq', [Op(YmmWordPtr(ridR12, 32)), Op(YMM9), Op(YMM10)], [$C4, $42, $B5, $8E, $54, $24, $20]);
  CheckReject('reject vmaskmovps mismatched mask width', 'vmaskmovps', [Op(YMM0), Op(XMM1), Op(YmmWordPtr(ridRCX))]);
  CheckReject('reject vmaskmovpd wrong memory width', 'vmaskmovpd', [Op(YMM0), Op(YMM1), Op(XmmWordPtr(ridRCX))]);
  CheckReject('reject vpmaskmovd mismatched data width', 'vpmaskmovd', [Op(YmmWordPtr(ridRCX)), Op(YMM1), Op(XMM2)]);
  CheckReject('reject vpmaskmovq wrong memory width', 'vpmaskmovq', [Op(XMM0), Op(XMM1), Op(YmmWordPtr(ridRCX))]);
end;

procedure CheckPublicApiPhase4;
var
  B: TAsmBuilder;
  Actual: TBytes;
begin
  B := TAsmBuilder.New;
  try
    B.Vmaskmovps(XMM8, XMM9, XmmWordPtr(ridR12, 32)).Vmaskmovpd(YmmWordPtr(ridR12, 32), YMM9, YMM10).Vpmaskmovd(XMM8, XMM9, XmmWordPtr(ridR12, 32)).Vpmaskmovq(YmmWordPtr(ridR12, 32), YMM9, YMM10);
    Actual := B.Build;
    if SameBytes(Actual, [$C4, $42, $31, $2C, $44, $24, $20, $C4, $42, $35, $2F, $54, $24, $20, $C4, $42, $31, $8C, $44, $24, $20, $C4, $42, $B5, $8E, $54, $24, $20]) then
    begin
      Inc(GPass);
      Writeln('PASS phase4 masked-memory public API');
      Writeln('  BYTES    ', BytesText(Actual));
    end
    else
    begin
      Inc(GFail);
      Writeln('FAIL phase4 masked-memory public API');
      Writeln('  ACTUAL   ', BytesText(Actual));
      Writeln('  EXPECTED C4 42 31 2C 44 24 20 C4 42 35 2F 54 24 20 C4 42 31 8C 44 24 20 C4 42 B5 8E 54 24 20');
    end;
  finally
    B.Free;
  end;
end;

procedure CheckRuntimePhase4;
type
  TCardinals = array[0..3] of Cardinal;
var
  Status: TAvxCpuStatus;
  Data: TCardinals;
  B: TAsmBuilder;
  Exe: TExecutableCode;
  Actual: TBytes;
begin
  Status := TAvxCpuFeatures.Query;
  if not Status.AvxUsable then
  begin
    Inc(GSkip);
    Writeln('SKIP AVX runtime phase4: AVX execution is not available');
    Exit;
  end;

  FillChar(Data, SizeOf(Data), 0);
  B := TAsmBuilder.New;
  try
    B.Vmovd(XMM0, EDX).Vmovd(XMM1, R8D).Vmaskmovps(XmmWordPtr(ridRCX), XMM1, XMM0).Ret;
    Actual := B.Build;
    if not SameBytes(Actual, [$C5, $F9, $6E, $C2, $C4, $C1, $79, $6E, $C8, $C4, $E2, $71, $2E, $01, $C3]) then
    begin
      Inc(GFail);
      Writeln('FAIL AVX runtime vmaskmovps store kernel encoding');
    end
    else
    begin
      Exe := TExecutableCode.Create(Actual);
      try
        Exe.Run(UInt64(NativeUInt(@Data[0])), $11223344, $80000000);
      finally
        Exe.Free;
      end;
      if Data[0] = $11223344 then begin Inc(GPass); Writeln('PASS AVX runtime vmaskmovps masked store'); end
      else begin Inc(GFail); Writeln('FAIL AVX runtime vmaskmovps masked store: ', IntToHex(Data[0], 8)); end;
    end;
  finally
    B.Free;
  end;

  if not Status.Avx2Usable then
  begin
    Inc(GSkip);
    Writeln('SKIP AVX2 runtime phase4: AVX2 execution is not available');
    Exit;
  end;

  FillChar(Data, SizeOf(Data), 0);
  B := TAsmBuilder.New;
  try
    B.Vmovd(XMM0, EDX).Vmovd(XMM1, R8D).Vpmaskmovd(XmmWordPtr(ridRCX), XMM1, XMM0).Ret;
    Actual := B.Build;
    if not SameBytes(Actual, [$C5, $F9, $6E, $C2, $C4, $C1, $79, $6E, $C8, $C4, $E2, $71, $8E, $01, $C3]) then
    begin
      Inc(GFail);
      Writeln('FAIL AVX2 runtime vpmaskmovd store kernel encoding');
    end
    else
    begin
      Exe := TExecutableCode.Create(Actual);
      try
        Exe.Run(UInt64(NativeUInt(@Data[0])), $55667788, $80000000);
      finally
        Exe.Free;
      end;
      if Data[0] = $55667788 then begin Inc(GPass); Writeln('PASS AVX2 runtime vpmaskmovd masked store'); end
      else begin Inc(GFail); Writeln('FAIL AVX2 runtime vpmaskmovd masked store: ', IntToHex(Data[0], 8)); end;
    end;
  finally
    B.Free;
  end;
end;


procedure CheckPhase5Encodings;
begin
  CheckEnc('vgatherdpd xmm8,[r12+xmm13*4+32],xmm9', 'vgatherdpd', [Op(XMM8), Op(Vm32x(ridR12, XMM13, s4, 32)), Op(XMM9)], [$C4, $02, $B1, $92, $44, $AC, $20]);
  CheckEnc('vgatherdpd ymm10,[r13+xmm14*8+64],ymm11', 'vgatherdpd', [Op(YMM10), Op(Vm32x(ridR13, XMM14, s8, 64)), Op(YMM11)], [$C4, $02, $A5, $92, $54, $F5, $40]);
  CheckEnc('vgatherdps xmm8,[r12+xmm13*4+32],xmm9', 'vgatherdps', [Op(XMM8), Op(Vm32x(ridR12, XMM13, s4, 32)), Op(XMM9)], [$C4, $02, $31, $92, $44, $AC, $20]);
  CheckEnc('vgatherdps ymm10,[r13+ymm14*8+64],ymm11', 'vgatherdps', [Op(YMM10), Op(Vm32y(ridR13, YMM14, s8, 64)), Op(YMM11)], [$C4, $02, $25, $92, $54, $F5, $40]);
  CheckEnc('vgatherqpd xmm8,[r12+xmm13*4+32],xmm9', 'vgatherqpd', [Op(XMM8), Op(Vm64x(ridR12, XMM13, s4, 32)), Op(XMM9)], [$C4, $02, $B1, $93, $44, $AC, $20]);
  CheckEnc('vgatherqpd ymm10,[r13+ymm14*8+64],ymm11', 'vgatherqpd', [Op(YMM10), Op(Vm64y(ridR13, YMM14, s8, 64)), Op(YMM11)], [$C4, $02, $A5, $93, $54, $F5, $40]);
  CheckEnc('vgatherqps xmm8,[r12+xmm13*4+32],xmm9', 'vgatherqps', [Op(XMM8), Op(Vm64x(ridR12, XMM13, s4, 32)), Op(XMM9)], [$C4, $02, $31, $93, $44, $AC, $20]);
  CheckEnc('vgatherqps xmm10,[r13+ymm14*8+64],xmm11', 'vgatherqps', [Op(XMM10), Op(Vm64y(ridR13, YMM14, s8, 64)), Op(XMM11)], [$C4, $02, $25, $93, $54, $F5, $40]);
  CheckEnc('vpgatherdd xmm8,[r12+xmm13*4+32],xmm9', 'vpgatherdd', [Op(XMM8), Op(Vm32x(ridR12, XMM13, s4, 32)), Op(XMM9)], [$C4, $02, $31, $90, $44, $AC, $20]);
  CheckEnc('vpgatherdd ymm10,[r13+ymm14*8+64],ymm11', 'vpgatherdd', [Op(YMM10), Op(Vm32y(ridR13, YMM14, s8, 64)), Op(YMM11)], [$C4, $02, $25, $90, $54, $F5, $40]);
  CheckEnc('vpgatherdq xmm8,[r12+xmm13*4+32],xmm9', 'vpgatherdq', [Op(XMM8), Op(Vm32x(ridR12, XMM13, s4, 32)), Op(XMM9)], [$C4, $02, $B1, $90, $44, $AC, $20]);
  CheckEnc('vpgatherdq ymm10,[r13+xmm14*8+64],ymm11', 'vpgatherdq', [Op(YMM10), Op(Vm32x(ridR13, XMM14, s8, 64)), Op(YMM11)], [$C4, $02, $A5, $90, $54, $F5, $40]);
  CheckEnc('vpgatherqd xmm8,[r12+xmm13*4+32],xmm9', 'vpgatherqd', [Op(XMM8), Op(Vm64x(ridR12, XMM13, s4, 32)), Op(XMM9)], [$C4, $02, $31, $91, $44, $AC, $20]);
  CheckEnc('vpgatherqd xmm10,[r13+ymm14*8+64],xmm11', 'vpgatherqd', [Op(XMM10), Op(Vm64y(ridR13, YMM14, s8, 64)), Op(XMM11)], [$C4, $02, $25, $91, $54, $F5, $40]);
  CheckEnc('vpgatherqq xmm8,[r12+xmm13*4+32],xmm9', 'vpgatherqq', [Op(XMM8), Op(Vm64x(ridR12, XMM13, s4, 32)), Op(XMM9)], [$C4, $02, $B1, $91, $44, $AC, $20]);
  CheckEnc('vpgatherqq ymm10,[r13+ymm14*8+64],ymm11', 'vpgatherqq', [Op(YMM10), Op(Vm64y(ridR13, YMM14, s8, 64)), Op(YMM11)], [$C4, $02, $A5, $91, $54, $F5, $40]);
  CheckEnc('vpgatherdd ymm0,[rcx+ymm4*4+16],ymm2', 'vpgatherdd', [Op(YMM0), Op(Vm32y(ridRCX, YMM4, s4, 16)), Op(YMM2)], [$C4, $E2, $6D, $90, $44, $A1, $10]);
  CheckEnc('vpgatherdd ymm0,[r13+ymm4*4],ymm2', 'vpgatherdd', [Op(YMM0), Op(Vm32y(ridR13, YMM4, s4, 0)), Op(YMM2)], [$C4, $C2, $6D, $90, $44, $A5, $00]);
  CheckEnc('vpgatherdd ymm0,[ymm4*4+12345678],ymm2', 'vpgatherdd', [Op(YMM0), Op(Vm32yNoBase(YMM4, s4, $12345678)), Op(YMM2)], [$C4, $E2, $6D, $90, $04, $A5, $78, $56, $34, $12]);
  CheckReject('reject gather regular memory operand', 'vpgatherdd', [Op(YMM0), Op(YmmWordPtr(ridRCX)), Op(YMM2)]);
  CheckReject('reject gather wrong VSIB index vector width', 'vpgatherdd', [Op(YMM0), Op(Vm32x(ridRCX, XMM1, s4)), Op(YMM2)]);
  CheckReject('reject gather wrong VSIB index element width', 'vpgatherdd', [Op(YMM0), Op(Vm64y(ridRCX, YMM1, s4)), Op(YMM2)]);
  CheckReject('reject gather destination/index alias', 'vpgatherdd', [Op(YMM1), Op(Vm32y(ridRCX, YMM1, s4)), Op(YMM2)]);
  CheckReject('reject gather destination/mask alias', 'vpgatherdd', [Op(YMM0), Op(Vm32y(ridRCX, YMM1, s4)), Op(YMM0)]);
  CheckReject('reject gather mask/index alias', 'vpgatherdd', [Op(YMM0), Op(Vm32y(ridRCX, YMM1, s4)), Op(YMM1)]);
end;

procedure CheckPublicApiPhase5;
var
  B: TAsmBuilder;
  Actual: TBytes;
begin
  B := TAsmBuilder.New;
  try
    B.Vgatherdps(YMM8, Vm32y(ridR12, YMM13, s4, 32), YMM9).Vpgatherdq(YMM10, Vm32x(ridR13, XMM14, s8, 64), YMM11).Vgatherqps(XMM8, Vm64y(ridR12, YMM13, s4, 32), XMM9).Vpgatherqq(YMM10, Vm64y(ridR13, YMM14, s8, 64), YMM11);
    Actual := B.Build;
    if SameBytes(Actual, [$C4, $02, $35, $92, $44, $AC, $20, $C4, $02, $A5, $90, $54, $F5, $40, $C4, $02, $35, $93, $44, $AC, $20, $C4, $02, $A5, $91, $54, $F5, $40]) then
    begin
      Inc(GPass);
      Writeln('PASS phase5 VSIB/gather public API');
      Writeln('  BYTES    ', BytesText(Actual));
    end
    else
    begin
      Inc(GFail);
      Writeln('FAIL phase5 VSIB/gather public API');
      Writeln('  ACTUAL   ', BytesText(Actual));
      Writeln('  EXPECTED C4 02 35 92 44 AC 20 C4 02 A5 90 54 F5 40 C4 02 35 93 44 AC 20 C4 02 A5 91 54 F5 40');
    end;
  finally
    B.Free;
  end;
end;

procedure CheckRuntimePhase5;
type
  TGatherData = packed record
    Source: array[0..15] of Cardinal;
    Indices: array[0..7] of Integer;
    Output: array[0..7] of Cardinal;
  end;
var
  Status: TAvxCpuStatus;
  Data: TGatherData;
  B: TAsmBuilder;
  Exe: TExecutableCode;
  Actual: TBytes;
  I: Integer;
  Ok: Boolean;
begin
  Status := TAvxCpuFeatures.Query;
  if not Status.Avx2Usable then
  begin
    Inc(GSkip);
    Writeln('SKIP AVX2 runtime phase5 gather: AVX2 execution is not available');
    Exit;
  end;

  FillChar(Data, SizeOf(Data), 0);
  for I := 0 to 15 do Data.Source[I] := 1000 + Cardinal(I * 10);
  Data.Indices[0] := 7;
  Data.Indices[1] := 0;
  Data.Indices[2] := 14;
  Data.Indices[3] := 3;
  Data.Indices[4] := 9;
  Data.Indices[5] := 2;
  Data.Indices[6] := 15;
  Data.Indices[7] := 5;

  B := TAsmBuilder.New;
  try
    B.Vmovdqu(YMM1, YmmWordPtr(ridRCX, 64)).Vpcmpeqd(YMM2, YMM2, YMM2).Vpgatherdd(YMM0, Vm32y(ridRCX, YMM1, s4), YMM2).Vmovdqu(YmmWordPtr(ridRCX, 96), YMM0).Vzeroupper.Ret;
    Actual := B.Build;
    if not SameBytes(Actual, [$C5, $FE, $6F, $49, $40, $C5, $ED, $76, $D2, $C4, $E2, $6D, $90, $04, $89, $C5, $FE, $7F, $41, $60, $C5, $F8, $77, $C3]) then
    begin
      Inc(GFail);
      Writeln('FAIL AVX2 runtime vpgatherdd kernel encoding');
      Writeln('  ACTUAL   ', BytesText(Actual));
      Writeln('  EXPECTED C5 FE 6F 49 40 C5 ED 76 D2 C4 E2 6D 90 04 89 C5 FE 7F 41 60 C5 F8 77 C3');
      Exit;
    end;
    Exe := TExecutableCode.Create(Actual);
    try
      Exe.Run(UInt64(NativeUInt(@Data)));
    finally
      Exe.Free;
    end;
  finally
    B.Free;
  end;

  Ok := True;
  for I := 0 to 7 do
    if Data.Output[I] <> Data.Source[Data.Indices[I]] then Ok := False;
  if Ok then begin Inc(GPass); Writeln('PASS AVX2 runtime vpgatherdd VSIB gather'); end
  else begin Inc(GFail); Writeln('FAIL AVX2 runtime vpgatherdd VSIB gather'); end;
end;


procedure CheckReleaseHardening;
begin
  CheckEnc('vaddps xmm8,xmm1,xmm2 canonical VEX2 R-only', 'vaddps', [Op(XMM8), Op(XMM1), Op(XMM2)], [$C5, $70, $58, $C2]);
  CheckEnc('vaddps xmm0,xmm1,xmm8 canonical VEX3 B', 'vaddps', [Op(XMM0), Op(XMM1), Op(XMM8)], [$C4, $C1, $70, $58, $C0]);
  CheckEnc('vmovaps xmm0,[rcx] unspecified memory load', 'vmovaps', [Op(XMM0), Op(TMemory.Create(ridRCX))], [$C5, $F8, $28, $01]);
  CheckEnc('vmovaps [rcx],xmm0 unspecified memory store', 'vmovaps', [Op(TMemory.Create(ridRCX)), Op(XMM0)], [$C5, $F8, $29, $01]);
  CheckEnc('vbroadcastss ymm0,[rcx+32] unspecified memory', 'vbroadcastss', [Op(YMM0), Op(TMemory.Create(ridRCX, 32))], [$C4, $E2, $7D, $18, $41, $20]);
end;

procedure CheckPublicApiReleaseHardening;
var
  B: TAsmBuilder;
  Actual: TBytes;
begin
  B := TAsmBuilder.New;
  try
    B.Vmovaps(XMM0, TMemory.Create(ridRCX)).Vmovaps(TMemory.Create(ridRDX), XMM0).Vbroadcastss(YMM0, TMemory.Create(ridR8, 32));
    Actual := B.Build;
    if SameBytes(Actual, [$C5, $F8, $28, $01, $C5, $F8, $29, $02, $C4, $C2, $7D, $18, $40, $20]) then
    begin
      Inc(GPass);
      Writeln('PASS release hardening public API');
      Writeln('  BYTES    ', BytesText(Actual));
    end
    else
    begin
      Inc(GFail);
      Writeln('FAIL release hardening public API');
      Writeln('  ACTUAL   ', BytesText(Actual));
      Writeln('  EXPECTED C5 F8 28 01 C5 F8 29 02 C4 C2 7D 18 40 20');
    end;
  finally
    B.Free;
  end;
end;

procedure CheckPhase6Encodings;
begin
  CheckEnc('vmovhlps xmm0,xmm1,xmm2', 'vmovhlps', [Op(XMM0), Op(XMM1), Op(XMM2)], [$C5, $F0, $12, $C2]);
  CheckEnc('vmovlhps xmm8,xmm9,xmm10', 'vmovlhps', [Op(XMM8), Op(XMM9), Op(XMM10)], [$C4, $41, $30, $16, $C2]);
  CheckEnc('vmovhpd [r12+16],xmm9', 'vmovhpd', [Op(QWordPtr(ridR12, 16)), Op(XMM9)], [$C4, $41, $79, $17, $4C, $24, $10]);
  CheckEnc('vmovhpd xmm10,xmm11,[r13+24]', 'vmovhpd', [Op(XMM10), Op(XMM11), Op(QWordPtr(ridR13, 24))], [$C4, $41, $21, $16, $55, $18]);
  CheckEnc('vmovhps [r14+32],xmm12', 'vmovhps', [Op(QWordPtr(ridR14, 32)), Op(XMM12)], [$C4, $41, $78, $17, $66, $20]);
  CheckEnc('vmovhps xmm13,xmm14,[r15+40]', 'vmovhps', [Op(XMM13), Op(XMM14), Op(QWordPtr(ridR15, 40))], [$C4, $41, $08, $16, $6F, $28]);
  CheckEnc('vmovlpd [r14+32],xmm12', 'vmovlpd', [Op(QWordPtr(ridR14, 32)), Op(XMM12)], [$C4, $41, $79, $13, $66, $20]);
  CheckEnc('vmovlpd xmm13,xmm14,[r15+40]', 'vmovlpd', [Op(XMM13), Op(XMM14), Op(QWordPtr(ridR15, 40))], [$C4, $41, $09, $12, $6F, $28]);
  CheckEnc('vmovlps [r12+48],xmm8', 'vmovlps', [Op(QWordPtr(ridR12, 48)), Op(XMM8)], [$C4, $41, $78, $13, $44, $24, $30]);
  CheckEnc('vmovlps xmm9,xmm10,[r13+56]', 'vmovlps', [Op(XMM9), Op(XMM10), Op(QWordPtr(ridR13, 56))], [$C4, $41, $28, $12, $4D, $38]);
  CheckEnc('vmovntdqa xmm8,[r12+32]', 'vmovntdqa', [Op(XMM8), Op(XmmWordPtr(ridR12, 32))], [$C4, $42, $79, $2A, $44, $24, $20]);
  CheckEnc('vmovntdqa ymm9,[r13+64]', 'vmovntdqa', [Op(YMM9), Op(YmmWordPtr(ridR13, 64))], [$C4, $42, $7D, $2A, $4D, $40]);
  CheckReject('reject vmovhlps YMM destination', 'vmovhlps', [Op(YMM0), Op(XMM1), Op(XMM2)]);
  CheckReject('reject vmovhpd m32 load', 'vmovhpd', [Op(XMM0), Op(XMM1), Op(DWordPtr(ridRCX))]);
  CheckReject('reject vmovlps m128 store', 'vmovlps', [Op(XmmWordPtr(ridRCX)), Op(XMM0)]);
  CheckReject('reject vmovntdqa register source', 'vmovntdqa', [Op(XMM0), Op(XMM1)]);
  CheckReject('reject vmovntdqa XMM/m256 mismatch', 'vmovntdqa', [Op(XMM0), Op(YmmWordPtr(ridRCX))]);
end;

procedure CheckPublicApiPhase6;
var
  B: TAsmBuilder;
  Actual: TBytes;
begin
  B := TAsmBuilder.New;
  try
    B.Vmovhlps(XMM0, XMM1, XMM2).Vmovhpd(QWordPtr(ridR12, 16), XMM9).Vmovlps(XMM9, XMM10, QWordPtr(ridR13, 56)).Vmovntdqa(YMM9, YmmWordPtr(ridR13, 64));
    Actual := B.Build;
    if SameBytes(Actual, [$C5, $F0, $12, $C2, $C4, $41, $79, $17, $4C, $24, $10, $C4, $41, $28, $12, $4D, $38, $C4, $42, $7D, $2A, $4D, $40]) then
    begin
      Inc(GPass);
      Writeln('PASS phase6 remaining safe VEX public API');
      Writeln('  BYTES    ', BytesText(Actual));
    end
    else
    begin
      Inc(GFail);
      Writeln('FAIL phase6 remaining safe VEX public API');
      Writeln('  ACTUAL   ', BytesText(Actual));
      Writeln('  EXPECTED C5 F0 12 C2 C4 41 79 17 4C 24 10 C4 41 28 12 4D 38 C4 42 7D 2A 4D 40');
    end;
  finally
    B.Free;
  end;
end;

procedure CheckRuntimePhase6;
var
  Status: TAvxCpuStatus;
  B: TAsmBuilder;
  Exe: TExecutableCode;
  Actual: TBytes;
  R: UInt64;
begin
  Status := TAvxCpuFeatures.Query;
  if not Status.AvxUsable then
  begin
    Inc(GSkip);
    Writeln('SKIP AVX runtime phase6: AVX execution is not available');
    Exit;
  end;

  B := TAsmBuilder.New;
  try
    B.Vmovq(XMM0, RCX).Vmovq(XMM1, RDX).Vmovlhps(XMM0, XMM0, XMM1).Vpextrq(RAX, XMM0, 1).Ret;
    Actual := B.Build;
    if not SameBytes(Actual, [$C4, $E1, $F9, $6E, $C1, $C4, $E1, $F9, $6E, $CA, $C5, $F8, $16, $C1, $C4, $E3, $F9, $16, $C0, $01, $C3]) then
    begin
      Inc(GFail);
      Writeln('FAIL AVX runtime vmovlhps kernel encoding');
      Writeln('  ACTUAL   ', BytesText(Actual));
      Exit;
    end;
    Exe := TExecutableCode.Create(Actual);
    try
      R := Exe.Run($1122334455667788, $AABBCCDDEEFF0011);
    finally
      Exe.Free;
    end;
  finally
    B.Free;
  end;
  if R = $AABBCCDDEEFF0011 then begin Inc(GPass); Writeln('PASS AVX runtime vmovlhps lane move'); end
  else begin Inc(GFail); Writeln('FAIL AVX runtime vmovlhps lane move: ', IntToHex(R, 16)); end;
end;

procedure CheckPhase7Encodings;
begin
  CheckEnc('vmovss xmm0,xmm1,xmm2 canonical RVM', 'vmovss', [Op(XMM0), Op(XMM1), Op(XMM2)], [$C5, $F2, $10, $C2]);
  CheckEnc('vmovss xmm8,xmm9,xmm10 canonical RVM', 'vmovss', [Op(XMM8), Op(XMM9), Op(XMM10)], [$C4, $41, $32, $10, $C2]);
  CheckEnc('vmovss xmm0,[rcx+4]', 'vmovss', [Op(XMM0), Op(DWordPtr(ridRCX, 4))], [$C5, $FA, $10, $41, $04]);
  CheckEnc('vmovss [r12+8],xmm9', 'vmovss', [Op(DWordPtr(ridR12, 8)), Op(XMM9)], [$C4, $41, $7A, $11, $4C, $24, $08]);
  CheckEnc('vmovsd xmm0,xmm1,xmm2 canonical RVM', 'vmovsd', [Op(XMM0), Op(XMM1), Op(XMM2)], [$C5, $F3, $10, $C2]);
  CheckEnc('vmovsd xmm8,xmm9,xmm10 canonical RVM', 'vmovsd', [Op(XMM8), Op(XMM9), Op(XMM10)], [$C4, $41, $33, $10, $C2]);
  CheckEnc('vmovsd xmm0,[rcx+8]', 'vmovsd', [Op(XMM0), Op(QWordPtr(ridRCX, 8))], [$C5, $FB, $10, $41, $08]);
  CheckEnc('vmovsd [r12+16],xmm9', 'vmovsd', [Op(QWordPtr(ridR12, 16)), Op(XMM9)], [$C4, $41, $7B, $11, $4C, $24, $10]);
  CheckReject('reject vmovss YMM destination', 'vmovss', [Op(YMM0), Op(XMM1), Op(XMM2)]);
  CheckReject('reject vmovsd m32 load', 'vmovsd', [Op(XMM0), Op(DWordPtr(ridRCX))]);
  CheckReject('reject vmovss m64 store', 'vmovss', [Op(QWordPtr(ridRCX)), Op(XMM0)]);
  CheckReject('reject vmovsd two-register form', 'vmovsd', [Op(XMM0), Op(XMM1)]);
end;

procedure CheckPublicApiPhase7;
var
  B: TAsmBuilder;
  Actual: TBytes;
begin
  B := TAsmBuilder.New;
  try
    B.Vmovss(XMM0, XMM1, XMM2).Vmovss(DWordPtr(ridR12, 8), XMM9).Vmovsd(XMM8, XMM9, XMM10).Vmovsd(XMM0, QWordPtr(ridRCX, 8));
    Actual := B.Build;
    if SameBytes(Actual, [$C5, $F2, $10, $C2, $C4, $41, $7A, $11, $4C, $24, $08, $C4, $41, $33, $10, $C2, $C5, $FB, $10, $41, $08]) then
    begin
      Inc(GPass);
      Writeln('PASS phase7 scalar move public API');
      Writeln('  BYTES    ', BytesText(Actual));
    end
    else
    begin
      Inc(GFail);
      Writeln('FAIL phase7 scalar move public API');
      Writeln('  ACTUAL   ', BytesText(Actual));
      Writeln('  EXPECTED C5 F2 10 C2 C4 41 7A 11 4C 24 08 C4 41 33 10 C2 C5 FB 10 41 08');
    end;
  finally
    B.Free;
  end;
end;

procedure CheckRuntimePhase7;
var
  Status: TAvxCpuStatus;
  B: TAsmBuilder;
  Exe: TExecutableCode;
  Actual: TBytes;
  R: UInt64;
begin
  Status := TAvxCpuFeatures.Query;
  if not Status.AvxUsable then
  begin
    Inc(GSkip);
    Writeln('SKIP AVX runtime phase7: AVX execution is not available');
    Exit;
  end;

  B := TAsmBuilder.New;
  try
    B.Vmovq(XMM1, RCX).Vmovq(XMM2, RDX).Vmovss(XMM0, XMM1, XMM2).Vpextrq(RAX, XMM0, 0).Ret;
    Actual := B.Build;
    if not SameBytes(Actual, [$C4, $E1, $F9, $6E, $C9, $C4, $E1, $F9, $6E, $D2, $C5, $F2, $10, $C2, $C4, $E3, $F9, $16, $C0, $00, $C3]) then
    begin
      Inc(GFail);
      Writeln('FAIL AVX runtime vmovss kernel encoding');
    end
    else
    begin
      Exe := TExecutableCode.Create(Actual);
      try
        R := Exe.Run($1122334455667788, $AABBCCDDEEFF0011);
      finally
        Exe.Free;
      end;
      if R = $11223344EEFF0011 then begin Inc(GPass); Writeln('PASS AVX runtime vmovss merge'); end
      else begin Inc(GFail); Writeln('FAIL AVX runtime vmovss merge: ', IntToHex(R, 16)); end;
    end;
  finally
    B.Free;
  end;

  B := TAsmBuilder.New;
  try
    B.Vmovq(XMM1, RCX).Vpinsrq(XMM1, XMM1, RDX, 1).Vmovq(XMM2, R8).Vmovsd(XMM0, XMM1, XMM2).Vpextrq(RAX, XMM0, 1).Ret;
    Actual := B.Build;
    if not SameBytes(Actual, [$C4, $E1, $F9, $6E, $C9, $C4, $E3, $F1, $22, $CA, $01, $C4, $C1, $F9, $6E, $D0, $C5, $F3, $10, $C2, $C4, $E3, $F9, $16, $C0, $01, $C3]) then
    begin
      Inc(GFail);
      Writeln('FAIL AVX runtime vmovsd kernel encoding');
    end
    else
    begin
      Exe := TExecutableCode.Create(Actual);
      try
        R := Exe.Run($1122334455667788, $AABBCCDDEEFF0011, $0123456789ABCDEF);
      finally
        Exe.Free;
      end;
      if R = $AABBCCDDEEFF0011 then begin Inc(GPass); Writeln('PASS AVX runtime vmovsd merge'); end
      else begin Inc(GFail); Writeln('FAIL AVX runtime vmovsd merge: ', IntToHex(R, 16)); end;
    end;
  finally
    B.Free;
  end;
end;

procedure CheckPhase8Encodings;
begin
  CheckEnc('vldmxcsr [rcx] unspecified memory', 'vldmxcsr', [Op(TMemory.Create(ridRCX))], [$C5, $F8, $AE, $11]);
  CheckEnc('vldmxcsr [r12+8]', 'vldmxcsr', [Op(DWordPtr(ridR12, 8))], [$C4, $C1, $78, $AE, $54, $24, $08]);
  CheckEnc('vstmxcsr [r13+16]', 'vstmxcsr', [Op(DWordPtr(ridR13, 16))], [$C4, $C1, $78, $AE, $5D, $10]);
  CheckEnc('vstmxcsr [rsp+24]', 'vstmxcsr', [Op(DWordPtr(ridRSP, 24))], [$C5, $F8, $AE, $5C, $24, $18]);
  CheckReject('reject vldmxcsr register operand', 'vldmxcsr', [Op(XMM0)]);
  CheckReject('reject vstmxcsr m64 operand', 'vstmxcsr', [Op(QWordPtr(ridRCX))]);
  CheckReject('reject vldmxcsr VSIB operand', 'vldmxcsr', [Op(Vm32x(ridRCX, XMM1))]);
end;

procedure CheckPublicApiPhase8;
var
  B: TAsmBuilder;
  Actual: TBytes;
begin
  B := TAsmBuilder.New;
  try
    B.Vldmxcsr(TMemory.Create(ridRCX)).Vstmxcsr(DWordPtr(ridR12, 8));
    Actual := B.Build;
    if SameBytes(Actual, [$C5, $F8, $AE, $11, $C4, $C1, $78, $AE, $5C, $24, $08]) then
    begin
      Inc(GPass);
      Writeln('PASS phase8 MXCSR public API');
      Writeln('  BYTES    ', BytesText(Actual));
    end
    else
    begin
      Inc(GFail);
      Writeln('FAIL phase8 MXCSR public API');
      Writeln('  ACTUAL   ', BytesText(Actual));
      Writeln('  EXPECTED C5 F8 AE 11 C4 C1 78 AE 5C 24 08');
    end;
  finally
    B.Free;
  end;
end;

procedure CheckRuntimePhase8;
type
  TMxcsrPair = array[0..1] of Cardinal;
var
  Status: TAvxCpuStatus;
  Values: TMxcsrPair;
  B: TAsmBuilder;
  Exe: TExecutableCode;
  Actual: TBytes;
begin
  Status := TAvxCpuFeatures.Query;
  if not Status.AvxUsable then
  begin
    Inc(GSkip);
    Writeln('SKIP AVX runtime phase8: AVX execution is not available');
    Exit;
  end;

  Values[0] := $FFFFFFFF;
  Values[1] := $FFFFFFFF;
  B := TAsmBuilder.New;
  try
    B.Vstmxcsr(DWordPtr(ridRCX)).Vldmxcsr(DWordPtr(ridRCX)).Vstmxcsr(DWordPtr(ridRCX, 4)).Ret;
    Actual := B.Build;
    if not SameBytes(Actual, [$C5, $F8, $AE, $19, $C5, $F8, $AE, $11, $C5, $F8, $AE, $59, $04, $C3]) then
    begin
      Inc(GFail);
      Writeln('FAIL AVX runtime MXCSR roundtrip kernel encoding');
      Writeln('  ACTUAL   ', BytesText(Actual));
      Exit;
    end;
    Exe := TExecutableCode.Create(Actual);
    try
      Exe.Run(UInt64(NativeUInt(@Values[0])));
    finally
      Exe.Free;
    end;
  finally
    B.Free;
  end;
  if (Values[0] = Values[1]) and ((Values[0] and $FFFF0000) = 0) then
  begin
    Inc(GPass);
    Writeln('PASS AVX runtime vldmxcsr/vstmxcsr roundtrip');
  end
  else
  begin
    Inc(GFail);
    Writeln('FAIL AVX runtime vldmxcsr/vstmxcsr roundtrip: ', IntToHex(Values[0], 8), ' / ', IntToHex(Values[1], 8));
  end;
end;

procedure CheckPhase9Encodings;
begin
  CheckEnc('vblendvps xmm0,xmm1,xmm2,xmm3', 'vblendvps', [Op(XMM0), Op(XMM1), Op(XMM2), Op(XMM3)], [$C4, $E3, $71, $4A, $C2, $30]);
  CheckEnc('vblendvps ymm8,ymm9,ymm10,ymm11', 'vblendvps', [Op(YMM8), Op(YMM9), Op(YMM10), Op(YMM11)], [$C4, $43, $35, $4A, $C2, $B0]);
  CheckEnc('vblendvpd xmm4,xmm5,[r12+32],xmm15', 'vblendvpd', [Op(XMM4), Op(XMM5), Op(XmmWordPtr(ridR12, 32)), Op(XMM15)], [$C4, $C3, $51, $4B, $64, $24, $20, $F0]);
  CheckEnc('vblendvpd ymm8,ymm9,ymm10,ymm15', 'vblendvpd', [Op(YMM8), Op(YMM9), Op(YMM10), Op(YMM15)], [$C4, $43, $35, $4B, $C2, $F0]);
  CheckEnc('vpblendvb xmm4,xmm5,xmm6,xmm7', 'vpblendvb', [Op(XMM4), Op(XMM5), Op(XMM6), Op(XMM7)], [$C4, $E3, $51, $4C, $E6, $70]);
  CheckEnc('vpblendvb ymm8,ymm9,[r12+32],ymm10', 'vpblendvb', [Op(YMM8), Op(YMM9), Op(YmmWordPtr(ridR12, 32)), Op(YMM10)], [$C4, $43, $35, $4C, $44, $24, $20, $A0]);
  CheckReject('reject vblendvps mixed data width', 'vblendvps', [Op(YMM0), Op(YMM1), Op(XMM2), Op(YMM3)]);
  CheckReject('reject vblendvpd wrong memory width', 'vblendvpd', [Op(YMM0), Op(YMM1), Op(XmmWordPtr(ridRCX)), Op(YMM3)]);
  CheckReject('reject vblendvps GPR selector', 'vblendvps', [Op(XMM0), Op(XMM1), Op(XMM2), Op(EAX)]);
  CheckReject('reject vpblendvb mixed selector width', 'vpblendvb', [Op(YMM0), Op(YMM1), Op(YMM2), Op(XMM3)]);
end;

procedure CheckPublicApiPhase9;
var
  B: TAsmBuilder;
  Actual: TBytes;
begin
  B := TAsmBuilder.New;
  try
    B.Vblendvps(XMM0, XMM1, XMM2, XMM3).Vblendvpd(YMM8, YMM9, YMM10, YMM15).Vpblendvb(YMM8, YMM9, YmmWordPtr(ridR12, 32), YMM10);
    Actual := B.Build;
    if SameBytes(Actual, [$C4, $E3, $71, $4A, $C2, $30, $C4, $43, $35, $4B, $C2, $F0, $C4, $43, $35, $4C, $44, $24, $20, $A0]) then
    begin
      Inc(GPass);
      Writeln('PASS phase9 /is4 blend public API');
      Writeln('  BYTES    ', BytesText(Actual));
    end
    else
    begin
      Inc(GFail);
      Writeln('FAIL phase9 /is4 blend public API');
      Writeln('  ACTUAL   ', BytesText(Actual));
      Writeln('  EXPECTED C4 E3 71 4A C2 30 C4 43 35 4B C2 F0 C4 43 35 4C 44 24 20 A0');
    end;
  finally
    B.Free;
  end;
end;

procedure CheckRuntimePhase9;
var
  Status: TAvxCpuStatus;
  B: TAsmBuilder;
  Exe: TExecutableCode;
  Actual: TBytes;
  R: UInt64;
begin
  Status := TAvxCpuFeatures.Query;
  if not Status.AvxUsable then
  begin
    Inc(GSkip);
    Writeln('SKIP AVX runtime phase9: AVX execution is not available');
    Exit;
  end;

  B := TAsmBuilder.New;
  try
    B.Vmovd(XMM1, EDX).Vmovd(XMM2, R8D).Vmovd(XMM3, R9D).Vblendvps(XMM0, XMM1, XMM2, XMM3).Vmovd(EAX, XMM0).Ret;
    Actual := B.Build;
    if not SameBytes(Actual, [$C5, $F9, $6E, $CA, $C4, $C1, $79, $6E, $D0, $C4, $C1, $79, $6E, $D9, $C4, $E3, $71, $4A, $C2, $30, $C5, $F9, $7E, $C0, $C3]) then
    begin
      Inc(GFail);
      Writeln('FAIL AVX runtime vblendvps /is4 kernel encoding');
      Writeln('  ACTUAL   ', BytesText(Actual));
      Exit;
    end;
    Exe := TExecutableCode.Create(Actual);
    try
      R := Exe.Run(0, $11223344, $55667788, $80000000);
    finally
      Exe.Free;
    end;
  finally
    B.Free;
  end;
  if Cardinal(R) = $55667788 then
  begin
    Inc(GPass);
    Writeln('PASS AVX runtime vblendvps /is4 selector');
  end
  else
  begin
    Inc(GFail);
    Writeln('FAIL AVX runtime vblendvps /is4 selector: ', IntToHex(R, 16));
  end;
end;

procedure CheckPhase10Encodings;
begin
  CheckEnc('vpcmpestri xmm0,xmm1,08', 'vpcmpestri', [Op(XMM0), Op(XMM1), Op($08)], [$C4, $E3, $79, $61, $C1, $08]);
  CheckEnc('vpcmpestri xmm8,[r12+32],18', 'vpcmpestri', [Op(XMM8), Op(XmmWordPtr(ridR12, 32)), Op($18)], [$C4, $43, $79, $61, $44, $24, $20, $18]);
  CheckEnc('vpcmpestrm xmm2,xmm3,08', 'vpcmpestrm', [Op(XMM2), Op(XMM3), Op($08)], [$C4, $E3, $79, $60, $D3, $08]);
  CheckEnc('vpcmpestrm xmm10,[r13+48],18', 'vpcmpestrm', [Op(XMM10), Op(XmmWordPtr(ridR13, 48)), Op($18)], [$C4, $43, $79, $60, $55, $30, $18]);
  CheckEnc('vpcmpistri xmm4,xmm5,0C', 'vpcmpistri', [Op(XMM4), Op(XMM5), Op($0C)], [$C4, $E3, $79, $63, $E5, $0C]);
  CheckEnc('vpcmpistri xmm12,[r14+64],1C', 'vpcmpistri', [Op(XMM12), Op(XmmWordPtr(ridR14, 64)), Op($1C)], [$C4, $43, $79, $63, $66, $40, $1C]);
  CheckEnc('vpcmpistrm xmm6,xmm7,0C', 'vpcmpistrm', [Op(XMM6), Op(XMM7), Op($0C)], [$C4, $E3, $79, $62, $F7, $0C]);
  CheckEnc('vpcmpistrm xmm14,[r15+80],1C', 'vpcmpistrm', [Op(XMM14), Op(XmmWordPtr(ridR15, 80)), Op($1C)], [$C4, $43, $79, $62, $77, $50, $1C]);
  CheckReject('reject vpcmpestri YMM first operand', 'vpcmpestri', [Op(YMM0), Op(XMM1), Op($08)]);
  CheckReject('reject vpcmpestrm m256 source', 'vpcmpestrm', [Op(XMM0), Op(YmmWordPtr(ridRCX)), Op($08)]);
  CheckReject('reject vpcmpistri imm8 above range', 'vpcmpistri', [Op(XMM0), Op(XMM1), Op(256)]);
  CheckReject('reject explicit implicit operands', 'vpcmpestri', [Op(XMM0), Op(XMM1), Op($08), Op(EAX), Op(EDX)]);
end;

procedure CheckPublicApiPhase10;
var
  B: TAsmBuilder;
  Actual: TBytes;
begin
  B := TAsmBuilder.New;
  try
    B.Vpcmpestri(XMM0, XMM1, $08).Vpcmpestrm(XMM8, XMM9, $18).Vpcmpistri(XMM2, XmmWordPtr(ridR12, 32), $0C).Vpcmpistrm(XMM10, XmmWordPtr(ridR13, 48), $1C);
    Actual := B.Build;
    if SameBytes(Actual, [$C4, $E3, $79, $61, $C1, $08, $C4, $43, $79, $60, $C1, $18, $C4, $C3, $79, $63, $54, $24, $20, $0C, $C4, $43, $79, $62, $55, $30, $1C]) then
    begin
      Inc(GPass);
      Writeln('PASS phase10 implicit-operand PCMP public API');
      Writeln('  BYTES    ', BytesText(Actual));
    end
    else
    begin
      Inc(GFail);
      Writeln('FAIL phase10 implicit-operand PCMP public API');
      Writeln('  ACTUAL   ', BytesText(Actual));
      Writeln('  EXPECTED C4 E3 79 61 C1 08 C4 43 79 60 C1 18 C4 C3 79 63 54 24 20 0C C4 43 79 62 55 30 1C');
    end;
  finally
    B.Free;
  end;
end;

procedure CheckRuntimePhase10;
type
  TPcmpData = packed record
    Pattern: array[0..15] of Byte;
    TextData: array[0..15] of Byte;
  end;
var
  Status: TAvxCpuStatus;
  Data: TPcmpData;
  B: TAsmBuilder;
  Exe: TExecutableCode;
  Actual: TBytes;
  R: UInt64;
begin
  Status := TAvxCpuFeatures.Query;
  if not Status.AvxUsable then
  begin
    Inc(GSkip);
    Writeln('SKIP AVX runtime phase10 PCMP: AVX execution is not available');
    Exit;
  end;

  FillChar(Data, SizeOf(Data), 0);
  Data.Pattern[0] := Ord('c');
  Data.Pattern[1] := Ord('a');
  Data.Pattern[2] := Ord('t');
  Data.TextData[0] := Ord('x');
  Data.TextData[1] := Ord('x');
  Data.TextData[2] := Ord('c');
  Data.TextData[3] := Ord('a');
  Data.TextData[4] := Ord('t');
  Data.TextData[5] := Ord('y');
  Data.TextData[6] := Ord('y');

  B := TAsmBuilder.New;
  try
    B.Vmovdqu(XMM0, XmmWordPtr(ridRCX)).Vmovdqu(XMM1, XmmWordPtr(ridRCX, 16)).Vpcmpistri(XMM0, XMM1, $0C).Vmovd(XMM2, ECX).Vmovd(EAX, XMM2).Ret;
    Actual := B.Build;
    if not SameBytes(Actual, [$C5, $FA, $6F, $01, $C5, $FA, $6F, $49, $10, $C4, $E3, $79, $63, $C1, $0C, $C5, $F9, $6E, $D1, $C5, $F9, $7E, $D0, $C3]) then
    begin
      Inc(GFail);
      Writeln('FAIL AVX runtime vpcmpistri kernel encoding');
      Writeln('  ACTUAL   ', BytesText(Actual));
      Exit;
    end;
    Exe := TExecutableCode.Create(Actual);
    try
      R := Exe.Run(UInt64(NativeUInt(@Data)));
    finally
      Exe.Free;
    end;
  finally
    B.Free;
  end;
  if Cardinal(R) = 2 then
  begin
    Inc(GPass);
    Writeln('PASS AVX runtime vpcmpistri implicit ECX result');
  end
  else
  begin
    Inc(GFail);
    Writeln('FAIL AVX runtime vpcmpistri implicit ECX result: ', IntToHex(R, 16));
  end;
end;

procedure CheckPhase11Encodings;
begin
  CheckEnc('vmovups xmm0,xmm1 corrected NP', 'vmovups', [Op(XMM0), Op(XMM1)], [$C5, $F8, $10, $C1]);
  CheckEnc('vmovups xmm8,[r12+32] corrected NP', 'vmovups', [Op(XMM8), Op(XmmWordPtr(ridR12, 32))], [$C4, $41, $78, $10, $44, $24, $20]);
  CheckEnc('vmovups [r13+16],xmm9 corrected NP', 'vmovups', [Op(XmmWordPtr(ridR13, 16)), Op(XMM9)], [$C4, $41, $78, $11, $4D, $10]);
  CheckEnc('vmovups ymm2,ymm3 corrected NP', 'vmovups', [Op(YMM2), Op(YMM3)], [$C5, $FC, $10, $D3]);
  CheckEnc('vmovupd xmm0,xmm1 corrected 66', 'vmovupd', [Op(XMM0), Op(XMM1)], [$C5, $F9, $10, $C1]);
  CheckEnc('vmovupd ymm8,[r12+32] corrected 66', 'vmovupd', [Op(YMM8), Op(YmmWordPtr(ridR12, 32))], [$C4, $41, $7D, $10, $44, $24, $20]);
  CheckEnc('vmovupd [r13+16],ymm9 corrected 66', 'vmovupd', [Op(YmmWordPtr(ridR13, 16)), Op(YMM9)], [$C4, $41, $7D, $11, $4D, $10]);
  CheckEnc('vpabsd xmm0,xmm1 corrected RM tag', 'vpabsd', [Op(XMM0), Op(XMM1)], [$C4, $E2, $79, $1E, $C1]);
  CheckEnc('vpabsd ymm8,ymm9', 'vpabsd', [Op(YMM8), Op(YMM9)], [$C4, $42, $7D, $1E, $C1]);
  CheckEnc('vpabsd ymm10,[r12+64]', 'vpabsd', [Op(YMM10), Op(YmmWordPtr(ridR12, 64))], [$C4, $42, $7D, $1E, $54, $24, $40]);
  CheckEnc('vmaskmovdqu xmm1,xmm2 implicit ds:rdi', 'vmaskmovdqu', [Op(XMM1), Op(XMM2)], [$C5, $F9, $F7, $CA]);
  CheckEnc('vmaskmovdqu xmm8,xmm9 implicit ds:rdi', 'vmaskmovdqu', [Op(XMM8), Op(XMM9)], [$C4, $41, $79, $F7, $C1]);
  CheckReject('reject vmovups m64 source', 'vmovups', [Op(XMM0), Op(QWordPtr(ridRCX))]);
  CheckReject('reject vmovupd YMM with m128 source', 'vmovupd', [Op(YMM0), Op(XmmWordPtr(ridRCX))]);
  CheckReject('reject vpabsd XMM with m256 source', 'vpabsd', [Op(XMM0), Op(YmmWordPtr(ridRCX))]);
  CheckReject('reject vmaskmovdqu YMM operands', 'vmaskmovdqu', [Op(YMM0), Op(YMM1)]);
  CheckReject('reject explicit vmaskmovdqu implicit memory', 'vmaskmovdqu', [Op(XMM0), Op(XMM1), Op(XmmWordPtr(ridRDI))]);
end;

procedure CheckPublicApiPhase11;
var
  B: TAsmBuilder;
  Actual: TBytes;
begin
  B := TAsmBuilder.New;
  try
    B.Vmovups(XMM0, XMM1).Vmovupd(YMM8, YmmWordPtr(ridR12, 32)).Vpabsd(YMM10, YmmWordPtr(ridR12, 64)).Vmaskmovdqu(XMM8, XMM9);
    Actual := B.Build;
    if SameBytes(Actual, [$C5, $F8, $10, $C1, $C4, $41, $7D, $10, $44, $24, $20, $C4, $42, $7D, $1E, $54, $24, $40, $C4, $41, $79, $F7, $C1]) then
    begin
      Inc(GPass);
      Writeln('PASS phase11 corrected-source and implicit-memory public API');
      Writeln('  BYTES    ', BytesText(Actual));
    end
    else
    begin
      Inc(GFail);
      Writeln('FAIL phase11 corrected-source and implicit-memory public API');
      Writeln('  ACTUAL   ', BytesText(Actual));
      Writeln('  EXPECTED C5 F8 10 C1 C4 41 7D 10 44 24 20 C4 42 7D 1E 54 24 40 C4 41 79 F7 C1');
    end;
  finally
    B.Free;
  end;
end;

procedure CheckRuntimePhase11;
type
  TAbsData = packed record
    Source: array[0..3] of Integer;
    Output: array[0..3] of Integer;
  end;
  TMaskData = packed record
    Output: array[0..15] of Byte;
  end;
var
  Status: TAvxCpuStatus;
  AbsData: TAbsData;
  MaskData: TMaskData;
  B: TAsmBuilder;
  Exe: TExecutableCode;
  Actual: TBytes;
  I: Integer;
  Ok: Boolean;
begin
  Status := TAvxCpuFeatures.Query;
  if not Status.AvxUsable then
  begin
    Inc(GSkip, 2);
    Writeln('SKIP AVX runtime phase11 corrected-source forms: AVX execution is not available');
    Writeln('SKIP AVX runtime phase11 vmaskmovdqu: AVX execution is not available');
    Exit;
  end;

  FillChar(AbsData, SizeOf(AbsData), 0);
  AbsData.Source[0] := -1;
  AbsData.Source[1] := 2;
  AbsData.Source[2] := -3;
  AbsData.Source[3] := 4;

  B := TAsmBuilder.New;
  try
    B.Vmovdqu(XMM0, XmmWordPtr(ridRCX)).Vpabsd(XMM1, XMM0).Vmovdqu(XmmWordPtr(ridRCX, 16), XMM1).Ret;
    Actual := B.Build;
    if not SameBytes(Actual, [$C5, $FA, $6F, $01, $C4, $E2, $79, $1E, $C8, $C5, $FA, $7F, $49, $10, $C3]) then
    begin
      Inc(GFail);
      Writeln('FAIL AVX runtime vpabsd kernel encoding');
      Writeln('  ACTUAL   ', BytesText(Actual));
    end
    else
    begin
      Exe := TExecutableCode.Create(Actual);
      try
        Exe.Run(UInt64(NativeUInt(@AbsData)));
      finally
        Exe.Free;
      end;
      Ok := True;
      for I := 0 to 3 do
        if AbsData.Output[I] <> Abs(AbsData.Source[I]) then
          Ok := False;
      if Ok then begin Inc(GPass); Writeln('PASS AVX runtime vpabsd corrected-source form'); end
      else begin Inc(GFail); Writeln('FAIL AVX runtime vpabsd corrected-source form'); end;
    end;
  finally
    B.Free;
  end;

  FillChar(MaskData, SizeOf(MaskData), $CC);
  B := TAsmBuilder.New;
  try
    B.Push(RDI).Mov(RDI, RCX).Vmovd(XMM0, EDX).Vpcmpeqb(XMM1, XMM1, XMM1).Vmaskmovdqu(XMM0, XMM1).Sfence.Pop(RDI).Ret;
    Actual := B.Build;
    if not SameBytes(Actual, [$57, $48, $8B, $F9, $C5, $F9, $6E, $C2, $C5, $F1, $74, $C9, $C5, $F9, $F7, $C1, $0F, $AE, $F8, $5F, $C3]) then
    begin
      Inc(GFail);
      Writeln('FAIL AVX runtime vmaskmovdqu kernel encoding');
      Writeln('  ACTUAL   ', BytesText(Actual));
    end
    else
    begin
      Exe := TExecutableCode.Create(Actual);
      try
        Exe.Run(UInt64(NativeUInt(@MaskData)), $11223344);
      finally
        Exe.Free;
      end;
      Ok := (MaskData.Output[0] = $44) and (MaskData.Output[1] = $33) and
            (MaskData.Output[2] = $22) and (MaskData.Output[3] = $11);
      for I := 4 to 15 do
        if MaskData.Output[I] <> 0 then
          Ok := False;
      if Ok then begin Inc(GPass); Writeln('PASS AVX runtime vmaskmovdqu implicit ds:rdi store'); end
      else begin Inc(GFail); Writeln('FAIL AVX runtime vmaskmovdqu implicit ds:rdi store'); end;
    end;
  finally
    B.Free;
  end;
end;

procedure Run;
begin
  Writeln('NativeASM AVX/VEX audit');
  Writeln('DB SHA-256: ', TAvxInstructionDb.SourceSha256);
  Writeln('Forms: ', TAvxInstructionDb.FormCount, '  Mnemonics: ', TAvxInstructionDb.MnemonicCount);
  Writeln;

  CheckEnc('vaddps ymm0,ymm1,ymm2', 'vaddps', [Op(YMM0), Op(YMM1), Op(YMM2)], [$C5, $F4, $58, $C2]);
  CheckEnc('vaddps xmm0,xmm1,xmm2', 'vaddps', [Op(XMM0), Op(XMM1), Op(XMM2)], [$C5, $F0, $58, $C2]);
  CheckEnc('vaddps ymm8,ymm1,ymm2', 'vaddps', [Op(YMM8), Op(YMM1), Op(YMM2)], [$C5, $74, $58, $C2]);
  CheckEnc('vaddps ymm0,ymm1,ymm8', 'vaddps', [Op(YMM0), Op(YMM1), Op(YMM8)], [$C4, $C1, $74, $58, $C0]);
  CheckEnc('vaddps ymm0,ymm1,[r12+32]', 'vaddps', [Op(YMM0), Op(YMM1), Op(YmmWordPtr(ridR12, 32))], [$C4, $C1, $74, $58, $44, $24, $20]);
  CheckEnc('vsubps ymm3,ymm4,ymm5', 'vsubps', [Op(YMM3), Op(YMM4), Op(YMM5)], [$C5, $DC, $5C, $DD]);
  CheckEnc('vmulps xmm6,xmm7,[r8+16]', 'vmulps', [Op(XMM6), Op(XMM7), Op(XmmWordPtr(ridR8, 16))], [$C4, $C1, $40, $59, $70, $10]);
  CheckEnc('vpaddd xmm0,xmm1,xmm2', 'vpaddd', [Op(XMM0), Op(XMM1), Op(XMM2)], [$C5, $F1, $FE, $C2]);
  CheckEnc('vpaddd ymm0,ymm1,ymm2', 'vpaddd', [Op(YMM0), Op(YMM1), Op(YMM2)], [$C5, $F5, $FE, $C2]);
  CheckEnc('vpsubd ymm3,ymm4,[rcx+32]', 'vpsubd', [Op(YMM3), Op(YMM4), Op(YmmWordPtr(ridRCX, 32))], [$C5, $DD, $FA, $59, $20]);
  CheckEnc('vpxor ymm0,ymm1,ymm2', 'vpxor', [Op(YMM0), Op(YMM1), Op(YMM2)], [$C5, $F5, $EF, $C2]);
  CheckEnc('vpand ymm8,ymm9,[r12+r13*4+64]', 'vpand', [Op(YMM8), Op(YMM9), Op(YmmWordPtrSib(ridR12, ridR13, s4, 64))], [$C4, $01, $35, $DB, $44, $AC, $40]);
  CheckEnc('vpor xmm2,xmm3,xmm4', 'vpor', [Op(XMM2), Op(XMM3), Op(XMM4)], [$C5, $E1, $EB, $D4]);
  CheckEnc('vpmulld xmm0,xmm1,xmm2', 'vpmulld', [Op(XMM0), Op(XMM1), Op(XMM2)], [$C4, $E2, $71, $40, $C2]);
  CheckEnc('vpmulld ymm0,ymm1,ymm2', 'vpmulld', [Op(YMM0), Op(YMM1), Op(YMM2)], [$C4, $E2, $75, $40, $C2]);
  CheckEnc('vmovdqu ymm0,[rcx]', 'vmovdqu', [Op(YMM0), Op(YmmWordPtr(ridRCX))], [$C5, $FE, $6F, $01]);
  CheckEnc('vmovdqu [r8+16],ymm9', 'vmovdqu', [Op(YmmWordPtr(ridR8, 16)), Op(YMM9)], [$C4, $41, $7E, $7F, $48, $10]);
  CheckEnc('vmovdqa xmm2,xmm3', 'vmovdqa', [Op(XMM2), Op(XMM3)], [$C5, $F9, $6F, $D3]);
  CheckEnc('vmovdqa ymm4,ymm5', 'vmovdqa', [Op(YMM4), Op(YMM5)], [$C5, $FD, $6F, $E5]);
  CheckEnc('vmovdqu ymm1,ymm2 canonical RM', 'vmovdqu', [Op(YMM1), Op(YMM2)], [$C5, $FE, $6F, $CA]);
  CheckEnc('vshufps ymm0,ymm1,ymm2,1B', 'vshufps', [Op(YMM0), Op(YMM1), Op(YMM2), Op($1B)], [$C5, $F4, $C6, $C2, $1B]);
  CheckEnc('vshufps xmm8,xmm9,xmm10,FF', 'vshufps', [Op(XMM8), Op(XMM9), Op(XMM10), Op($FF)], [$C4, $41, $30, $C6, $C2, $FF]);
  CheckEnc('vpermilpd ymm0,ymm1,05', 'vpermilpd', [Op(YMM0), Op(YMM1), Op($05)], [$C4, $E3, $7D, $05, $C1, $05]);
  CheckEnc('vpermilpd ymm0,ymm1,ymm2', 'vpermilpd', [Op(YMM0), Op(YMM1), Op(YMM2)], [$C4, $E2, $75, $0D, $C2]);
  CheckEnc('vaddpd ymm0,ymm1,ymm2', 'vaddpd', [Op(YMM0), Op(YMM1), Op(YMM2)], [$C5, $F5, $58, $C2]);
  CheckEnc('vsubpd xmm3,xmm4,xmm5', 'vsubpd', [Op(XMM3), Op(XMM4), Op(XMM5)], [$C5, $D9, $5C, $DD]);
  CheckEnc('vmulpd ymm6,ymm7,[r8+16]', 'vmulpd', [Op(YMM6), Op(YMM7), Op(YmmWordPtr(ridR8, 16))], [$C4, $C1, $45, $59, $70, $10]);
  CheckEnc('vdivps ymm0,ymm1,ymm2', 'vdivps', [Op(YMM0), Op(YMM1), Op(YMM2)], [$C5, $F4, $5E, $C2]);
  CheckEnc('vdivpd xmm8,xmm9,xmm10', 'vdivpd', [Op(XMM8), Op(XMM9), Op(XMM10)], [$C4, $41, $31, $5E, $C2]);
  CheckEnc('vandps ymm1,ymm2,ymm3', 'vandps', [Op(YMM1), Op(YMM2), Op(YMM3)], [$C5, $EC, $54, $CB]);
  CheckEnc('vandpd xmm4,xmm5,xmm6', 'vandpd', [Op(XMM4), Op(XMM5), Op(XMM6)], [$C5, $D1, $54, $E6]);
  CheckEnc('vorps ymm7,ymm8,[r12+32]', 'vorps', [Op(YMM7), Op(YMM8), Op(YmmWordPtr(ridR12, 32))], [$C4, $C1, $3C, $56, $7C, $24, $20]);
  CheckEnc('vorpd xmm9,xmm10,xmm11', 'vorpd', [Op(XMM9), Op(XMM10), Op(XMM11)], [$C4, $41, $29, $56, $CB]);
  CheckEnc('vxorps ymm12,ymm13,ymm14', 'vxorps', [Op(YMM12), Op(YMM13), Op(YMM14)], [$C4, $41, $14, $57, $E6]);
  CheckEnc('vxorpd xmm0,xmm1,[r9+16]', 'vxorpd', [Op(XMM0), Op(XMM1), Op(XmmWordPtr(ridR9, 16))], [$C4, $C1, $71, $57, $41, $10]);
  CheckEnc('vminps ymm2,ymm3,ymm4', 'vminps', [Op(YMM2), Op(YMM3), Op(YMM4)], [$C5, $E4, $5D, $D4]);
  CheckEnc('vmaxps xmm5,xmm6,xmm7', 'vmaxps', [Op(XMM5), Op(XMM6), Op(XMM7)], [$C5, $C8, $5F, $EF]);
  CheckEnc('vminpd ymm8,ymm9,ymm10', 'vminpd', [Op(YMM8), Op(YMM9), Op(YMM10)], [$C4, $41, $35, $5D, $C2]);
  CheckEnc('vmaxpd xmm11,xmm12,[r13+32]', 'vmaxpd', [Op(XMM11), Op(XMM12), Op(XmmWordPtr(ridR13, 32))], [$C4, $41, $19, $5F, $5D, $20]);
  CheckEnc('vsqrtps ymm0,ymm1', 'vsqrtps', [Op(YMM0), Op(YMM1)], [$C5, $FC, $51, $C1]);
  CheckEnc('vsqrtpd xmm8,[r9+32]', 'vsqrtpd', [Op(XMM8), Op(XmmWordPtr(ridR9, 32))], [$C4, $41, $79, $51, $41, $20]);
  CheckEnc('vpcmpeqb ymm0,ymm1,ymm2', 'vpcmpeqb', [Op(YMM0), Op(YMM1), Op(YMM2)], [$C5, $F5, $74, $C2]);
  CheckEnc('vpcmpeqw xmm3,xmm4,xmm5', 'vpcmpeqw', [Op(XMM3), Op(XMM4), Op(XMM5)], [$C5, $D9, $75, $DD]);
  CheckEnc('vpcmpeqd ymm8,ymm9,[r12+64]', 'vpcmpeqd', [Op(YMM8), Op(YMM9), Op(YmmWordPtr(ridR12, 64))], [$C4, $41, $35, $76, $44, $24, $40]);
  CheckEnc('vpcmpgtb ymm1,ymm2,ymm3', 'vpcmpgtb', [Op(YMM1), Op(YMM2), Op(YMM3)], [$C5, $ED, $64, $CB]);
  CheckEnc('vpcmpgtw xmm4,xmm5,xmm6', 'vpcmpgtw', [Op(XMM4), Op(XMM5), Op(XMM6)], [$C5, $D1, $65, $E6]);
  CheckEnc('vpcmpgtd ymm7,ymm8,ymm9', 'vpcmpgtd', [Op(YMM7), Op(YMM8), Op(YMM9)], [$C4, $C1, $3D, $66, $F9]);
  CheckEnc('vpslld ymm0,ymm1,05', 'vpslld', [Op(YMM0), Op(YMM1), Op($05)], [$C5, $FD, $72, $F1, $05]);
  CheckEnc('vpslld ymm2,ymm3,xmm4', 'vpslld', [Op(YMM2), Op(YMM3), Op(XMM4)], [$C5, $E5, $F2, $D4]);
  CheckEnc('vpsrld xmm5,xmm6,07', 'vpsrld', [Op(XMM5), Op(XMM6), Op($07)], [$C5, $D1, $72, $D6, $07]);
  CheckEnc('vpsrld ymm7,ymm8,xmm9', 'vpsrld', [Op(YMM7), Op(YMM8), Op(XMM9)], [$C4, $C1, $3D, $D2, $F9]);
  CheckEnc('vpsrad ymm10,ymm11,03', 'vpsrad', [Op(YMM10), Op(YMM11), Op($03)], [$C4, $C1, $2D, $72, $E3, $03]);
  CheckEnc('vpsrad xmm12,xmm13,xmm14', 'vpsrad', [Op(XMM12), Op(XMM13), Op(XMM14)], [$C4, $41, $11, $E2, $E6]);
  CheckEnc('vpshufd ymm0,ymm1,1B', 'vpshufd', [Op(YMM0), Op(YMM1), Op($1B)], [$C5, $FD, $70, $C1, $1B]);
  CheckEnc('vpshufb ymm2,ymm3,ymm4', 'vpshufb', [Op(YMM2), Op(YMM3), Op(YMM4)], [$C4, $E2, $65, $00, $D4]);
  CheckEnc('vfmadd132ps ymm0,ymm1,ymm2', 'vfmadd132ps', [Op(YMM0), Op(YMM1), Op(YMM2)], [$C4, $E2, $75, $98, $C2]);
  CheckEnc('vfmadd213ps xmm3,xmm4,xmm5', 'vfmadd213ps', [Op(XMM3), Op(XMM4), Op(XMM5)], [$C4, $E2, $59, $A8, $DD]);
  CheckEnc('vfmadd231ps ymm8,ymm9,[r12+32]', 'vfmadd231ps', [Op(YMM8), Op(YMM9), Op(YmmWordPtr(ridR12, 32))], [$C4, $42, $35, $B8, $44, $24, $20]);
  CheckEnc('vfmadd132pd xmm10,xmm11,xmm12', 'vfmadd132pd', [Op(XMM10), Op(XMM11), Op(XMM12)], [$C4, $42, $A1, $98, $D4]);
  CheckEnc('vfmadd213pd ymm13,ymm14,ymm15', 'vfmadd213pd', [Op(YMM13), Op(YMM14), Op(YMM15)], [$C4, $42, $8D, $A8, $EF]);
  CheckEnc('vfmadd231pd ymm0,ymm1,ymm2', 'vfmadd231pd', [Op(YMM0), Op(YMM1), Op(YMM2)], [$C4, $E2, $F5, $B8, $C2]);
  CheckEnc('vfmsub132ps ymm0,ymm1,ymm2', 'vfmsub132ps', [Op(YMM0), Op(YMM1), Op(YMM2)], [$C4, $E2, $75, $9A, $C2]);
  CheckEnc('vfmsub213ps xmm3,xmm4,xmm5', 'vfmsub213ps', [Op(XMM3), Op(XMM4), Op(XMM5)], [$C4, $E2, $59, $AA, $DD]);
  CheckEnc('vfmsub231ps ymm8,ymm9,[r12+32]', 'vfmsub231ps', [Op(YMM8), Op(YMM9), Op(YmmWordPtr(ridR12, 32))], [$C4, $42, $35, $BA, $44, $24, $20]);
  CheckEnc('vfmsub132pd xmm10,xmm11,xmm12', 'vfmsub132pd', [Op(XMM10), Op(XMM11), Op(XMM12)], [$C4, $42, $A1, $9A, $D4]);
  CheckEnc('vfmsub213pd ymm13,ymm14,ymm15', 'vfmsub213pd', [Op(YMM13), Op(YMM14), Op(YMM15)], [$C4, $42, $8D, $AA, $EF]);
  CheckEnc('vfmsub231pd ymm0,ymm1,ymm2', 'vfmsub231pd', [Op(YMM0), Op(YMM1), Op(YMM2)], [$C4, $E2, $F5, $BA, $C2]);
  CheckEnc('vfnmadd132ps ymm1,ymm2,ymm3', 'vfnmadd132ps', [Op(YMM1), Op(YMM2), Op(YMM3)], [$C4, $E2, $6D, $9C, $CB]);
  CheckEnc('vfnmadd213ps xmm4,xmm5,xmm6', 'vfnmadd213ps', [Op(XMM4), Op(XMM5), Op(XMM6)], [$C4, $E2, $51, $AC, $E6]);
  CheckEnc('vfnmadd231ps ymm9,ymm10,[r13+64]', 'vfnmadd231ps', [Op(YMM9), Op(YMM10), Op(YmmWordPtr(ridR13, 64))], [$C4, $42, $2D, $BC, $4D, $40]);
  CheckEnc('vfnmadd132pd xmm11,xmm12,xmm13', 'vfnmadd132pd', [Op(XMM11), Op(XMM12), Op(XMM13)], [$C4, $42, $99, $9C, $DD]);
  CheckEnc('vfnmadd213pd ymm14,ymm15,ymm8', 'vfnmadd213pd', [Op(YMM14), Op(YMM15), Op(YMM8)], [$C4, $42, $85, $AC, $F0]);
  CheckEnc('vfnmadd231pd ymm2,ymm3,ymm4', 'vfnmadd231pd', [Op(YMM2), Op(YMM3), Op(YMM4)], [$C4, $E2, $E5, $BC, $D4]);
  CheckEnc('vfnmsub132ps ymm5,ymm6,ymm7', 'vfnmsub132ps', [Op(YMM5), Op(YMM6), Op(YMM7)], [$C4, $E2, $4D, $9E, $EF]);
  CheckEnc('vfnmsub213ps xmm8,xmm9,xmm10', 'vfnmsub213ps', [Op(XMM8), Op(XMM9), Op(XMM10)], [$C4, $42, $31, $AE, $C2]);
  CheckEnc('vfnmsub231ps ymm11,ymm12,[r14+96]', 'vfnmsub231ps', [Op(YMM11), Op(YMM12), Op(YmmWordPtr(ridR14, 96))], [$C4, $42, $1D, $BE, $5E, $60]);
  CheckEnc('vfnmsub132pd xmm13,xmm14,xmm15', 'vfnmsub132pd', [Op(XMM13), Op(XMM14), Op(XMM15)], [$C4, $42, $89, $9E, $EF]);
  CheckEnc('vfnmsub213pd ymm0,ymm8,ymm9', 'vfnmsub213pd', [Op(YMM0), Op(YMM8), Op(YMM9)], [$C4, $C2, $BD, $AE, $C1]);
  CheckEnc('vfnmsub231pd ymm3,ymm4,ymm5', 'vfnmsub231pd', [Op(YMM3), Op(YMM4), Op(YMM5)], [$C4, $E2, $DD, $BE, $DD]);
  CheckEnc('vfmsub132ps xmm0,xmm1,xmm2', 'vfmsub132ps', [Op(XMM0), Op(XMM1), Op(XMM2)], [$C4, $E2, $71, $9A, $C2]);
  CheckEnc('vfmsub213ps ymm0,ymm1,ymm2', 'vfmsub213ps', [Op(YMM0), Op(YMM1), Op(YMM2)], [$C4, $E2, $75, $AA, $C2]);
  CheckEnc('vfmsub231ps xmm0,xmm1,xmm2', 'vfmsub231ps', [Op(XMM0), Op(XMM1), Op(XMM2)], [$C4, $E2, $71, $BA, $C2]);
  CheckEnc('vfmsub132pd ymm0,ymm1,ymm2', 'vfmsub132pd', [Op(YMM0), Op(YMM1), Op(YMM2)], [$C4, $E2, $F5, $9A, $C2]);
  CheckEnc('vfmsub213pd xmm0,xmm1,xmm2', 'vfmsub213pd', [Op(XMM0), Op(XMM1), Op(XMM2)], [$C4, $E2, $F1, $AA, $C2]);
  CheckEnc('vfmsub231pd xmm0,xmm1,xmm2', 'vfmsub231pd', [Op(XMM0), Op(XMM1), Op(XMM2)], [$C4, $E2, $F1, $BA, $C2]);
  CheckEnc('vfnmadd132ps xmm0,xmm1,xmm2', 'vfnmadd132ps', [Op(XMM0), Op(XMM1), Op(XMM2)], [$C4, $E2, $71, $9C, $C2]);
  CheckEnc('vfnmadd213ps ymm0,ymm1,ymm2', 'vfnmadd213ps', [Op(YMM0), Op(YMM1), Op(YMM2)], [$C4, $E2, $75, $AC, $C2]);
  CheckEnc('vfnmadd231ps xmm0,xmm1,xmm2', 'vfnmadd231ps', [Op(XMM0), Op(XMM1), Op(XMM2)], [$C4, $E2, $71, $BC, $C2]);
  CheckEnc('vfnmadd132pd ymm0,ymm1,ymm2', 'vfnmadd132pd', [Op(YMM0), Op(YMM1), Op(YMM2)], [$C4, $E2, $F5, $9C, $C2]);
  CheckEnc('vfnmadd213pd xmm0,xmm1,xmm2', 'vfnmadd213pd', [Op(XMM0), Op(XMM1), Op(XMM2)], [$C4, $E2, $F1, $AC, $C2]);
  CheckEnc('vfnmadd231pd xmm0,xmm1,xmm2', 'vfnmadd231pd', [Op(XMM0), Op(XMM1), Op(XMM2)], [$C4, $E2, $F1, $BC, $C2]);
  CheckEnc('vfnmsub132ps xmm0,xmm1,xmm2', 'vfnmsub132ps', [Op(XMM0), Op(XMM1), Op(XMM2)], [$C4, $E2, $71, $9E, $C2]);
  CheckEnc('vfnmsub213ps ymm0,ymm1,ymm2', 'vfnmsub213ps', [Op(YMM0), Op(YMM1), Op(YMM2)], [$C4, $E2, $75, $AE, $C2]);
  CheckEnc('vfnmsub231ps xmm0,xmm1,xmm2', 'vfnmsub231ps', [Op(XMM0), Op(XMM1), Op(XMM2)], [$C4, $E2, $71, $BE, $C2]);
  CheckEnc('vfnmsub132pd ymm0,ymm1,ymm2', 'vfnmsub132pd', [Op(YMM0), Op(YMM1), Op(YMM2)], [$C4, $E2, $F5, $9E, $C2]);
  CheckEnc('vfnmsub213pd xmm0,xmm1,xmm2', 'vfnmsub213pd', [Op(XMM0), Op(XMM1), Op(XMM2)], [$C4, $E2, $F1, $AE, $C2]);
  CheckEnc('vfnmsub231pd xmm0,xmm1,xmm2', 'vfnmsub231pd', [Op(XMM0), Op(XMM1), Op(XMM2)], [$C4, $E2, $F1, $BE, $C2]);
  CheckEnc('vzeroupper', 'vzeroupper', [], [$C5, $F8, $77]);

  CheckReject('reject mixed vector widths', 'vaddps', [Op(YMM0), Op(XMM1), Op(YMM2)]);
  CheckReject('reject wrong memory width', 'vpaddd', [Op(YMM0), Op(YMM1), Op(XmmWordPtr(ridRCX))]);
  CheckReject('reject MMX as XMM', 'vaddps', [Op(MM0), Op(XMM1), Op(XMM2)]);
  CheckReject('reject imm8 below range', 'vshufps', [Op(YMM0), Op(YMM1), Op(YMM2), Op(-129)]);
  CheckReject('reject imm8 above range', 'vshufps', [Op(YMM0), Op(YMM1), Op(YMM2), Op(256)]);
  CheckReject('reject AVX2 shift variable count in YMM', 'vpslld', [Op(YMM0), Op(YMM1), Op(YMM2)]);
  CheckReject('reject AVX2 shift count memory width 256', 'vpslld', [Op(YMM0), Op(YMM1), Op(YmmWordPtr(ridRCX))]);
  CheckReject('reject FMA mixed vector widths', 'vfmadd231ps', [Op(YMM0), Op(XMM1), Op(YMM2)]);
  CheckReject('reject FMA wrong memory width', 'vfmadd231pd', [Op(YMM0), Op(YMM1), Op(XmmWordPtr(ridRCX))]);
  CheckReject('reject VFMSUB mixed vector widths', 'vfmsub231ps', [Op(YMM0), Op(XMM1), Op(YMM2)]);
  CheckReject('reject VFNMADD wrong memory width', 'vfnmadd231pd', [Op(YMM0), Op(YMM1), Op(XmmWordPtr(ridRCX))]);
  CheckReject('reject VFNMSUB mixed vector widths', 'vfnmsub231ps', [Op(XMM0), Op(YMM1), Op(XMM2)]);

  CheckExpandedEncodings;
  CheckExpandedEncodingsV9;
  CheckExpandedEncodingsV10;
  CheckGprXmmEncodings;
  CheckInsertExtractEncodings;
  CheckPhase3Encodings;
  CheckPhase4Encodings;
  CheckPhase5Encodings;
  CheckPhase6Encodings;
  CheckPhase7Encodings;
  CheckPhase8Encodings;
  CheckPhase9Encodings;
  CheckPhase10Encodings;
  CheckPhase11Encodings;
  CheckReleaseHardening;
  CheckScaleEncoding;
  CheckPublicApi;
  CheckPublicApiV9;
  CheckPublicApiV10;
  CheckPublicApiGprXmm;
  CheckPublicApiInsertExtract;
  CheckPublicApiPhase3;
  CheckPublicApiPhase4;
  CheckPublicApiPhase5;
  CheckPublicApiPhase6;
  CheckPublicApiPhase7;
  CheckPublicApiPhase8;
  CheckPublicApiPhase9;
  CheckPublicApiPhase10;
  CheckPublicApiPhase11;
  CheckPublicApiReleaseHardening;
  Writeln;
  CheckRuntimeAvx;
  CheckRuntimeGprXmm;
  CheckRuntimeInsertExtract;
  CheckRuntimePhase3;
  CheckRuntimePhase4;
  CheckRuntimePhase5;
  CheckRuntimePhase6;
  CheckRuntimePhase7;
  CheckRuntimePhase8;
  CheckRuntimePhase9;
  CheckRuntimePhase10;
  CheckRuntimePhase11;
  CheckRuntimeScalarAvx;
  Writeln;
  CheckRuntimeAvx2;
  CheckRuntimeAvx2Shift;
  CheckRuntimeAvx2Permute;
  Writeln;
  CheckRuntimeFma;
  CheckRuntimeFmaExtended;

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
