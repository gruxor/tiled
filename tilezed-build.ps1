[CmdletBinding()]
param(
    [switch]$NoColor,
    [string]$LogPath,
    [string]$OutputPath,
    [string]$QtPath,
    [string]$VcVarsPath,
    [string]$Jobs,
    [switch]$NoSummary,
    [switch]$NoCleanup,
    [switch]$ShowCompileCommands,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$BuildArgs
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$buildScript = Join-Path $scriptDir 'tilezed-build.bat'

if ($OutputPath) {
    if (-not [System.IO.Path]::IsPathRooted($OutputPath)) {
        Write-Error "Output path must be absolute: $OutputPath"
        $global:LASTEXITCODE = 2
        return
    }
}
if ($QtPath) {
    if (-not [System.IO.Path]::IsPathRooted($QtPath)) {
        Write-Error "Qt path must be absolute: $QtPath"
        $global:LASTEXITCODE = 2
        return
    }
}
if ($VcVarsPath) {
    if (-not [System.IO.Path]::IsPathRooted($VcVarsPath)) {
        Write-Error "vcvars path must be absolute: $VcVarsPath"
        $global:LASTEXITCODE = 2
        return
    }
}

if (-not (Test-Path -LiteralPath $buildScript)) {
    Write-Error "Build script not found: $buildScript"
    $global:LASTEXITCODE = 1
    return
}

$logWriter = $null
if ($LogPath) {
    $logDirectory = Split-Path -Parent $LogPath
    if ($logDirectory -and -not (Test-Path -LiteralPath $logDirectory)) {
        New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
    }
    $logWriter = [System.IO.StreamWriter]::new($LogPath, $false, [System.Text.UTF8Encoding]::new($false))
}

$useColor = -not $NoColor
$warningCount = 0
$errorCount = 0
$lastPrintedBlank = $false
$suppressBlankLines = 0
$oldBuildOutputPath = [Environment]::GetEnvironmentVariable('BUILD_OUTPUT_PATH', 'Process')
$oldNoCleanup = [Environment]::GetEnvironmentVariable('NO_CLEANUP', 'Process')
$oldQtOverride = [Environment]::GetEnvironmentVariable('QT_OVERRIDE', 'Process')
$oldVcvarsOverride = [Environment]::GetEnvironmentVariable('VCVARS_OVERRIDE', 'Process')
$oldJobs = [Environment]::GetEnvironmentVariable('JOBS', 'Process')

function Write-BuildLine {
    param([string]$Line)

    if ($null -eq $Line) {
        return
    }

    if ($logWriter) {
        $logWriter.WriteLine($Line)
    }

    if ($Line -match '^Microsoft \(R\) Program Maintenance Utility Version ') {
        $script:suppressBlankLines = 2
        return
    }
    if ($Line -match '^Copyright \(C\) Microsoft Corporation\.\s+All rights reserved\.$') {
        $script:suppressBlankLines = 2
        return
    }

    if ([string]::IsNullOrWhiteSpace($Line)) {
        if ($script:suppressBlankLines -gt 0) {
            $script:suppressBlankLines--
            return
        }
        if ($script:lastPrintedBlank) {
            return
        }
        $script:lastPrintedBlank = $true
        Write-Output ''
        return
    }
    $script:lastPrintedBlank = $false

    if (-not $ShowCompileCommands -and $Line -match '(?i)^\s*(cl(\.exe)?\s+-|link(\.exe)?\s+|"?.*\\(moc|uic|rcc|qmake|jom|nmake)(\.exe)?"?\s+)') {
        return
    }

    $isError = $Line -match '(?i)^\s*ERROR\s*:|\b(fatal error|error)\b|\bnmake(?:\.exe)?\s*:\s*fatal error\b|\bBUILD FAILED\b'
    $isWarning = $Line -match '(?i)^\s*WARNING\s*:|\bwarning\b'
    $isPhase = $Line -match '^\[(check|prep|build|deploy|cleanup|\d+/\d+)\]'
    $isSuccess = $Line -match '(?i)^\s*SUCCESS\s*$|^FOUND:'

    if ($isError) {
        $script:errorCount++
        if ($useColor) {
            Write-Host $Line -ForegroundColor Red
        }
        else {
            Write-Output $Line
        }
        return
    }

    if ($isWarning) {
        $script:warningCount++
        if ($useColor) {
            Write-Host $Line -ForegroundColor Yellow
        }
        else {
            Write-Output $Line
        }
        return
    }

    if ($isPhase) {
        if ($useColor) {
            Write-Host $Line -ForegroundColor Cyan
        }
        else {
            Write-Output $Line
        }
        return
    }

    if ($isSuccess) {
        if ($useColor) {
            Write-Host $Line -ForegroundColor Green
        }
        else {
            Write-Output $Line
        }
        return
    }

    Write-Output $Line
}

try {
    if ($useColor) {
        Write-Host '[wrapper] Starting tilezed-build.bat' -ForegroundColor DarkCyan
        if ($LogPath) {
            Write-Host "[wrapper] Logging to $LogPath" -ForegroundColor DarkGray
        }
        if ($OutputPath) {
            Write-Host "[wrapper] Output path: $OutputPath" -ForegroundColor DarkGray
        }
        if ($QtPath) {
            Write-Host "[wrapper] Qt path: $QtPath" -ForegroundColor DarkGray
        }
        if ($VcVarsPath) {
            Write-Host "[wrapper] vcvars path: $VcVarsPath" -ForegroundColor DarkGray
        }
        if ($Jobs) {
            Write-Host "[wrapper] Jobs: $Jobs" -ForegroundColor DarkGray
        }
        if ($NoCleanup) {
            Write-Host '[wrapper] Cleanup disabled (-NoCleanup)' -ForegroundColor DarkGray
        }
    }
    else {
        Write-Output '[wrapper] Starting tilezed-build.bat'
        if ($LogPath) {
            Write-Output "[wrapper] Logging to $LogPath"
        }
        if ($OutputPath) {
            Write-Output "[wrapper] Output path: $OutputPath"
        }
        if ($QtPath) {
            Write-Output "[wrapper] Qt path: $QtPath"
        }
        if ($VcVarsPath) {
            Write-Output "[wrapper] vcvars path: $VcVarsPath"
        }
        if ($Jobs) {
            Write-Output "[wrapper] Jobs: $Jobs"
        }
        if ($NoCleanup) {
            Write-Output '[wrapper] Cleanup disabled (-NoCleanup)'
        }
    }

    if ($OutputPath) {
        $env:BUILD_OUTPUT_PATH = $OutputPath
    }
    if ($NoCleanup) {
        $env:NO_CLEANUP = '1'
    }
    if ($QtPath) {
        $env:QT_OVERRIDE = $QtPath
    }
    if ($VcVarsPath) {
        $env:VCVARS_OVERRIDE = $VcVarsPath
    }
    if ($Jobs) {
        $env:JOBS = $Jobs
    }

    $quotedArgs = @('"' + $buildScript + '"')
    foreach ($arg in $BuildArgs) {
        if ($arg -match '[\s"]') {
            $quotedArgs += '"' + ($arg -replace '"', '""') + '"'
        }
        else {
            $quotedArgs += $arg
        }
    }
    $cmdLine = ($quotedArgs -join ' ') + ' 2>&1'

    Push-Location $scriptDir
    try {
        & cmd.exe /d /c $cmdLine | ForEach-Object {
            Write-BuildLine ([string]$_)
        }
        $exitCode = $LASTEXITCODE
        if ($null -eq $exitCode) {
            $exitCode = 0
        }
    }
    finally {
        Pop-Location
    }

    if (-not $NoSummary) {
        $summary = "[wrapper] warnings=$warningCount errors=$errorCount exit=$exitCode"
        if ($exitCode -eq 0 -and $errorCount -eq 0) {
            if ($useColor) {
                Write-Host $summary -ForegroundColor Green
            }
            else {
                Write-Output $summary
            }
        }
        else {
            if ($useColor) {
                Write-Host $summary -ForegroundColor Yellow
            }
            else {
                Write-Output $summary
            }
        }
    }

    $global:LASTEXITCODE = $exitCode
    return
}
finally {
    [Environment]::SetEnvironmentVariable('BUILD_OUTPUT_PATH', $oldBuildOutputPath, 'Process')
    [Environment]::SetEnvironmentVariable('NO_CLEANUP', $oldNoCleanup, 'Process')
    [Environment]::SetEnvironmentVariable('QT_OVERRIDE', $oldQtOverride, 'Process')
    [Environment]::SetEnvironmentVariable('VCVARS_OVERRIDE', $oldVcvarsOverride, 'Process')
    [Environment]::SetEnvironmentVariable('JOBS', $oldJobs, 'Process')
    if ($logWriter) {
        $logWriter.Flush()
        $logWriter.Dispose()
    }
}
