#!/usr/bin/env python3
"""
boolean_search.py — Run job searches against ATS job boards via Tavily Search API.

Searches Greenhouse, Lever, Workday, and ICIMS directly for your target roles,
deduplicates against .job_history.txt, and outputs a text block ready
for Claude to score.

Credentials (required):
    Set BOOLEAN_TAVILY_API_KEY in .env
    Free tier: 1,000 queries/month at app.tavily.com

Usage:
    python scripts/boolean_search.py [--config PATH] [--history PATH] [--output PATH] [--dry-run]
"""

import argparse
import json
import os
import sys
import time
from datetime import date
from pathlib import Path

import requests

BASE_DIR = Path(__file__).parent.parent
TAVILY_ENDPOINT = "https://api.tavily.com/search"

ATS_JOB_PATTERNS = [
    "greenhouse.io",
    "lever.co",
    "myworkdayjobs.com",
    "careers.icims.com",
    "/jobs/",
    "/job/",
    "/careers/",
    "/opening/",
    "/apply/",
    "/position/",
]


def load_config(config_path: str) -> dict:
    with open(config_path) as f:
        return json.load(f)


def load_job_history(history_path: str) -> set:
    p = Path(history_path)
    if not p.exists():
        return set()
    return set(line.strip() for line in p.read_text().splitlines() if line.strip())


def run_query(query_string: str, num_results: int, api_key: str, days_back: int) -> list:
    """
    Run a single query via Tavily Search API.
    Returns list of result dicts with keys: url, title, description.
    Returns [] on any error — non-fatal.
    """
    payload = {
        "api_key": api_key,
        "query": query_string,
        "search_depth": "basic",
        "max_results": min(num_results, 20),
        "days": days_back,
    }
    try:
        resp = requests.post(TAVILY_ENDPOINT, json=payload, timeout=20)
        resp.raise_for_status()
        results = resp.json().get("results", [])
        return [
            {
                "url": r.get("url", ""),
                "title": r.get("title", ""),
                "description": (r.get("content", "") or "")[:200],
            }
            for r in results
        ]
    except requests.exceptions.HTTPError as exc:
        status = exc.response.status_code if exc.response is not None else "?"
        if status == 401:
            print("[BOOLEAN] ERROR: Invalid Tavily API key — check BOOLEAN_TAVILY_API_KEY", file=sys.stderr)
        elif status == 429:
            print("[BOOLEAN] WARNING: Tavily rate limit hit", file=sys.stderr)
        else:
            try:
                msg = exc.response.json().get("detail", str(exc))
            except Exception:
                msg = str(exc)
            print(f"[BOOLEAN] WARNING: HTTP {status}: {msg}", file=sys.stderr)
        return []
    except Exception as exc:
        print(f"[BOOLEAN] WARNING: Query failed ({exc}), skipping", file=sys.stderr)
        return []


def is_job_posting(item: dict) -> bool:
    url = (item.get("url") or "").lower()
    title = (item.get("title") or "").lower()

    for pattern in ATS_JOB_PATTERNS:
        if pattern in url:
            return True

    bad_signals = ["/blog/", "/news/", "/press/", "/about/", "/company/", "/search?"]
    if any(s in url for s in bad_signals):
        return False

    job_title_signals = [
        "manager", "director", "engineer", "analyst",
        "specialist", "lead", "associate", "coordinator",
    ]
    return any(sig in title for sig in job_title_signals)


def filter_new_results(results: list, seen_urls: set) -> list:
    return [r for r in results if r.get("url") not in seen_urls]


def format_as_text_block(results_by_query: dict, run_date: str) -> str:
    lines = [
        f"=== BOOLEAN SEARCH RESULTS - {run_date} ===",
        "Source: Direct ATS search via Tavily (Greenhouse, Lever, Workday, ICIMS)",
        "",
    ]

    total = sum(len(v) for v in results_by_query.values())
    if total == 0:
        lines.append("No new job postings found via Boolean search today.")
        return "\n".join(lines)

    for query_name, results in results_by_query.items():
        if not results:
            continue
        lines.append(f'Query: "{query_name}"')
        for i, item in enumerate(results, 1):
            lines += [
                f"--- Result {i} ---",
                f"Title: {item.get('title', '')}",
                f"URL: {item.get('url', '')}",
                f"Snippet: {item.get('description', '')}",
                "---",
            ]
        lines.append("")

    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description="Boolean ATS job search via Tavily Search API")
    parser.add_argument("--config", default=str(BASE_DIR / "boolean-search-config.json"))
    parser.add_argument("--history", default=str(BASE_DIR / ".job_history.txt"))
    parser.add_argument("--output", default=None)
    parser.add_argument(
        "--api-key",
        default=os.environ.get("BOOLEAN_TAVILY_API_KEY", ""),
        help="Tavily API key (or set BOOLEAN_TAVILY_API_KEY env var)",
    )
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    try:
        config = load_config(args.config)
    except FileNotFoundError:
        print(f"[BOOLEAN] ERROR: Config not found at {args.config}", file=sys.stderr)
        sys.exit(0)

    settings = config.get("settings", {})
    num_results = settings.get("results_per_query", 10)
    delay = settings.get("delay_between_queries_seconds", 2)
    days_back = settings.get("days_back", 7)

    queries = [q for q in config.get("queries", []) if q.get("enabled", True)]
    if not queries:
        print("[BOOLEAN] No enabled queries found in config", file=sys.stderr)
        sys.exit(0)

    if args.dry_run:
        print(f"[BOOLEAN] DRY RUN — {len(queries)} queries, days_back={days_back}")
        for q in queries:
            print(f"  [{q['name']}]\n  {q['string']}\n")
        sys.exit(0)

    if not args.api_key:
        print(
            "[BOOLEAN] ERROR: BOOLEAN_TAVILY_API_KEY not set.\n"
            "  Sign up at https://app.tavily.com (free: 1,000 queries/month)\n"
            "  Then add to .env: export BOOLEAN_TAVILY_API_KEY='tvly-...'",
            file=sys.stderr,
        )
        sys.exit(0)

    seen_urls = load_job_history(args.history)
    results_by_query = {}
    total_new = 0

    for i, q in enumerate(queries):
        name = q["name"]
        print(f"[BOOLEAN] Running: {name}", file=sys.stderr)

        raw = run_query(q["string"], num_results, args.api_key, days_back)
        job_results = [r for r in raw if is_job_posting(r)]
        new_results = filter_new_results(job_results, seen_urls)
        total_new += len(new_results)

        for r in new_results:
            seen_urls.add(r.get("url"))

        results_by_query[name] = new_results
        print(
            f"[BOOLEAN]   {len(raw)} results → {len(job_results)} job postings → {len(new_results)} new",
            file=sys.stderr,
        )

        if i < len(queries) - 1 and delay > 0:
            time.sleep(delay)

    output_text = format_as_text_block(results_by_query, date.today().isoformat())

    if args.output:
        Path(args.output).write_text(output_text)
    else:
        print(output_text)

    print(f"[BOOLEAN] {total_new} new jobs found across {len(queries)} queries", file=sys.stderr)
    sys.exit(0)


if __name__ == "__main__":
    main()
