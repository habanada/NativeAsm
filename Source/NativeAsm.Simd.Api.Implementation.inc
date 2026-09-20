function TAsmSimdHelper.Addpd(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('addpd', [A0, A1]);
end;

function TAsmSimdHelper.Addps(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('addps', [A0, A1]);
end;

function TAsmSimdHelper.Addsd(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('addsd', [A0, A1]);
end;

function TAsmSimdHelper.Addss(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('addss', [A0, A1]);
end;

function TAsmSimdHelper.Addsubpd(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('addsubpd', [A0, A1]);
end;

function TAsmSimdHelper.Addsubps(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('addsubps', [A0, A1]);
end;

function TAsmSimdHelper.Aesdec(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('aesdec', [A0, A1]);
end;

function TAsmSimdHelper.Aesdeclast(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('aesdeclast', [A0, A1]);
end;

function TAsmSimdHelper.Aesenc(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('aesenc', [A0, A1]);
end;

function TAsmSimdHelper.Aesenclast(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('aesenclast', [A0, A1]);
end;

function TAsmSimdHelper.Aesimc(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('aesimc', [A0, A1]);
end;

function TAsmSimdHelper.Aeskeygenassist(A0: TSimdOperand; A1: TSimdOperand; A2: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('aeskeygenassist', [A0, A1, A2]);
end;

function TAsmSimdHelper.Andnpd(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('andnpd', [A0, A1]);
end;

function TAsmSimdHelper.Andnps(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('andnps', [A0, A1]);
end;

function TAsmSimdHelper.Andpd(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('andpd', [A0, A1]);
end;

function TAsmSimdHelper.Andps(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('andps', [A0, A1]);
end;

function TAsmSimdHelper.Blendpd(A0: TSimdOperand; A1: TSimdOperand; A2: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('blendpd', [A0, A1, A2]);
end;

function TAsmSimdHelper.Blendps(A0: TSimdOperand; A1: TSimdOperand; A2: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('blendps', [A0, A1, A2]);
end;

function TAsmSimdHelper.Blendvpd(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('blendvpd', [A0, A1]);
end;

function TAsmSimdHelper.Blendvps(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('blendvps', [A0, A1]);
end;

function TAsmSimdHelper.Cmppd(A0: TSimdOperand; A1: TSimdOperand; A2: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('cmppd', [A0, A1, A2]);
end;

function TAsmSimdHelper.Cmpps(A0: TSimdOperand; A1: TSimdOperand; A2: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('cmpps', [A0, A1, A2]);
end;

function TAsmSimdHelper.Cmpsd(A0: TSimdOperand; A1: TSimdOperand; A2: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('cmpsd', [A0, A1, A2]);
end;

function TAsmSimdHelper.Cmpss(A0: TSimdOperand; A1: TSimdOperand; A2: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('cmpss', [A0, A1, A2]);
end;

function TAsmSimdHelper.Comisd(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('comisd', [A0, A1]);
end;

function TAsmSimdHelper.Comiss(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('comiss', [A0, A1]);
end;

function TAsmSimdHelper.Crc32(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('crc32', [A0, A1]);
end;

function TAsmSimdHelper.Cvtdq2pd(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('cvtdq2pd', [A0, A1]);
end;

function TAsmSimdHelper.Cvtdq2ps(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('cvtdq2ps', [A0, A1]);
end;

function TAsmSimdHelper.Cvtpd2dq(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('cvtpd2dq', [A0, A1]);
end;

function TAsmSimdHelper.Cvtpd2pi(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('cvtpd2pi', [A0, A1]);
end;

function TAsmSimdHelper.Cvtpd2ps(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('cvtpd2ps', [A0, A1]);
end;

function TAsmSimdHelper.Cvtpi2pd(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('cvtpi2pd', [A0, A1]);
end;

function TAsmSimdHelper.Cvtpi2ps(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('cvtpi2ps', [A0, A1]);
end;

function TAsmSimdHelper.Cvtps2dq(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('cvtps2dq', [A0, A1]);
end;

function TAsmSimdHelper.Cvtps2pd(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('cvtps2pd', [A0, A1]);
end;

function TAsmSimdHelper.Cvtps2pi(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('cvtps2pi', [A0, A1]);
end;

function TAsmSimdHelper.Cvtsd2si(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('cvtsd2si', [A0, A1]);
end;

function TAsmSimdHelper.Cvtsd2ss(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('cvtsd2ss', [A0, A1]);
end;

function TAsmSimdHelper.Cvtsi2sd(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('cvtsi2sd', [A0, A1]);
end;

function TAsmSimdHelper.Cvtsi2ss(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('cvtsi2ss', [A0, A1]);
end;

function TAsmSimdHelper.Cvtss2sd(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('cvtss2sd', [A0, A1]);
end;

function TAsmSimdHelper.Cvtss2si(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('cvtss2si', [A0, A1]);
end;

function TAsmSimdHelper.Cvttpd2dq(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('cvttpd2dq', [A0, A1]);
end;

function TAsmSimdHelper.Cvttpd2pi(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('cvttpd2pi', [A0, A1]);
end;

function TAsmSimdHelper.Cvttps2dq(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('cvttps2dq', [A0, A1]);
end;

function TAsmSimdHelper.Cvttps2pi(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('cvttps2pi', [A0, A1]);
end;

function TAsmSimdHelper.Cvttsd2si(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('cvttsd2si', [A0, A1]);
end;

function TAsmSimdHelper.Cvttss2si(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('cvttss2si', [A0, A1]);
end;

function TAsmSimdHelper.Divpd(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('divpd', [A0, A1]);
end;

function TAsmSimdHelper.Divps(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('divps', [A0, A1]);
end;

function TAsmSimdHelper.Divsd(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('divsd', [A0, A1]);
end;

function TAsmSimdHelper.Divss(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('divss', [A0, A1]);
end;

function TAsmSimdHelper.Dppd(A0: TSimdOperand; A1: TSimdOperand; A2: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('dppd', [A0, A1, A2]);
end;

function TAsmSimdHelper.Dpps(A0: TSimdOperand; A1: TSimdOperand; A2: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('dpps', [A0, A1, A2]);
end;

function TAsmSimdHelper.Extractps(A0: TSimdOperand; A1: TSimdOperand; A2: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('extractps', [A0, A1, A2]);
end;

function TAsmSimdHelper.Extrq(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('extrq', [A0, A1]);
end;

function TAsmSimdHelper.Extrq(A0: TSimdOperand; A1: TSimdOperand; A2: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('extrq', [A0, A1, A2]);
end;

function TAsmSimdHelper.Haddpd(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('haddpd', [A0, A1]);
end;

function TAsmSimdHelper.Haddps(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('haddps', [A0, A1]);
end;

function TAsmSimdHelper.Hsubpd(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('hsubpd', [A0, A1]);
end;

function TAsmSimdHelper.Hsubps(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('hsubps', [A0, A1]);
end;

function TAsmSimdHelper.Insertps(A0: TSimdOperand; A1: TSimdOperand; A2: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('insertps', [A0, A1, A2]);
end;

function TAsmSimdHelper.Insertq(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('insertq', [A0, A1]);
end;

function TAsmSimdHelper.Insertq(A0: TSimdOperand; A1: TSimdOperand; A2: TSimdOperand; A3: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('insertq', [A0, A1, A2, A3]);
end;

function TAsmSimdHelper.Lddqu(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('lddqu', [A0, A1]);
end;

function TAsmSimdHelper.Ldmxcsr(A0: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('ldmxcsr', [A0]);
end;

function TAsmSimdHelper.Maskmovdqu(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('maskmovdqu', [A0, A1]);
end;

function TAsmSimdHelper.Maxpd(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('maxpd', [A0, A1]);
end;

function TAsmSimdHelper.Maxps(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('maxps', [A0, A1]);
end;

function TAsmSimdHelper.Maxsd(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('maxsd', [A0, A1]);
end;

function TAsmSimdHelper.Maxss(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('maxss', [A0, A1]);
end;

function TAsmSimdHelper.Minpd(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('minpd', [A0, A1]);
end;

function TAsmSimdHelper.Minps(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('minps', [A0, A1]);
end;

function TAsmSimdHelper.Minsd(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('minsd', [A0, A1]);
end;

function TAsmSimdHelper.Minss(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('minss', [A0, A1]);
end;

function TAsmSimdHelper.Movapd(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('movapd', [A0, A1]);
end;

function TAsmSimdHelper.Movaps(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('movaps', [A0, A1]);
end;

function TAsmSimdHelper.Movd(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('movd', [A0, A1]);
end;

function TAsmSimdHelper.Movddup(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('movddup', [A0, A1]);
end;

function TAsmSimdHelper.Movdq2q(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('movdq2q', [A0, A1]);
end;

function TAsmSimdHelper.Movdqa(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('movdqa', [A0, A1]);
end;

function TAsmSimdHelper.Movdqu(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('movdqu', [A0, A1]);
end;

function TAsmSimdHelper.Movhlps(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('movhlps', [A0, A1]);
end;

function TAsmSimdHelper.Movhpd(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('movhpd', [A0, A1]);
end;

function TAsmSimdHelper.Movhps(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('movhps', [A0, A1]);
end;

function TAsmSimdHelper.Movlhps(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('movlhps', [A0, A1]);
end;

function TAsmSimdHelper.Movlpd(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('movlpd', [A0, A1]);
end;

function TAsmSimdHelper.Movlps(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('movlps', [A0, A1]);
end;

function TAsmSimdHelper.Movmskpd(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('movmskpd', [A0, A1]);
end;

function TAsmSimdHelper.Movmskps(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('movmskps', [A0, A1]);
end;

function TAsmSimdHelper.Movntdq(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('movntdq', [A0, A1]);
end;

function TAsmSimdHelper.Movntdqa(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('movntdqa', [A0, A1]);
end;

function TAsmSimdHelper.Movnti(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('movnti', [A0, A1]);
end;

function TAsmSimdHelper.Movntpd(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('movntpd', [A0, A1]);
end;

function TAsmSimdHelper.Movntps(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('movntps', [A0, A1]);
end;

function TAsmSimdHelper.Movntsd(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('movntsd', [A0, A1]);
end;

function TAsmSimdHelper.Movntss(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('movntss', [A0, A1]);
end;

function TAsmSimdHelper.Movq(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('movq', [A0, A1]);
end;

function TAsmSimdHelper.Movq2dq(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('movq2dq', [A0, A1]);
end;

function TAsmSimdHelper.Movsd(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('movsd', [A0, A1]);
end;

function TAsmSimdHelper.Movshdup(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('movshdup', [A0, A1]);
end;

function TAsmSimdHelper.Movsldup(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('movsldup', [A0, A1]);
end;

function TAsmSimdHelper.Movss(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('movss', [A0, A1]);
end;

function TAsmSimdHelper.Movupd(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('movupd', [A0, A1]);
end;

function TAsmSimdHelper.Movups(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('movups', [A0, A1]);
end;

function TAsmSimdHelper.Mpsadbw(A0: TSimdOperand; A1: TSimdOperand; A2: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('mpsadbw', [A0, A1, A2]);
end;

function TAsmSimdHelper.Mulpd(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('mulpd', [A0, A1]);
end;

function TAsmSimdHelper.Mulps(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('mulps', [A0, A1]);
end;

function TAsmSimdHelper.Mulsd(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('mulsd', [A0, A1]);
end;

function TAsmSimdHelper.Mulss(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('mulss', [A0, A1]);
end;

function TAsmSimdHelper.Orpd(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('orpd', [A0, A1]);
end;

function TAsmSimdHelper.Orps(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('orps', [A0, A1]);
end;

function TAsmSimdHelper.Pabsb(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('pabsb', [A0, A1]);
end;

function TAsmSimdHelper.Pabsd(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('pabsd', [A0, A1]);
end;

function TAsmSimdHelper.Pabsw(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('pabsw', [A0, A1]);
end;

function TAsmSimdHelper.Packssdw(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('packssdw', [A0, A1]);
end;

function TAsmSimdHelper.Packsswb(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('packsswb', [A0, A1]);
end;

function TAsmSimdHelper.Packusdw(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('packusdw', [A0, A1]);
end;

function TAsmSimdHelper.Packuswb(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('packuswb', [A0, A1]);
end;

function TAsmSimdHelper.Paddb(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('paddb', [A0, A1]);
end;

function TAsmSimdHelper.Paddd(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('paddd', [A0, A1]);
end;

function TAsmSimdHelper.Paddq(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('paddq', [A0, A1]);
end;

function TAsmSimdHelper.Paddsb(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('paddsb', [A0, A1]);
end;

function TAsmSimdHelper.Paddsw(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('paddsw', [A0, A1]);
end;

function TAsmSimdHelper.Paddusb(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('paddusb', [A0, A1]);
end;

function TAsmSimdHelper.Paddusw(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('paddusw', [A0, A1]);
end;

function TAsmSimdHelper.Paddw(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('paddw', [A0, A1]);
end;

function TAsmSimdHelper.Palignr(A0: TSimdOperand; A1: TSimdOperand; A2: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('palignr', [A0, A1, A2]);
end;

function TAsmSimdHelper.Pand(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('pand', [A0, A1]);
end;

function TAsmSimdHelper.Pandn(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('pandn', [A0, A1]);
end;

function TAsmSimdHelper.Pavgb(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('pavgb', [A0, A1]);
end;

function TAsmSimdHelper.Pavgw(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('pavgw', [A0, A1]);
end;

function TAsmSimdHelper.Pblendvb(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('pblendvb', [A0, A1]);
end;

function TAsmSimdHelper.Pblendw(A0: TSimdOperand; A1: TSimdOperand; A2: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('pblendw', [A0, A1, A2]);
end;

function TAsmSimdHelper.Pclmulqdq(A0: TSimdOperand; A1: TSimdOperand; A2: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('pclmulqdq', [A0, A1, A2]);
end;

function TAsmSimdHelper.Pcmpeqb(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('pcmpeqb', [A0, A1]);
end;

function TAsmSimdHelper.Pcmpeqd(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('pcmpeqd', [A0, A1]);
end;

function TAsmSimdHelper.Pcmpeqq(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('pcmpeqq', [A0, A1]);
end;

function TAsmSimdHelper.Pcmpeqw(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('pcmpeqw', [A0, A1]);
end;

function TAsmSimdHelper.Pcmpestri(A0: TSimdOperand; A1: TSimdOperand; A2: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('pcmpestri', [A0, A1, A2]);
end;

function TAsmSimdHelper.Pcmpestrm(A0: TSimdOperand; A1: TSimdOperand; A2: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('pcmpestrm', [A0, A1, A2]);
end;

function TAsmSimdHelper.Pcmpgtb(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('pcmpgtb', [A0, A1]);
end;

function TAsmSimdHelper.Pcmpgtd(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('pcmpgtd', [A0, A1]);
end;

function TAsmSimdHelper.Pcmpgtq(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('pcmpgtq', [A0, A1]);
end;

function TAsmSimdHelper.Pcmpgtw(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('pcmpgtw', [A0, A1]);
end;

function TAsmSimdHelper.Pcmpistri(A0: TSimdOperand; A1: TSimdOperand; A2: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('pcmpistri', [A0, A1, A2]);
end;

function TAsmSimdHelper.Pcmpistrm(A0: TSimdOperand; A1: TSimdOperand; A2: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('pcmpistrm', [A0, A1, A2]);
end;

function TAsmSimdHelper.Pextrb(A0: TSimdOperand; A1: TSimdOperand; A2: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('pextrb', [A0, A1, A2]);
end;

function TAsmSimdHelper.Pextrd(A0: TSimdOperand; A1: TSimdOperand; A2: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('pextrd', [A0, A1, A2]);
end;

function TAsmSimdHelper.Pextrq(A0: TSimdOperand; A1: TSimdOperand; A2: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('pextrq', [A0, A1, A2]);
end;

function TAsmSimdHelper.Pextrw(A0: TSimdOperand; A1: TSimdOperand; A2: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('pextrw', [A0, A1, A2]);
end;

function TAsmSimdHelper.Phaddd(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('phaddd', [A0, A1]);
end;

function TAsmSimdHelper.Phaddsw(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('phaddsw', [A0, A1]);
end;

function TAsmSimdHelper.Phaddw(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('phaddw', [A0, A1]);
end;

function TAsmSimdHelper.Phminposuw(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('phminposuw', [A0, A1]);
end;

function TAsmSimdHelper.Phsubd(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('phsubd', [A0, A1]);
end;

function TAsmSimdHelper.Phsubsw(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('phsubsw', [A0, A1]);
end;

function TAsmSimdHelper.Phsubw(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('phsubw', [A0, A1]);
end;

function TAsmSimdHelper.Pinsrb(A0: TSimdOperand; A1: TSimdOperand; A2: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('pinsrb', [A0, A1, A2]);
end;

function TAsmSimdHelper.Pinsrd(A0: TSimdOperand; A1: TSimdOperand; A2: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('pinsrd', [A0, A1, A2]);
end;

function TAsmSimdHelper.Pinsrq(A0: TSimdOperand; A1: TSimdOperand; A2: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('pinsrq', [A0, A1, A2]);
end;

function TAsmSimdHelper.Pinsrw(A0: TSimdOperand; A1: TSimdOperand; A2: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('pinsrw', [A0, A1, A2]);
end;

function TAsmSimdHelper.Pmaddubsw(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('pmaddubsw', [A0, A1]);
end;

function TAsmSimdHelper.Pmaddwd(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('pmaddwd', [A0, A1]);
end;

function TAsmSimdHelper.Pmaxsb(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('pmaxsb', [A0, A1]);
end;

function TAsmSimdHelper.Pmaxsd(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('pmaxsd', [A0, A1]);
end;

function TAsmSimdHelper.Pmaxsw(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('pmaxsw', [A0, A1]);
end;

function TAsmSimdHelper.Pmaxub(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('pmaxub', [A0, A1]);
end;

function TAsmSimdHelper.Pmaxud(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('pmaxud', [A0, A1]);
end;

function TAsmSimdHelper.Pmaxuw(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('pmaxuw', [A0, A1]);
end;

function TAsmSimdHelper.Pminsb(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('pminsb', [A0, A1]);
end;

function TAsmSimdHelper.Pminsd(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('pminsd', [A0, A1]);
end;

function TAsmSimdHelper.Pminsw(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('pminsw', [A0, A1]);
end;

function TAsmSimdHelper.Pminub(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('pminub', [A0, A1]);
end;

function TAsmSimdHelper.Pminud(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('pminud', [A0, A1]);
end;

function TAsmSimdHelper.Pminuw(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('pminuw', [A0, A1]);
end;

function TAsmSimdHelper.Pmovmskb(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('pmovmskb', [A0, A1]);
end;

function TAsmSimdHelper.Pmovsxbd(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('pmovsxbd', [A0, A1]);
end;

function TAsmSimdHelper.Pmovsxbq(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('pmovsxbq', [A0, A1]);
end;

function TAsmSimdHelper.Pmovsxbw(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('pmovsxbw', [A0, A1]);
end;

function TAsmSimdHelper.Pmovsxdq(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('pmovsxdq', [A0, A1]);
end;

function TAsmSimdHelper.Pmovsxwd(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('pmovsxwd', [A0, A1]);
end;

function TAsmSimdHelper.Pmovsxwq(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('pmovsxwq', [A0, A1]);
end;

function TAsmSimdHelper.Pmovzxbd(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('pmovzxbd', [A0, A1]);
end;

function TAsmSimdHelper.Pmovzxbq(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('pmovzxbq', [A0, A1]);
end;

function TAsmSimdHelper.Pmovzxbw(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('pmovzxbw', [A0, A1]);
end;

function TAsmSimdHelper.Pmovzxdq(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('pmovzxdq', [A0, A1]);
end;

function TAsmSimdHelper.Pmovzxwd(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('pmovzxwd', [A0, A1]);
end;

function TAsmSimdHelper.Pmovzxwq(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('pmovzxwq', [A0, A1]);
end;

function TAsmSimdHelper.Pmuldq(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('pmuldq', [A0, A1]);
end;

function TAsmSimdHelper.Pmulhrsw(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('pmulhrsw', [A0, A1]);
end;

function TAsmSimdHelper.Pmulhuw(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('pmulhuw', [A0, A1]);
end;

function TAsmSimdHelper.Pmulhw(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('pmulhw', [A0, A1]);
end;

function TAsmSimdHelper.Pmulld(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('pmulld', [A0, A1]);
end;

function TAsmSimdHelper.Pmullw(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('pmullw', [A0, A1]);
end;

function TAsmSimdHelper.Pmuludq(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('pmuludq', [A0, A1]);
end;

function TAsmSimdHelper.Por(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('por', [A0, A1]);
end;

function TAsmSimdHelper.Prefetchnta(A0: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('prefetchnta', [A0]);
end;

function TAsmSimdHelper.Prefetcht0(A0: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('prefetcht0', [A0]);
end;

function TAsmSimdHelper.Prefetcht1(A0: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('prefetcht1', [A0]);
end;

function TAsmSimdHelper.Prefetcht2(A0: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('prefetcht2', [A0]);
end;

function TAsmSimdHelper.Psadbw(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('psadbw', [A0, A1]);
end;

function TAsmSimdHelper.Pshufb(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('pshufb', [A0, A1]);
end;

function TAsmSimdHelper.Pshufd(A0: TSimdOperand; A1: TSimdOperand; A2: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('pshufd', [A0, A1, A2]);
end;

function TAsmSimdHelper.Pshufhw(A0: TSimdOperand; A1: TSimdOperand; A2: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('pshufhw', [A0, A1, A2]);
end;

function TAsmSimdHelper.Pshuflw(A0: TSimdOperand; A1: TSimdOperand; A2: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('pshuflw', [A0, A1, A2]);
end;

function TAsmSimdHelper.Psignb(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('psignb', [A0, A1]);
end;

function TAsmSimdHelper.Psignd(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('psignd', [A0, A1]);
end;

function TAsmSimdHelper.Psignw(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('psignw', [A0, A1]);
end;

function TAsmSimdHelper.Pslld(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('pslld', [A0, A1]);
end;

function TAsmSimdHelper.Pslldq(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('pslldq', [A0, A1]);
end;

function TAsmSimdHelper.Psllq(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('psllq', [A0, A1]);
end;

function TAsmSimdHelper.Psllw(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('psllw', [A0, A1]);
end;

function TAsmSimdHelper.Psrad(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('psrad', [A0, A1]);
end;

function TAsmSimdHelper.Psraw(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('psraw', [A0, A1]);
end;

function TAsmSimdHelper.Psrld(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('psrld', [A0, A1]);
end;

function TAsmSimdHelper.Psrldq(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('psrldq', [A0, A1]);
end;

function TAsmSimdHelper.Psrlq(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('psrlq', [A0, A1]);
end;

function TAsmSimdHelper.Psrlw(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('psrlw', [A0, A1]);
end;

function TAsmSimdHelper.Psubb(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('psubb', [A0, A1]);
end;

function TAsmSimdHelper.Psubd(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('psubd', [A0, A1]);
end;

function TAsmSimdHelper.Psubq(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('psubq', [A0, A1]);
end;

function TAsmSimdHelper.Psubsb(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('psubsb', [A0, A1]);
end;

function TAsmSimdHelper.Psubsw(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('psubsw', [A0, A1]);
end;

function TAsmSimdHelper.Psubusb(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('psubusb', [A0, A1]);
end;

function TAsmSimdHelper.Psubusw(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('psubusw', [A0, A1]);
end;

function TAsmSimdHelper.Psubw(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('psubw', [A0, A1]);
end;

function TAsmSimdHelper.Ptest(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('ptest', [A0, A1]);
end;

function TAsmSimdHelper.Punpckhbw(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('punpckhbw', [A0, A1]);
end;

function TAsmSimdHelper.Punpckhdq(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('punpckhdq', [A0, A1]);
end;

function TAsmSimdHelper.Punpckhqdq(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('punpckhqdq', [A0, A1]);
end;

function TAsmSimdHelper.Punpckhwd(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('punpckhwd', [A0, A1]);
end;

function TAsmSimdHelper.Punpcklbw(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('punpcklbw', [A0, A1]);
end;

function TAsmSimdHelper.Punpckldq(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('punpckldq', [A0, A1]);
end;

function TAsmSimdHelper.Punpcklqdq(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('punpcklqdq', [A0, A1]);
end;

function TAsmSimdHelper.Punpcklwd(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('punpcklwd', [A0, A1]);
end;

function TAsmSimdHelper.Pxor(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('pxor', [A0, A1]);
end;

function TAsmSimdHelper.Rcpps(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('rcpps', [A0, A1]);
end;

function TAsmSimdHelper.Rcpss(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('rcpss', [A0, A1]);
end;

function TAsmSimdHelper.Roundpd(A0: TSimdOperand; A1: TSimdOperand; A2: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('roundpd', [A0, A1, A2]);
end;

function TAsmSimdHelper.Roundps(A0: TSimdOperand; A1: TSimdOperand; A2: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('roundps', [A0, A1, A2]);
end;

function TAsmSimdHelper.Roundsd(A0: TSimdOperand; A1: TSimdOperand; A2: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('roundsd', [A0, A1, A2]);
end;

function TAsmSimdHelper.Roundss(A0: TSimdOperand; A1: TSimdOperand; A2: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('roundss', [A0, A1, A2]);
end;

function TAsmSimdHelper.Rsqrtps(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('rsqrtps', [A0, A1]);
end;

function TAsmSimdHelper.Rsqrtss(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('rsqrtss', [A0, A1]);
end;

function TAsmSimdHelper.Sha1msg1(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('sha1msg1', [A0, A1]);
end;

function TAsmSimdHelper.Sha1msg2(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('sha1msg2', [A0, A1]);
end;

function TAsmSimdHelper.Sha1nexte(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('sha1nexte', [A0, A1]);
end;

function TAsmSimdHelper.Sha1rnds4(A0: TSimdOperand; A1: TSimdOperand; A2: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('sha1rnds4', [A0, A1, A2]);
end;

function TAsmSimdHelper.Sha256msg1(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('sha256msg1', [A0, A1]);
end;

function TAsmSimdHelper.Sha256msg2(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('sha256msg2', [A0, A1]);
end;

function TAsmSimdHelper.Sha256rnds2(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('sha256rnds2', [A0, A1]);
end;

function TAsmSimdHelper.Shufpd(A0: TSimdOperand; A1: TSimdOperand; A2: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('shufpd', [A0, A1, A2]);
end;

function TAsmSimdHelper.Shufps(A0: TSimdOperand; A1: TSimdOperand; A2: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('shufps', [A0, A1, A2]);
end;

function TAsmSimdHelper.Sqrtpd(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('sqrtpd', [A0, A1]);
end;

function TAsmSimdHelper.Sqrtps(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('sqrtps', [A0, A1]);
end;

function TAsmSimdHelper.Sqrtsd(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('sqrtsd', [A0, A1]);
end;

function TAsmSimdHelper.Sqrtss(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('sqrtss', [A0, A1]);
end;

function TAsmSimdHelper.Stmxcsr(A0: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('stmxcsr', [A0]);
end;

function TAsmSimdHelper.Subpd(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('subpd', [A0, A1]);
end;

function TAsmSimdHelper.Subps(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('subps', [A0, A1]);
end;

function TAsmSimdHelper.Subsd(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('subsd', [A0, A1]);
end;

function TAsmSimdHelper.Subss(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('subss', [A0, A1]);
end;

function TAsmSimdHelper.Ucomisd(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('ucomisd', [A0, A1]);
end;

function TAsmSimdHelper.Ucomiss(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('ucomiss', [A0, A1]);
end;

function TAsmSimdHelper.Unpckhpd(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('unpckhpd', [A0, A1]);
end;

function TAsmSimdHelper.Unpckhps(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('unpckhps', [A0, A1]);
end;

function TAsmSimdHelper.Unpcklpd(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('unpcklpd', [A0, A1]);
end;

function TAsmSimdHelper.Unpcklps(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('unpcklps', [A0, A1]);
end;

function TAsmSimdHelper.Xorpd(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('xorpd', [A0, A1]);
end;

function TAsmSimdHelper.Xorps(A0: TSimdOperand; A1: TSimdOperand): TAsmBuilder;
begin
  Result := Simd('xorps', [A0, A1]);
end;
