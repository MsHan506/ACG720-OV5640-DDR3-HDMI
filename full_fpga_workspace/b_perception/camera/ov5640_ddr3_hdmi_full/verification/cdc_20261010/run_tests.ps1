$ErrorActionPreference = 'Stop'
$project = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$repo = (Resolve-Path (Join-Path $project '..\..\..')).Path
$work = Join-Path $repo 'work\cdc_tests_20261010'
New-Item -ItemType Directory -Path $work -Force | Out-Null
$iverilog = 'C:\iverilog\bin\iverilog.exe'
$vvp = 'C:\iverilog\bin\vvp.exe'
$cases = @(
    @{ name='tb_osd_cdc'; source='src\vga\sensor_osd_overlay.v' },
    @{ name='tb_frame_sync'; source='src\ddr3_ctrl_2port\fifo_ddr3_adapter.v' }
)
foreach ($case in $cases) {
    $output = Join-Path $work ($case.name + '.vvp')
    & $iverilog -g2012 -s $case.name -o $output `
        (Join-Path $project $case.source) (Join-Path $PSScriptRoot ($case.name + '.sv'))
    if ($LASTEXITCODE -ne 0) { throw "Compilation failed: $($case.name)" }
    $result = & $vvp $output 2>&1
    $exitCode = $LASTEXITCODE
    $result | Tee-Object -FilePath (Join-Path $work ($case.name + '.log'))
    if ($exitCode -ne 0 -or ($result -join "`n") -notmatch 'PASS') {
        throw "Simulation failed: $($case.name)"
    }
}
Write-Output 'CDC tests passed; these simulations do not test DDR hardware or RK3588 HDMI lock.'
