<#
.NOTES
 A script to automatically install or update a typical advanced users software environment.
 https://github.com/maksimaliabyshev
 Version 1.0 by Maksim Aliabyshev
#>

param(
    [string]$theme = "quick-term.omp.json",
    [string[]]$fonts = @(),
    [string]$poshName = "JanDeDobbeleer.OhMyPosh",
    [string[]]$modules = @(),
    [string[]]$modulesNoImport = @(),
    [string[]]$scripts = @(),
    [string]$ProfilePath,
    [string]$shell,
    [switch]$Elevated,
    $NoExit
)


###  Elevate Credentials  ###
# debugging command line arguments passing
# if (-not [string]::IsNullOrEmpty($PSBoundParameters)) {
#     $params = ($PSBoundParameters.GetEnumerator() | ForEach-Object { "-$($_.Key) `'$($_.Value)`'" }) -join ' '
#     Write-Host '$params: ', $params
# }

if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
    if ([int](Get-CimInstance -Class Win32_OperatingSystem | Select-Object -ExpandProperty BuildNumber) -ge 6000) {
        $CommandLine = "cd `'$pwd`'; $($MyInvocation.Line)" -replace '"', "`'"
        # Write-Host "CommandLine: $CommandLine"
        Start-Process powershell -Verb RunAs -ArgumentList ("-NoExit -NoProfile -Command $CommandLine")
        Exit $LASTEXITCODE
    }
}
(Remove-Item alias:\where -Force) 2>$null


###  Init  ###
$fonts = @("JetBrainsMono", "Meslo", "IBMPlexMono") + ($fonts -split "[\s\,]+")
$modules = @("PsReadLine", "Posh", "posh-git", "Terminal-Icons") + ($modules -split "[\s\,]+")
# $modules = @("Microsoft.PowerShell.ConsoleGuiTools") + ($modules -split "[\s\,]+")
# $modulesNoImport = @("PowerShellGet") + $modulesNoImport
$scripts = @("TabExpansion2") + ($scripts -split "[\s\,]+")


function Write-HostCenter {
    param($Message)
    Write-Host ("{0}{1}" -f (' ' * (([Math]::Max(0, $Host.UI.RawUI.BufferSize.Width / 2) - [Math]::Floor($Message.Length / 2)))), $Message) @args
}

Write-Host "Theme: " -NoNewline; Write-Host "$theme" -ForegroundColor Magenta
Write-Host "Fonts: " -NoNewline; Write-Host "$fonts" -ForegroundColor Magenta
Write-Host "Modules: " -NoNewline; Write-Host "$modules" -ForegroundColor Magenta

if ([Environment]::Is64BitProcess -ne [Environment]::Is64BitOperatingSystem) {
    Write-HostCenter "!!!   Разрядность Операционной Системы НЕ СОВПАДАЕТ с разрядностью Центрального Процессора   !!!" -ForegroundColor White -BackgroundColor Red
    Start-Sleep -Seconds 5
}


###  Install winget  ###
#Write-HostCenter "Installing package manager WinGet..." -ForegroundColor Cyan
#Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Scope AllUsers -Force
#Install-Script -Name winget-install -Scope AllUsers
#winget-install -ForceClose


###  Install Powershell Core  ###
#Write-HostCenter "Installing PowerShell Core..." -ForegroundColor Cyan
#winget install --id=Microsoft.Powershell --silent --disable-interactivity --accept-source-agreements --accept-package-agreements

# if ([Environment]::Is64BitOperatingSystem) {
#     # Invoke-Command { reg import '.\Powershell7 Add 64-Bit Context Menu On 64-Bit Windows.reg' *>&1 } | Out-Null
#     $link = "https://gist.githubusercontent.com/maksimaliabyshev/77568947ef80baf32043b3247841035c/raw/context_file_powershell_pwsh_ise.reg"
#     Invoke-WebRequest -Uri "$link" -OutFile "$env:TEMP/context_file_powershell_pwsh_ise.reg"
#     reg import "$env:TEMP/context_file_powershell_pwsh_ise.reg" *>$null

