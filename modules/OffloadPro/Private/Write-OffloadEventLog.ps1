function Write-OffloadEventLog {
    param([int]$EventId, [string]$EntryType = 'Information', [string]$Message)
    try {
        if ([System.Diagnostics.EventLog]::SourceExists('OffloadProDIT')) {
            Write-EventLog -LogName 'Application' -Source 'OffloadProDIT' -EventId $EventId -EntryType $EntryType -Message $Message -ErrorAction SilentlyContinue
        }
    } catch {}
}
