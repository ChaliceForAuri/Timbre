#!/usr/bin/env bash
#
# Review a pull request here, on this Mac, and post the evidence to it (GDR-0030).
#
#   tools/review.sh <pr> [--dry-run] [--skip-gates] [--no-status] [--model <id>]
#
# Gates first, deterministically: lint, the tests of the packages the change
# touches, the Mac app and companion builds, the Backstage JSON drift check,
# the site's type check and build. Then judgement: Claude Code in headless
# mode on this Mac reads the pull request against docs/design/review.md and
# docs/design/data-inventory.md and returns findings in the shape of
# tools/review-schema.json. Then evidence: one review comment on the pull
# request, inline comments where a finding has a line, and a commit status
# `timbre/review` that branch protection can require.
#
# --dry-run writes everything under .review/<pr>-<sha>/ and posts nothing.
# --skip-gates trusts CI for the gates (they are recorded as skipped).
#
# The gates run here. The judgement sends the diff and the files the model
# reads to Anthropic's API under your own Claude account; nothing else leaves
# the Mac, and no user data is ever in the repository (review.md, C5).
#
# Exit 0 on pass, 1 on changes needed or a failed gate, 2 when the tool
# itself could not complete.

set -euo pipefail
cd "$(dirname "$0")/.."
ROOT=$(pwd)

# Everything runs inside main so bash parses the whole file before executing
# any of it: an edit to this script while a review is running then cannot
# corrupt that run.
main() {

PR=""; DRY=0; SKIP_GATES=0; NO_STATUS=0; MODEL=""
while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY=1 ;;
        --skip-gates) SKIP_GATES=1 ;;
        --no-status) NO_STATUS=1 ;;
        --model) MODEL="$2"; shift ;;
        -h|--help) sed -n '3,24p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) if [[ "$1" =~ ^[0-9]+$ ]]; then PR="$1"; else echo "unknown argument: $1" >&2; exit 2; fi ;;
    esac
    shift
done
[ -n "$PR" ] || { echo "usage: tools/review.sh <pr> [--dry-run] [--skip-gates] [--no-status] [--model <id>]" >&2; exit 2; }

for t in gh claude jq python3 xcrun git; do
    command -v "$t" >/dev/null || { echo "tools/review.sh needs $t" >&2; exit 2; }
done
gh auth status >/dev/null 2>&1 || { echo "gh is not logged in" >&2; exit 2; }
REPO=$(gh repo view --json nameWithOwner --jq .nameWithOwner)

# ---- The pull request -------------------------------------------------------

PR_JSON=$(gh pr view "$PR" --json number,title,body,url,headRefName,headRefOid,baseRefName,files,author,isDraft)
SHA=$(jq -r .headRefOid <<<"$PR_JSON")
SHORT=${SHA:0:7}
TITLE=$(jq -r .title <<<"$PR_JSON")
RUN="$ROOT/.review/$PR-$SHORT"
mkdir -p "$RUN"
printf '%s' "$PR_JSON" > "$RUN/pr.json"
jq -r '.files[].path' <<<"$PR_JSON" > "$RUN/files.txt"
gh pr diff "$PR" > "$RUN/diff.patch"
echo "Reviewing #$PR \"$TITLE\" at $SHORT → $RUN"

# The tree under review, checked out beside the evidence. The checklist and
# the tool come from this checkout, not from the pull request: they are the
# review's version, and both hashes go on the record.
WT="$RUN/tree"
git fetch -q origin "refs/pull/$PR/head"
[ "$(git rev-parse FETCH_HEAD)" = "$SHA" ] || { echo "the pull request moved while fetching; run again" >&2; exit 2; }
git worktree remove --force "$WT" >/dev/null 2>&1 || true
git worktree add -q --detach "$WT" "$SHA"
trap 'git -C "$ROOT" worktree remove --force "$WT" >/dev/null 2>&1 || true' EXIT

hash_of() { shasum -a 256 "$@" | shasum -a 256 | cut -c1-12; }
TOOL_HASH=$(hash_of tools/review.sh tools/review-schema.json)
CHECKLIST_HASH=$(hash_of docs/design/review.md)
INVENTORY_HASH=$(hash_of docs/design/data-inventory.md)
jq -n --arg tool "$TOOL_HASH" --arg checklist "$CHECKLIST_HASH" --arg inventory "$INVENTORY_HASH" \
    --arg host "$(hostname -s)" --arg user "$(gh api user --jq .login)" \
    --arg started "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg repo "$REPO" \
    '{tool: $tool, checklist: $checklist, inventory: $inventory, host: $host, user: $user, started: $started, repo: $repo}' \
    > "$RUN/meta.json"

