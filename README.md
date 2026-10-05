<p>
  <a href="https://encypher.com">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="assets/encypher-logo-dark.svg">
      <img src="assets/encypher-logo.svg" alt="Encypher" width="300">
    </picture>
  </a>
</p>

# encypher

`encypher` puts proof of origin inside your photos, video and audio: who
published a file, when, and how it was made, signed by Encypher as Content
Credentials (the C2PA standard). The proof travels with the file, and anyone
can check it. Your files never leave your machine: Encypher's service signs,
and `encypher` writes the signed copy locally and checks it before saving it.

This README documents encypher v0.1.0.

## Install

macOS and Linux:

```
curl -fsSL https://github.com/encypherai/encypher-cli/releases/latest/download/install.sh | sh
```

Windows (PowerShell 5.1 or 7):

```
irm https://github.com/encypherai/encypher-cli/releases/latest/download/install.ps1 | iex
```

The installer checks the download against the release's `SHA256SUMS`, needs
no administrator rights, and puts `encypher` in `~/.local/bin` (Windows:
`%LOCALAPPDATA%\Programs\encypher`). If that directory is not on your `PATH`,
it prints what to run for this shell and for new ones. Run it again to
update. `ENCYPHER_INSTALL_DIR` installs to another absolute directory.

To install a specific version, name it in both the URL and `ENCYPHER_VERSION`:

```
curl -fsSL https://github.com/encypherai/encypher-cli/releases/download/v0.1.0/install.sh | ENCYPHER_VERSION=0.1.0 sh
$env:ENCYPHER_VERSION = '0.1.0'; irm https://github.com/encypherai/encypher-cli/releases/download/v0.1.0/install.ps1 | iex
```

A release stays marked "Pre-release" until the installer has run it on macOS,
Linux and Windows; pin only releases without that mark.

Supported: macOS 11 or later (Apple Silicon) and 10.12 or later (Intel);
Linux x86_64 and arm64 with glibc 2.34 or later (Ubuntu 22.04, Debian 12,
RHEL 9, Amazon Linux 2023 and later; not Alpine); Windows 10 1803 or later,
x64.

## Get an API key

Signing needs an Encypher API key. Create an account and a key at
https://dashboard.encypher.com, or ask your Encypher contact for a pilot key.
`verify` and `inspect` need no key.

## Quickstart

A file that carries no Content Credentials yet needs its IPTC digital source
type, which says how it was made. For a camera photo:

```
export ENCYPHER_API_KEY=...                  # Windows: $env:ENCYPHER_API_KEY = '...'
encypher sign photo.jpg --digital-source-type http://cv.iptc.org/newscodes/digitalsourcetype/digitalCapture
encypher verify photo-signed.jpg             # exit 0 when the service verifies it
encypher inspect photo-signed.jpg            # what the file carries, no network
```

The sign writes `photo-signed.jpg` beside the original and never replaces a
file. To sign a folder and keep a results file:

```
encypher sign --batch ./shoot --output-dir ./signed --jobs 4 --results shoot.jsonl \
  --digital-source-type http://cv.iptc.org/newscodes/digitalsourcetype/digitalCapture
```

If a sign is interrupted, run the same command again. Nothing is signed twice.

Three stops you may meet on the first sign:

- `DIGITAL_SOURCE_TYPE_REQUIRED` (exit 2): pass `--digital-source-type`.
- `EXISTING_PROVENANCE` (exit 2): the file already carries Content
  Credentials. Pass `--on-existing-provenance chain` to add yours on top.
- `FEATURE_NOT_AVAILABLE` (exit 5): local signing is not enabled for your
  organization yet. Ask your Encypher contact to enable it.

`encypher --help` lists every command, option and error code, each with its
next step.

## Exit codes

| Code | Meaning | What to do |
|---|---|---|
| 0 | Success | |
| 1 | Internal error in the client | Report it to support@encypher.com with the message |
| 2 | Usage error | Fix the command; the message says what is wrong |
| 3 | The service or signing engine returned something wrong; nothing was saved | Run it once more; report it if it repeats |
| 4 | Network, service or local file problem | Retry, unless `encypher --help` lists the code as one a retry cannot change |
| 5 | The service refused the request | Read the message; it carries the service's code |
| 6 | Upgrade required | Run the installer again |
| 7 | `verify`: the file is not verified | |
| 8 | A batch finished with failed items | Read the per-item lines or the results file |
| 130 | Cancelled with Ctrl-C | Run the same command to continue |

`--json` prints one JSON document on stdout and nothing on stderr.

## Update and uninstall

Run the install command again to update. To uninstall, delete
`~/.local/bin/encypher` (Windows: `%LOCALAPPDATA%\Programs\encypher`), the
`PATH` line you added, and the engine cache in `~/.cache/encypher` (Windows:
`%USERPROFILE%\.cache\encypher`).

## Machines that only run allowlisted programs

Santa, AppLocker or WDAC may block `encypher`. Approve the program by its own
hash; `SHA256SUMS` hashes the archives. Each release's `inventory.json` lists
that SHA-256 for every build (the `members` entry named `encypher` or
`encypher.exe`), so an administrator can approve it before anyone installs.
On an installed Mac, `shasum -a 256 ~/.local/bin/encypher` prints the same
value and `codesign -dvvv ~/.local/bin/encypher` the CDHash Santa also
accepts. AppLocker and WDAC take a rule generated from the file:

```
Get-AppLockerFileInformation <path to encypher.exe> | New-AppLockerPolicy -RuleType Hash -User Everyone -Xml
```

If PowerShell runs in Constrained Language Mode, use the manual install below.

## Manual install

Download `encypher-<version>-<target>.tar.gz` for your system and
`SHA256SUMS` from the release, then:

```
shasum -a 256 -c SHA256SUMS --ignore-missing     # Linux: sha256sum; Windows: Get-FileHash
tar -xzf encypher-<version>-<target>.tar.gz
mkdir -p ~/.local/bin && cp encypher-<version>-<target>/encypher ~/.local/bin/
```

After a browser download on macOS, also run
`xattr -dr com.apple.quarantine encypher-<version>-<target>`. The archive also
carries the C library and header for developers.

## Checking a release

Releases are immutable once published, and GitHub signs an attestation for
each one:

```
gh release verify v0.1.0 -R encypherai/encypher-cli
```

The checksums catch a damaged or substituted download. They do not protect
against someone who can publish releases here, since that person would
publish the checksums too.

`curl` and PowerShell do not mark the download, so macOS Gatekeeper and
Windows SmartScreen neither prompt for nor check the installed program; the
checksum is the check. The macOS builds carry an ad hoc code signature, which
Apple Silicon requires.

## Links

- Encypher: https://encypher.com
- Pricing: https://encypher.com/pricing
- Account and API keys: https://dashboard.encypher.com
- API documentation: https://api.encypher.com/docs
- Support: support@encypher.com

## License

`encypher` and the install scripts are licensed under the Apache License 2.0
or the MIT license, at your option; see `LICENSE`. The Encypher name and logo
are not licensed under these terms.
