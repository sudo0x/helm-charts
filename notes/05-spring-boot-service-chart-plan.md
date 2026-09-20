# Spring Boot Service Chart Plan

This note points to the next chart planned for the repository:

```text
charts/spring-boot-service/
```

Read the detailed design first:

```text
charts/spring-boot-service/README.md
```

The planned chart is a reusable application chart for Spring Boot microservices. It is separate from the Redis infrastructure chart.

## Planned repository layout

```text
charts/
├── redis/
└── spring-boot-service/
    └── README.md
```

Do not create Helm templates yet. First review the design, confirm the required Spring Boot conventions, and decide which optional features are needed.

## Recommended implementation order

1. Review `charts/spring-boot-service/README.md`.
2. Confirm the Spring Boot health endpoint paths.
3. Confirm the container port.
4. Confirm the image registry and tagging convention.
5. Decide how application Secrets are managed.
6. Implement the base Deployment.
7. Implement the ClusterIP Service.
8. Add resources, security contexts, and probes.
9. Add ConfigMap and existing Secret references.
10. Add optional Ingress, HPA, and PDB only when needed.
11. Validate with `helm lint` and `helm template`.
12. Write service installation examples.

## Important separation

Keep these independent:

```text
Redis chart:          charts/redis/
Spring Boot chart:    charts/spring-boot-service/
```

The Spring Boot chart may connect to Redis through configurable values, but it should not install Redis automatically by default.

