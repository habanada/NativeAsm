{ NativeASM | Copyright (c) 2026 Selahattin Erkoc }
{ SPDX-License-Identifier: MIT }
unit NativeAsm.BigInt.Types;

interface

uses
  System.SysUtils;

type
  TBigIntLimb = UInt64;
  PBigIntLimb = ^TBigIntLimb;
  TBigIntLimbs = TArray<TBigIntLimb>;
  TUInt128 = packed record Limbs: array[0..1] of TBigIntLimb; end;
  TUInt192 = packed record Limbs: array[0..2] of TBigIntLimb; end;
  TUInt256 = packed record Limbs: array[0..3] of TBigIntLimb; end;
  TUInt384 = packed record Limbs: array[0..5] of TBigIntLimb; end;
  TUInt448 = packed record Limbs: array[0..6] of TBigIntLimb; end;
  TUInt512 = packed record Limbs: array[0..7] of TBigIntLimb; end;
  TUInt576 = packed record Limbs: array[0..8] of TBigIntLimb; end;
  TUInt1024 = packed record Limbs: array[0..15] of TBigIntLimb; end;
  TUInt2048 = packed record Limbs: array[0..31] of TBigIntLimb; end;
  TUInt3072 = packed record Limbs: array[0..47] of TBigIntLimb; end;
  TUInt4096 = packed record Limbs: array[0..63] of TBigIntLimb; end;
  TBigIntEndian = (bieLittleEndian, bieBigEndian);

const
  BigIntLimbBits = 64;
  BigIntMaxRecommendedLimbs = 64;

implementation

end.
