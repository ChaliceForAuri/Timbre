#!/usr/bin/env python3
"""The evidence stage of tools/review.sh (GDR-0030).

Reads one run directory — the pull request's JSON, the gates, the CI snapshot,
the model's structured output, the diff — and writes the review comment
(review.md), the GitHub payload (payload.json), the verdict (verdict.txt) and
the full record (evidence.json). `--self-test` checks the one piece with a
right answer: which (path, line) pairs of a unified diff may carry an inline
comment.

    python3 -I tools/review-evidence.py <run-dir> <pr-number>
    python3 -I tools/review-evidence.py --self-test
"""

import datetime
import json
import re
import sys

HUNK = re.compile(r"@@ -\d+(?:,\d+)? \+(\d+)(?:,\d+)? @@")


def diff_lines(patch: str) -> set[tuple[str, int]]:
    """Every (new path, new line) a unified diff shows on its right side.

    GitHub accepts an inline review comment only on a line that appears in
    the diff: an added line or a context line, numbered in the new file.
    Deleted lines and files have no right-side number and are left out.
    """
    valid: set[tuple[str, int]] = set()
    path: str | None = None
    new: int | None = None
    for line in patch.splitlines():
        if line.startswith("+++ "):
            target = line[4:].strip()
            if target == "/dev/null":
                path = None
            else:
                path = target[2:] if target.startswith("b/") else target
            new = None
        elif line.startswith("@@"):
            m = HUNK.match(line)
            new = int(m.group(1)) if m else None
        elif new is not None and path is not None:
            if line.startswith("+") or line.startswith(" ") or line == "":
                valid.add((path, new))
                new += 1
            elif line.startswith("-") or line.startswith("\\"):
                pass
            else:
                new = None
    return valid


