# Sample Run: AWS Architecture Document Review

> 이 문서는 [`sample_aws_architecture.md`](sample_aws_architecture.md) (가상의 "OrderFlow Platform" AWS 아키텍처 문서)에 `consensus-review` 스킬을 적용한 **데모 실행 결과**입니다.
>
> **실행 조건**:
> - 에이전트 도구: Kiro CLI (또는 Claude Code)
> - 기반 모델: Claude Sonnet 4.6 (사용자 설정 따름)
> - 리뷰어 수: N=3 (기본값)
> - 총 소요 시간: 약 90초 (서브에이전트 3명 병렬 + 집계 1회)
>
> 실제 출력은 모델/버전에 따라 표현이 다를 수 있습니다. 아래는 예상되는 Tier 분포와 결함 목록입니다.

---

# 📋 Consensus Review 결과

**문서**: sample_aws_architecture.md (OrderFlow Platform AWS 아키텍처)
**리뷰어 수**: 3명 독립
**총 고유 이슈**: 11개 (🔴 4, 🟡 5, ⚪ 2)

| 리뷰어 | 발견한 결함 수 |
|---|---:|
| Reviewer 1 | 8건 |
| Reviewer 2 | 7건 |
| Reviewer 3 | 9건 |

---

## 🔴 High Confidence — 전원 합의 (4개)

> 3명 전원이 지적한 이슈입니다. 우선 처리 대상입니다.

### ISS-1: 가용성 SLA 목표가 두 섹션에서 다름

- **Type**: Inconsistency
- **Severity**: MAJOR
- **Agents**: 3/3
- **Confidence**: 10/10
- **Evidence Strength**: 5/5
- **Quotes**:
  - 📍 "SLA 목표: 99.95% 가용성, p99 응답시간 500ms 이하" — §1 (Reviewer 1, 2, 3)
  - 📍 "본 서비스는 99.99% 가용성을 보장합니다" — §3 (Reviewer 1, 2, 3)
- **Reasoning**: §1은 99.95%, §3은 99.99%로 서로 다른 가용성 목표를 명시합니다. 99.95%와 99.99%는 연간 다운타임 허용치가 4배 이상 차이나므로(약 4.4h vs 52min) 모호한 상태로 두면 안 됩니다. 어느 쪽이 공식 SLA인지 명확히 해야 합니다.

### ISS-2: 단일 리전 배포와 멀티 리전 DR 구성이 모순됨

- **Type**: Inconsistency
- **Severity**: CRITICAL
- **Agents**: 3/3
- **Confidence**: 10/10
- **Evidence Strength**: 5/5
- **Quotes**:
  - 📍 "배포 환경: AWS ap-northeast-2 리전 단일 배포" — §1 (Reviewer 1, 2, 3)
  - 📍 "본 시스템은 재해 복구를 위한 멀티 리전 구성을 지원한다. RPO는 5분, RTO는 30분을 목표로 한다." — §8 (Reviewer 1, 2, 3)
- **Reasoning**: §1은 단일 리전 배포라고 명시한 반면, §8은 멀티 리전 DR을 선언합니다. 단일 리전 배포에서는 리전 전체 장애에 대한 DR이 불가능하므로 RTO 30분/RPO 5분 목표도 달성 불가입니다. 배포 범위나 DR 전략 중 한쪽이 수정되어야 합니다.

### ISS-3: §2.2 요청 흐름에 Inventory Service 호출이 누락됨

- **Type**: Omission
- **Severity**: MAJOR
- **Agents**: 3/3
- **Confidence**: 9/10
- **Evidence Strength**: 5/5
- **Quotes**:
  - 📍 §2.2: "1. 클라이언트 → API Gateway / 2. API Gateway → Order Service / ..." (전체 흐름에 Inventory 없음) — Reviewer 1, 2, 3
  - 📍 "Order Service → Inventory Service (재고 확인)" — §9 (Reviewer 1, 2, 3)
