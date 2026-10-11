# Sample Run: AWS Architecture Document Review

> [`sample_aws_architecture.md`](sample_aws_architecture.md)(가상의 "OrderFlow Platform" AWS 아키텍처 문서)에 `consensus-review`를 적용했을 때의 **기대 결과 예시**입니다. 문서에 의도적으로 심어 둔 결함 11개를 담고 있어, 스킬을 고친 뒤 재현율을 확인하는 정답지로도 씁니다.
>
> - 리뷰어 N=3 (기본값), 모델은 사용자 설정을 따릅니다.
> - 실제 실행에서는 표현, 이슈 수, ISS 번호가 모델과 실행마다 달라집니다. 강한 모델은 이 11개 외에 20개 안팎을 더 찾습니다.
> - 아래 순서는 사용자가 보는 순서입니다: 채팅 요약 → 문서 옆 short 리포트 → 요청 시 full 상세.

---

## 1. 채팅 응답

```
✅ Consensus Review 완료 — 이슈 11개 (🔴 4 · 🟡 5 · ⚪ 2) · 먼저 고칠 것 4개

📄 ./consensus-review-sample_aws_architecture-20260511-101500.md

🔴 먼저 고칠 것
1. ISS-1 가용성 SLA 목표가 두 섹션에서 다름
2. ISS-2 단일 리전 배포와 멀티 리전 DR 구성이 모순
3. ISS-3 요청 흐름에 Inventory Service 호출 누락

"풀 버전" 또는 "ISS-N 자세히"라고 하면 상세를 펼칩니다.
```

---

## 2. Short 리포트 (기본, 문서 옆 파일)

`consensus-review-sample_aws_architecture-20260511-101500.md`

```markdown
# Consensus Review — sample_aws_architecture.md

리뷰어 3명 · 이슈 11개 (🔴 4 · 🟡 5 · ⚪ 2) · 먼저 고칠 것 4개 · 상세: `.consensus-review-output/20260511-101500-a3f7/full-report.md`

## 🔴 먼저 고칠 것 — 전원 합의, CRITICAL/MAJOR
1. **ISS-1 가용성 SLA 목표가 두 섹션에서 다름** (§1 ↔ §3) — 99.95%와 99.99% 중 공식 SLA 하나로 통일
2. **ISS-2 단일 리전 배포와 멀티 리전 DR 구성이 모순** (§1 ↔ §8) — 배포 범위나 DR 전략 중 한쪽을 수정
3. **ISS-3 요청 흐름에 Inventory Service 호출 누락** (§2.2 ↔ §9) — §2.2에 재고 확인 단계와 실패 경로 추가
4. **ISS-4 "Auto Scaling을 통한 자동 장애 복구"의 의미가 모호** (§3) — AZ 장애 시 트래픽 전환 메커니즘 명시

## 🟡 확인할 것 — 다수 합의, 또는 전원 합의 MINOR
5. **ISS-5 SNS가 흐름에는 있으나 컴포넌트 목록에 없음** (§2.1 ↔ §2.2) — §2.1에 SNS와 역할 추가
6. **ISS-6 Payment→Order 종속과 요청 흐름이 모순** (§2.2 ↔ §9) — Payment→Order 호출 방식(동기/이벤트) 정의
7. **ISS-7 Inventory만 EKS를 쓰는 근거 없음** (§2.1) — 혼용 근거를 적거나 Fargate로 통일
8. **ISS-8 CloudWatch 알림 임계치 값 누락** (§5) — 지표별 임계치와 warning/critical 구분 정의
9. **ISS-9 Fargate Spot에서 Order만 제외하는 기준 모호** (§7) — Spot 허용 기준(중요도·복구 비용) 명시

## ⚪ 참고 — 1명 지적
- ISS-10 "통합 테스트 필수"의 범위·기준 불명확 (§6)
- ISS-11 "MSA" 약어가 정의 없이 첫 등장 (§1)
```

---

## 3. Full 상세 (`full-report.md`, 요청 시)

매 실행 세션 디렉토리에 남는 파일입니다. "풀 버전"이라고 하면 문서 옆으로 복사되고, "ISS-6 자세히"라고 하면 해당 블록만 채팅에 나옵니다. 아래는 앞부분과 🟡 블록 하나만 옮겼습니다.

```markdown
# 📋 Consensus Review 결과 (Full)

**문서**: sample_aws_architecture.md
**리뷰어**: 3명 blind · 총 11개 (🔴 4, 🟡 5, ⚪ 2)
**리뷰어별 발견 수**: R1 8 / R2 7 / R3 9

## 🔴 High Confidence — 전원 합의

### ISS-1: 가용성 SLA 목표가 두 섹션에서 다름
- Verdict: 🔴
- Type: Inconsistency
- Severity: MAJOR (R1: MAJOR, R2: MAJOR, R3: MAJOR)
- Agents: 3/3 flagged
- Confidence: 10/10 (R1: 10, R2: 10, R3: 10)
- Quotes:
  📍 "99.95% 가용성, p99 응답시간 500ms 이하" (§1) — R1, R2, R3
  📍 "본 서비스는 99.99% 가용성을 보장합니다" (§3) — R1, R2, R3
- Reasoning: 두 목표는 연간 허용 다운타임이 약 4.4시간 대 52분으로 4배 넘게 차이 나며, 어느 쪽이 공식 SLA인지 알 수 없다.
- Fix: 99.95%와 99.99% 중 공식 SLA 하나로 통일

…

## 🟡 Needs Review — 다수 합의

### ISS-6: Payment→Order 종속과 요청 흐름이 모순
- Verdict: 🟡
- Type: Inconsistency
- Severity: MAJOR (R1: MAJOR, R2: MAJOR)
- Agents: 2/3 flagged
- Confidence: 8/10 (R1: 8, R2: 8)
- Quotes:
  📍 "Payment Service → Order Service (주문 상태 업데이트)" (§9) — R1, R2
  📍 "Payment Service → SNS → Notification Worker (비동기)" (§2.2) — R1, R2
- Reasoning: §9는 Payment가 Order를 직접 호출한다고 하지만 §2.2의 Payment 출력 경로는 SNS뿐이라 호출 방식이 정의되지 않았다.
- Fix: Payment→Order 호출 방식(동기/이벤트) 정의

…
```

ISS-6은 MAJOR지만 2명만 지적해서 "먼저 고칠 것"이 아니라 "확인할 것"에 들어갑니다. 먼저 고칠 것은 **전원 합의이면서** CRITICAL/MAJOR인 이슈만입니다.

---

## 이 예시에서 볼 것

- 🔴 4개 중 3개(ISS-1·2·3)와 🟡 ISS-6은 **섹션 사이 모순·누락**입니다. 단일 리뷰어가 앞뒤 섹션을 동시에 추적하다 확률적으로 놓치는 유형이라, blind 리뷰어 3명의 합집합에서 잡힙니다.
- ⚪ 2개는 1명만 짚은 경미한 이슈입니다. 합의가 약하다는 것 자체가 "긴급도 낮음" 신호로 쓰입니다.
- Tier별 정밀도 실험치(🔴 약 80~90%, 🟡 30~40%, ⚪ 15~20%)와 재현율 근거: [`../references/benchmark_summary.md`](../references/benchmark_summary.md)
