param([switch]$Check)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Root = Split-Path $PSScriptRoot -Parent
$InputFile = Join-Path $PSScriptRoot 'isa_x86.json'
$OutputFile = Join-Path $Root 'Source\NativeAsm.InstructionDB.Generated.pas'
$ReportFile = Join-Path $PSScriptRoot 'instruction_db_report.json'
$CheckOnly = $Check.IsPresent

$CC = @('o','no','b','nb','z','nz','be','nbe','s','ns','p','np','l','nl','le','nle')
$BaseMnemonics = @('mov','movsx','movsxd','movzx','lea','xchg','add','adc','sub','sbb','inc','dec','neg','imul','mul','shl','shr','sar','rol','ror','rcl','rcr','bsf','bsr','popcnt','bswap','xor','and','or','not','cmp','test','push','pop','call','jmp','ret','lfence','mfence','sfence','rdtsc','rdtscp','nop','int3','ud2','syscall')
$TargetMnemonics = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
foreach ($Name in $BaseMnemonics) { [void]$TargetMnemonics.Add($Name) }
foreach ($Name in $CC) { [void]$TargetMnemonics.Add('j' + $Name); [void]$TargetMnemonics.Add('cmov' + $Name); [void]$TargetMnemonics.Add('set' + $Name) }
$AllowedExt = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
foreach ($Name in @('CMOV','POPCNT','RDTSC','RDTSCP','SSE','SSE2')) { [void]$AllowedExt.Add($Name) }
$ExcludedSignatureTokens = @('sreg','creg','dreg','moff','R:fs','R:gs','W:fs','W:gs')

$Arch = @{ any='saAny'; x64='saX64' }
$Tag = @{ ''='efNone'; MR='efMR'; RM='efRM'; M='efM'; OP='efOP' }
$OpcodeMap = @{ primary='omPrimary'; '0f'='om0F'; '0f38'='om0F38'; '0f3a'='om0F3A' }
$Prefix = @{ none='mpNone'; np='mpNP'; '66'='mp66'; f2='mpF2'; f3='mpF3' }
$RexW = @{ never='rwNever'; bywidth='rwByResolvedGpWidth'; force='rwForce' }
$P66 = @{ never='p66Never'; bywidth='p66ByResolvedGpWidth'; force='p66ForceOperandSize'; mandatory='p66MandatoryOpcode' }
$ModRM = @{ none='mkNone'; operands='mkFromOperands'; fixedreg='mkFixedRegField'; ignored='mkIgnoredRegCanonicalZero'; fixedbyte='mkFixedByte' }
$Fixup = @{ none='dfkNone'; rel8='dfkRelative8'; rel32='dfkRelative32' }
$Support = @{ no='nsSourceOnly'; partial='nsPartial'; yes='nsSupported' }
$Canon = @{ none='ncNone'; lea16='ncLea16Uses66'; setcc0='ncSetccRegFieldZero'; pushimm='ncPushImmediateShortest'; nop='ncNativeMultiByteNop' }
$Restriction = @{ none='nrNone'; memory_source_only='nrMemorySourceOnly'; register_source_only='nrRegisterSourceOnly'; register_dest_only='nrRegisterDestinationOnly'; no_memory_immediate='nrNoMemoryImmediate'; signed_imm32_64='nrSignedImm32For64Bit'; bswap64='nrBswap64Only'; conditions10='nrNativeConditionSubset'; no_rel8='nrNoRelative8Fixup'; no_indirect_jmp='nrNoIndirectJmpApi'; no_syscall='nrNoSyscallBuilderApi'; rotate_imm_reg='nrRotateRegisterImmediateOnly'; shift_count='nrShiftCount0To63'; explicit_mem_size='nrExplicitMemorySizeRequired'; stack_mem64='nrStackMemory64OrUnspecified'; not_exposed='nrNotExposed' }
$Access = [System.Collections.Generic.Dictionary[string,string]]::new([System.StringComparer]::Ordinal)
$Access.Add('', 'oaNone')
$Access.Add('R', 'oaRead')
$Access.Add('W', 'oaWrite')
$Access.Add('w', 'oaWritePartial')
$Access.Add('X', 'oaReadWrite')
$Access.Add('x', 'oaReadWritePartial')
$RegClass = @{ ''='rcNone'; r8='rcGp8Any'; r16='rcGp16'; r32='rcGp32'; r64='rcGp64'; al='rcGp8Any'; cl='rcGp8Any'; ax='rcGp16'; eax='rcGp32'; rax='rcGp64'; dx='rcGp16'; edx='rcGp32'; rdx='rcGp64'; ecx='rcGp32' }
$MemClass = @{ ''='mcNone'; mem='mcUnspecified'; m8='mc8'; m16='mc16'; m32='mc32'; m64='mc64' }
$ImmKind = @{ ''='ikNone'; imm8='ikRaw8'; imms8='ikSigned8'; immu8='ikUnsigned8'; imm16='ikRaw16'; immu16='ikUnsigned16'; imm32='ikRaw32'; imms32='ikSigned32'; immu32='ikUnsigned32'; imm64='ikRaw64' }
$ImmBytes = @{ imm8=1; imms8=1; immu8=1; imm16=2; immu16=2; imm32=4; imms32=4; immu32=4; imm64=8 }
$OptionBits = @{ lock=(1 -shl 0); rep=(1 -shl 1); repne=(1 -shl 2); repIgnore=(1 -shl 3); xacquire=(1 -shl 4); xrelease=(1 -shl 5); bnd=(1 -shl 6); ilock=(1 -shl 7) }

function New-Operand([string]$Raw) {
    [pscustomobject]@{ Raw=$Raw; AccessRaw=''; AccessExpanded=''; Commutative=$false; Conditional=$false; Reg=''; Mem=''; Imm=''; Rel=0; FixedReg=''; FixedImplicit=$false; FixedImm=$null }
}

