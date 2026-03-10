<#
.SYNOPSIS
  Downloads blobs from an Azure Storage account, optimizes image files locally,
  and uploads the optimized images back while preserving container/folder structure.

.DESCRIPTION
  Workflow:
    1. Enumerate blob containers/blobs in a storage account.
    2. Download blobs to a local folder mirroring the storage structure:
         <DownloadRoot>/<container>/<blob-path>
    3. Run the local Python image optimizer against the downloaded files.
    4. Upload optimized images back to the same storage account, preserving
       container and blob path structure.

    By default, the script uploads optimized images as new suffixed blob names,
    so the original blobs remain untouched.

    The script can also load non-secret defaults from a repo-level JSON config file
    (for example tenant ID, subscription ID, storage account name, and default containers).
    Explicit parameters always take precedence over config values.

.AUTHENTICATION
  Uses Az module + Entra-based auth via `New-AzStorageContext -UseConnectedAccount`.
  Make sure you have already run `Connect-AzAccount` and have data-plane access
  to the storage account.

.EXAMPLE
  .\Sync-BlobImages.ps1 -DownloadRoot C:\temp\richmondwebmedia-raw -OptimizedRoot C:\temp\richmondwebmedia-optimized

.EXAMPLE
  .\Sync-BlobImages.ps1 -DownloadRoot C:\temp\raw -OptimizedRoot C:\temp\optimized -Preset featured -ContainerName media

.EXAMPLE
    .\Sync-BlobImages.ps1 -DownloadRoot C:\temp\raw -OptimizedRoot C:\temp\optimized -ContainerName media -BlobPrefix blog/2025-01_my_2024_recap/tromso/

.EXAMPLE
    .\Sync-BlobImages.ps1 -DownloadRoot C:\temp\raw -OptimizedRoot C:\temp\optimized -ContainerName media -BlobName static_assets/about/2021_hackaton1.JPG

.EXAMPLE
  .\Sync-BlobImages.ps1 -DownloadRoot C:\temp\raw -OptimizedRoot C:\temp\optimized -WhatIf

.EXAMPLE
    .\Sync-BlobImages.ps1 -ConfigPath ..\..\RemoteStorage\storage-account.json -DownloadRoot C:\temp\raw -OptimizedRoot C:\temp\optimized
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [string]$DownloadRoot,

    [Parameter(Mandatory = $true)]
    [string]$OptimizedRoot,

    [Parameter()]
    [string[]]$BlobPrefix,

    [Parameter()]
    [string[]]$BlobName,

    [Parameter()]
    [ValidateSet('gallery', 'featured', 'thumbnail')]
    [string]$Preset = 'gallery',

    [Parameter()]
    [switch]$ForceDownload,

    [Parameter()]
    [switch]$ForceOptimize,

    [Parameter()]
    [switch]$ForceUpload,

    [Parameter()]
    [switch]$KeepMetadata,

    [Parameter()]
    [switch]$SkipDownload,

    [Parameter()]
    [switch]$SkipUpload
)

$ErrorActionPreference = 'Stop'

function Assert-Command {
    param(
        [Parameter(Mandatory = $true)][string]$Name
    )

    if (-not (Get-Command -Name $Name -ErrorAction SilentlyContinue)) {
        throw "Required command '$Name' was not found."
    }
}

