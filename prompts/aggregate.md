# Aggregation Prompt

> 메인 에이전트가 직접 실행. 변수: `{n_agents}` 성공한 리뷰어 수 · `{document}` 문서 경로 · `{reviews}` `=== Reviewer i ===`로 이어붙인 원문

---

Merge the findings of {n_agents} blind reviewers into one deduplicated, voted list. Add no findings or judgments of your own.

Effort: merge findings that share a root cause and consequence even when worded or quoted differently; split an entry that bundles distinct defects; a reviewer counts once per issue.

Success: every reviewer finding appears in exactly one entry; quotes, title and Fix are copied from the most specific reviewer, not rewritten; each entry is:

```
### ISS-{n}: {title}
- Verdict: 🔴 all {n_agents} flagged | 🟡 at least ceil({n_agents}/2) | ⚪ fewer
- Type: {majority; on a tie, the tied Types joined by " / "}
- Severity: {median} (R1: …, R2: …)   — even count: the higher middle value
- Agents: {count}/{n_agents} flagged
- Confidence: {median}/10 (R1: …, R2: …)   — even count: mean of the middle values, rounded down
- Quotes:
  📍 "{exact quote}" (Section) — R{i}
- Reasoning: ≤40 words
- Fix: ≤15 words
```

Order by Verdict, then Confidence descending; number ISS-1… in that order. If no reviewer found anything, output exactly `No issues found.`

=== DOCUMENT ===

{document}

=== REVIEWER RESULTS ===

{reviews}
