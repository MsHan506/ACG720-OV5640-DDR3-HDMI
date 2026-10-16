$ErrorActionPreference = 'Stop'
$iverilog = Get-Command iverilog -ErrorAction SilentlyContinue
$vvp = Get-Command vvp -ErrorAction SilentlyContinue
if ($iverilog) {
    $iverilogPath = $iverilog.Source
} elseif (Test-Path 'C:\iverilog\bin\iverilog.exe') {
    $iverilogPath = 'C:\iverilog\bin\iverilog.exe'
}
if ($vvp) {
    $vvpPath = $vvp.Source
} elseif (Test-Path 'C:\iverilog\bin\vvp.exe') {
    $vvpPath = 'C:\iverilog\bin\vvp.exe'
}
if (-not $iverilogPath -or -not $vvpPath) {
    throw 'Icarus Verilog is not installed. Install it, then rerun this script.'
}

$root = Split-Path -Parent $PSScriptRoot
$rtl = @(
    "$root/rtl/common/uart_rx.v",
    "$root/rtl/common/uart_tx.v",
    "$root/rtl/tof/tfmini_s_parser.v",
    "$root/rtl/imu/wt901_parser.v",
    "$root/rtl/filter/tof_outlier_gate.v",
    "$root/rtl/filter/moving_average4_unsigned.v",
    "$root/rtl/filter/signed_iir_filter.v",
    "$root/rtl/filter/angle_iir_filter.v"
)

$tests = @('tb_uart_rx', 'tb_tfmini_s_parser', 'tb_wt901_parser', 'tb_filters')
foreach ($test in $tests) {
    $output = Join-Path $PSScriptRoot "$test.vvp"
    & $iverilogPath -g2005 -s $test -o $output @rtl (Join-Path $PSScriptRoot "$test.v")
    & $vvpPath $output
}

$dualBaudOutput = Join-Path $PSScriptRoot 'tb_perception_hub_dualbaud.vvp'
& $iverilogPath -g2012 -s tb_perception_hub_dualbaud -o $dualBaudOutput `
    @rtl "$root/rtl/integration/perception_hub.v" `
    (Join-Path $PSScriptRoot 'tb_perception_hub_dualbaud.v')
if ($LASTEXITCODE -ne 0) { throw 'Dual-baud perception test compilation failed.' }
& $vvpPath $dualBaudOutput
if ($LASTEXITCODE -ne 0) { throw 'Dual-baud perception test failed.' }

$telemetryOutput = Join-Path $PSScriptRoot 'tb_sensor_telemetry_tx_v3.vvp'
& $iverilogPath -g2012 -s tb_sensor_telemetry_tx_v3 -o $telemetryOutput `
    "$root/rtl/common/uart_tx_v3.v" `
    "$root/rtl/integration/sensor_telemetry_tx_v3.v" `
    (Join-Path $PSScriptRoot 'tb_sensor_telemetry_tx_v3.v')
if ($LASTEXITCODE -ne 0) { throw 'Telemetry v3 test compilation failed.' }
& $vvpPath $telemetryOutput
if ($LASTEXITCODE -ne 0) { throw 'Telemetry v3 test failed.' }
