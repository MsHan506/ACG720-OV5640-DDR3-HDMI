$ErrorActionPreference = 'Stop'
$simDir = 'C:\intelFPGA\20.1\modelsim_ase\win32aloem'
$projectDir = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$repoRoot = (Resolve-Path (Join-Path $projectDir '..\..\..')).Path
Push-Location $PSScriptRoot
try {
    if (-not (Test-Path -LiteralPath 'work')) { & "$simDir\vlib.exe" work }
    & "$simDir\vlog.exe" -sv 'C:\Gowin\Gowin_V1.9.12.03_x64\IDE\simlib\gw5a\prim_sim.v' `
        "$projectDir\src\true_hdmi\auxiliary_video_information_info_frame.sv" `
        "$projectDir\src\true_hdmi\packet_assembler.sv" `
        "$projectDir\src\true_hdmi\packet_picker.sv" `
        "$projectDir\src\true_hdmi\tmds_channel.sv" `
        "$projectDir\src\true_hdmi\serializer_gowin.sv" `
        "$projectDir\src\true_hdmi\hdmi.sv" tb_hdmi_protocol.sv
    if ($LASTEXITCODE -ne 0) { throw 'Compilation failed' }
    foreach ($test in @(@{dvi=0;log='after_fix_verified_checker.log'}, @{dvi=1;log='after_fix_dvi.log'})) {
        & "$simDir\vsim.exe" -c -voptargs=+acc "-gDVI_MODE=$($test.dvi)" `
            work.tb_hdmi_protocol -l $test.log -do 'run -all; quit -f'
        # ModelSim may exit with code 0 after $fatal followed by quit -f.
        # The self-checking summary and absence of Fatal are authoritative.
        $log = Get-Content -LiteralPath $test.log -Raw
        if ($log -notmatch 'RESULT pixels=2475000 .* failures=0' -or $log -match '\*\* Fatal:') {
            throw "Protocol regression failed: $($test.log)"
        }
    }

    & "$simDir\vlog.exe" -sv "+incdir+$projectDir\src\vga" `
        "$projectDir\src\vga\disp_driver.v" `
        "$projectDir\src\vga\sensor_osd_overlay.v" `
        "$repoRoot\src\target_box_overlay.v" `
        tb_full_video_alignment.sv
    if ($LASTEXITCODE -ne 0) { throw 'Full-video alignment compilation failed' }
    & "$simDir\vsim.exe" -c work.tb_full_video_alignment `
        -l full_video_alignment.log -do 'run -all; quit -f'
    $alignmentLog = Get-Content -LiteralPath 'full_video_alignment.log' -Raw
    if ($alignmentLog -notmatch 'RESULT checked=3300 failures=0' -or
        $alignmentLog -match '\*\* Fatal:') {
        throw 'Full-video alignment regression failed'
    }
} finally { Pop-Location }
