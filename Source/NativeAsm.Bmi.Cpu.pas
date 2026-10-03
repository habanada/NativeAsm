unit NativeAsm.Bmi.Cpu;

interface

type
  TBmiCpuStatus = record
    CpuBmi1: Boolean;
    CpuBmi2: Boolean;
  end;

  TBmiCpuFeatures = class sealed
  public
    class function Query: TBmiCpuStatus; static;
    class function SupportsBmi1: Boolean; static;
    class function SupportsBmi2: Boolean; static;
  end;

implementation

class function TBmiCpuFeatures.Query: TBmiCpuStatus;
var
  R: System.TCPUIDRec;
begin
  Result := Default(TBmiCpuStatus);
  R := System.GetCPUID(0);
  if R.EAX < 7 then Exit;
  R := System.GetCPUID(7, 0);
  Result.CpuBmi1 := (R.EBX and $00000008) <> 0;
  Result.CpuBmi2 := (R.EBX and $00000100) <> 0;
end;

class function TBmiCpuFeatures.SupportsBmi1: Boolean;
var
  Status: TBmiCpuStatus;
begin
  Status := Query;
  Result := Status.CpuBmi1;
end;

class function TBmiCpuFeatures.SupportsBmi2: Boolean;
var
  Status: TBmiCpuStatus;
begin
  Status := Query;
  Result := Status.CpuBmi2;
end;

end.