def compose(run: str, pr: str) -> int:
    pr_json = json.load(open(f"{run}/pr.json"))
    meta = json.load(open(f"{run}/meta.json"))
    sha = pr_json["headRefOid"]
    gates = [l.rstrip("\n").split("\t") for l in open(f"{run}/gates.tsv") if l.strip()]
    ci = json.load(open(f"{run}/ci.json"))
    try:
        model = json.load(open(f"{run}/model.json"))
    except (OSError, ValueError):
        model = {}
    out = model.get("structured_output") or None
    model_id = next(iter(model.get("modelUsage", {}).keys()), "unknown")
    cost = model.get("total_cost_usd")
    findings = (out or {}).get("findings", [])
    comp = (out or {}).get("compliance", {})

    gate_failed = any(g[1] == "fail" for g in gates)
    blocking = [f for f in findings if f["severity"] == "blocking"]
    model_says_no = (out or {}).get("verdict") == "changes-needed"
    if meta.get("judgement") == "skipped":
        verdict = "gates only, judgement skipped" if not gate_failed else "changes needed, judgement skipped"
        state = "failure" if gate_failed else "success"
    elif out is None:
        verdict, state = "model review failed", "error"
    elif gate_failed or blocking or model_says_no:
        verdict, state = "changes needed", "failure"
    else:
        verdict, state = "pass", "success"

    valid = diff_lines(open(f"{run}/diff.patch", encoding="utf-8", errors="replace").read())

    def row(k, v):
        return f"| {k} | {v} |"

    tree = "clean tree" if meta.get("clean") else "uncommitted changes"
    L = [f"## Timbre review · {verdict}", "", "| | |", "|---|---|",
         row("Head", f"`{sha}` (`{pr_json['headRefName']}` → `{pr_json['baseRefName']}`)"),
         row("Model", f"`{model_id}`" + (f" · ${cost:.2f}" if isinstance(cost, (int, float)) else "")),
         row("Checklist", f"`docs/design/review.md` @ {meta['checklist']} · inventory @ {meta['inventory']}"),
         row("Tool", f"`tools/review.sh` @ {meta['tool']}, from commit `{meta.get('commit', '')[:12]}` ({tree})"),
         row("Run", f"{meta['started']} by @{meta['user']}"), ""]
    L += ["### Gates", "", "| Gate | Result | Time |", "|---|---|---|"]
    for g in gates:
        L.append(f"| {g[0]} | {g[1]} | {g[2]}s |")
    if ci:
        L += ["", "CI at review time: " + ", ".join(f"{c['name']}: {c['state'].lower()}" for c in ci)]
    L += ["", "### Compliance (review.md §4–5)", ""]
    if comp:
        L += [f"- Personal data: **{comp['personal_data']}** · Network: **{comp['network']}** · "
              f"Storage or logging: **{comp['storage_or_logging']}** · Third party: **{comp['third_party']}**",
              f"- Real data in the repo: **{'yes' if comp['real_data_in_repo'] else 'no'}** · "
              f"User-facing copy: **{comp['user_facing_copy']}** · Rights: **{comp['rights']}** · "
              f"Inventory current: **{'yes' if comp['inventory_current'] else 'no'}**"]
        if comp.get("notes"):
            L += ["", "> " + comp["notes"].replace("\n", "\n> ")]
    else:
        L += ["_Judgement skipped by flag; the gates are the review._" if meta.get("judgement") == "skipped"
              else "_No answers: the model run did not complete._"]
    L += ["", "### Summary", "", (out or {}).get("summary", "_Judgement skipped by flag._" if meta.get("judgement") == "skipped"
                                                else "_No summary: the model run did not complete._")]
    L += ["", f"### Findings ({len(findings)})", ""]
    if not findings:
        L.append("None.")
    for sev in ("blocking", "should-fix", "nit"):
        group = [f for f in findings if f["severity"] == sev]
        if not group:
            continue
        L += [f"**{sev}**", ""]
        for f in group:
            if f.get("path") and f.get("line"):
                where = f"`{f['path']}:{f['line']}` — "
            elif f.get("path"):
                where = f"`{f['path']}` — "
            else:
                where = ""
            L.append(f"- {where}**{f['title']}** ({f['category']}). {f['detail']}"
                     + (f" _{f['suggestion']}_" if f.get("suggestion") else ""))
        L.append("")
    L += ["<sub>Posted by tools/review.sh (GDR-0030). The gates ran on the maintainer's Mac; "
          "the model advises; the maintainer approves by merging.</sub>"]
    body = "\n".join(L)

    comments = [{"path": f["path"], "line": f["line"], "side": "RIGHT",
                 "body": f"**{f['severity']} · {f['category']}** — {f['title']}\n\n{f['detail']}"
                         + (f"\n\n{f['suggestion']}" if f.get("suggestion") else "")}
                for f in findings
                if f.get("path") and f.get("line") and (f["path"], f["line"]) in valid]

    open(f"{run}/review.md", "w").write(body + "\n")
    json.dump({"commit_id": sha, "event": "COMMENT", "body": body, "comments": comments},
              open(f"{run}/payload.json", "w"), indent=1)
    desc = f"{len(gates)} gates, {len(findings)} findings" + (f", {len(blocking)} blocking" if blocking else "")
    open(f"{run}/verdict.txt", "w").write(f"{state}\t{verdict}\t{desc}\n")
    json.dump({"pr": int(pr), "head": sha, "meta": meta, "gates": gates, "ci": ci, "model": model_id,
               "cost_usd": cost, "session": model.get("session_id"), "verdict": verdict, "state": state,
               "review": out,
               "finished": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")},
              open(f"{run}/evidence.json", "w"), indent=1)
    print(f"  verdict: {verdict} ({desc}); inline comments: {len(comments)} of {len(findings)}")
    return 0


FIXTURE = """\
diff --git a/a.swift b/a.swift
index 1111111..2222222 100644
--- a/a.swift
+++ b/a.swift
@@ -10,4 +10,5 @@ struct A {
     let kept = 1
-    let gone = 2
+    let added = 2
+    let alsoAdded = 3
     let tail = 4
diff --git a/old.txt b/old.txt
deleted file mode 100644
--- a/old.txt
+++ /dev/null
@@ -1,2 +0,0 @@
-first
-second
diff --git a/new.md b/new.md
new file mode 100644
--- /dev/null
+++ b/new.md
@@ -0,0 +1,2 @@
+# Title
+
diff --git a/b.swift b/b.swift
--- a/b.swift
+++ b/b.swift
@@ -1,3 +1,3 @@
 one
-two
+deux
 three
\\ No newline at end of file
"""


def self_test() -> int:
    got = diff_lines(FIXTURE)
    expected = {
        ("a.swift", 10), ("a.swift", 11), ("a.swift", 12), ("a.swift", 13),   # context, two added, context
        ("new.md", 1), ("new.md", 2),                                          # a new file, including its blank line
        ("b.swift", 1), ("b.swift", 2), ("b.swift", 3),                        # context, replaced, context
    }
    problems = []
    if got != expected:
        problems.append(f"expected {sorted(expected)}, got {sorted(got)}")
    if any(p == "old.txt" for p, _ in got):
        problems.append("a deleted file has no right-side lines")
    if ("a.swift", 14) in got:
        problems.append("numbering ran past the hunk")
    if problems:
        print("review-evidence self-test FAILED:\n  " + "\n  ".join(problems))
        return 1
    print("review-evidence self-test ok")
    return 0


if __name__ == "__main__":
    if len(sys.argv) == 2 and sys.argv[1] == "--self-test":
        sys.exit(self_test())
    if len(sys.argv) != 3:
        print(__doc__)
        sys.exit(2)
    sys.exit(compose(sys.argv[1], sys.argv[2]))
