
<#
.SYNOPSIS
  List repositories for a GitHub user or organization using GitHub CLI (gh).

.DESCRIPTION
  Supports filtering by visibility and forks, limits results, and outputs to console, JSON, or CSV.
  Uses 'gh repo list' with --json for efficient, structured output.

.PARAMETER Owner
  GitHub owner name (user or org), e.g., 'microsoft' or 'andrewleyba'.

.PARAMETER IsOrg
  Switch to treat Owner as an organization (for clarity in help text; 'gh repo list' handles both).

.PARAMETER Limit
  Maximum number of repositories to return (default 100).

.PARAMETER Visibility
  Filter by repo visibility: public, private, or internal (optional).

.PARAMETER IncludeForks
  Include forked repositories (default: include). If false, forks are excluded.

.PARAMETER SourceOnly
  Show only repositories owned by the Owner (exclude forks owned by others).

.PARAMETER Topics
  Optional topic filter (string). Returns repos containing this topic.

.PARAMETER Output
  Output mode: Console (default), Json, or Csv.

.PARAMETER OutFile
  Path to write JSON or CSV output (optional). If omitted, writes to screen.

.PARAMETER OpenInBrowser
  Switch to open the Owner’s repositories page in the browser after listing.

.EXAMPLE
  .\Get-GhRepositories.ps1 -Owner "microsoft" -Limit 50 -Visibility public -Output Csv -OutFile .\repos.csv

.EXAMPLE
  .\Get-GhRepositories.ps1 -Owner "andrewleyba" -IncludeForks:$false -Topics "powershell" -Output Json -OutFile .\repos.json

.NOTES
  Requires GitHub CLI (gh) and authentication: gh auth login
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$Owner,

  [switch]$IsOrg,

  [int]$Limit = 100,

  [ValidateSet('public','private','internal')]
  [string]$Visibility,

  [bool]$IncludeForks = $true,

  [switch]$SourceOnly,

  [string]$Topics,

  [ValidateSet('Console','Json','Csv')]
  [string]$Output = 'Console',

  [string]$OutFile,

  [switch]$OpenInBrowser
)

function Ensure-GhReady {
  if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw "GitHub CLI 'gh' is not installed. Install it (e.g., 'winget install --id GitHub.cli') and run 'gh auth login'."
  }

  # Ensure we’re authenticated
  $authStatus = & gh auth status 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw "Not authenticated with GitHub. Run: gh auth login"
  }
}

function Get-GhRepoList {
  param(
    [string]$Owner,
    [int]$Limit,
    [string]$Visibility,
    [bool]$IncludeForks,
    [switch]$SourceOnly
  )

  # Build base args for gh repo list
  $args = @('repo','list',$Owner,'-L',"$Limit",'--json',
    'name,fullName,description,visibility,isPrivate,isFork,archived,sshUrl,url,homepageUrl,defaultBranchRef,updatedAt,createdAt,stargazerCount,watchersCount,issues,openIssues,licenseInfo,topics')

  if ($Visibility) {
    $args += @('--visibility', $Visibility)
  }

  if (-not $IncludeForks) {
    $args += '--no-forks'
  } else {
    # Optionally show only source repos (owned by the owner)
    if ($SourceOnly) {
      $args += '--source'
    }
  }

  # Invoke gh and parse JSON
  $json = & gh @args
  if ($LASTEXITCODE -ne 0) {
    throw "gh repo list command failed. Ensure the owner is correct and you have permissions."
  }
  $repos = $json | ConvertFrom-Json

  return $repos
}

function Filter-ByTopic {
  param(
    [Object[]]$Repos,
    [string]$Topics
  )

  if ([string]::IsNullOrWhiteSpace($Topics)) { return $Repos }

  # Topic filter (case-insensitive contains)
  $topicFilter = $Topics.Trim()
  $Repos | Where-Object {
    $_.topics -and ($_.topics | ForEach-Object { $_ }) -match [regex]::Escape($topicFilter)
  }
}

function Format-Console {
  param([Object[]]$Repos)

  if (-not $Repos -or $Repos.Count -eq 0) {
    Write-Host "No repositories found." -ForegroundColor Yellow
    return
  }

  # Pretty console output
  $Repos |
    Sort-Object -Property updatedAt -Descending |
    Select-Object @{Name='Name';Expression={$_.name}},
                  @{Name='Visibility';Expression={$_.visibility}},
                  @{Name='Fork';Expression={$_.isFork}},
                  @{Name='Archived';Expression={$_.archived}},
                  @{Name='Stars';Expression={$_.stargazerCount}},
                  @{Name='Updated';Expression={($_.updatedAt)}},
                  @{Name='URL';Expression={$_.url}} |
    Format-Table -AutoSize
}

function Write-Json {
  param([Object[]]$Repos, [string]$Path)

  $jsonOut = $Repos | ConvertTo-Json -Depth 6
  if ($Path) {
    $jsonOut | Set-Content -Path $Path -Encoding UTF8
    Write-Host "JSON written to $Path" -ForegroundColor Green
  } else {
    $jsonOut
  }
}

function Write-Csv {
  param([Object[]]$Repos, [string]$Path)

  $flat = $Repos | ForEach-Object {
    [pscustomobject]@{
      Name         = $_.name
      FullName     = $_.fullName
      Description  = $_.description
      Visibility   = $_.visibility
      IsPrivate    = $_.isPrivate
      IsFork       = $_.isFork
      Archived     = $_.archived
      Stars        = $_.stargazerCount
      UpdatedAt    = $_.updatedAt
      CreatedAt    = $_.createdAt
      DefaultBranch= $_.defaultBranchRef?.name
      URL          = $_.url
      SSHUrl       = $_.sshUrl
      HomepageUrl  = $_.homepageUrl
      License      = $_.licenseInfo?.spdxId
      Topics       = ($_.topics -join ';')
    }
  }

  if ($Path) {
    $flat | Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8
    Write-Host "CSV written to $Path" -ForegroundColor Green
  } else {
    $flat | Format-Table -AutoSize
  }
}

try {
  Ensure-GhReady

  # Retrieve repositories
  $repos = Get-GhRepoList -Owner $Owner -Limit $Limit -Visibility $Visibility -IncludeForks $IncludeForks -SourceOnly:$SourceOnly

  # Topic filter
  $repos = Filter-ByTopic -Repos $repos -Topics $Topics

  # Output selection
  switch ($Output) {
    'Console' { Format-Console -Repos $repos }
    'Json'    { Write-Json -Repos $repos -Path $OutFile }
    'Csv'     { Write-Csv -Repos $repos -Path $OutFile }
  }

  if ($OpenInBrowser) {
    # Open the repositories page in browser
    $url = "https://github.com/$Owner?tab=repositories"
    Write-Host "Opening $url..." -ForegroundColor Cyan
    Start-Process $url
   }
}
catch {
  Write-Error $_.Exception.Message
  exit 1
}