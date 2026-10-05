# Installs encypher through the release's install.ps1 the way a user does,
# then checks what the user gets. Run by release.yml's install-check job under
# Windows PowerShell 5.1 and PowerShell 7.
#
#   $env:BASE      release base URL: the published release, or a dry run's loopback mirror
#   $env:VERSION   the release version
#   $env:FIXTURE   directory holding signed-test.jpg and image_png.png
#   $env:ENCYPHER_INSTALL_DIR   optional install directory (default %LOCALAPPDATA%\Programs\encypher)
#   $env:ENCYPHER_API_KEY       optional: also sign a PNG and verify the result
#   $env:ENCYPHER_DOWNLOAD_URL  set by a dry run, read by the installer
#   $env:ENCYPHER_CHECK_UNPINNED  non-empty: install the README's unpinned way
$ErrorActionPreference = 'Stop'
$expected = '"client":\s*"' + [regex]::Escape($env:VERSION) + '"'
$seed = '%USERPROFILE%\encypher-seed'
$environment = 'HKCU:\Environment'

# A user Path entry that tracks a variable must survive the printed line.
$userPath = (Get-Item $environment).GetValue('Path', '', 'DoNotExpandEnvironmentNames')
if (($userPath -split ';') -notcontains $seed) {
    Set-ItemProperty $environment Path ("$seed;" + $userPath) -Type ExpandString
}

# Unpinned takes the script and the archive from latest/download and sets no
# ENCYPHER_VERSION, exactly as the README's main command does. Only a dry run
# asks for it: until promote, latest still points at the previous release.
$scriptUrl = "$env:BASE/download/v$env:VERSION/install.ps1"
$env:ENCYPHER_VERSION = $env:VERSION
if ($env:ENCYPHER_CHECK_UNPINNED) {
    $scriptUrl = "$env:BASE/latest/download/install.ps1"
    Remove-Item Env:\ENCYPHER_VERSION
}
# Each Write-Host record is one installer line, read from the record itself.
# Out-String would format the records, and Windows PowerShell 5.1 wraps that
# at the console width, splitting the long PATH line for new terminals.
function ConvertTo-InstallerLines {
    param([Parameter(ValueFromPipeline = $true)] $Record)
    process {
        $data = $Record
        if ($data -is [System.Management.Automation.InformationRecord]) { $data = $data.MessageData }
        if ($data -is [System.Management.Automation.HostInformationMessage]) { $data = $data.Message }
        "$data" -split "`r?`n"
    }
}
$lines = @((Invoke-RestMethod $scriptUrl | Invoke-Expression) 6>&1 | ConvertTo-InstallerLines)
Write-Host ($lines -join [Environment]::NewLine)
function Get-LineAfter([string] $Marker) {
    for ($i = 0; $i -lt $lines.Count - 1; $i++) {
        if ($lines[$i].Contains($Marker)) { return $lines[$i + 1].Trim() }
    }
    throw "install-check: the installer printed no line after '$Marker'"
}
$dir = Join-Path $env:LOCALAPPDATA 'Programs\encypher'
if ($env:ENCYPHER_INSTALL_DIR) { $dir = $env:ENCYPHER_INSTALL_DIR }
$cli = Join-Path $dir 'encypher.exe'

Invoke-Expression (Get-LineAfter 'in this session, run:')
if ((& encypher --version | Out-String) -notmatch $expected) { throw "install-check: encypher by name does not report $env:VERSION" }
Invoke-Expression (Get-LineAfter 'and for new terminals:')
$key = Get-Item $environment
if ($key.GetValueKind('Path') -ne 'ExpandString') { throw 'install-check: the user Path is no longer REG_EXPAND_SZ' }
$entries = $key.GetValue('Path', '', 'DoNotExpandEnvironmentNames') -split ';'
if ($entries -notcontains $dir) { throw "install-check: the user Path does not contain $dir" }
if ($entries -notcontains $seed) { throw "install-check: the printed line expanded $seed" }

if ((& $cli --version | Out-String) -notmatch $expected) { throw "install-check: $cli does not report $env:VERSION" }
& $cli inspect (Join-Path $env:FIXTURE 'signed-test.jpg') --json | Out-Null
if ($LASTEXITCODE -ne 0) { throw "install-check: inspect exited $LASTEXITCODE" }
& $cli verify (Join-Path $env:FIXTURE 'signed-test.jpg') --json
if ($LASTEXITCODE -ne 0) { throw "install-check: verify exited $LASTEXITCODE" }
if ($env:ENCYPHER_API_KEY) {
    $signed = Join-Path ([IO.Path]::GetTempPath()) ('encypher-' + [Guid]::NewGuid().ToString('N') + '.png')
    & $cli sign (Join-Path $env:FIXTURE 'image_png.png') -o $signed --on-existing-provenance chain --json `
        --digital-source-type http://cv.iptc.org/newscodes/digitalsourcetype/digitalCapture | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "install-check: sign exited $LASTEXITCODE" }
    & $cli verify $signed --json | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "install-check: verify of the signed PNG exited $LASTEXITCODE" }
    Write-Host 'install-check: signed and verified a PNG with the installed encypher'
} else {
    Write-Host 'install-check: ENCYPHER_API_KEY is not configured; live sign skipped'
}
Write-Host "install-check: encypher $env:VERSION installed by $scriptUrl under PowerShell $($PSVersionTable.PSVersion) and ran"