function Copy-Operand($Operand) {
    [pscustomobject]@{ Raw=$Operand.Raw; AccessRaw=$Operand.AccessRaw; AccessExpanded=$Operand.AccessExpanded; Commutative=$Operand.Commutative; Conditional=$Operand.Conditional; Reg=$Operand.Reg; Mem=$Operand.Mem; Imm=$Operand.Imm; Rel=$Operand.Rel; FixedReg=$Operand.FixedReg; FixedImplicit=$Operand.FixedImplicit; FixedImm=$Operand.FixedImm }
}

function New-Encoding {
    [pscustomobject]@{ Tag=''; OpcodeMap='primary'; Opcode=0; OpcodePlusReg=$false; Raw66=$false; Raw67=$false; MandatoryPrefix='none'; ExplicitRexW=$false; ModRMToken=''; FixedModRM=$null; ImmCode=''; RelCode='' }
}

function Get-JsonValue($Object, [string]$Name, $Default) {
    $Property = $Object.PSObject.Properties[$Name]
    if ($null -eq $Property) { return $Default }
    return $Property.Value
}

function Get-Tokens([string]$Text) {
    if ([string]::IsNullOrWhiteSpace($Text)) { return @() }
    return @($Text -split '\s+' | Where-Object { $_ -ne '' })
}

function Split-Options([string]$Signature) {
    if (-not $Signature.StartsWith('[')) { return [pscustomobject]@{ Options=@(); Body=$Signature } }
    $End = $Signature.IndexOf(']')
    if ($End -lt 0) { throw "unterminated option list: $Signature" }
    $Items = [System.Collections.Generic.List[string]]::new()
    $Raw = $Signature.Substring(1, $End - 1)
    foreach ($Opt in $Raw.Split('|')) {
        if ($Opt -eq 'xacqrel') { $Items.Add('xacquire'); $Items.Add('xrelease') }
        elseif ($Opt -ne '') { $Items.Add($Opt) }
    }
    [pscustomobject]@{ Options=$Items.ToArray(); Body=$Signature.Substring($End + 1).Trim() }
}

function Get-Mnemonic([string]$Signature) {
    $Split = Split-Options $Signature
    return (($Split.Body -split '\s+', 2)[0]).ToLowerInvariant()
}

function Parse-Operand([string]$Text) {
    $Raw = $Text.Trim()
    $S = $Raw
    $Op = New-Operand $Raw
    $M = [regex]::Match($S, '^([RWXwx])(\?)?:(.*)$')
    if ($M.Success) {
        $Op.AccessRaw = $M.Groups[1].Value
        $Op.AccessExpanded = $Op.AccessRaw
        $Op.Conditional = $M.Groups[2].Success
        $S = $M.Groups[3].Value
    }
    if ($S.StartsWith('~')) { $Op.Commutative = $true; $S = $S.Substring(1) }
    if ($S.StartsWith('<') -and $S.EndsWith('>')) { $Op.FixedImplicit = $true; $S = $S.Substring(1, $S.Length - 2) }
    if ($S -eq '1') { $Op.FixedImm = 1; $Op.Imm = 'imm8'; return $Op }
    if ($S -eq 'rel8' -or $S -eq 'rel32') { $Op.Rel = $(if ($S -eq 'rel8') { 1 } else { 4 }); return $Op }
    if ($S.StartsWith('imm')) {
        if ($S -eq 'immv') { $Op.Imm = 'immv' }
        elseif ($ImmKind.ContainsKey($S)) { $Op.Imm = $S }
        else { throw "unsupported immediate operand token '$S'" }
        return $Op
    }
    if (@('al','cl','ax','eax','rax','dx','edx','rdx','ecx','axv','dxv') -ccontains $S) { $Op.FixedReg = $S; return $Op }
    if ($S.Contains('/')) {
        $Parts = $S -split '/', 2
        if (@('r8','r16','r32','r64','rv','ry') -cnotcontains $Parts[0]) { throw "unsupported register side '$($Parts[0])' in '$Raw'" }
        if (@('m8','m16','m32','m64','mv','my') -cnotcontains $Parts[1]) { throw "unsupported memory side '$($Parts[1])' in '$Raw'" }
        $Op.Reg = $Parts[0]; $Op.Mem = $Parts[1]; return $Op
    }
    if (@('r8','r16','r32','r64','rv','ry') -ccontains $S) { $Op.Reg = $S; return $Op }
    if (@('m8','m16','m32','m64','mv','my','mem') -ccontains $S) { $Op.Mem = $S; return $Op }
    throw "unsupported operand token '$S' in '$Raw'"
}

function Parse-Signature([string]$Signature) {
    $Split = Split-Options $Signature
    $Parts = $Split.Body -split '\s+', 2
    $Mnemonic = $Parts[0].ToLowerInvariant()
    $Operands = [System.Collections.Generic.List[object]]::new()
    if ($Parts.Count -gt 1) { foreach ($Text in $Parts[1].Split(',')) { $Operands.Add((Parse-Operand $Text)) } }
    [pscustomobject]@{ Options=$Split.Options; Mnemonic=$Mnemonic; Operands=$Operands.ToArray() }
}

