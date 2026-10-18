#requires -Version 5.1
$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$copyScript = Join-Path $repositoryRoot 'New-PrivateAssessment1.ps1'
$normalisedScript = [IO.File]::ReadAllText($copyScript).Replace("`r`n", "`n")
$scriptHash = [BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes($normalisedScript))).Replace('-', '')
if (-not [IO.File]::ReadAllText((Join-Path $repositoryRoot 'README.md')).Contains($scriptHash)) { throw 'The README download command has a stale script checksum.' }
$realGit = (Get-Command git -CommandType Application | Select-Object -First 1).Source
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('agp-copy-test-' + [guid]::NewGuid().ToString('N'))
$shimRoot = Join-Path $testRoot 'cli with spaces'
New-Item -ItemType Directory -Path $shimRoot -Force | Out-Null
$sourceFixture = Join-Path $testRoot 'source fixture'
& $realGit init -b main $sourceFixture | Out-Null
& $realGit -C $sourceFixture config user.name 'Fixture Student'
& $realGit -C $sourceFixture config user.email 'student@example.invalid'
Set-Content -LiteralPath (Join-Path $sourceFixture 'Platformer3D.slnx') -Value '<Solution />'
& $realGit -C $sourceFixture add .
& $realGit -C $sourceFixture commit -m baseline | Out-Null
$branches = @('main', 'particle-effect', 'post-process', 'shader', 'rising-water')
foreach ($branch in $branches | Where-Object { $_ -ne 'main' }) {
    & $realGit -C $sourceFixture switch -c $branch main 2>$null
    Set-Content -LiteralPath (Join-Path $sourceFixture "$branch.txt") -Value $branch
    & $realGit -C $sourceFixture add .
    & $realGit -C $sourceFixture commit -m $branch | Out-Null
}
& $realGit -C $sourceFixture switch main 2>$null

@'
$ErrorActionPreference = 'Stop'
$arguments = @($args)
($arguments | ConvertTo-Json -Compress) | Add-Content -LiteralPath $env:AGP_TEST_LOG
if ($arguments[0] -eq 'auth') {
    if ($arguments[1] -eq 'git-credential') {
        [Console]::In.ReadToEnd() | Out-Null
        [Console]::Out.WriteLine('username=fixture-student')
        [Console]::Out.WriteLine('password=fixture-only-placeholder')
        exit 0
    }
    if ($arguments -notcontains 'workflow') { throw 'Workflow permission must be requested.' }
    if ($env:AGP_TEST_SCENARIO -eq 'auth-failure') { exit 1 }
    exit 0
}
if ($arguments[0] -eq 'repo' -and $arguments[1] -eq 'create') {
    if ($arguments -notcontains '--private') { throw 'Private creation was not requested.' }
    & $env:AGP_TEST_GIT init --bare -b main $env:AGP_TEST_PRIVATE | Out-Null
    exit $LASTEXITCODE
}
if ($arguments[0] -eq 'repo' -and $arguments[1] -eq 'edit') { exit 0 }
if ($arguments[0] -eq 'api') {
    $endpoint = $arguments[3]
    if ($endpoint -eq 'user') {
        $login = if ($env:AGP_TEST_SCENARIO -eq 'wrong-account') { 'someone-else' } else { 'fixture-student' }
        @{ login = $login; id = 9001 } | ConvertTo-Json -Compress
        exit 0
    }
    if ($endpoint -like '*/branches?per_page=*') {
        $items = @(& $env:AGP_TEST_GIT "--git-dir=$env:AGP_TEST_PRIVATE" for-each-ref '--format=%(refname:short)%09%(objectname)' refs/heads | ForEach-Object {
            $name, $sha = $_ -split "`t", 2
            @{ name = $name; commit = @{ sha = $sha } }
        })
        ConvertTo-Json -InputObject $items -Compress -Depth 4
        exit 0
    }
    if (-not (Test-Path -LiteralPath $env:AGP_TEST_PRIVATE)) {
        $code = if ($env:AGP_TEST_SCENARIO -eq 'network-error') { 500 } else { 404 }
        [Console]::Error.WriteLine("gh: fixture request failed (HTTP $code)")
        exit 1
    }
    @{
        private = ($env:AGP_TEST_SCENARIO -ne 'privacy-failure')
        owner = @{ login = 'fixture-student' }
        fork = $false
        full_name = 'fixture-student/AGP-Fixture'
        clone_url = 'https://github.com/fixture-student/AGP-Fixture.git'
        html_url = 'https://github.com/fixture-student/AGP-Fixture'
        default_branch = 'main'
    } | ConvertTo-Json -Compress
    exit 0
}
throw "Unexpected fixture command: $($arguments -join ' ')"
'@ | Set-Content -LiteralPath (Join-Path $shimRoot 'FakeGh.ps1') -Encoding utf8
'@echo off
@"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0FakeGh.ps1" %*
@exit /b %errorlevel%
' | Set-Content -LiteralPath (Join-Path $shimRoot 'gh.cmd') -Encoding ascii

