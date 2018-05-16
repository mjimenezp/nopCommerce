$ErrorActionPreference = "Stop"
if (-not (Test-Path env:AdditionalMsBuildParameter)) { 
  $env:AdditionalMsBuildParameter = " "
}
$namespace=@{default="http://schemas.microsoft.com/developer/msbuild/2003" }       

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
    Write-Host "Solution file get project path: $SolutionFile"
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
    param( [string]$projectPath)  
    $result=$FALSE
    $utestprojGuid = @(
      "{3AC096D0-A1C2-E12C-1390-A8335801FDAB}"
    )
    $valueContent= Select-Xml -Path $projectPath -Xpath "/default:Project/default:PropertyGroup/default:ProjectTypeGuids/text()" -Namespace $namespace   | Select-Object -Expand node | Select-Object -Expand Value
    if(!($valueContent -eq $null)){
        $listOfGuids=$valueContent.Split(";")
        foreach($projectGuid in $listOfGuids){
            if($utestprojGuid -Contains $projectGuid ){
                $result=$TRUE
            }
        }
    }
    if(!$result){
        Write-Host "Not determined yet if is unit test"
        $nunitFrameworkDll= Select-Xml -Path $projectPath -Xpath "/default:Project/default:ItemGroup/default:Reference[@Include[contains(.,'nunit.framework')]]/default:HintPath/text()"  -Namespace $namespace   | Select-Object -Expand node | Select-Object -Expand Value
        $nunitImportProp= Select-Xml -Path $projectPath -Xpath "/default:Project/default:Import[@Project[contains(.,'NUnit')]]/@Project" -Namespace $namespace   | Select-Object -Expand node | Select-Object -Expand Value
        Write-Host "NunitFramework dll: $nunitFrameworkDll"
        Write-Host "NunitFramework prop target: $nunitImportProp"
        $result=$nunitFrameworkDll -or $nunitImportProp
    }
    return $result
  }

  function Verify-IsNUnitStandAlone{
    param( [string]$projectPath)  
    $nunitFrameworkDll= Select-Xml -Path $projectPath -Xpath "/default:Project/default:ItemGroup/default:Reference[@Include[contains(.,'nunit.framework')]]/default:HintPath/text()"  -Namespace $namespace   | Select-Object -Expand node | Select-Object -Expand Value
    $nunitImportProp= Select-Xml -Path $projectPath -Xpath "/default:Project/default:Import[@Project[contains(.,'NUnit')]]/@Project" -Namespace $namespace   | Select-Object -Expand node | Select-Object -Expand Value
    return $nunitFrameworkDll -and (!$nunitImportProp)
  }

  function Verify-HaveNUnitTestProp{
    param( [string]$projectPath)  
    $result=$FALSE
    $nunitImportProp= Select-Xml -Path $projectPath -Xpath "/default:Project/default:Import[@Project[contains(.,'NUnit')]]/@Project" -Namespace $namespace   | Select-Object -Expand node | Select-Object -Expand Value
    return $nunitImportProp
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
    $SolutionFile=[System.IO.Path]::Combine("$($currentDir.path)", ("$solutionPath" -replace  "/","`\"))
    $BaseSolutionDir= [System.IO.Path]::GetDirectoryName("$SolutionFile")
    $BasePath=$currentDir
    Write-Host "---- $($currentDir.path)"
    Write-Host "---- $solutionPath"
    Write-Host "---- $SolutionFile"
    $projects= Get-ProjectsPath -SolutionFile $SolutionFile

    Foreach($project in $projects){
        $projectFolder=Split-Path -Path "$BasePath\$($project.File)"
        Write-Host "**********************************$($project.Name)  unit test******************************************"
        Write-Host $projectFolder;
        Write-Host $BasePath;
        Write-Host $BaseSolutionDir;
		Write-Host (Split-Path -Path $project.File)

        $outputPath=Get-OutputhPath -BasePath $BaseSolutionDir -Project $project -BuildConfiguration $BuildConfiguration 
        $assemblyName= Select-Xml -Path "$BaseSolutionDir\$($project.File)" -Xpath "/default:Project/default:PropertyGroup/default:AssemblyName/text()" -Namespace $namespace   | Select-Object -Expand node | Select-Object -Expand Value
        Write-Host "Content for Project Type Guid:"
        Write-Host "Project name with project guid: $project.Name"
        $IsUnitTestProject=Verify-IsUnitTestProject "$BaseSolutionDir\$($project.File)" 
        if ($IsUnitTestProject) {
            Write-Host "*****************Is a unit test project****************"
            New-Item -ItemType "directory" -Path "$($outputTestDir)\$($project.Name)" -Force 
            Write-Host "OutputPath lib: $($BaseSolutionDir)\$($outputPath)$($assemblyName).dll"
            New-Item -ItemType "directory" -Path "$($outputTestDir)\$($project.Name)" -Force 
            $testBinary="$($BaseSolutionDir)\$(Split-Path -Path $project.File)\$($outputPath)$($assemblyName).dll"
            if(Verify-IsNUnitStandAlone "$BaseSolutionDir\$($project.File)"){
				choco install nunit-console-runner -y
                & nunit3-console.exe $testBinary --result="$($outputTestDir)\$($project.Name).test.xml;transform=$($BasePath)\BuildScripts\nunit3-junit.xslt"
            }
            else{
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
exit 0