{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
unit NativeAsm.Algorithms.Hash64;

interface

uses
  System.SysUtils,
  NativeAsm.Types,
  NativeAsm.Builder,
  NativeAsm.Extensions;

type
  THash64Jit = class
  public const
    Fnv1aOffsetBasis = UInt64($CBF29CE484222325);
    Fnv1aPrime = UInt64($00000100000001B3);
  private
    FHashCode: TExecutableCode;
    FMixCode: TExecutableCode;
    class function BuildHashKernel: TExecutableCode; static;
    class function BuildMixKernel: TExecutableCode; static;
  public
    constructor Create;
    destructor Destroy; override;
    function Hash(Buffer: Pointer; Length: NativeUInt; Initial: UInt64 = $CBF29CE484222325): UInt64; overload;
    function Hash(const Data: TBytes; Initial: UInt64 = $CBF29CE484222325): UInt64; overload;
    function Mix(Value: UInt64): UInt64;
  end;

implementation

class function THash64Jit.BuildHashKernel: TExecutableCode;
var
  B: TAsmBuilder;
  LLoop, LDone: TLabel;
begin
  B := TAsmBuilder.Create;
  try
    LLoop := B.NewLabel;
    LDone := B.NewLabel;
    B.Mov(RAX, R8).Mov(R10, Int64(Fnv1aPrime)).Test(RDX, RDX).J(cond_JE, LDone).Bind(LLoop);
    B.Movzx(R9D, BytePtr(ridRCX)).Xor_(RAX, R9).Imul(RAX, R10).Inc_(RCX).Dec_(RDX).J(cond_JNE, LLoop).Bind(LDone).Ret;
    Result := TExecutableCode.FromBuilder(B);
  finally
    B.Free;
  end;
end;

class function THash64Jit.BuildMixKernel: TExecutableCode;
var
  B: TAsmBuilder;
begin
  B := TAsmBuilder.Create;
  try
    B.Mov(RAX, RCX).Mov(R9, RAX).Shr_(R9, 30).Xor_(RAX, R9).Mov(R10, -4658895280553007687).Imul(RAX, R10);
    B.Mov(R9, RAX).Shr_(R9, 27).Xor_(RAX, R9).Mov(R10, -7723592293110705685).Imul(RAX, R10);
    B.Mov(R9, RAX).Shr_(R9, 31).Xor_(RAX, R9).Ret;
    Result := TExecutableCode.FromBuilder(B);
  finally
    B.Free;
  end;
end;

constructor THash64Jit.Create;
begin
  inherited Create;
  FHashCode := BuildHashKernel;
  FMixCode := BuildMixKernel;
end;

destructor THash64Jit.Destroy;
begin
  FMixCode.Free;
  FHashCode.Free;
  inherited;
end;

function THash64Jit.Hash(Buffer: Pointer; Length: NativeUInt; Initial: UInt64): UInt64;
begin
  if (Buffer = nil) and (Length <> 0) then raise EArgumentNilException.Create('Buffer');
  Result := FHashCode.Run(UInt64(NativeUInt(Buffer)), UInt64(Length), Initial);
end;

function THash64Jit.Hash(const Data: TBytes; Initial: UInt64): UInt64;
begin
  if Length(Data) = 0 then Exit(Hash(nil, 0, Initial));
  Result := Hash(@Data[0], NativeUInt(Length(Data)), Initial);
end;

function THash64Jit.Mix(Value: UInt64): UInt64;
begin
  Result := FMixCode.Run(Value);
end;

end.
