param(
    [Parameter(Mandatory=$true)][string] $Version,
    [Parameter(Mandatory=$true)][string] $Repository
)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path '.').Path
$source = Join-Path $repo 'upstream'
$kit = Join-Path $repo 'portable-kit'
$staging = Join-Path $repo 'stage\YTSagePortable'
$artifacts = Join-Path $repo 'artifacts'
$dist = Join-Path $source 'dist\YTSage'
if ($Version -notmatch '^\d+\.\d+\.\d+[0-9a-zA-Z.\-]*$') { throw 'Unsafe package version' }
if ($Repository -notmatch '^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$') { throw 'Unsafe repository name' }
if (Test-Path (Join-Path $repo 'stage')) { Remove-Item (Join-Path $repo 'stage') -Recurse -Force }
New-Item -ItemType Directory -Force (Join-Path $staging 'App\YTSage') | Out-Null
New-Item -ItemType Directory -Force (Join-Path $staging 'App\AppInfo\Launcher') | Out-Null
New-Item -ItemType Directory -Force (Join-Path $staging 'Data') | Out-Null
New-Item -ItemType Directory -Force (Join-Path $staging 'Other\Source') | Out-Null
New-Item -ItemType Directory -Force $artifacts | Out-Null

$builtExe = Join-Path $dist "YTSage-v$Version.exe"
if (-not (Test-Path $builtExe)) { throw "Frozen YTSage executable missing: $builtExe" }
foreach ($name in @('ffmpeg.exe', 'ffprobe.exe')) {
    if (-not (Test-Path (Join-Path $dist $name))) { throw "Bundled $name missing" }
}
Copy-Item -Path (Join-Path $dist '*') -Destination (Join-Path $staging 'App\YTSage') -Recurse -Force
Rename-Item -Path (Join-Path $staging "App\YTSage\YTSage-v$Version.exe") -NewName 'YTSage.exe'

# Extract accurate package version for PortableApps.com Format. Preview suffix
# only belongs in DisplayVersion.
$verParts = [regex]::Match($Version, '^(\d+)\.(\d+)\.(\d+)')
$packageVersion = "$($verParts.Groups[1].Value).$($verParts.Groups[2].Value).$($verParts.Groups[3].Value).0"
$appInfo = (Get-Content (Join-Path $kit 'appinfo.ini') -Raw).Replace('__PACKAGE_VERSION__', $packageVersion).Replace('__DISPLAY_VERSION__', $Version).Replace('__PROJECT_URL__', "https://github.com/$Repository")
Set-Content -Path (Join-Path $staging 'App\AppInfo\appinfo.ini') -Value $appInfo -Encoding ascii
Copy-Item (Join-Path $kit 'YTSagePortable.ini') (Join-Path $staging 'App\AppInfo\Launcher\YTSagePortable.ini')
Copy-Item (Join-Path $source 'LICENSE') (Join-Path $staging 'Other\Source\LICENSE.txt')
Set-Content -Path (Join-Path $staging 'Data\README.txt') -Encoding ascii -Value 'YTSage settings, caches, helper binaries and history are kept under Data when launched with YTSagePortable.exe. Do not delete Data when updating.'
Set-Content -Path (Join-Path $staging 'Other\Source\buildinfo.txt') -Encoding ascii -Value "Upstream: https://github.com/oop7/YTSage`nVersion: $Version`nCommunity package repository: https://github.com/$Repository`nThe community portable launcher is not an official YTSage or PortableApps.com release."

# Create Launcher.exe using Windows .NET Framework C# compiler, available on GitHub hosted Windows runners.
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe'
if (-not (Test-Path $compiler)) { throw "Windows .NET Framework compiler not found: $compiler" }
$icon = Join-Path $source 'branding\icons\YTSage.ico'
if (-not (Test-Path $icon)) { throw "Upstream icon missing: $icon" }
Copy-Item $icon (Join-Path $staging 'App\AppInfo\appicon.ico')
$launcherExe = Join-Path $staging 'YTSagePortable.exe'
& $compiler /nologo /target:winexe "/out:$launcherExe" "/win32icon:$icon" /reference:System.Windows.Forms.dll (Join-Path $kit 'YTSagePortable.cs')
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $launcherExe)) { throw 'Portable launcher compilation failed' }

# PortableApps.com expects 16px and 32px icons as well.
Add-Type -AssemblyName System.Drawing
$img = [System.Drawing.Image]::FromFile((Join-Path $source 'ytsage\assets\Icon\icon.png'))
try {
    foreach ($size in @(16,32,128)) {
        $bitmap = [System.Drawing.Bitmap]::new($img, [int]$size, [int]$size)
        try {
            $bitmap.Save((Join-Path $staging "App\AppInfo\appicon_$size.png"), [System.Drawing.Imaging.ImageFormat]::Png)
        } finally { $bitmap.Dispose() }
    }
} finally { $img.Dispose() }

$zipPath = Join-Path $artifacts "YTSage-v$Version-TRUE-Portable.zip"
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path $staging -DestinationPath $zipPath -CompressionLevel Optimal
if (-not (Test-Path $zipPath)) { throw 'ZIP packaging failed' }
Write-Host "Portable package ready: $zipPath"
