Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Generator = Join-Path $PSScriptRoot 'Generate-InstructionDb.ps1'
$ReportFile = Join-Path $PSScriptRoot 'instruction_db_report.json'
$GeneratorOutput = . $Generator -Check

function Require([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }

function Find-FirstForm([scriptblock]$Predicate, [string]$Description) {
    foreach ($Form in $Forms) { if (& $Predicate $Form) { return $Form } }
    throw "missing expected form: $Description"
}

foreach ($Form in $Forms) {
    foreach ($Ext in @($Form.GroupExt + $Form.RecordExt)) { Require ($Ext -ne 'APX_F') "APX_F leaked into $($Form.SourceSignature)" }
    $UpperOp = $Form.SourceOp.ToUpperInvariant()
    foreach ($Bad in @('EVEX','VEX','REX2','NO67')) { Require (-not $UpperOp.Contains($Bad)) "$Bad leaked into $($Form.SourceSignature)" }
}

$R8Add = Find-FirstForm { param($F) $F.Mnemonic -eq 'add' -and @($F.Operands | Where-Object { $_.Reg -eq 'r8' }).Count -gt 0 } 'ADD r8 form'
Require (@($R8Add.Operands | Where-Object { $_.Reg -eq 'r8' }).Count -gt 0) 'r8 source constraint was rewritten'

$Adc64 = Find-FirstForm { param($F) $F.Mnemonic -eq 'adc' -and $F.Operands.Count -eq 2 -and $F.Operands[0].Reg -eq 'r64' } 'adc r64 form'
$Sbb64 = Find-FirstForm { param($F) $F.Mnemonic -eq 'sbb' -and $F.Operands.Count -eq 2 -and $F.Operands[0].Reg -eq 'r64' } 'sbb r64 form'
$Mul64 = Find-FirstForm { param($F) $F.Mnemonic -eq 'mul' -and @($F.Operands | Where-Object { $_.Reg -eq 'r64' -or $_.Mem -eq 'm64' }).Count -gt 0 } 'mul r64/m64 form'
Require (@('partial','yes') -contains $Adc64.NativeSupport) 'ADC r64 Native support metadata missing'
Require (@('partial','yes') -contains $Sbb64.NativeSupport) 'SBB r64 Native support metadata missing'
Require (@('partial','yes') -contains $Mul64.NativeSupport) 'MUL r64/m64 Native support metadata missing'

$Mz32 = Find-FirstForm { param($F) $F.Mnemonic -eq 'movzx' -and $F.Operands.Count -eq 2 -and $F.Operands[0].Reg -eq 'r32' -and $F.Operands[1].Mem -eq 'm16' } 'movzx r32, r16/m16'
$Mz64 = Find-FirstForm { param($F) $F.Mnemonic -eq 'movzx' -and $F.Operands.Count -eq 2 -and $F.Operands[0].Reg -eq 'r64' -and $F.Operands[1].Mem -eq 'm16' } 'movzx r64, r16/m16'
Require (-not $Mz32.Enc.ExplicitRexW) 'MOVZX r32,m16 unexpectedly forces REX.W'
Require $Mz64.Enc.ExplicitRexW 'MOVZX r64,m16 lost explicit REX.W'

foreach ($Mnemonic in @('bsf','bsr')) {
    $Form = Find-FirstForm { param($F) $F.Mnemonic -eq $Mnemonic -and $F.ExpandedWidth -eq 16 } "$Mnemonic rv"
    Require ($Form.Operands[0].AccessRaw -eq 'w') "$Mnemonic raw access must be w"
}

$ShlCl = Find-FirstForm { param($F) $F.Mnemonic -eq 'shl' -and $F.Operands.Count -eq 2 -and $F.Operands[1].FixedReg -eq 'cl' } 'shl ..., cl'
Require (-not $ShlCl.Operands[1].FixedImplicit) 'CL was incorrectly made implicit'

$Setz = Find-FirstForm { param($F) $F.Mnemonic -eq 'setz' } 'setz'
$SetzModRM = Get-ModRMFields $Setz
Require ($SetzModRM.Kind -eq 'ignored' -and $SetzModRM.RmIdx -eq 0) 'SETcc ModRM policy is not canonical ignored-reg'
Require ($Setz.Canonicalization -eq 'setcc0') 'SETcc canonicalization metadata missing'

$Lfence = Find-FirstForm { param($F) $F.Mnemonic -eq 'lfence' } 'lfence'
$Rdtscp = Find-FirstForm { param($F) $F.Mnemonic -eq 'rdtscp' } 'rdtscp'
Require ($Lfence.Enc.FixedModRM -eq 0xE8) 'LFENCE fixed ModRM must be E8'
Require ($Rdtscp.Enc.FixedModRM -eq 0xF9) 'RDTSCP fixed ModRM must be F9'

$Lea16 = Find-FirstForm { param($F) $F.Mnemonic -eq 'lea' -and $F.Operands.Count -gt 0 -and $F.Operands[0].Reg -eq 'r16' } 'lea r16, mem'
Require $Lea16.Enc.Raw67 'LEA16 raw AsmJit 67 fact was lost'
Require ($Lea16.Canonicalization -eq 'lea16') 'LEA16 Native canonicalization missing'

$PushImms = @($Forms | Where-Object { $_.Mnemonic -eq 'push' } | ForEach-Object { $_.Operands } | Where-Object { $_.Imm -ne '' } | ForEach-Object { $_.Imm } | Sort-Object -Unique)
foreach ($Imm in @('imm8','imm16','imms32')) { Require ($PushImms -contains $Imm) "PUSH immediate source form missing: $Imm" }

$Jz8 = Find-FirstForm { param($F) $F.Mnemonic -eq 'jz' -and $F.Enc.RelCode -eq 'cb' } 'jz rel8'
$Jz32 = Find-FirstForm { param($F) $F.Mnemonic -eq 'jz' -and $F.Enc.RelCode -eq 'cd' } 'jz rel32'
Require ($Jz8.NativeSupport -eq 'no') 'rel8 Jcc must not claim current Builder support'
Require (@('partial','yes') -contains $Jz32.NativeSupport) 'rel32 Jcc support metadata missing'

$Report = Get-Content -LiteralPath $ReportFile -Raw | ConvertFrom-Json
Require ($Report.source_sha256 -eq $SourceHash) 'report source hash mismatch'
Require ([int]$Report.forms -eq $Forms.Count) 'report form count mismatch'

"OK: $($Forms.Count) forms / $(@($Forms | ForEach-Object { $_.Mnemonic } | Sort-Object -Unique).Count) mnemonics"
"Source SHA256: $SourceHash"
'Critical mapping invariants: OK'
