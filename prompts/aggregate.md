# Aggregation Prompt

> 메인 에이전트가 직접 실행. 변수: `{n_agents}` 성공한 리뷰어 수 · `{document}` 문서 경로 · `{reviews}` `=== Reviewer i ===`로 이어붙인 원문

---

Merge the findings of {n_agents} blind reviewers into one deduplicated, voted list. Add no findings or judgments of your own.

Effort: **default is merge** — over-splitting fragments the consensus signal and inflates the count. Merge findings that share a root cause and consequence even when they quote different sentences, differ in detail, or one is a broader version of the other; keep them separate only when the root cause or consequence differs. Split an entry that bundles distinct defects; a reviewer counts once per issue, and each reviewer finding is credited to one entry only.

- Merge: R1 "§2 promises a refund policy that is never defined", R3 "refund window, method and eligibility are missing" → one issue (the promised policy is absent), both quotes.
- Separate: R1 "price $10/user in §3 vs $12 in §5", R2 "discount 10% in §3 vs 15% in §5" → two issues.

Success: every reviewer finding appears in exactly one entry; quotes, title and Fix are copied from the most specific reviewer, not rewritten; each entry is:

```
### ISS-{n}: {title}
- Verdict: {🔴 | 🟡 | ⚪}
- Type: {type}
- Severity: {median} (R1: …, R2: …)
- Agents: {count}/{n_agents} flagged
- Confidence: {median}/10 (R1: …, R2: …)
- Quotes:
  📍 "{exact quote}" (Section) — R{i}
- Reasoning: ≤40 words
- Fix: ≤15 words
```

- Verdict: 🔴 all {n_agents} flagged · 🟡 at least ceil({n_agents}/2) · ⚪ fewer.
- Type: the majority; on a tie, the tied Types joined by ` / ` in reviewer order.
- Severity / Confidence: median of the reviewers' values as given. With an even count, Severity takes the higher middle value and Confidence the mean of the middle values, rounded down.

Order by Verdict, then Confidence descending; number ISS-1… in that order. If no reviewer found anything, output exactly `No issues found.`

=== DOCUMENT ===

{document}

=== REVIEWER RESULTS ===

{reviews}
