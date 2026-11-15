param(
    [Parameter(Mandatory = $true)][string]$GodotExe,
    [int]$TimeoutSeconds = 60
)
$ErrorActionPreference = 'Stop'
$projectPath = Split-Path $PSScriptRoot -Parent
$enginePath = (Resolve-Path -LiteralPath $GodotExe).Path
$resultsPath = Join-Path $projectPath 'local-only/test-results'
New-Item -ItemType Directory -Force -Path $resultsPath | Out-Null
Set-Content -LiteralPath (Join-Path $resultsPath '.gdignore') -Value ''
$previousAppData = $env:APPDATA
$previousLocalAppData = $env:LOCALAPPDATA
try {
    # Aislar preferencias y logs del motor; no cambia la configuración del usuario.
    $env:APPDATA = Join-Path $resultsPath 'godot-user'
    New-Item -ItemType Directory -Force -Path $env:APPDATA | Out-Null
    $env:LOCALAPPDATA = Join-Path $resultsPath 'godot-local'
    New-Item -ItemType Directory -Force -Path $env:LOCALAPPDATA | Out-Null
    $cases = @(
        @{ Name = 'import'; Args = '--headless --path . --editor --import' },
        # El esquema vigente usa cuatro recursos y 42 soles. Las suites históricas
        # de masa/agua y 12 soles se conservan, pero no validan este contrato.
        @{ Name = 'simulation'; Args = '--headless --path . --script res://tests/test_current_simulation.gd' },
        @{ Name = 'survival'; Args = '--headless --path . --script res://tests/test_survival_loop.gd' },
        @{ Name = 'history'; Args = '--headless --path . --script res://tests/test_history_scroll.gd' },
        @{ Name = 'integration'; Args = '--headless --path . --script res://tests/test_interface_integration.gd' },
        @{ Name = 'scene'; Args = '--headless --path . --quit-after 10' }
    )
    foreach ($case in $cases) {
        $stdoutPath = Join-Path $resultsPath ($case.Name + '.log')
        $stderrPath = Join-Path $resultsPath ($case.Name + '-errors.log')
        $process = Start-Process -FilePath $enginePath -ArgumentList $case.Args -WorkingDirectory $projectPath -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
        if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
            $process.Kill()
            throw "Timeout: $($case.Name)"
        }
        $output = Get-Content -LiteralPath $stdoutPath -Raw
        $errors = Get-Content -LiteralPath $stderrPath -Raw
        Write-Output $output
        if ($errors) { Write-Output $errors }
        if ($process.ExitCode -ne 0 -or "$output`n$errors" -match '(?m)(SCRIPT ERROR:|ERROR:|FAIL:)') {
            throw "Falló $($case.Name), exit=$($process.ExitCode). Revisar $resultsPath"
        }
        if ($case.Name -eq 'simulation' -and $output -notmatch 'CURRENT_SIMULATION_TESTS: \d+ checks, 0 failures') {
            throw 'Falta marcador de pruebas completas'
        }
        if ($case.Name -eq 'survival' -and $output -notmatch 'SURVIVAL_LOOP_TESTS: \d+ checks, 0 failures') {
            throw 'Falta marcador de supervivencia completa'
        }
        if ($case.Name -eq 'history' -and $output -notmatch 'UI_HISTORY_TESTS: 0 failures') {
            throw 'Falta marcador de pruebas de historial completas'
        }
        if ($case.Name -eq 'integration' -and $output -notmatch 'UI_INTEGRATION_TESTS: \d+ checks, 0 failures') {
            throw 'Falta marcador de pruebas de integración completas'
        }
        Write-Output "PASS: $($case.Name)"
    }
} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
}
