# My local setup

Personal build + server config for this fork. Not part of upstream llama.cpp.

**Hardware:** RTX 5060 Ti 16 GB (Blackwell, sm_120a) · i7-8700K (AVX2, no AVX-512) · 32 GB RAM · Windows 11

| File | Purpose |
|---|---|
| `Build-LlamaCpp.ps1` | CUDA 13.5 + MSVC 2022 build tuned for the hardware above. `-Pull` merges `upstream/master`, `-Clean` wipes `build/`. |
| `Start-LocalAI.ps1` | Starts the `llama-server` router on `http://127.0.0.1:8080` using `build\bin` and `model.ini`. |
| `model.ini` | `llama-server --models-preset` file: Qwen3.8-27B IQ3_XXS with MTP speculative decoding. Benchmarks are in the header comments. |

These are the live files. `D:\AI-Dev\Scripts\Build-LlamaCpp.ps1` and
`D:\AI-Dev\Scripts\Start-LocalAI.ps1` are small stubs that forward here.

```powershell
& .\my-setup\Build-LlamaCpp.ps1 -Pull   # update from ggml-org and rebuild
& .\my-setup\Start-LocalAI.ps1          # start the server
```
