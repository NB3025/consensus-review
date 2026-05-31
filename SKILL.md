---
name: consensus-review
description: "Review Korean/English documents for defects by running N=3 independent LLM reviewers as parallel subagents, then aggregate findings with consensus-tier labels (🔴 high / 🟡 medium / ⚪ low). Use when the user asks to 리뷰해줘, 문서 검토, 놓친 게 있는지 확인, 기능정의서 리뷰, 요구사항 검토, 사업계획서 검토, 구현계획서 검토, review a document, find defects, audit a spec, check for issues in a PRD / RFC / NDA / requirements / architecture / implementation plan. Trigger for filenames like requirements.md, spec.md, prd.md, design.md, architecture.md. NOT for: simple typo/grammar fixes, translation proofreading, documents under 500 words, 가벼운 편집 요청. The skill increases recall (catches more defects than a single reviewer) and provides tier-based priority for human review."
---

# Consensus Review

N명의 독립 서브에이전트 리뷰어를 병렬 실행해 문서 결함을 탐지하고 🔴/🟡/⚪ Tier로 분류합니다.

## 실행 단계

### Step 1. 문서 준비

1. **PROJECT_DIR 결정** (모든 산출물의 기준 디렉토리):
   - 입력이 **파일 경로**면 → `PROJECT_DIR = dirname(document_path)` (해당 파일이 있는 디렉토리)
   - 입력이 **인라인 텍스트**면 → `PROJECT_DIR = cwd` (현재 작업 디렉토리)
2. **문서 로드**:
   - 파일 경로면 그대로 사용.
   - 인라인 텍스트면 500 단어 / 2KB 미만일 때만 그대로, 초과 시 `{PROJECT_DIR}/.consensus-review-output/input-{YYYYMMDD-HHMMSS}.md`로 저장 후 경로 사용.
3. `{language}`: 문서 전반이 한글 문자 ≥50%면 "ko", 아니면 "en".
4. `{doc_type_hint}`: 파일명에 `prd|spec|requirements|nda|rfc|architecture` 매치 또는 본문 첫 200자에서 직접 매치되는 키워드 → 해당 유형. 매치 없으면 "general".

**예시**: `requirements.md` → "requirements"; 본문에 "1조(목적)", "비밀유지" → "NDA".

> 📝 **왜 프로젝트 디렉토리인가**: `/tmp`는 샌드박스/컨테이너 환경에서 서브에이전트가 접근 불가할 수 있고, 세션 종료 시 날아갑니다. 프로젝트 디렉토리에 저장하면 (1) 권한 이슈 회피, (2) 중간 산출물 재확인/디버깅 가능, (3) 리뷰 대상 문서와 같은 공간에 격리됩니다. `.`으로 시작하는 숨김 폴더라 일반 파일 탐색을 방해하지 않습니다. `.gitignore`에 추가할지는 **사용자 판단**에 맡깁니다 — 스킬은 건드리지 않습니다.

### Step 2. N명 독립 리뷰어 실행 (서브에이전트 병렬 호출)

> 🚨 **=== CRITICAL: INDEPENDENCE MODE — REVIEWERS MUST NOT SEE EACH OTHER ===**
>
> You are STRICTLY PROHIBITED from:
> - 한 리뷰어의 출력을 다른 리뷰어에게 전달
> - 리뷰 프롬프트에 다른 리뷰어를 언급
> - 리뷰어 호출을 직렬화하여 뒤 리뷰어가 앞 리뷰어 상태를 관찰
> - 서브에이전트가 다른 리뷰어의 output 파일 / 이전 세션 리뷰 파일을 읽게 허용
>
> 독립성이 이 스킬의 존재 이유입니다. 위반 시 이 스킬의 핵심 효과(확률적 커버리지로 +6.5~30.6%p 재현율 향상)가 사라집니다.

#### 2-1. 세션 디렉토리 생성 (메인이 먼저)

리뷰어 출력이 서로 격리되도록 **세션마다 고유 디렉토리**를 만듭니다.

