$branch = "OOC-2025.10"

[string[]]$repos = Get-Content .\repos.dat

for($i = 0; $i -lt $repos.count; $i++)
{
$repo = $repos[$i]
$target = if( $repo -eq "shared") { "app" } else { $repo }

$repo
$target 

(Get-Content .\template.txt) -replace "<reponame>", "$($repo)" -replace "<targetname>", $($target) -replace "<branchname>", $($branch) -replace "<currentpath>", $($PWD.Path) | Set-Content .\$($repo).txt

if(Test-Path $($repo))
{
   Remove-Item $($repo) -Recurse -Force
}

git clone -b $($branch) https://bitbucket.org/StellarTechSol/$($repo).git  

Remove-Item .\$($repo) -Include *.pbl -Recurse

orcascr220 /D runtime_version="22.0.0.1900" .\$($repo).txt

Remove-Item .\$($repo).txt
Remove-Item .\$($repo).log
}