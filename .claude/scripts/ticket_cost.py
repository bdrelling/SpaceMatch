#!/usr/bin/env python3
"""Report session token usage + cost with per-agent breakdown.

Usage:
        python3 ticket_cost.py
"""

from __future__ import annotations

import json
import os
import sys
from dataclasses import dataclass
from pathlib import Path

# Per-million-token USD rates. Verified against platform.claude.com/docs pricing
# 2026-05-23. Update if Anthropic pricing changes.
PRICING = {
        "opus": {
                "input": 5.0,
                "output": 25.0,
                "cache_write_5m": 6.25,
                "cache_write_1h": 10.0,
                "cache_read": 0.50,
        },
        "opus_legacy": {
                # Opus 4 (deprecated) / 4.1 — 3x the 4.5+ rates.
                "input": 15.0,
                "output": 75.0,
                "cache_write_5m": 18.75,
                "cache_write_1h": 30.0,
                "cache_read": 1.50,
        },
        "sonnet": {
                "input": 3.0,
                "output": 15.0,
                "cache_write_5m": 3.75,
                "cache_write_1h": 6.0,
                "cache_read": 0.30,
        },
        "haiku": {
                "input": 1.0,
                "output": 5.0,
                "cache_write_5m": 1.25,
                "cache_write_1h": 2.0,
                "cache_read": 0.10,
        },
        "haiku_legacy": {
                # Haiku 3.5.
                "input": 0.80,
                "output": 4.0,
                "cache_write_5m": 1.0,
                "cache_write_1h": 1.60,
                "cache_read": 0.08,
        },
}


def model_family(model: str) -> str | None:
        m = (model or "").lower()
        if "opus" in m:
                if "opus-4-1" in m or "opus-4-0" in m or m.endswith("opus-4"):
                        return "opus_legacy"
                return "opus"
        if "sonnet" in m:
                return "sonnet"
        if "haiku" in m:
                if "haiku-3" in m:
                        return "haiku_legacy"
                return "haiku"
        return None


def encoded_cwd(cwd: str) -> str:
        return cwd.replace("/", "-")


def project_dir() -> Path:
        cwd = os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd()
        return Path.home() / ".claude" / "projects" / encoded_cwd(cwd)


def latest_session_id() -> str:
        pd = project_dir()
        if not pd.is_dir():
                return ""
        jsonls = sorted(pd.glob("*.jsonl"), key=lambda p: p.stat().st_mtime, reverse=True)
        return jsonls[0].stem if jsonls else ""


@dataclass
class Totals:
        input_tokens: int = 0
        output_tokens: int = 0
        cache_write: int = 0
        cache_read: int = 0
        cost_usd: float = 0.0
        skipped_tokens: int = 0


def accumulate(totals: Totals, usage: dict, model: str) -> None:
        family = model_family(model)
        if family is None:
                inp = int(usage.get("input_tokens", 0) or 0)
                out = int(usage.get("output_tokens", 0) or 0)
                totals.skipped_tokens += inp + out
                return
        rates = PRICING[family]
        inp = int(usage.get("input_tokens", 0) or 0)
        out = int(usage.get("output_tokens", 0) or 0)
        cr = int(usage.get("cache_read_input_tokens", 0) or 0)
        cw_dict = usage.get("cache_creation") or {}
        cw_5m = int(cw_dict.get("ephemeral_5m_input_tokens", 0) or 0)
        cw_1h = int(cw_dict.get("ephemeral_1h_input_tokens", 0) or 0)
        if not cw_dict:
                cw_5m = int(usage.get("cache_creation_input_tokens", 0) or 0)
        totals.input_tokens += inp
        totals.output_tokens += out
        totals.cache_read += cr
        totals.cache_write += cw_5m + cw_1h
        totals.cost_usd += (
                inp * rates["input"]
                + out * rates["output"]
                + cw_5m * rates["cache_write_5m"]
                + cw_1h * rates["cache_write_1h"]
                + cr * rates["cache_read"]
        ) / 1_000_000


def scan_jsonl(path: Path, totals: Totals) -> None:
        try:
                with path.open() as f:
                        for line in f:
                                try:
                                        d = json.loads(line)
                                except json.JSONDecodeError:
                                        continue
                                if d.get("type") != "assistant":
                                        continue
                                msg = d.get("message", {})
                                usage = msg.get("usage") or {}
                                if usage:
                                        accumulate(totals, usage, msg.get("model", ""))
        except FileNotFoundError:
                pass


def fmt_tokens(n: int) -> str:
        if n >= 1_000_000:
                return f"{n / 1_000_000:.2f}M"
        if n >= 1_000:
                return f"{n / 1_000:.1f}k"
        return str(n)


def fmt_cost(c: float) -> str:
        if c >= 1:
                return f"${c:,.2f}"
        return f"${c:.4f}"


def fmt_line(label: str, totals: Totals) -> str:
        return (
                f"{label}: {fmt_cost(totals.cost_usd)} "
                f"({fmt_tokens(totals.input_tokens)} in, "
                f"{fmt_tokens(totals.output_tokens)} out, "
                f"{fmt_tokens(totals.cache_read)} cache read, "
                f"{fmt_tokens(totals.cache_write)} cache write)"
        )


def main() -> int:
        sid = latest_session_id()
        if not sid:
                print("_No session found._")
                return 0

        pd = project_dir()

        main_totals = Totals()
        scan_jsonl(pd / f"{sid}.jsonl", main_totals)

        sub_dir = pd / sid / "subagents"
        agent_rows: list[tuple[str, Totals]] = []

        if sub_dir.is_dir():
                for jsonl in sorted(sub_dir.glob("agent-*.jsonl")):
                        agent_id = jsonl.stem
                        meta_path = jsonl.with_suffix(".jsonl").with_name(f"{agent_id}.meta.json")
                        label = agent_id
                        if meta_path.exists():
                                try:
                                        meta = json.loads(meta_path.read_text())
                                        desc = meta.get("description") or meta.get("agentType") or agent_id
                                        label = desc[:60]
                                except (json.JSONDecodeError, OSError):
                                        pass
                        t = Totals()
                        scan_jsonl(jsonl, t)
                        agent_rows.append((label, t))

        grand = Totals()
        for t in [main_totals] + [r[1] for r in agent_rows]:
                grand.input_tokens += t.input_tokens
                grand.output_tokens += t.output_tokens
                grand.cache_read += t.cache_read
                grand.cache_write += t.cache_write
                grand.cost_usd += t.cost_usd
                grand.skipped_tokens += t.skipped_tokens

        print(fmt_line("Total", grand))
        print(fmt_line("  main", main_totals))
        for label, t in agent_rows:
                print(fmt_line(f"  {label}", t))

        if grand.skipped_tokens:
                print(f"  (skipped {fmt_tokens(grand.skipped_tokens)} tokens with unrecognized model)")

        return 0


if __name__ == "__main__":
        sys.exit(main())