function Ensure-Directory {
    param(
        [Parameter(Mandatory = $true)][string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Get-RelativePathSafe {
    param(
        [Parameter(Mandatory = $true)][string]$BasePath,
        [Parameter(Mandatory = $true)][string]$Path
    )

    return [System.IO.Path]::GetRelativePath($BasePath, $Path)
}

function Get-ImageContentType {
    param(
        [Parameter(Mandatory = $true)][string]$Path
    )

    switch ([System.IO.Path]::GetExtension($Path).ToLowerInvariant()) {
        '.jpg' { return 'image/jpeg' }
        '.jpeg' { return 'image/jpeg' }
        '.png' { return 'image/png' }
        '.webp' { return 'image/webp' }
        '.gif' { return 'image/gif' }
        '.bmp' { return 'image/bmp' }
        '.tif' { return 'image/tiff' }
        '.tiff' { return 'image/tiff' }
        default { return 'application/octet-stream' }
    }
}

function Write-Section {
    param([string]$Message)
    Write-Host "`n=== $Message ===" -ForegroundColor Cyan
}

function Test-BlobSelection {
    param(
        [Parameter(Mandatory = $true)][string]$BlobPath,
        [string[]]$Prefixes,
        [string[]]$Names
    )

    if ($Names -and $Names.Count -gt 0) {
        $normalizedNames = $Names | ForEach-Object { $_.TrimStart('/') }
        if ($normalizedNames -notcontains $BlobPath) {
            return $false
        }
    }

    if ($Prefixes -and $Prefixes.Count -gt 0) {
        $matchedPrefix = $false
        foreach ($prefix in $Prefixes) {
            $normalizedPrefix = $prefix.TrimStart('/')
            if ($BlobPath.StartsWith($normalizedPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
                $matchedPrefix = $true
                break
            }
        }

        if (-not $matchedPrefix) {
            return $false
        }
    }

    return $true
}

Assert-Command -Name 'Get-AzContext'
Assert-Command -Name 'New-AzStorageContext'
Assert-Command -Name 'Get-AzStorageContainer'
Assert-Command -Name 'Get-AzStorageBlob'
Assert-Command -Name 'Get-AzStorageBlobContent'
Assert-Command -Name 'Set-AzStorageBlobContent'
Assert-Command -Name python

$OptimizerScriptPath = (Join-Path $PSScriptRoot 'image_optimize.py')
$ConfigPath = (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'RemoteStorage\storage-account.json')

Write-Section "Loading storage config from '$ConfigPath'"
$storageConfig = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
$TenantId = $storageConfig.tenantId
$StorageAccountName = $storageConfig.storageAccountName
$SubscriptionId = $storageConfig.subscriptionId
$ContainerName = $storageConfig.containerName

if (-not (Test-Path -LiteralPath $OptimizerScriptPath)) {
    throw "Optimizer script not found at '$OptimizerScriptPath'."
}

if (-not $StorageAccountName) {
    throw 'StorageAccountName was not provided and no value was found in the config file.'
}

$azContext = Get-AzContext
if (-not $azContext) {
    Connect-AzAccount | Out-Null
    $azContext = Get-AzContext
}

if ($azContext.Tenant.Id -ne $TenantId -or $azContext.Subscription.Id -ne $SubscriptionId) {
    Write-Warning "Setting correct Azure context for tenant '$TenantId' and subscription '$SubscriptionId'."
    Set-AzContext -SubscriptionId $SubscriptionId -Tenant $TenantId | Out-Null
}

Ensure-Directory -Path $DownloadRoot
Ensure-Directory -Path $OptimizedRoot

Write-Section "Creating storage context"
$storageContext = New-AzStorageContext -StorageAccountName $StorageAccountName -UseConnectedAccount

Write-Section "Enumerating containers"
$container = Get-AzStorageContainer -Name $ContainerName -Context $storageContext -ErrorAction Stop

if (-not $container) {
    throw "No container named '$ContainerName' found for storage account '$StorageAccountName'."
}

$downloadedBlobCount = 0
$downloadedByteCount = 0L
$selectedLocalFiles = [System.Collections.Generic.List[string]]::new()

function Get-PresetSpec {
    param([Parameter(Mandatory = $true)][string]$Name)

    switch ($Name) {
        'gallery' { return @{ Width = 1600; Extension = '.webp' } }
        'featured' { return @{ Width = 2000; Extension = '.webp' } }
        'thumbnail' { return @{ Width = 800; Extension = '.webp' } }
        default { throw "Unsupported preset '$Name'." }
    }
}

function Get-OptimizedOutputPath {
    param(
        [Parameter(Mandatory = $true)][string]$SourceFile,
        [Parameter(Mandatory = $true)][string]$DownloadRootPath,
        [Parameter(Mandatory = $true)][string]$OptimizedRootPath,
        [Parameter(Mandatory = $true)][string]$PresetName
    )

    $presetSpec = Get-PresetSpec -Name $PresetName
    $relativePath = Get-RelativePathSafe -BasePath $DownloadRootPath -Path $SourceFile
    $relativeDir = Split-Path -Parent $relativePath
    $stem = [System.IO.Path]::GetFileNameWithoutExtension($SourceFile)
    $fileName = "{0}-{1}w{2}" -f $stem, $presetSpec.Width, $presetSpec.Extension

    if ([string]::IsNullOrEmpty($relativeDir) -or $relativeDir -eq '.') {
        return Join-Path $OptimizedRootPath $fileName
    }

    return Join-Path (Join-Path $OptimizedRootPath $relativeDir) $fileName
}

if (-not $SkipDownload) {
    Write-Section "Downloading blobs"

    Write-Host "Container: $($container.Name)"
    $blobs = Get-AzStorageBlob -Container $container.Name -Context $storageContext

    foreach ($blob in $blobs) {
        if (-not $blob.Name -or $blob.Name.EndsWith('/')) {
            continue
        }

        if (-not (Test-BlobSelection -BlobPath $blob.Name -Prefixes $BlobPrefix -Names $BlobName)) {
            continue
        }

        $targetPath = Join-Path $DownloadRoot $container.Name
        $blobRelativePath = $blob.Name -replace '/', [System.IO.Path]::DirectorySeparatorChar
        $localFile = Join-Path $targetPath $blobRelativePath
        $localDir = Split-Path -Parent $localFile
        Ensure-Directory -Path $localDir

        if ((Test-Path -LiteralPath $localFile) -and (-not $ForceDownload)) {
            Write-Host "[skip-download] $($container.Name)/$($blob.Name)"
            $selectedLocalFiles.Add($localFile)
            continue
        }

        if ($PSCmdlet.ShouldProcess("$StorageAccountName/$($container.Name)/$($blob.Name)", 'Download blob')) {
            Get-AzStorageBlobContent -Context $storageContext -Container $container.Name -Blob $blob.Name -Destination $localFile -Force | Out-Null
            $downloadedBlobCount += 1
            if ($blob.Length) {
                $downloadedByteCount += [int64]$blob.Length
            }
            Write-Host "[downloaded] $($container.Name)/$($blob.Name)"
            $selectedLocalFiles.Add($localFile)
        }
    }
}
else {
    Write-Section 'Skipping blob download step'

    $localContainerRoot = Join-Path $DownloadRoot $container.Name
    if (Test-Path -LiteralPath $localContainerRoot) {
        $existingLocalFiles = Get-ChildItem -LiteralPath $localContainerRoot -Recurse -File -ErrorAction SilentlyContinue
        foreach ($localFile in $existingLocalFiles) {
            $relativeBlobPath = Get-RelativePathSafe -BasePath $localContainerRoot -Path $localFile.FullName
            $normalizedBlobPath = $relativeBlobPath -replace '\\', '/'
            if (Test-BlobSelection -BlobPath $normalizedBlobPath -Prefixes $BlobPrefix -Names $BlobName) {
                $selectedLocalFiles.Add($localFile.FullName)
            }
        }
    }
}

Write-Host "Downloaded blobs: $downloadedBlobCount"
Write-Host "Downloaded bytes: $downloadedByteCount"

$selectedLocalFiles = $selectedLocalFiles | Sort-Object -Unique
if (-not $selectedLocalFiles -or $selectedLocalFiles.Count -eq 0) {
    throw 'No local files matched the requested blob selection.'
}

Write-Host "Selected local files: $($selectedLocalFiles.Count)"

Write-Section "Optimizing local images"
$optimizedTargetFiles = [System.Collections.Generic.List[string]]::new()

foreach ($selectedLocalFile in $selectedLocalFiles) {
    $targetOutputPath = Get-OptimizedOutputPath -SourceFile $selectedLocalFile -DownloadRootPath $DownloadRoot -OptimizedRootPath $OptimizedRoot -PresetName $Preset
    $targetOutputDir = Split-Path -Parent $targetOutputPath

    $optimizerArgs = @(
        $OptimizerScriptPath,
        $selectedLocalFile,
        $targetOutputDir,
        '--preset', $Preset
    )

    if ($ForceOptimize) {
        $optimizerArgs += '--overwrite'
    }

    if ($KeepMetadata) {
        $optimizerArgs += '--keep-metadata'
    }

    & python @optimizerArgs
    if ($LASTEXITCODE -ne 0) {
        throw "Image optimizer failed with exit code $LASTEXITCODE for '$selectedLocalFile'."
    }

    if (Test-Path -LiteralPath $targetOutputPath) {
        $optimizedTargetFiles.Add($targetOutputPath)
    }
}

$optimizedFiles = $optimizedTargetFiles | Sort-Object -Unique
if (-not $optimizedFiles -or $optimizedFiles.Count -eq 0) {
    throw 'No optimized files were produced.'
}

$uploadedBlobCount = 0

if (-not $SkipUpload) {
    Write-Section "Uploading optimized images back to storage"

    foreach ($file in $optimizedFiles) {
        $relativePath = Get-RelativePathSafe -BasePath $OptimizedRoot -Path $file
        $segments = $relativePath -split '[\\/]'
        if ($segments.Count -lt 2) {
            Write-Warning "Skipping unexpected optimized file path: $relativePath"
            continue
        }

        $containerName = $segments[0]
        $targetBlobName = ($segments[1..($segments.Count - 1)] -join '/')
        $blobTarget = "$StorageAccountName/$containerName/$targetBlobName"

        if ($PSCmdlet.ShouldProcess($blobTarget, 'Upload optimized blob')) {
            $properties = @{
                ContentType = Get-ImageContentType -Path $file
            }

            $uploadParams = @{
                Context    = $storageContext
                Container  = $containerName
                Blob       = $targetBlobName
                File       = $file
                Force      = $ForceUpload.IsPresent
                Properties = $properties
            }

            Set-AzStorageBlobContent @uploadParams | Out-Null
            $uploadedBlobCount += 1
            Write-Host "[uploaded] $containerName/$targetBlobName"
        }
    }
}
else {
    Write-Section 'Skipping blob upload step'
}

Write-Section 'Completed'
Write-Host "Optimized files found: $($optimizedFiles.Count)"
Write-Host "Uploaded blobs: $uploadedBlobCount"
