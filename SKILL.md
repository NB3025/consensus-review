---
name: consensus-review
description: "Consensus review of a document: N=3 blind reviewer subagents hunt defects in parallel, then findings are merged and voted into 🔴/🟡/⚪ consensus tiers. Use when the user asks to review or audit a spec, PRD, RFC, requirements, architecture, contract/NDA, business or implementation plan (리뷰해줘, 문서 검토, 놓친 게 있는지 확인). Short report by default; full report on request (풀 버전, 상세, full). Not for typo/grammar fixes, translation proofreading, or documents under 500 words."
---

# Consensus Review

**Blind** 리뷰어 N명(기본 3)이 서로를 보지 못한 채 같은 문서를 리뷰하고, 메인 에이전트가 그 결과를 합쳐 합의 Tier로 투표합니다. 이 스킬의 효과(재현율 +6.5~30.6%p)는 전적으로 **blind**에서 나옵니다. 리뷰어 사이에 오가는 것은 원본 문서 경로뿐입니다.

두 번째 원칙: **파일이 정본**. 리뷰어 결과, 집계 결과, 리포트는 모두 파일로 남기고, 메인은 파일을 직접 읽습니다. 채팅에는 요약만 둡니다.

규칙 뒤의 이유(실제 사고 이력, 설계 근거)가 필요하면 `references/design-notes.md`를 읽으세요.

## 리포트 모드

| 모드 | 언제 | 문서 옆에 남는 파일 |
|---|---|---|
| **short** (기본) | 항상, 아래 요청이 없을 때 | 이슈 한 줄씩의 짧은 리포트 |
| **full** | "풀 버전", "상세 리포트", "full", "전체 다" | 이슈별 인용·근거·점수가 담긴 전체 리포트 |
| **html** | "HTML로", "브라우저로 볼 수 있게" | full 내용을 HTML로 (`references/html-mode.md`) |

모드와 무관하게 full 상세는 매 실행 세션 디렉토리에 `full-report.md`로 남습니다. 그래서 short로 받은 뒤 "풀 버전 보여줘", "ISS-5 자세히"는 재실행 없이 그 파일에서 답합니다.

## Step 1. 준비

1. `PROJECT_DIR`: 입력이 파일이면 그 파일의 디렉토리, 인라인 텍스트면 cwd.
2. `SESSION_ID` = `{YYYYMMDD-HHMMSS}-{4자 난수}`. `mkdir -p {PROJECT_DIR}/.consensus-review-output/{SESSION_ID}/`.
3. `document_path`: 파일이면 그대로. 인라인 텍스트가 500단어/2KB 이상이면 `{세션 디렉토리}/input.md`로 저장하고 그 경로를 씁니다. 이보다 작을 때만 텍스트를 그대로 넘깁니다.
4. `language`: 한글 문자가 50% 이상이면 `ko`, 아니면 `en`.
5. `doc_type_hint`: 파일명이나 본문 첫 200자로 판정 — `사업계획서` / `기능정의서` (PRD, spec, requirements) / `구현계획서` / `계약서` (NDA, 법률) / `architecture` / `general`.

완료 기준: 세션 디렉토리가 존재하고 다섯 값이 모두 정해졌다.

## Step 2. Blind 리뷰어 N명 병렬 실행

`prompts/review.md`를 리뷰어 프롬프트로, 서브에이전트 N명을 **한 번에 병렬로** 띄웁니다. 각자에게 넘기는 값:

- `{document_path}`, `{language}`, `{doc_type_hint}` — 전원 동일
- `{output_path}` — 리뷰어마다 고유: `{세션 디렉토리}/reviewer-{i}.md`

리뷰어 프롬프트에는 원본 문서 경로와 이 네 값만 들어갑니다. 다른 리뷰어, 이전 실행, 사용자의 기대는 언급하지 않습니다. 리뷰어는 결과를 `{output_path}`에 쓰고 `done`만 반환합니다.

완료 기준: N명 모두 반환했고 `reviewer-{i}.md`가 존재한다.

## Step 3. 집계 (메인이 직접)

1. `reviewer-{i}.md`를 직접 읽어 `=== Reviewer i ===` 머리로 이어붙입니다. 반환 메시지에 내용이 섞여 와도 파일이 정본입니다.
2. `prompts/aggregate.md`를 `{n_agents}` (성공한 리뷰어 수), `{document}` (경로), `{reviews}`로 실행합니다.
3. 집계 결과를 곧바로 `write`로 `{세션 디렉토리}/full-report.md`에 씁니다 — 형식은 `examples/output_template.md`의 **Full**. 집계 결과는 채팅 텍스트로 내보내지 않고 `write`의 content로만 보냅니다.

완료 기준: `full-report.md`에 모든 리뷰어의 모든 지적이 (병합되었든 아니든) 들어 있다.

## Step 4. 리포트와 채팅 요약

문서 옆에 `consensus-review-{원본파일명}-{YYYYMMDD-HHMMSS}.md`를 씁니다 (`.html`은 html 모드).

- **short**: `full-report.md`에서 `examples/output_template.md`의 **Short** 형식으로 렌더링합니다. 이슈마다 한 줄, 새 판단은 더하지 않습니다. "먼저 고칠 것"은 🔴 중 CRITICAL/MAJOR만입니다 (템플릿의 섹션 표).
- **full**: `full-report.md`의 내용을 그대로 씁니다.
- **html**: `references/html-mode.md`를 읽고 따릅니다.

`write`가 성공한 것을 확인한 뒤, 채팅에는 `examples/output_template.md`의 **Chat** 형식만 출력합니다. 리포트 본문은 응답 하나에 한 번, `write`의 content에만 나타납니다.

완료 기준: 리포트 파일이 존재하고 채팅에는 경로와 Chat 요약만 있다.

## 막혔을 때

- **문서 > 60K 토큰**: 청크 분할은 미구현. 토큰 수를 알리고 섹션을 나눠 달라고 요청한 뒤 멈춥니다. 문서를 자르거나 요약해서 진행하지 않습니다.
- **세션 디렉토리 쓰기 실패**: 경로와 원인을 보고하고 멈춥니다. 쓰기 가능한 위치를 사용자가 정합니다 (다른 경로로 자동 이동하거나 인라인 전달로 우회하지 않음).
- **리뷰어 1명 실패/타임아웃**: 남은 리뷰어로 집계하고 리포트 첫 줄에 `Reviewer i 실패 — N={남은 수}로 집계됨`을 적습니다. 재시도하지 않습니다.
- **리포트 `write` 실패**: 1회 재시도 후 `❌ 파일 저장 실패: {에러}`만 채팅에 보고합니다.

## 사용자가 바꿀 수 있는 것

- 리뷰어 수: "5명으로" → N=5 (2명은 비권장).
- 출력 언어: "한국어로" → 리포트 언어 고정. 리뷰어 프롬프트는 그대로.
- 관점: "보안만" → 리뷰어 프롬프트 끝에 한 줄 지시 추가 (전원 동일하게).
- 모드: 위 리포트 모드 표.
