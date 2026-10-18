#requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('Automatic', 'VSCode')]
    [string]$SignInMethod,
    [string]$RepositoryName,
    [string]$GitHubUsername,
    [string]$DestinationParent,
    [switch]$NoOpen
)

$ErrorActionPreference = 'Stop'
$sourceUrl = 'https://github.com/brockbankl/BFC-Advanced-Games-Programming-Assessment-1-Catchup.git'
$lessonBranches = @('particle-effect', 'post-process', 'shader', 'rising-water')
$allBranches = @('main') + $lessonBranches
$gitCommand = Get-Command git -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $gitCommand) { throw 'Git is missing. Ask your lecturer or college IT to install Git, then run this again.' }
$gitExecutable = $gitCommand.Source
$projectPath = $null
$previousGhHost = $env:GH_HOST
$previousTls = [Net.ServicePointManager]::SecurityProtocol

function Invoke-ProjectGit {
    param([string[]]$Arguments)
    & $gitExecutable @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Git failed: $($Arguments -join ' '). Keep this error visible for your lecturer." }
}

function Get-GitHubCli {
    $installed = Get-Command gh -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($installed) { return $installed.Source }
    if (-not $env:LOCALAPPDATA) { throw 'GitHub CLI is unavailable. Run again with -SignInMethod VSCode.' }

    Write-Host 'Preparing a user-level GitHub CLI from the official GitHub release (no administrator installation).'
    $release = Invoke-RestMethod 'https://api.github.com/repos/cli/cli/releases/latest' -Headers @{ 'User-Agent' = 'BFC-AGP-Assessment1' }
    $architecture = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'arm64' } else { 'amd64' }
    $asset = $release.assets | Where-Object { $_.name -match "_windows_$architecture\.zip$" } | Select-Object -First 1
    if (-not $asset -or $asset.digest -notmatch '^sha256:([a-fA-F0-9]{64})$') {
        throw 'Could not find a checksum-verified GitHub CLI download. Use -SignInMethod VSCode instead.'
    }
    $expectedHash = $Matches[1]
    if ($asset.browser_download_url -notlike 'https://github.com/cli/cli/releases/download/*') { throw 'Unexpected GitHub CLI download location.' }
    $toolRoot = Join-Path $env:LOCALAPPDATA ('BFC-AGP\Tools\GitHubCLI\' + $release.tag_name)
    $executable = Join-Path $toolRoot 'bin\gh.exe'
    if (-not (Test-Path -LiteralPath $executable)) {
        New-Item -ItemType Directory -Path $toolRoot -Force | Out-Null
        $archivePath = Join-Path $toolRoot $asset.name
        Invoke-WebRequest $asset.browser_download_url -UseBasicParsing -OutFile $archivePath
        if ((Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash -ne $expectedHash) { throw 'GitHub CLI checksum did not match. The download will not be run.' }
        Expand-Archive -LiteralPath $archivePath -DestinationPath $toolRoot -Force
    }
    if (-not (Test-Path -LiteralPath $executable)) { throw 'GitHub CLI could not be prepared. Use -SignInMethod VSCode instead.' }
    return $executable
}

function Get-GhResult {
    param([string[]]$Arguments)
    # Windows PowerShell 5.1 turns redirected native stderr into error records.
    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $lines = @(& $script:ghExecutable @Arguments 2>&1)
        $exitCode = $LASTEXITCODE
    }
    finally { $ErrorActionPreference = $previousPreference }
    return [pscustomobject]@{ ExitCode = $exitCode; Text = (($lines | ForEach-Object { $_.ToString() }) -join "`n") }
}

function Invoke-GhChecked {
    param([string[]]$Arguments)
    $result = Get-GhResult $Arguments
    if ($result.ExitCode -ne 0) { throw "GitHub command failed: $($result.Text)" }
    return $result.Text
}

function Open-Project {
    Write-Host "Project folder: $projectPath"
    if (-not $NoOpen) {
        $editor = Get-Command code -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($editor) { & $editor.Source --new-window $projectPath }
        else { Write-Host 'Open this complete folder in Visual Studio Code.' }
    }
}

