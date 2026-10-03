$ErrorActionPreference = 'Stop'
$ModelUrl = 'https://raw.githubusercontent.com/opencv/opencv/4.x/data/haarcascades/haarcascade_frontalface_default.xml'
$LicenseUrl = 'https://raw.githubusercontent.com/opencv/opencv/4.x/doc/LICENSE_BSD.txt'
$ModelOut = Join-Path $PSScriptRoot '..\haarcascade_frontalface_default.xml'
$LicenseOut = Join-Path $PSScriptRoot '..\OPENCV_LICENSE_BSD.txt'
Invoke-WebRequest -Uri $ModelUrl -OutFile $ModelOut
Invoke-WebRequest -Uri $LicenseUrl -OutFile $LicenseOut
Write-Host "Downloaded: $ModelOut"
Write-Host "Downloaded: $LicenseOut"
