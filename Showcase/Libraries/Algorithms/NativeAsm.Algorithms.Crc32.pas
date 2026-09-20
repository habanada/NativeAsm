{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
unit NativeAsm.Algorithms.Crc32;

interface

uses
  System.SysUtils,
  NativeAsm.Types,
  NativeAsm.Builder,
  NativeAsm.Extensions,
  NativeAsm.CpuFeatures;

type
  TCrc32Mode = (crc32mAuto, crc32mScalar, crc32mPclmul);

  TCrc32Jit = class
  private type
    TCrc32Table = array[0..255] of Cardinal;
    TQWord2 = array[0..1] of UInt64;
  private
    FCode: TExecutableCode;
    FTable: TCrc32Table;
    FK3K4: TQWord2;
    FK5K0: TQWord2;
    FU: TQWord2;
    FMaskZ: TQWord2;
    FMode: TCrc32Mode;
    class procedure BuildTable(var Table: TCrc32Table); static;
    procedure BuildConstants;
    function BuildScalarKernel: TExecutableCode;
    function BuildPclmulKernel: TExecutableCode;
    class function ResolveMode(Mode: TCrc32Mode): TCrc32Mode; static;
  public
    constructor Create(Mode: TCrc32Mode = crc32mAuto);
    destructor Destroy; override;
    function Compute(Buffer: Pointer; Length: NativeUInt; Initial: Cardinal = 0): Cardinal; overload;
    function Compute(const Data: TBytes; Initial: Cardinal = 0): Cardinal; overload;
    class function IsPclmulAvailable: Boolean; static;
    property Mode: TCrc32Mode read FMode;
  end;

implementation

uses
  NativeAsm.Simd,
  NativeAsm.Simd.Types;

class procedure TCrc32Jit.BuildTable(var Table: TCrc32Table);
const
  Polynomial = Cardinal($EDB88320);
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

procedure TCrc32Jit.BuildConstants;
begin
  FK3K4[0] := UInt64($00000001751997D0);
  FK3K4[1] := UInt64($00000000CCAA009E);
  FK5K0[0] := UInt64($0000000163CD6124);
  FK5K0[1] := 0;
  FU[0] := UInt64($00000001DB710641);
  FU[1] := UInt64($00000001F7011641);
  FMaskZ[0] := UInt64($00000000FFFFFFFF);
  FMaskZ[1] := UInt64($00000000FFFFFFFF);
end;

function TCrc32Jit.BuildScalarKernel: TExecutableCode;
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

function TCrc32Jit.BuildPclmulKernel: TExecutableCode;
var
  B: TAsmBuilder;
  LVectorLoop, LVectorReduce, LScalar, LScalarSetup, LScalarLoop, LScalarDone, LReturn: TLabel;
begin
  B := TAsmBuilder.Create;
  try
    LVectorLoop := B.NewLabel;
    LVectorReduce := B.NewLabel;
    LScalar := B.NewLabel;
    LScalarSetup := B.NewLabel;
    LScalarLoop := B.NewLabel;
    LScalarDone := B.NewLabel;
    LReturn := B.NewLabel;

    B.Cmp(RDX, 16).J(cond_JB, LScalar);
    B.Mov(R9, RDX).And_(R9, -16).Mov(R11, RDX).Sub(R11, R9);
    B.Mov(EAX, R8D).Not_(EAX).Movd(XMM0, EAX).Movdqu(XMM1, NativeAsm.Simd.Types.OWordPtr(ridRCX)).Pxor(XMM0, XMM1);
    B.Mov(R10, Int64(NativeUInt(@FK3K4[0]))).Movdqu(XMM5, NativeAsm.Simd.Types.OWordPtr(ridR10));
    B.Add(RCX, 16).Sub(R9, 16).Cmp(R9, 16).J(cond_JB, LVectorReduce);
    B.Bind(LVectorLoop);
    B.Movdqa(XMM1, XMM0).Pclmulqdq(XMM1, XMM5, $11);
    B.Movdqa(XMM2, XMM0).Pclmulqdq(XMM2, XMM5, $00);
    B.Movdqu(XMM3, NativeAsm.Simd.Types.OWordPtr(ridRCX)).Pxor(XMM1, XMM3).Pxor(XMM1, XMM2).Movdqa(XMM0, XMM1);
    B.Add(RCX, 16).Sub(R9, 16).Cmp(R9, 16).J(cond_JAE, LVectorLoop);

    B.Bind(LVectorReduce);
    B.Movdqa(XMM1, XMM0).Pclmulqdq(XMM1, XMM5, $10).Psrldq(XMM0, 8).Pxor(XMM0, XMM1);
    B.Mov(R10, Int64(NativeUInt(@FMaskZ[0]))).Movdqu(XMM3, NativeAsm.Simd.Types.OWordPtr(ridR10));
    B.Movdqa(XMM1, XMM0).Pand(XMM1, XMM3).Mov(R10, Int64(NativeUInt(@FK5K0[0]))).Movq(XMM2, QWordPtr(ridR10)).Pclmulqdq(XMM1, XMM2, $00);
    B.Movdqa(XMM2, XMM0).Psrldq(XMM2, 4).Movdqa(XMM0, XMM1).Pxor(XMM0, XMM2);
    B.Mov(R10, Int64(NativeUInt(@FU[0]))).Movdqu(XMM4, NativeAsm.Simd.Types.OWordPtr(ridR10));
    B.Movdqa(XMM1, XMM0).Pand(XMM1, XMM3).Pclmulqdq(XMM1, XMM4, $10).Pand(XMM1, XMM3).Pclmulqdq(XMM1, XMM4, $00).Pxor(XMM0, XMM1);
    B.Psrldq(XMM0, 4).Movd(EAX, XMM0).Not_(EAX).Test(R11, R11).J(cond_JE, LReturn).Mov(RDX, R11).J(cond_JMP, LScalarSetup);

    B.Bind(LScalar).Mov(EAX, R8D);
    B.Bind(LScalarSetup).Not_(EAX).Mov(R9, Int64(NativeUInt(@FTable[0]))).Test(RDX, RDX).J(cond_JE, LScalarDone);
    B.Bind(LScalarLoop);
    B.Movzx(R10D, BytePtr(ridRCX)).Xor_(R10D, EAX).And_(R10D, $FF).Shr_(EAX, 8);
    B.Mov(R8D, TMemory.CreateSib(ridR9, ridR10, s4, 0, sz32)).Xor_(EAX, R8D).Inc_(RCX).Dec_(RDX).J(cond_JNE, LScalarLoop);
    B.Bind(LScalarDone).Not_(EAX);
    B.Bind(LReturn).Ret;
    Result := TExecutableCode.FromBuilder(B);
  finally
    B.Free;
  end;
end;

class function TCrc32Jit.IsPclmulAvailable: Boolean;
begin
  Result := TCpuFeatures.Supports(cfSSE2) and TCpuFeatures.Supports(cfPCLMULQDQ);
end;

class function TCrc32Jit.ResolveMode(Mode: TCrc32Mode): TCrc32Mode;
begin
  case Mode of
    crc32mAuto: if IsPclmulAvailable then Result := crc32mPclmul else Result := crc32mScalar;
    crc32mScalar: Result := crc32mScalar;
    crc32mPclmul:
      begin
        if not IsPclmulAvailable then raise EInvalidOp.Create('PCLMULQDQ is not available on this CPU');
        Result := crc32mPclmul;
      end;
  else
    raise EArgumentException.Create('Invalid CRC32 mode');
  end;
end;

constructor TCrc32Jit.Create(Mode: TCrc32Mode);
begin
  inherited Create;
  BuildTable(FTable);
  BuildConstants;
  FMode := ResolveMode(Mode);
  if FMode = crc32mPclmul then FCode := BuildPclmulKernel else FCode := BuildScalarKernel;
end;

destructor TCrc32Jit.Destroy;
begin
  FCode.Free;
  inherited;
end;

function TCrc32Jit.Compute(Buffer: Pointer; Length: NativeUInt; Initial: Cardinal): Cardinal;
begin
  if (Buffer = nil) and (Length <> 0) then raise EArgumentNilException.Create('Buffer');
  Result := Cardinal(FCode.Run(UInt64(NativeUInt(Buffer)), UInt64(Length), UInt64(Initial)));
end;

function TCrc32Jit.Compute(const Data: TBytes; Initial: Cardinal): Cardinal;
begin
  if Length(Data) = 0 then Exit(Compute(nil, 0, Initial));
  Result := Compute(@Data[0], NativeUInt(Length(Data)), Initial);
end;

end.