1. `SESSION_ID` 생성: `{YYYYMMDD-HHMMSS}-{4자 난수}` 형태. 예: `20260428-022810-a3f7`
2. 메인이 `mkdir -p {PROJECT_DIR}/.consensus-review-output/{SESSION_ID}/` 실행 (Step 1에서 결정한 `PROJECT_DIR`)
3. 각 서브에이전트의 output 경로: `{PROJECT_DIR}/.consensus-review-output/{SESSION_ID}/reviewer-{N}.md` (N=1,2,3)

**세션 산출물은 자동 정리하지 않습니다.** 이전 세션 디렉토리는 그대로 남아 디버깅/재현에 사용됩니다. 사용자가 필요하면 수동으로 삭제.

#### 2-2. 왜 파일 기반인가 (raw 원문 보존)

**서브에이전트가 raw 리뷰를 메시지로 return하면** Main 세션이 그 내용을 자동으로 **요약/압축**할 수 있습니다. 결과: aggregator가 받는 건 "요약된 것"이지 리뷰어 원문이 아니게 되어 Preservation Rules가 깨집니다.

해법:
- 서브에이전트는 리뷰 결과를 **파일로 저장** (`write_file` 또는 `Write`)
- Main은 **파일을 직접 `read_file`** — 문자 그대로 읽음, 요약 개입 없음
- 서브에이전트 return 메시지는 **한 단어**: `"done"` (raw 복사 금지)

#### 2-3. 각 서브에이전트 호출 시 전달할 변수

- `{document_path}` ← 원본 문서의 파일 경로 (기본). 500 단어 / 2KB 미만 인라인 텍스트만 예외.
- `{output_path}` ← 이 리뷰어가 저장할 파일. 예: `{PROJECT_DIR}/.consensus-review-output/20260428-022810-a3f7/reviewer-1.md`
- `{language}` ← "ko" 또는 "en"
- `{doc_type_hint}` ← "사업계획서", "기능정의서", "구현계획서", "architecture", "general" 중 하나

서브에이전트 3명을 **동시에** 호출 (병렬). 각자 다른 `{output_path}`를 받음.

#### 2-4. 서브에이전트가 반드시 따라야 할 것 (review.md에도 명시)

1. `{document_path}`를 읽는다 (파일 경로면 `read_file`, 작은 인라인 텍스트면 직접).
2. 리뷰 수행 (ISS-N 포맷).
3. **결과 전체를 `{output_path}`에 `write_file`로 저장.**
4. Main에 return: **`"done"` 한 단어만.** Raw 리뷰 내용 절대 return 메시지에 포함 금지.

#### 2-5. 서브에이전트가 절대 하지 말 것 (독립성 유지)

- ❌ **`.consensus-review-output/` 하위의 다른 리뷰어 파일 읽기** (같은 세션의 `reviewer-2.md`를 reviewer-1이 읽는 것 등)
- ❌ **이전 세션(`.consensus-review-output/다른-SESSION_ID/`) 파일 참조**
- ❌ **Main 대화 히스토리에서 "이전 리뷰" 언급 참조**
- ❌ **`consensus-review-*.md` 패턴의 기존 결과 파일 참조** (과거 실행 결과)

독립 리뷰어는 **원본 문서와 자기 판단**만으로 작업합니다.

#### 2-6. 문서 전달 방식 — 파일 경로 우선 (기본값)

**기본 규칙: 항상 파일 경로만 전달하세요.** 서브에이전트가 `read_file` (또는 `Read`) 도구로 직접 파일을 읽습니다.

이유:
- 메인 에이전트가 3개 서브에이전트를 **병렬로 호출**할 때, tool call JSON 3개에 **문서 전문이 3번 중복 생성**됩니다. 큰 문서면 출력 토큰 한도를 넘겨 `InvalidJson`/truncation 에러가 납니다 (2026-04-28 실제 사고).
- 파일 경로는 수십 바이트, 문서 전문은 KB~MB. **경로 전달이 토큰을 1,000배 이상 절약**합니다.

