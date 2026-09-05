Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'

function Set-DynomaxDynamicContextProperty {
    param([Parameter(Mandatory)]$Object,[Parameter(Mandatory)][string]$Name,$Value)
    $property=$Object.PSObject.Properties[$Name]
    if($null -eq $property){
        $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
    }else{
        $property.Value=$Value
    }
}

function Get-DynomaxContinuationDecision {
    param([Parameter(Mandatory)][string]$ContextPath,[Parameter(Mandatory)][string]$StepId)
    $continuationContext=Read-DynomaxJson -Path $ContextPath
    $continuation=Get-DynomaxPropertyValue -Object $continuationContext -Name 'continuation' -DefaultValue $null
    if($null -eq $continuation){return 'EXECUTE'}
    $plan=Get-DynomaxPropertyValue -Object $continuation -Name 'plan' -DefaultValue $null
    if($null -eq $plan){throw 'Continuation context has no immutable plan.'}
    $matches=@((Get-DynomaxPropertyValue -Object $plan -Name 'items' -DefaultValue @())|Where-Object{
        [string](Get-DynomaxPropertyValue -Object $_ -Name 'targetStepId' -DefaultValue '') -ceq $StepId
    })
    if($matches.Count -ne 1){throw "Continuation plan has no unique decision for physical step '$StepId'."}
    $decision=([string](Get-DynomaxPropertyValue -Object $matches[0] -Name 'decision' -DefaultValue '')).ToUpperInvariant()
    if($decision -notin @('EXECUTE','REUSE','RERUNCONTEXT','INVALIDATED','BLOCKED')){throw "Continuation plan decision '$decision' is invalid."}
    return $decision
}

function Get-DynomaxRuntimeStepValue {
    param([Parameter(Mandatory)]$Context,[Parameter(Mandatory)]$StepInput,[Parameter(Mandatory)][string]$Name,[int]$AttemptNumber=1)
    switch($Name){
        'CurrentUtc' { return [DateTime]::UtcNow.ToString('o') }
        'AttemptNumber' { return [int][Math]::Max(1,$AttemptNumber) }
        'NodePath' {
            $nodePath=[string](Get-DynomaxPropertyValue -Object $StepInput -Name 'nodePath' -DefaultValue '')
            if([string]::IsNullOrWhiteSpace($nodePath)){throw 'RuntimeValue NodePath is unavailable for this Action step.'}
            return $nodePath
        }
        default {
            $runtimeValues=Get-DynomaxPropertyValue -Object $Context -Name 'runtimeValues' -DefaultValue $null
            if($null -eq $runtimeValues){throw "RuntimeValue '$Name' is unavailable because runtimeValues is missing from the Run context."}
            $property=$runtimeValues.PSObject.Properties[$Name]
            if($null -eq $property -or $null -eq $property.Value -or [string]::IsNullOrWhiteSpace([string]$property.Value)){throw "RuntimeValue '$Name' is unavailable for this Run."}
            return $property.Value
        }
    }
}

function Refresh-DynomaxRuntimeStepInputContext {
    param([Parameter(Mandatory)][string]$ContextPath,[Parameter(Mandatory)][string]$StepId,[Parameter(Mandatory)][int]$AttemptNumber)
    $context=Read-DynomaxJson -Path $ContextPath
    $active=Get-DynomaxPropertyValue -Object $context -Name 'activeStepInput' -DefaultValue $null
    if($null -eq $active){return $false}
    if(-not [string]::Equals([string](Get-DynomaxPropertyValue -Object $active -Name 'stepId' -DefaultValue ''),$StepId,[StringComparison]::Ordinal)){throw 'The active Dynomax step-input scope belongs to a different execution slot.'}
    $stepInputs=Get-DynomaxPropertyValue -Object $context -Name 'stepInputs' -DefaultValue $null
    $entryProperty=if($null -ne $stepInputs){$stepInputs.PSObject.Properties[$StepId]}else{$null}
    if($null -eq $entryProperty){return $false}
    $entry=$entryProperty.Value
    $changed=$false
    foreach($binding in @(Get-DynomaxPropertyValue -Object $entry -Name 'deferredBindings' -DefaultValue @())){
        if([string](Get-DynomaxPropertyValue -Object $binding -Name 'kind' -DefaultValue '') -ne 'RuntimeValue'){continue}
        $inputName=[string](Get-DynomaxPropertyValue -Object $binding -Name 'inputName' -DefaultValue '')
        $name=[string](Get-DynomaxPropertyValue -Object $binding -Name 'name' -DefaultValue '')
        if(-not $inputName -or -not $name){throw 'A Dynomax runtime-value binding is incomplete.'}
        Set-DynomaxDynamicContextProperty -Object $context.values -Name $inputName -Value (Get-DynomaxRuntimeStepValue -Context $context -StepInput $entry -Name $name -AttemptNumber $AttemptNumber)
        $changed=$true
    }
    if($changed){
        $runtimeValues=Get-DynomaxPropertyValue -Object $context -Name 'runtimeValues' -DefaultValue $null
        if($null -ne $runtimeValues){
            Set-DynomaxDynamicContextProperty -Object $runtimeValues -Name 'AttemptNumber' -Value ([int][Math]::Max(1,$AttemptNumber))
            Set-DynomaxDynamicContextProperty -Object $runtimeValues -Name 'CurrentUtc' -Value ([DateTime]::UtcNow.ToString('o'))
        }
        Write-DynomaxJson -Value $context -Path $ContextPath
    }
    return $changed
}