- **Reasoning**: §9 종속성에는 Order가 재고 확인을 위해 Inventory를 호출한다고 선언되어 있지만, §2.2 요청 흐름에는 이 단계가 빠져 있습니다. 실제 주문 생성 시 재고 확인 실패/성공 경로가 설계되지 않은 상태로 보입니다. 흐름 다이어그램에 3-a, 3-b 같은 단계로 추가되어야 합니다.

### ISS-4: "Auto Scaling을 통한 자동 장애 복구"의 의미가 모호

- **Type**: Ambiguity
- **Severity**: MAJOR
- **Agents**: 3/3
- **Confidence**: 8/10
- **Evidence Strength**: 4/5
- **Quotes**:
  - 📍 "Auto Scaling을 통한 자동 장애 복구" — §3 (Reviewer 1, 2, 3)
- **Reasoning**: Auto Scaling은 부하 기반 스케일링이지 장애 복구 메커니즘이 아닙니다. AZ 장애 시 트래픽을 어떤 방식으로 전환하는지(ALB 헬스체크 + Target 재등록, Route 53 헬스체크 + DNS failover 등)가 명시되지 않았습니다. "MTTR 5분 이내"를 달성하기 위한 구체 메커니즘이 정의되어야 합니다.

---

## 🟡 Needs Review — 다수 합의 (5개)

> 3명 중 2명이 지적했습니다. 검토를 권장합니다.

### ISS-5: §2.2에 SNS 등장하지만 §2.1 컴포넌트 목록에는 없음

- **Type**: Omission / Inconsistency
- **Severity**: MINOR
- **Agents**: 2/3
- **Confidence**: 8/10
- **Quotes**:
  - 📍 "Payment Service → SNS → Notification Worker (비동기)" — §2.2 (Reviewer 2, 3)
  - 📍 §2.1 컴포넌트 목록에 SNS 항목 없음 (Reviewer 2, 3)
- **Reasoning**: SNS가 흐름에는 쓰이는데 컴포넌트 테이블에 빠졌습니다. SQS만 "메시지 버스"로 표기되어 있어 독자에게 혼란을 줍니다. 컴포넌트 목록에 SNS를 추가하고 역할을 명시해야 합니다.

### ISS-6: Inventory Service만 EKS, 나머지는 Fargate — 배포 플랫폼 혼용 근거 없음

- **Type**: Structural
- **Severity**: MINOR
- **Agents**: 2/3
- **Confidence**: 7/10
- **Quotes**:
  - 📍 "Inventory Service | 재고 관리 | EKS" — §2.1 (Reviewer 1, 3)
  - 📍 "Order Service | ... | ECS on Fargate", "Payment Service | ... | ECS on Fargate" — §2.1 (Reviewer 1, 3)
- **Reasoning**: 같은 MSA 플랫폼에서 3개 서비스 중 1개만 EKS를 쓰는 이유가 설명되지 않았습니다. 운영 복잡도 증가(두 개의 컨테이너 플랫폼 관리 필요) 대비 얻는 이익이 불분명합니다. 근거가 있다면 명시하고, 없다면 Fargate로 통일하는 것을 권장합니다.

### ISS-7: §9 Payment→Order 종속과 §2.2 요청 흐름이 모순

- **Type**: Inconsistency
- **Severity**: MAJOR
- **Agents**: 2/3
- **Confidence**: 8/10
- **Quotes**:
  - 📍 "Payment Service → Order Service (주문 상태 업데이트)" — §9 (Reviewer 1, 2)
  - 📍 "Payment Service → SNS → Notification Worker (비동기)" — §2.2 (Reviewer 1, 2)
- **Reasoning**: §9는 Payment가 Order Service를 직접 호출한다고 선언하지만, §2.2 흐름에는 Payment의 outbound가 SNS로만 되어 있습니다. Payment → Order의 호출 경로(동기 REST? SQS? 이벤트?)가 정의되지 않았습니다.

### ISS-8: CloudWatch 임계치의 구체 값 누락

- **Type**: Omission / Ambiguity
- **Severity**: MINOR
- **Agents**: 2/3
- **Confidence**: 7/10
- **Quotes**:
  - 📍 "임계치 초과 시 SNS를 통해 담당자에게 알림이 발송됩니다" — §5 (Reviewer 1, 2)
