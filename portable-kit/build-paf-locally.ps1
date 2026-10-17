param(
    [Parameter(Mandatory=$true)][string]$PortableZip,
    [Parameter(Mandatory=$true)][string]$PortableAppsInstallerExe
)
$ErrorActionPreference = 'Stop'
$zip = (Resolve-Path $PortableZip).Path
$installer = (Resolve-Path $PortableAppsInstallerExe).Path
$destination = Join-Path ([System.IO.Path]::GetTempPath()) ("YTSagePAF-" + [guid]::NewGuid().ToString('N'))
try {
    New-Item -ItemType Directory -Path $destination | Out-Null
    Expand-Archive -Path $zip -DestinationPath $destination
    $appDir = Join-Path $destination 'YTSagePortable'
    if (-not (Test-Path (Join-Path $appDir 'App\AppInfo\appinfo.ini'))) {
        throw 'Input ZIP is missing PortableApps.com metadata'
    }
    # Official PortableApps.com Installer GUI/CLI accepts package directory as an argument.
    & $installer $appDir
    Write-Host "Check the directory above $appDir for the generated .paf.exe file."
    Write-Host 'Keep the generated package and verify its contents before distribution.'
} finally {
    # Leave build directory intact because the installer may output there.
    Write-Host "PAF build staging directory: $destination"
}
