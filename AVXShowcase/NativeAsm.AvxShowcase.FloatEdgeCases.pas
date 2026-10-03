unit NativeAsm.AvxShowcase.FloatEdgeCases;

interface

uses
  NativeAsm.Extensions,
  NativeAsm.AvxShowcase.Types;

type
  TFloatEdgeBlock = packed record
    A: TSingle8;
    B: TSingle8;
    Lo: TSingle8;
    Hi: TSingle8;
    MinOut: TSingle8;
    MaxOut: TSingle8;
    ClampOut: TSingle8;
    UnorderedMask: TCardinal8;
    OrderedMask: TCardinal8;
  end;

  TNativeAsmFloatEdgeCases = class sealed
  private
    class function Kernel: TExecutableCode; static;
  public
    class function IsSupported: Boolean; static;
    class procedure Evaluate(var Block: TFloatEdgeBlock); static;
    class function VerifySpecialMatrix(out Failure: string): Boolean; static;
    class function X86MinBits(A, B: Cardinal): Cardinal; static;
    class function X86MaxBits(A, B: Cardinal): Cardinal; static;
    class function X86ClampBits(Value, Lo, Hi: Cardinal): Cardinal; static;
  end;

function SingleFromBits(Bits: Cardinal): Single;
function SingleBits(Value: Single): Cardinal;
function IsNaNBits(Bits: Cardinal): Boolean;

implementation

uses
  System.SysUtils,
  NativeAsm.Types,
  NativeAsm.Builder,
  NativeAsm.Avx.Types,
  NativeAsm.Avx.Cpu,
  NativeAsm.Avx;

const
  OFS_A = 0;
  OFS_B = 32;
  OFS_LO = 64;
  OFS_HI = 96;
  OFS_MIN = 128;
  OFS_MAX = 160;
  OFS_CLAMP = 192;
  OFS_UNORDERED = 224;
  OFS_ORDERED = 256;
  SPECIAL_COUNT = 10;

var
  GFloatEdgeKernel: TExecutableCode;

function SingleFromBits(Bits: Cardinal): Single;
begin
  Move(Bits, Result, SizeOf(Result));
end;

function SingleBits(Value: Single): Cardinal;
begin
  Move(Value, Result, SizeOf(Result));
end;

function IsNaNBits(Bits: Cardinal): Boolean;
begin
  Result := ((Bits and $7F800000) = $7F800000) and ((Bits and $007FFFFF) <> 0);
end;

function BuildFloatEdgeKernel: TExecutableCode;
var
  B: TAsmBuilder;
begin
  B := TAsmBuilder.New;
  try
    B.Vmovups(YMM0, YmmWordPtr(ridRCX, OFS_A));
    B.Vmovups(YMM1, YmmWordPtr(ridRCX, OFS_B));
    B.Vminps(YMM2, YMM0, YMM1);
    B.Vmaxps(YMM3, YMM0, YMM1);
    B.Vmovups(YmmWordPtr(ridRCX, OFS_MIN), YMM2);
    B.Vmovups(YmmWordPtr(ridRCX, OFS_MAX), YMM3);
    B.Vmovups(YMM4, YmmWordPtr(ridRCX, OFS_LO));
    B.Vmaxps(YMM5, YMM0, YMM4);
    B.Vmovups(YMM4, YmmWordPtr(ridRCX, OFS_HI));
    B.Vminps(YMM5, YMM5, YMM4);
    B.Vmovups(YmmWordPtr(ridRCX, OFS_CLAMP), YMM5);
    B.Vcmpps(YMM2, YMM0, YMM1, $03);
    B.Vcmpps(YMM3, YMM0, YMM1, $07);
    B.Vmovups(YmmWordPtr(ridRCX, OFS_UNORDERED), YMM2);
    B.Vmovups(YmmWordPtr(ridRCX, OFS_ORDERED), YMM3);
    B.Vzeroupper.Ret;
    Result := TExecutableCode.Create(B.Build);
  finally
    B.Free;
  end;
end;

class function TNativeAsmFloatEdgeCases.Kernel: TExecutableCode;
begin
  if GFloatEdgeKernel = nil then GFloatEdgeKernel := BuildFloatEdgeKernel;
  Result := GFloatEdgeKernel;
end;

class function TNativeAsmFloatEdgeCases.IsSupported: Boolean;
begin
  Result := TAvxCpuFeatures.SupportsAvx;
end;

class procedure TNativeAsmFloatEdgeCases.Evaluate(var Block: TFloatEdgeBlock);
begin
  if not IsSupported then raise ENotSupportedException.Create('float edge-case showcase requires AVX');
  Kernel.Run(UInt64(NativeUInt(@Block)));
end;

class function TNativeAsmFloatEdgeCases.X86MinBits(A, B: Cardinal): Cardinal;
var
  SA, SB: Single;
begin
  if IsNaNBits(A) or IsNaNBits(B) then Exit(B);
  SA := SingleFromBits(A);
  SB := SingleFromBits(B);
  if SA < SB then Result := A else Result := B;
