# Job Search Automation

Searches ATS job boards directly using Boolean queries, scores new postings with Claude AI, and sends Slack alerts for strong matches. Runs on GitHub Actions 3x/day and deduplicates results so you only see genuinely new postings.

The core idea: Greenhouse, Lever, Workday, and ICIMS are public websites. Boolean search via [Tavily](https://app.tavily.com) hits them directly — no scraping, no job board subscriptions, no email digests to parse.

---

## How It Works

```
Boolean queries → Tavily Search API → deduplicate (.job_history.txt)
                                              ↓
                                  Claude Haiku scores each posting
                                              ↓
                                  Daily report + Slack alert
```

Four queries run per cycle (Greenhouse/Lever, Workday, ICIMS, plus one keyword variant). Each query costs 1 Tavily credit. At 3 runs/day: ~360 credits/month — well within the free tier of 1,000/month.

---

## Prerequisites

- Python 3.10+
- [Tavily API key](https://app.tavily.com) — free tier, 1,000 credits/month
- [Anthropic API key](https://console.anthropic.com/settings/keys)
- Slack incoming webhook URL (optional, for alerts)
- GitHub account (for scheduled runs)

---

## Setup

### 1. Fork or clone this repo

```bash
git clone https://github.com/your-username/job-search-automation.git
cd job-search-automation
```

### 2. Install dependencies

```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### 3. Configure your credentials

```bash
cp .env.example .env
# Edit .env with your API keys
```

### 4. Write your search profile

Edit `my-profile.md` to describe the roles you're targeting. This is what Claude reads to score job postings. See the [Writing Your Profile](#writing-your-profile) section below.

### 5. Configure your Boolean queries

Edit `boolean-search-config.json` with queries targeting your role. See [`references/boolean-search-patterns.md`](references/boolean-search-patterns.md) for ready-to-use query strings by role type.

### 6. Test locally

```bash
# Dry run — prints queries without hitting the API
source venv/bin/activate
python scripts/boolean_search.py --dry-run

# Full local run
source .env && ./scripts/daily-job-check.sh
```

### 7. Deploy to GitHub Actions

1. Push your repo to GitHub
2. Go to **Settings → Secrets and variables → Actions** and add:
   - `ANTHROPIC_API_KEY`
   - `BOOLEAN_TAVILY_API_KEY`
   - `SLACK_WEBHOOK_URL` (optional)
3. Go to the **Actions** tab and enable workflows
4. Trigger a manual run to verify

The workflow runs at 8 AM, 2 PM, and 8 PM EST by default. Edit the cron schedule in `.github/workflows/daily-job-check.yml` to change timing.

---

## Configuration

### `boolean-search-config.json`

Controls everything without touching code:

```json
{
  "settings": {
    "results_per_query": 5,
    "delay_between_queries_seconds": 2,
    "days_back": 7
  },
  "queries": [
    {
      "name": "My Role - Greenhouse + Lever",
      "enabled": true,
      "string": "(site:greenhouse.io OR site:lever.co) (\"senior product marketing manager\") (\"remote\")"
    }
  ]
}
```

- `results_per_query` — Tavily results per query, max 20. Start at 5.
- `days_back` — how far back to search. 7 days balances coverage with overlap.
- `delay_between_queries_seconds` — pause between queries. Keep at 2.
- Set `enabled: false` on any query to pause it without deleting it.

See [`references/boolean-search-patterns.md`](references/boolean-search-patterns.md) for copy-paste query strings by role type.

---

## How Scoring Works

Each posting is scored in two steps:

**Step 1: Talent pool ranking.** Claude estimates where you'd sit in the likely applicant pool for this specific role. If the ranking falls below the top 20%, the posting is deprioritized — better to focus where you have real differentiation.

**Step 2: Weighted score** across six dimensions:

| Dimension | Weight |
|-----------|--------|
| Role Fit | 30% |
| Company Fit | 25% |
| Compensation | 20% |
| Growth Potential | 10% |
| Location/Remote | 10% |
| Timeline | 5% |

**Priority tiers:**

| Score | Tier | What to do |
|-------|------|------------|
| 8.0–10.0 | HOT | Customize everything, reach out directly |
| 6.0–7.9 | WARM | Tailored materials, standard outreach |
| 4.0–5.9 | COOL | Light customization, direct application |
| < 4.0 | PASS | Skip unless pipeline is thin |

Slack alerts fire for jobs scoring 6.5 or above. Adjust this threshold in `scripts/daily-job-check.sh`.

---

## Writing Your Profile

`my-profile.md` is what Claude reads to score postings. Write it once, keep it updated. The more specific you are, the more accurate the scoring.

**What to include:**

- **Target roles** — specific titles (e.g., "Senior Product Marketing Manager", not just "marketing roles")
- **Experience summary** — years total, years in target function, notable companies, key achievements with numbers
- **Preferred industries** — ranked. Industry match often matters more than title match for how competitive you'll be.
- **Location** — remote only? Open to hybrid? Specific cities?
- **Compensation floor** — your actual minimum. This filters out roles not worth your time.
- **Must-haves** — things that would make you decline an offer even if everything else looks good
- **Red flags** — automatic disqualifiers (toxic culture signals, specific company types, etc.)
- **Key strengths** — what makes you a strong candidate. Claude uses this for talent pool ranking.
- **Gaps to be aware of** — where you're weaker than other applicants. Honest profiles score more accurately.

See `my-profile.md` in this repo for a template with examples.

---

## Output

Each run produces:

- **`daily-reports/report-YYYY-MM-DD.md`** — all scored jobs ranked by score, with qualifications and reasoning
- **`logs/job-check-YYYY-MM-DD.log`** — execution log
- **`.job_history.txt`** — tracks seen URLs for deduplication (persisted via GitHub Actions cache)
- **Slack alert** — fires for jobs scoring ≥ 6.5 (if webhook is configured)

---

## Cost

| Service | Usage | Cost |
|---------|-------|------|
| Tavily | 4 queries × 3 runs/day × 30 days = 360 credits | Free (limit: 1,000/month) |
| Claude Haiku | ~10-15 jobs scored per run | < $0.50/month |
| GitHub Actions | ~3 min/run × 90 runs/month = 270 min | Free (limit: 2,000 min/month) |

---

## Troubleshooting

**No jobs found:** Check that your Boolean strings are valid. Run `python scripts/boolean_search.py --dry-run` to print queries without hitting the API. Test a query string in Google manually first.

**401 error from Tavily:** Your `BOOLEAN_TAVILY_API_KEY` is wrong or not set. Check `.env` and GitHub Secrets.

**All results are duplicates:** Expected after the first run. Delete `.job_history.txt` to reset deduplication history.

**Slack not alerting:** Either the webhook URL is wrong, or scored jobs are below the 6.5 threshold. Check `daily-reports/` to confirm jobs are being found and scored.

**Boolean search skipped in GitHub Actions:** Ensure `BOOLEAN_TAVILY_API_KEY` is added to repository secrets.

---

## Project Structure

```
job-search-automation/
├── README.md
├── boolean-search-config.json      # Query configuration (edit this)
├── my-profile.md                   # Your search criteria (edit this)
├── .env.example                    # Credential template
├── requirements.txt
├── scripts/
│   ├── boolean_search.py           # Tavily search + deduplication
│   └── daily-job-check.sh          # Main orchestration script
├── references/
│   └── boolean-search-patterns.md  # Ready-to-use Boolean query strings
└── .github/
    └── workflows/
        └── daily-job-check.yml     # GitHub Actions workflow
```

---

## License

MIT
