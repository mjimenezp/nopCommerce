# valid versions are [2.0, 3.5, 4.0]

function Get-MsBuildPath {
 param( [string]$dotNetVersion)
 regKey = "HKLM:\software\Microsoft\MSBuild\ToolsVersions\$dotNetVersion"
  $regProperty = "MSBuildToolsPath"
  $msbuildExe = join-path -path (Get-ItemProperty $regKey).$regProperty -childpath "msbuild.exe"
  return $msbuildExe
}