# ---- Gates ------------------------------------------------------------------

GATES="$RUN/gates.tsv"
: > "$GATES"
touched() { grep -q -E "$1" "$RUN/files.txt"; }
gate() { # name  log-slug  command (a shell string, run in the tree)
    local name="$1" slug="$2" cmd="$3" start result secs
    start=$(date +%s)
    if ( cd "$WT" && eval "$cmd" ) > "$RUN/gate-$slug.log" 2>&1; then result=pass; else result=fail; fi
    secs=$(( $(date +%s) - start ))
    printf '%s\t%s\t%s\tgate-%s.log\n' "$name" "$result" "$secs" "$slug" >> "$GATES"
    printf '  %-36s %-4s %4ss\n' "$name" "$result" "$secs"
}
skipped() { printf '%s\tskipped\t0\t%s\n' "$1" "$2" >> "$GATES"; printf '  %-36s skipped (%s)\n' "$1" "$2"; }

if [ "$SKIP_GATES" = 1 ]; then
    skipped "all gates" "--skip-gates; CI is the record"
else
    echo "Gates:"
    DD="$ROOT/.review/DerivedData"
    gate "swift-format lint" lint "xcrun swift-format lint --strict --recursive packages apps/Timbre/Sources"
    for p in TimbreCore TimbreSpeech TimbreModel TimbreReminders TimbreCloud; do
        if touched "^packages/$p/"; then gate "$p tests" "test-$p" "swift test --package-path packages/$p"; fi
    done
    if touched '^packages/'; then gate "TimbreKit tests" test-TimbreKit "swift test --package-path packages/TimbreKit"; fi
    if touched '^packages/TimbreRelay/'; then
        sim=$(xcrun simctl list devices available -j | jq -r '.devices | to_entries[] | select(.key | contains("iOS")) | .value[] | select(.name | startswith("iPhone")) | .name' | head -1)
        if [ -n "$sim" ]; then
            gate "TimbreRelay tests ($sim)" test-TimbreRelay "cd packages/TimbreRelay && xcodebuild test -scheme TimbreRelay -destination 'platform=iOS Simulator,name=$sim' -derivedDataPath '$DD' CODE_SIGNING_ALLOWED=NO"
        else
            skipped "TimbreRelay tests" "no iPhone simulator"
        fi
    fi
    if touched '^(packages/|apps/Timbre/)'; then
        gate "Mac app build" build-mac "xcodebuild -project apps/Timbre/Timbre.xcodeproj -scheme Timbre -destination 'platform=macOS' -derivedDataPath '$DD' build CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=NO"
    fi
    if touched '^(packages/|apps/Companion/)'; then
        gate "Companion build" build-companion "xcodebuild -project apps/Companion/Companion.xcodeproj -scheme Timbre -destination 'generic/platform=iOS Simulator' -derivedDataPath '$DD' build CODE_SIGNING_ALLOWED=NO"
    fi
    if touched '^(docs/|CHANGELOG\.md|web/|packages/[^/]+/Fixtures/)'; then
        [ -e "$WT/web/node_modules" ] || ln -s "$ROOT/web/node_modules" "$WT/web/node_modules"
        gate "Backstage JSON is regenerated" docs-drift 'cd web && npx -y pnpm@9 run --silent sync:docs && cd .. && d=$(git status --porcelain -- web/src/lib) && { [ -z "$d" ] || { echo "drift:"; echo "$d"; exit 1; }; }'
        # The architecture views are generated, not committed; a fresh tree
        # needs them before the site can build, and generating validates the model.
        gate "Architecture model generates" architecture 'cd web && npx -y pnpm@9 run --silent gen:architecture'
        gate "Site type-checks" web-check 'cd web && npx -y pnpm@9 run --silent check'
        gate "Site builds" web-build 'cd web && npx -y pnpm@9 run --silent build'
    fi
    [ -s "$GATES" ] || skipped "no gate applies" "nothing under packages, apps, docs or web changed"
fi

gh pr checks "$PR" --json name,state,link > "$RUN/ci.json" 2>/dev/null || echo '[]' > "$RUN/ci.json"

# ---- Judgement --------------------------------------------------------------

{
    echo "You are the reviewer GDR-0030 describes, running on the maintainer's Mac through Claude Code."
    echo "Your instructions are the checklist below, then the data inventory it refers to. You are inside a"
    echo "checkout of the pull request's head commit: read any file you need with Read, Grep and Glob, and"
    echo "stay inside that tree and the run directory named in the prompt. Never edit anything. Answer every"
    echo "section of the checklist. Findings quote what the code does; a finding you could not verify says so."
    echo "Return exactly the structured output requested, with repository-relative paths and new-file lines."
    echo
    echo "==== docs/design/review.md ===="
    cat docs/design/review.md
    echo
    echo "==== docs/design/data-inventory.md ===="
    cat docs/design/data-inventory.md
} > "$RUN/system.md"

