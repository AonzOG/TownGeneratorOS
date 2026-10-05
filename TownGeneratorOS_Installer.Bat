@echo off
rem TownGeneratorOS Installer v8 - Canvas2D HTML5 compatibility build
setlocal
set "TGOS_INSTALLER_SELF=%~f0"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$raw=[System.IO.File]::ReadAllText($env:TGOS_INSTALLER_SELF); $marker=('#'+'==POWERSHELL=='); $i=$raw.IndexOf($marker); if($i -lt 0){throw 'Embedded PowerShell payload not found.'}; $code=$raw.Substring($i+$marker.Length); Invoke-Expression $code"
set "TGOS_EXIT=%ERRORLEVEL%"
endlocal & exit /b %TGOS_EXIT%
#==POWERSHELL==

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$script:ProductName = 'TownGeneratorOS'
$script:ProductTitle = 'Medieval Fantasy City Generator'
$script:InstallId = 'AonzOG.TownGeneratorOS.OpenFL.HTML5'
$script:RepoUrl = 'https://github.com/AonzOG/TownGeneratorOS'
$script:RepoCommit = '7fbc87a9398cc508af24de93f79cf2ad027f352b'
$script:RepoZipUrl = "https://github.com/AonzOG/TownGeneratorOS/archive/$($script:RepoCommit).zip"
$script:HaxeVersion = '3.4.7'
$script:NekoVersion = '2.2.0'
$script:LimeVersion = '7.3.0'
$script:OpenFLVersion = '8.9.0'
$script:MsignalVersion = '1.2.5'
$script:HaxelibCdnBase = 'https://haxelib-tr40bgq5.fra1.cdn.digitaloceanspaces.com/files/3.0'
$script:HaxelibStaticBase = 'https://lib.haxe.org/files/3.0'
$script:LimePackageFile = 'lime-7,3,0.zip'
$script:OpenFLPackageFile = 'openfl-8,9,0.zip'
$script:MsignalPackageFile = 'msignal-1,2,5.zip'
$script:HaxeZipUrl = 'https://github.com/HaxeFoundation/haxe/releases/download/3.4.7/haxe-3.4.7-win.zip'
$script:HaxeZipSize = 6346045
$script:NekoZipUrl = 'https://github.com/HaxeFoundation/neko/releases/download/v2-2-0/neko-2.2.0-win.zip'
$script:NekoZipSize = 1603570
$script:VcRedistX86Url = 'https://aka.ms/vc14/vc_redist.x86.exe'
$script:DefaultInstallDir = 'C:\TownGeneratorOS'
$script:InstallerSelf = [IO.Path]::GetFullPath($env:TGOS_INSTALLER_SELF)
$script:Mode = 'Install'
$script:InstallDir = $script:DefaultInstallDir
$script:DependenciesBuilt = $false

function Show-Error([string]$Message) {
    [System.Windows.Forms.MessageBox]::Show($Message, "$($script:ProductName) Setup", 'OK', 'Error') | Out-Null
}

function Show-Info([string]$Message) {
    [System.Windows.Forms.MessageBox]::Show($Message, "$($script:ProductName) Setup", 'OK', 'Information') | Out-Null
}

function Confirm-Action([string]$Message) {
    $result = [System.Windows.Forms.MessageBox]::Show($Message, "$($script:ProductName) Setup", 'YesNo', 'Warning')
    return $result -eq [System.Windows.Forms.DialogResult]::Yes
}