function Parse-Encoding([string]$Text) {
    $S = $Text.Trim()
    $Out = New-Encoding
    $M = [regex]::Match($S, '^\[([A-Z ]+)\]\s*(.*)$')
    if ($M.Success) {
        $Out.Tag = $M.Groups[1].Value.Replace(' ','')
        $S = $M.Groups[2].Value.Trim()
        if (-not $Tag.ContainsKey($Out.Tag)) { throw "unsupported source encoding tag [$($Out.Tag)] in '$Text'" }
    }
    $HexBytes = [System.Collections.Generic.List[int]]::new()
    $PlusRegOpcode = $null
    foreach ($Tok in ($S -split '\s+')) {
        if ($Tok -eq '') { continue }
        $U = $Tok.ToUpperInvariant()
        if ($Tok -eq '66') { $Out.Raw66 = $true }
        elseif ($Tok -eq '67') { $Out.Raw67 = $true }
        elseif ($U -eq 'NP') { $Out.MandatoryPrefix = 'np' }
        elseif ($U -eq 'F2') { $Out.MandatoryPrefix = 'f2' }
        elseif ($U -eq 'F3') { $Out.MandatoryPrefix = 'f3' }
        elseif ($U -eq 'REX.W') { $Out.ExplicitRexW = $true }
        elseif ($Tok -match '^/[0-7r]$') { $Out.ModRMToken = $Tok }
        elseif (@('ib','iw','id','iq','iv') -ccontains $Tok) { if ($Out.ImmCode -ne '') { throw "multiple immediate codes in '$Text'" }; $Out.ImmCode = $Tok }
        elseif (@('cb','cd') -ccontains $Tok) { $Out.RelCode = $Tok }
        elseif ($Tok -match '^[0-9A-Fa-f]{2}\+r$') { $PlusRegOpcode = [Convert]::ToInt32($Tok.Substring(0,2), 16) }
        elseif ($Tok -match '^[0-9A-Fa-f]{2}$') { $HexBytes.Add([Convert]::ToInt32($Tok, 16)) }
        else { throw "unsupported encoding token '$Tok' in '$Text'" }
    }
    if ($null -ne $PlusRegOpcode) { $HexBytes.Add([int]$PlusRegOpcode); $Out.OpcodePlusReg = $true }
    if ($HexBytes.Count -eq 0) { throw "no opcode bytes in '$Text'" }
    $Payload = @()
    if ($HexBytes[0] -eq 0x0F) {
        if ($HexBytes.Count -ge 2 -and @((0x38),(0x3A)) -contains $HexBytes[1]) { $Out.OpcodeMap = $(if ($HexBytes[1] -eq 0x38) { '0f38' } else { '0f3a' }); $Payload = @($HexBytes | Select-Object -Skip 2) }
        else { $Out.OpcodeMap = '0f'; $Payload = @($HexBytes | Select-Object -Skip 1) }
    } else { $Payload = $HexBytes.ToArray() }
    if ($Payload.Count -eq 0) { throw "missing final opcode in '$Text'" }
    $Out.Opcode = [int]$Payload[0]
    if ($Payload.Count -gt 1) {
        if ($Payload.Count -ne 2 -or $Out.ModRMToken -ne '') { throw "unresolved extra opcode/fixed bytes in '$Text'" }
        $Out.FixedModRM = [int]$Payload[1]
    }
    return $Out
}

function Uses-VGroup($Operands) {
    foreach ($Op in $Operands) { if ($Op.Reg -eq 'rv' -or $Op.Mem -eq 'mv' -or $Op.Imm -eq 'immv' -or @('axv','dxv') -contains $Op.FixedReg) { return $true } }
    return $false
}

function Uses-YGroup($Operands) {
    foreach ($Op in $Operands) { if ($Op.Reg -eq 'ry' -or $Op.Mem -eq 'my') { return $true } }
    return $false
}

function Expand-Operand($Operand, [int]$Width) {
    $X = Copy-Operand $Operand
    if ($X.Reg -eq 'rv' -or $X.Reg -eq 'ry') { $X.Reg = @{16='r16';32='r32';64='r64'}[$Width] }
    if ($X.Mem -eq 'mv' -or $X.Mem -eq 'my') { $X.Mem = @{16='m16';32='m32';64='m64'}[$Width] }
    if ($X.Imm -eq 'immv') { $X.Imm = @{16='imm16';32='imm32';64='imms32'}[$Width] }
    if ($X.FixedReg -eq 'axv') { $X.FixedReg = @{16='ax';32='eax';64='rax'}[$Width] }
    if ($X.FixedReg -eq 'dxv') { $X.FixedReg = @{16='dx';32='edx';64='rdx'}[$Width] }
    if ((@(32,64) -contains $Width) -and (@('w','x') -contains $X.AccessExpanded)) { $X.AccessExpanded = $X.AccessExpanded.ToUpperInvariant() }
    return $X
}

function Expand-Form($Form) {
    $HasV = Uses-VGroup $Form.Operands
    $HasY = Uses-YGroup $Form.Operands
    if ($HasV -and $HasY) { throw "mixed rv/ry groups are not supported: $($Form.SourceSignature)" }
    $Widths = if ($HasV) { @(16,32,64) } elseif ($HasY) { @(32,64) } else { @(0) }
    $Result = [System.Collections.Generic.List[object]]::new()
    foreach ($Width in $Widths) {
        $Ops = [System.Collections.Generic.List[object]]::new()
        foreach ($Op in $Form.Operands) { $Ops.Add((Expand-Operand $Op $Width)) }
        $Result.Add([pscustomobject]@{ SourceIndex=$Form.SourceIndex; Category=$Form.Category; GroupExt=$Form.GroupExt; RecordExt=$Form.RecordExt; Arch=$Form.Arch; OptionsRaw=$Form.OptionsRaw; Mnemonic=$Form.Mnemonic; SourceSignature=$Form.SourceSignature; SourceOp=$Form.SourceOp; Io=$Form.Io; Alt=$Form.Alt; Operands=$Ops.ToArray(); Enc=$Form.Enc; ExpandedWidth=$Width; NativeSupport='no'; Restriction='not_exposed'; Canonicalization='none' })
    }
    return $Result.ToArray()
}

