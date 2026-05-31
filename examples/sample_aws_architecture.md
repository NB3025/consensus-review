# Sample Input: AWS Architecture Document for "OrderFlow Platform"

> 이 문서는 `consensus-review` 스킬 데모를 위한 **가상의 AWS 아키텍처 문서**입니다. 실제 기업 문서가 아니며, 의도적으로 여러 결함(모순, 누락, 모호함, 용어 불일치, 구조 문제)을 포함하고 있습니다. 샘플 실행 결과는 [`sample_run.md`](sample_run.md)를 참고하세요.

---

## 1. 개요

OrderFlow Platform은 전자상거래 주문 처리를 위한 MSA 기반 플랫폼입니다. 본 문서는 AWS 상에서의 배포 아키텍처와 운영 방침을 정의합니다.

- **서비스 대상**: B2B 이커머스 사업자 (일 평균 주문 100만 건)
- **SLA 목표**: 99.95% 가용성, p99 응답시간 500ms 이하
- **배포 환경**: AWS ap-northeast-2 리전 단일 배포
- **예상 MAU**: 약 50만

## 2. 아키텍처 개요

### 2.1 컴포넌트 목록

| 컴포넌트 | 역할 | AWS 서비스 |
|---|---|---|
| API Gateway | 외부 요청 진입점 | Amazon API Gateway (REST) |
| Order Service | 주문 생성/조회 | ECS on Fargate |
| Payment Service | 결제 처리 | ECS on Fargate |
| Inventory Service | 재고 관리 | EKS |
| Notification Worker | 이메일/SMS 발송 | Lambda |
| 메시지 버스 | 서비스 간 비동기 통신 | Amazon SQS |
| 데이터베이스 | 주문/결제 영구 저장 | Amazon Aurora (MySQL 호환) |
| 캐시 | 조회 성능 개선 | Amazon ElastiCache (Redis) |

### 2.2 요청 흐름

1. 클라이언트 → API Gateway
2. API Gateway → Order Service (동기 호출)
3. Order Service → Aurora (주문 저장)
4. Order Service → SQS → Payment Service (비동기)
5. Payment Service → 외부 PG사 API
6. Payment Service → SNS → Notification Worker (비동기)

## 3. 가용성 요구사항

본 서비스는 99.99% 가용성을 보장합니다. 이를 위해 다음과 같이 구성합니다:

- 모든 서비스는 최소 2개의 가용영역(AZ)에 배포
- Aurora는 Multi-AZ 구성
- Auto Scaling을 통한 자동 장애 복구

장애 발생 시 평균 복구 시간(MTTR)은 5분 이내로 한다.

## 4. 보안

### 4.1 네트워크

- 모든 Fargate 태스크는 Private Subnet에 배치
- API Gateway는 Public, 백엔드 서비스는 VPC Endpoint를 통해 접근
- Security Group은 최소 권한 원칙으로 구성

### 4.2 인증/인가

- 외부 API 인증은 OAuth 2.0 (Cognito)
- 내부 서비스 간 통신은 mTLS
- 관리자 접근은 IAM Role로 제한

### 4.3 데이터 암호화

- 전송 구간: TLS 1.2 이상
- 저장 구간: AWS KMS를 통한 Aurora, ElastiCache 암호화
- 민감 데이터(결제 정보)는 필드 수준 암호화 적용

## 5. 모니터링

CloudWatch를 통해 다음 메트릭을 수집합니다:

- API 응답 시간 (p50, p99)
- 오류율
- CPU/Memory 사용률

임계치 초과 시 SNS를 통해 담당자에게 알림이 발송됩니다.

## 6. 배포 및 CI/CD

- GitHub → CodePipeline → ECR
- Fargate Service 업데이트는 Rolling Deployment
- 배포 전 통합 테스트 필수 수행

## 7. 비용 최적화

- Fargate Spot 활용 (Order Service 제외)
- Aurora Serverless v2로 자동 스케일
- 로그는 30일 후 S3 Glacier로 이관

## 8. 재해 복구

본 시스템은 재해 복구를 위한 멀티 리전 구성을 지원한다. RPO는 5분, RTO는 30분을 목표로 한다.

## 9. 종속성

- Order Service → Inventory Service (재고 확인)
- Payment Service → Order Service (주문 상태 업데이트)
- Notification Worker → Order Service, Payment Service

## 10. 팀 및 담당

- 플랫폼 팀: 전체 아키텍처 책임
- 결제 팀: Payment Service 책임
- 인프라 팀: AWS 리소스 프로비저닝 및 모니터링