{
    echo "# Pull request #$PR: $TITLE"
    echo
    echo "Base \`$(jq -r .baseRefName <<<"$PR_JSON")\`, head \`$(jq -r .headRefName <<<"$PR_JSON")\` at \`$SHA\`."
    echo "The tree is your working directory. The full diff is also at \`$RUN/diff.patch\`."
    echo
    echo "## Description"
    echo
    jq -r .body <<<"$PR_JSON"
    echo
    echo "## Files changed"
    echo
    sed 's/^/- /' "$RUN/files.txt"
    echo
    echo "## Gates (already run)"
    echo
    awk -F'\t' '{ printf "- %s: %s (%ss)\n", $1, $2, $3 }' "$GATES"
    echo
    echo "## Diff"
    echo
    if [ "$(wc -c < "$RUN/diff.patch")" -gt 600000 ]; then
        echo "The diff is $(( $(wc -c < "$RUN/diff.patch") / 1024 )) KB, too large to inline: read \`$RUN/diff.patch\` in parts."
    else
        echo '```diff'
        cat "$RUN/diff.patch"
        echo '```'
    fi
} > "$RUN/prompt.md"

echo "Judgement (${MODEL:-default model}) …"
set +e
( cd "$WT" && claude -p \
    --output-format json \
    --json-schema "$(cat "$ROOT/tools/review-schema.json")" \
    --append-system-prompt-file "$RUN/system.md" \
    --allowedTools "Read,Grep,Glob" \
    --add-dir "$RUN" \
    --max-turns 80 \
    ${MODEL:+--model "$MODEL"} \
    < "$RUN/prompt.md" > "$RUN/model.json" 2> "$RUN/model.err" )
MODEL_EXIT=$?
set -e
[ "$MODEL_EXIT" = 0 ] || echo "  the model run exited $MODEL_EXIT (see $RUN/model.err)"

# ---- Evidence ---------------------------------------------------------------

python3 -I - "$RUN" "$PR" <<'PY'
import datetime, json, re, sys

run, pr = sys.argv[1], sys.argv[2]
pr_json = json.load(open(f"{run}/pr.json"))
meta = json.load(open(f"{run}/meta.json"))
sha = pr_json["headRefOid"]
gates = [l.rstrip("\n").split("\t") for l in open(f"{run}/gates.tsv") if l.strip()]
ci = json.load(open(f"{run}/ci.json"))
try:
    model = json.load(open(f"{run}/model.json"))
except Exception:
    model = {}
out = model.get("structured_output") or None
model_id = next(iter(model.get("modelUsage", {}).keys()), "unknown")
cost = model.get("total_cost_usd")
findings = (out or {}).get("findings", [])
comp = (out or {}).get("compliance", {})

gate_failed = any(g[1] == "fail" for g in gates)
blocking = [f for f in findings if f["severity"] == "blocking"]
if out is None:
    verdict, state = "model review failed", "error"
elif gate_failed or blocking:
    verdict, state = "changes needed", "failure"
else:
    verdict, state = "pass", "success"

# Lines the pull request's diff touches, by new-file number: the only places
# GitHub accepts an inline comment.
valid, path, new = set(), None, None
for line in open(f"{run}/diff.patch", encoding="utf-8", errors="replace"):
    if line.startswith("+++ "):
        p = line[4:].strip()
        path = None if p == "/dev/null" else (p[2:] if p.startswith("b/") else p)
        new = None
    elif line.startswith("@@"):
        m = re.match(r"@@ -\d+(?:,\d+)? \+(\d+)(?:,\d+)? @@", line)
        new = int(m.group(1)) if m else None
    elif new is not None and path:
        if line.startswith("+") or line.startswith(" "):
            valid.add((path, new)); new += 1
        elif line.startswith("-") or line.startswith("\\"):
            pass
        else:
            new = None

def row(k, v): return f"| {k} | {v} |"
L = [f"## Timbre review · {verdict}", "", "| | |", "|---|---|",
     row("Head", f"`{sha}` (`{pr_json['headRefName']}` → `{pr_json['baseRefName']}`)"),
     row("Model", f"`{model_id}`" + (f" · ${cost:.2f}" if isinstance(cost, (int, float)) else "")),
     row("Checklist", f"`docs/design/review.md` @ {meta['checklist']} · inventory @ {meta['inventory']}"),
     row("Tool", f"`tools/review.sh` @ {meta['tool']}"),
     row("Run", f"{meta['started']} on {meta['host']} by @{meta['user']}"), ""]
