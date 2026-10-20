# Reads the Windows System Media Transport Controls session (what the shell
# shows in the volume flyout) and prints one JSON line per poll.
# Works for the NetEase client as well as any other player; the overlay picks
# which session it wants.
$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false

Add-Type -AssemblyName System.Runtime.WindowsRuntime

$asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
        $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and
        $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
    })[0]

function Await($WinRtTask, $ResultType) {
    $asTask = $asTaskGeneric.MakeGenericMethod($ResultType)
    $netTask = $asTask.Invoke($null, @($WinRtTask))
    $netTask.Wait(-1) | Out-Null
    $netTask.Result
}

$null = [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager, Windows.Media, ContentType = WindowsRuntime]
$mgr = Await ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager]::RequestAsync()) ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager])

$intervalMs = 250
if ($args.Count -ge 1) {
    $parsed = 0
    if ([int]::TryParse([string]$args[0], [ref]$parsed) -and $parsed -ge 50) { $intervalMs = $parsed }
}

while ($true) {
    $now = [DateTimeOffset]::Now
    $list = New-Object System.Collections.ArrayList

    $sessions = @()
    try { $sessions = @($mgr.GetSessions()) } catch { $sessions = @() }

    foreach ($s in $sessions) {
        $o = [ordered]@{
            app    = [string]$s.SourceAppUserModelId
            title  = ''
            artist = ''
            album  = ''
            status = ''
            pos    = 0.0
            dur    = 0.0
        }
        try {
            $props = Await ($s.TryGetMediaPropertiesAsync()) ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties])
            if ($null -ne $props) {
                $o.title = [string]$props.Title
                $o.artist = [string]$props.Artist
                $o.album = [string]$props.AlbumTitle
            }
        }
        catch { }
        try {
            $info = $s.GetPlaybackInfo()
            $o.status = [string]$info.PlaybackStatus
            $tl = $s.GetTimelineProperties()
            $o.pos = [double]$tl.Position.TotalSeconds
            $o.dur = [double]$tl.EndTime.TotalSeconds
            # Position is sampled at LastUpdatedTime, NOT at this poll.
            # Some players update the timeline only on play/pause/seek.
            try {
                $updated = [DateTimeOffset]$tl.LastUpdatedTime
                if ($updated.ToUnixTimeMilliseconds() -gt 0) {
                    $o.timeline_t = [double]$updated.ToUnixTimeMilliseconds()
                }
            } catch { }
            try {
                if ($null -ne $info.PlaybackRate) { $o.rate = [double]$info.PlaybackRate }
            } catch { }
        }
        catch { }
        [void]$list.Add($o)
    }

    $payload = [ordered]@{
        ok       = $true
        t        = [double]$now.ToUnixTimeMilliseconds()
        sessions = $list
    }
    try {
        $json = $payload | ConvertTo-Json -Compress -Depth 5
    }
    catch {
        $json = '{"ok":false,"sessions":[]}'
    }
    [Console]::Out.WriteLine($json)
    [Console]::Out.Flush()

    Start-Sleep -Milliseconds $intervalMs
}
