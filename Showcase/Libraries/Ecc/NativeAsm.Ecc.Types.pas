{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
unit NativeAsm.Ecc.Types;

interface

uses
  NativeAsm.BigInt.Types;

type
  TEccAffinePoint256 = record
    X: TUInt256;
    Y: TUInt256;
    Infinity: Boolean;
  end;

  TEccJacobianPoint256 = record
    X: TUInt256;
    Y: TUInt256;
    Z: TUInt256;
  end;

  TX25519Bytes = array[0..31] of Byte;
  TEccBytes64 = array[0..63] of Byte;

  TEd25519AffinePoint = record
    X: TUInt256;
    Y: TUInt256;
  end;

implementation

end.
