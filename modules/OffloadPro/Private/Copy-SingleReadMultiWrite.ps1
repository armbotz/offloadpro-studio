# OS Professor Kernel I/O Optimization: SequentialScan Read-Ahead Hint + Explicit Hardware FlushFileBuffers
function Copy-SingleReadMultiWrite {
    param(
        [string]$SourceFile,
        [string[]]$TargetFiles,
        [string]$HashAlgorithm
    )
    $hasher = New-CryptoHasher -HashAlgorithm $HashAlgorithm
    $buf = New-Object byte[] (4 * 1024 * 1024)
    $inStream = New-Object System.IO.FileStream(
        $SourceFile,
        [System.IO.FileMode]::Open,
        [System.IO.FileAccess]::Read,
        [System.IO.FileShare]::Read,
        (4 * 1024 * 1024),
        [System.IO.FileOptions]::SequentialScan
    )
    $outStreams = New-Object 'System.Collections.Generic.List[System.IO.FileStream]'
    try {
        foreach ($tf in $TargetFiles) {
            $dir = Split-Path -Parent $tf
            if (-not (Test-Path -LiteralPath $dir)) {
                [void][System.IO.Directory]::CreateDirectory($dir)
            }
            $outStreams.Add((New-Object System.IO.FileStream(
                $tf,
                [System.IO.FileMode]::Create,
                [System.IO.FileAccess]::Write,
                [System.IO.FileShare]::None,
                (4 * 1024 * 1024),
                [System.IO.FileOptions]::SequentialScan
            )))
        }
        while (($read = $inStream.Read($buf, 0, $buf.Length)) -gt 0) {
            [void]$hasher.TransformBlock($buf, 0, $read, $buf, 0)
            foreach ($os in $outStreams) {
                $os.Write($buf, 0, $read)
            }
        }
        foreach ($os in $outStreams) {
            $os.Flush($true)
        }
        [void]$hasher.TransformFinalBlock($buf, 0, 0)
        return [System.BitConverter]::ToString($hasher.Hash).Replace('-', '')
    } finally {
        $inStream.Dispose()
        foreach ($os in $outStreams) { $os.Dispose() }
        $hasher.Dispose()
    }
}
