$ErrorActionPreference = 'Stop'
$projectDir = $PSScriptRoot
$repoDir = (Resolve-Path (Join-Path $projectDir '..\..\..')).Path
$releaseDir = Join-Path $repoDir 'deliverables\hdmi_fix_20261010'
$snapshotDir = Join-Path $releaseDir 'source_snapshot'
$gowin = 'C:\Gowin\Gowin_V1.9.12.03_x64\IDE\bin\gw_sh.exe'
New-Item -ItemType Directory -Path $snapshotDir -Force | Out-Null

$projects = @('ov5640_ddr3_hdmi.gprj', 'rk3588_hdmi_link_test.gprj')
$inputs = @()
foreach ($name in $projects) {
    $path = Join-Path $projectDir $name
    $inputs += $path
    # Gowin accepts a legacy XML declaration with version="1". .NET requires
    # "1.0"; omit only the declaration in memory, without changing the project.
    [xml]$xml = (Get-Content -LiteralPath $path -Raw) -replace '^\s*<\?xml[^>]*\?>', ''
    foreach ($file in $xml.Project.FileList.File) {
        if ($file.enable -eq '1') {
            $inputs += (Resolve-Path (Join-Path $projectDir $file.path)).Path
        }
    }
}
# Include files and readable vendor netlists are retained as a superset of
# compiler inputs. The enabled FileList above identifies the actual projects.
$inputs += Get-ChildItem (Join-Path $projectDir 'src') -Recurse -File |
    Where-Object { $_.Extension -in @('.v','.sv','.vh','.vo','.sdc','.cst') } |
    ForEach-Object { $_.FullName }
$inputs += @('build_hdmi_protocol_fixed_20261010.tcl',
             'build_complete_protocol_fixed_20261010.tcl',
             'build_audited_release_20261010.ps1') | ForEach-Object { Join-Path $projectDir $_ }
$inputs = @($inputs | Sort-Object -Unique)
$sourceRecords = foreach ($path in $inputs) {
    if (-not $path.StartsWith($repoDir + '\', [StringComparison]::OrdinalIgnoreCase)) {
        throw "Input escapes repository: $path"
    }
    $relative = $path.Substring($repoDir.Length + 1)
    $target = Join-Path $snapshotDir $relative
    New-Item -ItemType Directory -Path (Split-Path $target -Parent) -Force | Out-Null
    Copy-Item -LiteralPath $path -Destination $target -Force
    [ordered]@{ path=$relative; sha256=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash }
}

$builds = @(
    @{ script='build_hdmi_protocol_fixed_20261010.tcl'; base='rk3588_hdmi_protocol_fixed_20261010'; role='isolated_color_bars' },
    @{ script='build_complete_protocol_fixed_20261010.tcl'; base='b_full_hdmi_protocol_fixed_20261010'; role='full_camera_robot_candidate' }
)
$artifacts = @()
Push-Location $projectDir
try {
    foreach ($build in $builds) {
        $start = Get-Date
        $log = Join-Path $releaseDir ($build.base + '_build.log')
        & $gowin $build.script 2>&1 | Tee-Object -FilePath $log
        if ($LASTEXITCODE -ne 0) { throw "Gowin failed: $($build.base)" }
        $bitstream = Join-Path $projectDir ('impl\pnr\' + $build.base + '.fs')
        if (-not (Test-Path -LiteralPath $bitstream) -or (Get-Item $bitstream).LastWriteTime -lt $start) {
            throw "No freshly built bitstream: $bitstream"
        }
        $report = Join-Path $projectDir ('impl\pnr\' + $build.base + '_tr_content.html')
        $html = Get-Content -LiteralPath $report -Raw
        $setup = [regex]::Match($html, 'Numbers of Setup Violated Endpoints</td>\s*<td>(\d+)</td>')
        $hold = [regex]::Match($html, 'Numbers of Hold Violated Endpoints</td>\s*<td>(\d+)</td>')
        if (-not $setup.Success -or -not $hold.Success) { throw 'Missing STA summary' }
        $target = Join-Path $releaseDir ($build.base + '.fs')
        Copy-Item -LiteralPath $bitstream -Destination $target -Force
        foreach ($path in @($report,
            (Join-Path $projectDir ('impl\pnr\' + $build.base + '.rpt.txt')),
            (Join-Path $projectDir ('impl\gwsynthesis\' + $build.base + '.vg')))) {
            Copy-Item -LiteralPath $path -Destination $releaseDir -Force
        }
        $artifacts += [ordered]@{
            file=($build.base + '.fs'); role=$build.role
            sha256=(Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
            size_bytes=(Get-Item $target).Length
            build_time=(Get-Item $target).LastWriteTime.ToString('o')
            setup_violated_endpoints=[int]$setup.Groups[1].Value
            hold_violated_endpoints=[int]$hold.Groups[1].Value
            hardware_rk3588_lock_verified=$false
        }
    }
} finally { Pop-Location }

# Refuse to associate a binary with a source tree modified during compilation.
foreach ($record in $sourceRecords) {
    $actual = (Get-FileHash -LiteralPath (Join-Path $repoDir $record.path) -Algorithm SHA256).Hash
    if ($actual -ne $record.sha256) { throw "Source changed during build: $($record.path)" }
}
$manifest = [ordered]@{
    generated_at=(Get-Date).ToString('o')
    tool='Gowin V1.9.12.03 (64-bit)'
    git_head=(& git -C $repoDir rev-parse HEAD)
    dirty_worktree=$true
    source_snapshot='source_snapshot; repository-relative layout; includes a superset of source/include files'
    sources=$sourceRecords
    artifacts=$artifacts
    acceptance='Functional simulation and compilation are not physical HDMI/RK3588 acceptance. Full candidate retains STA violations; see CHECKS.md.'
}
$manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $releaseDir 'manifest.json') -Encoding UTF8
Write-Output "AUDITED RELEASE: $releaseDir"
