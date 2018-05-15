param(
  [string]$SolutionFile="",
  [string]$BasePath="",
  [string]$websitename="ecnweb",
  [string]$environment="dev",
  [string]$envfile=""
)

$projects=Get-Content $SolutionFile | Select-String "Project\(" |
    ForEach-Object {
      $projectParts=$_ -Split '[,=]' | ForEach-Object { $_.Trim('[ "{}]')};
      New-Object PSObject -Property @{
        Name= $projectParts[1];
        File= $projectParts[2];
        Guid= $projectParts[3];
      }
    }

Foreach($project in $projects){
  Write-Host $project.Name
  Get-Content "$BasePath\$project.File" | Select-String "<PropertyGroup Condition=" |
  ForEach-Object {
    Write-Host $_
  }
}