function Get-OptionsMask($Options) {
    $Value = 0
    foreach ($Opt in $Options) { if (@('lock','rep','repne','repIgnore','xacquire','xrelease','bnd','ilock') -cnotcontains $Opt) { throw "unknown selected instruction option '$Opt'" }; $Value = $Value -bor $OptionBits[$Opt] }
    return $Value
}

function Get-FixedRegFields([string]$Name) {
    if ($Name -eq '') { return [pscustomobject]@{ Id=0; Type='rt64' } }
    $Ids = @{ al=0; ax=0; eax=0; rax=0; cl=1; ecx=1; dx=2; edx=2; rdx=2 }
    $Types = @{ al='rt8'; cl='rt8'; ax='rt16'; dx='rt16'; eax='rt32'; ecx='rt32'; edx='rt32'; rax='rt64'; rdx='rt64' }
    if (-not $Ids.ContainsKey($Name)) { throw "unsupported fixed register '$Name'" }
    [pscustomobject]@{ Id=$Ids[$Name]; Type=$Types[$Name] }
}

function Get-NativeClassification($Form) {
    $M = $Form.Mnemonic
    $E = $Form.Enc
    if (@('lfence','mfence','sfence','rdtsc','rdtscp','int3','ud2') -contains $M) { return @('yes','none','none') }
    if ($M -eq 'nop') { if ($Form.Operands.Count -eq 0) { return @('yes','none','nop') }; return @('no','not_exposed','nop') }
    if ($M -eq 'syscall') { return @('no','no_syscall','none') }
    if ($M -eq 'ret') { return @('yes','none','none') }
    if ($M -eq 'lea' -and $Form.Operands.Count -gt 0 -and @('r16','r32','r64') -contains $Form.Operands[0].Reg) { return @('yes','none',$(if ($Form.Operands[0].Reg -eq 'r16') {'lea16'} else {'none'})) }
    if ($M -eq 'bswap') { if ($Form.Operands.Count -gt 0 -and $Form.Operands[0].Reg -eq 'r64') { return @('yes','bswap64','none') }; return @('no','bswap64','none') }
    if (@('rcl','rcr') -contains $M) { return @('no','not_exposed','none') }
    if (@('rol','ror') -contains $M) { return @('partial','rotate_imm_reg','none') }
    if (@('shl','shr','sar') -contains $M) { return @('partial','shift_count','none') }
    if (@('bsf','bsr','popcnt') -contains $M) { return @('partial','register_source_only','none') }
    if ($M -eq 'imul') { if ($Form.Operands.Count -gt 0 -and $Form.Operands[0].FixedImplicit) { return @('no','not_exposed','none') }; return @('partial','register_source_only','none') }
    if ($M -eq 'mul') { return @('partial','explicit_mem_size','none') }
    if ($M.StartsWith('cmov')) { return @('partial','register_source_only','none') }
    if ($M.StartsWith('set')) { return @('partial','register_dest_only','setcc0') }
    if ($M.StartsWith('j') -and $M -ne 'jmp') { if ($E.RelCode -eq 'cb') { return @('no','no_rel8','none') }; return @('partial','conditions10','none') }
    if ($M -eq 'jmp') { if ($E.RelCode -eq 'cb') { return @('no','no_rel8','none') }; if ($E.RelCode -eq 'cd') { return @('yes','none','none') }; return @('no','no_indirect_jmp','none') }
    if ($M -eq 'call') { return @('yes','none','none') }
    if (@('push','pop') -contains $M) {
        if ($M -eq 'push' -and @($Form.Operands | Where-Object { $_.Imm -ne '' }).Count -gt 0) { if (@($Form.Operands | Where-Object { $_.Imm -eq 'imm16' }).Count -gt 0) { return @('no','not_exposed','none') }; return @('partial','none','pushimm') }
        if (@($Form.Operands | Where-Object { $_.Mem -ne '' }).Count -gt 0) { return @('partial','stack_mem64','none') }
        return @('yes','none','none')
    }
    if (@('movsx','movzx','movsxd') -contains $M) { return @('partial','memory_source_only','none') }
    if ($M -eq 'mov') { if (@($Form.Operands | Where-Object { $_.Imm -ne '' }).Count -gt 0 -and @($Form.Operands | Where-Object { $_.Mem -ne '' }).Count -gt 0) { return @('partial','no_memory_immediate','none') }; return @('partial','none','none') }
    if ($M -eq 'xchg') { return @('partial','register_source_only','none') }
    if (@('inc','dec','neg','not') -contains $M) { return @('partial','explicit_mem_size','none') }
    if (@('add','adc','sub','sbb','and','or','xor','cmp','test') -contains $M) {
        if (@($Form.Operands | Where-Object { $_.Imm -ne '' }).Count -gt 0) { if ($Form.ExpandedWidth -eq 64 -or @($Form.Operands | Where-Object { $_.Reg -eq 'r64' -or $_.Mem -eq 'm64' }).Count -gt 0) { return @('partial','signed_imm32_64','none') }; return @('partial','explicit_mem_size','none') }
        return @('partial','none','none')
    }
    return @('no','not_exposed','none')
}