$environmentNames = @('PATH','GIT_CONFIG_GLOBAL','GIT_CONFIG_NOSYSTEM','GIT_TERMINAL_PROMPT','GH_CONFIG_DIR','GH_TOKEN','GITHUB_TOKEN','AGP_TEST_LOG','AGP_TEST_GIT','AGP_TEST_PRIVATE','AGP_TEST_SCENARIO')
$savedEnvironment = @{}
foreach ($name in $environmentNames) { $savedEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process') }
try {
    $env:PATH = "$shimRoot;$env:PATH"
    if ((Get-Command gh -CommandType Application | Select-Object -First 1).Source -ne (Join-Path $shimRoot 'gh.cmd')) { throw 'The test must use the fake CLI, never a real GitHub login.' }
    $env:GH_TOKEN = $null
    $env:GITHUB_TOKEN = $null
    $env:GH_CONFIG_DIR = Join-Path $testRoot 'isolated gh configuration'
    $env:GIT_CONFIG_NOSYSTEM = '1'
    $env:GIT_TERMINAL_PROMPT = '0'
    $env:AGP_TEST_GIT = $realGit
    $engines = @((Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'))
    $pwsh = Get-Command pwsh -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($pwsh) { $engines += $pwsh.Source }
    $testCount = 0
    foreach ($engine in $engines) {
        foreach ($scenario in @('automatic','vscode','auth-failure','wrong-account','existing-folder','existing-repo','privacy-failure','network-error')) {
            $caseRoot = Join-Path $testRoot ([guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $caseRoot | Out-Null
            $env:AGP_TEST_PRIVATE = Join-Path $caseRoot 'private fixture.git'
            $env:AGP_TEST_LOG = Join-Path $caseRoot 'commands.jsonl'
            $env:AGP_TEST_SCENARIO = $scenario
            $env:GIT_CONFIG_GLOBAL = Join-Path $caseRoot 'isolated git configuration'
            $sourceUri = ([uri]($sourceFixture + [IO.Path]::DirectorySeparatorChar)).AbsoluteUri
            $privateUri = ([uri]($env:AGP_TEST_PRIVATE + [IO.Path]::DirectorySeparatorChar)).AbsoluteUri
            & $realGit config --file $env:GIT_CONFIG_GLOBAL "url.$sourceUri.insteadOf" 'https://github.com/brockbankl/BFC-Advanced-Games-Programming-Assessment-1-Catchup.git'
            & $realGit config --file $env:GIT_CONFIG_GLOBAL "url.$privateUri.insteadOf" 'https://github.com/fixture-student/AGP-Fixture.git'
            if ($scenario -eq 'existing-repo') { & $realGit init --bare -b main $env:AGP_TEST_PRIVATE | Out-Null }
            $destinationParent = Join-Path $caseRoot 'projects with spaces'
            $project = Join-Path $destinationParent 'AGP-Fixture'
            if ($scenario -eq 'existing-folder') {
                New-Item -ItemType Directory -Path $project -Force | Out-Null
                Set-Content -LiteralPath (Join-Path $project 'keep.txt') -Value 'student work'
            }
            $method = if ($scenario -eq 'vscode') { 'VSCode' } else { 'Automatic' }
            $previousPreference = $ErrorActionPreference
            $ErrorActionPreference = 'Continue'
            $output = @(& $engine -NoProfile -ExecutionPolicy Bypass -File $copyScript -RepositoryName 'AGP-Fixture' -GitHubUsername 'fixture-student' -DestinationParent $destinationParent -SignInMethod $method -NoOpen 2>&1)
            $exitCode = $LASTEXITCODE
            $ErrorActionPreference = $previousPreference
            $expectedSuccess = $scenario -in @('automatic','vscode','auth-failure')
            if (($exitCode -eq 0) -ne $expectedSuccess) { $output | Write-Host; throw "Unexpected exit code in $scenario ($engine): $exitCode" }
            $commands = if (Test-Path -LiteralPath $env:AGP_TEST_LOG) { @(Get-Content -LiteralPath $env:AGP_TEST_LOG) } else { @() }
            if ($scenario -ne 'automatic' -and $scenario -ne 'privacy-failure' -and @($commands | Where-Object { $_ -match '"create"' }).Count -gt 0) { throw "Unexpected repository creation in $scenario" }
            if ($scenario -eq 'automatic') {
                foreach ($branch in $branches) {
                    $sourceHead = & $realGit -C $sourceFixture rev-parse $branch
                    $copyHead = & $realGit "--git-dir=$env:AGP_TEST_PRIVATE" rev-parse "refs/heads/$branch"
                    if ($sourceHead -ne $copyHead) { throw "Branch $branch was not copied unchanged" }
                    $upstream = & $realGit -C $project config "branch.$branch.remote"
                    if ($upstream -ne 'origin') { throw 'Branch upstream was not switched to the private copy' }
                }
                $helpers = @(& $realGit -C $project config --local --get-all 'credential.https://github.com.helper')
                if ($helpers.Count -ne 2 -or $helpers[0] -ne '' -or $helpers[1] -notlike "!* auth git-credential") { throw 'Local credential helper reset/selection did not survive argument quoting' }
                $credential = @('protocol=https', 'host=github.com', '') | & $realGit -C $project credential fill
                if ($LASTEXITCODE -ne 0 -or $credential -notcontains 'username=fixture-student') { throw 'Git could not invoke the selected credential helper from a path with spaces' }
                if ((& $realGit -C $project config user.email) -ne '9001+fixture-student@users.noreply.github.com') { throw 'Commit identity was not set locally' }
            }
            if ($scenario -in @('vscode','auth-failure')) {
                if (@(& $realGit -C $project remote).Count -ne 0) { throw 'VS Code publishing must start without a remote' }
                foreach ($branch in $branches) { & $realGit -C $project show-ref --verify --quiet "refs/heads/$branch"; if ($LASTEXITCODE -ne 0) { throw 'VS Code fallback lost a lesson branch' } }
                if (Test-Path -LiteralPath $env:AGP_TEST_PRIVATE) { throw 'The VS Code route must not create a remote repository automatically' }
            }
            if ($scenario -eq 'privacy-failure' -and @(& $realGit "--git-dir=$env:AGP_TEST_PRIVATE" for-each-ref refs/heads).Count -ne 0) { throw 'Files were pushed before privacy verification' }
            if ($scenario -eq 'existing-folder' -and (Get-Content -LiteralPath (Join-Path $project 'keep.txt')) -ne 'student work') { throw 'Existing student files changed' }
            $testCount++
            Write-Host "PASS: $scenario using $([IO.Path]::GetFileName($engine))"
        }
    }
    Write-Host "PASS: $testCount private-copy integration checks; real local Git, mocked GitHub, no real accounts created."
}
finally {
    foreach ($name in $environmentNames) { [Environment]::SetEnvironmentVariable($name, $savedEnvironment[$name], 'Process') }
}
exit 0
