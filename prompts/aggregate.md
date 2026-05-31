# Aggregation Prompt

> 이 프롬프트는 `consensus-review` 스킬의 Step 3에서 메인 에이전트가 직접 실행합니다 (서브에이전트 아님).
>
> **변수**:
> - `{n_agents}` — 리뷰어 수 (기본 3)
> - `{document}` — 원본 문서 전체 또는 **파일 경로**. 집계는 1회 호출이라 중복 문제가 없어 인라인 허용. 다만 문서가 매우 크면 경로로 넘기고 `read_file`로 로드해도 됨.
> - `{reviews}` — 각 리뷰어의 raw 출력. `=== Reviewer 1 ===\n...\n\n=== Reviewer 2 ===\n...` 형태로 이어붙임.

---

You are aggregating results from {n_agents} independent reviewers who examined a document for defects.

Your job: collect all unique findings, merge duplicates, and assign agreement tiers.

**IMPORTANT**: Only report what reviewers explicitly identified. Do not invent, infer, or extrapolate issues beyond what reviewers stated. Adding your own findings will corrupt the aggregation and invalidate the results.

## Merge Rules

**COVERAGE RULE**: Every finding from every reviewer must appear in output — either as its own entry or merged into another. Missing a reviewer's finding is a failure.

**DEFAULT ACTION IS MERGE.** When in doubt, merge. **Over-splitting fragments the consensus signal and inflates the issue count** — this breaks downstream tier classification and recall measurement.

1. MERGE if two issues describe the SAME underlying problem — same root cause, same consequence — even if quoted text differs.
2. SEPARATE only if genuinely DIFFERENT problems: different root cause OR different consequence.
3. When merging, keep the most specific description. Preserve all distinct quotes from each reviewer.
4. If one reviewer flags it and another says "not a problem", count ONLY those who flagged it as an error.

### Merge Examples

MERGE (same root cause):
- Reviewer 1: "GDP figure on page 3 says $21T but source says $23T"
- Reviewer 3: "The GDP number appears incorrect based on the cited report"
→ One issue. Keep Reviewer 1's version (more specific). Cite both.

SEPARATE (different root cause):
- Reviewer 1: "GDP figure is wrong — $21T vs $23T"
- Reviewer 2: "GDP growth rate is wrong — 2.1% vs 3.4%"
→ Two issues. Different data points, different errors.

## Recognize your own merge biases

You will be tempted to split issues that should be merged:
- "They quoted different sentences" — different quotes can describe the same error. Merge.
- "One reviewer was more detailed" — detail level is not a reason to separate. Merge and keep the detailed version.
- "They used different terminology" — terminology is not root cause. If the underlying problem is the same, merge.

You will also be tempted to merge issues that should be separate:
- "They're in the same paragraph" — proximity is not sameness. Check root cause.
- "They're the same type of error" — two typos are two issues if they're different words.

**If you catch yourself justifying a merge with "close enough" or a split with "slightly different wording", stop.** Re-check root cause and consequence — if they match, merge; otherwise split. Do not rationalize past the rule.

## Preservation Rules

These rules exist because downstream evaluation uses Type, Title, and Reasoning as signals. Rewriting reviewer findings breaks this.

1. **Type preservation**: When merging, use the Type assigned by the MAJORITY of reviewers. Do NOT reclassify based on your own judgment.
2. **Title preservation**: Use the most specific reviewer's title VERBATIM. Do NOT paraphrase.
3. **Framing preservation**: Keep the most specific reviewer's reasoning structure intact. You may ADD quotes from other reviewers, but do NOT reframe the core argument.
4. **Evidence preservation**: Every exact quote cited by any reviewer MUST appear in the merged output. Do not summarize or paraphrase quotes.
5. **Granularity preservation**: If a reviewer packed multiple distinct errors into one ISS entry, preserve each separately — either as sub-points within the merged entry or as separate issues.

   **Example**:
   - Reviewer 2 ISS-4: "Table 2 has two problems: the units column says 'kg' but should be 'g', and the total row sums wrong."
   → Split into two ISS entries (different root causes: unit error vs arithmetic error), or keep one entry with two clearly-labeled sub-points. **Do not collapse into "Table 2 has errors."**

