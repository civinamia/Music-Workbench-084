param([switch]$NoPause)
$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
$root = $PSScriptRoot
$report = Join-Path $root '启动诊断报告.txt'
try { [IO.File]::WriteAllText($report, '', (New-Object Text.UTF8Encoding $false)) }
catch { $report = Join-Path $env:TEMP '曲幕-启动诊断报告.txt' }
function Record([string]$value) {
    $value | Out-File -LiteralPath $report -Append -Encoding UTF8
    Write-Host $value
}
Record ('曲幕启动诊断 ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
Record ('系统：' + [Environment]::OSVersion.VersionString)
Record ('64位系统：' + [Environment]::Is64BitOperatingSystem)
Record ('程序目录：' + $root)
Record '不需要安装 Python；本诊断使用 Windows 自带 PowerShell。'
$missing = 0
$manifest = Join-Path $root 'package-manifest.json'
if (Test-Path -LiteralPath $manifest) {
    $data = Get-Content -LiteralPath $manifest -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($entry in $data.files) {
        $path = Join-Path $root $entry.path
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            Record ('缺少文件：' + $entry.path); $missing++; continue
        }
        $actual = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
        if ($actual -ne $entry.sha256) { Record ('文件被修改或损坏：' + $entry.path); $missing++ }
    }
    Record ('完整性错误数：' + $missing)
} else { Record '未找到完整性清单，请使用新版完整压缩包。' }
$selfCheck = Join-Path $env:TEMP ('SubtitleWorkbench-check-' + $PID + '.json')
$env:SUBTITLE_DIAGNOSTIC_MODE = '1'
$exe = Join-Path $root 'Verseline.exe'
try {
    $process = Start-Process -FilePath $exe -ArgumentList @('--self-check', ('"' + $selfCheck + '"')) -PassThru -WindowStyle Hidden
    if ($process.WaitForExit(70000)) {
        Record ('启动自检退出码：' + $process.ExitCode)
        if (Test-Path -LiteralPath $selfCheck) { Record (Get-Content -LiteralPath $selfCheck -Raw -Encoding UTF8) }
    } else { Record '启动自检超过70秒，内部程序尚未退出。' }
} catch { Record ('Windows 启动错误：' + $_.Exception.Message) }
$startupLog = Join-Path $env:LOCALAPPDATA 'SubtitleWorkbench/startup.log'
if (Test-Path -LiteralPath $startupLog) {
    Record "`n最近的启动日志："
    Record ((Get-Content -LiteralPath $startupLog -Tail 80 -Encoding UTF8) -join "`r`n")
}
Record "`n请把此报告发给开发者：$report"
if (-not $NoPause) { Read-Host '按回车关闭' | Out-Null }
