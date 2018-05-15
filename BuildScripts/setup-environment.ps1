If(!(Test-Path -Path "$env:ProgramData\Chocolatey")){
    Set-ExecutionPolicy Bypass -Scope Process -Force; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
}
choco install saxonhe -y

exit 0