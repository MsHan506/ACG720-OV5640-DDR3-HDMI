param(
    [string]$ReleaseName = 'cdc_fix_20261010',
    [string]$BaseName = 'b_full_cdc_fixed_20261010',
    [string]$BuildTcl = 'build_complete_cdc_fixed_20261010.tcl',
    [switch]$RunFullVerification
)

$ErrorActionPreference = 'Stop'
$projectDir = $PSScriptRoot
$repoDir = (Resolve-Path (Join-Path $projectDir '..\..\..')).Path
$releaseDir = Join-Path $repoDir (Join-Path 'deliverables' $ReleaseName)
$snapshotDir = Join-Path $releaseDir 'source_snapshot'
$base = $BaseName
$gowin = 'C:\Gowin\Gowin_V1.9.12.03_x64\IDE\bin\gw_sh.exe'
New-Item -ItemType Directory -Path $snapshotDir -Force | Out-Null
$gprj = Join-Path $projectDir 'ov5640_ddr3_hdmi.gprj'
[xml]$xml = (Get-Content -LiteralPath $gprj -Raw) -replace '^\s*<\?xml[^>]*\?>', ''
$inputs = @($gprj, $PSCommandPath, (Join-Path $projectDir $BuildTcl))
foreach ($file in $xml.Project.FileList.File) {
    if ($file.enable -eq '1') { $inputs += (Resolve-Path (Join-Path $projectDir $file.path)).Path }
}
$inputs += Get-ChildItem (Join-Path $projectDir 'src') -Recurse -File |
    Where-Object { $_.Extension -in @('.v','.sv','.vh','.vo','.sdc','.cst','.ipc') } |
    ForEach-Object { $_.FullName }
$inputs += Get-ChildItem (Join-Path $projectDir 'verification\cdc_20261010') -File |
    ForEach-Object { $_.FullName }
$inputs += Get-ChildItem (Join-Path $projectDir 'verification\hdmi_protocol_20261010') -File |
    Where-Object { $_.Extension -in @('.sv','.v','.ps1') } |
    ForEach-Object { $_.FullName }
