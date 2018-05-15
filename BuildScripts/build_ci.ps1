$ErrorActionPreference = "Stop"
if (-not (Test-Path env:AdditionalMsBuildParameter)) { 
  $env:AdditionalMsBuildParameter = " "
}

Write-Host "Solution list: $env:SolutionList"
$solutionList = $env:SolutionList.Replace("\`"","").Replace("`'","").Split(",")
$buildConfig=$env:BuildConfiguration.Replace("\`"","").Replace("`'","")
$additionalParams=$env:AdditionalMsBuildParameter.Replace("\`"","").Replace("`'","")
$msbuild="`"C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\MSBuild\15.0\Bin\MSBuild.exe`""
$msbuild_parameters="/t:Clean,Compile,Rebuild /p:Configuration=$buildConfig $additionalParams"
Write-Host "MSbuid params: $msbuild_parameters"
Write-Host "Build config: $buildConfig"
Write-Host "AdditionalMsBuildParameter : $additionalParams"
Write-Host "SolutionList : $solutionList"
Write-Host "Current folder content"
ls
#####################################Functions################################################################################################
function Get-OutputhPath {
  param( [string]$BasePath, $Project,[string]$BuildConfiguration)
  $outputPath=""
  Get-Content "$BasePath\$($Project.File)" | Select-String "<PropertyGroup Condition=" -Context 5 |
  ForEach-Object {
    if ($_.Line -like "*$($BuildConfiguration)*"){
      Foreach($lineContext in $_.Context.PostContext){
        if($lineContext -like "*<OutputPath*"){
          $matchesOutPath=$lineContext | Select-String -Pattern "\<OutputPath\>(.*)\</OutputPath\>"
          $outputPath=$matchesOutPath.Matches.Groups[1].Value
        }
      }
    }
  }
  return $outputPath
}

function Get-ProjectsPath {
 param( [string]$SolutionFile)
 $result= Get-Content $SolutionFile | Select-String "Project\(" |
      ForEach-Object {
        $projectParts=$_ -Split '[,=]' | ForEach-Object { $_.Trim('[ "{}]')};
        New-Object PSObject -Property @{
          Name= $projectParts[1];
          File= $projectParts[2];
          Guid= $projectParts[3];
        }
      }
  return $result
}

function Verify-IsWebProject{
  param( [string]$ProjectType)  
  $webprojGuid = @(
    "{8BB2217D-0F2D-49D1-97BC-3654ED321F3B}",
    "{603C0E0B-DB56-11DC-BE95-000D561079B0}",
    "{F85E285D-A4E0-4152-9332-AB1D724D3325}",
    "{E53F8FEA-EAE0-44A6-8774-FFD645390401}",
    "{E3E379DF-F4C6-4180-9B81-6769533ABE47}",
    "{349C5851-65DF-11DA-9384-00065B846F21}",
    "{E24C65DC-7377-472B-9ABA-BC803B73C61A}",
    "{3D9AD99F-2412-4246-B90B-4EAA41C64699}"
  )
  $listOfGuids=$valueContent.Split(";")
  foreach($projectGuid in $listOfGuids){
    if($webprojGuid -Contains $projectGuid ){
      return $TRUE
    }
  }
  return $FALSE
}

############################################################################################################################################
$currentDir= Get-Location
$outputDir="$($currentDir.path)\JenkinsBuildOutput"

Write-Host "Output Directory: $outputDir"

if(Test-Path $outputDir){
  Clear-Content -Path $outputDir -Force
  Write-Host "cleaned: $outputDir"
}
else {
  New-Item -ItemType "directory" -Path $outputDir -Force   
}

foreach($solutionPath in $solutionList){
  Write-Host "---Running msbuild---"
  $cmdArgumentsToRunMsBuild="/k $msbuild $solutionPath $msbuild_parameters"

  $buildCommand=Start-Process cmd.exe -ArgumentList $cmdArgumentsToRunMsBuild -NoNewWindow -PassThru
  Wait-Process -Id $buildCommand.id
  Write-Host "---Build process ended---"

  ####################Collect artifacts#################################
  $SolutionFile="$($currentDir.path)\$solutionPath"
  $BasePath=$currentDir

  $projects= Get-ProjectsPath -SolutionFile $SolutionFile
  
  Foreach($project in $projects){
    $IsWebProject=$FALSE
    $projectFolder=Split-Path -Path "$BasePath\$($project.File)"
    $outputPath=Get-OutputhPath -BasePath $BasePath -Project $project -BuildConfiguration $BuildConfiguration
    Write-Host $project.Name
    Write-Host $projectFolder;
    Write-Host "Out: $outputPath";
    
    $namespace=@{default="http://schemas.microsoft.com/developer/msbuild/2003" }
    $valueContent= Select-Xml -Path "$BasePath\$($project.File)" -Xpath "/default:Project/default:PropertyGroup/default:ProjectTypeGuids/text()" -Namespace $namespace   | Select-Object -Expand node | Select-Object -Expand Value
    Write-Host "Content for Project Type Guid:"
    Write-Host $valueContent
    if ($valueContent) { 
      Write-Host "Project name with project guid: $project.Name"
      $IsWebProject=Verify-IsWebProject $valueContent
      if($IsWebProject){
        Write-Host "*****************Is a web project,publishing****************"
        New-Item -ItemType "directory" -Path "$($outputDir)\$($project.Name)" -Force 
        $msbuild_websitepublish=" /p:DeployOnBuild=true;DeployTarget=PipelinePreDeployCopyAllFilesToOneFolder;_PackageTempDir=`"$($outputDir)\$($project.Name)`";AutoParameterizationWebConfigConnectionStrings=false"
        $cmdArgumentsToRunMsBuild="$msbuild `"$BasePath\$($project.File)`" $msbuild_websitepublish"
        Write-Host "command: $cmdArgumentsToRunMsBuild"
        $cmdArgumentsToRunMsBuild | Set-Content "$currentDir\$($project.Name).bat"
        $buildCommand=Start-Process cmd.exe -ArgumentList "/k $currentDir\$($project.Name).bat" -NoNewWindow -PassThru
        Wait-Process -Id $buildCommand.id
      }
    }
    else{
      if(Test-Path "$projectFolder\$outputPath"){
        New-Item -ItemType "directory" -Path "$($outputDir)\$($project.Name)" -Force 
        Copy-Item "$projectFolder\$outputPath\*" -Destination "$($outputDir)\$($project.Name)" -Recurse  
      }
    }
    
    if(Test-Path "$($outputDir)\$($project.Name)"){
      $fileCount=(Get-ChildItem "$($outputDir)\$($project.Name)" | Measure-Object ).Count
      if($fileCount -gt 0){
        Compress-Archive -Path "$($outputDir)\$($project.Name)" -DestinationPath "$($outputDir)\$($project.Name).zip" -CompressionLevel "Optimal"
      }
    }
  }
}

exit 0