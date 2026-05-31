# 출력 템플릿 — 파일 전체 리포트 + 채팅 요약 분리

> 메인 에이전트가 집계 결과(Step 3)를 받은 뒤 두 곳에 결과를 남깁니다:
>
> - **파일 (전체 상세 리포트)**: `consensus-review-{원본}-{YYYYMMDD-HHMMSS}.md`
> - **채팅 (짧은 요약)**: 저장 경로 + 요약만 출력.

> 🔒 **불변식 (Invariant)**
>
> 전체 리포트 본문은 한 응답에 **오직 한 곳에만** 등장합니다 — `write.content`.
> `assistant_text`(= 채팅)에는 B 섹션의 **리터럴 템플릿**만 들어갑니다.
> 이 불변식 위반 시 `max_output_tokens`를 넘어 **InvalidJson 크래시가 발생하고 세션이 종료됩니다** (2026-04-28 실제 사고).

---

## === RECOGNIZE YOUR OWN RATIONALIZATIONS ===

당신은 아래 핑계로 B 템플릿을 벗어나려는 충동을 느낄 것입니다. **전부 무시하세요**:

- ❌ "사용자가 바로 볼 수 있게 🔴 이슈 본문도 채팅에 넣자" — 금지. 제목만.
- ❌ "Quote 1~2개 정도는 채팅에 넣어도 안전하지 않을까" — 금지. 제목만.
- ❌ "파일 쓰기가 실패할 수도 있으니 채팅에도 백업으로 넣자" — 금지. 실패하면 재시도하거나 실패를 보고.
- ❌ "사용자가 요약을 원하면 상세도 원할 것이다" — 금지. 명시적 "상세" 요청 전엔 경로만.

**B 템플릿 외의 모든 본문 복제는 REJECT 대상입니다.**

---

## A. 파일에 저장할 전체 리포트 형식

`write.content`에 담을 내용. 상세 리포트 전문은 여기에만.

### 치환 규칙

- `{중괄호}`는 실제 값으로 치환. 중괄호 자체는 출력 금지.
- 이모지/레이블(📋, 🔴, 🟡, ⚪, 💡)은 **리터럴**. 번역·축약·삭제 금지.
- 섹션 순서와 빈 줄 위치는 유지.

**Good**: `"📄 저장 경로: ./consensus-review-foo-20260428-010700.md"`
**Bad (플레이스홀더 잔존)**: `"📄 저장 경로: ./consensus-review-{원본}-{YYYYMMDD-HHMMSS}.md"`
**Bad (리터럴 변경)**: `"📄 Path: ./consensus-review-foo-20260428-010700.md"`

### 파일 템플릿

```markdown
# 📋 Consensus Review 결과

**문서**: {문서 이름 또는 간략 요약}
**리뷰어 수**: {N}명 독립 (Consensus Review 스킬)
**총 고유 이슈**: {총 개수}개 (🔴 {X}, 🟡 {Y}, ⚪ {Z})

| 리뷰어 | 발견한 결함 수 |
|---|---:|
| Reviewer 1 | {a}건 |
| Reviewer 2 | {b}건 |
| Reviewer 3 | {c}건 |

---

## 🔴 High Confidence — 전원 합의 ({X}개)

> 3명 전원이 지적한 이슈입니다. 우선 처리 대상입니다.

### ISS-1: {제목 ≤12 단어}

- **Verdict**: 🔴
- **Type**: {Inconsistency / Omission / Ambiguity / Terminology / Structural}
- **Severity**: {CRITICAL / MAJOR / MINOR}
- **Agents**: {count}/{N} flagged
- **Confidence**: {median}/10 (R1: {x}, R2: {y}, R3: {z})
- **Evidence Strength**: {median}/5
- **Quotes**:
  - 📍 "{exact quote}" — Reviewer 1
  - 📍 "{exact quote}" — Reviewer 2
  - 📍 "{exact quote}" — Reviewer 3
- **Reasoning**: {≤40 words}

### ISS-2: ...

---

## 🟡 Needs Review — 다수 합의 ({Y}개)

🔴와 동일 포맷. `Verdict`만 🟡로 변경.

---

## ⚪ Low — 소수 지적 ({Z}개)

- **ISS-N**: {제목} — {한 줄 요약}
- **ISS-N+1**: {제목} — {한 줄 요약}

---

## 💡 권장 조치

- 🔴부터 우선 검토하세요. 3명 전원 합의라 진짜 결함일 확률이 높습니다.
- 시간 여유가 있으면 🟡까지. 다수 합의라 정밀도 중간 이상입니다.
- ⚪는 리소스 여유 시에만. 환각 가능성이 상대적으로 큽니다.
```

---

## B. 채팅에 출력할 **짧은 요약** 형식