$records = foreach ($path in ($inputs | Sort-Object -Unique)) {
    if (-not $path.StartsWith($repoDir + '\', [StringComparison]::OrdinalIgnoreCase)) {
        throw "Input escapes repository: $path"
    }
    $relative = $path.Substring($repoDir.Length + 1)
    $target = Join-Path $snapshotDir $relative
    New-Item -ItemType Directory -Path (Split-Path $target -Parent) -Force | Out-Null
    Copy-Item -LiteralPath $path -Destination $target -Force
    [ordered]@{ path=$relative; sha256=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash }
}
& (Join-Path $projectDir 'verification\cdc_20261010\run_tests.ps1') |
    Tee-Object -FilePath (Join-Path $releaseDir 'cdc_tests.log')
if ($RunFullVerification) {
    & (Join-Path $projectDir 'verification\hdmi_protocol_20261010\run_tests.ps1') |
        Tee-Object -FilePath (Join-Path $releaseDir 'hdmi_protocol.log')
    & (Join-Path $repoDir 'run_all_checks.ps1') |
        Tee-Object -FilePath (Join-Path $releaseDir 'full_regression.log')
}
$start = Get-Date
Push-Location $projectDir
try {
    & $gowin $BuildTcl 2>&1 |
        Tee-Object -FilePath (Join-Path $releaseDir 'build.log')
    if ($LASTEXITCODE -ne 0) { throw 'Gowin failed; no accepted artifact is produced.' }
} finally { Pop-Location }
foreach ($record in $records) {
    $actual = (Get-FileHash -LiteralPath (Join-Path $repoDir $record.path) -Algorithm SHA256).Hash
    if ($actual -ne $record.sha256) { throw "Source changed during build: $($record.path)" }
}
$pnr = Join-Path $projectDir 'impl\pnr'
$bitstream = Join-Path $pnr ($base + '.fs')
if (-not (Test-Path -LiteralPath $bitstream) -or (Get-Item $bitstream).LastWriteTime -lt $start) {
    throw 'No freshly built bitstream; refusing to copy stale output.'
}
$report = Join-Path $pnr ($base + '_tr_content.html')
$html = Get-Content -LiteralPath $report -Raw
$setup = [regex]::Match($html, 'Numbers of Setup Violated Endpoints</td>\s*<td>(\d+)</td>')
$hold = [regex]::Match($html, 'Numbers of Hold Violated Endpoints</td>\s*<td>(\d+)</td>')
if (-not $setup.Success -or -not $hold.Success) { throw 'Missing STA summary.' }
$paths = @()
$categories = [ordered]@{}
foreach ($kind in @('Setup','Hold','Recovery','Removal')) {
    $section = [regex]::Match($html, '(?s)<a name="' + $kind + '_Slack_Table".*?</table>')
    if (-not $section.Success) { throw "Missing timing category: $kind" }
    $rows = [regex]::Matches($section.Value, '(?s)<tr[^>]*class = "error"[^>]*>(.*?)</tr>')
    $categories[$kind] = $rows.Count
    foreach ($row in $rows) {
        $cells = @([regex]::Matches($row.Groups[1].Value, '(?s)<td>(.*?)</td>') |
            ForEach-Object { [Net.WebUtility]::HtmlDecode($_.Groups[1].Value.Trim()) })
        $paths += [ordered]@{ category=$kind; slack_ns=$cells[1]; from=$cells[2]; to=$cells[3];
            from_clock=$cells[4]; to_clock=$cells[5]; relation_ns=$cells[6];
            clock_skew_ns=$cells[7]; data_delay_ns=$cells[8] }
    }
}
$closed = [int]$setup.Groups[1].Value -eq 0 -and [int]$hold.Groups[1].Value -eq 0
$status = if ($closed) { 'STA_CLOSED_HARDWARE_UNVERIFIED' } else { 'REJECTED_TIMING_NOT_CLOSED' }
$binaryDir = Join-Path $releaseDir $(if ($closed) { 'hardware_unverified' } else { 'candidate_not_accepted' })
New-Item -ItemType Directory -Path $binaryDir -Force | Out-Null
$target = Join-Path $binaryDir ($base + '.fs')
Copy-Item -LiteralPath $bitstream -Destination $target -Force
foreach ($path in @($report, (Join-Path $pnr ($base + '.rpt.txt')),
    (Join-Path $projectDir ('impl\gwsynthesis\' + $base + '.vg')))) {
    Copy-Item -LiteralPath $path -Destination $releaseDir -Force
}
# Use -InputObject so an empty result serializes as [] and cannot leave a stale
# violation list from an earlier rejected build in the release directory.
ConvertTo-Json -InputObject @($paths) -Depth 6 |
    Set-Content -LiteralPath (Join-Path $releaseDir 'remaining_paths.json') -Encoding UTF8
$manifest = [ordered]@{
    generated_at=(Get-Date).ToString('o'); status=$status; tool='Gowin V1.9.12.03 (64-bit)'
    git_head=(& git -C $repoDir rev-parse HEAD); dirty_worktree=$true
    sources=$records; source_snapshot='Repository-relative superset of source/IP/test files; hashes verified before/after build'
    artifact=[ordered]@{
        file=$target.Substring($releaseDir.Length + 1)
        sha256=(Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash
        size_bytes=(Get-Item $target).Length; build_time=(Get-Item $target).LastWriteTime.ToString('o')
        setup_summary_endpoints=[int]$setup.Groups[1].Value
        hold_summary_endpoints=[int]$hold.Groups[1].Value
        reported_negative_paths_by_category=$categories
        hardware_rk3588_lock_verified=$false
    }
    acceptance='STA summary includes recovery/removal checks. Simulation is finite and does not verify physical DDR calibration, TMDS phase after cold start, or RK3588 lock. Nonzero timing results are rejected, not suppressed.'
}
$manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $releaseDir 'manifest.json') -Encoding UTF8
Write-Output "AUDITED BUILD RESULT: $status; $releaseDir"
