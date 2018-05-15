Write-Host "Solution list: $env:SolutionList"
$solutionList = $env:SolutionList.Replace("\`"","").Replace("`'","").Split(",")

foreach($solutionPath in $solutionList){
    & nuget.exe restore ".\$solutionPath"
}