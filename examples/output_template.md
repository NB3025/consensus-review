# 출력 템플릿

세 가지 형식입니다. `{중괄호}`는 실제 값으로 치환하고, 이모지와 레이블은 그대로 씁니다.

- **Full** — `{세션 디렉토리}/full-report.md` (매 실행). full 모드에서는 문서 옆 리포트도 이 내용.
- **Short** — 문서 옆 `consensus-review-{원본}-{YYYYMMDD-HHMMSS}.md` (기본 모드).
- **Chat** — 채팅 응답. 리포트 파일을 쓴 뒤 이것만 출력.

---

## Short

full-report.md에서 렌더링합니다. 이슈 하나에 한 줄: 제목, 위치, Fix. 인용·점수는 넣지 않습니다.

섹션은 Verdict와 Severity로 나눕니다:

| 섹션 | 들어가는 이슈 |
|---|---|
| 🔴 먼저 고칠 것 | 🔴 이면서 Severity CRITICAL 또는 MAJOR |
| 🟡 확인할 것 | 🔴 이면서 MINOR, 그리고 🟡 전부 |
| ⚪ 참고 | ⚪ 전부 |

각 섹션 안에서는 ISS 번호 순. 0개인 섹션은 통째로 생략합니다.

```markdown
# Consensus Review — {문서 이름}

리뷰어 {N}명 · 이슈 {총}개 (🔴 {X} · 🟡 {Y} · ⚪ {Z}) · 먼저 고칠 것 {K}개 · 상세: `{세션 디렉토리}/full-report.md`

## 🔴 먼저 고칠 것 — 전원 합의, CRITICAL/MAJOR
1. **ISS-1 {제목}** ({위치}) — {Fix}
2. **ISS-2 {제목}** ({위치}) — {Fix}

## 🟡 확인할 것 — 다수 합의, 또는 전원 합의 MINOR
3. **ISS-3 {제목}** ({위치}) — {Fix}

## ⚪ 참고 — 1명 지적
- ISS-6 {제목} ({위치})
```

- `{위치}`: 대표 인용의 섹션 괄호에서 가져옵니다 (`§3.2`, `Req 4`). 여러 곳이면 `§1.4 ↔ §3.2`.
- `{Fix}`: 집계된 Fix 그대로. 없으면 Reasoning의 첫 문장.
- ⚪는 Fix 없이 제목과 위치만.
- Severity가 `MAJOR / MINOR`처럼 갈려 있으면 높은 쪽으로 봅니다.

예시:

```markdown
# Consensus Review — requirements.md

리뷰어 3명 · 이슈 9개 (🔴 2 · 🟡 4 · ⚪ 3) · 먼저 고칠 것 2개 · 상세: `.consensus-review-output/20260511-101500-a3f7/full-report.md`

## 🔴 먼저 고칠 것 — 전원 합의, CRITICAL/MAJOR
1. **ISS-1 세션 타임아웃 30분/60분 충돌** (§1.4 ↔ §3.2) — 한 값으로 통일하고 다른 절은 참조로 변경
2. **ISS-2 에러 코드 409 정의 누락** (§5 API) — 409 발생 조건과 응답 본문 추가
```

---

## Full

```markdown
# 📋 Consensus Review 결과 (Full)

**문서**: {문서 이름}
**리뷰어**: {N}명 blind · 총 {총}개 (🔴 {X}, 🟡 {Y}, ⚪ {Z})
**리뷰어별 발견 수**: R1 {a} / R2 {b} / R3 {c}

## 🔴 High Confidence — 전원 합의

{집계 결과의 🔴 ISS 블록 그대로}

## 🟡 Needs Review — 다수 합의

{🟡 ISS 블록 그대로}

## ⚪ Low — 소수 지적

{⚪ ISS 블록 그대로}
```

ISS 블록은 `prompts/aggregate.md`의 Output 형식입니다. 리뷰어 실패·제외가 있었으면 `**리뷰어**` 줄 다음에 그 메모를 둡니다.

---

## Chat

```
✅ Consensus Review 완료 — 이슈 {총}개 (🔴 {X} · 🟡 {Y} · ⚪ {Z}) · 먼저 고칠 것 {K}개

📄 {리포트 경로}

🔴 먼저 고칠 것
1. ISS-1 {제목}
2. ISS-2 {제목}
3. ISS-3 {제목}

"풀 버전" 또는 "ISS-N 자세히"라고 하면 상세를 펼칩니다.
```

- "먼저 고칠 것"(short 리포트의 같은 섹션)에서 최대 3개, 제목만. 0개면 그 자리에 `🔴 먼저 고칠 것 없음 — 확인할 것 {개수}개는 리포트에서 확인하세요`.
- 이슈 0개: `✅ Consensus Review 완료 — 지적된 이슈 없음. 📄 {리포트 경로}`
- full 모드에서는 마지막 줄을 `"ISS-N 자세히"라고 하면 해당 이슈만 펼칩니다.`로.

## 후속 요청

- "풀 버전", "상세 리포트", "전체 다" → `full-report.md`를 문서 옆 `consensus-review-{원본}-{같은 타임스탬프}-full.md`로 복사하고 경로를 알립니다. 사용자가 채팅으로 보여 달라고 하면 그때 내용을 출력합니다.
- "ISS-N 자세히" → `full-report.md`에서 그 ISS 블록만 채팅에 출력합니다.
- "TOP 5로", "요약 다시" → Chat 형식 안에서 조정합니다.
