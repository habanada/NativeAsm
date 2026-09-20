Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Root = Split-Path $PSScriptRoot -Parent
$SourceDir = Join-Path $Root 'Source'
$BuilderFile = Join-Path $SourceDir 'NativeAsm.Builder.pas'
$StaticFile = Join-Path $SourceDir 'NativeAsm.StaticEncoder.pas'
$DbFile = Join-Path $SourceDir 'NativeAsm.InstructionDB.pas'
$GeneratedFile = Join-Path $SourceDir 'NativeAsm.InstructionDB.Generated.pas'
$TypesFile = Join-Path $SourceDir 'NativeAsm.Types.pas'
$SimdDbFile = Join-Path $SourceDir 'NativeAsm.Simd.Db.pas'
$SimdGeneratedFile = Join-Path $SourceDir 'NativeAsm.Simd.Db.Generated.pas'
$CpuFile = Join-Path $SourceDir 'NativeAsm.CpuFeatures.pas'
$TestFile = Join-Path $Root 'Tests\StaticDbRegression.dpr'

function Require([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }

& (Join-Path $PSScriptRoot 'Verify-InstructionDb.ps1')

$SourceText = [string]::Join("`n", @(Get-ChildItem -LiteralPath $SourceDir -Filter '*.pas' -File | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }))
Require (-not $SourceText.Contains('System.JSON')) 'runtime Source units unexpectedly depend on System.JSON'

$Builder = Get-Content -LiteralPath $BuilderFile -Raw
$Static = Get-Content -LiteralPath $StaticFile -Raw
$Db = Get-Content -LiteralPath $DbFile -Raw
$Generated = Get-Content -LiteralPath $GeneratedFile -Raw
$Types = Get-Content -LiteralPath $TypesFile -Raw
$SimdDb = Get-Content -LiteralPath $SimdDbFile -Raw
$SimdGenerated = Get-Content -LiteralPath $SimdGeneratedFile -Raw
$Cpu = Get-Content -LiteralPath $CpuFile -Raw

Require $Builder.Contains('NativeAsm.StaticEncoder') 'Builder is not wired to StaticEncoder'
$Routed = [regex]::Matches($Builder, 'TStaticInstructionEncoder\.(?:Encode|EmitRelative32Placeholder)').Count
Require ($Routed -ge 40) "too few Builder paths routed through static DB: $Routed"

foreach ($Dead in @('procedure TAsmBuilder.EmitArith(','procedure TAsmBuilder.EmitArithImm(','procedure TAsmBuilder.EmitShift(')) { Require (-not $Builder.Contains($Dead)) "dead manual encoding helper remains: $Dead" }
Require ($Db.Contains('nrNoRelative8Fixup') -and $Db.Contains('nrNoIndirectJmpApi')) 'fail-closed Native restrictions are missing'
Require ($Db.Contains('mkFixedByte') -and $Db.Contains('mkIgnoredRegCanonicalZero')) 'required ModRM descriptor modes are missing'
Require ($Static.ToLowerInvariant().Contains('length-first')) 'canonical static selector length-first policy is missing'
Require $Generated.Contains('CInstructionFormCount = 470;') 'unexpected generated form count'
Require $Generated.Contains('CInstructionMnemonicCount = 94;') 'unexpected generated mnemonic count'
Require $Generated.Contains('CInstructionOperandCount = 850;') 'unexpected generated operand count'
Require ($Types.Contains('sz128') -and $Types.Contains('Alignment     : Byte;')) 'base 128-bit/alignment memory metadata was lost'
Require ($Static.Contains('NativeAsm.Rules') -and $Static.Contains('TAsmRuleValidator.Validate(Result, Operands);')) 'base rule validation was lost from StaticEncoder'
Require ($SimdDb.Contains('sePCLMULQDQ') -and $SimdGenerated.Contains('CSimdMnemonicCount = 275;') -and $SimdGenerated.Contains('CSimdFormCount = 338;') -and $SimdGenerated.Contains('CSimdOperandCount = 719;') -and $SimdGenerated.Contains("'pclmulqdq'")) 'PCLMULQDQ SIMD integration is incomplete'
Require ($Cpu.Contains('cfSSE2') -and $Cpu.Contains('cfSSSE3') -and $Cpu.Contains('cfSSE42') -and $Cpu.Contains('cfPOPCNT') -and $Cpu.Contains('cfPCLMULQDQ')) 'extended CPU feature detection is incomplete'

$Test = Get-Content -LiteralPath $TestFile -Raw
foreach ($Case in @('mov rax,rbx','add rax,1','adc rax,rdx','sbb r9,r10','mul r8','xchg rax,rcx','setz r8b','movzx rax,word [rcx]','jz rel32 fixup')) { Require $Test.Contains($Case) "Delphi regression case missing: $Case" }

"Project integration: OK ($Routed static Builder routes)"
'Runtime JSON/parser dependency: none'
'Delphi regression source: present'
