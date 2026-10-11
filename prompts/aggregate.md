# Aggregation Prompt

> 메인 에이전트가 Step 3에서 직접 실행합니다 (서브에이전트 아님).
> `{n_agents}` 성공한 리뷰어 수 · `{document}` 원본 문서 경로 · `{reviews}` `=== Reviewer i ===`로 이어붙인 리뷰어 원문

---

You are aggregating findings from {n_agents} blind reviewers of one document. Your job is to **deduplicate and vote**, not to review: every finding comes from a reviewer, and you add none of your own.

**Coverage**: every finding from every reviewer appears in the output, either as its own entry or merged into another.

## Merge

**Default is merge.** Over-splitting fragments the consensus signal and inflates the count.

- Merge when two findings share the same **root cause** and the same consequence, even if they quote different sentences, differ in detail, or use different terms.
- Keep separate when the root cause or the consequence differs, even if they sit in the same paragraph or have the same Type.
- If one reviewer packed several distinct defects into one entry, split them (or keep labelled sub-points). "Table 2 has a unit error and a wrong total" is two issues, not "Table 2 has errors".
- A reviewer who flags the same defect twice counts once.
- If reviewers contradict (one flags, one explicitly says it is fine), count only those who flagged it and note `R{i} disagreed: {reason}`.

Example — merge: R1 "GDP on page 3 says $21T but the source says $23T", R3 "the GDP figure looks wrong against the cited report" → one issue, R1's version, both quotes.
Example — separate: R1 "GDP figure $21T vs $23T", R2 "growth rate 2.1% vs 3.4%" → two issues.

## Preserve

Downstream evaluation reads these fields, so carry them over rather than rewriting them:

- **Type**: majority of the merged reviewers.
- **Title**: the most specific reviewer's title, verbatim.
- **Reasoning**: the most specific reviewer's argument; you may add one clause saying why the merged quotes share a root cause.
- **Quotes**: every exact quote from every merged reviewer.
- **Fix**: the most specific reviewer's Fix, verbatim.
- **Severity / Confidence**: the median of the reviewers' values, individual values in parentheses — `Confidence: 7 (R1: 8, R2: 7, R3: 5)`. Use the reviewers' scores as given. With an even number of values, Severity takes the higher of the two middle values and Confidence takes their mean, rounded down — `Severity: MAJOR (R2: MAJOR, R3: MINOR)`, `Confidence: 5 (R2: 6, R3: 4)`.

## Tiers

- 🔴 all {n_agents} reviewers flagged it
- 🟡 at least ceil({n_agents}/2), not all
- ⚪ below majority

n=3: 🔴 3/3, 🟡 2/3, ⚪ 1/3 · n=5: 🔴 5/5, 🟡 3–4/5, ⚪ 1–2/5

## Output

```
### ISS-{n}: {title}
- Verdict: 🔴 | 🟡 | ⚪
- Type: {type}
- Severity: {median} ({R1: …, R2: …})
- Agents: {count}/{n_agents} flagged
- Confidence: {median}/10 ({R1: …, R2: …})
- Quotes:
  📍 "{exact quote}" (Section X) — R{i}
- Reasoning: {≤40 words}
- Fix: {≤15 words}
```

Order by Verdict (🔴 → 🟡 → ⚪), then Confidence descending. Number ISS-1… in that order.

Edge cases:
- A reviewer output that is empty or has no ISS entries is excluded: note `R{i} excluded ({reason})` and reduce {n_agents}.
- If every reviewer reported no issues, the whole output is exactly `No issues found.`

---

=== DOCUMENT ===

{document}

=== REVIEWER RESULTS ===

{reviews}
