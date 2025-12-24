Clear-Host
$rep = & gh api repos/RenPSG/mirror-StellarTechSol-cf_ddc/branches --jq ".[].name"
$rep | Out-GridView 
Write-Host $rep
gh repo list RenPSG --limit 1000 --json name|ConvertFrom-Json| Where-Object{$_.name -match 'mirror-Stellar'}| Select-Object name| Out-GridView
gh api -X DELETE "repos/$owner/$repo/git/refs/heads/$name"