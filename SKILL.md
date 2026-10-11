---
name: consensus-review
description: "Consensus review of a document: N=3 blind reviewer subagents hunt defects in parallel, then findings are merged and voted into 🔴/🟡/⚪ consensus tiers. Use when the user asks to review or audit a spec, PRD, RFC, requirements, architecture, contract/NDA, business or implementation plan (리뷰해줘, 문서 검토, 놓친 게 있는지 확인). Short report by default; full report on request (풀 버전, 상세, full). Not for typo/grammar fixes, translation proofreading, or documents under 500 words."
---

# Consensus Review

**원하는 것**: 문서 결함을 놓치지 않기. 리뷰어 N명(기본 3)이 **blind**로 — 서로의 결과도, 이전 실행도 보지 않고 — 같은 문서를 리뷰하고, 합의 정도로 우선순위를 매깁니다. 효과는 전부 blind에서 나옵니다.

**노력**: 리뷰어는 병렬 서브에이전트로 한 번에 띄우고 `prompts/review.md`에 문서 **경로**, 각자의 출력 경로, `language`(한글 50% 이상이면 ko, 아니면 en), `doc_type_hint`(파일명·첫 200자로: 사업계획서 / 기능정의서 / 구현계획서 / 계약서 / architecture / general)만 채워 줍니다. 메인은 합치기만 하고 새 판단을 더하지 않습니다.

**성공**:
- `{문서 디렉토리}/.consensus-review-output/{YYYYMMDD-HHMMSS-4자난수}/`에 `reviewer-{i}.md`(리뷰어가 씀)와 `full-report.md`(`prompts/aggregate.md` 결과를 `examples/output_template.md`의 Full 형식으로)가 있다.
- 문서 옆 `consensus-review-{원본파일명}-{YYYYMMDD-HHMMSS}.md`가 Short 형식이다 ("풀 버전"/"full"이면 Full, "HTML로"면 `references/html-mode.md`).
- 채팅에는 템플릿의 Chat 형식만 있다. "풀 버전", "ISS-N 자세히"는 재실행 없이 `full-report.md`에서 답한다.

리뷰어가 실패하면 남은 수로 집계하고 리포트 첫 줄에 적습니다. 문서가 60K 토큰을 넘거나 쓰기가 실패하면 이유를 알리고 멈춥니다. 설계 이유: `references/design-notes.md`.
