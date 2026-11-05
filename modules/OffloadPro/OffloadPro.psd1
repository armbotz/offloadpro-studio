@{
    RootModule = 'OffloadPro.psm1'
    ModuleVersion = '4.4.0'
    GUID = 'a73d57b1-2184-4869-923f-e9b46e3e5714'
    Author = 'OffloadPro Open-Source Community'
    CompanyName = 'OffloadPro Studio'
    Copyright = '(c) 2026 OffloadPro. MIT License.'
    Description = 'Professional media offload, ASC-MHL & NLE sealer, self-healing 3-2-1 vault, and reversible card release engine.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @('Start-OffloadProSession', 'Test-MediaParity', 'Repair-MediaVault', 'Test-MediaArchive', 'New-CameraProxy', 'Clear-CameraCard', 'Undo-CardClear', 'Get-CameraCardXRay', 'Find-DuplicateMedia', 'Invoke-MediaOrganization')
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
}
