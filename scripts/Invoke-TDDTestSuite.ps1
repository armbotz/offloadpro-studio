<#
.SYNOPSIS
    OffloadPro DIT Studio v4.1 - Standalone Test-Driven Development (TDD) & Mutation Test Runner.
.DESCRIPTION
    Executes 12 deterministic Red/Green boundary, mutation, self-healing vault repair, camera OEM
    detection, taxonomy, collision, organizer, crash-resume checkpoint, two-stage deduplication,
    NLE (.ALE/.CSV) deliverables, and privacy invariant tests in an isolated temporary directory.
    Uses strongly-typed -PassThru PSCustomObject assertions and O(N) literal .Contains() checks
    with ZERO regular expressions in CI.
    Returns ExitCode 0 when all 12 tests pass, or ExitCode 1 on any assertion failure.
#>
$ErrorActionPreference = 'Stop'
$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$EnginePath = Join-Path $ScriptDir 'Invoke-OffloadProEngine.ps1'

$RawTemp    = Join-Path ([System.IO.Path]::GetTempPath()) "OffloadPro_TDD_$([guid]::NewGuid().ToString('N'))"
[void][System.IO.Directory]::CreateDirectory($RawTemp)
$TempRoot   = (Get-Item -LiteralPath $RawTemp -Force).FullName
$MockSd     = Join-Path $TempRoot 'MockSD'
$DcimDir    = Join-Path $MockSd 'DCIM\100MEDIA'
$BackupDir  = Join-Path $TempRoot 'Backups\Roll_A001'
$MirrorDir  = Join-Path $TempRoot 'Backups\Roll_A001_Mirror'
$OrgDir     = Join-Path $TempRoot 'Organized_Vault'
$DedupeDir  = Join-Path $TempRoot 'Dedupe_Vault'
$SonyMockSd = Join-Path $TempRoot 'SonyMockSD'

$Passed = 0
$Failed = 0

function Assert-Condition {
    param([bool]$Condition, [string]$TestName, [string]$FailureDetail)
    if ($Condition) {
        Write-Host "  [PASS] $TestName" -ForegroundColor Green
        $script:Passed++
    } else {
        Write-Host "  [FAIL] $TestName -> $FailureDetail" -ForegroundColor Red
        $script:Failed++
    }
}

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "OffloadPro v4.1 TDD & Mutation Test Suite (12 Red/Green Tests)" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan

