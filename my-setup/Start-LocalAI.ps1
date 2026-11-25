# Start the local llama-server router (OpenAI-compatible API on http://127.0.0.1:8080).
# Uses the self-built binary from this repo (build with my-setup\Build-LlamaCpp.ps1)
# and the presets in my-setup\model.ini. Paths are relative to this script.
#
# Usage:  & "D:\AI-Dev\Tools\llama.cpp_git\my-setup\Start-LocalAI.ps1"
#         (or the stub at D:\AI-Dev\Scripts\Start-LocalAI.ps1)

$repo   = Split-Path -Parent $PSScriptRoot
$server = "$repo\build\bin\llama-server.exe"
$preset = "$PSScriptRoot\model.ini"

if (-not (Test-Path $server)) { throw "llama-server not built yet - run $PSScriptRoot\Build-LlamaCpp.ps1" }

# CUDA runtime DLLs (cudart/cublas) come from the installed toolkit
$cuda = (Get-ChildItem "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA" | Sort-Object Name | Select-Object -Last 1).FullName
$env:PATH = "$cuda\bin\x64;$cuda\bin;$env:PATH"

& $server `
    --models-preset $preset `
    --models-max 1 `
    --sleep-idle-seconds 900 `
    --parallel 1 `
    --host 127.0.0.1 `
    --port 8080
