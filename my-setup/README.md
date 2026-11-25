# My local setup

Personal build + server config for this fork. Not part of upstream llama.cpp.

**Hardware:** RTX 5060 Ti 16 GB (Blackwell, sm_120a) · i7-8700K (AVX2, no AVX-512) · 32 GB RAM · Windows 11

| File | Purpose |
|---|---|
| `Build-LlamaCpp.ps1` | CUDA 13.5 + MSVC 2022 build tuned for the hardware above. `-Pull` merges `upstream/master`, `-Clean` wipes `build/`. |
| `Start-LocalAI.ps1` | Starts the `llama-server` router on `http://127.0.0.1:8080` using `build\bin` and `model.ini`. |
| `model.ini` | `llama-server --models-preset` file: Qwen3.8-27B IQ3_XXS with MTP speculative decoding. Benchmarks are in the header comments. |
| `bench-server.sh` | Git Bash benchmark: starts a server on `:8099` with given flags, prints VRAM, prompt and generation t/s plus MTP draft acceptance. `SERVER=` picks another build, `PROMPT=` another prompt. Logs go to `bench-logs/` (git-ignored). |
| `bench-agent.py` | Simulates an OpenHands tool-calling loop against a running server and prints per-turn prompt-cache reuse and timings. `--thinking`, `--interleave` (unrelated requests in between), `--url`, `--turns`. |

These are the live files. `D:\AI-Dev\Scripts\Build-LlamaCpp.ps1`,
`D:\AI-Dev\Scripts\Start-LocalAI.ps1` and `D:\AI-Dev\Tools\llama.cpp\scripts\bench-server.sh`
(benchmarks the old prebuilt) are small stubs that forward here.

```powershell
& .\my-setup\Build-LlamaCpp.ps1 -Pull   # update from ggml-org and rebuild
& .\my-setup\Start-LocalAI.ps1          # start the server
```

```bash
my-setup/bench-server.sh n4 -c 98304 -ngl all -fa on -ctk q8_0 -ctv q8_0 --spec-type draft-mtp --spec-draft-n-max 4 --spec-draft-p-min 0.2
```