try {
    [void][System.IO.Directory]::CreateDirectory($DcimDir)

    # Seed synthetic camera roll:
    # - Sequence C0001.pdf, C0002.pdf, C0004.pdf (missing C0003 -> 1 sequence gap)
    # - Live Photo pair IMG_0001.jpg + IMG_0001.mov + edited IMG_0001.aae sidecar (with later mtime)
    # - Orphan sidecar IMG_9999.xmp (no matching primary media -> 1 orphan sidecar)
    # - Tier-2 macOS AppleDouble ._IMG_0001.jpg + .DS_Store
    $captureDate   = [DateTime]::SpecifyKind([DateTime]::Parse('2026-06-15T14:30:00Z'), [DateTimeKind]::Utc)
    $laterEditDate = [DateTime]::SpecifyKind([DateTime]::Parse('2026-08-20T09:15:00Z'), [DateTimeKind]::Utc)

    foreach ($name in @('C0001.pdf', 'C0002.pdf', 'C0004.pdf')) {
        $p = Join-Path $DcimDir $name
        [System.IO.File]::WriteAllText($p, "%PDF-1.7`nSynthetic Camera Clip $name")
        [System.IO.File]::SetLastWriteTimeUtc($p, $captureDate)
    }

    $jpgPath         = Join-Path $DcimDir 'IMG_0001.jpg'
    $movPath         = Join-Path $DcimDir 'IMG_0001.mov'
    $aaePath         = Join-Path $DcimDir 'IMG_0001.aae'
    $orphanPath      = Join-Path $DcimDir 'IMG_9999.xmp'
    $appleDoublePath = Join-Path $DcimDir '._IMG_0001.jpg'
    $dsStorePath     = Join-Path $DcimDir '.DS_Store'

    [System.IO.File]::WriteAllText($jpgPath, "SYNTHETIC_JPEG_PAYLOAD_0001")
    [System.IO.File]::SetLastWriteTimeUtc($jpgPath, $captureDate)
    [System.IO.File]::WriteAllText($movPath, "SYNTHETIC_MOV_PAYLOAD_0001")
    [System.IO.File]::SetLastWriteTimeUtc($movPath, $captureDate)
    [System.IO.File]::WriteAllText($aaePath, "<plist>Protected iOS Edit</plist>")
    [System.IO.File]::SetLastWriteTimeUtc($aaePath, $laterEditDate)
    [System.IO.File]::WriteAllText($orphanPath, "<x:xmpmeta>Orphan Sidecar</x:xmpmeta>")
    [System.IO.File]::SetLastWriteTimeUtc($orphanPath, $captureDate)
    [System.IO.File]::WriteAllBytes($appleDoublePath, ([byte[]](0..63)))
    [System.IO.File]::SetLastWriteTimeUtc($appleDoublePath, $captureDate)
    [System.IO.File]::WriteAllBytes($dsStorePath, ([byte[]](0..31)))
    [System.IO.File]::SetLastWriteTimeUtc($dsStorePath, $captureDate)

    # --- TEST 1: Typed -PassThru Pre-Flight Sequence Gap, Orphan Sidecar, Live Photo & Camera OEM Detection ---
    $preflightStdout = (& $EnginePath -Action Preflight -TargetPath $MockSd *>&1 | ForEach-Object { "$_" }) -join "`n"
    $scanObj = & $EnginePath -Action Preflight -TargetPath $MockSd -PassThru 6>$null
    Assert-Condition `
        -Condition ($scanObj.sequenceGapCount -eq 1 -and $scanObj.orphanSidecarsCount -eq 1 -and $scanObj.livePhotoPairsCount -eq 1 -and $scanObj.detectedCameraOems.Count -eq 2) `
        -TestName "Test 1: Typed -PassThru Pre-Flight detects Sequence Gaps (1), Orphan Sidecars (1), Live Photos (1) & Camera OEMs (2)" `
        -FailureDetail "Gap=$($scanObj.sequenceGapCount), Orphan=$($scanObj.orphanSidecarsCount), Live=$($scanObj.livePhotoPairsCount), OEMs=$($scanObj.detectedCameraOems -join ',')"

    # --- TEST 2: Single-Read Dual-Destination (3-2-1) Offload & 3-Tier Sidecar Taxonomy Invariant ---
    $offloadRes = & $EnginePath -Action Offload -SourceRoot $MockSd -DestinationRoot $BackupDir -SecondaryDestinationRoot $MirrorDir -Algorithm SHA256 -MacMode forensic_split -VerifyLevel1 $true -VerifyLevel2 $false -VerifyLevel3 $false -Threads 2 -PassThru 6>$null
    $aaeSurvived  = (Test-Path -LiteralPath (Join-Path $BackupDir 'DCIM\100MEDIA\IMG_0001.aae')) -and
                    (Test-Path -LiteralPath (Join-Path $MirrorDir 'DCIM\100MEDIA\IMG_0001.aae'))
    $junkIsolated = (Test-Path -LiteralPath (Join-Path "${BackupDir}_forensics" 'DCIM\100MEDIA\._IMG_0001.jpg')) -and
                    (-not (Test-Path -LiteralPath (Join-Path $BackupDir 'DCIM\100MEDIA\._IMG_0001.jpg')))
    Assert-Condition `
        -Condition ($aaeSurvived -and $junkIsolated -and $offloadRes.status -eq 'GREEN_321_VERIFIED' -and $offloadRes.hashMismatches -eq 0) `
        -TestName "Test 2: Dual-Destination 3-2-1 Offload preserves .AAE on both copies & isolates ._* to _forensics" `
        -FailureDetail "aaeSurvived=$aaeSurvived, junkIsolated=$junkIsolated, status=$($offloadRes.status)"

    # --- TEST 3: 100% Full-Roll ASC-MHL Sealing & Green VerifyMhl Pass ---
    $mhlFile = Join-Path (Split-Path -Parent $BackupDir) 'Roll_A001.mhl'
    [xml]$mhlXml = Get-Content -LiteralPath $mhlFile -Raw
    $sealedCount = @($mhlXml.hashlist.hash).Count
    $verifyGreen = & $EnginePath -Action VerifyMhl -TargetPath $BackupDir -Threads 2 -PassThru 6>$null
    Assert-Condition `
        -Condition ($sealedCount -eq 7 -and $LASTEXITCODE -eq 0 -and $verifyGreen.verifiedOk -eq 7 -and $verifyGreen.totalFailures -eq 0) `
        -TestName "Test 3: 100% Full-Roll ASC-MHL Sealer seals all 7 real files & VerifyMhl passes (7/7)" `
        -FailureDetail "sealedCount=$sealedCount, ExitCode=$LASTEXITCODE, verifiedOk=$($verifyGreen.verifiedOk)"

    # --- TEST 4: Red/Green Bit-Flip Mutation Test (VerifyMhl Must Catch 1-Byte Corruption & Exit 1) ---
    $targetPdf = Join-Path $BackupDir 'DCIM\100MEDIA\C0001.pdf'
    $origBytes = [System.IO.File]::ReadAllBytes($targetPdf)
    $mutatedBytes = [byte[]]$origBytes.Clone()
    $mutatedBytes[$mutatedBytes.Length - 1] = $mutatedBytes[$mutatedBytes.Length - 1] -bxor 1
    [System.IO.File]::WriteAllBytes($targetPdf, $mutatedBytes)

    $verifyRed = & $EnginePath -Action VerifyMhl -TargetPath $BackupDir -Threads 2 -PassThru 6>$null
    $bitrotExitCode = $LASTEXITCODE
    Assert-Condition `
        -Condition ($bitrotExitCode -eq 1 -and $verifyRed.bitrotCount -eq 1 -and $verifyRed.totalFailures -eq 1) `
        -TestName "Test 4: Bit-Flip Mutation Test catches 1-bit corruption (same file size) & returns ExitCode 1" `
        -FailureDetail "Expected ExitCode 1 and bitrotCount=1, got ExitCode=$bitrotExitCode, bitrotCount=$($verifyRed.bitrotCount)"

    # --- TEST 5: Self-Healing 3-2-1 Vault Repair (-Action HealFromMirror) ---
    $healRes = & $EnginePath -Action HealFromMirror -TargetPath $BackupDir -SourceRoot $MirrorDir -Threads 2 -PassThru 6>$null
    $healExitCode = $LASTEXITCODE
    $verifyAfterHeal = & $EnginePath -Action VerifyMhl -TargetPath $BackupDir -Threads 2 -PassThru 6>$null
    Assert-Condition `
        -Condition ($healExitCode -eq 0 -and $healRes.corruptedFound -eq 1 -and $healRes.healedCount -eq 1 -and $healRes.unhealableCount -eq 0 -and $verifyAfterHeal.verifiedOk -eq 7) `
        -TestName "Test 5: Self-Healing Vault (-Action HealFromMirror) repairs 1-bit rot from verified Mirror & restores 7/7 MHL seal" `
        -FailureDetail "healExitCode=$healExitCode, healed=$($healRes.healedCount), postVerifyOk=$($verifyAfterHeal.verifiedOk)"

    # --- TEST 6: Roll-Name Collision Guard Test ---
    [System.IO.File]::WriteAllText($targetPdf, "%PDF-1.7`nDIFFERENT_ROLL_COLLISION_SIZE_PAYLOAD_LONGER")
    $collisionBlocked = $false
    try {
        [void](& $EnginePath -Action Offload -SourceRoot $MockSd -DestinationRoot $BackupDir -VerifyLevel1 $true -VerifyLevel2 $false *>&1)
    } catch {
        if ($_.Exception.Message.Contains('DIT ROLL-COLLISION GUARD BLOCKED')) {
            $collisionBlocked = $true
        }
    }
    Assert-Condition `
        -Condition $collisionBlocked `
        -TestName "Test 6: Roll-Name Collision Guard blocks accidental overwrite of different-sized roll clip" `
        -FailureDetail "Collision guard did not throw expected exception."
    [System.IO.File]::WriteAllBytes($targetPdf, $origBytes)
    [System.IO.File]::SetLastWriteTimeUtc($targetPdf, $captureDate)

    # --- TEST 7: Non-Destructive Sidecar-Glued Date Organizer (-Action OrganizeByDate) ---
    $orgRes = & $EnginePath -Action OrganizeByDate -SourceRoot $BackupDir -DestinationRoot $OrgDir -PassThru 6>$null
    $expectedBucket = Join-Path $OrgDir '2026\2026-06-15'
    $gluedTogether = (Test-Path -LiteralPath (Join-Path $expectedBucket 'IMG_0001.jpg')) -and
                     (Test-Path -LiteralPath (Join-Path $expectedBucket 'IMG_0001.mov')) -and
                     (Test-Path -LiteralPath (Join-Path $expectedBucket 'IMG_0001.aae'))
    Assert-Condition `
        -Condition ($gluedTogether -and $orgRes.organizedFiles -eq 7 -and $orgRes.dateBuckets -eq 1) `
        -TestName "Test 7: OrganizeByDate glues Live Photo (.JPG+.MOV) and later-edited .AAE into same YYYY\YYYY-MM-DD bucket" `
        -FailureDetail "gluedTogether=$gluedTogether, organizedFiles=$($orgRes.organizedFiles)"

    # --- TEST 8: Zero-PII stdout Privacy Invariant (Deterministic .Contains Check, Zero Regex) ---
    $leakedPii = $preflightStdout.Contains('IMG_0001') -or
                 $preflightStdout.Contains('IMG_9999') -or
                 $preflightStdout.Contains('C0001.pdf') -or
                 $preflightStdout.Contains('C0002.pdf')
    Assert-Condition `
        -Condition (-not $leakedPii) `
        -TestName "Test 8: Zero-PII stdout Privacy Invariant (0 personal filenames printed to console)" `
        -FailureDetail "Personal filename detected in stdout!"

    # --- TEST 9: OS Professor Crash-Resumable Checkpoint Invariant ---
    $resumeRes = & $EnginePath -Action Offload -SourceRoot $MockSd -DestinationRoot $BackupDir -Algorithm SHA256 -MacMode forensic_split -VerifyLevel1 $true -VerifyLevel2 $false -VerifyLevel3 $false -Threads 2 -PassThru 6>$null
    Assert-Condition `
        -Condition ($resumeRes.resumedFiles -eq 9 -and $resumeRes.newlyCopied -eq 0 -and $resumeRes.hashMismatches -eq 0) `
        -TestName "Test 9: Crash-Resumable Checkpoint resumes all 9 intact files with 0 re-copies & 0 mismatches" `
        -FailureDetail "resumedFiles=$($resumeRes.resumedFiles), newlyCopied=$($resumeRes.newlyCopied)"

    # --- TEST 10: Systems Design Professor Two-Stage Deduplication Engine (-Action DedupeScan) ---
    [void][System.IO.Directory]::CreateDirectory($DedupeDir)
    [System.IO.File]::WriteAllText((Join-Path $DedupeDir 'Clip_Original.mov'), "EXACT_SAME_32_BYTE_PAYLOAD_AAAA!")
    [System.IO.File]::WriteAllText((Join-Path $DedupeDir 'Clip_TrueDupe.mov'), "EXACT_SAME_32_BYTE_PAYLOAD_AAAA!")
    [System.IO.File]::WriteAllText((Join-Path $DedupeDir 'Clip_SameSizeDiffContent.mov'), "EXACT_SAME_32_BYTE_PAYLOAD_BBBB!")
    [System.IO.File]::WriteAllText((Join-Path $DedupeDir 'Clip_UniqueSize.mov'), "UNIQUE_SIZE_PAYLOAD")

    $dedupeRes = & $EnginePath -Action DedupeScan -TargetPath $DedupeDir -Algorithm SHA256 -Threads 2 -PassThru 6>$null
    Assert-Condition `
        -Condition ($dedupeRes.totalScanned -eq 4 -and $dedupeRes.sameSizeCandidates -eq 3 -and $dedupeRes.trueDuplicates -eq 1) `
        -TestName "Test 10: Two-Stage DedupeScan filters unique sizes in O(1) & distinguishes true duplicate from same-size collision" `
        -FailureDetail "total=$($dedupeRes.totalScanned), candidates=$($dedupeRes.sameSizeCandidates), dupes=$($dedupeRes.trueDuplicates)"

    # --- TEST 11: Lead DIT NLE Post-House Deliverables (.ALE & .CSV) ---
    $aleFile = Join-Path (Split-Path -Parent $BackupDir) 'Roll_A001.ale'
    $csvFile = Join-Path (Split-Path -Parent $BackupDir) 'Roll_A001_PostHouse_Manifest.csv'
    $aleRaw  = if (Test-Path -LiteralPath $aleFile) { Get-Content -LiteralPath $aleFile -Raw } else { '' }
    $aleExists = ($aleRaw.Length -gt 0) -and $aleRaw.Contains('FPS') -and $aleRaw.Contains('Roll_A001')
    $csvExists = (Test-Path -LiteralPath $csvFile) -and (@(Get-Content -LiteralPath $csvFile).Count -eq 8)
    Assert-Condition `
        -Condition ($aleExists -and $csvExists) `
        -TestName "Test 11: NLE Post-House Deliverables generates valid Avid/Resolve .ALE & 7-clip .CSV manifest" `
        -FailureDetail "aleExists=$aleExists, csvExists=$csvExists"

    # --- TEST 12: Camera-Vendor OEM Structure Warning (Sony M4ROOT\CLIP without MEDIAPRO.XML) ---
    $sonyClipDir = Join-Path $SonyMockSd 'PRIVATE\M4ROOT\CLIP'
    [void][System.IO.Directory]::CreateDirectory($sonyClipDir)
    [System.IO.File]::WriteAllText((Join-Path $sonyClipDir 'C0001.MP4'), "SONY_XAVC_CLIP_PAYLOAD")
    $sonyScan = & $EnginePath -Action Preflight -TargetPath $SonyMockSd -PassThru 6>$null
    Assert-Condition `
        -Condition ($sonyScan.detectedCameraOems -contains 'Sony XAVC / Cinema Line' -and $sonyScan.oemStructureWarnings.Count -eq 1) `
        -TestName "Test 12: Camera-Vendor OEM Recognizer flags Sony M4ROOT\CLIP missing MEDIAPRO.XML conform metadata" `
        -FailureDetail "OEMs=$($sonyScan.detectedCameraOems -join ','), Warnings=$($sonyScan.oemStructureWarnings.Count)"

} finally {
    Remove-Item -LiteralPath $TempRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "----------------------------------------------------------------" -ForegroundColor Cyan
Write-Host "TDD Summary: $Passed Passed, $Failed Failed" -ForegroundColor $(if ($Failed -eq 0) { 'Green' } else { 'Red' })
if ($Failed -gt 0) { exit 1 }
exit 0