**인라인 전달이 허용되는 예외**:
- 사용자가 **인라인 텍스트**(파일이 아닌 채팅 붙여넣기)로 문서를 제공했고,
- **AND** 문서가 500 단어 / 2KB **미만**일 때.

위 조건을 모두 만족하지 않으면 **반드시 파일로 먼저 저장한 뒤 경로를 전달**하세요. `{PROJECT_DIR}/.consensus-review-output/input-{YYYYMMDD-HHMMSS}.md` 경로 사용 (Step 1).

> ⚠️ **중요: 인라인 텍스트 저장 시 `document_path`도 함께 업데이트**
>
> 인라인 텍스트를 파일로 저장했다면, 서브에이전트에 전달하는 `{document_path}`는 **저장된 파일 경로**(`{PROJECT_DIR}/.consensus-review-output/input-*.md`)여야 합니다. 원본 텍스트를 그대로 `document_path`에 넣으면 병렬 호출 시 토큰이 N배로 부풀어 `InvalidJson`이 납니다.

#### 2-7. 기타 주의

- 모델은 사용자의 현재 설정을 따릅니다 (스킬에서 지정 안 함). 최소 요구치: context window ≥ 200K. 그 미만 모델이 감지되면 사용자에게 알리고 중단.
- temperature는 서브에이전트 기본값 사용. 벤치마크(6 LLM × 3 benchmark) 기준 temperature=0.7~1.0 구간에서 재현율이 단조 증가. **0.3 미만으로 낮추지 마세요** — 독립성이 깨집니다.

#### 2-8. 차단 상황 분기 (Blocked Approach)

실패/한계 상황에서 임의로 돌파하지 말고 아래 경로를 따르세요:

- **문서 > 60K 토큰**: 청크 분할은 아직 미구현. 사용자에게 알리고 중단: *"문서가 60K 토큰을 초과합니다(X 토큰). 현재 버전은 청크 분할을 지원하지 않습니다. 섹션을 나눠서 주시겠습니까?"* **임의로 자르거나 요약하지 마세요**.
- **`.consensus-review-output/` 저장 실패** (디스크 풀/권한/읽기전용 디렉토리): 사용자에게 원인과 함께 보고하고 중단. 예: *"PROJECT_DIR({dir})에 쓰기 권한이 없습니다. 쓰기 가능한 다른 경로에서 실행하거나 권한을 조정해주세요."* **`/tmp` 같은 다른 경로로 자동 fallback하지 마세요** — 접근 이슈는 명시적으로 드러내야 합니다. **인라인 전달로 우회하지도 마세요** — 토큰 한도를 넘겨 InvalidJson이 납니다.
- **서브에이전트 1명 `write_file` 실패 또는 타임아웃**: 남은 2명으로 진행. 최종 리포트 상단에 `"Reviewer X 실패 — N=2로 집계됨"`을 명시. 실패한 리뷰어를 같은 프롬프트로 재시도하지 마세요.
- **서브에이전트가 "done" 대신 raw 내용을 return한 경우**: 해당 내용 무시하고 파일을 `read_file`로 직접 읽으세요. 서브에이전트 출력이 아니라 **파일이 정본**.

### Step 3. 집계 (본인 에이전트가 직접 수행)

> 🚨 **REMEMBER**: By Step 3 the reviewers have finished independently. 메인 에이전트(당신)만이 세 개의 출력을 모두 볼 수 있습니다. 통합한 출력을 어떤 리뷰어에게도 "refinement"용으로 되돌려 보내지 마세요.

#### 3-1. 3개 리뷰어 파일 read

서브에이전트 3명이 `done`을 return한 후:

```
read_file {PROJECT_DIR}/.consensus-review-output/{SESSION_ID}/reviewer-1.md → raw_1
read_file {PROJECT_DIR}/.consensus-review-output/{SESSION_ID}/reviewer-2.md → raw_2
read_file {PROJECT_DIR}/.consensus-review-output/{SESSION_ID}/reviewer-3.md → raw_3
```

