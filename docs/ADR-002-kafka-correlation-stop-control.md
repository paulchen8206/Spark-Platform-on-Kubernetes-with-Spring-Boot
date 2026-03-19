# ADR-002: Kafka Correlation-ID Stop Control for Spark Jobs

- Status: Accepted
- Date: 2026-03-19
- Decision Makers: Platform team

## Context

The platform launches Spark jobs asynchronously through API requests. A running job may need to be stopped after API acceptance, potentially from another client session or operational workflow.

A stop mechanism is required that is:

- Decoupled from the API request lifecycle
- Reliable for distributed, long-running workloads
- Compatible with both batch and streaming job runtime behavior
- Traceable by a shared execution identifier

## Decision

Use Kafka topic based stop signaling with correlation id matching.

- The Spring Boot service publishes stop requests to a configured topic.
- The running Spark job consumes stop events and applies them only when the message correlation id matches the job correlation id.
- On match, the runtime stops active streaming queries and cancels/stops Spark context execution.

## Decision Drivers

- Asynchronous control plane aligned with HTTP 202 API behavior
- Loose coupling between API service and job runtime
- Support for distributed runtime and Kubernetes pod lifecycle
- Explicit targeting through correlation id

## Consequences

### Positive

- Stop control remains available even when API request thread has completed
- Correlation id provides deterministic targeting and auditability
- Works for streaming cancellation and broader Spark context cancellation
- Fits event-driven operational patterns already used in the platform

### Negative

- Requires careful topic/property alignment between producer and consumers
- Stop action is eventually consistent, not immediate synchronous termination
- Adds messaging dependency for control-path reliability
- Requires robust observability to diagnose mismatched correlation ids

## Alternatives Considered

### Direct process or pod kill from API service

- Pros: Immediate forceful termination
- Cons: Tight coupling to runtime internals, less graceful shutdown, higher operational risk

### Synchronous stop RPC from service to running job

- Pros: Clear request/response semantics
- Cons: Requires stable endpoint exposure from transient job runtime, harder in dynamic pod topology

### Polling and status-driven cancellation without messaging

- Pros: Simpler control channel conceptually
- Cons: Slower reaction time, weaker decoupling, more control-plane overhead

## Implementation Notes

- Producer path: Spark job service stop endpoint delegates to launcher publish call.
- Consumer path: Spark execution manager Kafka listener validates correlation id before stop actions.
- Stop actions: stop streaming queries, then cancel and stop SparkContext.

## References

- [Spring Application Lifecycle](SPRING_APPLICATION_LIFECYCLE.md)
- [Project Architecture](ARCHITECTURE.md)
- [Spark Job Service API](SPARK_JOB_SERVICE_API.md)
- [spark-job-service/src/main/java/com/aiks/spark/launcher/SparkSubmitJobLauncher.java](../spark-job-service/src/main/java/com/aiks/spark/launcher/SparkSubmitJobLauncher.java)
- [spark-job-commons/src/main/java/com/aiks/spark/common/SparkExecutionManager.java](../spark-job-commons/src/main/java/com/aiks/spark/common/SparkExecutionManager.java)
