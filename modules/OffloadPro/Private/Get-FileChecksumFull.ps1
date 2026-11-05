function Get-FileChecksumFull {
    param([string]$FilePath, [string]$HashAlgorithm)
    $hasher = New-CryptoHasher -HashAlgorithm $HashAlgorithm
    $s = New-Object System.IO.FileStream(
        $FilePath,
        [System.IO.FileMode]::Open,
        [System.IO.FileAccess]::Read,
        [System.IO.FileShare]::Read,
        (4 * 1024 * 1024),
        [System.IO.FileOptions]::SequentialScan
    )
    try {
        return [System.BitConverter]::ToString($hasher.ComputeHash($s)).Replace('-', '')
    } finally {
        $s.Dispose()
        $hasher.Dispose()
    }
}
