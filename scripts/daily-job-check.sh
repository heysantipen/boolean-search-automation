#!/bin/bash

################################################################################
# Daily Job Check
# Searches ATS job boards via Tavily Boolean search, analyzes results with
# Claude API, and generates ranked reports with optional Slack notifications.
################################################################################

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DATE=$(date +%Y-%m-%d)
LOG_FILE="$BASE_DIR/logs/job-check-$DATE.log"
REPORT_FILE="$BASE_DIR/daily-reports/report-$DATE.md"
PROFILE_FILE="$BASE_DIR/my-profile.md"
TEMP_DIR="$BASE_DIR/.temp-$$"
JOB_HISTORY_FILE="$BASE_DIR/.job_history.txt"

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

log() {
    echo "[$(date +%Y-%m-%d\ %H:%M:%S)] $*" | tee -a "$LOG_FILE"
}

error() {
    echo "[$(date +%Y-%m-%d\ %H:%M:%S)] ERROR: $*" | tee -a "$LOG_FILE" >&2
}

cleanup() {
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}

trap cleanup EXIT

check_dependencies() {
    log "Checking dependencies..."

    local missing_deps=()

    if ! command -v curl &> /dev/null; then
        missing_deps+=("curl")
    fi

    if ! command -v jq &> /dev/null; then
        missing_deps+=("jq")
    fi

    if [ ${#missing_deps[@]} -gt 0 ]; then
        error "Missing required dependencies: ${missing_deps[*]}"
        error "Install with: brew install ${missing_deps[*]}"
        exit 1
    fi

    log "All dependencies present"
}

check_env_vars() {
    log "Checking environment variables..."

    local missing_vars=()

    if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
        missing_vars+=("ANTHROPIC_API_KEY")
    fi

    if [ -z "${SLACK_WEBHOOK_URL:-}" ]; then
        log "WARNING: SLACK_WEBHOOK_URL not set - notifications disabled"
    fi

    if [ ${#missing_vars[@]} -gt 0 ]; then
        error "Missing required environment variables: ${missing_vars[*]}"
        error "See .env.example for setup instructions"
        exit 1
    fi

    log "Environment variables configured"
}

# ============================================================================
# BOOLEAN SEARCH (direct ATS discovery)
# ============================================================================

run_boolean_search() {
    log "Running Boolean searches for direct ATS job listings..."

    local output="$TEMP_DIR/boolean_results.txt"

    if [ ! -f "$SCRIPT_DIR/boolean_search.py" ]; then
        log "WARNING: boolean_search.py not found, skipping Boolean search"
        return 0
    fi

    # Use venv Python if available (local), fall back to system python3 (GitHub Actions)
    local python_cmd
    if [ -f "$BASE_DIR/venv/bin/python3" ]; then
        python_cmd="$BASE_DIR/venv/bin/python3"
    elif command -v python3 &>/dev/null; then
        python_cmd="python3"
    else
        log "WARNING: Python 3 not found, skipping Boolean search"
        return 0
    fi

    if ! "$python_cmd" "$SCRIPT_DIR/boolean_search.py" \
        --output "$output" \
        --history "$JOB_HISTORY_FILE" 2>&1 | tee -a "$LOG_FILE"; then
        log "WARNING: Boolean search failed, continuing"
        return 0
    fi

    if [ -f "$output" ] && [ -s "$output" ]; then
        cat "$output" >> "$TEMP_DIR/search_results.txt"
        log "Boolean search results added to analysis queue"
    else
        log "Boolean search returned no new results"
    fi

    return 0
}

# ============================================================================
# CLAUDE API ANALYSIS
# ============================================================================

analyze_jobs_with_claude() {
    log "Analyzing jobs with Claude API..."

    if [ ! -f "$PROFILE_FILE" ]; then
        error "Profile file not found: $PROFILE_FILE"
        exit 1
    fi

    local profile_content
    profile_content=$(cat "$PROFILE_FILE")

    local results_content
    if [ -f "$TEMP_DIR/search_results.txt" ] && [ -s "$TEMP_DIR/search_results.txt" ]; then
        results_content=$(cat "$TEMP_DIR/search_results.txt" | head -2000)
    else
        log "No search results to analyze"
        echo '{"summary": {"total": 0, "top_score": 0, "avg_score": 0}, "jobs": []}' > "$TEMP_DIR/analysis.json"
        return 0
    fi

    local prompt="You are a job search assistant analyzing job postings.

INSTRUCTIONS:
1. Extract every job posting from the results provided.
2. For each job, extract: title, company, location, salary (if mentioned), application link, and the top 3 critical qualifications.
3. Score each job 1-10 based on fit with the candidate profile below.

SCORING:
- Match against target roles, required experience, industry preferences, and location
- Flag qualifications that might disqualify the candidate (years of experience, specific domain expertise, hard skills, location constraints)
- Avoid generic qualifications like 'excellent communication' — focus on specific, measurable requirements

Return ONLY a valid JSON object in this exact format:
{
  \"summary\": {
    \"total\": <number of jobs found>,
    \"top_score\": <highest score>,
    \"avg_score\": <average score rounded to 1 decimal>
  },
  \"jobs\": [
    {
      \"score\": <1-10>,
      \"title\": \"Job Title\",
      \"company\": \"Company Name\",
      \"location\": \"Location or Remote\",
      \"salary\": \"Salary range or null\",
      \"link\": \"Application URL\",
      \"qualifications\": [\"Specific requirement 1\", \"Specific requirement 2\", \"Specific requirement 3\"],
      \"reasoning\": \"Why this score — 1-2 sentences\"
    }
  ]
}

CANDIDATE PROFILE:
$profile_content

JOB POSTINGS:
$results_content

Return ONLY the JSON object, no additional text."

    log "Sending request to Claude API..."

    local payload_file="$TEMP_DIR/api_payload.json"
    local prompt_escaped
    prompt_escaped=$(echo "$prompt" | jq -Rs .)

    cat > "$payload_file" << EOF
{
    "model": "claude-haiku-4-5-20251001",
    "max_tokens": 8192,
    "messages": [
        {
            "role": "user",
            "content": $prompt_escaped
        }
    ]
}
EOF

    local api_response
    api_response=$(curl -s --request POST \
        --url https://api.anthropic.com/v1/messages \
        --header "anthropic-version: 2023-06-01" \
        --header "content-type: application/json" \
        --header "x-api-key: $ANTHROPIC_API_KEY" \
        --data-binary "@$payload_file" 2>> "$LOG_FILE")

    local claude_response
    claude_response=$(echo "$api_response" | jq -r '.content[0].text' 2>> "$LOG_FILE")

    if [ "$claude_response" = "null" ] || [ -z "$claude_response" ]; then
        error "Failed to get valid response from Claude API"
        error "API Response: $api_response"
        echo '{"summary": {"total": 0, "top_score": 0, "avg_score": 0}, "jobs": []}' > "$TEMP_DIR/analysis.json"
        return 1
    fi

    # Strip markdown code fences if present
    claude_response=$(echo "$claude_response" | sed 's/^```json[[:space:]]*//' | sed 's/^```[[:space:]]*//' | sed 's/[[:space:]]*```$//')

    echo "$claude_response" > "$TEMP_DIR/analysis.json"

    if ! jq empty "$TEMP_DIR/analysis.json" 2>> "$LOG_FILE"; then
        error "Invalid JSON response from Claude"
        echo '{"summary": {"total": 0, "top_score": 0, "avg_score": 0}, "jobs": []}' > "$TEMP_DIR/analysis.json"
        return 1
    fi

    # Normalize scores (handle rare case where Claude returns 80 instead of 8.0)
    if jq '
        .jobs = (.jobs | map(
            .score = ((.score | tonumber) | if . > 10 then . / 10 else . end)
        )) |
        .summary.top_score = ((.summary.top_score | tonumber) | if . > 10 then . / 10 else . end) |
        .summary.avg_score = ((.summary.avg_score | tonumber) | if . > 10 then . / 10 else . end)
    ' "$TEMP_DIR/analysis.json" > "$TEMP_DIR/analysis_normalized.json"; then
        mv "$TEMP_DIR/analysis_normalized.json" "$TEMP_DIR/analysis.json"
    else
        rm -f "$TEMP_DIR/analysis_normalized.json"
    fi

    local job_count
    job_count=$(jq -r '.summary.total' "$TEMP_DIR/analysis.json")
    log "Analysis complete: $job_count jobs found and scored"

    return 0
}

# ============================================================================
# DEDUPLICATION
# ============================================================================

mark_new_jobs() {
    log "Checking for new jobs..."

    touch "$JOB_HISTORY_FILE"

    if [ ! -f "$TEMP_DIR/analysis.json" ]; then
        error "Analysis file not found for job tracking"
        return 1
    fi

    local seen_jobs
    seen_jobs=$(cat "$JOB_HISTORY_FILE" 2>/dev/null || echo "")

    local updated_jobs
    updated_jobs=$(jq --arg seen_jobs "$seen_jobs" '
        .jobs = (.jobs | map(
            . + {is_new: (.link as $l | $seen_jobs | contains($l) | not)}
        ))
    ' "$TEMP_DIR/analysis.json")

    if [ -n "$updated_jobs" ]; then
        echo "$updated_jobs" > "$TEMP_DIR/analysis.json"
    fi

    local new_job_urls
    new_job_urls=$(echo "$updated_jobs" | jq -r '.jobs[] | select(.is_new == true) | .link')

    if [ -n "$new_job_urls" ]; then
        echo "$new_job_urls" >> "$JOB_HISTORY_FILE"
        local new_count
        new_count=$(echo "$new_job_urls" | wc -l | tr -d ' ')
        log "Marked $new_count new job(s)"
    else
        log "No new jobs found (all previously seen)"
    fi

    return 0
}

# ============================================================================
# REPORT GENERATION
# ============================================================================

generate_report() {
    log "Generating markdown report..."

    if [ ! -f "$TEMP_DIR/analysis.json" ]; then
        error "Analysis file not found"
        exit 1
    fi

    local total top_score avg_score
    total=$(jq -r '.summary.total' "$TEMP_DIR/analysis.json")
    top_score=$(jq -r '.summary.top_score' "$TEMP_DIR/analysis.json")
    avg_score=$(jq -r '.summary.avg_score' "$TEMP_DIR/analysis.json")

    cat > "$REPORT_FILE" << EOF
# Daily Job Report - $DATE

## Summary
- **Total Jobs Found**: $total
- **Top Score**: $top_score/10
- **Average Score**: $avg_score/10
- **Generated**: $(date +"%Y-%m-%d %H:%M:%S")

---

EOF

    if [ "$total" -eq 0 ]; then
        echo "No job listings found today." >> "$REPORT_FILE"
        log "Report generated (no jobs found)"
        return 0
    fi

    echo "## Job Listings (Ranked by Score)" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"

    local jobs_array
    jobs_array=$(jq -c '.jobs | sort_by(-.score) | .[:15] | .[]' "$TEMP_DIR/analysis.json")

    local job_num=1
    while IFS= read -r job; do
        local score title company location salary link reasoning qualifications is_new new_label

        score=$(echo "$job" | jq -r '.score')
        title=$(echo "$job" | jq -r '.title')
        company=$(echo "$job" | jq -r '.company')
        location=$(echo "$job" | jq -r '.location')
        salary=$(echo "$job" | jq -r '.salary')
        link=$(echo "$job" | jq -r '.link')
        reasoning=$(echo "$job" | jq -r '.reasoning')
        qualifications=$(echo "$job" | jq -r '.qualifications // [] | map("• " + .) | join("\n")')
        is_new=$(echo "$job" | jq -r '.is_new // false')

        if [ "$is_new" = "true" ]; then
            new_label="NEW | "
        else
            new_label=""
        fi

        if [ "$salary" = "null" ] || [ -z "$salary" ]; then
            salary="Not specified"
        fi

        cat >> "$REPORT_FILE" << EOF
### $job_num. $title
${new_label}Score: $score/10

- **Company**: $company
- **Location**: $location
- **Salary**: $salary
- **Link**: $link

**Key Qualifications:**
$qualifications

**Reasoning:** $reasoning

---

EOF

        ((job_num++))
    done <<< "$jobs_array"

    log "Report generated: $REPORT_FILE"
    return 0
}

# ============================================================================
# SLACK NOTIFICATIONS
# ============================================================================

send_slack_notification() {
    if [ -z "${SLACK_WEBHOOK_URL:-}" ]; then
        log "Slack webhook not configured, skipping notification"
        return 0
    fi

    log "Sending Slack notification..."

    if [ ! -f "$TEMP_DIR/analysis.json" ]; then
        error "Analysis file not found for notifications"
        return 1
    fi

    # Alert threshold — jobs at or above this score trigger a detailed alert
    local threshold=6.5

    local high_score_jobs total_jobs top_score avg_score
    high_score_jobs=$(jq "[.jobs[] | select(.score >= $threshold)] | length" "$TEMP_DIR/analysis.json")
    total_jobs=$(jq -r '.summary.total' "$TEMP_DIR/analysis.json")
    top_score=$(jq -r '.summary.top_score' "$TEMP_DIR/analysis.json")
    avg_score=$(jq -r '.summary.avg_score' "$TEMP_DIR/analysis.json")

    if [ "$high_score_jobs" -eq 0 ]; then
        local summary_msg
        if [ "$total_jobs" -eq 0 ]; then
            summary_msg="Daily job check complete. No new postings found."
        else
            summary_msg="Daily job check complete. Found $total_jobs posting(s), none above the alert threshold."
        fi

        local payload
        payload=$(jq -n --arg msg "$summary_msg" '{
            text: $msg
        }')

        curl -s -X POST "$SLACK_WEBHOOK_URL" \
            -H "Content-Type: application/json" \
            -d "$payload" >> "$LOG_FILE" 2>&1
        log "Summary notification sent"
        return 0
    fi

    log "Found $high_score_jobs high-scoring job(s), sending detailed notification..."

    # Build job blocks for high-scoring postings
    local job_blocks=""
    local job_num=1

    while IFS= read -r job; do
        local title company score location salary link qualifications is_new new_label

        title=$(echo "$job" | jq -r '.title' | sed 's/"/\\"/g')
        company=$(echo "$job" | jq -r '.company' | sed 's/"/\\"/g')
        score=$(echo "$job" | jq -r '.score')
        location=$(echo "$job" | jq -r '.location' | sed 's/"/\\"/g')
        salary=$(echo "$job" | jq -r '.salary')
        link=$(echo "$job" | jq -r '.link')
        qualifications=$(echo "$job" | jq -r '.qualifications // [] | map("• " + .) | join("\\n")')
        is_new=$(echo "$job" | jq -r '.is_new // false')

        if [ "$is_new" = "true" ]; then
            new_label="NEW | "
        else
            new_label=""
        fi

        if [ "$salary" = "null" ] || [ -z "$salary" ]; then
            salary="Not specified"
        fi

        job_blocks+=$(cat << EOFJOB
,{
    "type": "section",
    "text": {
        "type": "mrkdwn",
        "text": "${new_label}*${job_num}. ${title}* at *${company}*\nScore: ${score}/10"
    }
},
{
    "type": "section",
    "fields": [
        {"type": "mrkdwn", "text": "*Location:*\n${location}"},
        {"type": "mrkdwn", "text": "*Salary:*\n${salary}"}
    ]
},
{
    "type": "section",
    "text": {
        "type": "mrkdwn",
        "text": "*Qualifications:*\n${qualifications}\n<${link}|View Posting>"
    }
},
{"type": "divider"}
EOFJOB
)
        ((job_num++))
    done < <(jq -c "[.jobs[] | select(.score >= $threshold)] | sort_by(-.score) | .[]" "$TEMP_DIR/analysis.json")

    local slack_payload
    slack_payload=$(cat << EOF
{
    "text": "$high_score_jobs high-priority job(s) found",
    "blocks": [
        {
            "type": "header",
            "text": {"type": "plain_text", "text": "$high_score_jobs High-Priority Job(s) Found"}
        },
        {
            "type": "section",
            "text": {
                "type": "mrkdwn",
                "text": "*Total found:* $total_jobs | *Top score:* $top_score/10 | *Avg:* $avg_score/10"
            }
        },
        {"type": "divider"}
        $job_blocks
    ]
}
EOF
)

    local slack_response
    slack_response=$(curl -s -X POST "$SLACK_WEBHOOK_URL" \
        -H "Content-Type: application/json" \
        -d "$slack_payload" 2>> "$LOG_FILE")

    if [ "$slack_response" = "ok" ]; then
        log "Slack notification sent successfully"
    else
        error "Failed to send Slack notification: $slack_response"
        return 1
    fi

    return 0
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    log "========================================="
    log "Daily Job Check - Starting"
    log "========================================="

    mkdir -p "$BASE_DIR/logs"
    mkdir -p "$BASE_DIR/daily-reports"

    check_dependencies
    check_env_vars

    mkdir -p "$TEMP_DIR"
    touch "$TEMP_DIR/search_results.txt"

    run_boolean_search

    if ! analyze_jobs_with_claude; then
        error "Claude analysis failed (continuing with empty results)"
    fi

    if ! mark_new_jobs; then
        log "WARNING: Failed to mark new jobs (continuing)"
    fi

    if ! generate_report; then
        error "Failed to generate report"
        exit 1
    fi

    if ! send_slack_notification; then
        log "WARNING: Failed to send Slack notification (continuing)"
    fi

    local total_jobs
    total_jobs=$(jq -r '.summary.total' "$TEMP_DIR/analysis.json" 2>/dev/null || echo "0")

    log "========================================="
    log "Daily Job Check - Complete"
    log "Jobs found: $total_jobs"
    log "Report: $REPORT_FILE"
    log "========================================="

    return 0
}

main "$@"
