function New-CryptoHasher {
    param([string]$HashAlgorithm)
    switch ($HashAlgorithm.ToUpperInvariant()) {
        'MD5'    { return [System.Security.Cryptography.MD5]::Create() }
        'SHA1'   { return [System.Security.Cryptography.SHA1]::Create() }
        default  { return [System.Security.Cryptography.SHA256]::Create() }
    }
}