function Prepare-VSCodePublishing {
    # VS Code's Publish to GitHub needs a local repository without a remote.
    # All five local branches remain intact; nothing is deleted from GitHub.
    Invoke-ProjectGit @('-C', $projectPath, 'remote', 'remove', 'catchup')
    Write-Host ''
    Write-Host 'READY FOR VS CODE SIGN-IN (NETLAB FALLBACK)'
    Write-Host '1. In VS Code, open Source Control (Ctrl+Shift+G).'
    Write-Host '2. Run Publish to GitHub (also available through Ctrl+Shift+P).'
    Write-Host '3. Sign in to YOUR GitHub account and choose a PRIVATE repository.'
    Write-Host '4. Once main is published, switch to each of the four lesson branches and use Publish Branch.'
    Write-Host "Lesson branches: $($lessonBranches -join ', ')"
    Write-Host '5. Check on GitHub that the repository says Private and shows all five branches.'
    Write-Host 'This route prepares the clone; the VS Code publishing steps create your private repository.'
    Open-Project
}

try {
    [Net.ServicePointManager]::SecurityProtocol = $previousTls -bor [Net.SecurityProtocolType]::Tls12
    if ([string]::IsNullOrWhiteSpace($SignInMethod)) {
        Write-Host '1 = Browser/GitHub CLI sign-in: creates and verifies your private repository automatically.'
        Write-Host '2 = VS Code Source Control sign-in: Netlab fallback if terminal sign-in is still broken.'
        $choice = Read-Host 'Sign-in method [1]'
        if ([string]::IsNullOrWhiteSpace($choice) -or $choice -eq '1') { $SignInMethod = 'Automatic' }
        elseif ($choice -eq '2') { $SignInMethod = 'VSCode' }
        else { throw 'Choose 1 for automatic sign-in or 2 for the VS Code Netlab fallback.' }
    }
    if ([string]::IsNullOrWhiteSpace($RepositoryName)) {
        $RepositoryName = Read-Host 'Name for your new private repository [AGP-Assessment-1]'
        if ([string]::IsNullOrWhiteSpace($RepositoryName)) { $RepositoryName = 'AGP-Assessment-1' }
    }
    if ($RepositoryName -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]{0,99}$' -or $RepositoryName -match '\.git$') {
        throw 'Use a repository name starting with a letter or number, containing only letters, numbers, dots, hyphens or underscores, without a .git ending.'
    }
    if ([string]::IsNullOrWhiteSpace($DestinationParent)) {
        $documents = [Environment]::GetFolderPath('MyDocuments')
        if ([string]::IsNullOrWhiteSpace($documents)) { $documents = Join-Path $env:USERPROFILE 'Documents' }
        $DestinationParent = Join-Path $documents 'projects'
    }
    $projectPath = [IO.Path]::GetFullPath((Join-Path $DestinationParent $RepositoryName))
    if (Test-Path -LiteralPath $projectPath) { throw "The folder already exists: $projectPath. Your files have not been changed. Choose a new name or open your existing project." }
    New-Item -ItemType Directory -Path $DestinationParent -Force | Out-Null
    Write-Host 'Downloading the Assessment 1 baseline and all four lesson branches...'
    Invoke-ProjectGit @('clone', '--origin', 'catchup', '--branch', 'main', $sourceUrl, $projectPath)
    foreach ($branch in $lessonBranches) {
        Invoke-ProjectGit @('-C', $projectPath, 'branch', '--track', $branch, "catchup/$branch")
    }
    if ($SignInMethod -eq 'VSCode') { Prepare-VSCodePublishing; return }

    if ($env:GH_TOKEN -or $env:GITHUB_TOKEN) { throw 'An environment GitHub token is set in this terminal. Use a normal PowerShell window with your own sign-in, or the VS Code route.' }
    $env:GH_HOST = 'github.com'
    try { $script:ghExecutable = Get-GitHubCli }
    catch {
        Write-Host "GitHub CLI could not be prepared: $($_.Exception.Message)"
        Write-Host 'Preparing the VS Code Source Control route instead.'
        Prepare-VSCodePublishing
        return
    }
    if ([string]::IsNullOrWhiteSpace($GitHubUsername)) { $GitHubUsername = Read-Host 'Your GitHub username (not your password or college login)' }
    if ($GitHubUsername -notmatch '^[A-Za-z0-9](?:[A-Za-z0-9-]{0,37}[A-Za-z0-9])?$') { throw 'Enter your GitHub username, using letters, numbers or hyphens.' }
    Write-Host 'Complete GitHub sign-in in the browser using YOUR account. The script never asks for your password.'
    Write-Host 'If the browser does not open, use the device-login URL and one-time code printed by GitHub CLI.'
    & $script:ghExecutable auth login --hostname github.com --git-protocol https --web --scopes workflow
    if ($LASTEXITCODE -ne 0) {
        Write-Host 'Terminal sign-in did not complete. Preparing the VS Code Source Control route instead.'
        Prepare-VSCodePublishing
        return
    }
    $account = (Invoke-GhChecked @('api', '--hostname', 'github.com', 'user')) | ConvertFrom-Json
    if ($account.login -ine $GitHubUsername) { throw "GitHub signed in as $($account.login), but you entered $GitHubUsername. No repository was created. Sign in with your own account." }
    $fullName = "$($account.login)/$RepositoryName"
    $existing = Get-GhResult @('api', '--hostname', 'github.com', "repos/$fullName")
    if ($existing.ExitCode -eq 0) { throw "$fullName already exists on GitHub. It has not been changed. Choose a different repository name." }
    if ($existing.Text -notmatch 'HTTP 404') { throw "Could not check whether the destination exists: $($existing.Text)" }

    Write-Host "Creating your PRIVATE repository: $fullName"
    Invoke-GhChecked @('repo', 'create', $fullName, '--private', '--disable-wiki', '--description', 'My AGP Assessment 1 catchup project') | Write-Host
    $created = (Invoke-GhChecked @('api', '--hostname', 'github.com', "repos/$fullName")) | ConvertFrom-Json
    if ($created.private -ne $true -or $created.owner.login -ine $account.login -or $created.fork -ne $false -or $created.full_name -ine $fullName) {
        throw 'The new repository did not pass the owner/private/independent-copy check. No project files have been pushed.'
    }
    $expectedUrl = "https://github.com/$fullName.git"
    if ($created.clone_url -ine $expectedUrl) { throw 'Unexpected destination URL. No project files have been pushed.' }
    Invoke-ProjectGit @('-C', $projectPath, 'remote', 'add', 'origin', $expectedUrl)

    # Scope the credential helper and commit identity to this clone only.
    # Single-quote the executable for Git's shell, including paths with spaces/apostrophes.
    $helperPath = $script:ghExecutable.Replace('\', '/').Replace("'", "'\''")
    $helper = "!'$helperPath' auth git-credential"
    $emptyHelper = if ($PSVersionTable.PSVersion.Major -lt 7) { '""' } else { '' }
    Invoke-ProjectGit @('-C', $projectPath, 'config', '--local', '--add', 'credential.https://github.com.helper', $emptyHelper)
    Invoke-ProjectGit @('-C', $projectPath, 'config', '--local', '--add', 'credential.https://github.com.helper', $helper)
    Invoke-ProjectGit @('-C', $projectPath, 'config', '--local', 'user.name', $account.login)
    Invoke-ProjectGit @('-C', $projectPath, 'config', '--local', 'user.email', "$($account.id)+$($account.login)@users.noreply.github.com")
    Invoke-ProjectGit (@('-C', $projectPath, 'push', '--atomic', '--set-upstream', 'origin') + $allBranches)
    Invoke-GhChecked @('repo', 'edit', $fullName, '--default-branch', 'main') | Out-Null
    Invoke-ProjectGit @('-C', $projectPath, 'config', '--local', 'remote.origin.gh-resolved', 'base')

    $remoteBranches = (Invoke-GhChecked @('api', '--hostname', 'github.com', "repos/$fullName/branches?per_page=100")) | ConvertFrom-Json
    foreach ($branch in $allBranches) {
        $localHead = Invoke-ProjectGit @('-C', $projectPath, 'rev-parse', "refs/heads/$branch")
        $remote = $remoteBranches | Where-Object { $_.name -eq $branch }
        if (-not $remote -or $remote.commit.sha -ne $localHead) { throw "The remote copy of $branch did not verify. Keep the project folder and show your lecturer this error." }
    }
    $final = (Invoke-GhChecked @('api', '--hostname', 'github.com', "repos/$fullName")) | ConvertFrom-Json
    if ($final.private -ne $true -or $final.default_branch -ne 'main' -or @($remoteBranches).Count -ne 5) { throw 'The final privacy/default-branch/five-branch check failed.' }
    Write-Host ''
    Write-Host 'PRIVATE COPY READY - all five branches verified.'
    Write-Host $final.html_url
    Write-Host 'Next: run Setup-Assessment1.cmd in your project folder. Combining the lesson branches is your challenge.'
    Open-Project
}
catch {
    if ($projectPath -and (Test-Path -LiteralPath $projectPath)) { Write-Host "Your existing/downloaded files are preserved in: $projectPath" }
    throw
}
finally {
    $env:GH_HOST = $previousGhHost
    [Net.ServicePointManager]::SecurityProtocol = $previousTls
}
