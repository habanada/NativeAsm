{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
unit NativeAsm.Algorithms.BloomFilter;

interface

uses
  System.SysUtils,
  NativeAsm.Algorithms.Hash64;

type
  TBloomFilter = class
  private
    FWords: TArray<UInt64>;
    FBitCount: NativeUInt;
    FHashCount: Integer;
    FHash: THash64Jit;
    class procedure ValidateBuffer(Buffer: Pointer; Length: NativeUInt); static;
    procedure GetHashes(Buffer: Pointer; Length: NativeUInt; out H1, H2: UInt64);
  public
    constructor Create(BitCount: NativeUInt; HashCount: Integer = 7);
    destructor Destroy; override;
    procedure Clear;
    procedure Add(Buffer: Pointer; Length: NativeUInt); overload;
    procedure Add(const Data: TBytes); overload;
    function Contains(Buffer: Pointer; Length: NativeUInt): Boolean; overload;
    function Contains(const Data: TBytes): Boolean; overload;
    property BitCount: NativeUInt read FBitCount;
    property HashCount: Integer read FHashCount;
  end;

implementation

class procedure TBloomFilter.ValidateBuffer(Buffer: Pointer; Length: NativeUInt);
begin
  if (Buffer = nil) and (Length <> 0) then raise EArgumentNilException.Create('Buffer');
end;

constructor TBloomFilter.Create(BitCount: NativeUInt; HashCount: Integer);
var
  WordCount: NativeUInt;
begin
  inherited Create;
  if BitCount = 0 then raise EArgumentOutOfRangeException.Create('BitCount');
  if (HashCount < 1) or (HashCount > 32) then raise EArgumentOutOfRangeException.Create('HashCount');
  if BitCount > High(NativeUInt) - 63 then raise ERangeError.Create('Bloom filter size overflow');
  WordCount := (BitCount + 63) div 64;
  if WordCount > NativeUInt(MaxInt) then raise ERangeError.Create('Bloom filter exceeds Delphi array limits');
  FBitCount := WordCount * 64;
  FHashCount := HashCount;
  SetLength(FWords, Integer(WordCount));
  FHash := THash64Jit.Create;
end;

destructor TBloomFilter.Destroy;
begin
  FHash.Free;
  inherited;
end;

procedure TBloomFilter.Clear;
begin
  if Length(FWords) <> 0 then FillChar(FWords[0], NativeInt(NativeUInt(Length(FWords)) * SizeOf(UInt64)), 0);
end;

procedure TBloomFilter.GetHashes(Buffer: Pointer; Length: NativeUInt; out H1, H2: UInt64);
begin
  H1 := FHash.Hash(Buffer, Length);
  H2 := FHash.Mix(H1 xor UInt64($9E3779B97F4A7C15)) or UInt64(1);
end;

procedure TBloomFilter.Add(Buffer: Pointer; Length: NativeUInt);
var
  H1, H2, Position: UInt64;
  I: Integer;
begin
  ValidateBuffer(Buffer, Length);
  GetHashes(Buffer, Length, H1, H2);
  for I := 0 to FHashCount - 1 do
  begin
    Position := (H1 + UInt64(I) * H2) mod UInt64(FBitCount);
    FWords[Integer(Position shr 6)] := FWords[Integer(Position shr 6)] or (UInt64(1) shl (Position and 63));
  end;
end;

procedure TBloomFilter.Add(const Data: TBytes);
begin
  if Length(Data) = 0 then Add(nil, 0) else Add(@Data[0], NativeUInt(Length(Data)));
end;

function TBloomFilter.Contains(Buffer: Pointer; Length: NativeUInt): Boolean;
var
  H1, H2, Position: UInt64;
  I: Integer;
begin
  ValidateBuffer(Buffer, Length);
  GetHashes(Buffer, Length, H1, H2);
  for I := 0 to FHashCount - 1 do
  begin
    Position := (H1 + UInt64(I) * H2) mod UInt64(FBitCount);
    if (FWords[Integer(Position shr 6)] and (UInt64(1) shl (Position and 63))) = 0 then Exit(False);
  end;
  Result := True;
end;

function TBloomFilter.Contains(const Data: TBytes): Boolean;
begin
  if Length(Data) = 0 then Result := Contains(nil, 0) else Result := Contains(@Data[0], NativeUInt(Length(Data)));
end;

end.
