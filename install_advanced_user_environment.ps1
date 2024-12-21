# .NOTES
# A script to automatically install or update a typical advanced users software environment.
# https://github.com/maksimaliabyshev
# Version 1.1 by Maksim Aliabyshev

param(
    [string]$theme = "powerlevel10k_rainbow",
    [string[]]$fonts = @(),
    [string[]]$scripts = @(),
    [string[]]$modulesNoImport = @(),
    [string[]]$modules = @(),
    [string[]]$resourceOnlyCore = @(),
    [string]$ProfilePath,
    [string]$shell
)

##### START ELEVATE TO ADMIN #####
if (-not [string]::IsNullOrEmpty($PSBoundParameters)) {
    $params = ($PSBoundParameters.GetEnumerator() | ForEach-Object { "-$($_.Key) $($_.Value -split ' ' -join ',')" }) -join ' '
}
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
    if ([int](Get-CimInstance -Class Win32_OperatingSystem | Select-Object -ExpandProperty BuildNumber) -ge 6000) {
        Start-Process powershell -Verb RunAs -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -NonInteractive -NoExit -File `"$($MyInvocation.MyCommand.Definition)`" $params")
        Exit $LASTEXITCODE
    }
}
Set-Location (Split-Path -Parent $MyInvocation.MyCommand.Definition)
##### END ELEVATE TO ADMIN #####


#####  Init  #####
$fonts = @("JetBrainsMono", "Meslo") + ($fonts -split "[\s\,]+")
$scripts = @("Invoke-Obliteration") + ($scripts -split "[\s\,]+")
$modulesNoImport = @("PackageManagement", "psedit", "PSScriptAnalyzer", "Posh-SSH", "PSScriptTools", "FindOpenFile", "CodeConversion") + ($modulesNoImport -split "[\s\,]+")
$modules = @("Posh", "posh-git", "Terminal-Icons", "scoop-completion", "plinqo", "CompletionPredictor") + ($modules -split "[\s\,]+")

$resourceOnlyCore = @("CompletionPredictor") + ($resourceOnlyCore -split "[\s\,]+")
$textToProfile = @{
    # ModuleName1           = "One Line Text"
    # ModuleName2           = "Multiline`r`nText"
    # ModuleName3           = "remove"  #remove module
    # 'Invoke-Obliteration' = "remove"  #remove script
    # 'Posh-SSH'            = "remove"  #remove moduleNoImport
    CompletionPredictor = "Import-Module -Name CompletionPredictor`r`nSet-PSReadLineOption -PredictionSource HistoryAndPlugin"
}
$searchPatternInProfile = @{
    # ModuleName1       = "One Line*"
    # ModuleName2       = "Multi*`r`n*Any T??t*"
    # ModuleName3       = "*ModuleName3*`r`n*Any configuration text...*"  #delete the rows of the removed module
    CompletionPredictor = "*CompletionPredictor*`r`n*HistoryAndPlugin*"
}

Write-Host "Theme: " -NoNewline; Write-Host $theme -ForegroundColor Magenta
Write-Host "Fonts: " -NoNewline; Write-Host $fonts -ForegroundColor Magenta
Write-Host "Scripts: " -NoNewline; Write-Host $scripts -ForegroundColor Magenta
Write-Host "ModulesNoImport: " -NoNewline; Write-Host "$modulesNoImport" -ForegroundColor Magenta
Write-Host "Modules: " -NoNewline; Write-Host "$modules" -ForegroundColor Magenta

$env:Path = [Environment]::GetEnvironmentVariable("PATH", [EnvironmentVariableTarget]::Machine)

function Write-HostCenter {
    param($Message)
    Write-Host ("{0}{1}" -f (' ' * (([Math]::Max(0, $Host.UI.RawUI.BufferSize.Width / 2) - [Math]::Floor($Message.Length / 2)))), $Message) @args
}

function Update-ContentFile {
    param (
        [Parameter(Mandatory = $true)][String]$Path,
        [AllowEmptyString()]$Text = @(""),
        [AllowEmptyString()]$SearchPattern = @(""),
        [AllowEmptyString()]$FindedLines = @(),
        [AllowEmptyString()]$FileContent = @()
    )

    $Text = ($Text -split '\r?\n').Trim().Split([Environment]::NewLine, [Stringsplitoptions]::RemoveEmptyEntries) #| ForEach-Object { $_.Trim() }
    $SearchPattern = ($SearchPattern -split '\r?\n').Trim().Split([Environment]::NewLine, [Stringsplitoptions]::RemoveEmptyEntries)

    if (!(Test-Path $Path)) {
        New-Item -Path $Path -ItemType File -Force
        Write-Host "`nPowerShell profile created: " -ForegroundColor DarkGreen -NoNewline; Write-Host $Path -ForegroundColor Yellow
    }

    foreach ($line in (Get-Content -Path $Path)) {
        $Text + $SearchPattern | ForEach-Object {
            if ($line -like $_.Trim()) {
                if (![string]::IsNullOrWhiteSpace($line)) {
                    $FindedLines += $line
                }
                continue
            }
        }
        $FileContent += $line
    }
    $diffCompareLines = Compare-Object -ReferenceObject $Text -DifferenceObject $FindedLines;

    # add text
    if ($Text -and !$FindedLines) {
        Add-Content -Path $Path -Value $Text
        Write-Host "ADDED to Profile: " -NoNewline; Write-Host $Path -ForegroundColor Yellow
        Write-Host ($Text -join [environment]::NewLine) -ForegroundColor DarkGreen
        return
    }
    # update text
    if ($Text -and $diffCompareLines) {
        Set-Content -Path $Path -Value $FileContent, $Text
        Write-Host "UPDATED Profile: " -NoNewline; Write-Host $Path -ForegroundColor Yellow
        Write-Host ($Text -join [environment]::NewLine) -ForegroundColor DarkGreen
        return
    }
    # remove text
    if (!$Text -and $FindedLines) {
        Set-Content -Path $Path -Value $FileContent
        Write-Host "REMOVED from Profile: " -NoNewline; Write-Host $Path -ForegroundColor Yellow
        Write-Host ($FindedLines -join [environment]::NewLine) -ForegroundColor DarkRed
        return
    }
}

