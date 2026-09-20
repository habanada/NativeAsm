{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
unit NativeAsm.BigInt.Fields;

interface

uses
  System.SysUtils,
  NativeAsm.BigInt.Types,
  NativeAsm.BigInt.Montgomery;

type
  TPrimeFieldId = (pfSecp256k1, pfP256, pfP384, pfP521, pfCurve25519, pfCurve448);
  TPrimeFieldFactory = class sealed
  public
    class function Modulus(Id: TPrimeFieldId): TBigIntLimbs; static;
    class function CreateContext(Id: TPrimeFieldId): TMontgomeryContext; static;
  end;

implementation

class function TPrimeFieldFactory.Modulus(Id: TPrimeFieldId): TBigIntLimbs;
begin
  case Id of
    pfSecp256k1:
    begin
      SetLength(Result, 4);
      Result[0] := $FFFFFFFEFFFFFC2F;
      Result[1] := $FFFFFFFFFFFFFFFF;
      Result[2] := $FFFFFFFFFFFFFFFF;
      Result[3] := $FFFFFFFFFFFFFFFF;
    end;
    pfP256:
    begin
      SetLength(Result, 4);
      Result[0] := $FFFFFFFFFFFFFFFF;
      Result[1] := $00000000FFFFFFFF;
      Result[2] := $0000000000000000;
      Result[3] := $FFFFFFFF00000001;
    end;
    pfP384:
    begin
      SetLength(Result, 6);
      Result[0] := $00000000FFFFFFFF;
      Result[1] := $FFFFFFFF00000000;
      Result[2] := $FFFFFFFFFFFFFFFE;
      Result[3] := $FFFFFFFFFFFFFFFF;
      Result[4] := $FFFFFFFFFFFFFFFF;
      Result[5] := $FFFFFFFFFFFFFFFF;
    end;
    pfP521:
    begin
      SetLength(Result, 9);
      Result[0] := $FFFFFFFFFFFFFFFF;
      Result[1] := $FFFFFFFFFFFFFFFF;
      Result[2] := $FFFFFFFFFFFFFFFF;
      Result[3] := $FFFFFFFFFFFFFFFF;
      Result[4] := $FFFFFFFFFFFFFFFF;
      Result[5] := $FFFFFFFFFFFFFFFF;
      Result[6] := $FFFFFFFFFFFFFFFF;
      Result[7] := $FFFFFFFFFFFFFFFF;
      Result[8] := $00000000000001FF;
    end;
    pfCurve25519:
    begin
      SetLength(Result, 4);
      Result[0] := $FFFFFFFFFFFFFFED;
      Result[1] := $FFFFFFFFFFFFFFFF;
      Result[2] := $FFFFFFFFFFFFFFFF;
      Result[3] := $7FFFFFFFFFFFFFFF;
    end;
    pfCurve448:
    begin
      SetLength(Result, 7);
      Result[0] := $FFFFFFFFFFFFFFFF;
      Result[1] := $FFFFFFFFFFFFFFFF;
      Result[2] := $FFFFFFFFFFFFFFFF;
      Result[3] := $FFFFFFFEFFFFFFFF;
      Result[4] := $FFFFFFFFFFFFFFFF;
      Result[5] := $FFFFFFFFFFFFFFFF;
      Result[6] := $FFFFFFFFFFFFFFFF;
    end;
  else
    raise EArgumentOutOfRangeException.Create('Id');
  end;
end;

class function TPrimeFieldFactory.CreateContext(Id: TPrimeFieldId): TMontgomeryContext;
var
  N: TBigIntLimbs;
begin
  N := Modulus(Id);
  Result := TMontgomeryContext.Create(N);
end;

end.
