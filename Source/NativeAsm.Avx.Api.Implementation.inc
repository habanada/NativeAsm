function TAsmAvxHelper.Vaddpd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vaddpd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vaddps(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vaddps', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vaddsubpd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vaddsubpd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vaddsubps(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vaddsubps', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vandnpd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vandnpd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vandnps(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vandnps', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vandpd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vandpd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vandps(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vandps', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vblendpd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand; A3: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vblendpd', [A0, A1, A2, A3]);
end;

function TAsmAvxHelper.Vblendps(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand; A3: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vblendps', [A0, A1, A2, A3]);
end;

function TAsmAvxHelper.Vbroadcastf128(A0: TAvxOperand; A1: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vbroadcastf128', [A0, A1]);
end;

function TAsmAvxHelper.Vbroadcasti128(A0: TAvxOperand; A1: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vbroadcasti128', [A0, A1]);
end;

function TAsmAvxHelper.Vcmppd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand; A3: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vcmppd', [A0, A1, A2, A3]);
end;

function TAsmAvxHelper.Vcmpps(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand; A3: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vcmpps', [A0, A1, A2, A3]);
end;

function TAsmAvxHelper.Vdivpd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vdivpd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vdivps(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vdivps', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vdppd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand; A3: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vdppd', [A0, A1, A2, A3]);
end;

function TAsmAvxHelper.Vdpps(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand; A3: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vdpps', [A0, A1, A2, A3]);
end;

function TAsmAvxHelper.Vextractf128(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vextractf128', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vextracti128(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vextracti128', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vfmadd132pd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vfmadd132pd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vfmadd132ps(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vfmadd132ps', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vfmadd213pd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vfmadd213pd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vfmadd213ps(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vfmadd213ps', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vfmadd231pd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vfmadd231pd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vfmadd231ps(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vfmadd231ps', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vfmaddsub132pd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vfmaddsub132pd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vfmaddsub132ps(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vfmaddsub132ps', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vfmaddsub213pd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vfmaddsub213pd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vfmaddsub213ps(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vfmaddsub213ps', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vfmaddsub231pd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vfmaddsub231pd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vfmaddsub231ps(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vfmaddsub231ps', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vfmsub132pd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vfmsub132pd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vfmsub132ps(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vfmsub132ps', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vfmsub213pd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vfmsub213pd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vfmsub213ps(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vfmsub213ps', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vfmsub231pd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vfmsub231pd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vfmsub231ps(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vfmsub231ps', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vfmsubadd132pd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vfmsubadd132pd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vfmsubadd132ps(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vfmsubadd132ps', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vfmsubadd213pd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vfmsubadd213pd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vfmsubadd213ps(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vfmsubadd213ps', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vfmsubadd231pd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vfmsubadd231pd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vfmsubadd231ps(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vfmsubadd231ps', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vfnmadd132pd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vfnmadd132pd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vfnmadd132ps(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vfnmadd132ps', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vfnmadd213pd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vfnmadd213pd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vfnmadd213ps(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vfnmadd213ps', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vfnmadd231pd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vfnmadd231pd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vfnmadd231ps(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vfnmadd231ps', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vfnmsub132pd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vfnmsub132pd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vfnmsub132ps(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vfnmsub132ps', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vfnmsub213pd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vfnmsub213pd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vfnmsub213ps(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vfnmsub213ps', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vfnmsub231pd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vfnmsub231pd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vfnmsub231ps(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vfnmsub231ps', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vhaddpd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vhaddpd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vhaddps(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vhaddps', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vhsubpd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vhsubpd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vhsubps(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vhsubps', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vinsertf128(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand; A3: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vinsertf128', [A0, A1, A2, A3]);
end;

function TAsmAvxHelper.Vinserti128(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand; A3: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vinserti128', [A0, A1, A2, A3]);
end;

function TAsmAvxHelper.Vlddqu(A0: TAvxOperand; A1: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vlddqu', [A0, A1]);
end;

function TAsmAvxHelper.Vmaxpd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vmaxpd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vmaxps(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vmaxps', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vminpd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vminpd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vminps(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vminps', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vmovapd(A0: TAvxOperand; A1: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vmovapd', [A0, A1]);
end;

function TAsmAvxHelper.Vmovaps(A0: TAvxOperand; A1: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vmovaps', [A0, A1]);
end;

function TAsmAvxHelper.Vmovdqa(A0: TAvxOperand; A1: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vmovdqa', [A0, A1]);
end;

function TAsmAvxHelper.Vmovdqu(A0: TAvxOperand; A1: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vmovdqu', [A0, A1]);
end;

function TAsmAvxHelper.Vmovntdq(A0: TAvxOperand; A1: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vmovntdq', [A0, A1]);
end;

function TAsmAvxHelper.Vmovntpd(A0: TAvxOperand; A1: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vmovntpd', [A0, A1]);
end;

function TAsmAvxHelper.Vmovntps(A0: TAvxOperand; A1: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vmovntps', [A0, A1]);
end;

function TAsmAvxHelper.Vmovshdup(A0: TAvxOperand; A1: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vmovshdup', [A0, A1]);
end;

function TAsmAvxHelper.Vmovsldup(A0: TAvxOperand; A1: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vmovsldup', [A0, A1]);
end;

function TAsmAvxHelper.Vmpsadbw(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand; A3: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vmpsadbw', [A0, A1, A2, A3]);
end;

function TAsmAvxHelper.Vmulpd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vmulpd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vmulps(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vmulps', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vorpd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vorpd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vorps(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vorps', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpabsb(A0: TAvxOperand; A1: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpabsb', [A0, A1]);
end;

function TAsmAvxHelper.Vpabsw(A0: TAvxOperand; A1: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpabsw', [A0, A1]);
end;

function TAsmAvxHelper.Vpackssdw(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpackssdw', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpacksswb(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpacksswb', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpackusdw(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpackusdw', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpackuswb(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpackuswb', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpaddb(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpaddb', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpaddd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpaddd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpaddq(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpaddq', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpaddsb(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpaddsb', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpaddsw(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpaddsw', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpaddusb(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpaddusb', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpaddusw(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpaddusw', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpaddw(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpaddw', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpalignr(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand; A3: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpalignr', [A0, A1, A2, A3]);
end;

function TAsmAvxHelper.Vpand(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpand', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpandn(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpandn', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpavgb(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpavgb', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpavgw(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpavgw', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpblendd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand; A3: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpblendd', [A0, A1, A2, A3]);
end;

function TAsmAvxHelper.Vpblendw(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand; A3: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpblendw', [A0, A1, A2, A3]);
end;

function TAsmAvxHelper.Vpcmpeqb(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpcmpeqb', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpcmpeqd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpcmpeqd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpcmpeqq(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpcmpeqq', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpcmpeqw(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpcmpeqw', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpcmpgtb(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpcmpgtb', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpcmpgtd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpcmpgtd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpcmpgtq(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpcmpgtq', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpcmpgtw(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpcmpgtw', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vperm2f128(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand; A3: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vperm2f128', [A0, A1, A2, A3]);
end;

function TAsmAvxHelper.Vperm2i128(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand; A3: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vperm2i128', [A0, A1, A2, A3]);
end;

function TAsmAvxHelper.Vpermd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpermd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpermilpd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpermilpd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpermilps(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpermilps', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpermpd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpermpd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpermps(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpermps', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpermq(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpermq', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vphaddd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vphaddd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vphaddsw(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vphaddsw', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vphaddw(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vphaddw', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vphsubd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vphsubd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vphsubsw(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vphsubsw', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vphsubw(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vphsubw', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpmaddubsw(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpmaddubsw', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpmaddwd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpmaddwd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpmaxsb(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpmaxsb', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpmaxsd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpmaxsd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpmaxsw(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpmaxsw', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpmaxub(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpmaxub', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpmaxud(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpmaxud', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpmaxuw(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpmaxuw', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpminsb(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpminsb', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpminsd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpminsd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpminsw(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpminsw', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpminub(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpminub', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpminud(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpminud', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpminuw(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpminuw', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpmuldq(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpmuldq', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpmulhrsw(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpmulhrsw', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpmulhuw(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpmulhuw', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpmulhw(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpmulhw', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpmulld(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpmulld', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpmullw(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpmullw', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpmuludq(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpmuludq', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpor(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpor', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpsadbw(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpsadbw', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpshufb(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpshufb', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpshufd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpshufd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpshufhw(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpshufhw', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpshuflw(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpshuflw', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpsignb(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpsignb', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpsignd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpsignd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpsignw(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpsignw', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpslld(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpslld', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpslldq(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpslldq', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpsllq(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpsllq', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpsllvd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpsllvd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpsllvq(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpsllvq', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpsllw(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpsllw', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpsrad(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpsrad', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpsravd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpsravd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpsraw(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpsraw', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpsrld(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpsrld', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpsrldq(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpsrldq', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpsrlq(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpsrlq', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpsrlvd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpsrlvd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpsrlvq(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpsrlvq', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpsrlw(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpsrlw', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpsubb(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpsubb', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpsubd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpsubd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpsubq(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpsubq', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpsubsb(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpsubsb', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpsubsw(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpsubsw', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpsubusb(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpsubusb', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpsubusw(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpsubusw', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpsubw(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpsubw', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vptest(A0: TAvxOperand; A1: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vptest', [A0, A1]);
end;

function TAsmAvxHelper.Vpunpckhbw(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpunpckhbw', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpunpckhdq(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpunpckhdq', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpunpckhqdq(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpunpckhqdq', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpunpckhwd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpunpckhwd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpunpcklbw(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpunpcklbw', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpunpckldq(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpunpckldq', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpunpcklqdq(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpunpcklqdq', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpunpcklwd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpunpcklwd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpxor(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpxor', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vrcpps(A0: TAvxOperand; A1: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vrcpps', [A0, A1]);
end;

function TAsmAvxHelper.Vroundpd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vroundpd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vroundps(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vroundps', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vrsqrtps(A0: TAvxOperand; A1: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vrsqrtps', [A0, A1]);
end;

function TAsmAvxHelper.Vshufpd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand; A3: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vshufpd', [A0, A1, A2, A3]);
end;

function TAsmAvxHelper.Vshufps(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand; A3: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vshufps', [A0, A1, A2, A3]);
end;

function TAsmAvxHelper.Vsqrtpd(A0: TAvxOperand; A1: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vsqrtpd', [A0, A1]);
end;

function TAsmAvxHelper.Vsqrtps(A0: TAvxOperand; A1: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vsqrtps', [A0, A1]);
end;

function TAsmAvxHelper.Vsubpd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vsubpd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vsubps(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vsubps', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vtestpd(A0: TAvxOperand; A1: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vtestpd', [A0, A1]);
end;

function TAsmAvxHelper.Vtestps(A0: TAvxOperand; A1: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vtestps', [A0, A1]);
end;

function TAsmAvxHelper.Vunpckhpd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vunpckhpd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vunpckhps(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vunpckhps', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vunpcklpd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vunpcklpd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vunpcklps(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vunpcklps', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vxorpd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vxorpd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vxorps(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vxorps', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vzeroall: TAsmBuilder;
begin
  Result := Avx('vzeroall', []);
end;

function TAsmAvxHelper.Vzeroupper: TAsmBuilder;
begin
  Result := Avx('vzeroupper', []);
end;

function TAsmAvxHelper.Vaddsd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vaddsd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vaddss(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vaddss', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vbroadcastsd(A0: TAvxOperand; A1: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vbroadcastsd', [A0, A1]);
end;

function TAsmAvxHelper.Vbroadcastss(A0: TAvxOperand; A1: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vbroadcastss', [A0, A1]);
end;

function TAsmAvxHelper.Vcmpsd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand; A3: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vcmpsd', [A0, A1, A2, A3]);
end;

function TAsmAvxHelper.Vcmpss(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand; A3: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vcmpss', [A0, A1, A2, A3]);
end;

function TAsmAvxHelper.Vcomisd(A0: TAvxOperand; A1: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vcomisd', [A0, A1]);
end;

function TAsmAvxHelper.Vcomiss(A0: TAvxOperand; A1: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vcomiss', [A0, A1]);
end;

function TAsmAvxHelper.Vcvtdq2pd(A0: TAvxOperand; A1: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vcvtdq2pd', [A0, A1]);
end;

function TAsmAvxHelper.Vcvtdq2ps(A0: TAvxOperand; A1: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vcvtdq2ps', [A0, A1]);
end;

function TAsmAvxHelper.Vcvtpd2dq(A0: TAvxOperand; A1: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vcvtpd2dq', [A0, A1]);
end;

function TAsmAvxHelper.Vcvtpd2ps(A0: TAvxOperand; A1: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vcvtpd2ps', [A0, A1]);
end;

function TAsmAvxHelper.Vcvtps2dq(A0: TAvxOperand; A1: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vcvtps2dq', [A0, A1]);
end;

function TAsmAvxHelper.Vcvtps2pd(A0: TAvxOperand; A1: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vcvtps2pd', [A0, A1]);
end;

function TAsmAvxHelper.Vcvtsd2ss(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vcvtsd2ss', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vcvtss2sd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vcvtss2sd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vcvttpd2dq(A0: TAvxOperand; A1: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vcvttpd2dq', [A0, A1]);
end;

function TAsmAvxHelper.Vcvttps2dq(A0: TAvxOperand; A1: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vcvttps2dq', [A0, A1]);
end;

function TAsmAvxHelper.Vdivsd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vdivsd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vdivss(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vdivss', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vfmadd132sd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vfmadd132sd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vfmadd132ss(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vfmadd132ss', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vfmadd213sd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vfmadd213sd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vfmadd213ss(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vfmadd213ss', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vfmadd231sd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vfmadd231sd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vfmadd231ss(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vfmadd231ss', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vfmsub132sd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vfmsub132sd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vfmsub132ss(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vfmsub132ss', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vfmsub213sd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vfmsub213sd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vfmsub213ss(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vfmsub213ss', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vfmsub231sd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vfmsub231sd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vfmsub231ss(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vfmsub231ss', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vfnmadd132sd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vfnmadd132sd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vfnmadd132ss(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vfnmadd132ss', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vfnmadd213sd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vfnmadd213sd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vfnmadd213ss(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vfnmadd213ss', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vfnmadd231sd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vfnmadd231sd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vfnmadd231ss(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vfnmadd231ss', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vfnmsub132sd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vfnmsub132sd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vfnmsub132ss(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vfnmsub132ss', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vfnmsub213sd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vfnmsub213sd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vfnmsub213ss(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vfnmsub213ss', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vfnmsub231sd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vfnmsub231sd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vfnmsub231ss(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vfnmsub231ss', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vinsertps(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand; A3: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vinsertps', [A0, A1, A2, A3]);
end;

function TAsmAvxHelper.Vmaxsd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vmaxsd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vmaxss(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vmaxss', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vminsd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vminsd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vminss(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vminss', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vmovddup(A0: TAvxOperand; A1: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vmovddup', [A0, A1]);
end;

function TAsmAvxHelper.Vmulsd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vmulsd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vmulss(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vmulss', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpbroadcastb(A0: TAvxOperand; A1: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpbroadcastb', [A0, A1]);
end;

function TAsmAvxHelper.Vpbroadcastd(A0: TAvxOperand; A1: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpbroadcastd', [A0, A1]);
end;

function TAsmAvxHelper.Vpbroadcastq(A0: TAvxOperand; A1: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpbroadcastq', [A0, A1]);
end;

function TAsmAvxHelper.Vpbroadcastw(A0: TAvxOperand; A1: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpbroadcastw', [A0, A1]);
end;

function TAsmAvxHelper.Vphminposuw(A0: TAvxOperand; A1: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vphminposuw', [A0, A1]);
end;

function TAsmAvxHelper.Vpmovsxbd(A0: TAvxOperand; A1: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpmovsxbd', [A0, A1]);
end;

function TAsmAvxHelper.Vpmovsxbq(A0: TAvxOperand; A1: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpmovsxbq', [A0, A1]);
end;

function TAsmAvxHelper.Vpmovsxbw(A0: TAvxOperand; A1: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpmovsxbw', [A0, A1]);
end;

function TAsmAvxHelper.Vpmovsxdq(A0: TAvxOperand; A1: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpmovsxdq', [A0, A1]);
end;

function TAsmAvxHelper.Vpmovsxwd(A0: TAvxOperand; A1: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpmovsxwd', [A0, A1]);
end;

function TAsmAvxHelper.Vpmovsxwq(A0: TAvxOperand; A1: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpmovsxwq', [A0, A1]);
end;

function TAsmAvxHelper.Vpmovzxbd(A0: TAvxOperand; A1: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpmovzxbd', [A0, A1]);
end;

function TAsmAvxHelper.Vpmovzxbq(A0: TAvxOperand; A1: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpmovzxbq', [A0, A1]);
end;

function TAsmAvxHelper.Vpmovzxbw(A0: TAvxOperand; A1: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpmovzxbw', [A0, A1]);
end;

function TAsmAvxHelper.Vpmovzxdq(A0: TAvxOperand; A1: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpmovzxdq', [A0, A1]);
end;

function TAsmAvxHelper.Vpmovzxwd(A0: TAvxOperand; A1: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpmovzxwd', [A0, A1]);
end;

function TAsmAvxHelper.Vpmovzxwq(A0: TAvxOperand; A1: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpmovzxwq', [A0, A1]);
end;

function TAsmAvxHelper.Vrcpss(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vrcpss', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vroundsd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand; A3: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vroundsd', [A0, A1, A2, A3]);
end;

function TAsmAvxHelper.Vroundss(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand; A3: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vroundss', [A0, A1, A2, A3]);
end;

function TAsmAvxHelper.Vrsqrtss(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vrsqrtss', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vsqrtsd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vsqrtsd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vsqrtss(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vsqrtss', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vsubsd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vsubsd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vsubss(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vsubss', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vucomisd(A0: TAvxOperand; A1: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vucomisd', [A0, A1]);
end;

function TAsmAvxHelper.Vucomiss(A0: TAvxOperand; A1: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vucomiss', [A0, A1]);
end;

function TAsmAvxHelper.Vmovd(A0: TAvxOperand; A1: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vmovd', [A0, A1]);
end;

function TAsmAvxHelper.Vmovq(A0: TAvxOperand; A1: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vmovq', [A0, A1]);
end;

function TAsmAvxHelper.Vpextrb(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpextrb', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpextrd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpextrd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpextrq(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpextrq', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpinsrb(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand; A3: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpinsrb', [A0, A1, A2, A3]);
end;

function TAsmAvxHelper.Vpinsrd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand; A3: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpinsrd', [A0, A1, A2, A3]);
end;

function TAsmAvxHelper.Vpinsrq(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand; A3: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpinsrq', [A0, A1, A2, A3]);
end;

function TAsmAvxHelper.Vcvtsd2si(A0: TAvxOperand; A1: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vcvtsd2si', [A0, A1]);
end;

function TAsmAvxHelper.Vcvtsi2sd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vcvtsi2sd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vcvtsi2ss(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vcvtsi2ss', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vcvtss2si(A0: TAvxOperand; A1: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vcvtss2si', [A0, A1]);
end;

function TAsmAvxHelper.Vcvttsd2si(A0: TAvxOperand; A1: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vcvttsd2si', [A0, A1]);
end;

function TAsmAvxHelper.Vcvttss2si(A0: TAvxOperand; A1: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vcvttss2si', [A0, A1]);
end;

function TAsmAvxHelper.Vextractps(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vextractps', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vmovmskpd(A0: TAvxOperand; A1: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vmovmskpd', [A0, A1]);
end;

function TAsmAvxHelper.Vmovmskps(A0: TAvxOperand; A1: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vmovmskps', [A0, A1]);
end;

function TAsmAvxHelper.Vpextrw(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpextrw', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpinsrw(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand; A3: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpinsrw', [A0, A1, A2, A3]);
end;

function TAsmAvxHelper.Vpmovmskb(A0: TAvxOperand; A1: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpmovmskb', [A0, A1]);
end;

function TAsmAvxHelper.Vmaskmovpd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vmaskmovpd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vmaskmovps(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vmaskmovps', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpmaskmovd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpmaskmovd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpmaskmovq(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpmaskmovq', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vgatherdpd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vgatherdpd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vgatherdps(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vgatherdps', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vgatherqpd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vgatherqpd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vgatherqps(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vgatherqps', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpgatherdd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpgatherdd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpgatherdq(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpgatherdq', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpgatherqd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpgatherqd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpgatherqq(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpgatherqq', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vmovhlps(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vmovhlps', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vmovhpd(A0: TAvxOperand; A1: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vmovhpd', [A0, A1]);
end;

function TAsmAvxHelper.Vmovhpd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vmovhpd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vmovhps(A0: TAvxOperand; A1: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vmovhps', [A0, A1]);
end;

function TAsmAvxHelper.Vmovhps(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vmovhps', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vmovlhps(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vmovlhps', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vmovlpd(A0: TAvxOperand; A1: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vmovlpd', [A0, A1]);
end;

function TAsmAvxHelper.Vmovlpd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vmovlpd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vmovlps(A0: TAvxOperand; A1: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vmovlps', [A0, A1]);
end;

function TAsmAvxHelper.Vmovlps(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vmovlps', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vmovntdqa(A0: TAvxOperand; A1: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vmovntdqa', [A0, A1]);
end;

function TAsmAvxHelper.Vmovsd(A0: TAvxOperand; A1: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vmovsd', [A0, A1]);
end;

function TAsmAvxHelper.Vmovsd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vmovsd', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vmovss(A0: TAvxOperand; A1: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vmovss', [A0, A1]);
end;

function TAsmAvxHelper.Vmovss(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vmovss', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vldmxcsr(A0: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vldmxcsr', [A0]);
end;

function TAsmAvxHelper.Vstmxcsr(A0: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vstmxcsr', [A0]);
end;

function TAsmAvxHelper.Vblendvpd(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand; A3: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vblendvpd', [A0, A1, A2, A3]);
end;

function TAsmAvxHelper.Vblendvps(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand; A3: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vblendvps', [A0, A1, A2, A3]);
end;

function TAsmAvxHelper.Vpblendvb(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand; A3: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpblendvb', [A0, A1, A2, A3]);
end;

function TAsmAvxHelper.Vpcmpestri(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpcmpestri', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpcmpestrm(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpcmpestrm', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpcmpistri(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpcmpistri', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vpcmpistrm(A0: TAvxOperand; A1: TAvxOperand; A2: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpcmpistrm', [A0, A1, A2]);
end;

function TAsmAvxHelper.Vmaskmovdqu(A0: TAvxOperand; A1: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vmaskmovdqu', [A0, A1]);
end;

function TAsmAvxHelper.Vmovupd(A0: TAvxOperand; A1: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vmovupd', [A0, A1]);
end;

function TAsmAvxHelper.Vmovups(A0: TAvxOperand; A1: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vmovups', [A0, A1]);
end;

function TAsmAvxHelper.Vpabsd(A0: TAvxOperand; A1: TAvxOperand): TAsmBuilder;
begin
  Result := Avx('vpabsd', [A0, A1]);
end;

