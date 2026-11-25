# My local setup

Personal build + server config for this fork. Not part of upstream llama.cpp.

**Hardware:** RTX 5060 Ti 16 GB (Blackwell, sm_120a) · i7-8700K (AVX2, no AVX-512) · 32 GB RAM · Windows 11

| File | Purpose | Live copy used on this PC |
|---|---|---|
| `Build-LlamaCpp.ps1` | CUDA 13.5 + MSVC 2022 build tuned for the hardware above. `-Pull` merges `upstream/master`, `-Clean` wipes `build/`. | `D:\AI-Dev\Scripts\Build-LlamaCpp.ps1` |
| `model.ini` | `llama-server --models-preset` file: Qwen3.8-27B IQ3_XXS with MTP speculative decoding. Benchmarks are in the header comments. | `D:\AI-Dev\Config\model.ini` |

These are copies. After editing a live file, copy it back here and commit.

Server launch (router mode, as used by `Start-LocalAI.ps1`):

```powershell
build\bin\llama-server.exe --models-preset my-setup\model.ini --models-max 1 --sleep-idle-seconds 900 --parallel 1 --host 127.0.0.1 --port 8080
```
