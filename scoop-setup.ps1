param($dir, $app)

. "$scoopdir\apps\scoop\current\lib\manifest.ps1" # 'Get-Manifest'
. "$scoopdir\apps\scoop\current\lib\versions.ps1" # 'Select-CurrentVersion'

$ProductName = (Get-Item $dir).VersionInfo.ProductName
$architecture = Get-DefaultArchitecture

function GetAllApps {
   Param(
     [Parameter(ValueFromPipeline = $true, Position = 0, Mandatory = $true)]
     [object[]]$str
   )
   [string]$bucket = $null
   $apps = @()
   $str | ForEach-Object {
     if ($_ -match "\'(?<bucket>[^\']+)\' bucket") {
       $bucket = $Matches.bucket
     }
     elseif ($_ -match "(?<app>[^\s]+)\s\((?<version>[^\)]+)\)\s(?:\[(?<status>[ ^\]]+)\])?") {
       $app = $Matches.Clone()
       $app.bucket = $bucket
       $app.value = @($bucket, $app.app) -join '/'
       $apps += $app
     }
   }
   $apps
}

function SetupApp {
   Param($filePath, $curr_app)
   $app, $bucket, $version = parse_app $curr_app
   $app, $manifest, $bucket, $url = Get-Manifest "$bucket/$app"

   $version = $manifest.version
   $architecture = Get-SupportedArchitecture $manifest $architecture

   $url = script:url $manifest $architecture
   $cached = fullpath (cache_path $app $version $url)
   Copy-Item -Path $filePath -Destination $cached -Force
   info "Added to cache successfully"
   $installed = installed $app
   if ($installed) {
     scoop update $("$bucket/$app") --force --skip
   }
   else {
     scoop install $("$bucket/$app") --no-update-scoop --skip
   }
}

$apps = GetAllApps(sfsu.exe search $ProductName.ToLower())
[object]$selected = if ( $app ) {
   $apps | Where-Object { $_.value -eq $app } | Select-Object -First 1
}
else {
   $null
}

if (!$apps.count) {
   Write-Host "Unknown $ProductName"
   return
}

if ($app -and !$selected) {
   Write-Host "The mainfest $app does not exist, please select an mainfest to install:"
}
elseif (!$app) {
   Write-Host "Please select an mainfest to install:"
}
else {
   Write-Host "Installing with mainfest $app"
}

while (!$selected) {
   $i = 0
   $appsMap = @{}
   $apps | ForEach-Object {
     $i += 1
     $str = $("$i.", $($_.value)) -join ' '
     $str += if ($_.status) { " [$($_.status)]" } else { "" }
     $appsMap[$_.value] = $_
     Write-Host $str
   }

   # Get the user's choice
   $selectedIndex = Read-Host "Please enter your selection (1-$i)"

   # Validate input and perform corresponding operations
   if ($selectedIndex -match "[1-$i]") {
     $selected = $apps[$selectedIndex - 1]
     $app = $selected.value
     Write-Host "You selected: $app"
   }
   else {
     Write-Host "Wrong selection, please select again"
   }
}

SetupApp $dir $selected.value
