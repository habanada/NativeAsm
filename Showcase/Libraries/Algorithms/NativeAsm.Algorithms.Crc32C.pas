{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
unit NativeAsm.Algorithms.Crc32C;

interface

uses
  System.SysUtils,
  NativeAsm.Types,
  NativeAsm.Builder,
  NativeAsm.Extensions,
  NativeAsm.CpuFeatures;

type
  TCrc32CMode = (cmAuto, cmScalar, cmSse42);

  TCrc32CJit = class
  private type
    TCrc32CTable = array[0..255] of Cardinal;
  private
    FCode: TExecutableCode;
    FTable: TCrc32CTable;
    FMode: TCrc32CMode;
    class procedure BuildTable(var Table: TCrc32CTable); static;
    function BuildScalarKernel: TExecutableCode;
    class function BuildSse42Kernel: TExecutableCode; static;
  public
    constructor Create(Mode: TCrc32CMode = cmAuto);
    destructor Destroy; override;
    function Compute(Buffer: Pointer; Length: NativeUInt; Initial: Cardinal = 0): Cardinal; overload;
    function Compute(const Data: TBytes; Initial: Cardinal = 0): Cardinal; overload;
    class function IsSse42Available: Boolean; static;
    property Mode: TCrc32CMode read FMode;
  end;

implementation

uses
  NativeAsm.Simd;

class procedure TCrc32CJit.BuildTable(var Table: TCrc32CTable);
const
  Polynomial = Cardinal($82F63B78);
var
  I, J: Integer;
  C: Cardinal;
begin
  for I := 0 to 255 do
  begin
    C := Cardinal(I);
    for J := 0 to 7 do
      if (C and 1) <> 0 then C := (C shr 1) xor Polynomial else C := C shr 1;
    Table[I] := C;
  end;
end;

function TCrc32CJit.BuildScalarKernel: TExecutableCode;
var
  B: TAsmBuilder;
  LLoop, LDone: TLabel;
begin
  B := TAsmBuilder.Create;
  try
    LLoop := B.NewLabel;
    LDone := B.NewLabel;
    B.Mov(EAX, R8D).Not_(EAX).Mov(R9, Int64(NativeUInt(@FTable[0]))).Test(RDX, RDX).J(cond_JE, LDone);
    B.Bind(LLoop);
    B.Movzx(R10D, BytePtr(ridRCX)).Xor_(R10D, EAX).And_(R10D, $FF).Shr_(EAX, 8);
    B.Mov(R11D, TMemory.CreateSib(ridR9, ridR10, s4, 0, sz32)).Xor_(EAX, R11D).Inc_(RCX).Dec_(RDX).J(cond_JNE, LLoop);
    B.Bind(LDone).Not_(EAX).Ret;
    Result := TExecutableCode.FromBuilder(B);
  finally
    B.Free;
  end;
end;

class function TCrc32CJit.BuildSse42Kernel: TExecutableCode;
var
  B: TAsmBuilder;
  LQwordLoop, LByteLoop, LByteCheck, LDone: TLabel;
begin
  B := TAsmBuilder.Create;
  try
    LQwordLoop := B.NewLabel;
    LByteLoop := B.NewLabel;
    LByteCheck := B.NewLabel;
    LDone := B.NewLabel;
    B.Mov(EAX, R8D).Not_(EAX).Cmp(RDX, 8).J(cond_JB, LByteCheck);
    B.Bind(LQwordLoop);
    B.Crc32(RAX, QWordPtr(ridRCX)).Add(RCX, 8).Sub(RDX, 8).Cmp(RDX, 8).J(cond_JAE, LQwordLoop);
    B.Bind(LByteCheck).Test(RDX, RDX).J(cond_JE, LDone);
    B.Bind(LByteLoop);
    B.Crc32(EAX, BytePtr(ridRCX)).Inc_(RCX).Dec_(RDX).J(cond_JNE, LByteLoop);
    B.Bind(LDone).Not_(EAX).Ret;
    Result := TExecutableCode.FromBuilder(B);
  finally
    B.Free;
  end;
end;

constructor TCrc32CJit.Create(Mode: TCrc32CMode);
begin
  inherited Create;
  BuildTable(FTable);
  case Mode of
    cmAuto: if IsSse42Available then FMode := cmSse42 else FMode := cmScalar;
    cmScalar: FMode := cmScalar;
    cmSse42:
      begin
        if not IsSse42Available then raise EInvalidOp.Create('SSE4.2 is not available on this CPU');
        FMode := cmSse42;
      end;
  else
    raise EArgumentException.Create('Invalid CRC32C mode');
  end;
  if FMode = cmSse42 then FCode := BuildSse42Kernel else FCode := BuildScalarKernel;
end;

destructor TCrc32CJit.Destroy;
begin
  FCode.Free;
  inherited;
end;

function TCrc32CJit.Compute(Buffer: Pointer; Length: NativeUInt; Initial: Cardinal): Cardinal;
begin
  if (Buffer = nil) and (Length <> 0) then raise EArgumentNilException.Create('Buffer');
  Result := Cardinal(FCode.Run(UInt64(NativeUInt(Buffer)), UInt64(Length), UInt64(Initial)));
end;

function TCrc32CJit.Compute(const Data: TBytes; Initial: Cardinal): Cardinal;
begin
  if Length(Data) = 0 then Exit(Compute(nil, 0, Initial));
  Result := Compute(@Data[0], NativeUInt(Length(Data)), Initial);
end;

class function TCrc32CJit.IsSse42Available: Boolean;
begin
  Result := TCpuFeatures.Supports(cfSSE42);
end;

end.
