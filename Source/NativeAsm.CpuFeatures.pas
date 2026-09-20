{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
unit NativeAsm.CpuFeatures;

interface

type
  TCpuFeature = (cfAES, cfSHA, cfLZCNT, cfBMI1, cfSSE2, cfSSSE3, cfSSE42, cfPOPCNT, cfPCLMULQDQ);

  TCpuFeatures = class sealed
  public
    class function Supports(Feature: TCpuFeature): Boolean; static;
    class function Name(Feature: TCpuFeature): string; static;
  end;

implementation

class function TCpuFeatures.Name(Feature: TCpuFeature): string;
begin
  case Feature of
    cfAES: Result := 'AES';
    cfSHA: Result := 'SHA';
    cfLZCNT: Result := 'LZCNT';
    cfBMI1: Result := 'BMI1';
    cfSSE2: Result := 'SSE2';
    cfSSSE3: Result := 'SSSE3';
    cfSSE42: Result := 'SSE4.2';
    cfPOPCNT: Result := 'POPCNT';
    cfPCLMULQDQ: Result := 'PCLMULQDQ';
  else
    Result := 'Unknown';
  end;
end;

class function TCpuFeatures.Supports(Feature: TCpuFeature): Boolean;
var
  R: System.TCPUIDRec;
begin
  Result := False;
  case Feature of
    cfAES, cfSSE2, cfSSSE3, cfSSE42, cfPOPCNT, cfPCLMULQDQ:
      begin
        R := System.GetCPUID(0);
        if R.EAX < 1 then Exit;
        R := System.GetCPUID(1);
        case Feature of
          cfAES: Result := (R.ECX and $02000000) <> 0;
          cfSSE2: Result := (R.EDX and $04000000) <> 0;
          cfSSSE3: Result := (R.ECX and $00000200) <> 0;
          cfSSE42: Result := (R.ECX and $00100000) <> 0;
          cfPOPCNT: Result := (R.ECX and $00800000) <> 0;
          cfPCLMULQDQ: Result := (R.ECX and $00000002) <> 0;
        end;
      end;
    cfSHA, cfBMI1:
      begin
        R := System.GetCPUID(0);
        if R.EAX < 7 then Exit;
        R := System.GetCPUID(7, 0);
        if Feature = cfSHA then Result := (R.EBX and $20000000) <> 0 else Result := (R.EBX and $00000008) <> 0;
      end;
    cfLZCNT:
      begin
        R := System.GetCPUID($80000000);
        if R.EAX < $80000001 then Exit;
        R := System.GetCPUID($80000001);
        Result := (R.ECX and $00000020) <> 0;
      end;
  end;
end;

end.
