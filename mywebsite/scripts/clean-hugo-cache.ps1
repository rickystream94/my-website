<#
.SYNOPSIS
  Clears Hugo cache/build outputs for this repo, then optionally starts `hugo server`.

.DESCRIPTION
  When using remote images (resources.GetRemote) and/or Hugo Pipes, Hugo can reuse cached
  resources even across server runs. This script removes the common cache locations so a
  plain `hugo server` will pick up updated assets again.

  It removes:
    - ./public (optional)
    - ./resources/_gen
    - Hugo's temp cache folder(s) (commonly: %TEMP%\hugo_cache)

.PARAMETER Serve
  If set, runs `hugo server` after cleaning.

.PARAMETER NoPublic
  If set, does NOT delete the ./public directory.

.PARAMETER NoTempCache
  If set, does NOT delete Hugo's temp cache directories.

.PARAMETER NoResourcesGen
  If set, does NOT delete ./resources/_gen.

.PARAMETER Force
  Don't prompt for confirmation.

.EXAMPLE
  # Clean caches only
  .\scripts\clean-hugo-cache.ps1

.EXAMPLE
  # Clean and start the normal dev server
  .\scripts\clean-hugo-cache.ps1 -Serve
#>

[CmdletBinding(SupportsShouldProcess=$true)]
param(
  [switch]$Serve,
  [switch]$NoPublic,
  [switch]$NoTempCache,
  [switch]$NoResourcesGen,
  [switch]$Force
)

$ErrorActionPreference = 'Stop'

function Remove-DirIfExists {
  param(
    [Parameter(Mandatory=$true)][string]$Path
  )

  if (-not (Test-Path -LiteralPath $Path)) {
    Write-Host "[skip] Not found: $Path"
    return
  }

  if ($PSCmdlet.ShouldProcess($Path, 'Remove directory')) {
    Write-Host "[rm]   $Path"
    Remove-Item -LiteralPath $Path -Recurse -Force
  }
}

# Workspace root = parent of this script's directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = Resolve-Path (Join-Path $scriptDir '..')
Set-Location $root

Write-Host "Workspace: $root"

# Confirmation (unless -Force)
if (-not $Force) {
  $choices = '&Yes', '&No'
  $decision = $Host.UI.PromptForChoice(
    'Clear Hugo caches',
    "This will delete generated folders (and may force re-download of remote resources). Continue?",
    $choices,
    1
  )
  if ($decision -ne 0) {
    Write-Host 'Aborted.'
    exit 0
  }
}

if (-not $NoResourcesGen) {
  Remove-DirIfExists (Join-Path $root 'resources\\_gen')
}

if (-not $NoPublic) {
  Remove-DirIfExists (Join-Path $root 'public')
}

if (-not $NoTempCache) {
  # Hugo commonly uses %TEMP%\hugo_cache on Windows.
  # We'll try a few likely temp roots to be safe.
  $tempRoots = @()

  if ($env:TEMP) { $tempRoots += $env:TEMP }
  if ($env:TMP -and $env:TMP -ne $env:TEMP) { $tempRoots += $env:TMP }

  # Some shells expose LocalAppData\Temp explicitly; include it if different.
  if ($env:LOCALAPPDATA) {
    $localTemp = Join-Path $env:LOCALAPPDATA 'Temp'
    if ($tempRoots -notcontains $localTemp) { $tempRoots += $localTemp }
  }

  $tempRoots = $tempRoots | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -Unique

  foreach ($t in $tempRoots) {
    Remove-DirIfExists (Join-Path $t 'hugo_cache')
  }
}

Write-Host 'Done cleaning.'

if ($Serve) {
  Write-Host 'Starting: hugo server'
  hugo server
}
