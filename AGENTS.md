# Agent Development Guidelines

This document provides guidelines for AI coding agents working with this GitOps repository.

## Repository Overview

This is a Kubernetes GitOps repository using Flux for continuous delivery. The repository contains Kubernetes manifests organized by service in the `flux/` directory.

## Build/Lint/Test Commands

### Deployment Commands

```bash
# Bootstrap Flux (initial setup)
flux install
flux bootstrap github \
  --deploy-token-auth \
  --owner=eeveebot \
  --repository=gitops \
  --branch=main \
  --path=flux

# Apply changes to cluster
kubectl apply -k flux/

# Check Flux status
flux get all -A
```

### Encryption/Decryption

```bash
# Encrypt sensitive files
./flux/encrypt.sh <file>

# Decrypt sensitive files
./flux/decrypt.sh <file>
```

### Validation

```bash
# Validate Kubernetes manifests
kubectl apply --dry-run=client -k flux/

# Check for syntax errors
flux validate kustomization flux/
```

### Testing Individual Components

```bash
# Test individual service deployment
kubectl apply --dry-run=client -k flux/<service-name>/

# Validate specific manifest
kubectl apply --dry-run=client -f flux/<service>/<manifest>.yaml
```

## Code Style Guidelines

### File Organization

1. Organize manifests by service/component in separate directories under `flux/`
2. Use Kustomize for managing environment-specific configurations
3. Keep sensitive data encrypted with SOPS
4. Maintain consistent naming conventions for resources
5. Group related resources in the same directory

### YAML Formatting

1. Use 2-space indentation (no tabs)
2. Always use explicit values for booleans (true/false instead of yes/no)
3. Quote strings that contain special characters
4. Use consistent ordering of keys:
   - apiVersion
   - kind
   - metadata
   - spec
   - status (if applicable)

### Resource Naming

1. Use descriptive names that clearly indicate the resource's purpose
2. Follow Kubernetes naming conventions (lowercase, DNS-compatible)
3. Use consistent prefixes for related resources
4. Avoid generic names like "server" or "app"

### Labels and Annotations

1. Use standard labels:
   - app.kubernetes.io/name: Application name
   - app.kubernetes.io/instance: Unique instance identifier
   - app.kubernetes.io/version: Application version
   - app.kubernetes.io/component: Component within the application

### Secrets Management

1. Always encrypt secrets using SOPS before committing
2. Store encryption keys securely and never commit them
3. Use Kubernetes secrets for sensitive data
4. Rotate secrets regularly

### Error Handling

1. Include appropriate health checks (liveness/readiness probes)
2. Set resource limits and requests
3. Handle pod disruption budgets for critical services
4. Use appropriate restart policies

### Documentation

1. Comment complex configurations
2. Document external dependencies
3. Include README files for each service directory
4. Keep documentation up-to-date with code changes

### Version Control

1. Make small, focused commits with descriptive messages
2. Use feature branches for significant changes
3. Tag releases appropriately
4. Follow conventional commit message format

### Security Practices

1. Regularly update base images and dependencies
2. Run containers as non-root users when possible
3. Implement network policies to restrict traffic
4. Scan images for vulnerabilities
5. Apply principle of least privilege for RBAC

### Testing

1. Validate manifests with dry-run before applying
2. Test changes in a development environment first
3. Use namespace isolation for testing
4. Implement rollback procedures

These guidelines help maintain consistency and reliability across the GitOps workflow.