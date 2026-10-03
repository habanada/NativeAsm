unit NativeAsm.ByteBuffer;

{$ALIGN ON}
{$MINENUMSIZE 4}

interface

uses
  System.SysUtils;

type
  TAsmByteBuffer = record
  private
    FData: TBytes;
    FCount: Integer;
  public
    procedure Init(InitialCapacity: Integer);
    procedure Put(B: Byte);
    procedure PutInt32(V: Integer);
    function Finish: TBytes;
  end;

implementation

procedure TAsmByteBuffer.Init(InitialCapacity: Integer);
begin
  if InitialCapacity < 1 then InitialCapacity := 1;
  SetLength(FData, InitialCapacity);
  FCount := 0;
end;

procedure TAsmByteBuffer.Put(B: Byte);
begin
  if FCount >= Length(FData) then SetLength(FData, Length(FData) * 2);
  FData[FCount] := B;
  Inc(FCount);
end;

procedure TAsmByteBuffer.PutInt32(V: Integer);
var
  U: Cardinal absolute V;
begin
  Put(Byte(U));
  Put(Byte(U shr 8));
  Put(Byte(U shr 16));
  Put(Byte(U shr 24));
end;

function TAsmByteBuffer.Finish: TBytes;
begin
  SetLength(FData, FCount);
  Result := FData;
end;

end.
