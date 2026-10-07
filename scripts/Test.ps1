param([string]$LuaCommand='', [string]$MoonSharpPath='')
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
$addon=Join-Path $root 'GrimfallReroll'
$versionLine=Get-Content -LiteralPath (Join-Path $addon 'GrimfallReroll.toc')|Where-Object {$_ -match '^## Version: '}
$version=($versionLine -replace '^## Version: ','').Trim()
if($version -notmatch '^\d+\.\d+\.\d+(-[a-z0-9.-]+)?$'){throw 'Unexpected addon version.'}
$baseline=Get-Content -LiteralPath (Join-Path $root ('tests/fixtures/release-'+$version+'.json')) -Raw|ConvertFrom-Json
$extra=@('LICENSE.txt','THIRD_PARTY_NOTICES.txt')
$allowed=@($baseline|ForEach-Object {$_.name})
$allowed+=@($extra|Where-Object {$_ -notin $allowed})
$files=@(Get-ChildItem -LiteralPath $addon -File -Recurse)
if($files.Count -ne $allowed.Count){throw "Expected $($allowed.Count) addon files; found $($files.Count)."}
foreach($file in $files){
 $relative=$file.FullName.Substring($addon.Length+1).Replace('\','/')
 if($relative -notin $allowed){throw "Unexpected addon member: $relative"}
}
foreach($entry in $baseline){
 $path=Join-Path $addon $entry.name
 if(!(Test-Path -LiteralPath $path)){throw "Missing baseline member: $($entry.name)"}
 if((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $entry.sha256){throw "Runtime baseline changed: $($entry.name). Review and update the release baseline deliberately."}
}
Write-Output "PASS: all $($baseline.Count) runtime/package files match the reviewed $version baseline."
if((Get-FileHash -LiteralPath (Join-Path $root 'LICENSE')).Hash -ne (Get-FileHash -LiteralPath (Join-Path $addon 'LICENSE.txt')).Hash){throw 'Repository and packaged MIT licenses differ.'}
foreach($line in Get-Content -LiteralPath (Join-Path $addon 'GrimfallReroll.toc')){
 if($line.Trim() -and !$line.StartsWith('#') -and !(Test-Path -LiteralPath (Join-Path $addon $line.Trim()))){throw "Missing TOC reference: $line"}
}
foreach($file in Get-ChildItem -LiteralPath (Join-Path $addon 'Art') -Filter '*.tga'){
 $bytes=[IO.File]::ReadAllBytes($file.FullName)
 if($bytes.Length -lt 18){throw "Invalid TGA header: $($file.Name)"}
 $w=[int]$bytes[12]+256*[int]$bytes[13];$h=[int]$bytes[14]+256*[int]$bytes[15]
 if($bytes[2] -ne 2 -or $bytes[16] -ne 32 -or $bytes[17] -ne 8){throw "Invalid TGA format: $($file.Name)"}
 if($w -notin 32,64,128,256,512,1024 -or $h -notin 32,64,128,256,512,1024 -or $bytes.Length -ne (18+$w*$h*4)){throw "Invalid texture dimensions: $($file.Name)"}
}
foreach($name in @('PT_Sans-Web-Regular.ttf','PT_Serif-Web-Regular.ttf','PT_Serif-Web-Bold.ttf')){
 $bytes=[IO.File]::ReadAllBytes((Join-Path $addon ('Fonts/'+$name)))
 if($bytes.Length -lt 50000 -or $bytes[0] -ne 0 -or $bytes[1] -ne 1 -or $bytes[2] -ne 0 -or $bytes[3] -ne 0){throw "Invalid font: $name"}
}
foreach($name in @('ptsans-OFL.txt','ptserif-OFL.txt')){
 $notice=Get-Content -LiteralPath (Join-Path $addon ('Fonts/'+$name)) -Raw
 if($notice -notmatch 'SIL OPEN FONT LICENSE Version 1.1' -or $notice -notmatch 'ParaType'){throw "Missing font license: $name"}
}
Write-Output 'PASS: TOC, native texture formats, bundled fonts, and license notices.'

Push-Location $root
try {
 if($LuaCommand){
  & $LuaCommand 'tests/run.lua'
  if($LASTEXITCODE -ne 0){throw 'Lua offline tests failed.'}
 } else {
  if(!$MoonSharpPath){throw 'Provide -LuaCommand lua5.1 or -MoonSharpPath with an installed MoonSharp.Interpreter.dll. No tools are silently downloaded.'}
  Add-Type -Path (Resolve-Path -LiteralPath $MoonSharpPath).Path
  $vm=New-Object MoonSharp.Interpreter.Script
  foreach($file in Get-ChildItem -LiteralPath $addon -Filter '*.lua'){
   [void]$vm.LoadString((Get-Content -LiteralPath $file.FullName -Raw),$null,$file.Name)
  }
  # Same load and execution order as tests/run.lua; printing is handled below.
  [void]$vm.DoString((Get-Content -LiteralPath 'tests/Test-Reroll.lua' -Raw))
  foreach($name in @('Model.lua','Client.lua','Presentation.lua')){[void]$vm.DoString((Get-Content -LiteralPath (Join-Path $addon $name) -Raw))}
  [void]$vm.DoString('RunTests()')
  foreach($name in @('Skin.lua','UI.lua')){[void]$vm.DoString((Get-Content -LiteralPath (Join-Path $addon $name) -Raw))}
  [void]$vm.DoString('RunUITests()')
  [void]$vm.DoString((Get-Content -LiteralPath 'tests/Test-History.lua' -Raw))
  [void]$vm.DoString('RunHistoryTests()')
  foreach($name in @('Test-Skin.lua','Test-Polish.lua','Test-HideLocked.lua','Test-Notices.lua')){[void]$vm.DoString((Get-Content -LiteralPath (Join-Path 'tests' $name) -Raw))}
  [void]$vm.DoString((Get-Content -LiteralPath (Join-Path $addon 'Core.lua') -Raw))
  [void]$vm.DoString('RunCoreTests()')
  $results=@($vm.Globals.Get('results').Table.Values)
  $results|ForEach-Object {$_.String}
  [void]$vm.DoString('FinishTests()')
  Write-Output "PASS: $($results.Count) offline behavior/layout tests; mock APIs only."
 }
} finally {Pop-Location}