## Agreement Tiers

- 🔴 **High Confidence**: all {n_agents} reviewers agreed
- 🟡 **Needs Review**: majority (≥ ceil({n_agents}/2)) but not all
- ⚪ **Low**: below majority

For {n_agents}=3: 🔴 = 3/3, 🟡 = 2/3, ⚪ = 1/3

**Examples for other n**:
- {n_agents}=5: 🔴 = 5/5, 🟡 = 3–4/5, ⚪ = 1–2/5
- {n_agents}=7: 🔴 = 7/7, 🟡 = 4–6/7, ⚪ = 1–3/7

## Scoring (리뷰어 값 재사용)

리뷰어가 이미 각 ISS에 Confidence(1-10)와 Evidence Strength(1-5)를 부여했습니다 (`prompts/review.md`의 앵커 정의 참조). Aggregator는 **재평가하지 말고** 리뷰어 값을 그대로 사용하세요.

- 복수 리뷰어가 같은 이슈에 서로 다른 값을 준 경우: **중앙값(median)**을 output에 기록. 괄호 안에 개별 값도 표기.
  - 예: `Confidence: 7 (R1: 8, R2: 7, R3: 5)`
- 단일 리뷰어만 점수를 준 경우: 그 값 그대로.

기준 재정의는 **금지** — 리뷰어의 앵커 정의(Confidence 9-10 = "direct contradiction with two exact quotes" 등)가 시스템 기준입니다.

## Output Format

For each issue:

```
### ISS-{number}: {title}
- Verdict: 🔴 | 🟡 | ⚪
- Type: {type}
- Agents: {count}/{n_agents} flagged
- Confidence: {score}/10 — {justification}
- Evidence Strength: {score}/5
- Quotes:
  📍 "{exact quote}" — Reviewer {id}
- Reasoning: ≤40 words. State the defect in one sentence. If merged, add one sentence explaining why the quotes describe the same root cause. If split, omit the merge clause.
```

Order by: Verdict (🔴 → 🟡 → ⚪), then Confidence descending.

**Reasoning 예시**:
- Good (merged): `"Section 3과 7이 uptime SLA 99.99% vs 99.9%로 상충 (R1·R3). 동일 root cause — uptime 계약 불이행."`
- Good (split): `"Section 4 결제 흐름에 refund 경로 누락."`
- Bad (re-quoting filler): `"As Reviewer 1 noted, Section 3 says 99.99%..."`
- Bad (vague): `"This causes inconsistency."`

If no issues found across ALL reviewers: respond with exactly "No issues found."

## Edge Cases

- Reviewer output is empty, contains no ISS-N entries, or cannot be split into discrete findings → exclude that reviewer. Note: `"R{n} excluded (reason: {empty | no ISS entries | unstructured})"`. Adjust denominator accordingly.
- Single reviewer duplicates the same finding across multiple ISS entries within their own output → count as **ONE flag** from that reviewer. Preserve all quotes, but do not inflate the denominator.
- Reviewers directly contradict on the SAME finding (one flags error, another explicitly says "not a problem") → count only those who flagged it. Note in Reasoning: `"R{n} disagreed: {their reason}"`.
- All reviewers report 0 issues → respond with exactly "No issues found." **Do not search for issues yourself.**

## Reminders

- DEFAULT IS MERGE. Prefer fewer well-supported items over many fragments.
- Only report what reviewers found. Do not add your own findings. Doing so invalidates the aggregation.
- Every issue from every reviewer must appear — either as its own entry or merged into another.
- PRESERVE reviewer Type, Title, and Reasoning verbatim. Your role is to deduplicate and vote, not to rewrite.

---

=== DOCUMENT ===

{document}

=== REVIEWER RESULTS ===

{reviews}
