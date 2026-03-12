#!/usr/bin/env python3
"""Tail and parse Claude Code OTEL JSONL logs.

Usage:
  otel-tail.py <file.jsonl>              # tail -f mode
  otel-tail.py --cat <file.jsonl>        # dump entire file
  cat file.jsonl | otel-tail.py          # pipe mode
"""
import json
import sys
import argparse
import subprocess

DIM = "\033[2m"
BOLD = "\033[1m"
RESET = "\033[0m"
CYAN = "\033[36m"
YELLOW = "\033[33m"
GREEN = "\033[32m"
RED = "\033[31m"
MAGENTA = "\033[35m"

def format_record(rec):
    body = rec.get("body", {}).get("stringValue", "")
    attrs = {}
    for a in rec.get("attributes", []):
        v = a["value"]
        attrs[a["key"]] = v.get("stringValue", v.get("intValue", v.get("doubleValue", "")))

    event = body.replace("claude_code.", "")
    ts = attrs.get("event.timestamp", "")
    time_short = ts[11:19] if len(ts) > 19 else ""

    if event == "user_prompt":
        length = attrs.get("prompt_length", "?")
        return f"{DIM}{time_short}{RESET} {BOLD}{CYAN}PROMPT{RESET} ({length} chars)"

    elif event == "api_request":
        model = attrs.get("model", "?")
        # Shorten model name
        if "opus" in model:
            model = "opus"
        elif "sonnet" in model:
            model = "sonnet"
        elif "haiku" in model:
            model = "haiku"
        cost = attrs.get("cost_usd", "0")
        try:
            cost = f"${float(cost):.3f}"
        except (ValueError, TypeError):
            cost = f"${cost}"
        in_tok = attrs.get("input_tokens", "?")
        out_tok = attrs.get("output_tokens", "?")
        cache_r = attrs.get("cache_read_tokens", "0")
        dur = attrs.get("duration_ms", "?")
        try:
            dur = f"{int(dur)/1000:.1f}s"
        except (ValueError, TypeError):
            pass
        return f"{DIM}{time_short}{RESET} {YELLOW}API{RESET} {model} {cost} {DIM}in={in_tok} out={out_tok} cache={cache_r} {dur}{RESET}"

    elif event == "tool_decision":
        tool = attrs.get("tool_name", "?")
        decision = attrs.get("decision", "?")
        color = GREEN if decision == "accept" else RED
        return f"{DIM}{time_short}{RESET} {color}TOOL{RESET} {BOLD}{tool}{RESET} → {decision}"

    elif event == "tool_result":
        tool = attrs.get("tool_name", "?")
        ok = attrs.get("success", "?")
        dur = attrs.get("duration_ms", "?")
        size = attrs.get("tool_result_size_bytes", "?")
        params = attrs.get("tool_parameters", "")
        detail = ""
        if params:
            try:
                p = json.loads(params)
                if "full_command" in p:
                    detail = f" {DIM}{p['full_command'][:60]}{RESET}"
                elif "file_path" in p:
                    detail = f" {DIM}{p['file_path']}{RESET}"
            except (json.JSONDecodeError, TypeError):
                pass
        try:
            dur = f"{int(dur)/1000:.1f}s"
        except (ValueError, TypeError):
            pass
        icon = GREEN + "✓" if ok == "true" else RED + "✗"
        return f"{DIM}{time_short}{RESET}   {icon}{RESET} {tool} {DIM}{dur} {size}B{RESET}{detail}"

    else:
        return f"{DIM}{time_short}{RESET} {MAGENTA}{event}{RESET}"


def process_line(line):
    line = line.strip()
    if not line:
        return
    try:
        obj = json.loads(line)
    except json.JSONDecodeError:
        return
    for rl in obj.get("data", {}).get("resourceLogs", []):
        for sl in rl.get("scopeLogs", []):
            for rec in sl.get("logRecords", []):
                msg = format_record(rec)
                if msg:
                    print(msg, flush=True)


def main():
    parser = argparse.ArgumentParser(description="Parse Claude Code OTEL JSONL")
    parser.add_argument("file", nargs="?", help="JSONL file to tail/read")
    parser.add_argument("--cat", action="store_true", help="Dump whole file instead of tail -f")
    args = parser.parse_args()

    if args.file:
        if args.cat:
            with open(args.file) as f:
                for line in f:
                    process_line(line)
        else:
            proc = subprocess.Popen(
                ["tail", "-f", args.file],
                stdout=subprocess.PIPE,
                text=True,
            )
            try:
                for line in proc.stdout:
                    process_line(line)
            except KeyboardInterrupt:
                proc.terminate()
    else:
        for line in sys.stdin:
            process_line(line)


if __name__ == "__main__":
    main()
