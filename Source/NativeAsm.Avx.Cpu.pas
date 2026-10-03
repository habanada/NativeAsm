unit NativeAsm.Avx.Cpu;

{$ALIGN ON}
{$MINENUMSIZE 4}

interface

type
  TAvxCpuStatus = record
    CpuXsave: Boolean;
    OsXsave: Boolean;
    CpuAvx: Boolean;
    CpuAvx2: Boolean;
    CpuFma: Boolean;
    Xcr0: UInt64;
    XmmState: Boolean;
    YmmState: Boolean;
    function AvxUsable: Boolean;
    function Avx2Usable: Boolean;
    function FmaUsable: Boolean;
  end;

  TAvxCpuFeatures = class sealed
  private
    class function ReadXcr0: UInt64; static;
  public
    class function Query: TAvxCpuStatus; static;
    class function SupportsAvx: Boolean; static;
    class function SupportsAvx2: Boolean; static;
    class function SupportsFma: Boolean; static;
  end;

implementation

uses
  NativeAsm.Builder,
  NativeAsm.Extensions;

function TAvxCpuStatus.AvxUsable: Boolean;
begin
  Result := CpuXsave and OsXsave and CpuAvx and XmmState and YmmState;
end;

function TAvxCpuStatus.Avx2Usable: Boolean;
begin
  Result := AvxUsable and CpuAvx2;
end;

function TAvxCpuStatus.FmaUsable: Boolean;
begin
  Result := AvxUsable and CpuFma;
end;

class function TAvxCpuFeatures.ReadXcr0: UInt64;
var
  B: TAsmBuilder;
  Exe: TExecutableCode;
begin
  B := TAsmBuilder.New;
  try
    B.EmitBytes([$31, $C9, $0F, $01, $D0, $48, $C1, $E2, $20, $48, $09, $D0, $C3]);
    Exe := TExecutableCode.FromBuilder(B);
    try
      Result := Exe.Run;
    finally
      Exe.Free;
    end;
  finally
    B.Free;
  end;
end;

class function TAvxCpuFeatures.Query: TAvxCpuStatus;
var
  MaxLeaf: Cardinal;
  R: System.TCPUIDRec;
begin
  Result := Default(TAvxCpuStatus);
  R := System.GetCPUID(0);
  MaxLeaf := R.EAX;
  if MaxLeaf < 1 then Exit;

  R := System.GetCPUID(1);
  Result.CpuXsave := (R.ECX and $04000000) <> 0;
  Result.OsXsave := (R.ECX and $08000000) <> 0;
  Result.CpuAvx := (R.ECX and $10000000) <> 0;
  Result.CpuFma := (R.ECX and $00001000) <> 0;

  if Result.CpuXsave and Result.OsXsave then
  begin
    Result.Xcr0 := ReadXcr0;
    Result.XmmState := (Result.Xcr0 and $2) <> 0;
    Result.YmmState := (Result.Xcr0 and $4) <> 0;
  end;

  if MaxLeaf >= 7 then
  begin
    R := System.GetCPUID(7, 0);
    Result.CpuAvx2 := (R.EBX and $00000020) <> 0;
  end;
end;

class function TAvxCpuFeatures.SupportsAvx: Boolean;
var
  S: TAvxCpuStatus;
begin
  S := Query;
  Result := S.AvxUsable;
end;

class function TAvxCpuFeatures.SupportsAvx2: Boolean;
var
  S: TAvxCpuStatus;
begin
  S := Query;
  Result := S.Avx2Usable;
end;

class function TAvxCpuFeatures.SupportsFma: Boolean;
var
  S: TAvxCpuStatus;
begin
  S := Query;
  Result := S.FmaUsable;
end;

end.
