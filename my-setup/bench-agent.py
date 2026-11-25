"""Agent-loop benchmark: simulates an OpenHands-style tool-calling session against
a running llama-server and reports per-turn prompt-cache reuse and timings.

Each turn sends the whole conversation (system + tools + history), gets a tool
call back, appends it plus a large tool result (a real source file chunk), and
repeats - like CodeActAgent does. Shows how many prompt tokens were re-used from
the cache vs re-processed, which dominates agent latency on long contexts.

Usage:  python my-setup/bench-agent.py [--url http://127.0.0.1:8099] [--turns 8]
        [--thinking] [--chunk 12000]
"""
import argparse, json, pathlib, time, urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
TOOLS = [
    {"type": "function", "function": {"name": "execute_bash", "description": "Run a bash command in the sandbox and return stdout/stderr.",
     "parameters": {"type": "object", "properties": {"command": {"type": "string"}, "timeout": {"type": "number"}}, "required": ["command"]}}},
    {"type": "function", "function": {"name": "str_replace_editor", "description": "View, create and edit files. Commands: view, create, str_replace, insert, undo_edit.",
     "parameters": {"type": "object", "properties": {"command": {"type": "string", "enum": ["view", "create", "str_replace", "insert", "undo_edit"]},
        "path": {"type": "string"}, "old_str": {"type": "string"}, "new_str": {"type": "string"}, "view_range": {"type": "array", "items": {"type": "integer"}}},
        "required": ["command", "path"]}}},
    {"type": "function", "function": {"name": "finish", "description": "Signal the task is complete.",
     "parameters": {"type": "object", "properties": {"message": {"type": "string"}}, "required": ["message"]}}},
]
SYSTEM = ("You are OpenHands agent, a helpful AI assistant that can interact with a computer to solve tasks.\n"
          "<ROLE>Investigate the repository, then make minimal, correct changes. Always use a tool; never answer in prose.</ROLE>\n"
          "<EFFICIENCY>Each action is expensive. Combine commands where possible. View files in chunks.</EFFICIENCY>\n" * 3)
TASK = ("The repository is llama.cpp at /workspace. Investigate how the HTTP server decides whether a cached prompt "
        "can be reused between requests (look at tools/server). Read the relevant code step by step with the tools, "
        "one file chunk per call. Do not finish before at least 8 tool calls.")


def chunks(size):
    src = (ROOT / "tools/server/server-context.cpp")
    if not src.exists():
        src = next((ROOT / "tools/server").glob("*.cpp"))
    text = src.read_text(encoding="utf-8", errors="replace")
    i = 0
    while True:
        yield src.name, text[i:i + size] or text[:size]
        i = (i + size) % max(len(text) - size, 1)


def post(url, body):
    req = urllib.request.Request(url + "/v1/chat/completions", data=json.dumps(body).encode(), headers={"Content-Type": "application/json"})
    t = time.time()
    with urllib.request.urlopen(req, timeout=1800) as r:
        return json.load(r), time.time() - t


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--url", default="http://127.0.0.1:8099")
    ap.add_argument("--turns", type=int, default=8)
    ap.add_argument("--chunk", type=int, default=12000, help="chars of tool output per turn (~3-4k tokens)")
    ap.add_argument("--thinking", action="store_true", help="enable thinking (default off, like the Orchestrator relay)")
    ap.add_argument("--model", default="Qwen3.8-Q4")
    ap.add_argument("--interleave", action="store_true",
                    help="send an unrelated ~6k-token request between agent turns (another task / condenser call)")
    a = ap.parse_args()
    msgs = [{"role": "system", "content": SYSTEM}, {"role": "user", "content": TASK}]
    src = chunks(a.chunk)
    tot_wall = tot_proc = tot_cached = 0
    print(f"{'turn':>4} {'prompt':>7} {'cached':>7} {'new':>6} {'pp s':>6} {'gen':>5} {'tg t/s':>7} {'wall s':>7}")
    for turn in range(1, a.turns + 1):
        body = {"model": a.model, "messages": msgs, "tools": TOOLS, "max_tokens": 1024, "temperature": 0.6,
                "chat_template_kwargs": {"enable_thinking": a.thinking}}
        if a.interleave and turn > 1:
            other = [{"role": "user", "content": "Summarize these events in 3 bullets:\n" + next(src)[1] * 2}]
            post(a.url, {"model": a.model, "messages": other, "max_tokens": 64, "chat_template_kwargs": {"enable_thinking": False}})
        d, wall = post(a.url, body)
        t = d["timings"]; m = d["choices"][0]["message"]
        cached = t.get("cache_n", 0); new = t["prompt_n"]
        print(f"{turn:>4} {cached + new:>7} {cached:>7} {new:>6} {t['prompt_ms'] / 1000:>6.1f} {t['predicted_n']:>5} {t['predicted_per_second']:>7.1f} {wall:>7.1f}")
        tot_wall += wall; tot_proc += new; tot_cached += cached
        msg = {"role": "assistant", "content": m.get("content") or ""}
        if m.get("reasoning_content"):
            msg["reasoning_content"] = m["reasoning_content"]
        calls = m.get("tool_calls") or []
        if not calls:  # model answered in prose: push it back to tools
            msgs += [msg, {"role": "user", "content": "Use a tool. Continue investigating."}]
            continue
        msg["tool_calls"] = calls
        msgs.append(msg)
        name, text = next(src)
        for c in calls:
            msgs.append({"role": "tool", "tool_call_id": c.get("id", ""), "content": f"[{name}]\n{text}"})
    print(f"total wall {tot_wall:.0f} s | prompt tokens processed {tot_proc} | re-used from cache {tot_cached}")


if __name__ == "__main__":
    main()