function Get-DynomaxRunDataPoolOutputEntry {
    param([Parameter(Mandatory)]$Context,[Parameter(Mandatory)][string]$SourceStepId,[Parameter(Mandatory)][string]$OutputName)
    $pool=Get-DynomaxPropertyValue -Object $Context -Name 'runDataPool' -DefaultValue $null
    $steps=if($null -ne $pool){Get-DynomaxPropertyValue -Object $pool -Name 'steps' -DefaultValue $null}else{$null}
    $stepProperty=if($null -ne $steps){$steps.PSObject.Properties[$SourceStepId]}else{$null}
    if($null -eq $stepProperty){throw "Required Dynomax source step '$SourceStepId' has no captured outputs."}
    $outputs=Get-DynomaxPropertyValue -Object $stepProperty.Value -Name 'outputs' -DefaultValue $null
    $outputProperty=if($null -ne $outputs){$outputs.PSObject.Properties[$OutputName]}else{$null}
    if($null -eq $outputProperty -or -not [bool](Get-DynomaxPropertyValue -Object $outputProperty.Value -Name 'available' -DefaultValue $false)){
        throw "Required Dynomax output '$OutputName' from source step '$SourceStepId' is unavailable."
    }
    return $outputProperty.Value
}

function Get-DynomaxRunDataPoolOutputValue {
    param([Parameter(Mandatory)]$Context,[Parameter(Mandatory)][string]$SourceStepId,[Parameter(Mandatory)][string]$OutputName)
    $entry=Get-DynomaxRunDataPoolOutputEntry -Context $Context -SourceStepId $SourceStepId -OutputName $OutputName
    return (Get-DynomaxPropertyValue -Object $entry -Name 'value' -DefaultValue $null)
}

