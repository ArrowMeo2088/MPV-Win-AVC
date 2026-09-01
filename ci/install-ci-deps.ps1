# CI-only: install meson/ninja/ccache/NASM with mirrors (avoid flaky nasm.us via winget).
$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $true
Set-StrictMode -Version Latest

function Install-NasmCi {
    param(
        [string]$Version = "2.16.01"
    )

    $dest = Join-Path $env:RUNNER_TEMP "nasm"
    $nasmExe = Join-Path $dest "nasm.exe"
    if (Test-Path $nasmExe) {
        Write-Host "NASM already present: $nasmExe"
        return $dest
    }

    $zipName = "nasm-$Version-win64.zip"
    $zipPath = Join-Path $env:RUNNER_TEMP $zipName
    $urls = @(
        # vcpkg community mirror (when nasm.us is down)
        "https://github.com/microsoft/vcpkg/files/12073957/$zipName",
        "https://www.nasm.us/pub/nasm/releasebuilds/$Version/win64/$zipName"
    )

    $downloaded = $false
    foreach ($url in $urls) {
        try {
            Write-Host "Downloading NASM: $url"
            Invoke-WebRequest -Uri $url -OutFile $zipPath -TimeoutSec 180 -UseBasicParsing
            if ((Get-Item $zipPath).Length -lt 10000) {
                throw "Download too small, likely an error page"
            }
            $downloaded = $true
            break
        }
        catch {
            Write-Warning "NASM download failed from ${url}: $_"
        }
    }

    if (-not $downloaded) {
        throw "Failed to download NASM $Version from all mirrors"
    }

    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    Expand-Archive -Path $zipPath -DestinationPath $dest -Force
    if (-not (Test-Path $nasmExe)) {
        throw "nasm.exe not found after extracting $zipPath"
    }

    Write-Host "NASM installed to $dest"
    return $dest
}

Write-Host "=== pip: meson + ninja ==="
python -m pip install --upgrade pip
python -m pip install meson ninja

Write-Host "=== winget: ccache (optional) ==="
try {
    winget install --accept-source-agreements --accept-package-agreements Ccache.Ccache
    $wingetLinks = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Links"
    if (Test-Path $wingetLinks) {
        "CCACHE_WINGET_LINKS=$wingetLinks" >> $env:GITHUB_ENV
    }
}
catch {
    Write-Warning "ccache winget install failed (non-fatal): $_"
}

Write-Host "=== NASM (mirrors) ==="
$nasmDir = Install-NasmCi
"NASM_DIR=$nasmDir" >> $env:GITHUB_ENV
"$nasmDir" >> $env:GITHUB_PATH

Write-Host "=== verify tools ==="
meson --version
ninja --version
& (Join-Path $nasmDir "nasm.exe") -v
if (Get-Command ccache -ErrorAction SilentlyContinue) {
    ccache --version
}