- **Reasoning**: 응답시간/오류율/리소스 사용률 각각의 임계치 구체값이 없습니다. 누가 언제 알림을 받는지, warning과 critical 구분은 있는지도 정의되지 않았습니다. 알림 정책을 정의하거나 별도 런북을 참조해야 합니다.

### ISS-9: Fargate Spot 제외 기준 모호 — "Order Service 제외"의 이유

- **Type**: Ambiguity
- **Severity**: MINOR
- **Agents**: 2/3
- **Confidence**: 6/10
- **Quotes**:
  - 📍 "Fargate Spot 활용 (Order Service 제외)" — §7 (Reviewer 2, 3)
- **Reasoning**: Order만 Spot에서 제외하는 근거가 없습니다. Payment도 결제라 중요도 높은데 왜 Payment는 Spot 허용인지 불명확합니다. "중요도 기준" 혹은 "interruption 복구 비용 기준" 같은 정책이 명시되어야 합니다.

---

## ⚪ Low — 소수 지적 (2개)

> 3명 중 1명이 지적했습니다. 시간 여유가 있을 때 확인하세요.

- **ISS-10**: "통합 테스트 필수"의 범위/기준 불명확 (Reviewer 3) — §6에서 통합 테스트 필수를 언급하지만, 어떤 테스트(E2E? 서비스 간 계약 테스트?)인지, 성공 기준은 무엇인지 없음.
- **ISS-11**: "MSA" 약어가 정의 없이 첫 등장 (Reviewer 2) — §1에서 "MSA 기반 플랫폼"이라고 쓰지만 본문에 Microservices Architecture 정의가 없음. 비기술 독자 고려 시 첫 등장 시 풀어쓰기 권장.

(상세 내용은 요청 시 펼쳐 드립니다.)

---

## 💡 권장 조치

1. **🔴 4개부터 즉시 수정**하세요. 특히 ISS-1(SLA 모순)과 ISS-2(DR 모순)는 서비스 설계의 근본 방향을 재정의해야 하는 문제입니다.
2. **🟡 5개는 아키텍처 리뷰 미팅에서 결정**하세요. ISS-5~9 중 ISS-7(Payment→Order 경로)이 가장 긴급합니다 — 구현에 직접 영향.
3. **⚪ 2개는 최종 리뷰 단계에서 확인**하세요. 독자 이해도에 영향을 주는 마이너 이슈.

---

## 🔬 분석 — 왜 이 결함들이 단일 리뷰에서 놓쳐졌을까

이 문서에는 **섹션 간 상호 참조 모순(ISS-1, 2, 3, 7)**이 많습니다. 단일 LLM 리뷰어는 긴 문서의 앞뒤 섹션을 동시에 추적하기 어렵기 때문에 이런 종류의 결함을 확률적으로 놓치는 경향이 있습니다.

실제 실험 데이터로도 확인된 패턴:

- ISS-1, ISS-2, ISS-3, ISS-7은 **섹션 간 Inconsistency/Omission** 타입으로, 단일 리뷰 재현율이 60~70%대인 카테고리입니다.
- 3명의 독립 리뷰어 중 **각자 놓친 결함이 다르므로**, 합집합으로 모으면 거의 모두 🔴로 수렴합니다.
- 반면 ISS-10, ISS-11 같은 마이너 이슈는 합의가 약해 ⚪로 분류되며, 이는 "긴급도 낮음"의 신호로 자연스럽게 활용됩니다.

---

## ℹ️ 이 스킬에 대해

이 리뷰는 **같은 모델로 N명의 독립 리뷰어를 병렬 실행 → 결과 합의 Tier로 분류**하는 `consensus-review` 스킬에 의해 생성되었습니다.

단일 리뷰가 확률적으로 놓치는 결함들을 독립 N명이 교차 탐지해 **재현율을 6.5~30.6%p 끌어올리는** 것을 목표로 설계되었습니다.

- 🔴 정밀도 (실험치, FAVA 기준): 약 80~90%
- 🟡 정밀도: 약 30~40%
- ⚪ 정밀도: 약 15~20%

상세 근거: [`../references/benchmark_summary.md`](../references/benchmark_summary.md)
