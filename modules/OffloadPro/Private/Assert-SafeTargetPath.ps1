function Assert-SafeTargetPath {
    param([string]$InputPath, [bool]$IsMutating = $false)
    if ([string]::IsNullOrWhiteSpace($InputPath)) {
        throw "Target path cannot be empty."
    }
    $trimmedInput = $InputPath.Trim()
    $lowerInput   = $trimmedInput.Replace('/', '\').ToLowerInvariant()

    # Cross-platform check for protected Windows & macOS/POSIX system directories
    $winForbidden = @('c:\windows', 'c:\program files', 'c:\program files (x86)', 'c:\programdata', 'c:\system volume information')
    foreach ($prefix in $winForbidden) {
        if ($lowerInput -eq $prefix -or $lowerInput.StartsWith("$prefix\")) {
            throw "Blocked access to protected system directory: $InputPath"
        }
    }
    if ($IsMutating -and ($lowerInput -eq 'c:\' -or $lowerInput -eq 'c:')) {
        throw "Mutating operations on C:\ root are blocked."
    }

    $posixLower = $trimmedInput.Replace('\', '/').ToLowerInvariant()
    $macForbidden = @('/system', '/bin', '/sbin', '/usr', '/etc', '/library')
    foreach ($mp in $macForbidden) {
        if ($posixLower -eq $mp -or $posixLower.StartsWith("$mp/")) {
            throw "Blocked access to protected system directory: $InputPath"
        }
    }
    if ($IsMutating -and $posixLower -eq '/') {
        throw "Mutating operations on / root are blocked."
    }

    $resolved = [System.IO.Path]::GetFullPath($trimmedInput)
    if (Test-Path -LiteralPath $resolved) {
        $resolved = (Get-Item -LiteralPath $resolved -Force).FullName
    }
    return $resolved
}
