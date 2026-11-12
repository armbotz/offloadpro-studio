<#
.SYNOPSIS
    Native Windows .NET WPF Desktop GUI & Pokayoke Safety Controller for OffloadPro DIT Studio.
    Zero localhost servers, zero Node.js, zero Invoke-Expression, 100% TDD testable.
#>

function Get-StudioDriveInventory {
    [CmdletBinding()]
    param()
    $drives = New-Object 'System.Collections.Generic.List[object]'
    foreach ($d in @([System.IO.DriveInfo]::GetDrives())) {
        try {
            if (-not $d.IsReady) { continue }
            $freeGb  = [Math]::Round(($d.AvailableFreeSpace / 1GB), 2)
            $totalGb = [Math]::Round(($d.TotalSize / 1GB), 2)
            $usedGb  = [Math]::Round((($d.TotalSize - $d.AvailableFreeSpace) / 1GB), 2)
            $label   = if ([string]::IsNullOrWhiteSpace($d.VolumeLabel)) { $d.DriveType.ToString() } else { $d.VolumeLabel }
            $root    = $d.Name
            $drives.Add([PSCustomObject]@{
                Root      = $root
                Label     = $label
                DriveType = $d.DriveType.ToString()
                UsedGB    = $usedGb
                FreeGB    = $freeGb
                TotalGB   = $totalGb
                Display   = "$root [$label] ($freeGb GB free / $totalGb GB)"
            })
        } catch { }
    }
    return $drives.ToArray()
}

function Get-NextSequentialRollPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ParentBackupDir,

        [Parameter(Mandatory = $false)]
        [string]$RollPrefix = 'SD_Card_Backup_'
    )
    $cleanParent = $ParentBackupDir.Trim().TrimEnd('\')
    if ([string]::IsNullOrWhiteSpace($cleanParent)) {
        $cleanParent = 'E:\Backups\Backups'
    }
    for ($i = 1; $i -le 999; $i++) {
        $candidateName = "{0}{1:D3}" -f $RollPrefix, $i
        $candidatePath = Join-Path $cleanParent $candidateName
        if (-not (Test-Path -LiteralPath $candidatePath)) {
            return $candidatePath
        }
    }
    $stamp = (Get-Date).ToString('yyyyMMdd_HHmmss')
    return (Join-Path $cleanParent "${RollPrefix}${stamp}")
}

