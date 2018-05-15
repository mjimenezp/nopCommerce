$ErrorActionPreference = "Stop"
if (-not (Test-Path env:AdditionalMsBuildParameter)) { 
  $env:AdditionalMsBuildParameter = " "
}

Write-Host "Solution list: $env:SolutionList"
$solutionList = $env:SolutionList.Replace("\`"","").Replace("`'","").Split(",")
$buildConfig=$env:BuildConfiguration.Replace("\`"","").Replace("`'","")
$additionalParams=$env:AdditionalMsBuildParameter.Replace("\`"","").Replace("`'","")
$vstestconsole="`"C:\Program Files (x86)\Microsoft Visual Studio\2017\Community\Common7\IDE\CommonExtensions\Microsoft\TestWindow\vstest.console.exe`""
Write-Host "Build config: $buildConfig"
Write-Host "AdditionalMsBuildParameter : $additionalParams"
Write-Host "SolutionList : $solutionList"

#####################################Functions################################################################################################
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


function Verify-IsUnitTestProject{
    param( [string]$ProjectType)  
    $utestprojGuid = @(
      "{3AC096D0-A1C2-E12C-1390-A8335801FDAB}"
    )
    $listOfGuids=$valueContent.Split(";")
    foreach($projectGuid in $listOfGuids){
      if($utestprojGuid -Contains $projectGuid ){
        return $TRUE
      }
    }
    return $FALSE
  }
  
#####################################Functions################################################################################################
$currentDir= Get-Location
$outputTestDir="$($currentDir.path)\JenkinsTestOutput"

if(Test-Path $outputTestDir){
    Clear-Content -Path $outputTestDir -Force
    Write-Host "cleaned: $outputTestDir"
  }
  else {
    New-Item -ItemType "directory" -Path $outputTestDir -Force   
  }

foreach($solutionPath in $solutionList){
    $SolutionFile="$($currentDir.path)\$solutionPath"
    $BasePath=$currentDir
    $projects= Get-ProjectsPath -SolutionFile $SolutionFile
    Foreach($project in $projects){
        $projectFolder=Split-Path -Path "$BasePath\$($project.File)"
        $outputPath=Get-OutputhPath -BasePath $BasePath -Project $project -BuildConfiguration $BuildConfiguration

        $namespace=@{default="http://schemas.microsoft.com/developer/msbuild/2003" }
        $valueContent= Select-Xml -Path "$BasePath\$($project.File)" -Xpath "/default:Project/default:PropertyGroup/default:ProjectTypeGuids/text()" -Namespace $namespace   | Select-Object -Expand node | Select-Object -Expand Value
        $assemblyName= Select-Xml -Path "$BasePath\$($project.File)" -Xpath "/default:Project/default:PropertyGroup/default:AssemblyName/text()" -Namespace $namespace   | Select-Object -Expand node | Select-Object -Expand Value
        Write-Host "Content for Project Type Guid:"
        Write-Host $valueContent
        if ($valueContent) { 
            Write-Host "Project name with project guid: $project.Name"
            $IsUnitTestProject=Verify-IsUnitTestProject $valueContent
            if ($IsUnitTestProject) {
                Write-Host "*****************Is a unit test project****************"
                New-Item -ItemType "directory" -Path "$($outputTestDir)\$($project.Name)" -Force 
                Write-Host "OutputPath lib: $($projectFolder)\$($outputPath)$($assemblyName).dll"
                
                New-Item -ItemType "directory" -Path "$($outputTestDir)\$($project.Name)" -Force 

                $testBinary="$($projectFolder)\$($outputPath)$($assemblyName).dll"
                $cmdArgumentsToRunVsTest="/k $vstestconsole $testBinary /ResultsDirectory:$($outputTestDir)\$($project.Name) /logger:trx"
                $buildCommand=Start-Process cmd.exe -ArgumentList $cmdArgumentsToRunVsTest -NoNewWindow -PassThru
                Wait-Process -Id $buildCommand.id
            }
        }
    }
}

$trxFiles=Get-ChildItem -Path "$outputTestDir" -Recurse -Include *.trx
foreach($trxFile in $trxFiles){
    $DirectoryName=(Get-Item (Split-Path -Path $trxFile)).Name
    & "C:\ProgramData\chocolatey\bin\SaxonHE\bin\Transform.exe" -s:"$($trxFile)" -xsl:".\BuildScripts\trx-junitxml.xslt" -o:"$outputTestDir\$($DirectoryName).test.xml"
}