function Enter-DynomaxStepInputContext {
    param([Parameter(Mandatory)][string]$ContextPath,[Parameter(Mandatory)][string]$StepId)
    $context=Read-DynomaxJson -Path $ContextPath
    $active=Get-DynomaxPropertyValue -Object $context -Name 'activeStepInput' -DefaultValue $null
    if($null -ne $active){throw 'A Dynomax step-input scope is already active; the previous Action did not restore its context.'}
    $stepInputs=Get-DynomaxPropertyValue -Object $context -Name 'stepInputs' -DefaultValue $null
    if($null -eq $stepInputs){return $false}
    $entryProperty=$stepInputs.PSObject.Properties[$StepId]
    if($null -eq $entryProperty){return $false}
    $entry=$entryProperty.Value
    $stepValues=Get-DynomaxPropertyValue -Object $entry -Name 'values' -DefaultValue $null
    $resolvedValues=[ordered]@{}
    $deferredSensitiveLookup=@{}
    if($null -ne $stepValues){foreach($property in @($stepValues.PSObject.Properties)){$resolvedValues[[string]$property.Name]=$property.Value}}
    foreach($binding in @(Get-DynomaxPropertyValue -Object $entry -Name 'deferredBindings' -DefaultValue @())){
        $kind=[string](Get-DynomaxPropertyValue -Object $binding -Name 'kind' -DefaultValue '')
        $inputName=[string](Get-DynomaxPropertyValue -Object $binding -Name 'inputName' -DefaultValue '')
        if(-not $inputName){throw 'A Dynomax deferred binding has no inputName.'}
        if($kind -eq 'StepOutput'){
            $sourceStepId=[string](Get-DynomaxPropertyValue -Object $binding -Name 'sourceStepId' -DefaultValue '')
            $sourceOutputName=[string](Get-DynomaxPropertyValue -Object $binding -Name 'sourceOutputName' -DefaultValue '')
            if(-not $sourceStepId -or -not $sourceOutputName){throw 'A Dynomax step-output binding is incomplete.'}
            $sourceOutput=Get-DynomaxRunDataPoolOutputEntry -Context $context -SourceStepId $sourceStepId -OutputName $sourceOutputName
            $resolvedValues[$inputName]=Get-DynomaxPropertyValue -Object $sourceOutput -Name 'value' -DefaultValue $null
            if([string](Get-DynomaxPropertyValue -Object $sourceOutput -Name 'classification' -DefaultValue 'Normal') -eq 'SensitiveRedacted'){$deferredSensitiveLookup[$inputName]=$true}
        }elseif($kind -eq 'RuntimeValue'){
            $name=[string](Get-DynomaxPropertyValue -Object $binding -Name 'name' -DefaultValue '')
            if(-not $name){throw 'A Dynomax runtime-value binding is incomplete.'}
            $resolvedValues[$inputName]=Get-DynomaxRuntimeStepValue -Context $context -StepInput $entry -Name $name -AttemptNumber 1
        }else{
            throw "Deferred Dynomax binding kind '$kind' is not supported by this Core release."
        }
    }
    if($resolvedValues.Count -eq 0){return $false}

    $secretLookup=@{}
    foreach($key in @(Get-DynomaxPropertyValue -Object $context -Name 'secretKeys' -DefaultValue @())){if(-not [string]::IsNullOrWhiteSpace([string]$key)){$secretLookup[[string]$key]=$true}}
    $sensitiveLookup=@{}
    foreach($key in @(Get-DynomaxPropertyValue -Object $context -Name 'sensitiveKeys' -DefaultValue @())){if(-not [string]::IsNullOrWhiteSpace([string]$key)){$sensitiveLookup[[string]$key]=$true}}
    $stepSecretLookup=@{}
    foreach($key in @(Get-DynomaxPropertyValue -Object $entry -Name 'secretKeys' -DefaultValue @())){if(-not [string]::IsNullOrWhiteSpace([string]$key)){$stepSecretLookup[[string]$key]=$true}}
    $stepSensitiveLookup=@{}
    foreach($key in @(Get-DynomaxPropertyValue -Object $entry -Name 'sensitiveKeys' -DefaultValue @())){if(-not [string]::IsNullOrWhiteSpace([string]$key)){$stepSensitiveLookup[[string]$key]=$true}}
    foreach($key in @($deferredSensitiveLookup.Keys)){$stepSensitiveLookup[[string]$key]=$true}
    $priorValues=[ordered]@{};$priorSecretFlags=[ordered]@{};$priorSensitiveFlags=[ordered]@{}
    foreach($name in @($resolvedValues.Keys)){
        $existing=$context.values.PSObject.Properties[$name]
        $priorValues[$name]=[ordered]@{exists=($null -ne $existing);value=$(if($null -ne $existing){$existing.Value}else{$null})}
        $priorSecretFlags[$name]=$secretLookup.ContainsKey($name)
        $priorSensitiveFlags[$name]=$sensitiveLookup.ContainsKey($name)
        Set-DynomaxDynamicContextProperty -Object $context.values -Name $name -Value $resolvedValues[$name]
        if($stepSecretLookup.ContainsKey($name)){$secretLookup[$name]=$true}else{[void]$secretLookup.Remove($name)}
        if($stepSensitiveLookup.ContainsKey($name) -or $stepSecretLookup.ContainsKey($name)){$sensitiveLookup[$name]=$true}else{[void]$sensitiveLookup.Remove($name)}
    }
    $context.secretKeys=@($secretLookup.Keys|Sort-Object)
    Set-DynomaxDynamicContextProperty -Object $context -Name 'sensitiveKeys' -Value @($sensitiveLookup.Keys|Sort-Object)
    Set-DynomaxDynamicContextProperty -Object $context -Name 'activeStepInput' -Value ([pscustomobject][ordered]@{stepId=$StepId;priorValues=[pscustomobject]$priorValues;priorSecretFlags=[pscustomobject]$priorSecretFlags;priorSensitiveFlags=[pscustomobject]$priorSensitiveFlags})
    Write-DynomaxJson -Value $context -Path $ContextPath
    return $true
}