L += ["### Gates", "", "| Gate | Result | Time |", "|---|---|---|"]
for g in gates:
    L.append(f"| {g[0]} | {g[1]} | {g[2]}s |")
if ci:
    L += ["", "CI at review time: " + ", ".join(f"{c['name']}: {c['state'].lower()}" for c in ci)]
L += ["", "### Compliance (review.md §4–5)", ""]
if comp:
    L += [f"- Personal data: **{comp['personal_data']}** · Network: **{comp['network']}** · Storage or logging: **{comp['storage_or_logging']}** · Third party: **{comp['third_party']}**",
          f"- Real data in the repo: **{'yes' if comp['real_data_in_repo'] else 'no'}** · User-facing copy: **{comp['user_facing_copy']}** · Rights: **{comp['rights']}** · Inventory current: **{'yes' if comp['inventory_current'] else 'no'}**"]
    if comp.get("notes"):
        L += ["", "> " + comp["notes"].replace("\n", "\n> ")]
else:
    L += ["_No answers: the model run did not complete._"]
L += ["", "### Summary", "", (out or {}).get("summary", "_No summary: the model run did not complete._")]
L += ["", f"### Findings ({len(findings)})", ""]
if not findings:
    L.append("None.")
for sev in ("blocking", "should-fix", "nit"):
    group = [f for f in findings if f["severity"] == sev]
    if not group:
        continue
    L += [f"**{sev}**", ""]
    for f in group:
        where = f"`{f['path']}:{f['line']}` — " if f.get("path") and f.get("line") else (f"`{f['path']}` — " if f.get("path") else "")
        L.append(f"- {where}**{f['title']}** ({f['category']}). {f['detail']}" + (f" _{f['suggestion']}_" if f.get("suggestion") else ""))
    L.append("")
L += ["<sub>Posted by tools/review.sh (GDR-0030). The gates ran on the maintainer's Mac; the model advises; the maintainer approves by merging.</sub>"]
body = "\n".join(L)

comments = [{"path": f["path"], "line": f["line"], "side": "RIGHT",
             "body": f"**{f['severity']} · {f['category']}** — {f['title']}\n\n{f['detail']}" + (f"\n\n{f['suggestion']}" if f.get('suggestion') else "")}
            for f in findings if f.get("path") and f.get("line") and (f["path"], f["line"]) in valid]

open(f"{run}/review.md", "w").write(body + "\n")
json.dump({"commit_id": sha, "event": "COMMENT", "body": body, "comments": comments}, open(f"{run}/payload.json", "w"), indent=1)
desc = f"{len(gates)} gates, {len(findings)} findings" + (f", {len(blocking)} blocking" if blocking else "")
open(f"{run}/verdict.txt", "w").write(f"{state}\t{verdict}\t{desc}\n")
json.dump({"pr": int(pr), "head": sha, "meta": meta, "gates": gates, "ci": ci, "model": model_id, "cost_usd": cost,
           "session": model.get("session_id"), "verdict": verdict, "state": state, "review": out,
           "finished": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")},
          open(f"{run}/evidence.json", "w"), indent=1)
print(f"  verdict: {verdict} ({desc}); inline comments: {len(comments)} of {len(findings)}")
PY

IFS=$'\t' read -r STATE VERDICT DESC < "$RUN/verdict.txt"

# ---- Post -------------------------------------------------------------------

if [ "$DRY" = 1 ]; then
    echo "Dry run: nothing posted. The review is at $RUN/review.md"
else
    if ! REVIEW_JSON=$(gh api --method POST "repos/$REPO/pulls/$PR/reviews" --input "$RUN/payload.json" 2>"$RUN/post.err"); then
        echo "  inline comments refused ($(head -c 200 "$RUN/post.err")); posting the body alone"
        jq 'del(.comments)' "$RUN/payload.json" > "$RUN/payload-body-only.json"
        REVIEW_JSON=$(gh api --method POST "repos/$REPO/pulls/$PR/reviews" --input "$RUN/payload-body-only.json")
    fi
    URL=$(jq -r .html_url <<<"$REVIEW_JSON")
    echo "Posted: $URL"
    if [ "$NO_STATUS" = 0 ]; then
        gh api --method POST "repos/$REPO/statuses/$SHA" -f state="$STATE" -f context="timbre/review" \
            -f description="$VERDICT: $DESC" -f target_url="$URL" >/dev/null
        echo "Status timbre/review = $STATE on $SHORT"
    fi
fi

case "$STATE" in success) exit 0 ;; failure) exit 1 ;; *) exit 2 ;; esac
}

main "$@"