`assistant_text`에 담을 내용. **B 템플릿의 리터럴만** 출력. 전체 상세 복제 금지.

### 채팅 템플릿

```
✅ Consensus Review 완료

📄 저장 경로: ./consensus-review-{원본}-{YYYYMMDD-HHMMSS}.md

📊 요약
- 총 이슈: {N}개 (🔴 {X}, 🟡 {Y}, ⚪ {Z})
- 리뷰어별 발견 수: R1 {a}건 / R2 {b}건 / R3 {c}건

🔴 High Confidence TOP 3 (각 제목 ≤15 단어, Quote·Reasoning 금지):
1. ISS-1: {제목 ≤15 단어}
2. ISS-2: {제목 ≤15 단어}
3. ISS-3: {제목 ≤15 단어}

💡 전체 상세는 위 저장 경로의 파일을 열어보세요.
   "ISS-N 자세히"라고 하면 특정 이슈만 펼쳐드릴 수 있습니다.
```

### === 출력 예시 ===

**Good** (채팅 출력이 이래야 합니다):

```
✅ Consensus Review 완료

📄 저장 경로: ./consensus-review-plan_v2-20260428-010700.md

📊 요약
- 총 이슈: 14개 (🔴 3, 🟡 6, ⚪ 5)
- 리뷰어별 발견 수: R1 7건 / R2 9건 / R3 6건

🔴 High Confidence TOP 3 (각 제목 ≤15 단어, Quote·Reasoning 금지):
1. ISS-1: 인증 플로우와 스펙 §3.2 불일치
2. ISS-2: 에러 코드 409 정의 누락
3. ISS-3: 용어 "세션"이 두 의미로 혼용

💡 전체 상세는 위 저장 경로의 파일을 열어보세요.
   "ISS-N 자세히"라고 하면 특정 이슈만 펼쳐드릴 수 있습니다.
```

**Bad** (절대 금지 — InvalidJson 크래시 유발):

- 채팅에 🔴 이슈의 Quote·Reasoning 본문을 함께 출력 ❌
- 채팅에 `## 🔴 High Confidence — 전원 합의` 같은 **파일 템플릿 헤더** 출력 ❌
- `write.content`에 넣은 본문을 `assistant_text`에도 복제 ❌

**Bad (리터럴 훼손)**:

- `"Consensus Review 완료했습니다 ✅"` (순서·문구 변경)
- `"📄 파일: ..."` ("저장 경로" 리터럴 훼손)

---

## === 실패 및 분기 ===

- **파일 쓰기 실패** → 재시도 1회. 실패하면 채팅에 `"❌ 파일 저장 실패: {에러}. 저장 없이 진행할까요?"`만 출력. **본문을 채팅에 덤프 금지** — InvalidJson이 납니다.
- **🔴 0개** → `"🔴 High Confidence: 없음"` 한 줄. TOP 3 섹션 생략.
- **총 이슈 0개** → B 템플릿 대신 `"✅ Consensus Review 완료 — 지적된 이슈 없음. 파일: {경로}"`만.
- **사용자가 "상세 보기" 명시** (Good 표현: "ISS-5 자세히", "ISS-5 펼쳐", "전체 상세", "full report", "다 보여줘") → 해당 이슈만 채팅에 출력.
- **상세 요청 아님** (Bad 표현: "뭐가 중요해?", "요약 다시", "TOP 5로 늘려") → B 템플릿 범위 내 조정.
- **애매하면** → `"파일을 열어보시겠어요, 아니면 특정 ISS-N을 펼쳐드릴까요?"`로 되묻기.

---

## REMEMBER

파일(A)과 채팅(B)은 **두 개의 완전히 다른 출력**입니다. 같은 본문을 양쪽에 절대 복제하지 마세요. `write.content`에는 A 템플릿, `assistant_text`에는 B 템플릿 리터럴 — 이 매핑을 어기면 **InvalidJson 크래시로 세션이 실패**합니다.

---

## C. HTML 리포트 모드 (옵션)

기본 출력은 Markdown(A)입니다. **사용자가 명시적으로 HTML 출력을 요청한 경우에만** HTML 모드로 전환하세요.

### 트리거 (Good 표현)

- "HTML로 보여줘" / "HTML 리포트로 저장해줘" / "html report 만들어줘"
- "인터랙티브로", "필터 기능 있게", "접고 펼치는 형태로"
- "단일 HTML 파일로 줘", "브라우저로 볼 수 있게"

**HTML이 아니라 Markdown을 원할 가능성이 높은 표현**: "보고서로", "리포트로", "정리해줘" — 그냥 A로 진행. 모호하면 되묻기: *"Markdown(.md)으로 저장할까요, HTML(.html)로 만들까요?"*