각 파일이 누락된 경우: Step 2-8의 "서브에이전트 1명 실패" 분기를 따름.

#### 3-2. `{reviews}` 변수 구성

3개 파일의 raw를 다음 형식으로 이어붙임:

```
=== Reviewer 1 ===
{raw_1}

=== Reviewer 2 ===
{raw_2}

=== Reviewer 3 ===
{raw_3}
```

#### 3-3. `prompts/aggregate.md` 실행 (Main LLM 1회 호출)

`prompts/aggregate.md` 프롬프트에 다음 변수 치환:
- `{n_agents}` ← 3 (또는 실제 성공한 리뷰어 수)
- `{document}` ← 원본 문서 경로 또는 전문
- `{reviews}` ← 위 3-2의 이어붙인 텍스트

집계 결과는 🔴/🟡/⚪ Tier가 붙은 ISS-1, ISS-2 … 형태의 통합 목록입니다.

> 🚨 **중요 — 집계 결과를 `assistant_text`로 출력하지 마세요.**
>
> 집계 결과(전체 이슈 목록)는 **내부 산출물**입니다. 채팅 응답 텍스트로 찍지 말고, **곧바로 Step 4a의 `write` 툴 호출의 `content` 인자로 전달**하세요.
>
> 이를 어기면 같은 리포트가 응답 텍스트와 `write.content`에 이중 출력되어 `max_output_tokens`를 넘기고 `InvalidJson`으로 잘립니다 (2026-04-28 실제 사고).

### Step 4. 사용자에게 보고 + 파일 저장

`examples/output_template.md`의 형식으로 최종 Markdown 리포트를 생성합니다. **파일 저장이 기본이고, 채팅 출력은 요약만 합니다.**

> 💡 **HTML 리포트 모드 (옵션)**: 사용자가 명시적으로 HTML 출력을 요청하면("HTML로", "인터랙티브로", "단일 HTML 파일") `examples/output_template.html`을 베이스로 .html 파일을 생성하세요. 자세한 분기 규칙은 `examples/output_template.md`의 **C 섹션**을 참고. 명시 요청이 없으면 기본 .md로 진행. 영감: Simon Willison, "The Unreasonable Effectiveness of HTML" (2026-05-08).

> 🔒 **불변식 (Invariant) — 반드시 지켜야 하는 규칙**
>
> **전체 리포트 본문은 한 응답에 오직 한 곳에만 등장합니다** — `write` 툴의 `content` 인자입니다.
>
> - `write.content` ← 전체 리포트 Markdown 전문 (✅ 여기 한 번)
> - `assistant_text` (채팅) ← **Step 4b의 짧은 요약 템플릿만** (✅ 요약만)
>
> 이 불변식을 지키면 출력 토큰이 절반으로 줄어 대형 리포트에서도 JSON이 잘리지 않습니다.
>
> **자주 하는 실수 — 이렇게 하지 마세요**:
>
> - ❌ assistant_text에 "집계 결과를 먼저 보여주고" 이어서 write 호출 — 본문이 두 번 등장
> - ❌ Step 4b의 요약에 이슈 전체 상세(Quote, Reasoning)를 포함 — TOP 3 **제목만**
> - ❌ "파일에 저장 예정입니다" 같은 선언 후 본문을 채팅에 먼저 찍기 — write가 먼저 호출돼야 함
>
> **순서**:
> 1. 먼저 `write` 툴 호출 — `content`에 전체 리포트 Markdown
> 2. 같은 응답의 `assistant_text`에는 Step 4b의 **짧은 요약 템플릿만**
> 3. Step 3 집계 결과를 중간에 채팅에 덤프하는 행동 **금지**

#### 4a. 파일로 전체 리포트 저장 (기본 동작)