function Get-SourceForms($Db) {
    $Result = [System.Collections.Generic.List[object]]::new()
    $SourceIndex = 0
    foreach ($Group in $Db.instructions) {
        $Category = if ($null -ne $Group.category) { [string]$Group.category } else { '' }
        $GroupExt = @(Get-Tokens ([string](Get-JsonValue $Group 'ext' '')))
        foreach ($Rec in $Group.instructions) {
            $RecordExt = @(Get-Tokens ([string](Get-JsonValue $Rec 'ext' '')))
            $ValidExt = $true
            foreach ($Ext in @(($GroupExt + $RecordExt) | Select-Object -Unique)) { if (-not $AllowedExt.Contains($Ext)) { $ValidExt = $false; break } }
            if (-not $ValidExt) { continue }
            foreach ($ArchName in @('any','x64')) {
                $Property = $Rec.PSObject.Properties[$ArchName]
                if ($null -eq $Property) { continue }
                $Signature = [string]$Property.Value
                $Mnemonic = Get-Mnemonic $Signature
                if (-not $TargetMnemonics.Contains($Mnemonic)) { continue }
                $Excluded = $false
                foreach ($Token in $ExcludedSignatureTokens) { if ($Signature.Contains($Token)) { $Excluded = $true; break } }
                if ($Excluded) { continue }
                try { $Parsed = Parse-Signature $Signature; $Encoding = Parse-Encoding ([string](Get-JsonValue $Rec 'op' '')) }
                catch { throw "selected form failed closed: '$Signature' / '$([string](Get-JsonValue $Rec 'op' ''))': $($_.Exception.Message)" }
                $Form = [pscustomobject]@{ SourceIndex=$SourceIndex; Category=$Category; GroupExt=$GroupExt; RecordExt=$RecordExt; Arch=$ArchName; OptionsRaw=$Parsed.Options; Mnemonic=$Parsed.Mnemonic; SourceSignature=$Signature; SourceOp=[string](Get-JsonValue $Rec 'op' ''); Io=[string](Get-JsonValue $Rec 'io' ''); Alt=[bool](Get-JsonValue $Rec 'alt' $false); Operands=$Parsed.Operands; Enc=$Encoding; ExpandedWidth=0; NativeSupport='no'; Restriction='not_exposed'; Canonicalization='none' }
                foreach ($Expanded in (Expand-Form $Form)) { $Result.Add($Expanded) }
                $SourceIndex++
            }
        }
    }
    foreach ($Form in $Result) { $Class = Get-NativeClassification $Form; $Form.NativeSupport=$Class[0]; $Form.Restriction=$Class[1]; $Form.Canonicalization=$Class[2] }
    return $Result.ToArray()
}

function ConvertTo-PascalString([string]$Text) { return "'" + $Text.Replace("'", "''") + "'" }

function Get-CategoryMask([string]$Category) {
    $Bits = @{ GP=(1 -shl 0); GP_EXT=(1 -shl 1) }
    $Value = 0
    foreach ($Token in (Get-Tokens $Category)) { if (@('GP','GP_EXT') -cnotcontains $Token) { throw "unknown selected category token '$Token'" }; $Value = $Value -bor $Bits[$Token] }
    return $Value
}

function Get-ExtensionMask($GroupExt, $RecordExt) {
    $Bits = @{ CMOV=(1 -shl 0); POPCNT=(1 -shl 1); RDTSC=(1 -shl 2); RDTSCP=(1 -shl 3); SSE=(1 -shl 4); SSE2=(1 -shl 5) }
    $Value = 0
    foreach ($Token in @(($GroupExt + $RecordExt) | Select-Object -Unique)) { if (-not $Bits.ContainsKey($Token)) { throw "unknown selected extension token '$Token'" }; $Value = $Value -bor $Bits[$Token] }
    return $Value
}

function ConvertTo-OperandPascal($Op) {
    if (-not $RegClass.ContainsKey($Op.Reg)) { throw "unexpanded/unknown register class '$($Op.Reg)'" }
    if (-not $MemClass.ContainsKey($Op.Mem)) { throw "unexpanded/unknown memory class '$($Op.Mem)'" }
    if ($Op.Imm -ne '' -and -not $ImmKind.ContainsKey($Op.Imm)) { throw "unexpanded/unknown immediate class '$($Op.Imm)'" }
    $Kinds = 0
    if ($Op.Reg -ne '' -or $Op.FixedReg -ne '') { $Kinds = $Kinds -bor 1 }
    if ($Op.Mem -ne '') { $Kinds = $Kinds -bor 2 }
    if ($Op.Imm -ne '' -or $null -ne $Op.FixedImm) { $Kinds = $Kinds -bor 4 }
    if ($Op.Rel -ne 0) { $Kinds = $Kinds -bor 8 }
    $Fixed = Get-FixedRegFields $Op.FixedReg
    $FixedFlags = 0
    if ($Op.FixedReg -ne '') { $FixedFlags = $FixedFlags -bor 1 }
    if ($Op.FixedImplicit) { $FixedFlags = $FixedFlags -bor 2 }
    if ($null -ne $Op.FixedImm) { $FixedFlags = $FixedFlags -bor 4 }
    $FixedImm = if ($null -ne $Op.FixedImm) { [int]$Op.FixedImm } else { 0 }
    $Flags = $(if ($Op.Commutative) {1} else {0}) -bor $(if ($Op.Conditional) {2} else {0})
    $Ik = if ($ImmKind.ContainsKey($Op.Imm)) { $ImmKind[$Op.Imm] } else { 'ikNone' }
    return ('(Kinds:${0:X2}; RegClass:{1}; MemClass:{2}; RawAccess:{3}; ExpandedAccess:{4}; Flags:${5:X2}; FixedFlags:${6:X2}; FixedRegID:{7}; FixedRegType:{8}; FixedImm:{9}; ImmKind:{10}; RelBytes:{11})' -f $Kinds,$RegClass[$Op.Reg],$MemClass[$Op.Mem],$Access[$Op.AccessRaw],$Access[$Op.AccessExpanded],$Flags,$FixedFlags,$Fixed.Id,$Fixed.Type,$FixedImm,$Ik,$Op.Rel)
}