### HTML 모드일 때의 변경점

#### C-1. 파일 확장자와 경로

```
consensus-review-{원본}-{YYYYMMDD-HHMMSS}.html
```

- 같은 디렉토리(원본 문서 옆), 같은 타임스탬프 규칙. 확장자만 `.html`.
- 사용자가 "둘 다"라고 하면 같은 타임스탬프로 `.md` + `.html` 두 개 생성.

#### C-2. `write.content`에 담을 내용

`examples/output_template.html`을 베이스로 다음을 치환하세요:

| 자리표시자 | 치환값 |
|---|---|
| `{원본파일명}` | 원본 문서 파일명(확장자 제외) |
| `{문서 이름}` | 원본 경로 또는 짧은 설명 |
| `{N}` | 실제 성공한 리뷰어 수 |
| `{총 개수}` / `{X}` / `{Y}` / `{Z}` | 총 이슈 / 🔴 / 🟡 / ⚪ 개수 |
| `{a}` / `{b}` / `{c}` | 리뷰어별 발견 수 |
| `{YYYY-MM-DD HH:MM:SS}` | 생성 시각 |
| `{{TOP_ACTIONS_LOOP}}` | 상단 권장 조치 박스의 액션 항목 (아래 C-3a) |
| `{{HIGH_ISSUES_LOOP}}` | 🔴 이슈 카드 반복 (아래 C-3) |
| `{{MID_ISSUES_LOOP}}` | 🟡 이슈 카드 반복 |
| `{{LOW_ISSUES_LOOP}}` | ⚪ 콤팩트 리스트 항목 반복 |

**자기완결형 원칙**: CSS와 JS는 모두 `<style>`/`<script>` 인라인. **외부 CDN/폰트 로드 금지** (오프라인에서도 열려야 함). `output_template.html` 그대로 유지하면 자동으로 충족됩니다.

#### C-3a. Top Actions 박스 (필터 위, 의사결정자용 요약)

상단 `.top-actions` 박스는 **3~5개 핵심 액션**으로 의사결정자가 스크롤 없이 우선순위를 파악하게 합니다. 하단의 상세 권장 조치(`#detailed-recommendations`)와 **요약 + 상세** 페어로 동작합니다.

**작성 규칙**:

- **3~5개**가 적정. 6개 이상이면 의사결정 부담이 늘어나니 통합 또는 하단으로 이동.
- 각 항목 = `<strong>{한 줄 액션}</strong> — {간단한 이유} ({관련 ISS 번호})` 형태.
- 액션은 **동사로 시작** (예: "통합", "명문화", "교체"). "X에 대해 검토" 같은 막연한 표현 금지.
- ISS 번호는 **🔴 우선**으로 묶기. 같은 root cause를 공유하는 ISS는 한 액션으로 묶음 (예: "ISS-1, ISS-10을 묶어 매핑 통합").
- 🔴이 0개이면 박스 자체를 생략하거나 🟡 기준으로 작성하고 박스 좌측 컬러 바를 `--mid`로 변경.

**예시**:

```html
<aside class="top-actions" aria-labelledby="top-actions-heading">
  <h2 id="top-actions-heading">💡 먼저 처리할 일 (Top Actions)</h2>
  <ol>
    <li><strong>doc_type_hint 매핑 통합</strong> — 영문 키워드와 한국어 후보 값을 단일 표로 정리 (🔴 ISS-1, ISS-10).</li>
    <li><strong>N 변수 일반화</strong> — reviewer-1/2/3 하드코딩을 N개 일반화로 교체 (🔴 ISS-2).</li>
    <li><strong>외부 파일 의존성 명문화</strong> — aggregate.md / output_template.* 위치·존재 보장·fallback 추가 (🔴 ISS-3).</li>
  </ol>
  <p class="more">상세 가이드는 페이지 하단 <a href="#detailed-recommendations">권장 조치 섹션</a>을 참고하세요.</p>
</aside>
```

**왜 분리했나**:
- 하단 권장 조치는 톤이 일반적("🔴부터 우선 검토하세요...") — 모든 리포트에 공통.
- 상단 Top Actions는 **이번 리포트 고유의 핵심 액션** — 매번 다르게 작성.
- 의사결정자는 상단만 보면 되고, 실무자는 하단 + ISS 카드까지 본다.

#### C-3. 이슈 카드 (HTML)

🔴/🟡 이슈는 `<details class="issue severity-{high|mid}">` 카드로 렌더:

```html
<details class="issue severity-high" data-tier="high">
  <summary>
    <span class="iss-id">ISS-1</span>
    <span class="iss-emoji">🔴</span>
    <span class="iss-title">인증 플로우와 스펙 §3.2 불일치</span>
  </summary>
  <div class="issue-body">
    <div class="issue-meta">
      <span class="tag type">Inconsistency</span>
      <span class="tag severity-CRITICAL">CRITICAL</span>
      <span class="tag">Agents 3/3</span>
      <span class="tag">Confidence 9/10 (R1: 9, R2: 10, R3: 8)</span>
      <span class="tag">Evidence 5/5</span>
    </div>
    <ul class="quotes">
      <li>📍 "<mark>로그인 후 30분 비활성 시 자동 로그아웃</mark>" (Spec §1.4)<span class="reviewer-tag">R1</span></li>
      <li>📍 "<mark>세션 타임아웃은 1시간으로 설정</mark>" (Spec §3.2)<span class="reviewer-tag">R2</span></li>
      <li>📍 "<mark>auto-logout: 30min vs spec §3.2: 60min</mark>" (Spec §3.2)<span class="reviewer-tag">R3</span></li>
    </ul>
    <p class="reasoning">스펙 §3.2와 본문 1.4절의 세션 타임아웃 값이 30분/60분으로 충돌. 둘 중 어느 쪽이 정인지 명시 필요.</p>
  </div>
</details>
```

> 🧠 **카드 enrichment는 페이지 하단 JS가 자동 수행합니다** (서버측에서 별도 마크업 불필요):
> - 카드 접힘 상태에서도 보이는 `🔍 진단` / `👉 검토` / `📍 출처` 글랜스 영역
> - `근거 인용 N건` 헤더가 quotes 위에 자동 추가
> - `📍 출처`는 quote 끝의 `(괄호)` 패턴(예: `(Glossary)`, `(Req 3, AC1)`)에서 자동 추출
> - `👉 검토`는 `tag.type` 값(Inconsistency / Omission / 불일치 / 누락 등)에서 자동 매핑
>
> 따라서 quote 끝에 **출처 괄호를 일관되게 붙여주세요** — `</mark>" ({출처})<span class="reviewer-tag">` 형식. 출처가 없으면 글랜스의 출처 라인도 자동 생략됩니다.
>
> `open` 속성은 붙이지 마세요 — 모든 이슈는 기본 접힘 상태로 시작합니다 (인쇄 시 JS가 자동 펼침).

**이스케이프 규칙**: 이슈 제목/Quote/Reasoning 안의 `<`, `>`, `&` 문자는 `&lt;`, `&gt;`, `&amp;`로 치환. 따옴표는 `&quot;` 사용 권장. **이슈 텍스트에 사용자 마크다운 표기가 있어도 그대로 텍스트로 출력**(HTML 직접 임베드 금지) — XSS/렌더 깨짐 방지.

⚪ 이슈는 `<details>` 대신 `<ul class="low-list">` 안에 한 줄짜리 `<li>`로:

```html
<li><span class="iss-id">ISS-7</span><strong>용어 "세션"이 두 의미로 혼용</strong> — 인증 세션과 사용자 세션이 같은 단어로 쓰여 혼란.</li>
```

#### C-4. 채팅 응답(B)는 그대로

HTML 모드여도 채팅 출력은 **B 템플릿** 그대로. 단 `📄 저장 경로`의 확장자만 `.html`로 변경:

```
✅ Consensus Review 완료

📄 저장 경로: ./consensus-review-plan_v2-20260510-133000.html
   (브라우저로 열어 보세요)

📊 요약
- ...
```

`open`이나 macOS `Finder`/`xdg-open` 호출은 **하지 마세요** (사용자 환경/허락 모름). 경로만 안내.

#### C-5. 이점 (왜 옵션을 만들었나)

1. **Tier별 접고 펼치기** (`<details>`) — 한눈에 요약, 클릭하면 상세
2. **Quote 인라인 강조** (`<mark>`) — 원문 인용이 즉시 눈에 띔
3. **필터 토글** — 🔴만 / 🟡만 보기 (JS 수십 줄)
4. **Severity 색깔 코딩** — 카드 좌측 컬러 바
5. **다크 모드 자동 대응** — `prefers-color-scheme`
6. **인쇄/PDF 친화** — `@media print`로 모두 펼쳐 인쇄

영감: Simon Willison, "The Unreasonable Effectiveness of HTML" (2026-05-08).

#### C-6. 주의

- ❌ 외부 CDN/폰트 로드 금지 (오프라인에서도 열려야 함)
- ❌ HTML 본문을 `assistant_text`로 출력 금지 (Markdown 모드와 동일하게 InvalidJson 위험)
- ❌ JavaScript에 외부 fetch/XHR 추가 금지 (정적 HTML이어야 함)
- ✅ `output_template.html`의 CSS/JS는 그대로 유지하고, **데이터(이슈 카드)만 치환**하는 것이 안전
