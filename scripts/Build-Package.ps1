param([string]$LuaCommand='', [string]$MoonSharpPath='')
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
& (Join-Path $PSScriptRoot 'Test.ps1') -LuaCommand $LuaCommand -MoonSharpPath $MoonSharpPath
$addon=Join-Path $root 'GrimfallReroll'
$versionLine=Get-Content -LiteralPath (Join-Path $addon 'GrimfallReroll.toc')|Where-Object {$_ -match '^## Version: '}
$version=($versionLine -replace '^## Version: ','').Trim()
if($version -notmatch '^\d+\.\d+\.\d+(-[a-z0-9.-]+)?$'){throw 'Unexpected addon version.'}
$dist=Join-Path $root 'dist'
$null=New-Item -ItemType Directory -Path $dist -Force
$zip=Join-Path $dist ('RE-Roller-'+$version+'.zip')
if(Test-Path -LiteralPath $zip){throw 'This package already exists. Use a clean checkout for a rebuild; never silently replace a published artifact.'}
$files=@(Get-ChildItem -LiteralPath $addon -Recurse -File|Sort-Object FullName)
$manifest=@(foreach($file in $files){
 [ordered]@{name=$file.FullName.Substring($addon.Length+1).Replace('\','/');sha256=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash;bytes=$file.Length}
})
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive=[IO.Compression.ZipFile]::Open($zip,[IO.Compression.ZipArchiveMode]::Create)
try {
 foreach($entry in $manifest){
  $member=$archive.CreateEntry(('GrimfallReroll/'+$entry.name),[IO.Compression.CompressionLevel]::Optimal)
  $member.LastWriteTime=[DateTimeOffset]::new(2026,10,6,0,0,0,[TimeSpan]::Zero)
  $inputStream=[IO.File]::OpenRead((Join-Path $addon $entry.name));$outputStream=$member.Open()
  try {$inputStream.CopyTo($outputStream)} finally {$inputStream.Dispose();$outputStream.Dispose()}
 }
} finally {$archive.Dispose()}
$archive=[IO.Compression.ZipFile]::OpenRead($zip)
try {
 if($archive.Entries.Count -ne $manifest.Count){throw 'ZIP member count mismatch.'}
 foreach($member in $archive.Entries){
  $expected=@($manifest|Where-Object {('GrimfallReroll/'+$_.name) -eq $member.FullName})
  if($expected.Count -ne 1){throw "Unexpected ZIP path: $($member.FullName)"}
  $stream=$member.Open();$sha=[Security.Cryptography.SHA256]::Create()
  try {$hash=([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-','')} finally {$stream.Dispose();$sha.Dispose()}
  if($hash -ne $expected[0].sha256){throw "ZIP hash mismatch: $($member.FullName)"}
 }
} finally {$archive.Dispose()}
$utf8=New-Object Text.UTF8Encoding($false)
[IO.File]::WriteAllText((Join-Path $dist 'manifest.json'),($manifest|ConvertTo-Json -Depth 5)+"`n",$utf8)
$zipHash=(Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()
[IO.File]::WriteAllText((Join-Path $dist 'SHA256SUMS.txt'),($zipHash+'  '+[IO.Path]::GetFileName($zip)+"`n"),$utf8)
Write-Output "PASS: all $($manifest.Count) ZIP members match the tested source."
Write-Output "Package: $zip"
Write-Output "SHA256: $zipHash"