function Get-RexWPolicy($Form) { if ($Form.Enc.ExplicitRexW) { return 'force' }; if ($Form.ExpandedWidth -eq 64 -and @('push','pop','call','jmp','ret') -notcontains $Form.Mnemonic) { return 'bywidth' }; return 'never' }
function Get-Legacy66Policy($Form) { if ($Form.Mnemonic -eq 'lea' -and $Form.Operands.Count -gt 0 -and $Form.Operands[0].Reg -eq 'r16') { return 'force' }; if ($Form.Enc.Raw66) { return 'force' }; if ($Form.ExpandedWidth -eq 16) { return 'bywidth' }; return 'never' }

function Get-ModRMFields($Form) {
    $E = $Form.Enc
    if ($null -ne $E.FixedModRM) { return [pscustomobject]@{ Kind='fixedbyte'; RegIdx=-1; RmIdx=-1; FixedReg=0; FixedByte=[int]$E.FixedModRM } }
    if ($E.ModRMToken -eq '') { return [pscustomobject]@{ Kind='none'; RegIdx=-1; RmIdx=-1; FixedReg=0; FixedByte=0 } }
    if ($E.ModRMToken -ne '/r') {
        $Rm = -1
        for ($I=0; $I -lt $Form.Operands.Count; $I++) { if ($Form.Operands[$I].Reg -ne '' -or $Form.Operands[$I].Mem -ne '') { $Rm=$I; break } }
        return [pscustomobject]@{ Kind='fixedreg'; RegIdx=-1; RmIdx=$Rm; FixedReg=[int]$E.ModRMToken.Substring(1,1); FixedByte=0 }
    }
    if ($Form.Mnemonic.StartsWith('set')) { return [pscustomobject]@{ Kind='ignored'; RegIdx=-1; RmIdx=0; FixedReg=0; FixedByte=0 } }
    if ($E.Tag -eq 'MR') { return [pscustomobject]@{ Kind='operands'; RegIdx=1; RmIdx=0; FixedReg=0; FixedByte=0 } }
    if ($E.Tag -eq 'RM') { return [pscustomobject]@{ Kind='operands'; RegIdx=0; RmIdx=1; FixedReg=0; FixedByte=0 } }
    if ($E.Tag -eq 'M' -and $Form.Operands.Count -eq 1) { return [pscustomobject]@{ Kind='ignored'; RegIdx=-1; RmIdx=0; FixedReg=0; FixedByte=0 } }
    throw "cannot resolve /r binding for $($Form.SourceSignature) => $($Form.SourceOp)"
}

function Get-OpcodeRegIndex($Form) {
    if (-not $Form.Enc.OpcodePlusReg) { return -1 }
    $Candidates = [System.Collections.Generic.List[int]]::new()
    for ($I=0; $I -lt $Form.Operands.Count; $I++) { if ($Form.Operands[$I].Reg -ne '' -and $Form.Operands[$I].FixedReg -eq '') { $Candidates.Add($I) } }
    if ($Candidates.Count -ne 1) { throw "cannot resolve opcode+reg operand for $($Form.SourceSignature)" }
    return $Candidates[0]
}

function Get-ImmediateFields($Form) {
    $Idx = -1
    for ($I=0; $I -lt $Form.Operands.Count; $I++) { if ($Form.Operands[$I].Imm -ne '' -and $null -eq $Form.Operands[$I].FixedImm) { $Idx=$I; break } }
    if ($Idx -lt 0) { return [pscustomobject]@{ Index=-1; Kind='ikNone'; Bytes=0 } }
    $Op = $Form.Operands[$Idx]
    $Kind = $ImmKind[$Op.Imm]
    $Size = $ImmBytes[$Op.Imm]
    $CodeSize = switch ($Form.Enc.ImmCode) { 'ib' {1}; 'iw' {2}; 'id' {4}; 'iq' {8}; 'iv' {$Size}; default {0} }
    if ($CodeSize -ne $Size) { throw "immediate width mismatch in $($Form.SourceSignature): operand $($Op.Imm), op $($Form.SourceOp)" }
    [pscustomobject]@{ Index=$Idx; Kind=$Kind; Bytes=$Size }
}

function Get-FixupFields($Form) {
    $Idx = -1
    for ($I=0; $I -lt $Form.Operands.Count; $I++) { if ($Form.Operands[$I].Rel -ne 0) { $Idx=$I; break } }
    if ($Idx -lt 0) { if ($Form.Enc.RelCode -ne '') { throw "rel encoding without relative operand: $($Form.SourceSignature)" }; return [pscustomobject]@{ Has=$false; Kind='none'; Index=-1 } }
    $Kind = if ($Form.Operands[$Idx].Rel -eq 1) { 'rel8' } else { 'rel32' }
    $Expected = if ($Kind -eq 'rel8') { 'cb' } else { 'cd' }
    if ($Form.Enc.RelCode -ne $Expected) { throw "relative width mismatch in $($Form.SourceSignature): $($Form.SourceOp)" }
    [pscustomobject]@{ Has=$true; Kind=$Kind; Index=$Idx }
}

function ConvertTo-BoolText([bool]$Value) { if ($Value) { return 'true' }; return 'false' }

