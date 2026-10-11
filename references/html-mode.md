# HTML 모드

사용자가 HTML을 명시적으로 요청했을 때만 읽습니다 ("HTML로", "인터랙티브로", "브라우저로 볼 수 있게", "단일 HTML 파일"). "보고서로", "정리해줘"는 Markdown입니다. 모호하면 *"Markdown(.md)으로 저장할까요, HTML(.html)로 만들까요?"*로 묻습니다.

HTML은 full 내용을 렌더링합니다. 데이터 출처는 세션 디렉토리의 `full-report.md`입니다.

## 파일

- 경로: 문서 옆 `consensus-review-{원본}-{YYYYMMDD-HHMMSS}.html`. "둘 다"면 같은 타임스탬프로 short `.md`도 함께.
- 베이스: `examples/output_template.html`. CSS/JS는 그대로 두고 **데이터만 치환**합니다. 결과는 자기완결형 정적 파일입니다 (외부 CDN·폰트·fetch 없음, 오프라인에서 열림).

| 자리표시자 | 치환값 |
|---|---|
| `{원본파일명}`, `{문서 이름}` | 원본 파일명 / 경로 또는 짧은 설명 |
| `{N}` | 성공한 리뷰어 수 |
| `{총 개수}` `{X}` `{Y}` `{Z}` | 총 / 🔴 / 🟡 / ⚪ 개수 |
| `{a}` `{b}` `{c}` | 리뷰어별 발견 수 |
| `{YYYY-MM-DD HH:MM:SS}` | 생성 시각 |
| `{{TOP_ACTIONS_LOOP}}` | Top Actions 항목 |
| `{{HIGH_ISSUES_LOOP}}` / `{{MID_ISSUES_LOOP}}` | 🔴 / 🟡 이슈 카드 |
| `{{LOW_ISSUES_LOOP}}` | ⚪ 한 줄 항목 |

## Top Actions

이번 리포트 고유의 핵심 액션 3~5개. 항목 형식: `<strong>{동사로 시작하는 한 줄 액션}</strong> — {이유} ({ISS 번호})`. 같은 root cause의 ISS는 한 액션으로 묶고 🔴을 앞에 둡니다. 🔴이 0개면 🟡 기준으로 쓰고 박스 컬러를 `--mid`로 바꿉니다. 액션 문구는 각 ISS의 Fix에서 가져옵니다.

```html
<li><strong>doc_type_hint 매핑 통합</strong> — 영문 키워드와 한국어 값을 단일 표로 (🔴 ISS-1, ISS-10).</li>
```

## 이슈 카드

🔴/🟡는 `<details>` 카드, 기본 접힘(`open` 없음):

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
    </div>
    <ul class="quotes">
      <li>📍 "<mark>로그인 후 30분 비활성 시 자동 로그아웃</mark>" (Spec §1.4)<span class="reviewer-tag">R1</span></li>
      <li>📍 "<mark>세션 타임아웃은 1시간으로 설정</mark>" (Spec §3.2)<span class="reviewer-tag">R2</span></li>
    </ul>
    <p class="reasoning">§1.4와 §3.2의 세션 타임아웃이 30분/60분으로 충돌. 수정: 한 값으로 통일하고 다른 절에서 참조.</p>
  </div>
</details>
```

- quote 끝에 `({출처})`를 일관되게 붙입니다. 페이지 JS가 이를 읽어 `📍 출처` 글랜스를 만들고, `tag.type`으로 `👉 검토` 문구를 매핑합니다.
- `reasoning` 문단 끝에 `수정: {Fix}`를 붙입니다.
- 🟡는 `severity-mid` / `data-tier="mid"`.

⚪는 한 줄 항목:

```html
<li><span class="iss-id">ISS-7</span><strong>용어 "세션"이 두 의미로 혼용</strong> — 인증 세션과 사용자 세션이 같은 단어.</li>
```

이슈 텍스트는 HTML 이스케이프합니다 (`<` `>` `&` `"` → `&lt;` `&gt;` `&amp;` `&quot;`). 리뷰어 텍스트의 마크다운도 텍스트로 둡니다.

## 채팅

`examples/output_template.md`의 Chat 형식 그대로, 경로 확장자만 `.html`이고 다음 줄에 `(브라우저로 열어 보세요)`를 덧붙입니다. 파일을 여는 명령(`open`, `xdg-open`)은 실행하지 않고 경로만 안내합니다.