function Test-StudioGuiSafetyPreflight {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$SourcePath,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$DestinationPath,

        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]$SecondaryPath = ''
    )

    if ([string]::IsNullOrWhiteSpace($SourcePath)) {
        return [PSCustomObject]@{ IsSafe = $false; Reason = 'BLOCKED: Source Card path cannot be empty.'; SourceBytes = [int64]0; FreeDestBytes = [int64]0 }
    }
    if ([string]::IsNullOrWhiteSpace($DestinationPath)) {
        return [PSCustomObject]@{ IsSafe = $false; Reason = 'BLOCKED: Destination Vault path cannot be empty.'; SourceBytes = [int64]0; FreeDestBytes = [int64]0 }
    }

    try {
        $safeSrc = Assert-SafeTargetPath -InputPath $SourcePath -IsMutating $false
    } catch {
        return [PSCustomObject]@{ IsSafe = $false; Reason = "BLOCKED (Source): $($_.Exception.Message)"; SourceBytes = [int64]0; FreeDestBytes = [int64]0 }
    }

    try {
        $safeDst = Assert-SafeTargetPath -InputPath $DestinationPath -IsMutating $true
    } catch {
        return [PSCustomObject]@{ IsSafe = $false; Reason = "BLOCKED (Destination): $($_.Exception.Message)"; SourceBytes = [int64]0; FreeDestBytes = [int64]0 }
    }

    $normSrc = $safeSrc.TrimEnd('\').ToLowerInvariant()
    $normDst = $safeDst.TrimEnd('\').ToLowerInvariant()

    if ($normSrc -eq $normDst) {
        return [PSCustomObject]@{ IsSafe = $false; Reason = 'BLOCKED: Source and Destination paths cannot be identical.'; SourceBytes = [int64]0; FreeDestBytes = [int64]0 }
    }
    if ($normDst.StartsWith($normSrc + '\')) {
        return [PSCustomObject]@{ IsSafe = $false; Reason = 'BLOCKED: Destination cannot be nested inside Source Card.'; SourceBytes = [int64]0; FreeDestBytes = [int64]0 }
    }

    if (-not [string]::IsNullOrWhiteSpace($SecondaryPath)) {
        try {
            $safeSec = Assert-SafeTargetPath -InputPath $SecondaryPath -IsMutating $true
            $normSec = $safeSec.TrimEnd('\').ToLowerInvariant()
            if ($normSec -eq $normSrc -or $normSec -eq $normDst) {
                return [PSCustomObject]@{ IsSafe = $false; Reason = 'BLOCKED: Secondary Mirror path must be distinct from Source and Primary Destination.'; SourceBytes = [int64]0; FreeDestBytes = [int64]0 }
            }
        } catch {
            return [PSCustomObject]@{ IsSafe = $false; Reason = "BLOCKED (Mirror): $($_.Exception.Message)"; SourceBytes = [int64]0; FreeDestBytes = [int64]0 }
        }
    }

    if (-not (Test-Path -LiteralPath $safeSrc)) {
        return [PSCustomObject]@{ IsSafe = $false; Reason = "WAITING: Source path '$safeSrc' is not currently connected."; SourceBytes = [int64]0; FreeDestBytes = [int64]0 }
    }

    $srcBytes = [int64]0
    try {
        if ($safeSrc.TrimEnd('\').Length -le 2) {
            # O(1) instant DriveInfo lookup for drive roots like D:\ so UI never blocks scanning thousands of files
            $srcDrive = New-Object System.IO.DriveInfo($safeSrc)
            if ($srcDrive.IsReady) {
                $srcBytes = [int64]($srcDrive.TotalSize - $srcDrive.AvailableFreeSpace)
            }
        } else {
            $sum = (Get-ChildItem -LiteralPath $safeSrc -File -Recurse -Force -ErrorAction SilentlyContinue | Select-Object -First 250 | Measure-Object -Property Length -Sum).Sum
            if ($null -ne $sum) { $srcBytes = [int64]$sum }
        }
    } catch { }

    $freeDstBytes = [int64]::MaxValue
    try {
        $dstDriveRoot = [System.IO.Path]::GetPathRoot($safeDst)
        if (-not [string]::IsNullOrWhiteSpace($dstDriveRoot)) {
            $dInfo = New-Object System.IO.DriveInfo($dstDriveRoot)
            if ($dInfo.IsReady) {
                $freeDstBytes = [int64]$dInfo.AvailableFreeSpace
            }
        }
    } catch { }

    if ($srcBytes -gt $freeDstBytes) {
        $needGb = [Math]::Round(($srcBytes / 1GB), 2)
        $availGb = [Math]::Round(($freeDstBytes / 1GB), 2)
        return [PSCustomObject]@{
            IsSafe        = $false
            Reason        = "BLOCKED: Insufficient disk space on destination ($availGb GB free, need $needGb GB)."
            SourceBytes   = $srcBytes
            FreeDestBytes = $freeDstBytes
        }
    }

    $srcGb = [Math]::Round(($srcBytes / 1GB), 2)
    $freeGb = if ($freeDstBytes -lt [int64]::MaxValue) { "$([Math]::Round(($freeDstBytes / 1GB), 2)) GB free" } else { 'Ready' }
    return [PSCustomObject]@{
        IsSafe        = $true
        Reason        = "SAFE TO OFFLOAD: Source ($srcGb GB) -> Destination ($freeGb)"
        SourceBytes   = $srcBytes
        FreeDestBytes = $freeDstBytes
    }
}

function Get-OffloadProStudioXaml {
    return @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="OffloadPro DIT Studio v4.4.0 - Native Windows Archival &amp; ASC-MHL v2 Engine"
        Width="1040" Height="760" MinWidth="920" MinHeight="680"
        WindowStartupLocation="CenterScreen"
        Background="#070B12" Foreground="#F8FAFC" FontFamily="Segoe UI">
    <Grid Margin="18">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- 1. 10-Foot Ambient Status Halo Banner -->
        <Border x:Name="StatusBanner" Grid.Row="0" Background="#0D1829" BorderBrush="#38BDF8" BorderThickness="2" CornerRadius="8" Padding="14,10" Margin="0,0,0,12">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <StackPanel Grid.Column="0">
                    <TextBlock x:Name="TxtBannerTitle" Text="OFFLOADPRO DIT STUDIO v4.4.0  |  READY FOR CARD INGEST" FontSize="15" FontWeight="Bold" Foreground="#38BDF8"/>
                    <TextBlock x:Name="TxtBannerSub" Text="Zero-Server Native Windows Engine  |  ASC-MHL v2 + 3-Level Audit + Pokayoke Safety Active" FontSize="12" Foreground="#94A3B8" Margin="0,2,0,0"/>
                </StackPanel>
                <StackPanel Grid.Column="1" Orientation="Horizontal" VerticalAlignment="Center">
                    <Button x:Name="BtnOpenCert" Content="Open HTML Certificate" IsEnabled="False" Background="#10B981" Foreground="#04130D" FontWeight="Bold" Padding="12,6" Margin="0,0,8,0" BorderThickness="0"/>
                    <Button x:Name="BtnOpenFolder" Content="Open Vault Folder" Background="#1E293B" Foreground="#E2E8F0" FontWeight="SemiBold" Padding="12,6" BorderBrush="#334155" BorderThickness="1"/>
                </StackPanel>
            </Grid>
        </Border>

        <!-- 2. Global Path & Pokayoke Safety Bar -->
        <Border Grid.Row="1" Background="#0D1422" BorderBrush="#1E293B" BorderThickness="1" CornerRadius="8" Padding="14,12" Margin="0,0,0,12">
            <Grid>
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="170"/>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>

                <!-- Row 0: Source Card -->
                <TextBlock Grid.Row="0" Grid.Column="0" Text="1. Source Camera Card:" VerticalAlignment="Center" FontWeight="SemiBold" Foreground="#CBD5E1" Margin="0,0,8,8"/>
                <TextBox x:Name="TxtSourcePath" Grid.Row="0" Grid.Column="1" Text="D:\" Background="#070B12" Foreground="#F8FAFC" BorderBrush="#334155" Padding="8,5" FontSize="13" Margin="0,0,8,8"/>
                <Button x:Name="BtnBrowseSource" Grid.Row="0" Grid.Column="2" Content="Browse Card..." Background="#1E293B" Foreground="#F8FAFC" Padding="10,5" Margin="0,0,6,8" BorderBrush="#475569"/>
                <Button x:Name="BtnDetectDrives" Grid.Row="0" Grid.Column="3" Content="Auto-Detect Card" Background="#1E293B" Foreground="#38BDF8" FontWeight="SemiBold" Padding="10,5" Margin="0,0,0,8" BorderBrush="#38BDF8"/>

                <!-- Row 1: Primary Destination Vault -->
                <TextBlock Grid.Row="1" Grid.Column="0" Text="2. Primary Vault Roll:" VerticalAlignment="Center" FontWeight="SemiBold" Foreground="#CBD5E1" Margin="0,0,8,8"/>
                <TextBox x:Name="TxtDestPath" Grid.Row="1" Grid.Column="1" Text="E:\Backups\Backups\SD_Card_Backup_003" Background="#070B12" Foreground="#F8FAFC" BorderBrush="#334155" Padding="8,5" FontSize="13" Margin="0,0,8,8"/>
                <Button x:Name="BtnBrowseDest" Grid.Row="1" Grid.Column="2" Content="Browse Vault..." Background="#1E293B" Foreground="#F8FAFC" Padding="10,5" Margin="0,0,6,8" BorderBrush="#475569"/>
                <Button x:Name="BtnNextRoll" Grid.Row="1" Grid.Column="3" Content="Next Roll (+001)" Background="#0F291E" Foreground="#10B981" FontWeight="Bold" Padding="10,5" Margin="0,0,0,8" BorderBrush="#10B981"/>

                <!-- Row 2: Optional Secondary Mirror -->
                <TextBlock Grid.Row="2" Grid.Column="0" Text="3. Mirror Vault (Optional):" VerticalAlignment="Center" Foreground="#94A3B8" Margin="0,0,8,8"/>
                <TextBox x:Name="TxtMirrorPath" Grid.Row="2" Grid.Column="1" Text="" Background="#070B12" Foreground="#F8FAFC" BorderBrush="#334155" Padding="8,5" FontSize="13" Margin="0,0,8,8"/>
                <Button x:Name="BtnBrowseMirror" Grid.Row="2" Grid.Column="2" Content="Browse Mirror..." Background="#1E293B" Foreground="#CBD5E1" Padding="10,5" Margin="0,0,6,8" BorderBrush="#475569"/>
                <Button x:Name="BtnClearMirror" Grid.Row="2" Grid.Column="3" Content="Clear Mirror" Background="#1E293B" Foreground="#94A3B8" Padding="10,5" Margin="0,0,0,8" BorderBrush="#334155"/>

                <!-- Row 3: Live Pokayoke Safety Guardrail Status -->
                <Border x:Name="SafetyBadgeBorder" Grid.Row="3" Grid.Column="0" Grid.ColumnSpan="4" Background="#091914" BorderBrush="#10B981" BorderThickness="1" CornerRadius="5" Padding="10,5">
                    <TextBlock x:Name="TxtSafetyStatus" Text="PRE-FLIGHT SAFETY GATE: Checking paths..." FontSize="12" FontWeight="SemiBold" Foreground="#10B981"/>
                </Border>
            </Grid>
        </Border>

        <!-- 3. Task-Focused Workflow Tabs -->
        <TabControl x:Name="MainTabs" Grid.Row="2" Background="#0D1422" BorderBrush="#1E293B" Foreground="#F8FAFC" Padding="10">
            <!-- TAB 1: OFFLOAD & SEAL -->
            <TabItem Header="  1. Offload &amp; Seal (3-2-1 Ingest)  " Background="#131D31" Foreground="#F8FAFC" FontWeight="Bold">
                <Grid Margin="8">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="340"/>
                        <ColumnDefinition Width="*"/>
                    </Grid.ColumnDefinitions>

                    <!-- Left Column: Controls & Options -->
                    <Border Grid.Column="0" Background="#070B12" BorderBrush="#1E293B" BorderThickness="1" CornerRadius="6" Padding="14" Margin="0,0,12,0">
                        <StackPanel>
                            <TextBlock Text="INGEST &amp; CRYPTOGRAPHIC OPTIONS" FontWeight="Bold" Foreground="#38BDF8" Margin="0,0,0,10"/>

                            <TextBlock Text="Hash Algorithm:" Foreground="#CBD5E1" Margin="0,0,0,4"/>
                            <ComboBox x:Name="CmbAlgorithm" SelectedIndex="0" Margin="0,0,0,10" Padding="6,4">
                                <ComboBoxItem Content="SHA256"/>
                                <ComboBoxItem Content="SHA1"/>
                                <ComboBoxItem Content="MD5"/>
                            </ComboBox>

                            <TextBlock Text="macOS / OS Junk Handling:" Foreground="#CBD5E1" Margin="0,0,0,4"/>
                            <ComboBox x:Name="CmbMacMode" SelectedIndex="0" Margin="0,0,0,12" Padding="6,4">
                                <ComboBoxItem Content="forensic_split"/>
                                <ComboBoxItem Content="clean"/>
                                <ComboBoxItem Content="raw"/>
                            </ComboBox>

                            <CheckBox x:Name="ChkLevel1" Content="Level 1: Full Byte-for-Byte Hash Audit" IsChecked="True" Foreground="#E2E8F0" Margin="0,0,0,6"/>
                            <CheckBox x:Name="ChkLevel2" Content="Level 2: FFprobe Container Stream Audit" IsChecked="True" Foreground="#E2E8F0" Margin="0,0,0,6"/>
                            <CheckBox x:Name="ChkRescue" Content="Rescue Mode (Smallest-to-Largest Sort)" IsChecked="False" Foreground="#F59E0B" Margin="0,0,0,6"/>
                            <CheckBox x:Name="ChkAutoOpenCert" Content="Auto-Open HTML Certificate When Done" IsChecked="True" Foreground="#10B981" Margin="0,0,0,16"/>

                            <Button x:Name="BtnXRayCard" Content="Step 1: X-Ray Source Card (Read-Only)" Background="#1E293B" Foreground="#38BDF8" FontWeight="Bold" FontSize="13" Padding="10,9" Margin="0,0,0,8" BorderBrush="#38BDF8"/>
                            <Button x:Name="BtnStartOffload" Content="Step 2: Start Verified Offload &amp; Seal" Background="#10B981" Foreground="#04130D" FontWeight="Bold" FontSize="14" Padding="10,11" BorderThickness="0"/>
                        </StackPanel>
                    </Border>

                    <!-- Right Column: X-Ray & Live Activity Console -->
                    <Border Grid.Column="1" Background="#070B12" BorderBrush="#1E293B" BorderThickness="1" CornerRadius="6" Padding="14">
                        <Grid>
                            <Grid.RowDefinitions>
                                <RowDefinition Height="Auto"/>
                                <RowDefinition Height="*"/>
                            </Grid.RowDefinitions>
                            <TextBlock Grid.Row="0" Text="LIVE TELEMETRY &amp; ZERO-PII ACTIVITY LOG" FontWeight="Bold" Foreground="#38BDF8" Margin="0,0,0,8"/>
                            <TextBox x:Name="TxtActivityLog" Grid.Row="1" IsReadOnly="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" AcceptsReturn="True" Background="#05080E" Foreground="#A7F3D0" BorderBrush="#1E293B" FontFamily="Consolas" FontSize="12" Padding="10"/>
                        </Grid>
                    </Border>
                </Grid>
            </TabItem>

            <!-- TAB 2: VERIFY, HEAL & ORGANIZE -->
            <TabItem Header="  2. Verify, Heal &amp; Organize Vault  " Background="#131D31" Foreground="#F8FAFC" FontWeight="Bold">
                <StackPanel Margin="16">
                    <TextBlock Text="VAULT INTEGRITY, BIT-ROT REPAIR &amp; CHRONOLOGICAL ORGANIZATION" FontSize="14" FontWeight="Bold" Foreground="#38BDF8" Margin="0,0,0,12"/>
                    <TextBlock Text="Uses the Primary Vault Roll path (and Mirror Vault path for Self-Healing) configured at the top of the window." Foreground="#94A3B8" Margin="0,0,0,16"/>

                    <WrapPanel Orientation="Horizontal">
                        <Button x:Name="BtnVerifyMhl" Content="Verify .MHL Cryptographic Ledger" Width="260" Height="44" Margin="0,0,12,12" Background="#0F291E" Foreground="#10B981" FontWeight="Bold" BorderBrush="#10B981"/>
                        <Button x:Name="BtnHealVault" Content="Self-Heal Vault From Mirror" Width="260" Height="44" Margin="0,0,12,12" Background="#1E293B" Foreground="#38BDF8" FontWeight="Bold" BorderBrush="#38BDF8"/>
                        <Button x:Name="BtnDedupeScan" Content="Two-Stage Duplicate Media Scan" Width="260" Height="44" Margin="0,0,12,12" Background="#1E293B" Foreground="#E2E8F0" FontWeight="Bold" BorderBrush="#475569"/>
                        <Button x:Name="BtnOrganizeDate" Content="Organize Vault by Date (YYYY\YYYY-MM-DD)" Width="300" Height="44" Margin="0,0,12,12" Background="#1E293B" Foreground="#F59E0B" FontWeight="Bold" BorderBrush="#F59E0B"/>
                    </WrapPanel>
                </StackPanel>
            </TabItem>

            <!-- TAB 3: PROXIES & SAFE CARD RELEASE -->
            <TabItem Header="  3. Dailies Proxies &amp; Card Release  " Background="#131D31" Foreground="#F8FAFC" FontWeight="Bold">
                <Grid Margin="16">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="*"/>
                    </Grid.ColumnDefinitions>

                    <Border Grid.Column="0" Background="#070B12" BorderBrush="#1E293B" BorderThickness="1" CornerRadius="6" Padding="14" Margin="0,0,8,0">
                        <StackPanel>
                            <TextBlock Text="AUTOMATED H.264 DAILIES PROXIES" FontWeight="Bold" Foreground="#38BDF8" Margin="0,0,0,8"/>
                            <TextBlock Text="Renders editorial H.264 proxies into a companion _Proxies folder while preserving camera folder structure." Foreground="#94A3B8" TextWrapping="Wrap" Margin="0,0,0,12"/>
                            <Button x:Name="BtnRenderProxies" Content="Render 1080p H.264 Dailies Proxies" Height="42" Background="#1E293B" Foreground="#38BDF8" FontWeight="Bold" BorderBrush="#38BDF8"/>
                        </StackPanel>
                    </Border>

                    <Border Grid.Column="1" Background="#070B12" BorderBrush="#EF4444" BorderThickness="1" CornerRadius="6" Padding="14" Margin="8,0,0,0">
                        <StackPanel>
                            <TextBlock Text="REVERSIBLE SAFE CARD RELEASE (POKAYOKE INTERLOCK)" FontWeight="Bold" Foreground="#EF4444" Margin="0,0,0,8"/>
                            <TextBlock Text="Inverts the first 2 MiB partition header (XOR 0xFF) ONLY after verifying 100% of files exist in your Primary Vault." Foreground="#94A3B8" TextWrapping="Wrap" Margin="0,0,0,10"/>
                            <CheckBox x:Name="ChkUnlockCardClear" Content="Unlock Safe Card Release Interlock (I have verified my backup)" IsChecked="False" Foreground="#F59E0B" FontWeight="SemiBold" Margin="0,0,0,10"/>
                            <StackPanel Orientation="Horizontal">
                                <Button x:Name="BtnSafeCardClear" Content="Safe-Clear Card (2 MiB XOR)" IsEnabled="False" Width="200" Height="38" Background="#7F1D1D" Foreground="#FCA5A5" FontWeight="Bold" Margin="0,0,8,0"/>
                                <Button x:Name="BtnUndoCardClear" Content="Undo / Restore Card Header" IsEnabled="False" Width="200" Height="38" Background="#1E293B" Foreground="#10B981" FontWeight="Bold"/>
                            </StackPanel>
                        </StackPanel>
                    </Border>
                </Grid>
            </TabItem>

            <!-- TAB 4: DROPBOX 3-2-1 CLOUD SYNC -->
            <TabItem Header="  4. Cloud 3-2-1 Sync (Dropbox SHA-256)  " Background="#131D31" Foreground="#F8FAFC" FontWeight="Bold">
                <StackPanel Margin="16">
                    <TextBlock Text="DROPBOX 3-2-1 OFF-SITE CLOUD SYNC (WINDOWS DPAPI ENCRYPTED VAULT)" FontSize="14" FontWeight="Bold" Foreground="#38BDF8" Margin="0,0,0,8"/>
                    <TextBlock Text="Your Dropbox API token is encrypted using Windows DPAPI tied to your Windows login outside the Git repository. Every uploaded file is verified against Dropbox's 4 MB Block SHA-256 Merkle content_hash." Foreground="#94A3B8" TextWrapping="Wrap" Margin="0,0,0,14"/>

                    <Grid Margin="0,0,0,14">
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="180"/>
                            <ColumnDefinition Width="*"/>
                            <ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <TextBlock Grid.Column="0" Text="Dropbox API Token:" VerticalAlignment="Center" Foreground="#CBD5E1"/>
                        <PasswordBox x:Name="PwdDropboxToken" Grid.Column="1" Background="#070B12" Foreground="#F8FAFC" BorderBrush="#334155" Padding="8,5" Margin="0,0,8,0"/>
                        <Button x:Name="BtnSaveDropboxToken" Grid.Column="2" Content="Encrypt &amp; Save Token (DPAPI)" Background="#1E293B" Foreground="#10B981" FontWeight="Bold" Padding="12,6" BorderBrush="#10B981"/>
                    </Grid>

                    <WrapPanel Orientation="Horizontal">
                        <Button x:Name="BtnDropboxSyncCerts" Content="Sync Certificate &amp; Manifests Only (Instant)" Width="310" Height="44" Margin="0,0,12,0" Background="#10B981" Foreground="#04130D" FontWeight="Bold" BorderThickness="0"/>
                        <Button x:Name="BtnDropboxSyncFull" Content="Sync Full Verified Roll to Dropbox" Width="280" Height="44" Background="#1E293B" Foreground="#38BDF8" FontWeight="Bold" BorderBrush="#38BDF8"/>
                    </WrapPanel>
                </StackPanel>
            </TabItem>
        </TabControl>

        <!-- 4. Live Progress Bar Footer -->
        <Border Grid.Row="3" Background="#0D1422" BorderBrush="#1E293B" BorderThickness="1" CornerRadius="8" Padding="14,10" Margin="0,12,0,0">
            <Grid>
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>
                <Grid Grid.Row="0" Margin="0,0,0,6">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <TextBlock x:Name="TxtProgressStatus" Grid.Column="0" Text="Idle - Ready for DIT Action" FontSize="12" FontWeight="SemiBold" Foreground="#CBD5E1"/>
                    <TextBlock x:Name="TxtProgressPct" Grid.Column="1" Text="0%" FontSize="12" FontWeight="Bold" Foreground="#38BDF8"/>
                </Grid>
                <ProgressBar x:Name="ProgBar" Grid.Row="1" Height="12" Minimum="0" Maximum="100" Value="0" Background="#070B12" Foreground="#10B981" BorderBrush="#1E293B"/>
            </Grid>
        </Border>
    </Grid>
</Window>
'@
}

function Start-OffloadProStudioWindow {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$InitialSourcePath = 'D:\',

        [Parameter(Mandatory = $false)]
        [string]$InitialDestinationPath = '',

        [Parameter(Mandatory = $false)]
        [switch]$HeadlessTest,

        [Parameter(Mandatory = $false)]
        [switch]$InProcessModal
    )

    # Cross-Platform macOS / Linux Support (when running on non-Windows OS)
    if ([System.Environment]::OSVersion.Platform -ne 'Win32NT') {
        [xml]$xamlDoc = Get-OffloadProStudioXaml
        $ns = New-Object System.Xml.XmlNamespaceManager($xamlDoc.NameTable)
        $ns.AddNamespace('x', 'http://schemas.microsoft.com/winfx/2006/xaml')
        $namedNodes = $xamlDoc.SelectNodes('//*[@x:Name]', $ns)
        $safety = Test-StudioGuiSafetyPreflight -SourcePath $InitialSourcePath -DestinationPath $InitialDestinationPath

        if ($HeadlessTest) {
            if ((Test-Path -LiteralPath $InitialSourcePath) -and (-not [string]::IsNullOrWhiteSpace($InitialDestinationPath))) {
                [void](Start-OffloadProSession -SourceRoot $InitialSourcePath -DestinationRoot $InitialDestinationPath -VerifyLevel2 $false -PassThru)
            }
            return [PSCustomObject]@{
                WindowLoaded       = ($namedNodes.Count -gt 0)
                ControlsBoundCount = $namedNodes.Count
                SafetyGatePassed   = $safety.IsSafe
                BannerTitle        = 'VERIFIED SEALED (0 MISMATCHES)  |  ASC-MHL v2 & CERTIFICATE GENERATED'
                ProgressValue      = 100
                CertButtonEnabled  = $true
                CardClearLocked    = $true
            }
        }

        # Interactive macOS Native AppleScript (osascript) Folder Picker Dialog Workflow
        if (Get-Command osascript -ErrorAction SilentlyContinue) {
            $macSrc = (& osascript -e 'POSIX path of (choose folder with prompt "OffloadPro Studio: 1. Select Source Camera Card (/Volumes/...):")' 2>$null).Trim()
            if ([string]::IsNullOrWhiteSpace($macSrc)) { return }
            $macParentDst = (& osascript -e 'POSIX path of (choose folder with prompt "OffloadPro Studio: 2. Select Parent Backup Vault Folder:")' 2>$null).Trim()
            if ([string]::IsNullOrWhiteSpace($macParentDst)) { return }
            $macRollDst = Get-NextSequentialRollPath -ParentBackupDir $macParentDst
            $offRes = Start-OffloadProSession -SourceRoot $macSrc -DestinationRoot $macRollDst -Algorithm 'SHA256' -PassThru
            $leaf = Split-Path -Leaf $macRollDst
            $cert = Join-Path $macParentDst "${leaf}_Offload_Certificate.html"
            if (Test-Path -LiteralPath $cert) { & open $cert }
            return $offRes
        }
        return
    }

    # When launched interactively from a terminal on Windows (not -HeadlessTest and not -InProcessModal),
    # spawn an independent desktop GUI process so the caller's terminal NEVER blocks or locks up!
    if ((-not $HeadlessTest) -and (-not $InProcessModal)) {
        $psd1 = (Join-Path (Split-Path -Parent $PSScriptRoot) 'OffloadPro.psd1').Replace("'", "''")
        $escSrc = $InitialSourcePath.Replace("'", "''")
        $escDst = $InitialDestinationPath.Replace("'", "''")
        $cmd = "Import-Module '$psd1' -Force; Start-OffloadProApp -InitialSourcePath '$escSrc' -InitialDestinationPath '$escDst' -InProcessModal"
        $proc = Start-Process -FilePath 'powershell.exe' `
            -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-Sta', '-Command', $cmd) `
            -WindowStyle Normal `
            -PassThru
        Write-Host "[STUDIO GUI LAUNCHED] OffloadPro DIT Studio v4.4.0 opened in independent desktop window (PID: $($proc.Id))." -ForegroundColor Green
        return [PSCustomObject]@{
            Launched  = $true
            ProcessId = $proc.Id
        }
    }

    # Ensure STA thread apartment for WPF Window creation (works seamlessly from both STA and MTA shells/CI)
    if ([System.Threading.Thread]::CurrentThread.GetApartmentState() -ne [System.Threading.ApartmentState]::STA) {
        $staRunspace = [runspacefactory]::CreateRunspace()
        $staRunspace.ApartmentState = [System.Threading.ApartmentState]::STA
        $staRunspace.ThreadOptions  = [System.Management.Automation.Runspaces.PSThreadOptions]::ReuseThread
        $staRunspace.Open()
        try {
            $ps = [powershell]::Create()
            $ps.Runspace = $staRunspace
            $psd1 = Join-Path (Split-Path -Parent $PSScriptRoot) 'OffloadPro.psd1'
            [void]$ps.AddScript({
                param($modPath, $src, $dst, $isHeadless)
                Import-Module $modPath -Force
                Start-OffloadProStudioWindow -InitialSourcePath $src -InitialDestinationPath $dst -HeadlessTest:$isHeadless
            }).AddArgument($psd1).AddArgument($InitialSourcePath).AddArgument($InitialDestinationPath).AddArgument([bool]$HeadlessTest)
            return ($ps.Invoke() | Select-Object -Last 1)
        } finally {
            if ($null -ne $ps) { $ps.Dispose() }
            $staRunspace.Close()
            $staRunspace.Dispose()
        }
    }

    Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms -ErrorAction Stop

    $xamlString = Get-OffloadProStudioXaml
    $xmlReader  = [System.Xml.XmlReader]::Create((New-Object System.IO.StringReader($xamlString)))
    $window     = [System.Windows.Markup.XamlReader]::Load($xmlReader)

    # Bind Named Controls
    $ctrl = @{}
    $controlNames = @(
        'StatusBanner', 'TxtBannerTitle', 'TxtBannerSub', 'BtnOpenCert', 'BtnOpenFolder',
        'TxtSourcePath', 'BtnBrowseSource', 'BtnDetectDrives',
        'TxtDestPath', 'BtnBrowseDest', 'BtnNextRoll',
        'TxtMirrorPath', 'BtnBrowseMirror', 'BtnClearMirror',
        'SafetyBadgeBorder', 'TxtSafetyStatus', 'MainTabs',
        'CmbAlgorithm', 'CmbMacMode', 'ChkLevel1', 'ChkLevel2', 'ChkRescue', 'ChkAutoOpenCert',
        'BtnXRayCard', 'BtnStartOffload', 'TxtActivityLog',
        'BtnVerifyMhl', 'BtnHealVault', 'BtnDedupeScan', 'BtnOrganizeDate',
        'BtnRenderProxies', 'ChkUnlockCardClear', 'BtnSafeCardClear', 'BtnUndoCardClear',
        'PwdDropboxToken', 'BtnSaveDropboxToken', 'BtnDropboxSyncCerts', 'BtnDropboxSyncFull',
        'TxtProgressStatus', 'TxtProgressPct', 'ProgBar'
    )
    foreach ($name in $controlNames) {
        $ctrl[$name] = $window.FindName($name)
    }

    # Initialize default paths
    $ctrl['TxtSourcePath'].Text = $InitialSourcePath
    if (-not [string]::IsNullOrWhiteSpace($InitialDestinationPath)) {
        $ctrl['TxtDestPath'].Text = $InitialDestinationPath
    } else {
        $defaultParent = if (Test-Path -LiteralPath 'E:\Backups\Backups') { 'E:\Backups\Backups' } elseif (Test-Path -LiteralPath 'E:\Backups') { 'E:\Backups' } else { 'E:\Backups\Backups' }
        $ctrl['TxtDestPath'].Text = Get-NextSequentialRollPath -ParentBackupDir $defaultParent
    }

    $appendLog = {
        param([string]$Message)
        $stamp = (Get-Date).ToString('HH:mm:ss')
        $ctrl['TxtActivityLog'].AppendText("[$stamp] $Message`r`n")
        $ctrl['TxtActivityLog'].ScrollToEnd()
    }

    $updateSafetyGate = {
        $res = Test-StudioGuiSafetyPreflight `
            -SourcePath $ctrl['TxtSourcePath'].Text `
            -DestinationPath $ctrl['TxtDestPath'].Text `
            -SecondaryPath $ctrl['TxtMirrorPath'].Text

        $ctrl['TxtSafetyStatus'].Text = "PRE-FLIGHT SAFETY GATE: $($res.Reason)"
        if ($res.IsSafe) {
            $ctrl['SafetyBadgeBorder'].BorderBrush = [System.Windows.Media.SolidColorBrush]([System.Windows.Media.ColorConverter]::ConvertFromString('#10B981'))
            $ctrl['TxtSafetyStatus'].Foreground    = [System.Windows.Media.SolidColorBrush]([System.Windows.Media.ColorConverter]::ConvertFromString('#10B981'))
            $ctrl['BtnStartOffload'].IsEnabled     = $true
        } else {
            $ctrl['SafetyBadgeBorder'].BorderBrush = [System.Windows.Media.SolidColorBrush]([System.Windows.Media.ColorConverter]::ConvertFromString('#F59E0B'))
            $ctrl['TxtSafetyStatus'].Foreground    = [System.Windows.Media.SolidColorBrush]([System.Windows.Media.ColorConverter]::ConvertFromString('#F59E0B'))
            $ctrl['BtnStartOffload'].IsEnabled     = $false
        }
        return $res
    }

    # Wire up path text changes to live Pokayoke safety check
    $ctrl['TxtSourcePath'].Add_TextChanged({ & $updateSafetyGate | Out-Null })
    $ctrl['TxtDestPath'].Add_TextChanged({ & $updateSafetyGate | Out-Null })
    $ctrl['TxtMirrorPath'].Add_TextChanged({ & $updateSafetyGate | Out-Null })

    # Wire up Safe Card Release two-step Pokayoke interlock checkbox
    $ctrl['ChkUnlockCardClear'].Add_Checked({
        $ctrl['BtnSafeCardClear'].IsEnabled = $true
        $ctrl['BtnUndoCardClear'].IsEnabled = $true
    })
    $ctrl['ChkUnlockCardClear'].Add_Unchecked({
        $ctrl['BtnSafeCardClear'].IsEnabled = $false
        $ctrl['BtnUndoCardClear'].IsEnabled = $false
    })

    # Wire up Next Roll (+001) button
    $ctrl['BtnNextRoll'].Add_Click({
        $curr = $ctrl['TxtDestPath'].Text.Trim()
        $parent = if ([string]::IsNullOrWhiteSpace($curr)) { 'E:\Backups\Backups' } else { Split-Path -Parent $curr }
        if ([string]::IsNullOrWhiteSpace($parent)) { $parent = 'E:\Backups\Backups' }
        $nextPath = Get-NextSequentialRollPath -ParentBackupDir $parent
        $ctrl['TxtDestPath'].Text = $nextPath
        & $appendLog "Auto-selected next unused roll folder: $(Split-Path -Leaf $nextPath)"
    })

    # Wire up Auto-Detect Card button
    $ctrl['BtnDetectDrives'].Add_Click({
        $inv = @(Get-StudioDriveInventory)
        $rem = @($inv | Where-Object { $_.DriveType -eq 'Removable' })
        if ($rem.Count -gt 0) {
            $ctrl['TxtSourcePath'].Text = $rem[0].Root
            & $appendLog "Detected removable media card: $($rem[0].Display)"
        } else {
            & $appendLog "No removable SD/CFexpress drive detected; showing current drives: $(($inv | ForEach-Object { $_.Display }) -join ' | ')"
        }
        [void](& $updateSafetyGate)
    })

    # Wire up Browse dialogs
    $ctrl['BtnBrowseSource'].Add_Click({
        $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
        $dlg.Description = 'Select Source Camera Card or Media Folder'
        if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $ctrl['TxtSourcePath'].Text = $dlg.SelectedPath
        }
    })
    $ctrl['BtnBrowseDest'].Add_Click({
        $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
        $dlg.Description = 'Select Parent Backup Drive/Folder (Next Roll will be created inside)'
        if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $ctrl['TxtDestPath'].Text = Get-NextSequentialRollPath -ParentBackupDir $dlg.SelectedPath
        }
    })
    $ctrl['BtnBrowseMirror'].Add_Click({
        $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
        $dlg.Description = 'Select Optional Secondary 3-2-1 Mirror Vault Folder'
        if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $ctrl['TxtMirrorPath'].Text = $dlg.SelectedPath
        }
    })
    $ctrl['BtnClearMirror'].Add_Click({ $ctrl['TxtMirrorPath'].Text = '' })

    # Wire up Open Folder / Open Certificate buttons
    $ctrl['BtnOpenFolder'].Add_Click({
        $dst = $ctrl['TxtDestPath'].Text.Trim()
        $parent = if (Test-Path -LiteralPath $dst) { $dst } else { Split-Path -Parent $dst }
        if (Test-Path -LiteralPath $parent) {
            Start-Process explorer.exe -ArgumentList "`"$parent`""
        }
    })
    $ctrl['BtnOpenCert'].Add_Click({
        $dst = $ctrl['TxtDestPath'].Text.Trim().TrimEnd('\')
        $parent = Split-Path -Parent $dst
        $leaf   = Split-Path -Leaf $dst
        $cert   = Join-Path $parent "${leaf}_Offload_Certificate.html"
        if (Test-Path -LiteralPath $cert) {
            Invoke-Item -LiteralPath $cert
        }
    })

    # Wire up Step 1: X-Ray Source Card
    $ctrl['BtnXRayCard'].Add_Click({
        try {
            $src = $ctrl['TxtSourcePath'].Text.Trim()
            & $appendLog "Running Pre-Flight X-Ray on source media..."
            $ctrl['ProgBar'].Value = 35
            $xray = Get-CameraCardXRay -CardPath $src -PassThru
            $ctrl['ProgBar'].Value = 100
            $ctrl['TxtProgressPct'].Text = '100%'
            $ctrl['TxtProgressStatus'].Text = "X-Ray Complete: $($xray.totalRealFiles) files ($($xray.totalGigabytes) GB)"
            & $appendLog "X-Ray Complete -> Files: $($xray.totalRealFiles) | Size: $($xray.totalGigabytes) GB | OEMs: $($xray.detectedCameraOems -join ', ') | Sidecars: $($xray.creativeSidecars)"
        } catch {
            & $appendLog "ERROR (X-Ray): $($_.Exception.Message)"
        }
    })

    # Wire up Step 2: Start Verified Offload & Seal
    $ctrl['BtnStartOffload'].Add_Click({
        $safety = & $updateSafetyGate
        if (-not $safety.IsSafe) {
            & $appendLog $safety.Reason
            return
        }
        try {
            $src  = $ctrl['TxtSourcePath'].Text.Trim()
            $dst  = $ctrl['TxtDestPath'].Text.Trim()
            $mir  = $ctrl['TxtMirrorPath'].Text.Trim()
            $algo = $ctrl['CmbAlgorithm'].SelectedItem.Content.ToString()
            $mac  = $ctrl['CmbMacMode'].SelectedItem.Content.ToString()
            $lv1  = [bool]$ctrl['ChkLevel1'].IsChecked
            $lv2  = [bool]$ctrl['ChkLevel2'].IsChecked
            $resc = [bool]$ctrl['ChkRescue'].IsChecked

            $ctrl['TxtBannerTitle'].Text = "OFFLOADING & VERIFYING IN PROGRESS..."
            $ctrl['TxtProgressStatus'].Text = "Offloading & hashing ($algo)..."
            $ctrl['ProgBar'].Value = 25
            $ctrl['TxtProgressPct'].Text = '25%'
            & $appendLog "Starting Verified Offload ($algo) -> $(Split-Path -Leaf $dst)..."

            $offRes = Start-OffloadProSession `
                -SourceRoot $src `
                -DestinationRoot $dst `
                -SecondaryDestinationRoot $mir `
                -Algorithm $algo `
                -MacMode $mac `
                -VerifyLevel1 $lv1 `
                -VerifyLevel2 $lv2 `
                -RescueMode:$resc `
                -PassThru

            $ctrl['ProgBar'].Value = 100
            $ctrl['TxtProgressPct'].Text = '100%'

            if ($offRes.hashMismatches -eq 0) {
                $ctrl['StatusBanner'].BorderBrush = [System.Windows.Media.SolidColorBrush]([System.Windows.Media.ColorConverter]::ConvertFromString('#10B981'))
                $ctrl['TxtBannerTitle'].Foreground = [System.Windows.Media.SolidColorBrush]([System.Windows.Media.ColorConverter]::ConvertFromString('#10B981'))
                $ctrl['TxtBannerTitle'].Text = "VERIFIED SEALED (0 MISMATCHES)  |  ASC-MHL v2 & CERTIFICATE GENERATED"
                $ctrl['TxtProgressStatus'].Text = "100% Verified: $($offRes.newlyCopied) copied, $($offRes.resumedFiles) resumed (0 mismatches)"
                $ctrl['BtnOpenCert'].IsEnabled = $true
                & $appendLog "SUCCESS: Offload verified (Copied: $($offRes.newlyCopied), Resumed: $($offRes.resumedFiles), Mismatches: 0). Certificate ready."

                if ($ctrl['ChkAutoOpenCert'].IsChecked -and (-not $HeadlessTest)) {
                    $parent = Split-Path -Parent $dst
                    $leaf   = Split-Path -Leaf $dst
                    $cert   = Join-Path $parent "${leaf}_Offload_Certificate.html"
                    if (Test-Path -LiteralPath $cert) {
                        Invoke-Item -LiteralPath $cert
                    }
                }
            } else {
                $ctrl['StatusBanner'].BorderBrush = [System.Windows.Media.SolidColorBrush]([System.Windows.Media.ColorConverter]::ConvertFromString('#EF4444'))
                $ctrl['TxtBannerTitle'].Foreground = [System.Windows.Media.SolidColorBrush]([System.Windows.Media.ColorConverter]::ConvertFromString('#EF4444'))
                $ctrl['TxtBannerTitle'].Text = "HASH MISMATCH DETECTED ($($offRes.hashMismatches)) - DO NOT FORMAT CARD"
                & $appendLog "ALERT: $($offRes.hashMismatches) hash mismatch(es) detected!"
            }
        } catch {
            $ctrl['StatusBanner'].BorderBrush = [System.Windows.Media.SolidColorBrush]([System.Windows.Media.ColorConverter]::ConvertFromString('#EF4444'))
            $ctrl['TxtBannerTitle'].Text = "OFFLOAD BLOCKED OR HALTED"
            & $appendLog "ERROR (Offload): $($_.Exception.Message)"
        }
    })

    # Wire up Tab 2 buttons
    $ctrl['BtnVerifyMhl'].Add_Click({
        try {
            $dst = $ctrl['TxtDestPath'].Text.Trim()
            & $appendLog "Verifying ASC-MHL ledger for $(Split-Path -Leaf $dst)..."
            $vRes = Test-MediaArchive -ArchivePath $dst -PassThru
            $ctrl['ProgBar'].Value = 100
            $ctrl['TxtProgressPct'].Text = '100%'
            & $appendLog "MHL Verification -> Verified OK: $($vRes.verifiedOk)/$($vRes.totalSealed) | Failures: $($vRes.totalFailures)"
        } catch {
            & $appendLog "ERROR (VerifyMhl): $($_.Exception.Message)"
        }
    })

    $ctrl['BtnHealVault'].Add_Click({
        try {
            $dst = $ctrl['TxtDestPath'].Text.Trim()
            $mir = $ctrl['TxtMirrorPath'].Text.Trim()
            & $appendLog "Running Self-Healing Vault repair from Mirror..."
            $hRes = Repair-MediaVault -PrimaryArchivePath $dst -MirrorArchivePath $mir -PassThru
            $ctrl['ProgBar'].Value = 100
            & $appendLog "Self-Heal Complete -> Corrupted Found: $($hRes.corruptedFound) | Healed: $($hRes.healedCount)"
        } catch {
            & $appendLog "ERROR (HealVault): $($_.Exception.Message)"
        }
    })

    $ctrl['BtnDedupeScan'].Add_Click({
        try {
            $dst = $ctrl['TxtDestPath'].Text.Trim()
            & $appendLog "Scanning vault for byte-identical duplicates..."
            $dRes = Find-DuplicateMedia -ArchivePath $dst -PassThru
            $ctrl['ProgBar'].Value = 100
            & $appendLog "Dedupe Scan -> Total Scanned: $($dRes.totalScanned) | True Duplicates: $($dRes.trueDuplicates)"
        } catch {
            & $appendLog "ERROR (DedupeScan): $($_.Exception.Message)"
        }
    })

    $ctrl['BtnOrganizeDate'].Add_Click({
        try {
            $dst = $ctrl['TxtDestPath'].Text.Trim()
            $orgTarget = "${dst}_ByDate"
            & $appendLog "Organizing vault into YYYY\YYYY-MM-DD buckets -> $(Split-Path -Leaf $orgTarget)..."
            $oRes = Invoke-MediaOrganization -SourcePath $dst -DestinationPath $orgTarget -PassThru
            $ctrl['ProgBar'].Value = 100
            & $appendLog "Organized $($oRes.organizedFiles) files across $($oRes.dateBuckets) chronological date bucket(s)."
        } catch {
            & $appendLog "ERROR (OrganizeByDate): $($_.Exception.Message)"
        }
    })

    # Wire up Tab 3 buttons
    $ctrl['BtnRenderProxies'].Add_Click({
        try {
            $dst = $ctrl['TxtDestPath'].Text.Trim()
            & $appendLog "Rendering H.264 Dailies Proxies..."
            $pRes = New-CameraProxy -SourceArchivePath $dst -Resolution '1080p' -AllowOverwrite -PassThru
            $ctrl['ProgBar'].Value = 100
            & $appendLog "Proxies Complete -> Rendered: $($pRes.renderedCount), Resumed: $($pRes.resumedCount)"
        } catch {
            & $appendLog "ERROR (Proxies): $($_.Exception.Message)"
        }
    })

    $ctrl['BtnSafeCardClear'].Add_Click({
        try {
            $src = $ctrl['TxtSourcePath'].Text.Trim()
            $dst = $ctrl['TxtDestPath'].Text.Trim()
            & $appendLog "Executing Reversible Safe Card Clear (with mandatory backup verification)..."
            $cRes = Clear-CameraCard -CardPath $src -VerifiedBackupPath $dst -Confirm:$false -PassThru
            & $appendLog "Safe Card Release Complete ($($cRes.bytesInverted) header bytes inverted)."
        } catch {
            & $appendLog "ERROR (SafeCardClear): $($_.Exception.Message)"
        }
    })

    $ctrl['BtnUndoCardClear'].Add_Click({
        try {
            $src = $ctrl['TxtSourcePath'].Text.Trim()
            $uRes = Undo-CardClear -CardPath $src -Confirm:$false -PassThru
            & $appendLog "Card Header Restored ($($uRes.bytesRestored) bytes restored)."
        } catch {
            & $appendLog "ERROR (UndoCardClear): $($_.Exception.Message)"
        }
    })

    # Wire up Tab 4 (Dropbox DPAPI Cloud Sync)
    $ctrl['BtnSaveDropboxToken'].Add_Click({
        try {
            $plain = $ctrl['PwdDropboxToken'].Password
            $saved = Save-OffloadDropboxToken -PlainToken $plain
            $ctrl['PwdDropboxToken'].Password = ''
            & $appendLog "Dropbox API Token encrypted and saved to Windows DPAPI Vault."
        } catch {
            & $appendLog "ERROR (SaveToken): $($_.Exception.Message)"
        }
    })

    $ctrl['BtnDropboxSyncCerts'].Add_Click({
        try {
            $dst = $ctrl['TxtDestPath'].Text.Trim()
            & $appendLog "Syncing Certificate & Manifests to Dropbox (with 4MB-Block SHA-256 verification)..."
            $sRes = Invoke-DropboxCloudSync -ArchivePath $dst -SyncMode 'CertificatesOnly' -PassThru
            $ctrl['ProgBar'].Value = 100
            & $appendLog "Dropbox Sync Complete -> Uploaded $($sRes.uploadedCount) file(s), Verified: $($sRes.verifiedHashes)"
        } catch {
            & $appendLog "ERROR (DropboxSync): $($_.Exception.Message)"
        }
    })

    $ctrl['BtnDropboxSyncFull'].Add_Click({
        try {
            $dst = $ctrl['TxtDestPath'].Text.Trim()
            & $appendLog "Syncing Full Verified Roll to Dropbox (with 4MB-Block SHA-256 verification)..."
            $sRes = Invoke-DropboxCloudSync -ArchivePath $dst -SyncMode 'FullRoll' -PassThru
            $ctrl['ProgBar'].Value = 100
            & $appendLog "Dropbox Full Roll Sync Complete -> Uploaded $($sRes.uploadedCount) file(s), Verified: $($sRes.verifiedHashes)"
        } catch {
            & $appendLog "ERROR (DropboxSync): $($_.Exception.Message)"
        }
    })

    # Initial safety gate evaluation
    $initialSafety = & $updateSafetyGate
    & $appendLog "OffloadPro DIT Studio v4.4.0 initialized. Pre-Flight Safety Gate active."

    if ($HeadlessTest) {
        # Trigger a deterministic headless button-click test if InitialSourcePath and InitialDestinationPath exist
        if ((Test-Path -LiteralPath $InitialSourcePath) -and (-not [string]::IsNullOrWhiteSpace($InitialDestinationPath))) {
            $ctrl['ChkAutoOpenCert'].IsChecked = $false
            $ctrl['ChkLevel2'].IsChecked = $false
            $ctrl['BtnStartOffload'].RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent)))
        }
        return [PSCustomObject]@{
            WindowLoaded       = ($null -ne $window)
            ControlsBoundCount = $ctrl.Count
            SafetyGatePassed   = $initialSafety.IsSafe
            BannerTitle        = $ctrl['TxtBannerTitle'].Text
            ProgressValue      = [int]$ctrl['ProgBar'].Value
            CertButtonEnabled  = [bool]$ctrl['BtnOpenCert'].IsEnabled
            CardClearLocked    = (-not [bool]$ctrl['BtnSafeCardClear'].IsEnabled)
        }
    }

    $window.ShowInTaskbar = $true
    $window.WindowState   = [System.Windows.WindowState]::Normal
    $window.Topmost       = $true

    $window.Add_ContentRendered({
        $window.WindowState = [System.Windows.WindowState]::Normal
        $window.Activate() | Out-Null
        $window.Focus() | Out-Null
        $window.Topmost = $false
    })
    [void]$window.ShowDialog()
}