function Render-Database($Forms, [string]$SourceHash) {
    $Mnemonics = @($Forms | ForEach-Object { $_.Mnemonic } | Sort-Object -Unique)
    $MIndex = @{}
    for ($I=0; $I -lt $Mnemonics.Count; $I++) { $MIndex[$Mnemonics[$I]] = $I }
    $FormOrder = [System.Collections.Generic.List[int]]::new()
    $MnemonicStarts = [System.Collections.Generic.List[int]]::new()
    $MnemonicCounts = [System.Collections.Generic.List[int]]::new()
    foreach ($Mnemonic in $Mnemonics) {
        $MnemonicStarts.Add($FormOrder.Count)
        $Ids = [System.Collections.Generic.List[int]]::new()
        for ($I=0; $I -lt $Forms.Count; $I++) { if ($Forms[$I].Mnemonic -eq $Mnemonic) { $Ids.Add($I) } }
        foreach ($Id in $Ids) { $FormOrder.Add($Id) }
        $MnemonicCounts.Add($Ids.Count)
    }
    $Operands = [System.Collections.Generic.List[object]]::new()
    $Starts = [System.Collections.Generic.List[int]]::new()
    foreach ($Form in $Forms) { $Starts.Add($Operands.Count); foreach ($Op in $Form.Operands) { $Operands.Add($Op) } }
    $Lines = [System.Collections.Generic.List[string]]::new()
    $Lines.Add('unit NativeAsm.InstructionDB.Generated;')
    $Lines.Add('')
    $Lines.Add('{ AUTO-GENERATED. DO NOT EDIT BY HAND.')
    $Lines.Add('  Generator : Tools/Generate-InstructionDb.ps1')
    $Lines.Add("  Source SHA256: $SourceHash")
    $Lines.Add('  Scope     : NativeAsm legacy x64 GP/control-flow/fence/timing/debug subset')
    $Lines.Add('}')
    $Lines.Add('')
    $Lines.Add('interface')
    $Lines.Add('')
    $Lines.Add('uses NativeAsm.Types, NativeAsm.InstructionDB;')
    $Lines.Add('')
    $Lines.Add('const')
    $Lines.Add("  CInstructionDbSourceSha256 = '$SourceHash';")
    $Lines.Add("  CInstructionMnemonicCount = $($Mnemonics.Count);")
    $Lines.Add("  CInstructionFormCount = $($Forms.Count);")
    $Lines.Add("  CInstructionOperandCount = $($Operands.Count);")
    $Lines.Add('')
    $Lines.Add("  CInstructionMnemonicNames: array[0..$($Mnemonics.Count - 1)] of string = (")
    for ($I=0; $I -lt $Mnemonics.Count; $I++) { $Lines.Add('    ' + (ConvertTo-PascalString $Mnemonics[$I]) + $(if ($I + 1 -lt $Mnemonics.Count) {','} else {''})) }
    $Lines.Add('  );')
    $Lines.Add('')
    $Lines.Add("  CInstructionMnemonicFormStart: array[0..$($Mnemonics.Count - 1)] of Word = (")
    for ($I=0; $I -lt $MnemonicStarts.Count; $I++) { $Lines.Add("    $($MnemonicStarts[$I])" + $(if ($I + 1 -lt $MnemonicStarts.Count) {','} else {''})) }
    $Lines.Add('  );')
    $Lines.Add('')
    $Lines.Add("  CInstructionMnemonicFormCount: array[0..$($Mnemonics.Count - 1)] of Word = (")
    for ($I=0; $I -lt $MnemonicCounts.Count; $I++) { $Lines.Add("    $($MnemonicCounts[$I])" + $(if ($I + 1 -lt $MnemonicCounts.Count) {','} else {''})) }
    $Lines.Add('  );')
    $Lines.Add('')
    $Lines.Add("  CInstructionFormOrder: array[0..$($Forms.Count - 1)] of Word = (")
    for ($I=0; $I -lt $FormOrder.Count; $I++) { $Lines.Add("    $($FormOrder[$I])" + $(if ($I + 1 -lt $FormOrder.Count) {','} else {''})) }
    $Lines.Add('  );')
    $Lines.Add('')
    $Lines.Add("  CInstructionSourceSignatures: array[0..$($Forms.Count - 1)] of string = (")
    for ($I=0; $I -lt $Forms.Count; $I++) { $Lines.Add('    ' + (ConvertTo-PascalString $Forms[$I].SourceSignature) + $(if ($I + 1 -lt $Forms.Count) {','} else {''})) }
    $Lines.Add('  );')
    $Lines.Add('')
    $Lines.Add("  CInstructionSourceOps: array[0..$($Forms.Count - 1)] of string = (")
    for ($I=0; $I -lt $Forms.Count; $I++) { $Lines.Add('    ' + (ConvertTo-PascalString $Forms[$I].SourceOp) + $(if ($I + 1 -lt $Forms.Count) {','} else {''})) }
    $Lines.Add('  );')
    $Lines.Add('')
    $Lines.Add("  CInstructionOperands: array[0..$($Operands.Count - 1)] of TDbOperandSpec = (")
    for ($I=0; $I -lt $Operands.Count; $I++) { $Lines.Add('    ' + (ConvertTo-OperandPascal $Operands[$I]) + $(if ($I + 1 -lt $Operands.Count) {','} else {''})) }
    $Lines.Add('  );')
    $Lines.Add('')
    $Lines.Add("  CInstructionForms: array[0..$($Forms.Count - 1)] of TEncodingDescriptor = (")
    for ($I=0; $I -lt $Forms.Count; $I++) {
        $Form = $Forms[$I]
        $E = $Form.Enc
        $MF = Get-ModRMFields $Form
        $OpRegIdx = Get-OpcodeRegIndex $Form
        $IF = Get-ImmediateFields $Form
        $FF = Get-FixupFields $Form
        $Record = ('(MnemonicIndex:{0}; SourceRecordIndex:{1}; SourceArch:{2}; CategoryMask:${3:X4}; ExtensionMask:${4:X4}; AllowedOptionsMask:${5:X4}; SourceTag:{6}; SourceAlt:{7}; ExpandedWidth:{8}; OpcodeMap:{9}; Opcode:${10:X2}; OpcodePlusReg:{11}; MandatoryPrefix:{12}; Raw66:{13}; Raw67:{14}; RexWPolicy:{15}; Legacy66Policy:{16}; ModRMKind:{17}; ModRegOperandIdx:{18}; ModRmOperandIdx:{19}; FixedRegValue:{20}; FixedModRMByte:${21:X2}; OpcodeRegOperandIdx:{22}; ImmediateOperandIdx:{23}; ImmKind:{24}; ImmediateBytes:{25}; HasFixup:{26}; FixupKind:{27}; FixupOperandIdx:{28}; OperandStart:{29}; OperandCount:{30}; NativeSupport:{31}; NativeRestriction:{32}; NativeCanonicalization:{33})' -f $MIndex[$Form.Mnemonic],$Form.SourceIndex,$Arch[$Form.Arch],(Get-CategoryMask $Form.Category),(Get-ExtensionMask $Form.GroupExt $Form.RecordExt),(Get-OptionsMask $Form.OptionsRaw),$Tag[$E.Tag],(ConvertTo-BoolText $Form.Alt),$Form.ExpandedWidth,$OpcodeMap[$E.OpcodeMap],$E.Opcode,(ConvertTo-BoolText $E.OpcodePlusReg),$Prefix[$E.MandatoryPrefix],(ConvertTo-BoolText $E.Raw66),(ConvertTo-BoolText $E.Raw67),$RexW[(Get-RexWPolicy $Form)],$P66[(Get-Legacy66Policy $Form)],$ModRM[$MF.Kind],$MF.RegIdx,$MF.RmIdx,$MF.FixedReg,$MF.FixedByte,$OpRegIdx,$IF.Index,$IF.Kind,$IF.Bytes,(ConvertTo-BoolText $FF.Has),$Fixup[$FF.Kind],$FF.Index,$Starts[$I],$Form.Operands.Count,$Support[$Form.NativeSupport],$Restriction[$Form.Restriction],$Canon[$Form.Canonicalization])
        $Lines.Add('    ' + $Record + $(if ($I + 1 -lt $Forms.Count) {','} else {''}))
    }
    $Lines.Add('  );')
    $Lines.Add('')
    $Lines.Add('implementation')
    $Lines.Add('')
    $Lines.Add('end.')
    $Lines.Add('')
    return [string]::Join("`n", $Lines)
}