function Normalize-Path([string]$Path) {
    $expanded = [Environment]::ExpandEnvironmentVariables(($Path + '').Trim())
    if ([string]::IsNullOrWhiteSpace($expanded)) { return $script:DefaultInstallDir }
    return [IO.Path]::GetFullPath($expanded).TrimEnd('\')
}

function Get-InstallPaths([string]$Root) {
    return [pscustomobject]@{
        Root = $Root
        App = Join-Path $Root 'app'
        Runtime = Join-Path $Root 'runtime'
        Haxe = Join-Path $Root 'runtime\haxe'
        Neko = Join-Path $Root 'runtime\neko'
        Haxelib = Join-Path $Root 'haxelib'
        Logs = Join-Path $Root 'logs'
        Marker = Join-Path $Root '.towngeneratoros-installer.json'
        Launcher = Join-Path $Root 'Start TownGeneratorOS.bat'
        Index = Join-Path $Root 'app\Export\html5\bin\index.html'
    }
}

function Assert-SafeRoot([string]$Root) {
    $full = Normalize-Path $Root
    $dangerous = @(
        [IO.Path]::GetPathRoot($full).TrimEnd('\'),
        $env:SystemRoot.TrimEnd('\'),
        $env:USERPROFILE.TrimEnd('\'),
        $env:LOCALAPPDATA.TrimEnd('\'),
        $env:APPDATA.TrimEnd('\'),
        $env:ProgramFiles.TrimEnd('\')
    ) | Where-Object { $_ }
    foreach ($d in $dangerous) {
        if ($full.Equals($d, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Safety stop: '$full' is too broad to use as an installation root."
        }
    }
    return $full
}

function Assert-WritableInstallPath([string]$Root) {
    $Root = Assert-SafeRoot $Root
    if (-not (Test-Path -LiteralPath $Root)) {
        New-Item -ItemType Directory -Path $Root -Force | Out-Null
    }
    $probe = Join-Path $Root ('.tgos-write-test-' + [guid]::NewGuid().ToString('N') + '.tmp')
    try {
        [IO.File]::WriteAllText($probe, 'test')
    } finally {
        Remove-Item -LiteralPath $probe -Force -ErrorAction SilentlyContinue
    }
}

function Read-InstallMarker([string]$Root) {
    $p = (Get-InstallPaths $Root).Marker
    if (-not (Test-Path -LiteralPath $p)) { return $null }
    try { return (Get-Content -LiteralPath $p -Raw | ConvertFrom-Json) } catch { return $null }
}

function Assert-RecognizedInstall([string]$Root) {
    $marker = Read-InstallMarker $Root
    if (-not $marker -or $marker.installId -ne $script:InstallId) {
        throw 'Safety stop: the selected folder is not recognized as a TownGeneratorOS installation made by this installer.'
    }
}

function Invoke-RobocopyTree([string]$Source, [string]$Destination) {
    if (-not (Test-Path -LiteralPath $Destination)) {
        New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    }
    & robocopy.exe $Source $Destination /E /COPY:DAT /DCOPY:DAT /R:2 /W:1 /NFL /NDL /NP | Out-Null
    $code = $LASTEXITCODE
    if ($code -ge 8) { throw "Robocopy failed with exit code $code." }
}

function Download-File([string]$Uri, [string]$OutFile, [Int64]$ExpectedSize = -1) {
    Invoke-WebRequest -UseBasicParsing -Uri $Uri -OutFile $OutFile
    if (-not (Test-Path -LiteralPath $OutFile)) { throw "Download failed: $Uri" }
    if ($ExpectedSize -ge 0) {
        [Int64]$actual = (Get-Item -LiteralPath $OutFile).Length
        if ($actual -ne $ExpectedSize) {
            throw "Downloaded file size mismatch for $Uri. Expected $ExpectedSize bytes, got $actual bytes."
        }
    }
}

function Test-ZipArchive([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
        $zip = [IO.Compression.ZipFile]::OpenRead($Path)
        try {
            return ($zip.Entries.Count -gt 0)
        } finally {
            $zip.Dispose()
        }
    } catch {
        return $false
    }
}

function Download-HaxelibPackage([string]$FileName, [string]$OutFile) {
    $urls = @(
        ($script:HaxelibCdnBase + '/' + $FileName),
        ($script:HaxelibStaticBase + '/' + $FileName)
    )
    $lastError = $null
    foreach ($url in $urls) {
        try {
            Remove-Item -LiteralPath $OutFile -Force -ErrorAction SilentlyContinue
            Download-File $url $OutFile
            if (-not (Test-ZipArchive $OutFile)) {
                throw "Downloaded Haxelib package is not a valid ZIP archive: $url"
            }
            return $url
        } catch {
            $lastError = $_
        }
    }
    if ($lastError) { throw $lastError }
    throw "Unable to download Haxelib package: $FileName"
}

function Test-VcRuntimeX86 {
    $keys = @(
        'HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x86',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\14.0\VC\Runtimes\x86'
    )
    foreach ($key in $keys) {
        try {
            $item = Get-ItemProperty -LiteralPath $key -ErrorAction Stop
            if ($item.Installed -eq 1) { return $true }
        } catch { }
    }
    return $false
}

function Install-VcRuntimeX86 {
    $file = Join-Path $env:TEMP ('tgos-vcredist-x86-' + [guid]::NewGuid().ToString('N') + '.exe')
    try {
        Download-File $script:VcRedistX86Url $file
        $sig = Get-AuthenticodeSignature -LiteralPath $file
        if ($sig.Status -ne 'Valid' -or -not $sig.SignerCertificate -or $sig.SignerCertificate.Subject -notmatch 'Microsoft') {
            throw 'Microsoft Visual C++ Redistributable signature verification failed.'
        }
        $proc = Start-Process -FilePath $file -ArgumentList @('/install','/quiet','/norestart') -Verb RunAs -Wait -PassThru
        if ($proc.ExitCode -notin @(0, 1638, 3010)) {
            throw "Microsoft Visual C++ x86 Redistributable installer returned exit code $($proc.ExitCode)."
        }
    } finally {
        Remove-Item -LiteralPath $file -Force -ErrorAction SilentlyContinue
    }
}

function Move-ExtractedRootContents([string]$ExtractRoot, [string]$Destination) {
    $dirs = @(Get-ChildItem -LiteralPath $ExtractRoot -Directory -Force)
    $files = @(Get-ChildItem -LiteralPath $ExtractRoot -File -Force)
    $source = $ExtractRoot
    if ($dirs.Count -eq 1 -and $files.Count -eq 0) { $source = $dirs[0].FullName }
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    Get-ChildItem -LiteralPath $source -Force | ForEach-Object {
        Move-Item -LiteralPath $_.FullName -Destination $Destination -Force
    }
}

function Validate-AppSource([string]$AppDir) {
    $project = Join-Path $AppDir 'project.xml'
    $main = Join-Path $AppDir 'Source\com\watabou\towngenerator\Main.hx'
    if (-not (Test-Path -LiteralPath $project) -or -not (Test-Path -LiteralPath $main)) {
        throw 'Downloaded source is not a recognizable TownGeneratorOS/OpenFL project.'
    }
    [xml]$xml = Get-Content -LiteralPath $project -Raw
    if ($xml.project.meta.package -ne 'com.watabou.towngenerator') {
        throw 'Downloaded project.xml has an unexpected application package.'
    }
    $libs = @{}
    foreach ($lib in $xml.project.haxelib) { $libs[$lib.name] = $lib.version }
    if ($libs['lime'] -ne $script:LimeVersion -or $libs['openfl'] -ne $script:OpenFLVersion -or $libs['msignal'] -ne $script:MsignalVersion) {
        throw 'Downloaded project.xml dependency pins do not match the installer expectations.'
    }
}

function Download-Source([string]$Root) {
    $p = Get-InstallPaths $Root
    $zip = Join-Path $env:TEMP ('tgos-source-' + [guid]::NewGuid().ToString('N') + '.zip')
    $extract = Join-Path $env:TEMP ('tgos-source-' + [guid]::NewGuid().ToString('N'))
    try {
        Remove-Item -LiteralPath $p.App -Recurse -Force -ErrorAction SilentlyContinue
        New-Item -ItemType Directory -Path $extract -Force | Out-Null
        Download-File $script:RepoZipUrl $zip
        Expand-Archive -LiteralPath $zip -DestinationPath $extract -Force
        $rootDir = Get-ChildItem -LiteralPath $extract -Directory | Select-Object -First 1
        if (-not $rootDir) { throw 'Repository archive did not contain a source directory.' }
        Invoke-RobocopyTree $rootDir.FullName $p.App
        Validate-AppSource $p.App
    } finally {
        Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $extract -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Set-LocalToolEnvironment([string]$Root) {
    $p = Get-InstallPaths $Root
    $env:HAXEPATH = $p.Haxe
    $env:HAXE_STD_PATH = Join-Path $p.Haxe 'std'
    $env:HAXELIB_PATH = $p.Haxelib
    $env:NEKOPATH = $p.Neko
    $env:PATH = "$($p.Haxe);$($p.Neko);$env:PATH"
}

function Invoke-VersionProbe([string]$FilePath, [string]$Argument) {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $FilePath
    $psi.Arguments = $Argument
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    try {
        $proc = New-Object System.Diagnostics.Process
        $proc.StartInfo = $psi
        if (-not $proc.Start()) { return [pscustomobject]@{ Started=$false; ExitCode=$null; Text='Process did not start.' } }
        $stdout = $proc.StandardOutput.ReadToEnd()
        $stderr = $proc.StandardError.ReadToEnd()
        $proc.WaitForExit()
        return [pscustomobject]@{ Started=$true; ExitCode=$proc.ExitCode; Text=(($stdout + "`n" + $stderr).Trim()) }
    } catch {
        return [pscustomobject]@{ Started=$false; ExitCode=$null; Text=$_.Exception.Message }
    }
}

function Get-LocalRuntimeInfo([string]$Root) {
    $p = Get-InstallPaths $Root
    $haxe = Join-Path $p.Haxe 'haxe.exe'
    $haxelib = Join-Path $p.Haxe 'haxelib.exe'
    $neko = Join-Path $p.Neko 'neko.exe'
    $filesPresent = (Test-Path -LiteralPath $haxe) -and (Test-Path -LiteralPath $haxelib) -and (Test-Path -LiteralPath $neko)
    $hv = $null
    $nv = $null
    $detail = $null
    $valid = $false
    if ($filesPresent) {
        Set-LocalToolEnvironment $Root
        $hp = Invoke-VersionProbe $haxe '-version'
        $np = Invoke-VersionProbe $neko '-version'
        $hv = $hp.Text
        $nv = $np.Text
        $haxeMatches = $hp.Started -and ($hp.ExitCode -eq 0) -and ($hp.Text -match ('(^|[^0-9])' + [regex]::Escape($script:HaxeVersion) + '([^0-9]|$)'))
        $nekoMatches = $np.Started -and ($np.ExitCode -eq 0) -and ($np.Text -match ('(^|[^0-9])' + [regex]::Escape($script:NekoVersion) + '([^0-9]|$)'))
        $valid = $haxeMatches -and $nekoMatches
        if (-not $valid) {
            $detail = "Haxe probe: started=$($hp.Started), exit=$($hp.ExitCode), output='$($hp.Text)'; Neko probe: started=$($np.Started), exit=$($np.ExitCode), output='$($np.Text)'"
        }
    } else {
        $detail = 'One or more runtime executables are missing after extraction.'
    }
    return [pscustomobject]@{ Valid=$valid; HaxeVersion=$hv; NekoVersion=$nv; Haxe=$haxe; Haxelib=$haxelib; Neko=$neko; Detail=$detail }
}

function Install-LocalRuntime([string]$Root) {
    $p = Get-InstallPaths $Root
    New-Item -ItemType Directory -Path $p.Runtime -Force | Out-Null
    New-Item -ItemType Directory -Path $p.Haxelib -Force | Out-Null
    Remove-Item -LiteralPath $p.Haxe -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $p.Neko -Recurse -Force -ErrorAction SilentlyContinue

    $haxeZip = Join-Path $env:TEMP ('tgos-haxe-' + [guid]::NewGuid().ToString('N') + '.zip')
    $haxeExtract = Join-Path $env:TEMP ('tgos-haxe-' + [guid]::NewGuid().ToString('N'))
    $nekoZip = Join-Path $env:TEMP ('tgos-neko-' + [guid]::NewGuid().ToString('N') + '.zip')
    $nekoExtract = Join-Path $env:TEMP ('tgos-neko-' + [guid]::NewGuid().ToString('N'))
    try {
        New-Item -ItemType Directory -Path $haxeExtract -Force | Out-Null
        New-Item -ItemType Directory -Path $nekoExtract -Force | Out-Null

        Download-File $script:HaxeZipUrl $haxeZip ([Int64]$script:HaxeZipSize)
        Expand-Archive -LiteralPath $haxeZip -DestinationPath $haxeExtract -Force
        Move-ExtractedRootContents $haxeExtract $p.Haxe

        Download-File $script:NekoZipUrl $nekoZip ([Int64]$script:NekoZipSize)
        Expand-Archive -LiteralPath $nekoZip -DestinationPath $nekoExtract -Force
        Move-ExtractedRootContents $nekoExtract $p.Neko

        Set-LocalToolEnvironment $Root

        if (-not (Test-VcRuntimeX86)) {
            $installVc = Confirm-Action 'This historical Haxe/Neko toolchain needs the Microsoft Visual C++ x86 runtime. It is not detected. Install the official Microsoft runtime now? Windows may show a UAC prompt.'
            if ($installVc) { Install-VcRuntimeX86 }
        }

        $info = Get-LocalRuntimeInfo $Root
        if (-not $info.Valid) {
            $repairVc = Confirm-Action ("The local Haxe/Neko executables did not verify correctly. Install or repair the official Microsoft Visual C++ x86 runtime and retry the probes?`n`n" + $info.Detail)
            if ($repairVc) {
                Install-VcRuntimeX86
                $info = Get-LocalRuntimeInfo $Root
            }
        }
        if (-not $info.Valid) {
            throw ("Haxe/Neko archives were extracted, but runtime verification failed. " + $info.Detail)
        }
        return $info
    } finally {
        Remove-Item -LiteralPath $haxeZip -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $haxeExtract -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $nekoZip -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $nekoExtract -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Ensure-LocalRuntime([string]$Root) {
    $info = Get-LocalRuntimeInfo $Root
    if ($info.Valid) { return $info }
    return Install-LocalRuntime $Root
}

function New-BuildCommand([string]$Root) {
    $p = Get-InstallPaths $Root
    $info = Ensure-LocalRuntime $Root
    $cmd = Join-Path $env:TEMP ('tgos-build-' + [guid]::NewGuid().ToString('N') + '.cmd')
    $log = Join-Path $p.Logs 'build.log'
    New-Item -ItemType Directory -Path $p.Logs -Force | Out-Null
    $packageDir = Join-Path $p.Runtime 'packages'
    New-Item -ItemType Directory -Path $packageDir -Force | Out-Null
    $limeArchive = Join-Path $packageDir $script:LimePackageFile
    $openflArchive = Join-Path $packageDir $script:OpenFLPackageFile
    $msignalArchive = Join-Path $packageDir $script:MsignalPackageFile

    Download-HaxelibPackage $script:LimePackageFile $limeArchive | Out-Null
    Download-HaxelibPackage $script:OpenFLPackageFile $openflArchive | Out-Null
    Download-HaxelibPackage $script:MsignalPackageFile $msignalArchive | Out-Null

    $content = @"
@echo off
setlocal
title TownGeneratorOS - Installing Haxe libraries and building
set "HAXEPATH=$($p.Haxe)"
set "HAXE_STD_PATH=$($p.Haxe)\std"
set "HAXELIB_PATH=$($p.Haxelib)"
set "NEKOPATH=$($p.Neko)"
set "PATH=$($p.Haxe);$($p.Neko);%PATH%"
cd /d "$($p.App)"
echo TownGeneratorOS build started > "$log"
echo. >> "$log"
echo Installing pinned Haxelib packages from local release archives...
echo lime $($script:LimeVersion) >> "$log"
"$($info.Haxelib)" install "$limeArchive" --always >> "$log" 2>&1
if errorlevel 1 goto :fail
echo openfl $($script:OpenFLVersion) >> "$log"
"$($info.Haxelib)" install "$openflArchive" --always >> "$log" 2>&1
if errorlevel 1 goto :fail
echo msignal $($script:MsignalVersion) >> "$log"
"$($info.Haxelib)" install "$msignalArchive" --always >> "$log" 2>&1
if errorlevel 1 goto :fail
"$($info.Haxelib)" set lime $($script:LimeVersion) >> "$log" 2>&1
if errorlevel 1 goto :fail
"$($info.Haxelib)" set openfl $($script:OpenFLVersion) >> "$log" 2>&1
if errorlevel 1 goto :fail
"$($info.Haxelib)" set msignal $($script:MsignalVersion) >> "$log" 2>&1
if errorlevel 1 goto :fail
echo Building HTML5 release...
"$($info.Haxelib)" run lime build html5 -release -nocffi -Dcanvas >> "$log" 2>&1
if errorlevel 1 goto :fail
if not exist "$($p.Index)" (
  echo Build completed but index.html was not found at expected path. >> "$log"
  goto :fail
)
echo.
echo Build complete.
echo Log: $log
exit /b 0
:fail
echo.
echo Build failed. Review:
echo   $log
echo.
type "$log"
pause
exit /b 1
"@
    Set-Content -LiteralPath $cmd -Value $content -Encoding ASCII
    return $cmd
}

function Test-Vc2013RuntimeX86 {
    $windows = $env:WINDIR
    if ([Environment]::Is64BitOperatingSystem) {
        $crtDir = Join-Path $windows 'SysWOW64'
    } else {
        $crtDir = Join-Path $windows 'System32'
    }
    $msvcr = Join-Path $crtDir 'msvcr120.dll'
    $msvcp = Join-Path $crtDir 'msvcp120.dll'
    return (Test-Path -LiteralPath $msvcr) -and (Test-Path -LiteralPath $msvcp)
}

function Install-Vc2013RuntimeX86 {
    $url = 'https://aka.ms/highdpimfc2013x86enu'
    $file = Join-Path $env:TEMP ('tgos-vc2013-x86-' + [guid]::NewGuid().ToString('N') + '.exe')
    try {
        Download-File $url $file
        $sig = Get-AuthenticodeSignature -LiteralPath $file
        if ($sig.Status -ne 'Valid' -or -not $sig.SignerCertificate -or $sig.SignerCertificate.Subject -notmatch 'Microsoft') {
            throw 'Microsoft Visual C++ 2013 x86 Redistributable signature verification failed.'
        }
        $proc = Start-Process -FilePath $file -ArgumentList @('/install','/quiet','/norestart') -Verb RunAs -Wait -PassThru
        if ($proc.ExitCode -notin @(0, 1638, 3010)) {
            throw "Microsoft Visual C++ 2013 x86 Redistributable returned exit code $($proc.ExitCode)."
        }
        if (-not (Test-Vc2013RuntimeX86)) {
            if ($proc.ExitCode -eq 3010) {
                throw 'Visual C++ 2013 x86 runtime installed but Windows reports that a restart is required. Restart Windows, then run Step 4 again.'
            }
            throw 'Visual C++ 2013 x86 runtime installation completed, but MSVCR120.dll/MSVCP120.dll are still not available to 32-bit applications.'
        }
    } finally {
        Remove-Item -LiteralPath $file -Force -ErrorAction SilentlyContinue
    }
}

function Ensure-HaxelibStep4Prerequisites([string]$Root) {
    $p = Get-InstallPaths $Root
    $haxelib = Join-Path $p.Haxe 'haxelib.exe'
    if (-not (Test-Path -LiteralPath $haxelib)) {
        throw "Step 4 cannot start because haxelib.exe is missing: $haxelib"
    }

    if (-not (Test-Vc2013RuntimeX86)) {
        Install-Vc2013RuntimeX86
    }
}

function Run-DependencyBuild([string]$Root) {
    Ensure-HaxelibStep4Prerequisites $Root
    $cmd = New-BuildCommand $Root
    try {
        $proc = Start-Process -FilePath $env:ComSpec -ArgumentList @('/d','/c',('"' + $cmd + '"')) -Wait -PassThru
        if ($proc.ExitCode -ne 0) { throw "Dependency installation/build failed with exit code $($proc.ExitCode)." }
        $p = Get-InstallPaths $Root
        if (-not (Test-Path -LiteralPath $p.Index)) { throw 'Build finished without producing the expected HTML5 index.html.' }
    } finally {
        Remove-Item -LiteralPath $cmd -Force -ErrorAction SilentlyContinue
    }
}

function Write-Launcher([string]$Root) {
    $p = Get-InstallPaths $Root
    $content = @"
@echo off
setlocal
title TownGeneratorOS Local Server
set "TGOS_ROOT=%~dp0"
set "TGOS_WEBROOT=%TGOS_ROOT%app\Export\html5\bin"
set "TGOS_INDEX=%TGOS_WEBROOT%\index.html"
set "TGOS_NODE=%TGOS_ROOT%haxelib\lime\7,3,0\templates\bin\node\node-windows.exe"
set "TGOS_SERVER=%TGOS_ROOT%haxelib\lime\7,3,0\templates\bin\node\http-server\bin\http-server"
if not exist "%TGOS_INDEX%" (
  echo TownGeneratorOS is not built or the installation is incomplete.
  echo Expected:
  echo   %TGOS_INDEX%
  echo.
  echo Run TownGeneratorOS_Installer_v8.bat and choose Repair.
  pause
  exit /b 1
)
if not exist "%TGOS_NODE%" (
  echo Lime's bundled Node runtime was not found.
  echo Expected:
  echo   %TGOS_NODE%
  echo.
  echo Run TownGeneratorOS_Installer_v8.bat and choose Repair.
  pause
  exit /b 1
)
if not exist "%TGOS_SERVER%" (
  echo Lime's bundled HTML5 web server was not found.
  echo Expected:
  echo   %TGOS_SERVER%
  echo.
  echo Run TownGeneratorOS_Installer_v8.bat and choose Repair.
  pause
  exit /b 1
)
echo Starting TownGeneratorOS through Lime's local HTML5 server...
echo The browser will open automatically.
echo Keep this window open while using TownGeneratorOS.
echo Press CTRL+C or close this window to stop the server.
echo.
"%TGOS_NODE%" "%TGOS_SERVER%" "%TGOS_WEBROOT%" -a 127.0.0.1 -c-1 --cors -o
set "TGOS_EXIT=%ERRORLEVEL%"
if not "%TGOS_EXIT%"=="0" (
  echo.
  echo TownGeneratorOS local server exited with code %TGOS_EXIT%.
  pause
)
exit /b %TGOS_EXIT%
"@
    Set-Content -LiteralPath $p.Launcher -Value $content -Encoding ASCII
    return $p.Launcher
}

function Write-ProvisionalMarker([string]$Root, [string]$State) {
    $p = Get-InstallPaths $Root
    $marker = [ordered]@{
        installId = $script:InstallId
        product = $script:ProductName
        title = $script:ProductTitle
        installRoot = $Root
        repository = $script:RepoUrl
        sourceCommit = $script:RepoCommit
        state = $State
        target = 'html5'
        createdAt = (Get-Date).ToString('o')
        ownedPaths = @('app','runtime','haxelib','logs','Start TownGeneratorOS.bat','.towngeneratoros-installer.json')
    }
    $marker | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $p.Marker -Encoding UTF8
}

function Write-InstallMarker([string]$Root) {
    $p = Get-InstallPaths $Root
    $runtime = Get-LocalRuntimeInfo $Root
    $marker = [ordered]@{
        installId = $script:InstallId
        product = $script:ProductName
        title = $script:ProductTitle
        installRoot = $Root
        repository = $script:RepoUrl
        sourceCommit = $script:RepoCommit
        haxeVersion = $runtime.HaxeVersion
        nekoVersion = $runtime.NekoVersion
        limeVersion = $script:LimeVersion
        openflVersion = $script:OpenFLVersion
        msignalVersion = $script:MsignalVersion
        target = 'html5'
        state = 'installed'
        installedAt = (Get-Date).ToString('o')
        ownedPaths = @('app','runtime','haxelib','logs','Start TownGeneratorOS.bat','.towngeneratoros-installer.json')
    }
    $marker | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $p.Marker -Encoding UTF8
}

function Prepare-Install([string]$Root, [bool]$Repair) {
    $Root = Assert-SafeRoot $Root
    Assert-WritableInstallPath $Root
    $p = Get-InstallPaths $Root
    $marker = Read-InstallMarker $Root

    if ($Repair) {
        Assert-RecognizedInstall $Root
        Write-ProvisionalMarker $Root 'repairing'
        foreach ($path in @($p.App, $p.Runtime, $p.Haxelib, $p.Launcher)) {
            Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction SilentlyContinue
        }
    } elseif ($marker -and $marker.installId -eq $script:InstallId) {
        if (-not (Confirm-Action "An existing TownGeneratorOS installation was found in:`n`n$Root`n`nReinstall it?")) {
            throw 'Installation cancelled.'
        }
        Write-ProvisionalMarker $Root 'reinstalling'
        foreach ($path in @($p.App, $p.Runtime, $p.Haxelib, $p.Launcher)) {
            Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction SilentlyContinue
        }
    } else {
        if ($marker) {
            throw 'Safety stop: the selected folder contains an installation marker that does not belong to TownGeneratorOS.'
        }
        $ownedCollisions = @($p.App, $p.Runtime, $p.Haxelib, $p.Logs, $p.Launcher) | Where-Object { Test-Path -LiteralPath $_ }
        if ($ownedCollisions.Count -gt 0) {
            throw "Safety stop: the selected folder already contains one or more paths this installer would own:`n`n$($ownedCollisions -join "`n")`n`nChoose a different folder or remove/rename those paths yourself."
        }
        $existing = @(Get-ChildItem -LiteralPath $Root -Force -ErrorAction SilentlyContinue)
        if ($existing.Count -gt 0) {
            if (-not (Confirm-Action "The selected folder already contains unrelated files:`n`n$Root`n`nTownGeneratorOS will use its own app, runtime, haxelib, and logs entries and will leave other files untouched. Continue?")) {
                throw 'Installation cancelled.'
            }
        }
        Write-ProvisionalMarker $Root 'installing'
    }

    Download-Source $Root
}

function Start-App([string]$Root) {
    $p = Get-InstallPaths $Root
    if (-not (Test-Path -LiteralPath $p.Index)) { throw 'The built application was not found. Run Repair first.' }
    if (-not (Test-Path -LiteralPath $p.Launcher)) { Write-Launcher $Root | Out-Null }
    Start-Process -FilePath $env:ComSpec -ArgumentList @('/d','/c',('"' + $p.Launcher + '"')) -WorkingDirectory $Root | Out-Null
}

function Invoke-Uninstall([string]$Root) {
    $Root = Assert-SafeRoot $Root
    Assert-RecognizedInstall $Root
    $p = Get-InstallPaths $Root
    if (-not (Confirm-Action "Remove TownGeneratorOS installer-owned files from:`n`n$Root`n`nUnmanaged files in the folder will be left untouched.")) {
        throw 'Uninstall cancelled.'
    }

    foreach ($path in @($p.App, $p.Runtime, $p.Haxelib, $p.Logs, $p.Launcher, $p.Marker)) {
        if (Test-Path -LiteralPath $path) {
            Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction Stop
        }
    }

    $remaining = @(Get-ChildItem -LiteralPath $Root -Force -ErrorAction SilentlyContinue)
    if ($remaining.Count -eq 0) {
        Remove-Item -LiteralPath $Root -Force -ErrorAction SilentlyContinue
    }
}

# ---- GUI wizard ----
$form = New-Object System.Windows.Forms.Form
$form.Text = 'TownGeneratorOS Setup'
$form.StartPosition = 'CenterScreen'
$form.Size = New-Object System.Drawing.Size(820, 560)
$form.MinimumSize = New-Object System.Drawing.Size(820, 560)
$form.MaximizeBox = $false
$form.FormBorderStyle = 'FixedDialog'
$form.Font = New-Object System.Drawing.Font('Segoe UI', 10)

$header = New-Object System.Windows.Forms.Label
$header.Location = New-Object System.Drawing.Point(28, 18)
$header.Size = New-Object System.Drawing.Size(750, 34)
$header.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 18)
$header.Text = 'TownGeneratorOS Setup'
$form.Controls.Add($header)

$stepLabel = New-Object System.Windows.Forms.Label
$stepLabel.Location = New-Object System.Drawing.Point(31, 58)
$stepLabel.Size = New-Object System.Drawing.Size(740, 22)
$stepLabel.ForeColor = [System.Drawing.Color]::DimGray
$form.Controls.Add($stepLabel)

$line = New-Object System.Windows.Forms.Label
$line.BorderStyle = 'Fixed3D'
$line.Location = New-Object System.Drawing.Point(30, 88)
$line.Size = New-Object System.Drawing.Size(748, 2)
$form.Controls.Add($line)

$panelHost = New-Object System.Windows.Forms.Panel
$panelHost.Location = New-Object System.Drawing.Point(30, 105)
$panelHost.Size = New-Object System.Drawing.Size(748, 350)
$form.Controls.Add($panelHost)

$backButton = New-Object System.Windows.Forms.Button
$backButton.Text = '< Back'
$backButton.Location = New-Object System.Drawing.Point(548, 472)
$backButton.Size = New-Object System.Drawing.Size(105, 34)
$form.Controls.Add($backButton)

$nextButton = New-Object System.Windows.Forms.Button
$nextButton.Text = 'Next >'
$nextButton.Location = New-Object System.Drawing.Point(665, 472)
$nextButton.Size = New-Object System.Drawing.Size(105, 34)
$form.Controls.Add($nextButton)

$cancelButton = New-Object System.Windows.Forms.Button
$cancelButton.Text = 'Cancel'
$cancelButton.Location = New-Object System.Drawing.Point(30, 472)
$cancelButton.Size = New-Object System.Drawing.Size(105, 34)
$form.Controls.Add($cancelButton)

$panels = @()
for ($i=0; $i -lt 5; $i++) {
    $panel = New-Object System.Windows.Forms.Panel
    $panel.Dock = 'Fill'
    $panel.Visible = $false
    $panelHost.Controls.Add($panel)
    $panels += $panel
}

# Page 1: action
$p1Title = New-Object System.Windows.Forms.Label
$p1Title.Text = 'Choose an action'
$p1Title.Location = New-Object System.Drawing.Point(0, 8)
$p1Title.Size = New-Object System.Drawing.Size(700, 30)
$p1Title.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 14)
$panels[0].Controls.Add($p1Title)

$installRadio = New-Object System.Windows.Forms.RadioButton
$installRadio.Text = 'Install'
$installRadio.Location = New-Object System.Drawing.Point(10, 58)
$installRadio.Size = New-Object System.Drawing.Size(200, 28)
$installRadio.Checked = $true
$panels[0].Controls.Add($installRadio)

$installDesc = New-Object System.Windows.Forms.Label
$installDesc.Text = 'Download the pinned TownGeneratorOS source, install a private Haxe/Neko toolchain, install exact Haxelib dependencies, and build the HTML5 release.'
$installDesc.Location = New-Object System.Drawing.Point(35, 87)
$installDesc.Size = New-Object System.Drawing.Size(680, 48)
$installDesc.ForeColor = [System.Drawing.Color]::DimGray
$panels[0].Controls.Add($installDesc)

$repairRadio = New-Object System.Windows.Forms.RadioButton
$repairRadio.Text = 'Repair'
$repairRadio.Location = New-Object System.Drawing.Point(10, 145)
$repairRadio.Size = New-Object System.Drawing.Size(200, 28)
$panels[0].Controls.Add($repairRadio)

$repairDesc = New-Object System.Windows.Forms.Label
$repairDesc.Text = 'Reconstruct installer-owned source, runtime, libraries, launcher, and build output. Build logs are retained until the new build succeeds.'
$repairDesc.Location = New-Object System.Drawing.Point(35, 174)
$repairDesc.Size = New-Object System.Drawing.Size(680, 48)
$repairDesc.ForeColor = [System.Drawing.Color]::DimGray
$panels[0].Controls.Add($repairDesc)

$uninstallRadio = New-Object System.Windows.Forms.RadioButton
$uninstallRadio.Text = 'Uninstall'
$uninstallRadio.Location = New-Object System.Drawing.Point(10, 235)
$uninstallRadio.Size = New-Object System.Drawing.Size(200, 28)
$panels[0].Controls.Add($uninstallRadio)

$uninstallDesc = New-Object System.Windows.Forms.Label
$uninstallDesc.Text = 'Remove only installer-owned files after verifying the installation marker. Unmanaged files in the selected folder are not deleted.'
$uninstallDesc.Location = New-Object System.Drawing.Point(35, 264)
$uninstallDesc.Size = New-Object System.Drawing.Size(680, 48)
$uninstallDesc.ForeColor = [System.Drawing.Color]::DimGray
$panels[0].Controls.Add($uninstallDesc)

# Page 2: folder
$p2Title = New-Object System.Windows.Forms.Label
$p2Title.Text = 'Choose installation directory'
$p2Title.Location = New-Object System.Drawing.Point(0, 8)
$p2Title.Size = New-Object System.Drawing.Size(700, 30)
$p2Title.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 14)
$panels[1].Controls.Add($p2Title)

$p2Desc = New-Object System.Windows.Forms.Label
$p2Desc.Text = 'Source, private runtime, Haxelib packages, build output, logs, and launcher are kept inside this folder.'
$p2Desc.Location = New-Object System.Drawing.Point(0, 48)
$p2Desc.Size = New-Object System.Drawing.Size(700, 45)
$panels[1].Controls.Add($p2Desc)

$pathBox = New-Object System.Windows.Forms.TextBox
$pathBox.Location = New-Object System.Drawing.Point(0, 110)
$pathBox.Size = New-Object System.Drawing.Size(610, 28)
$pathBox.Text = $script:DefaultInstallDir
$panels[1].Controls.Add($pathBox)

$browseButton = New-Object System.Windows.Forms.Button
$browseButton.Text = 'Browse...'
$browseButton.Location = New-Object System.Drawing.Point(620, 107)
$browseButton.Size = New-Object System.Drawing.Size(105, 32)
$panels[1].Controls.Add($browseButton)

$p2Note = New-Object System.Windows.Forms.Label
$p2Note.Text = "Default: $($script:DefaultInstallDir)`nNo administrator rights or permanent PATH changes are required."
$p2Note.Location = New-Object System.Drawing.Point(0, 160)
$p2Note.Size = New-Object System.Drawing.Size(720, 70)
$p2Note.ForeColor = [System.Drawing.Color]::DimGray
$panels[1].Controls.Add($p2Note)

# Page 3: runtime
$p3Title = New-Object System.Windows.Forms.Label
$p3Title.Text = 'Private Haxe runtime'
$p3Title.Location = New-Object System.Drawing.Point(0, 8)
$p3Title.Size = New-Object System.Drawing.Size(700, 30)
$p3Title.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 14)
$panels[2].Controls.Add($p3Title)

$runtimeStatus = New-Object System.Windows.Forms.Label
$runtimeStatus.Location = New-Object System.Drawing.Point(0, 58)
$runtimeStatus.Size = New-Object System.Drawing.Size(720, 80)
$runtimeStatus.Text = 'Setup will verify Haxe 4.0.5 and Neko 2.3.0 inside the installation root.'
$panels[2].Controls.Add($runtimeStatus)

$runtimeButton = New-Object System.Windows.Forms.Button
$runtimeButton.Text = 'Install / Verify Runtime'
$runtimeButton.Location = New-Object System.Drawing.Point(0, 150)
$runtimeButton.Size = New-Object System.Drawing.Size(220, 36)
$panels[2].Controls.Add($runtimeButton)

$runtimeNote = New-Object System.Windows.Forms.Label
$runtimeNote.Text = 'Uses official HaxeFoundation GitHub release ZIPs. These 2019 assets do not publish upstream SHA-256 digests, so setup validates HTTPS, exact release-asset size, executable version, and expected project metadata.'
$runtimeNote.Location = New-Object System.Drawing.Point(0, 205)
$runtimeNote.Size = New-Object System.Drawing.Size(710, 85)
$runtimeNote.ForeColor = [System.Drawing.Color]::DimGray
$panels[2].Controls.Add($runtimeNote)

# Page 4: dependencies/build or uninstall
$p4Title = New-Object System.Windows.Forms.Label
$p4Title.Text = 'Install libraries and build'
$p4Title.Location = New-Object System.Drawing.Point(0, 8)
$p4Title.Size = New-Object System.Drawing.Size(700, 30)
$p4Title.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 14)
$panels[3].Controls.Add($p4Title)

$p4Desc = New-Object System.Windows.Forms.Label
$p4Desc.Location = New-Object System.Drawing.Point(0, 53)
$p4Desc.Size = New-Object System.Drawing.Size(715, 105)
$p4Desc.Text = "Setup will install exact Haxelib versions and build the static HTML5 release:`n`n    lime 7.3.0    openfl 8.9.0    msignal 1.2.5`n`nA terminal window will show build progress; the full log is kept under logs\build.log."
$panels[3].Controls.Add($p4Desc)

$buildButton = New-Object System.Windows.Forms.Button
$buildButton.Text = 'Install Libraries and Build'
$buildButton.Location = New-Object System.Drawing.Point(0, 180)
$buildButton.Size = New-Object System.Drawing.Size(235, 38)
$panels[3].Controls.Add($buildButton)

$buildStatus = New-Object System.Windows.Forms.Label
$buildStatus.Location = New-Object System.Drawing.Point(0, 240)
$buildStatus.Size = New-Object System.Drawing.Size(710, 70)
$buildStatus.ForeColor = [System.Drawing.Color]::DimGray
$buildStatus.Text = 'Not started.'
$panels[3].Controls.Add($buildStatus)

# Page 5: complete
$p5Title = New-Object System.Windows.Forms.Label
$p5Title.Text = 'Setup complete'
$p5Title.Location = New-Object System.Drawing.Point(0, 8)
$p5Title.Size = New-Object System.Drawing.Size(700, 30)
$p5Title.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 14)
$panels[4].Controls.Add($p5Title)

$finishText = New-Object System.Windows.Forms.Label
$finishText.Location = New-Object System.Drawing.Point(0, 58)
$finishText.Size = New-Object System.Drawing.Size(715, 110)
$panels[4].Controls.Add($finishText)

$runButton = New-Object System.Windows.Forms.Button
$runButton.Text = 'Run'
$runButton.Location = New-Object System.Drawing.Point(0, 190)
$runButton.Size = New-Object System.Drawing.Size(130, 40)
$panels[4].Controls.Add($runButton)

$exitButton = New-Object System.Windows.Forms.Button
$exitButton.Text = 'Exit'
$exitButton.Location = New-Object System.Drawing.Point(145, 190)
$exitButton.Size = New-Object System.Drawing.Size(130, 40)
$panels[4].Controls.Add($exitButton)

$script:currentPage = 0

function Refresh-Page3 {
    if ($script:Mode -eq 'Uninstall') {
        $runtimeStatus.Text = 'Runtime setup is not required for uninstall. Continue to the removal step.'
        $runtimeButton.Enabled = $false
        return
    }
    $runtimeButton.Enabled = $true
    $info = Get-LocalRuntimeInfo $script:InstallDir
    if ($info.Valid) {
        $runtimeStatus.Text = "Haxe $($info.HaxeVersion) and Neko $($info.NekoVersion) are ready inside the installation root."
    } else {
        $runtimeStatus.Text = 'The exact local Haxe/Neko runtime is not installed yet, or version verification failed. Setup will install/replace it.'
    }
}

function Refresh-Page4 {
    $script:DependenciesBuilt = $false
    if ($script:Mode -eq 'Uninstall') {
        $p4Title.Text = 'Remove installation'
        $p4Desc.Text = "Setup will remove only installer-owned paths under:`n`n    $($script:InstallDir)`n`nThe installation marker must match. Unmanaged files are left untouched."
        $buildButton.Text = 'Uninstall Now'
        $buildStatus.Text = 'Not started.'
    } else {
        $p4Title.Text = 'Install libraries and build'
        $p4Desc.Text = "Setup will verify/install the Microsoft Visual C++ 2013 x86 runtime required by haxelib.exe, then install exact Haxelib versions and build the static HTML5 release:`n`n    lime 7.3.0    openfl 8.9.0    msignal 1.2.5`n`nA UAC prompt appears only if the VC++ 2013 runtime is missing. The full build log is kept under logs\build.log."
        $buildButton.Text = 'Install Libraries and Build'
        $buildStatus.Text = 'Not started.'
    }
}

function Show-Page([int]$Index) {
    $script:currentPage = $Index
    for ($i=0; $i -lt $panels.Count; $i++) { $panels[$i].Visible = ($i -eq $Index) }
    $stepLabel.Text = "Step $($Index + 1) of 5"
    $backButton.Visible = $Index -gt 0 -and $Index -lt 4
    $nextButton.Visible = $Index -lt 4
    $cancelButton.Visible = $Index -lt 4

    if ($Index -eq 2) { Refresh-Page3 }
    if ($Index -eq 3) { Refresh-Page4 }
    if ($Index -eq 4) {
        $backButton.Visible = $false
        $nextButton.Visible = $false
        $cancelButton.Visible = $false
        if ($script:Mode -eq 'Uninstall') {
            $runButton.Visible = $false
            $finishText.Text = "Uninstall completed. Installer-owned files were removed from:`n`n$($script:InstallDir)"
        } else {
            $runButton.Visible = $true
            $finishText.Text = "TownGeneratorOS is installed and built.`n`nThe reusable launcher is:`n$((Get-InstallPaths $script:InstallDir).Launcher)`n`nRun starts Lime's local HTML5 server and opens the application in your default browser."
        }
    }
}

$browseButton.Add_Click({
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description = 'Choose the TownGeneratorOS installation directory'
    $dlg.SelectedPath = $pathBox.Text
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { $pathBox.Text = $dlg.SelectedPath }
})

$runtimeButton.Add_Click({
    if ($script:Mode -eq 'Uninstall') { return }
    try {
        $runtimeButton.Enabled = $false
        $runtimeStatus.Text = 'Downloading and verifying the private Haxe/Neko runtime...'
        [System.Windows.Forms.Application]::DoEvents()
        $info = Ensure-LocalRuntime $script:InstallDir
        $runtimeStatus.Text = "Haxe $($info.HaxeVersion) and Neko $($info.NekoVersion) are ready inside the installation root."
    } catch {
        Show-Error $_.Exception.Message
        Refresh-Page3
    } finally {
        $runtimeButton.Enabled = $true
    }
})

$buildButton.Add_Click({
    try {
        $buildButton.Enabled = $false
        if ($script:Mode -eq 'Uninstall') {
            $buildStatus.Text = 'Removing installer-owned files...'
            [System.Windows.Forms.Application]::DoEvents()
            Invoke-Uninstall $script:InstallDir
            $buildStatus.Text = 'Uninstall completed.'
            $script:DependenciesBuilt = $true
        } else {
            Ensure-LocalRuntime $script:InstallDir | Out-Null
            $buildStatus.Text = 'Checking VC++ 2013 x86 runtime, then installing Haxelib packages and building HTML5 release...'
            [System.Windows.Forms.Application]::DoEvents()
            Run-DependencyBuild $script:InstallDir
            Write-Launcher $script:InstallDir | Out-Null
            Write-InstallMarker $script:InstallDir
            $buildStatus.Text = 'Libraries installed and HTML5 release built successfully.'
            $script:DependenciesBuilt = $true
        }
    } catch {
        $buildStatus.Text = 'Action failed.'
        Show-Error $_.Exception.Message
    } finally {
        $buildButton.Enabled = $true
    }
})

$backButton.Add_Click({
    if ($script:currentPage -gt 0) { Show-Page ($script:currentPage - 1) }
})

$nextButton.Add_Click({
    try {
        switch ($script:currentPage) {
            0 {
                if ($repairRadio.Checked) { $script:Mode = 'Repair' }
                elseif ($uninstallRadio.Checked) { $script:Mode = 'Uninstall' }
                else { $script:Mode = 'Install' }
                Show-Page 1
            }
            1 {
                $script:InstallDir = Normalize-Path $pathBox.Text
                $pathBox.Text = $script:InstallDir
                if ($script:Mode -eq 'Install') {
                    Prepare-Install $script:InstallDir $false
                } elseif ($script:Mode -eq 'Repair') {
                    Prepare-Install $script:InstallDir $true
                } else {
                    Assert-RecognizedInstall $script:InstallDir
                }
                Show-Page 2
            }
            2 {
                if ($script:Mode -ne 'Uninstall') { Ensure-LocalRuntime $script:InstallDir | Out-Null }
                Show-Page 3
            }
            3 {
                if (-not $script:DependenciesBuilt) {
                    if ($script:Mode -eq 'Uninstall') {
                        Invoke-Uninstall $script:InstallDir
                    } else {
                        Run-DependencyBuild $script:InstallDir
                        Write-Launcher $script:InstallDir | Out-Null
                        Write-InstallMarker $script:InstallDir
                    }
                    $script:DependenciesBuilt = $true
                }
                Show-Page 4
            }
        }
    } catch {
        Show-Error $_.Exception.Message
    }
})

$cancelButton.Add_Click({ $form.Close() })

$runButton.Add_Click({
    try {
        Start-App $script:InstallDir
        $form.Close()
    } catch {
        Show-Error $_.Exception.Message
    }
})

$exitButton.Add_Click({ $form.Close() })

Show-Page 0
[void]$form.ShowDialog()