#     $link = "https://gist.githubusercontent.com/maksimaliabyshev/77568947ef80baf32043b3247841035c/raw/context_folder_pwsh_x64.reg"
#     Invoke-WebRequest -Uri "$link" -OutFile "$env:TEMP/context_folder_pwsh_x64.reg"
#     reg import "$env:TEMP/context_folder_pwsh_x64.reg" *>$null
# }
# else {
#     $link = "https://gist.githubusercontent.com/maksimaliabyshev/77568947ef80baf32043b3247841035c/raw/context_folder_pwsh_x32.reg"
#     Invoke-WebRequest -Uri "$link" -OutFile "$env:TEMP/context_folder_pwsh_x32.reg"
#     reg import "$env:TEMP/context_folder_pwsh_x32.reg" *>$null
# }

#if needs change only target profile, argument 'powershell' - PowerShell
if ($ProfilePath) {
    if (!(Test-Path -Path $ProfilePath) ) {
        $directoryPath = Split-Path -Path $ProfilePath
        if (!(Test-Path -Path $directoryPath)) {
            Write-HostCenter "!!!   Не существует дирректории `"$directoryPath`" для создания файла профиля   !!!" -ForegroundColor White -BackgroundColor Red
            Start-Sleep -Seconds 5
            Exit
        }
        New-Item -ItemType File -Path $ProfilePath -Force
    }

    if ($shell -like '*powershell*') {
        $powershellStatus = $true
        $powershellProfile = $ProfilePath
        Write-Host "Targeted PowerShell profile: " -NoNewline
        Write-Host $powershellProfile -ForegroundColor Yellow
    }
    else {
        $pwshStatus = $true
        $pwshProfile = $ProfilePath
        Write-Host "Targeted PowerShell Core profile: " -NoNewline
        Write-Host $pwshProfile -ForegroundColor Yellow
    }
}

#detect PowerShell
if ((Get-Command -Name powershell -ErrorAction SilentlyContinue) -and !$ProfilePath) {
    $powershellStatus = $true
    $powershellProfileAllUsersAllHosts = powershell.exe -Command '$PROFILE.AllUsersAllHosts'
    $powershellProfile = $powershellProfileAllUsersAllHosts
    #$powershellProfile = powershell.exe -Command '$PROFILE.CurrentUserCurrentHost'
    Write-Host "==============  detect PowerShell  ==============" -ForegroundColor Green -BackgroundColor Black
    Write-Host "PowerShell profile: " -NoNewline; Write-Host $powershellProfile -ForegroundColor Yellow
    (powershell.exe -Command '$PSVersionTable')
}

#detect PowerShell Core
if ((Get-Command -Name pwsh -ErrorAction SilentlyContinue) -and !$ProfilePath) {
    $pwshStatus = $true
    $pwshProfileAllUsersAllHosts = pwsh.exe -Command '$PROFILE.AllUsersAllHosts'
    $pwshProfile = $pwshProfileAllUsersAllHosts
    #$pwshProfile = pwsh.exe -Command '$PROFILE.CurrentUserCurrentHost'
    Write-Host "==============  detect PowerShell Core  ==============" -ForegroundColor Green -BackgroundColor Black
    Write-Host "PowerShell Core profile: " -NoNewline; Write-Host $pwshProfile -ForegroundColor Yellow
    (pwsh.exe -Command '$PSVersionTable')
}


###  Install Microsoft Edge WebView2 Runtime  ###
#Write-HostCenter "Installing Microsoft Edge WebView2 Runtime..." -ForegroundColor Cyan
#winget install --id=Microsoft.EdgeWebView2Runtime --silent --disable-interactivity --accept-source-agreements --accept-package-agreements


###  Install Microsoft Visual C++ 2005/2008/2010/2012/2013/2015+ Redistributable  ###
#Write-HostCenter "Installing Microsoft Visual C++ 2005/2008/2010/2012/2013/2015+ Redistributable..." -ForegroundColor Cyan
#winget install --id=Microsoft.VCRedist.2005.x86 --silent --disable-interactivity --accept-source-agreements --accept-package-agreements
#winget install --id=Microsoft.VCRedist.2005.x64 --silent --disable-interactivity --accept-source-agreements --accept-package-agreements
#winget install --id=Microsoft.VCRedist.2008.x86 --silent --disable-interactivity --accept-source-agreements --accept-package-agreements
#winget install --id=Microsoft.VCRedist.2008.x64 --silent --disable-interactivity --accept-source-agreements --accept-package-agreements
#winget install --id=Microsoft.VCRedist.2010.x86 --silent --disable-interactivity --accept-source-agreements --accept-package-agreements
#winget install --id=Microsoft.VCRedist.2010.x64 --silent --disable-interactivity --accept-source-agreements --accept-package-agreements
#winget install --id=Microsoft.VCRedist.2012.x86 --silent --disable-interactivity --accept-source-agreements --accept-package-agreements
#winget install --id=Microsoft.VCRedist.2012.x64 --silent --disable-interactivity --accept-source-agreements --accept-package-agreements
#winget install --id=Microsoft.VCRedist.2013.x86 --silent --disable-interactivity --accept-source-agreements --accept-package-agreements
#winget install --id=Microsoft.VCRedist.2013.x64 --silent --disable-interactivity --accept-source-agreements --accept-package-agreements
#winget install --id=Microsoft.VCLibs.Desktop.14 --silent --disable-interactivity --accept-source-agreements --accept-package-agreements
#winget install --id=Microsoft.VCRedist.2015+.x86 --silent --disable-interactivity --accept-source-agreements --accept-package-agreements
#winget install --id=Microsoft.VCRedist.2015+.x64 --silent --disable-interactivity --accept-source-agreements --accept-package-agreements


###  Install Microsoft Visual Studio BuildTools  ###
#Write-HostCenter "Installing Microsoft VisualStudio 2022 BuildTools..." -ForegroundColor Cyan
#winget install --id=Microsoft.VisualStudio.2022.BuildTools --silent --disable-interactivity --accept-source-agreements --accept-package-agreements
# Individual Components: Windows SDK, C++ x64/x86 build tools
#Start-Process "C:\Program Files (x86)\Microsoft Visual Studio\Installer\vs_installer.exe" -Wait -PassThru -ArgumentList `
#'modify --installPath "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools" --passive --norestart --nocache --downloadThenInstall --includeRecommended --includeOptional --force',
#'--add Microsoft.VisualStudio.Component.NuGet.BuildTools',
#'--add Microsoft.VisualStudio.Workload.VCTools',
#'--add Microsoft.VisualStudio.Workload.MSBuildTools'


###  Install Microsoft .NET Desktop 3.1/5/6/7/8/Preview  ###
#Write-HostCenter "Installing Microsoft .NET Desktop 3.1/5/6/7/8/Preview..." -ForegroundColor Cyan
#winget install --id=Microsoft.dotnetRuntime.3-x86 --silent --disable-interactivity --accept-source-agreements --accept-package-agreements
#winget install --id=Microsoft.DotNet.DesktopRuntime.3_1 --silent --disable-interactivity --accept-source-agreements --accept-package-agreements
#winget install --id=Microsoft.dotnetRuntime.5-x86 --silent --disable-interactivity --accept-source-agreements --accept-package-agreements
#winget install --id=Microsoft.DotNet.DesktopRuntime.5 --silent --disable-interactivity --accept-source-agreements --accept-package-agreements
#winget install --id=Microsoft.dotnetRuntime.6-x86 --silent --disable-interactivity --accept-source-agreements --accept-package-agreements
#winget install --id=Microsoft.DotNet.DesktopRuntime.6 --silent --disable-interactivity --accept-source-agreements --accept-package-agreements
#winget install --id=Microsoft.DotNet.DesktopRuntime.7 --silent --disable-interactivity --accept-source-agreements --accept-package-agreements
#winget install --id=Microsoft.DotNet.DesktopRuntime.8 --silent --disable-interactivity --accept-source-agreements --accept-package-agreements
#winget install --id=Microsoft.DotNet.DesktopRuntime.Preview --silent --disable-interactivity --accept-source-agreements --accept-package-agreements


###  Microsoft .NET Framework 2/3/4.5/4@latest  ###
#Write-HostCenter "Installing Microsoft .NET Framework 2/3..." -ForegroundColor Cyan
#winget install --id=Microsoft.DotNet.Framework.DeveloperPack.4.5 --silent --disable-interactivity --accept-source-agreements --accept-package-agreements
#winget install --id=Microsoft.DotNet.Framework.DeveloperPack_4 --silent --disable-interactivity --accept-source-agreements --accept-package-agreements
#!(Get-WindowsCapability -Online -Name "NetFx3").State -eq "Installed" -and (Enable-WindowsOptionalFeature -Online -FeatureName "NetFx3") >$null


###  Microsoft ASP.NET Core 2/3/5/6/7/8/Preview  ###
#Write-HostCenter "Installing Microsoft ASP.NET Core 2/3/5/6/7/8/Preview..." -ForegroundColor Cyan
#winget install --id=Microsoft.DotNet.AspNetCore.2_1 --silent --disable-interactivity --accept-source-agreements --accept-package-agreements
#winget install --id=Microsoft.DotNet.AspNetCore.3_1 --silent --disable-interactivity --accept-source-agreements --accept-package-agreements
#winget install --id=Microsoft.DotNet.AspNetCore.5 --silent --disable-interactivity --accept-source-agreements --accept-package-agreements
#winget install --id=Microsoft.DotNet.AspNetCore.6 --silent --disable-interactivity --accept-source-agreements --accept-package-agreements
#winget install --id=Microsoft.DotNet.AspNetCore.7 --silent --disable-interactivity --accept-source-agreements --accept-package-agreements
#winget install --id=Microsoft.DotNet.AspNetCore.8 --silent --disable-interactivity --accept-source-agreements --accept-package-agreements
#winget install --id=Microsoft.DotNet.AspNetCore.Preview --silent --disable-interactivity --accept-source-agreements --accept-package-agreements


###  Install DirectX Web Installer  ###
#Write-HostCenter "Installing Microsoft DirectX End-User Runtime Web Installer..." -ForegroundColor Cyan
#winget install --id=Microsoft.DirectX --silent --disable-interactivity --accept-source-agreements --accept-package-agreements 2>&1>$null


###  Install OpenJDK JRE 17  ###
#Write-HostCenter "Installing Java Runtime Environment..." -ForegroundColor Cyan
#winget install --id=Oracle.JavaRuntimeEnvironment --silent --disable-interactivity --accept-source-agreements --accept-package-agreements
#winget install --id=ojdkbuild.openjdk.11.jre --silent --disable-interactivity --accept-source-agreements --accept-package-agreements
#winget install --id=ojdkbuild.openjdk.17.jre --silent --disable-interactivity --accept-source-agreements --accept-package-agreements


###  Install Git   ###
#Write-HostCenter "Installing Git..." -ForegroundColor Cyan
#winget install --id=Git.Git --silent --disable-interactivity --accept-source-agreements --accept-package-agreements


###  Install WinFsp  ###
#Write-HostCenter "Installing WinFsp - supports Windows native, FUSE, .NET and Cygwin file systems..." -ForegroundColor Cyan
#winget install --id=WinFsp.WinFsp --silent --disable-interactivity --accept-source-agreements --accept-package-agreements


###  Install Scoop   ###
#Write-HostCenter "Installing package manager Scoop..." -ForegroundColor Cyan
#iex "& {$(irm https://raw.githubusercontent.com/scoopinstaller/install/master/install.ps1)} -RunAsAdmin"
#scoop bucket add extras

###  Install curl, wget, aria2   ###
#scoop install curl --global
#scoop install wget --global
#scoop install aria2 --global

###  Install Clink for cmd.exe  ###
#Write-HostCenter "Installing Clink autocomplit tool for cmd.exe: " -NoNewline -ForegroundColor Cyan
#Write-Host "https://chrisant996.github.io/clink" -ForegroundColor Yellow
#scoop install clink --global
#cmd.exe /c "clink autorun install -a"

###  Install NodeJS  ###
#Write-HostCenter "Installing NodeJS..." -ForegroundColor Cyan
#scoop install nodejs --global


###  Install Python  ###
#Write-HostCenter "Installing Python..." -ForegroundColor Cyan
#scoop install python --global


###  Install MinGW  ###
#Write-HostCenter "Installing WinLibs standalone build of GCC and MinGW-w64 for Windows: " -NoNewline -ForegroundColor Cyan
#Write-Host "https://winlibs.com" -ForegroundColor Yellow
#scoop info mingw-winlibs --global


###  Install WinFetch  ###
#Write-HostCenter "Installing WinFetch..." -ForegroundColor Cyan
#scoop install winfetch --global


###  Install Pragtical Editor  ###
# if ([Environment]::Is64BitOperatingSystem) {
#     # Write-HostCenter "Installing Pragtical Editor..." -ForegroundColor Cyan
#     scoop install pragtical --global
    scoop shim add p 'pragtical' --global
    scoop shim add pwshconf 'pragtical' '$(pwsh.exe -Command "$PROFILE.AllUsersAllHosts")' --global

#     scoop install https://gist.githubusercontent.com/maksimaliabyshev/6b311f327078022dd365eea96f2428e8/raw/pragtical-plugin-manager.json --global
#     # $pragticalDataFolder = [Environment]::GetFolderPath('CommonApplicationData') + "\scoop\apps\pragtical\current\data"
#     ppm purge --force
#     ppm update --assume-yes --progress
#     #ppm install plugin_manager --assume-yes --progress
#     #ppm install language* --assume-yes --progress
#     #ppm color install * --assume-yes --progress
#     #ppm install lsp lsp_snippets snippets --assume-yes --progress
#     ppm install font_symbols_nerdfont_mono_regular nerdicons --assume-yes --progress

#     ppm install align_carets autoinsert autowrap bracketmatch codeplus colorpicker colorpreview console copyfilelocation custom_caret `
#         datetimestamps editorconfig evergreen endwise eofnewline ephemeral_tabs eval exec exterm extend_selection_line force_syntax formatter `
#         fontconfig fontpreview gitblame gitdiff_highlight gitopen gitstatus gui_filepicker indent_convert indentguide json jsonmod `
#         keymap_export linenumbers link_opener lintplus lorem markers minimap motiontrail navigate openfilelocation openselected `
#         profiler rainbowparen recentfiles regexreplacepreview restoretabs scalestatus scm selectionhighlight smartopenselected smoothcaret `
#         sort sortcss spellcheck sticky_scroll su_save svg_screenshot tab_switcher tabnumbers terminal texcompile titleize `
#         todotreeview togglesnakecamel treeview-extender typingspeed wordcount --assume-yes --progress

#     ppm upgrade --assume-yes --progress
# }


###  Install oh-my-posh  ###
#Write-HostCenter "Installing oh-my-posh..." -ForegroundColor Cyan
#winget install $poshName --disable-interactivity --accept-source-agreements --accept-package-agreements


###  Powershell Enhancement  ###
function Edit-Profile {
    param (
        [Parameter(Mandatory = $true)][String]$ProfilePath,
        [AllowEmptyString()]$SearchPattern,
        [AllowEmptyString()]$Text
    )
    $Text = $Text -Replace "[ \t]+", " "
    $SearchPattern = $SearchPattern -Replace "[ \t]+", " "
    Write-Host "---Text $Text"
    Write-Host "---SearchPattern $SearchPattern"
    if (!(Test-Path $ProfilePath)) {
        New-Item -Path $ProfilePath -ItemType File -Force
        Write-Host "`nPowerShell profile created: " -ForegroundColor DarkGreen -NoNewline; Write-Host $ProfilePath -ForegroundColor Yellow
    }

    # $selectedText = Get-Content $ProfilePath | Select-String -Pattern $SearchPattern -SimpleMatch
    $selectedText = Select-String -Path $ProfilePath -Pattern $SearchPattern -SimpleMatch | Select-Object -First 1 -ExpandProperty Line
    Write-Host "---selectedText $selectedText"
    # add text
    if ($Text -and !$selectedText) {
        Add-Content -Path $ProfilePath -Value $Text
        Write-Host "Added Profile: " -NoNewline; Write-Host $ProfilePath -ForegroundColor Yellow
        Write-Host $Text -ForegroundColor DarkGreen
    }
    # update text
    if ($Text -and $selectedText -and ($Text -ne $selectedText)) {
        (Get-Content $ProfilePath -Raw) -Replace "$selectedText", "$Text" -Replace "\n{3,}", "\n" | Set-Content $ProfilePath
        Write-Host "Updated Profile: " -NoNewline; Write-Host $ProfilePath -ForegroundColor Yellow
        Write-Host $Text -ForegroundColor DarkGreen
    }
    # remove text
    if (!$Text -and $selectedText) {
        (Get-Content $ProfilePath -Raw) -Replace "$selectedText", "" -Replace "\n{3,}", "\n" | Set-Content $ProfilePath
        Write-Host "Removed in Profile: " -NoNewline; Write-Host $ProfilePath -ForegroundColor Yellow
        Write-Host $selectedText -ForegroundColor DarkRed
    }
}

#disable restricted PowerShell language mode
# Remove-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment' __PSLockdownPolicy 2>$null

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

$fixWhereCommand = '(Remove-Item alias:\where -Force) 2>$null'

if ($powershellStatus) {
    #fix CTRL+C, CTRL+V, CTRL+X for Russian keyboard layout
    # Edit-Profile -ProfilePath $powershellProfileAllUsersAllHosts  -Text $fixRussianKeyboardCopyPaste -SearchPattern $fixRussianKeyboardCopyPaste

    #remove a bad allias that blocks the 'where' command
    Edit-Profile -ProfilePath $powershellProfile -Text $fixWhereCommand -SearchPattern $fixWhereCommand
}
if ($pwshStatus) {
    #fix CTRL+C, CTRL+V, CTRL+X for Russian keyboard layout
    # Edit-Profile -ProfilePath $pwshProfileAllUsersAllHosts  -Text $fixRussianKeyboardCopyPaste -SearchPattern $fixRussianKeyboardCopyPaste

    #remove a bad allias that blocks the 'where' command
    Edit-Profile -ProfilePath $pwshProfile -Text $fixWhereCommand -SearchPattern $fixWhereCommand
}


Write-Host "`nInstalling modules...:  " -ForegroundColor Cyan -NoNewline; Write-Host "$modules $modulesNoImport" -ForegroundColor Green
Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted
Get-PSRepository

foreach ($moduleName in $modules) {

    if ($powershellStatus) {
        Write-Host "`nInstall module in PowerShell: $moduleName" -ForegroundColor White -BackgroundColor Magenta
        powershell.exe -Command "Install-Module -Name $moduleName -Scope AllUsers -AllowClobber -Force"
        if ($?) {
            #add import module to profile
            $moduleLine = "Import-Module -Name $moduleName"
            Edit-Profile -ProfilePath $powershellProfile -Text $moduleLine -SearchPattern "Import-Module -Name $moduleName"
        }
    }

    if ($pwshStatus) {
        Write-Host "`nInstall module in PowerShell Core: $moduleName" -ForegroundColor White -BackgroundColor Magenta
        pwsh.exe -Command "Install-Module -Name $moduleName -Scope AllUsers -AllowClobber -AllowPrerelease -Force"
        if ($?) {
            #add import module to profile
            $moduleLine = "Import-Module -Name $moduleName"
            Edit-Profile -ProfilePath $pwshProfile -Text $moduleLine -SearchPattern "Import-Module -Name $moduleName"
        }
    }
}

foreach ($moduleName in $modulesNoImport) {

    if ($powershellStatus) {
        Write-Host "`nInstall module in PowerShell:  $moduleName" -ForegroundColor White -BackgroundColor Magenta
        powershell.exe -Command "Install-Module -Name $moduleName -Scope AllUsers -AllowClobber -Force"
    }

    if ($pwshStatus) {
        Write-Host "`nInstall module in PowerShell Core:  $moduleName" -ForegroundColor White -BackgroundColor Magenta
        pwsh.exe -Command "Install-Module -Name $moduleName -Scope AllUsers -AllowClobber -AllowPrerelease -Force"
    }
}

foreach ($scriptName in $scripts) {

    if ($powershellStatus) {
        Write-Host "`nInstall script in PowerShell:  $scriptName" -ForegroundColor White -BackgroundColor Magenta
        powershell.exe -Command "Install-Script -Name $scriptName -Scope AllUsers -Force"
    }

    if ($pwshStatus) {
        Write-Host "`nInstall script in PowerShell Core:  $scriptName" -ForegroundColor White -BackgroundColor Magenta
        pwsh.exe -Command "Install-Script -Name $scriptName -Scope AllUsers -Force"
    }
}


#oh-my-posh configuration
$poshLine = "oh-my-posh init pwsh --config ""$env:POSH_THEMES_PATH\$($theme)"" | Invoke-Expression"
if ($powershellStatus) {
    # poshConfiguration -ProfilePath $powershellProfile
    Edit-Profile -ProfilePath $powershellProfile -Text $poshLine -SearchPattern "oh-my-posh init pwsh"
}
#oh-my-posh configuration PowerShell Core
if ($pwshStatus) {
    # poshConfiguration -ProfilePath $pwshProfile
    Edit-Profile -ProfilePath $pwshProfile -Text $poshLine -SearchPattern "oh-my-posh init pwsh"
}


###  Install Font  ###
Write-HostCenter "`nInstalling Font..." -ForegroundColor Cyan
foreach ($font in $fonts) {
    if ($font -like "IBMPlexMono") {$font ="BlexMonoNerdFont"}
    $installedFonts = Get-ChildItem -Path "C:\Windows\Fonts" | Where-Object { $_.Name -like "$font*" }
    if ($installedFonts) {
        Write-Host "Font '$font' is already installed."
    }
    else {
        & "$env:USERPROFILE\AppData\Local\Programs\oh-my-posh\bin\oh-my-posh.exe" font install $font
    }
}

#set default font Windows Terminal
Set-ItemProperty -Path "HKCU:\Console\" -Name "FaceName" -Type String -Value "JetBrainsMono NFM Medium" 2>$null
Set-ItemProperty -Path "HKCU:\Console\" -Name "FontSize" -Type DWord -Value "16" 2>$null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Console\TrueTypeFont\" -Name "0" -Value "JetBrainsMono NFM Medium" 2>$null
Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Console\TrueTypeFont\" -Name "00" -Value "JetBrainsMono NFM Medium" 2>$null


###  FINISH  ###
Write-Host; Write-Host "Reloading Profile..." -ForegroundColor Cyan
. $PROFILE

Write-HostCenter "Installation Complete." -ForegroundColor Green
Write-Host

Write-Host "Installed Modules and Scripts: " -ForegroundColor White -BackgroundColor Magenta
Get-InstalledModule
Get-InstalledScript

winfetch -ShowDisks * -cpustyle 'bar' -memorystyle 'bartext'  -diskstyle 'bartext' -batterystyle 'bartext'

Write-Host "`n" -BackgroundColor DarkRed
Write-HostCenter "!!!   Не забудьте поменять шрифт своего терминала на:   !!!" -ForegroundColor DarkRed
Write-HostCenter "!!!     JetBrainsMono NFM Medium     font-size: 16      !!!" -ForegroundColor DarkRed
Write-HostCenter "!!!     или MesloLGS Nerd Font Mono  font-size: 16      !!!" -ForegroundColor DarkRed
Write-HostCenter "!!!     или BlexMono Nerd Font Mono  font-size: 18      !!!" -ForegroundColor DarkRed -NoNewline
Write-Host "`n" -BackgroundColor DarkRed
Write-HostCenter "> p - запустить из терминала редактор Pragtical Editor; [ctrl]+[shift]+[P] -> Plugin Manager: Show;" -ForegroundColor DarkYellow

Write-Host; Write-HostCenter "Press any key to Update-Help" -ForegroundColor Gray
$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") *>$null

#update help manuals for commandlets
# Update-Help 2>$null

Exit







#########  Support Commands  #########
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
