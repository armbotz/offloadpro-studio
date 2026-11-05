function Set-ExecutionAwakeLock {
    param([bool]$Enable)
    try {
        Initialize-OffloadProPInvoke
        $ES_CONTINUOUS      = [uint32]2147483648
        $ES_SYSTEM_REQUIRED = [uint32]1
        if ($Enable) {
            [void][OffloadPro.PowerGuard]::SetThreadExecutionState($ES_CONTINUOUS -bor $ES_SYSTEM_REQUIRED)
        } else {
            [void][OffloadPro.PowerGuard]::SetThreadExecutionState($ES_CONTINUOUS)
        }
    } catch {}
}
