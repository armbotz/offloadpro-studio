function Assert-SafeTargetPath {
    param([string]$InputPath, [bool]$IsMutating = $false)
    if ([string]::IsNullOrWhiteSpace($InputPath)) {
        throw "Target path cannot be empty."
    }
    $resolved = [System.IO.Path]::GetFullPath($InputPath)
    if (Test-Path -LiteralPath $resolved) {
        $resolved = (Get-Item -LiteralPath $resolved -Force).FullName
    }
    $lower = $resolved.ToLowerInvariant()
    $forbidden = @('c:\windows', 'c:\program files', 'c:\program files (x86)', 'c:\programdata', 'c:\system volume information')
    foreach ($prefix in $forbidden) {
        if ($lower -eq $prefix -or $lower.StartsWith("$prefix\")) {
            throw "Blocked access to protected system directory: $resolved"
        }
    }
    if ($IsMutating -and $lower -eq 'c:\') {
        throw "Mutating operations on C:\ root are blocked."
    }
    return $resolved
}
