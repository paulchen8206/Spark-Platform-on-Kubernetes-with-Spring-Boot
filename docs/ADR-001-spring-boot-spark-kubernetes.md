# ADR-001: Spring Boot Control Plane with Spark on Kubernetes

- Status: Accepted
- Date: 2026-03-19
- Decision Makers: Platform team

## Context

The platform needs to expose APIs to start, stop, and observe data processing workloads while supporting both batch and streaming execution. The solution must be cloud-native, portable across environments, and operationally consistent with Kubernetes-based deployment practices.

Traditional cluster managers like YARN can run Spark effectively, but they introduce a split operating model when the control plane (Spring services) already runs on Kubernetes.

## Decision

Use Spring Boot as the control plane and Apache Spark on Kubernetes as the distributed compute plane.

- Spring Boot provides REST APIs, validation, orchestration, configuration binding, and operational endpoints.
- Spark provides distributed batch and streaming execution.
- Kubernetes hosts both layers and manages pod scheduling, scaling, lifecycle, and policy controls.
- Spark applications are packaged as container images and launched through spark-submit targeting Kubernetes.

## Decision Drivers

- Dynamic executor scaling for workload-aware resource usage
- Unified infrastructure for service and data processing runtimes
- Container portability across dev, qa, stg, and production
- Alignment with cloud-native operational model (RBAC, networking, observability)

## Consequences

### Positive

- Better elasticity through executor scale out and scale in
- One orchestration platform for APIs, jobs, and supporting services
- Consistent CI/CD and deployment model using container images
- Strong isolation and lifecycle management through pods and namespaces

### Negative

- Higher operational complexity requiring Spring + Spark + Kubernetes expertise
- Additional networking and security configuration for driver/executor communication
- More moving parts for storage, metadata, and streaming checkpoint management
- Requires mature observability to debug cross-layer issues quickly

## When to Use

Choose this architecture when:

- A Spring Boot API must trigger and govern Spark pipelines
- Workloads require distributed compute with cloud-native scaling
- Teams want a single Kubernetes operating model for microservices and data jobs

## Alternatives Considered

### Spark on YARN with separate Spring service platform

- Pros: Mature Spark runtime model, known patterns in Hadoop-centric environments
- Cons: Split operations model, weaker container-native portability, duplicated platform concerns

### Spark standalone cluster outside Kubernetes

- Pros: Simpler Spark-focused setup for limited scenarios
- Cons: Separate lifecycle, weaker integration with Kubernetes-native service operations

## References

- [Project Architecture](ARCHITECTURE.md)
- [Spring Boot Framework](SPRING_BOOT_FRAMEWORK.md)
- [Spring Application Lifecycle](SPRING_APPLICATION_LIFECYCLE.md)
