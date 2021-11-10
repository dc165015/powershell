
Function global:Add-DirectoryToPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias("FullName")]
        [string] $path,

        [switch] $whatIf
    )

    BEGIN {

        ## normalize paths

        $count = 0

        $paths = @()
        $env:PATH.Split(";") | ForEach-Object {
            if ($_.Length -gt 0) {
                $count = $count + 1
                $paths += $_.ToLowerInvariant()
            }
        }

        ## Write-Host "Currently $($count) entries in `$env:PATH" -ForegroundColor Green

        Function Array-Contains {
            param(
                [string[]] $array,
                [string] $item
            )

            $any = $array | Where-Object -FilterScript {
                $_ -eq $item
            }

            Write-Output ($null -ne $any)
        }
    }

    PROCESS {

        $path = $path -replace "^(.*);+$", "`$1"
        $path = $path -replace "^(.*)\\$", "`$1"
        if (Test-Path -Path $path) {
            $path = (Resolve-Path -Path $path).Path
            $path = $path.Trim()

            $newPath = $path.ToLowerInvariant()
            if (-not (Array-Contains -Array $paths -Item $newPath)) {
                if ($whatIf.IsPresent) {
                    Write-Host $path
                }
                $paths += $path

                ## Write-Host "Adding $($path) to `$env:PATH" -ForegroundColor Green
            }
        }
        else {

            Write-Host "Invalid entry in `$Env:PATH: ``$path``" -ForegroundColor Yellow

        }
    }

    END {

        ## re-create PATH environment variable

        $joinedPaths = [string]::Join(";", $paths)
        $envPATH = "$($joinedpaths)"

        if ($whatIf.IsPresent) {
            Write-Output $envPATH
        }
        else {
            $env:PATH = $envPATH
        }
    }
}

## Well-known profiles script
Function Load-Profile {
    [CmdletBinding()]
    param(
        [string] $name
    )

    BEGIN {
        Function Get-PwshExpression {
            param([string]$path)

            $content = Get-Content -Path $path -Raw
            # $content = $content -replace "[Ff]unction\ +([A-Za-z])", "Function global:`$1"
            $content = $content -replace "[Ss][Ee][Tt]\-[Aa][Ll][Ii][Aa][Ss]\ +(.*)$", "Set-Alias -Scope Global `$1"

            Write-Output $content
        }
    }

    PROCESS {

        $alternate = $profile.Replace("profile", $name)
        if (Test-Path -Path $alternate) {
            Write-Host "Loading $name profile." -ForegroundColor Gray
            Invoke-Expression -Command (Get-PwshExpression -Path $alternate)
        }
        else {

            $alternate = $profile.Replace("profile", "$name-profile")
            if (Test-Path -Path $alternate) {
                Write-Host "Loading $name profile." -ForegroundColor Gray
                Invoke-Expression -Command (Get-PwshExpression -Path $alternate)
            }
            else {
                Write-Host "No such profile '$name'." -ForegroundColor Magenta
            }
        }
    }
}

Load-Profile "dc"

## Setup PATH environment variable

Add-DirectoryToPath "C:\Program Files (x86)\Yarn\bin" 
Add-DirectoryToPath "C:\tools\neovim\neovim\bin\nvim.exe"

Function c {
    param([string] $path = ".")
    . code-insiders $path
}

Function cguid { [Guid]::NewGuid().guid | clipp }

Function cwd { $PWD.Path | clipp }

Function ewd { param([string] $path = $PWD.Path) explorer $path }
Set-Alias -Name e -Value ewd

Function dcx { ssh root@dcx }

Function lsp { netstat -aon | findstr $args }

Function reload { & $profile }

Set-Alias -Name vi -Value nvim

Function Reboot-Wsl { Restart-Service LxssManager }

Function Reboot-Docker {
    restart-service *docker*
    $processes = Get-Process "*docker desktop*"
    if ($processes.Count -gt 0) {
        $processes[0].Kill()
        $processes[0].WaitForExit()
    }
    Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"
}

Function Set-Proxy ( $server, $port) {
    If ((Test-NetConnection -ComputerName $server -Port $port).TcpTestSucceeded) {
        Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -name ProxyServer -Value "$($server):$($port)"
        Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -name ProxyEnable -Value 1
    }
    Else {
        Write-Error -Message "Invalid proxy server address or port:  $($server):$($port)"
    }
}

Function proxy {
    [System.Net.WebRequest]::DefaultWebProxy = [System.Net.WebRequest]::GetSystemWebProxy()
    [System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
}

Function proxyOff {
    $Env:no_proxy = 1
}

Add-Type -AssemblyName Microsoft.VisualBasic

Function recycle($Path) {
    $item = Get-Item -Path $Path -ErrorAction SilentlyContinue
    if ($null -eq $item) {
        Write-Error("'{0}' not found" -f $Path)
    }
    else {
        $fullpath = $item.FullName
        Write-Verbose ("Moving '{0}' to the Recycle Bin" -f $fullpath)
        if (Test-Path -Path $fullpath -PathType Container) {
            [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory($fullpath, 'OnlyErrorDialogs', 'SendToRecycleBin')
        }
        else {
            [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($fullpath, 'OnlyErrorDialogs', 'SendToRecycleBin')
        }
    }
}

Function wsl2ports {
    $remoteport = bash.exe -c "ifconfig eth0 | grep 'inet '"
    $found = $remoteport -match '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}';

    if ( $found ) {
        $remoteport = $matches[0];
    }
    else {
        echo "The Script Exited, the ip address of WSL 2 cannot be found";
        exit;
    }

    #[Ports]

    #All the ports you want to forward separated by coma
    $ports = @(80, 443, 10000, 3000, 5000);


    #[Static ip]
    #You can change the addr to your ip config to listen to a specific address
    $addr = '0.0.0.0';
    $ports_a = $ports -join ",";


    #Remove Firewall Exception Rules
    iex "Remove-NetFireWallRule -DisplayName 'WSL 2 Firewall Unlock' ";

    #adding Exception Rules for inbound and outbound Rules
    iex "New-NetFireWallRule -DisplayName 'WSL 2 Firewall Unlock' -Direction Outbound -LocalPort $ports_a -Action Allow -Protocol TCP";
    iex "New-NetFireWallRule -DisplayName 'WSL 2 Firewall Unlock' -Direction Inbound -LocalPort $ports_a -Action Allow -Protocol TCP";

    for ( $i = 0; $i -lt $ports.length; $i++ ) {
        $port = $ports[$i];
        iex "netsh interface portproxy delete v4tov4 listenport=$port listenaddress=$addr";
        iex "netsh interface portproxy add v4tov4 listenport=$port listenaddress=$addr connectport=$port connectaddress=$remoteport";
    }
}