function New-Report($Forms, [string]$SourceHash) {
    $BySupport = [ordered]@{ yes=0; partial=0; no=0 }
    $ByMnemonic = @{}
    foreach ($Form in $Forms) { $BySupport[$Form.NativeSupport]++; if (-not $ByMnemonic.ContainsKey($Form.Mnemonic)) { $ByMnemonic[$Form.Mnemonic]=0 }; $ByMnemonic[$Form.Mnemonic]++ }
    $SortedMnemonic = [ordered]@{}
    foreach ($Name in ($ByMnemonic.Keys | Sort-Object)) { $SortedMnemonic[$Name] = $ByMnemonic[$Name] }
    return [ordered]@{ source_sha256=$SourceHash; forms=$Forms.Count; mnemonics=$ByMnemonic.Count; native_support=$BySupport; forms_by_mnemonic=$SortedMnemonic }
}

function Render-Report($Report) {
    $Lines = [System.Collections.Generic.List[string]]::new()
    $Lines.Add('{')
    $Lines.Add('  "source_sha256": "' + $Report['source_sha256'] + '",')
    $Lines.Add('  "forms": ' + $Report['forms'] + ',')
    $Lines.Add('  "mnemonics": ' + $Report['mnemonics'] + ',')
    $Lines.Add('  "native_support": {')
    $Lines.Add('    "yes": ' + $Report['native_support']['yes'] + ',')
    $Lines.Add('    "partial": ' + $Report['native_support']['partial'] + ',')
    $Lines.Add('    "no": ' + $Report['native_support']['no'])
    $Lines.Add('  },')
    $Lines.Add('  "forms_by_mnemonic": {')
    $Keys = @($Report['forms_by_mnemonic'].Keys)
    for ($I=0; $I -lt $Keys.Count; $I++) {
        $Name = [string]$Keys[$I]
        $Suffix = if ($I + 1 -lt $Keys.Count) { ',' } else { '' }
        $Lines.Add('    "' + $Name + '": ' + $Report['forms_by_mnemonic'][$Name] + $Suffix)
    }
    $Lines.Add('  }')
    $Lines.Add('}')
    $Lines.Add('')
    return [string]::Join("`n", $Lines)
}

$Raw = [System.IO.File]::ReadAllBytes($InputFile)
$Sha = [System.Security.Cryptography.SHA256]::Create()
try { $SourceHash = [BitConverter]::ToString($Sha.ComputeHash($Raw)).Replace('-','').ToLowerInvariant() } finally { $Sha.Dispose() }
$Json = [System.Text.Encoding]::UTF8.GetString($Raw)
$Db = $Json | ConvertFrom-Json
$Forms = @(Get-SourceForms $Db)
$Text = Render-Database $Forms $SourceHash
$Report = New-Report $Forms $SourceHash
if ($CheckOnly) {
    if (-not (Test-Path -LiteralPath $OutputFile)) { throw "generated instruction DB is missing: $OutputFile" }
    $Current = [System.IO.File]::ReadAllText($OutputFile, [System.Text.Encoding]::UTF8).Replace("`r`n","`n")
    if ($Current -ne $Text) { throw 'generated instruction DB is stale; run Tools\Generate-InstructionDb.ps1' }
} else {
    [System.IO.Directory]::CreateDirectory((Split-Path $OutputFile -Parent)) | Out-Null
    [System.IO.File]::WriteAllText($OutputFile, $Text, [System.Text.UTF8Encoding]::new($false))
}
$ReportText = Render-Report $Report
[System.IO.File]::WriteAllText($ReportFile, $ReportText, [System.Text.UTF8Encoding]::new($false))
$ReportText.TrimEnd()