end;

class function TNativeAsmFloatEdgeCases.X86MaxBits(A, B: Cardinal): Cardinal;
var
  SA, SB: Single;
begin
  if IsNaNBits(A) or IsNaNBits(B) then Exit(B);
  SA := SingleFromBits(A);
  SB := SingleFromBits(B);
  if SA > SB then Result := A else Result := B;
end;

class function TNativeAsmFloatEdgeCases.X86ClampBits(Value, Lo, Hi: Cardinal): Cardinal;
begin
  Result := X86MinBits(X86MaxBits(Value, Lo), Hi);
end;

class function TNativeAsmFloatEdgeCases.VerifySpecialMatrix(out Failure: string): Boolean;
const
  Values: array[0..SPECIAL_COUNT - 1] of Cardinal = (
    $00000000,
    $80000000,
    $3F800000,
    $BF800000,
    $7F800000,
    $FF800000,
    $7FC12345,
    $7FC54321,
    $7F7FFFFF,
    $FF7FFFFF
  );
  LoBits = $BF800000;
  HiBits = $3F800000;
var
  Block: TFloatEdgeBlock;
  PairIndex, Lane, AIndex, BIndex: Integer;
  ABit, BBit, ExpectedMin, ExpectedMax, ExpectedClamp: Cardinal;
  ExpectedUnordered, ExpectedOrdered: Cardinal;
begin
  Failure := '';
  Result := False;
  if not IsSupported then
  begin
    Failure := 'AVX not supported';
    Exit;
  end;

  PairIndex := 0;
  while PairIndex < SPECIAL_COUNT * SPECIAL_COUNT do
  begin
    FillChar(Block, SizeOf(Block), 0);
    for Lane := 0 to 7 do
    begin
      if PairIndex + Lane < SPECIAL_COUNT * SPECIAL_COUNT then
      begin
        AIndex := (PairIndex + Lane) div SPECIAL_COUNT;
        BIndex := (PairIndex + Lane) mod SPECIAL_COUNT;
        Block.A[Lane] := SingleFromBits(Values[AIndex]);
        Block.B[Lane] := SingleFromBits(Values[BIndex]);
      end;
      Block.Lo[Lane] := SingleFromBits(LoBits);
      Block.Hi[Lane] := SingleFromBits(HiBits);
    end;

    Evaluate(Block);

    for Lane := 0 to 7 do
    begin
      if PairIndex + Lane >= SPECIAL_COUNT * SPECIAL_COUNT then Break;
      AIndex := (PairIndex + Lane) div SPECIAL_COUNT;
      BIndex := (PairIndex + Lane) mod SPECIAL_COUNT;
      ABit := Values[AIndex];
      BBit := Values[BIndex];
      ExpectedMin := X86MinBits(ABit, BBit);
      ExpectedMax := X86MaxBits(ABit, BBit);
      ExpectedClamp := X86ClampBits(ABit, LoBits, HiBits);
      if IsNaNBits(ABit) or IsNaNBits(BBit) then ExpectedUnordered := $FFFFFFFF else ExpectedUnordered := 0;
      if ExpectedUnordered = 0 then ExpectedOrdered := $FFFFFFFF else ExpectedOrdered := 0;

      if SingleBits(Block.MinOut[Lane]) <> ExpectedMin then
      begin
        Failure := Format('VMINPS pair %d/%d expected $%.8x got $%.8x', [AIndex, BIndex, ExpectedMin, SingleBits(Block.MinOut[Lane])]);
        Exit;
      end;
      if SingleBits(Block.MaxOut[Lane]) <> ExpectedMax then
      begin
        Failure := Format('VMAXPS pair %d/%d expected $%.8x got $%.8x', [AIndex, BIndex, ExpectedMax, SingleBits(Block.MaxOut[Lane])]);
        Exit;
      end;
      if SingleBits(Block.ClampOut[Lane]) <> ExpectedClamp then
      begin
        Failure := Format('clamp pair %d/%d expected $%.8x got $%.8x', [AIndex, BIndex, ExpectedClamp, SingleBits(Block.ClampOut[Lane])]);
        Exit;
      end;
      if Block.UnorderedMask[Lane] <> ExpectedUnordered then
      begin
        Failure := Format('UNORD mask pair %d/%d expected $%.8x got $%.8x', [AIndex, BIndex, ExpectedUnordered, Block.UnorderedMask[Lane]]);
        Exit;
      end;
      if Block.OrderedMask[Lane] <> ExpectedOrdered then
      begin
        Failure := Format('ORD mask pair %d/%d expected $%.8x got $%.8x', [AIndex, BIndex, ExpectedOrdered, Block.OrderedMask[Lane]]);
        Exit;
      end;
    end;
    Inc(PairIndex, 8);
  end;

  Result := True;
end;

initialization
  GFloatEdgeKernel := nil;

finalization
  GFloatEdgeKernel.Free;

end.
