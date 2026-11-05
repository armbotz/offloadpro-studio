function Get-RelativePathSafe {
    param([string]$BasePath, [string]$FullPath)
    $cleanBase = $BasePath.TrimEnd('\', '/')
    if ($FullPath.StartsWith($cleanBase, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $FullPath.Substring($cleanBase.Length).TrimStart('\', '/')
    }
    return [System.IO.Path]::GetFileName($FullPath)
}