#set target profile, default PowerShell Core, for PowerShell use argument '-Shell powershell'
if ($ProfilePath) {
    if (!(Test-Path -Path $ProfilePath)) {
        $directoryPath = Split-Path -Path $ProfilePath
        if (!(Test-Path -Path $directoryPath)) {
            Write-Host "!!!   Не существует дирректории `"$directoryPath`" для создания файла профиля   !!!" -ForegroundColor White -BackgroundColor Red
            Start-Sleep -Seconds 5
            Exit
        }
        New-Item -ItemType File -Path $ProfilePath -Force
    }

    if ($shell -like '*powershell*') {
        $powershellStatus = $true
        $powershellProfile = $ProfilePath
        Write-Host "[argument] PowerShell profile: " -NoNewline
        Write-Host $powershellProfile -ForegroundColor Yellow
    }
    else {
        $pwshStatus = $true
        $pwshProfile = $ProfilePath
        Write-Host "[argument] PowerShell Core profile: " -NoNewline
        Write-Host $pwshProfile -ForegroundColor Yellow
    }
}

(Remove-Item alias:\where -Force) 2>$null
Register-PSRepository -Default -InstallationPolicy Trusted -ErrorAction Ignore
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12


#####  Install winget  #####
Write-Host; Write-HostCenter "Installing package manager WinGet..." -ForegroundColor Cyan

if (-not (Get-PackageProvider -Name NuGet) -or (Get-PackageProvider -Name NuGet).version -lt 2.8.5.201 ) {
    try {
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Confirm:$False -Force
    }
    catch {
        Write-Error -Message $_.Exception
    }
}

try {
    winget --version
}
catch {
    # Install VC++ x64 executable
    Invoke-WebRequest -Uri https://aka.ms/vs/16/release/vc_redist.x64.exe -OutFile $env:TEMP\vc_redist.x64.exe
    Start-Process $env:TEMP\vc_redist.x64.exe /S -NoNewWindow -Wait -PassThru

    # Install Microsoft.UI.Xaml from NuGet
    Invoke-WebRequest -Uri https://www.nuget.org/api/v2/package/Microsoft.UI.Xaml/2.8.6 -OutFile $env:TEMP\microsoft.ui.xaml.2.8.6.zip
    Expand-Archive -Path $env:TEMP\microsoft.ui.xaml.2.8.6.zip -DestinationPath $env:TEMP\microsoft.ui.xaml -Force
    Add-AppxPackage $env:TEMP\microsoft.ui.xaml\tools\AppX\x64\Release\Microsoft.UI.Xaml.2.8.appx

    # Install the latest release of Microsoft.DesktopInstaller from GitHub
    Invoke-WebRequest -Uri https://github.com/microsoft/winget-cli/releases/latest/download/Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle -OutFile $env:TEMP\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle
    Add-AppxPackage $env:TEMP\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle

    $ResolveWingetPath = Resolve-Path -Path "$env:PROGRAMFILES\WindowsApps\Microsoft.DesktopAppInstaller_*x64__8wekyb3d8bbwe"
    if ($ResolveWingetPath -and ($env:Path -split ';') -notcontains "$($ResolveWingetPath[-1].Path)") {
        $env:PATH += ";$($ResolveWingetPath[-1].Path)"
        [Environment]::SetEnvironmentVariable("PATH", $env:PATH, [EnvironmentVariableTarget]::Machine)
    }
}


#####  Install Powershell Core  #####
Write-Host; Write-HostCenter "Installing PowerShell Core..." -ForegroundColor Cyan
winget install --id=Microsoft.Powershell --silent --disable-interactivity --accept-source-agreements --accept-package-agreements
if (($env:Path -split ';') -notcontains "$env:PROGRAMFILES\PowerShell\7") {
    $env:PATH += ";$env:PROGRAMFILES\PowerShell\7"
    [Environment]::SetEnvironmentVariable("PATH", $env:PATH, [EnvironmentVariableTarget]::Machine)
}

#detect PowerShell
if ((Get-Command -Name powershell -ErrorAction SilentlyContinue) -and !$ProfilePath) {
    $powershellStatus = $true
    $powershellProfileAllUsersAllHosts = powershell -NoProfile -Command '$PROFILE.AllUsersAllHosts'
    $powershellProfile = $powershellProfileAllUsersAllHosts
    Write-Host "==============  detect PowerShell  ==============" -ForegroundColor Green -BackgroundColor Black
    Write-Host "PowerShell profile AllUsersAllHosts: " -NoNewline; Write-Host $powershellProfile -ForegroundColor Yellow
    (powershell -NoProfile -Command '$PSVersionTable')
}

#detect PowerShell Core
if ((Get-Command -Name pwsh -ErrorAction SilentlyContinue) -and !$ProfilePath) {
    $pwshStatus = $true
    $pwshProfileAllUsersAllHosts = pwsh -NoProfile -Command '$PROFILE.AllUsersAllHosts'
    $pwshProfile = $pwshProfileAllUsersAllHosts
    Write-Host "==============  detect PowerShell Core  ==============" -ForegroundColor Green -BackgroundColor Black
    Write-Host "PowerShell Core profile AllUsersAllHosts: " -NoNewline; Write-Host $pwshProfile -ForegroundColor Yellow
    (pwsh -NoProfile -Command '$PSVersionTable')
}

#install PSResourceGet
if ($powershellStatus) {
    Write-Host "PowerShell install " -ForegroundColor Cyan -NoNewline; Write-Host 'Microsoft.PowerShell.PSResourceGet' -ForegroundColor Blue
    powershell -NoProfile -Command 'Install-Module -Name PSReadLine -Scope AllUsers -AllowClobber -Force -ErrorAction SilentlyContinue'
    powershell -NoProfile -Command 'Install-Module -Name PowerShellGet -Scope AllUsers -AllowClobber -Force -ErrorAction SilentlyContinue'
    powershell -NoProfile -Command 'Install-Module -Name Microsoft.PowerShell.PSResourceGet -Scope AllUsers -AllowClobber -Force'
    if (($env:Path -split ';') -notcontains "$env:PROGRAMFILES\WindowsPowerShell\Scripts") {
        $env:PATH += ";$env:PROGRAMFILES\WindowsPowerShell\Scripts"
        [Environment]::SetEnvironmentVariable("PATH", $env:PATH, [EnvironmentVariableTarget]::Machine)
    }
}
if ($pwshStatus) {
    Write-Host "PowerShell Core install " -ForegroundColor Cyan -NoNewline; Write-Host 'Microsoft.PowerShell.PSResourceGet' -ForegroundColor Blue
    pwsh -NoProfile -Command 'Install-Module -Name PSReadLine -Scope AllUsers -AllowClobber -Force -ErrorAction SilentlyContinue'
    pwsh -NoProfile -Command 'Install-Module -Name PowerShellGet -Scope AllUsers -AllowPrerelease -AllowClobber -Force -ErrorAction SilentlyContinue'
    pwsh -NoProfile -Command 'Install-Module -Name Microsoft.PowerShell.PSResourceGet -Scope AllUsers -AllowPrerelease -AllowClobber -Force'
    if (($env:Path -split ';') -notcontains "$env:PROGRAMFILES\PowerShell\Scripts") {
        $env:PATH += ";$env:PROGRAMFILES\PowerShell\Scripts"
        [Environment]::SetEnvironmentVariable("PATH", $env:PATH, [EnvironmentVariableTarget]::Machine)
    }
}
Set-PSResourceRepository -Name PSGallery -Trusted -ErrorAction SilentlyContinue

#add context menu for files and folders
if ([Environment]::Is64BitOperatingSystem) {
    $link = "https://gist.githubusercontent.com/maksimaliabyshev/77568947ef80baf32043b3247841035c/raw/context_file_powershell_pwsh_ise.reg"
    Invoke-WebRequest -Uri "$link" -OutFile "$env:TEMP/context_file_powershell_pwsh_ise.reg"
    reg import "$env:TEMP/context_file_powershell_pwsh_ise.reg" *>$null

    $link = "https://gist.githubusercontent.com/maksimaliabyshev/77568947ef80baf32043b3247841035c/raw/context_folder_pwsh_x64.reg"
    Invoke-WebRequest -Uri "$link" -OutFile "$env:TEMP/context_folder_pwsh_x64.reg"
    reg import "$env:TEMP/context_folder_pwsh_x64.reg" *>$null
}
else {
    $link = "https://gist.githubusercontent.com/maksimaliabyshev/77568947ef80baf32043b3247841035c/raw/context_folder_pwsh_x32.reg"
    Invoke-WebRequest -Uri "$link" -OutFile "$env:TEMP/context_folder_pwsh_x32.reg"
    reg import "$env:TEMP/context_folder_pwsh_x32.reg" *>$null
}


#####  Install Microsoft Edge WebView2 Runtime  #####
Write-Host; Write-HostCenter "Installing Microsoft Edge WebView2 Runtime..." -ForegroundColor Cyan
winget install --id=Microsoft.EdgeWebView2Runtime --silent --disable-interactivity --accept-source-agreements --accept-package-agreements


#####  Install Microsoft Visual C++ 2005/2008/2010/2012/2013/2015+ Redistributable  #####
Write-Host; Write-HostCenter "Installing Microsoft Visual C++ 2005/2008/2010/2012/2013/2015+ Redistributable..." -ForegroundColor Cyan
winget install --id=Microsoft.VCRedist.2005.x86 --silent --disable-interactivity --accept-source-agreements --accept-package-agreements
winget install --id=Microsoft.VCRedist.2005.x64 --silent --disable-interactivity --accept-source-agreements --accept-package-agreements
winget install --id=Microsoft.VCRedist.2008.x86 --silent --disable-interactivity --accept-source-agreements --accept-package-agreements
winget install --id=Microsoft.VCRedist.2008.x64 --silent --disable-interactivity --accept-source-agreements --accept-package-agreements
winget install --id=Microsoft.VCRedist.2010.x86 --silent --disable-interactivity --accept-source-agreements --accept-package-agreements
winget install --id=Microsoft.VCRedist.2010.x64 --silent --disable-interactivity --accept-source-agreements --accept-package-agreements
winget install --id=Microsoft.VCRedist.2012.x86 --silent --disable-interactivity --accept-source-agreements --accept-package-agreements
winget install --id=Microsoft.VCRedist.2012.x64 --silent --disable-interactivity --accept-source-agreements --accept-package-agreements
winget install --id=Microsoft.VCRedist.2013.x86 --silent --disable-interactivity --accept-source-agreements --accept-package-agreements
winget install --id=Microsoft.VCRedist.2013.x64 --silent --disable-interactivity --accept-source-agreements --accept-package-agreements
winget install --id=Microsoft.VCLibs.Desktop.14 --silent --disable-interactivity --accept-source-agreements --accept-package-agreements
winget install --id=Microsoft.VCRedist.2015+.x86 --silent --disable-interactivity --accept-source-agreements --accept-package-agreements
winget install --id=Microsoft.VCRedist.2015+.x64 --silent --disable-interactivity --accept-source-agreements --accept-package-agreements


#####  Install Microsoft Visual Studio BuildTools  #####
#Write-Host; Write-HostCenter "Installing Microsoft VisualStudio 2022 BuildTools..." -ForegroundColor Cyan
#winget install --id=Microsoft.VisualStudio.2022.BuildTools --silent --disable-interactivity --accept-source-agreements --accept-package-agreements
# Individual Components: Windows SDK, C++ x64/x86 build tools
#Start-Process "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vs_installer.exe" -Wait -PassThru -ArgumentList `
#'modify --installPath "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\BuildTools" --passive --norestart --nocache --downloadThenInstall --includeRecommended --includeOptional --force',
#'--add Microsoft.VisualStudio.Component.NuGet.BuildTools',
#'--add Microsoft.VisualStudio.Workload.VCTools',
#'--add Microsoft.VisualStudio.Workload.MSBuildTools'


#####  Install Microsoft .NET Desktop 3.1/5/6/7/8/Preview  #####
Write-Host; Write-HostCenter "Installing Microsoft .NET Desktop 3.1/5/6/7/8/Preview..." -ForegroundColor Cyan
winget install --id=Microsoft.dotnetRuntime.3-x86 --silent --disable-interactivity --accept-source-agreements --accept-package-agreements
winget install --id=Microsoft.DotNet.DesktopRuntime.3_1 --silent --disable-interactivity --accept-source-agreements --accept-package-agreements
winget install --id=Microsoft.dotnetRuntime.5-x86 --silent --disable-interactivity --accept-source-agreements --accept-package-agreements
winget install --id=Microsoft.DotNet.DesktopRuntime.5 --silent --disable-interactivity --accept-source-agreements --accept-package-agreements
winget install --id=Microsoft.dotnetRuntime.6-x86 --silent --disable-interactivity --accept-source-agreements --accept-package-agreements
winget install --id=Microsoft.DotNet.DesktopRuntime.6 --silent --disable-interactivity --accept-source-agreements --accept-package-agreements
winget install --id=Microsoft.DotNet.DesktopRuntime.7 --silent --disable-interactivity --accept-source-agreements --accept-package-agreements
winget install --id=Microsoft.DotNet.DesktopRuntime.8 --silent --disable-interactivity --accept-source-agreements --accept-package-agreements
winget install --id=Microsoft.DotNet.DesktopRuntime.Preview --silent --disable-interactivity --accept-source-agreements --accept-package-agreements


#####  Microsoft .NET Framework 2/3/4.5/4@latest  #####
Write-Host; Write-HostCenter "Installing Microsoft .NET Framework 2/3..." -ForegroundColor Cyan
# winget install --id=Microsoft.DotNet.Framework.DeveloperPack.4.5 --silent --disable-interactivity --accept-source-agreements --accept-package-agreements
# winget install --id=Microsoft.DotNet.Framework.DeveloperPack_4 --silent --disable-interactivity --accept-source-agreements --accept-package-agreements
!(Get-WindowsCapability -Online -Name "NetFx3").State -eq "Installed" -and (Enable-WindowsOptionalFeature -Online -FeatureName "NetFx3") >$null


#####  Microsoft ASP.NET Core 2/3/5/6/7/8/Preview  #####
#Write-Host; Write-HostCenter "Installing Microsoft ASP.NET Core 2/3/5/6/7/8/Preview..." -ForegroundColor Cyan
#winget install --id=Microsoft.DotNet.AspNetCore.2_1 --silent --disable-interactivity --accept-source-agreements --accept-package-agreements
#winget install --id=Microsoft.DotNet.AspNetCore.3_1 --silent --disable-interactivity --accept-source-agreements --accept-package-agreements
#winget install --id=Microsoft.DotNet.AspNetCore.5 --silent --disable-interactivity --accept-source-agreements --accept-package-agreements
#winget install --id=Microsoft.DotNet.AspNetCore.6 --silent --disable-interactivity --accept-source-agreements --accept-package-agreements
#winget install --id=Microsoft.DotNet.AspNetCore.7 --silent --disable-interactivity --accept-source-agreements --accept-package-agreements
#winget install --id=Microsoft.DotNet.AspNetCore.8 --silent --disable-interactivity --accept-source-agreements --accept-package-agreements
#winget install --id=Microsoft.DotNet.AspNetCore.Preview --silent --disable-interactivity --accept-source-agreements --accept-package-agreements


#####  Install DirectX Web Installer  #####
#Write-Host; Write-HostCenter "Installing Microsoft DirectX End-User Runtime Web Installer..." -ForegroundColor Cyan
#winget install --id=Microsoft.DirectX --silent --disable-interactivity --accept-source-agreements --accept-package-agreements >$null


#####  Install Java Runtime Environment  #####
# Write-Host; Write-HostCenter "Installing Java Runtime Environment..." -ForegroundColor Cyan
# winget install --id=Amazon.Corretto.8.JRE --silent --disable-interactivity --accept-source-agreements --accept-package-agreements
# winget install --id=EclipseAdoptium.Temurin.8.JRE --silent --disable-interactivity --accept-source-agreements --accept-package-agreements
# winget install --id=EclipseAdoptium.Temurin.23.JRE --silent --disable-interactivity --accept-source-agreements --accept-package-agreements


#####  Install Java Software Development Kit  #####
Write-Host; Write-HostCenter "Installing Java Software Development Kit..." -ForegroundColor Cyan
# winget install --id=Amazon.Corretto.8.JDK --silent --disable-interactivity --accept-source-agreements --accept-package-agreements
# winget install --id=Amazon.Corretto.23.JDK --silent --disable-interactivity --accept-source-agreements --accept-package-agreements
# winget install --id=EclipseAdoptium.Temurin.8.JDK --silent --disable-interactivity --accept-source-agreements --accept-package-agreements
winget install --id=EclipseAdoptium.Temurin.17.JDK --silent --disable-interactivity --accept-source-agreements --accept-package-agreements
# winget install --id=EclipseAdoptium.Temurin.23.JDK --silent --disable-interactivity --accept-source-agreements --accept-package-agreements


#####  Install WinFsp  #####
Write-Host; Write-HostCenter "Installing WinFsp - supports Windows native, FUSE, .NET and Cygwin file systems..." -ForegroundColor Cyan
winget install --id=WinFsp.WinFsp --silent --disable-interactivity --accept-source-agreements --accept-package-agreements


#####  Install Scoop   #####
Write-Host; Write-HostCenter "Installing package manager Scoop..." -ForegroundColor Cyan
$env:SCOOP = "$env:PROGRAMDATA\Scoop"
[Environment]::SetEnvironmentVariable('SCOOP', $env:SCOOP, [EnvironmentVariableTarget]::Machine)
[Environment]::SetEnvironmentVariable('SCOOP', $env:SCOOP, [EnvironmentVariableTarget]::User)
if (Test-Path -Path "$env:SCOOP\shims\scoop.ps1") {
    scoop update
}
else {
    Invoke-Expression "& {$(Invoke-RestMethod get.scoop.sh)} -RunAsAdmin"
}
# scoop cleanup *
scoop bucket add extras
scoop install main/scoop-search --global
scoop install innounp --global

#####  Install Git   #####
Write-Host; Write-HostCenter "Installing Git..." -ForegroundColor Cyan
scoop install git --global


#####  Install curl, wget   #####
scoop install curl --global
scoop install wget --global
scoop install aria2 --global

#####  Install Clink for cmd.exe  #####
Write-Host; Write-HostCenter "Installing Clink autocomplit tool for cmd.exe" -ForegroundColor Cyan
scoop install clink --global
cmd.exe /c "clink autorun install -a"


#####  Install NodeJS  #####
Write-Host; Write-HostCenter "Installing NodeJS..." -ForegroundColor Cyan
scoop install nodejs --global


#####  Install Python  #####
Write-Host; Write-HostCenter "Installing Python..." -ForegroundColor Cyan
scoop install python --global


#####  Install PHP  #####
Write-Host; Write-HostCenter "Installing PHP..." -ForegroundColor Cyan
scoop install php --global


#####  Install MinGW  #####
Write-Host; Write-HostCenter "Installing WinLibs standalone build of GCC and MinGW-w64 for Windows" -ForegroundColor Cyan
scoop install mingw-winlibs --global


#####  Install WinFetch  #####
Write-Host; Write-HostCenter "Installing WinFetch..." -ForegroundColor Cyan
scoop install winfetch --global


#####  Install Zoxide  #####
Write-Host; Write-HostCenter "Installing Zoxide..." -ForegroundColor Cyan
# winget install ajeetdsouza.zoxide --silent --disable-interactivity --accept-source-agreements --accept-package-agreements
scoop install zoxide --global


#####  Install micro editor #####
Write-Host; Write-HostCenter "Installing micro..." -ForegroundColor Cyan
scoop install micro --global
micro -plugin install fish lsp go autofmt snippets detectindent zigfmt runit editorconfig manipulator joinLines filemanager `
    palettero quoter pony crystal bounce cheat aspell bookmark jlabbrev gotham-colors fzf misspell wc quickfix jump

#####  Install Pragtical Editor  #####
# if ([Environment]::Is64BitOperatingSystem) {
#     Write-Host; Write-HostCenter "Installing Pragtical Editor..." -ForegroundColor Cyan
#     scoop install pragtical --global
#     if (($env:PATH -split ';') -notcontains "$env:PROGRAMDATA\scoop\apps\pragtical\current") {
#         $env:PATH += ";$env:PROGRAMDATA\scoop\apps\pragtical\current"
#         [Environment]::SetEnvironmentVariable("PATH", $env:PATH, [EnvironmentVariableTarget]::Machine)
#     }
#     scoop shim add p 'pragtical' --global
#     scoop shim add powershellconf 'pragtical' `"$(powershell -NoProfile -Command '$PROFILE.AllUsersAllHosts')`" --global
#     scoop shim add pwshconf 'pragtical' `"$(pwsh -NoProfile -Command '$PROFILE.AllUsersAllHosts')`" --global

#     scoop install https://gist.githubusercontent.com/maksimaliabyshev/6b311f327078022dd365eea96f2428e8/raw/pragtical-plugin-manager.json --global
#     $datadir = "$([Environment]::GetFolderPath('CommonApplicationData'))\scoop\apps\pragtical\current\data"
#     ppm purge --force
#     ppm install language* --assume-yes --progress --datadir=$datadir
#     ppm color install * --assume-yes --progress --datadir=$datadir
#     ppm install font_symbols_nerdfont_mono_regular nerdicons --assume-yes --progress --datadir=$datadir
#     ppm install lsp lsp_snippets snippets --assume-yes --progress --datadir=$datadir

#     ppm install align_carets autoinsert autowrap bracketmatch codeplus colorpicker colorpreview console copyfilelocation custom_caret `
#         datetimestamps editorconfig endwise eofnewline ephemeral_tabs eval evergreen exec extend_selection_line exterm force_syntax formatter `
#         gitblame gitdiff_highlight gitopen gitstatus gui_filepicker indent_convert indentguide json jsonmod `
#         keymap_export linenumbers link_opener lintplus lorem markers minimap motiontrail navigate openfilelocation openselected `
#         profiler rainbowparen recentfiles regexreplacepreview restoretabs `
#         scalestatus selectionhighlight smartopenselected smoothcaret sort sortcss spellcheck sticky_scroll su_save svg_screenshot `
#         tab_switcher tabnumbers terminal texcompile titleize togglesnakecamel treeview-extender typingspeed wordcount `
#         --assume-yes --progress --datadir=$datadir

#     ppm upgrade --assume-yes --datadir=$datadir
# }


#####  Install oh-my-posh  #####
Write-Host; Write-HostCenter "Installing oh-my-posh..." -ForegroundColor Cyan
$env:POSH_THEMES_PATH = "$env:PROGRAMDATA\Scoop\apps\oh-my-posh\current\themes"
[Environment]::SetEnvironmentVariable('POSH_THEMES_PATH', $env:POSH_THEMES_PATH, [EnvironmentVariableTarget]::Machine)
[Environment]::SetEnvironmentVariable('POSH_THEMES_PATH', $env:POSH_THEMES_PATH, [EnvironmentVariableTarget]::User)
scoop install 'oh-my-posh' --global

#oh-my-posh configuration
if ($powershellStatus) {
    $poshLine = "oh-my-posh init powershell --config `"$env:POSH_THEMES_PATH\$($theme).omp.json`" | Invoke-Expression"
    Update-ContentFile -Path $powershellProfile -Text $poshLine -SearchPattern "oh-my-posh init *"
}
if ($pwshStatus) {
    $poshLine = "oh-my-posh init pwsh --config `"$env:POSH_THEMES_PATH\$($theme).omp.json`" | Invoke-Expression"
    Update-ContentFile -Path $pwshProfile -Text $poshLine -SearchPattern "oh-my-posh init *"
}


#####  Powershell Enhancement  #####
#disable restricted PowerShell language mode
# Remove-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment' __PSLockdownPolicy 2>$null

Write-Host "`nInstalling scripts: " -ForegroundColor Cyan -NoNewline; Write-Host "$scripts" -ForegroundColor Blue
foreach ($scriptName in $scripts) {

    if ($pwshStatus) {
        if ($textToProfile[$scriptName] -eq 'remove') {
            Write-Host "`nRemove script in PowerShell Core: $scriptName" -ForegroundColor White -BackgroundColor DarkRed
            pwsh -NoProfile -Command "Remove-Module -Name $scriptName -Force -ErrorAction SilentlyContinue"
        }
        else {
            Write-Host "`nInstall script in PowerShell Core: $scriptName" -ForegroundColor White -BackgroundColor Magenta
            pwsh -NoProfile -Command "Install-PSResource -Name $scriptName -Scope AllUsers -Prerelease -AcceptLicense -Reinstall -ErrorAction SilentlyContinue"
        }
    }

    if ($resourceOnlyCore -contains $scriptName) { continue }

    if ($powershellStatus) {
        if ($textToProfile[$scriptName] -eq 'remove') {
            Write-Host "`nRemove script in PowerShell: $scriptName" -ForegroundColor White -BackgroundColor DarkRed
            powershell -NoProfile -Command "Remove-Module -Name $scriptName -Force -ErrorAction SilentlyContinue"
        }
        else {
            Write-Host "`nInstall script in PowerShell: $scriptName" -ForegroundColor White -BackgroundColor Magenta
            powershell -NoProfile -Command "Install-PSResource -Name $scriptName -Scope AllUsers -Prerelease -AcceptLicense -Reinstall -ErrorAction SilentlyContinue"
        }
    }
}

Write-Host "`nInstalling modules: " -ForegroundColor Cyan -NoNewline; Write-Host "$modulesNoImport" -ForegroundColor Blue
foreach ($moduleName in $modulesNoImport) {

    if ($pwshStatus) {
        if ($textToProfile[$moduleName] -eq 'remove') {
            Write-Host "`nRemove module in PowerShell:  $moduleName" -ForegroundColor White -BackgroundColor DarkRed
            pwsh -NoProfile -Command "Remove-Module -Name $moduleName -Force -ErrorAction SilentlyContinue"
        }
        else {
            Write-Host "`nInstall module in PowerShell Core:  $moduleName" -ForegroundColor White -BackgroundColor Magenta
            pwsh -NoProfile -Command "Install-PSResource -Name $moduleName -Scope AllUsers -Prerelease -AcceptLicense -Reinstall -ErrorAction SilentlyContinue"
        }
    }

    if ($resourceOnlyCore -contains $moduleName) { continue }

    if ($powershellStatus) {
        if ($textToProfile[$moduleName] -eq 'remove') {
            Write-Host "`nRemove module in PowerShell:  $moduleName" -ForegroundColor White -BackgroundColor DarkRed
            powershell -NoProfile -Command "Remove-Module -Name $moduleName -Force -ErrorAction SilentlyContinue"
        }
        else {
            Write-Host "`nInstall module in PowerShell:  $moduleName" -ForegroundColor White -BackgroundColor Magenta
            powershell -NoProfile -Command "Install-PSResource -Name $moduleName -Scope AllUsers -AcceptLicense -Reinstall -ErrorAction SilentlyContinue"
        }
    }
}

Write-Host "`nInstalling modules with import to Profile: " -ForegroundColor Cyan -NoNewline; Write-Host "$modules" -ForegroundColor Blue
foreach ($moduleName in $modules) {

    $moduleText = "Import-Module -Name $moduleName"
    if ($moduleName -in $textToProfile.Keys) {
        $moduleText = $textToProfile[$moduleName]
    }
    if ($moduleName -in $searchPatternInProfile.Keys) {
        $SearchPattern = $searchPatternInProfile[$moduleName]
    }

    if ($pwshStatus) {
        if ($moduleText -eq 'remove') {
            Write-Host "`nRemove module in PowerShell Core:  $moduleName" -ForegroundColor White -BackgroundColor DarkRed
            pwsh -NoProfile -Command "Remove-Module -Name $moduleName -Force -ErrorAction SilentlyContinue"
            $moduleText = $null
        }
        else {
            Write-Host "`nInstall module in PowerShell Core: $moduleName" -ForegroundColor White -BackgroundColor Magenta
            pwsh -NoProfile -Command "Install-PSResource -Name $moduleName -Scope AllUsers -Prerelease -AcceptLicense -Reinstall -ErrorAction SilentlyContinue"
        }
        Update-ContentFile -Path $pwshProfile -Text $moduleText -SearchPattern $SearchPattern
    }

    if ($resourceOnlyCore -contains $moduleName) { continue }

    if ($powershellStatus) {
        if ($moduleText -eq 'remove') {
            Write-Host "`nRemove module in PowerShell:  $moduleName" -ForegroundColor White -BackgroundColor DarkRed
            powershell -NoProfile -Command "Remove-Module -Name $moduleName -Force -ErrorAction SilentlyContinue"
        }
        else {
            Write-Host "`nInstall module in PowerShell: $moduleName" -ForegroundColor White -BackgroundColor Magenta
            powershell -NoProfile -Command "Install-PSResource -Name $moduleName -Scope AllUsers -AcceptLicense -Reinstall -ErrorAction SilentlyContinue"
        }
        Update-ContentFile -Path $powershellProfile -Text $moduleText -SearchPattern $SearchPattern
    }
}

# $fixRussianKeyboardCopyPaste = @"
# Set-PSReadLineKeyHandler -Chord Ctrl+м -ScriptBlock {
#     [Microsoft.PowerShell.PSConsoleReadLine]::Paste()
# }

# Set-PSReadLineKeyHandler -Chord Ctrl+с -ScriptBlock {
#     [Microsoft.PowerShell.PSConsoleReadLine]::Copy()
# }

# Set-PSReadLineKeyHandler -Chord Ctrl+ч -ScriptBlock {
#     [Microsoft.PowerShell.PSConsoleReadLine]::Cut()
# }
# "@

$fixWhereLine = '(Remove-Item alias:\where -Force) 2>$null'
$zoxideLine = 'Invoke-Expression (& { (zoxide init powershell | Out-String) })'

if ($powershellStatus) {
    #fix CTRL+C, CTRL+V, CTRL+X for Russian keyboard layout
    # Update-ContentFile -Path $powershellProfile -Text $fixRussianKeyboardCopyPaste -SearchPattern $fixRussianKeyboardCopyPaste

    #remove a bad allias that blocks the 'where' command
    Update-ContentFile -Path $powershellProfile -Text $fixWhereLine -SearchPattern $fixWhereLine

    Update-ContentFile -Path $powershellProfile -Text $zoxideLine -SearchPattern $zoxideLine
}
if ($pwshStatus) {
    #fix CTRL+C, CTRL+V, CTRL+X for Russian keyboard layout
    # Update-ContentFile -Path $pwshProfile -Text $fixRussianKeyboardCopyPaste -SearchPattern $fixRussianKeyboardCopyPaste

    #remove a bad allias that blocks the 'where' command
    Update-ContentFile -Path $pwshProfile -Text $fixWhereLine -SearchPattern $fixWhereLine

    Update-ContentFile -Path $pwshProfile -Text $zoxideLine -SearchPattern $zoxideLine
}


#####  Install Font  #####
Write-Host; Write-HostCenter "Installing Fonts..." -ForegroundColor Cyan
foreach ($font in $fonts) {
    switch ($font) {
        "IBMPlexMono" {
            $installedFonts = Get-ChildItem -Path "C:\Windows\Fonts" | Where-Object { $_.Name -like "BlexMonoNerdFont*" }
        }
        Default {
            $installedFonts = Get-ChildItem -Path "C:\Windows\Fonts" | Where-Object { $_.Name -like "$font*" }
        }
    }
    if ($installedFonts) {
        Write-Host "Font '$font' is already installed."
    }
    else {
        & "$env:SCOOP\shims\oh-my-posh.exe" font install $font
    }
}

#set default font Windows Terminal
Set-ItemProperty -Path "HKCU:\Console\" -Name "FaceName" -Type String -Value "JetBrainsMono NFM" 2>$null
Set-ItemProperty -Path "HKCU:\Console\" -Name "FontSize" -Type DWord -Value "16" 2>$null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Console\TrueTypeFont\" -Name "00" -Value "JetBrainsMono NFM" 2>$null

#short command to edit profiles 
scoop shim add powershellconf 'micro' `"$(powershell -NoProfile -Command '$PROFILE.AllUsersAllHosts')`" --global
scoop shim add pwshconf 'micro' `"$(pwsh -NoProfile -Command '$PROFILE.AllUsersAllHosts')`" --global

#####  FINISH  #####
# Write-Host; Write-HostCenter "Reloading Profile..." -ForegroundColor Cyan
# . $PROFILE.AllUsersAllHosts

Write-Host; Write-HostCenter "Installation Complete." -ForegroundColor Green; Write-Host

if ($powershellStatus) {
    Write-Host "Installed Modules and Scripts PowerShell: " -ForegroundColor White -BackgroundColor Magenta
    (powershell -NoProfile -Command "Get-InstalledPSResource -Scope AllUsers | Format-Table Name, InstalledLocation")
}

if ($pwshStatus) {
    Write-Host "Installed Modules and Scripts PowerShell Core: " -ForegroundColor White -BackgroundColor Magenta
    (pwsh -NoProfile -Command "Get-InstalledPSResource -Scope AllUsers | Format-Table Name, InstalledLocation")
}

winfetch -ShowDisks * -cpustyle 'bar' -memorystyle 'bartext'  -diskstyle 'bartext' -batterystyle 'bartext'

Write-Host "`n" -BackgroundColor DarkRed
Write-HostCenter "!!!   Не забудьте поменять шрифт своего терминала на:   !!!" -ForegroundColor Yellow
Write-HostCenter "!!!       JetBrainsMono NFM          font-size: 16      !!!" -ForegroundColor Yellow
Write-HostCenter "!!!       MesloLGS Nerd Font Mono    font-size: 16      !!!" -ForegroundColor Yellow -NoNewline
Write-Host "`n" -BackgroundColor DarkRed
Write-HostCenter "> powershellconf - редактировать профиль PowerShell $PROFILE.AllUsersAllHosts" -ForegroundColor DarkYellow
Write-HostCenter "> pwshconf - редактировать профиль PowerShell Core $PROFILE.AllUsersAllHosts" -ForegroundColor DarkYellow
# Write-HostCenter "> p - запустить из терминала редактор Pragtical Editor " -ForegroundColor DarkYellow
Write-HostCenter "> psedit - терминальный редактор ps скриптов" -ForegroundColor DarkYellow
Write-HostCenter "> micro - терминальный редактор" -ForegroundColor DarkYellow
Write-HostCenter "[F2] в терминале, октрывает таблицу истории команд" -ForegroundColor DarkYellow

# Write-Host; Write-HostCenter "Press any key to Update-Help" -ForegroundColor Gray
# $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") *>$null
Write-Host; Write-HostCenter "Update help manuals for commands..." -ForegroundColor Cyan
Update-Help 2>$null

# Exit







###############  Support Commands  ###############
# all profiles current shell
#$PROFILE | Select-Object *Host* | Format-List

# open current shell profile in pragtical editor
#xl $PROFILE

# check the version
#(Get-Command pwsh).FileVersionInfo

# path executable file
#(Get-Command oh-my-posh).Source
#where lpm

# oh-my-posh - choice Nerd Font to install
#oh-my-posh font install

# oh-my-posh - demonstrate all themes
#Get-PoshThemes

# check restricted language mode PowerShell
#$ExecutionContext.SessionState.LanguageMode

# get help any command online
#Get-Help Update-Module -Online

# list all module folders path
#$env:PSModulePath -split ';'

# reset the PSModulePath in each open session
#$env:PSModulePath=[Environment]::GetEnvironmentVariable("PSModulePath", "Machine")

# folder Documets current user
#$DOCUMENTS = [Environment]::GetFolderPath("MyDocuments")
