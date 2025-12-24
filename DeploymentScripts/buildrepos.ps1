[string[]]$repos = Get-Content .\repos.dat

for($i = 0; $i -lt $repos.count; $i++)
{
$repo = $repos[$i]
$target = if( $repo -eq "shared") { "app" } else { $repo }

$repo
$target 

pbc220 /c .\$($repo)\$($target).pbt > .\$($repo)\log.txt
}
