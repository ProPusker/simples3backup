########################################################################
# AUTHOR:Pusker
#
# CHANGELOG:
# 
#   09/16/2023  - first version
#   11/15/2023 - improved version with modularization, error handling, and logging
########################################################################

param (
    [string]$ConfigFile = "$PSScriptRoot\backup.xml",
    [string]$LogPath = "$PSScriptRoot\logs"
)

# Ensure PowerShell version 5
if ($PSVersionTable.PSVersion.Major -ne 5) {
    Write-Host "PS version is $($PSVersionTable.PSVersion) - version 5 required" -ForegroundColor Red
    exit 1    
}

# Ensure script is run as administrator
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Start-Process powershell "-NoProfile -ExecutionPolicy ByPass -File `"$PSCommandPath`"" -Verb RunAs
    exit 0
}

# Function to log messages
function Log-Message {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp [$Level] $Message"
    Write-Host $logMessage -ForegroundColor $(if ($Level -eq "ERROR") { "Red" } else { "DarkGreen" })
    Add-Content -Path "$LogPath\backup.log" -Value $logMessage
}

# Function to validate configuration file
function Validate-Config {
    param (
        [string]$ConfigFile
    )
    if (-not (Test-Path -Path $ConfigFile)) {
        Log-Message "$ConfigFile not found" -Level "ERROR"
        exit 1
    }
    [xml]$config = Get-Content -Path $ConfigFile
    if (-not $config.XXX.Volume) {
        Log-Message "Invalid configuration file: No volumes defined" -Level "ERROR"
        exit 1
    }
    return $config
}

# Function to check AWS CLI installation
function Check-AwsCli {
    if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
        Log-Message "AWS CLI is not installed. Please install and configure AWS CLI." -Level "ERROR"
        exit 1
    }
}

# Function to create shadow copy
function Create-ShadowCopy {
    param (
        [string]$Volume
    )
    $linkPath = "$($Volume):\ShadowCopy"
    if (Test-Path -Path $linkPath) {
        Log-Message "Deleting the shadowcopy snapshot at $linkPath"
        (Get-Item "$linkPath").Delete()
    }

    Log-Message "Taking a snapshot of $($Volume):\\"
    $class = [WMICLASS]"root\cimv2:win32_shadowcopy"
    $result = $class.create("$($Volume):\\", "ClientAccessible")
    if ($result.ReturnValue -ne 0) {
        Log-Message "We cannot create VSS snapshot for $($Volume). Error code: $($result.ReturnValue)" -Level "ERROR"
        return $null
    }

    $shadow = Get-CimInstance -ClassName Win32_ShadowCopy | Where-Object ID -eq $result.ShadowID
    $target = "$($shadow.DeviceObject)\"
    Log-Message "Creating SymLink to shadowcopy at $linkPath"
    Invoke-Expression -Command "cmd /c mklink /d '$linkPath' '$target'"
    return $linkPath
}

# Function to sync files to S3
function Sync-ToS3 {
    param (
        [string]$LocalPath,
        [string]$RemotePath,
        [string]$Profile
    )
    if (-not (Test-Path -Path $LocalPath)) {
        Log-Message "$LocalPath not found" -Level "ERROR"
        return
    }

    if ((Get-Item -Path $LocalPath) -is [System.IO.DirectoryInfo]) {
        $command = "'$LocalPath' '$RemotePath'"
    } else {
        $command = "'$(Split-Path -Path $LocalPath -Parent)' '$RemotePath' --exclude='*' --include='$(Split-Path -Path $LocalPath -Leaf)'"
    }

    Log-Message "aws s3 sync $command --storage-class STANDARD_IA --profile $Profile"
    Invoke-Expression -Command "cmd /c aws s3 sync $command --storage-class STANDARD_IA --profile $Profile"
}

# Function to delete old backups
function Delete-OldBackups {
    param (
        [string]$Prefix,
        [int]$KeepDays,
        [string]$Profile
    )
    $dateFormat = "yyyy-MM-dd"
    $dateAgo = (Get-Date).AddDays(-$KeepDays)
    $date = Get-Date -Date $dateAgo -Format $dateFormat
    Log-Message "aws s3api list-objects --bucket XXX-backup --prefix '$Prefix' --output text --query 'Contents[?LastModified<=``$date``][].{Key: Key}' --profile $Profile"
    $filesList = Invoke-Expression -Command "cmd /c aws s3api list-objects --bucket XXX-backup --prefix '$Prefix' --output text --query 'Contents[?LastModified<=``$date``][].{Key: Key}' --profile $Profile"
    foreach ($e in $filesList) {
        Log-Message "aws s3 rm s3://XXX-backup/$e --profile $Profile"
        Invoke-Expression -Command "cmd /c aws s3 rm s3://XXX-backup/$e --profile $Profile"
    }
}

# Main script execution
trap {
    Log-Message $_ -Level "ERROR"
    Stop-Transcript -Verbose
    exit 1
}

# Initialize logging
if (-not (Test-Path -Path $LogPath)) {
    New-Item -Path $LogPath -ItemType Directory -Force -Verbose
}
Start-Transcript -OutputDirectory $LogPath -Force -Verbose

# Validate configuration file
$config = Validate-Config -ConfigFile $ConfigFile
Log-Message "Reading configuration from $ConfigFile"

# Check AWS CLI
Check-AwsCli

# Process each volume in the configuration
foreach ($evolume in $config.XXX.Volume) {
    $volume = $evolume.Drive
    $linkPath = Create-ShadowCopy -Volume $volume
    if (-not $linkPath) {
        continue
    }

    foreach ($etask in $evolume.Task) {
        $localPath = "$($linkPath)$(Split-Path -Path $etask.Path -NoQualifier)"
        $remotePath = "s3://XXX-backup/$($Env:COMPUTERNAME)/$($etask.Id)"
        Sync-ToS3 -LocalPath $localPath -RemotePath $remotePath -Profile "XXX-backup-user"
        Delete-OldBackups -Prefix "$($Env:COMPUTERNAME)/$($etask.Id)" -KeepDays $etask.KeepDays -Profile "XXX-backup-user"
    }

    Log-Message "vssadmin delete shadows /for=$($volume): /oldest /quiet"
    Invoke-Expression -Command "cmd /c vssadmin delete shadows /for=$($volume): /oldest /quiet"

    if (Test-Path -Path $linkPath) {
        (Get-Item "$linkPath").Delete()
    }
}

Stop-Transcript -Verbose
exit 0