이 단계에서 `write` 툴을 호출합니다. (불변식 재확인: `write.content`에만 전체 본문, `assistant_text`에는 Step 4b 요약만.)

리뷰 대상 문서와 **같은 디렉토리**에 다음 규칙으로 저장:

```
consensus-review-{원본파일명}-{YYYYMMDD-HHMMSS}.md
```

- `{원본파일명}`: 확장자 제외 (예: `requirements.md` → `requirements`)
- `{YYYYMMDD-HHMMSS}`: 실행 시점 기준 초 단위 타임스탬프 (같은 초에 겹칠 확률 ≈ 0)
- 예시: `consensus-review-requirements-20260426-152410.md`

**HTML 모드일 경우** 동일 규칙으로 확장자만 `.html`: `consensus-review-requirements-20260426-152410.html`. 사용자가 "둘 다"라고 하면 같은 타임스탬프로 .md + .html 두 개 생성. 자세한 HTML 모드 규칙은 `examples/output_template.md` C 섹션.

**같은 문서를 여러 번 리뷰해도 타임스탬프가 달라 덮어쓰지 않습니다.** 리뷰 이력을 자동 보존합니다.

**저장 후 검증**: `write` 툴 반환값을 확인한 뒤 Step 4b 요약을 출력하세요. 실패하면 차단 상황 분기의 `.consensus-review-output/ 저장 실패` 항목을 따르세요 — **본문을 채팅에 대신 덤프하지 마세요**.

> 📝 **최종 리포트는 원본 문서 옆, 중간 산출물은 `.consensus-review-output/` 안**
>
> - 최종 리포트(`consensus-review-{원본}-{timestamp}.md`): **원본 문서와 같은 디렉토리** — 사용자가 바로 발견.
> - 중간 산출물(reviewer-1.md, reviewer-2.md, reviewer-3.md, input-*.md): `.consensus-review-output/{SESSION_ID}/` — 감춰져 있고 디버깅/재현용.

#### 4b. 채팅은 **요약만** 출력 (상세 덤프 금지)

파일 저장 후 채팅에는 **짧은 요약**만 출력하세요. 긴 Quote나 Reasoning 전체를 재출력하면 느리고 토큰을 낭비합니다.

**채팅에 출력할 것**:

```
✅ Consensus Review 완료

📄 저장 경로: ./consensus-review-{원본}-{YYYYMMDD-HHMMSS}.md

📊 요약
- 총 이슈: N개 (🔴 X, 🟡 Y, ⚪ Z)
- 리뷰어별 발견 수: R1 a건 / R2 b건 / R3 c건

🔴 High Confidence TOP 3 (제목만):
1. ISS-1: {title}
2. ISS-2: {title}
3. ISS-3: {title}

💡 전체 상세는 위 저장 경로의 파일을 열어보세요.
   "ISS-N 자세히" 라고 하면 특정 이슈만 펼쳐드릴 수 있습니다.
```

**금지**:
- 🔴/🟡/⚪ 전 이슈의 Quote와 Reasoning을 채팅에 다 출력하는 것 ❌
- 파일 내용을 그대로 복붙하는 것 ❌

**허용**:
- 사용자가 "ISS-5 자세히 보여줘"라고 **명시적으로 요청**했을 때 해당 이슈만 파일에서 읽어 보여주기.
- 사용자가 "전체 다 보여줘"라고 하면 그때 파일 내용 출력.

기본 동작은 **"파일 저장 + 요약 + 경로 안내"**입니다. 사용자가 터미널에서 파일을 열어 읽는 것이 훨씬 빠릅니다.

## 설정 변경 (사용자가 요청하면)

- **N 변경**: "리뷰어 5명으로 해줘" → N=5. "2명만" → N=2 (비권장). 기본은 3.
- **언어 강제**: "한국어로 출력해줘" → 최종 리포트를 한국어로. 서브에이전트 프롬프트는 원본 유지.
- **특정 측면만**: "보안 이슈만 봐줘" → 리뷰 프롬프트에 지시 추가.