function Exit-DynomaxStepInputContext {
    param([Parameter(Mandatory)][string]$ContextPath,[Parameter(Mandatory)][string]$StepId)
    $context=Read-DynomaxJson -Path $ContextPath
    $active=Get-DynomaxPropertyValue -Object $context -Name 'activeStepInput' -DefaultValue $null
    $secretLookup=@{}
    foreach($key in @(Get-DynomaxPropertyValue -Object $context -Name 'secretKeys' -DefaultValue @())){if(-not [string]::IsNullOrWhiteSpace([string]$key)){$secretLookup[[string]$key]=$true}}
    $sensitiveLookup=@{}
    foreach($key in @(Get-DynomaxPropertyValue -Object $context -Name 'sensitiveKeys' -DefaultValue @())){if(-not [string]::IsNullOrWhiteSpace([string]$key)){$sensitiveLookup[[string]$key]=$true}}
    if($null -ne $active){
        if(-not [string]::Equals([string](Get-DynomaxPropertyValue -Object $active -Name 'stepId' -DefaultValue ''),$StepId,[StringComparison]::Ordinal)){throw 'The active Dynomax step-input scope belongs to a different execution slot.'}
        foreach($triple in @(
            @('priorValues','priorSecretFlags','priorSensitiveFlags'),
            @('priorOutputValues','priorOutputSecretFlags','priorOutputSensitiveFlags')
        )){
            $priorValues=Get-DynomaxPropertyValue -Object $active -Name $triple[0] -DefaultValue $null
            $priorSecretFlags=Get-DynomaxPropertyValue -Object $active -Name $triple[1] -DefaultValue $null
            $priorSensitiveFlags=Get-DynomaxPropertyValue -Object $active -Name $triple[2] -DefaultValue $null
            if($null -ne $priorValues){foreach($property in @($priorValues.PSObject.Properties)){
                $name=[string]$property.Name;$previous=$property.Value
                if([bool](Get-DynomaxPropertyValue -Object $previous -Name 'exists' -DefaultValue $false)){Set-DynomaxDynamicContextProperty -Object $context.values -Name $name -Value (Get-DynomaxPropertyValue -Object $previous -Name 'value' -DefaultValue $null)}else{[void]$context.values.PSObject.Properties.Remove($name)}
                $wasSecret=$false;if($null -ne $priorSecretFlags){$sp=$priorSecretFlags.PSObject.Properties[$name];if($null -ne $sp){$wasSecret=[bool]$sp.Value}}
                if($wasSecret){$secretLookup[$name]=$true}else{[void]$secretLookup.Remove($name)}
                $wasSensitive=$false;if($null -ne $priorSensitiveFlags){$sp=$priorSensitiveFlags.PSObject.Properties[$name];if($null -ne $sp){$wasSensitive=[bool]$sp.Value}}
                if($wasSensitive){$sensitiveLookup[$name]=$true}else{[void]$sensitiveLookup.Remove($name)}
            }}
        }
        [void]$context.PSObject.Properties.Remove('activeStepInput')
    }
    $pool=Get-DynomaxPropertyValue -Object $context -Name 'runDataPool' -DefaultValue $null
    $steps=if($null -ne $pool){Get-DynomaxPropertyValue -Object $pool -Name 'steps' -DefaultValue $null}else{$null}
    $stepProperty=if($null -ne $steps){$steps.PSObject.Properties[$StepId]}else{$null}
    if($null -ne $stepProperty){
        $outputs=Get-DynomaxPropertyValue -Object $stepProperty.Value -Name 'outputs' -DefaultValue $null
        if($null -ne $outputs){foreach($property in @($outputs.PSObject.Properties)){
            if([bool](Get-DynomaxPropertyValue -Object $property.Value -Name 'available' -DefaultValue $false)){
                $name=[string]$property.Name
                Set-DynomaxDynamicContextProperty -Object $context.values -Name $name -Value (Get-DynomaxPropertyValue -Object $property.Value -Name 'value' -DefaultValue $null)
                if([string](Get-DynomaxPropertyValue -Object $property.Value -Name 'classification' -DefaultValue 'Normal') -eq 'SensitiveRedacted'){$sensitiveLookup[$name]=$true}else{[void]$sensitiveLookup.Remove($name)}
            }
        }}
    }
    $context.secretKeys=@($secretLookup.Keys|Sort-Object)
    Set-DynomaxDynamicContextProperty -Object $context -Name 'sensitiveKeys' -Value @($sensitiveLookup.Keys|Sort-Object)
    Write-DynomaxJson -Value $context -Path $ContextPath
}

