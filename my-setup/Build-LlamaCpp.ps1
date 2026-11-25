# Build llama.cpp from source, tuned for this PC:
#   GPU: RTX 5060 Ti 16 GB (Blackwell, compute 12.0 -> 120a-real, native FP4 tensor cores)
#   CPU: i7-8700K (Coffee Lake: AVX2 + FMA + F16C + BMI2, no AVX-512)
#
# Usage:  & "D:\AI-Dev\Scripts\Build-LlamaCpp.ps1"            # incremental build
#         & "D:\AI-Dev\Scripts\Build-LlamaCpp.ps1" -Pull      # merge latest ggml-org master first
#         & "D:\AI-Dev\Scripts\Build-LlamaCpp.ps1" -Clean     # wipe build dir first
#
# Repo layout: origin = your fork (Volen-M/llama.cpp), upstream = ggml-org/llama.cpp.
# -Pull merges upstream/master into the current branch (keeps your own commits);
# push the result to your fork yourself with: git -C D:\AI-Dev\Tools\llama.cpp_git push
param([switch]$Pull, [switch]$Clean)
$ErrorActionPreference = "Stop"

$src   = "D:\AI-Dev\Tools\llama.cpp_git"
$build = "$src\build"
$vs    = "C:\Program Files\Microsoft Visual Studio\2022\Community"   # MSVC 14.44, officially supported by nvcc

if ($Pull) {
    git -C $src fetch upstream
    if ($LASTEXITCODE) { throw "git fetch upstream failed" }
    git -C $src merge --no-edit upstream/master
    if ($LASTEXITCODE) { throw "merge with upstream/master failed - resolve conflicts in $src, then rerun" }
}
if ($Clean -and (Test-Path $build)) { Remove-Item -Recurse -Force $build }

# Load the x64 MSVC environment (also puts VS-bundled CMake + Ninja on PATH)
& "$vs\Common7\Tools\Launch-VsDevShell.ps1" -Arch amd64 -HostArch amd64 -SkipAutomaticLocation | Out-Null

if (-not $env:CUDA_PATH) {
    $env:CUDA_PATH = (Get-ChildItem "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA" | Sort-Object Name | Select-Object -Last 1).FullName
}
$env:PATH = "$env:CUDA_PATH\bin;$env:PATH"

cmake -S $src -B $build -G Ninja `
    -DCMAKE_BUILD_TYPE=Release `
    -DGGML_CUDA=ON `
    -DCMAKE_CUDA_ARCHITECTURES=120a-real `
    -DGGML_CUDA_NCCL=OFF `
    -DGGML_NATIVE=OFF `
    -DGGML_AVX=ON -DGGML_AVX2=ON -DGGML_FMA=ON -DGGML_F16C=ON -DGGML_BMI2=ON `
    -DGGML_AVX512=OFF `
    -DLLAMA_BUILD_LIBRESSL=ON `
    -DLLAMA_BUILD_TESTS=OFF `
    -DLLAMA_BUILD_EXAMPLES=OFF
if ($LASTEXITCODE) { throw "cmake configure failed" }

cmake --build $build --config Release -j $env:NUMBER_OF_PROCESSORS
if ($LASTEXITCODE) { throw "build failed" }

Write-Host "`nBuilt: $build\bin\llama-server.exe" -ForegroundColor Green
& "$build\bin\llama-server.exe" --version
