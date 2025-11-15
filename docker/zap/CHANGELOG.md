# Changelog - OWASP ZAP Scanner Script

## 2025-11-14 - Docker Image Name Update

### Problem

The script was using outdated OWASP ZAP Docker image names that no longer exist:

- ❌ `owasp/zap2docker-stable` (deprecated)
- ❌ `owasp/zap2docker-weekly` (deprecated)

These images were causing Docker pull errors:

```text
docker: Error response from daemon: pull access denied for owasp/zap2docker-stable, 
repository does not exist or may require 'docker login': denied: requested access to 
the resource is denied
```

### Solution

Updated the script to use the current official OWASP ZAP Docker images:

- ✅ `zaproxy/zap-stable` (stable release on Docker Hub)
- ✅ `zaproxy/zap-weekly` (weekly release on Docker Hub)
- ✅ `ghcr.io/zaproxy/zaproxy:stable` (GitHub Container Registry - unchanged)

### Changes Made

1. **check-zap-cve.sh**: Updated Docker image references in the menu options and case statement
2. **README.md**: Updated documentation to reflect the correct image names
3. Both script and documentation now reference the correct Docker Hub repository: `zaproxy/*`

### Testing

Verified that the updated script successfully pulls and runs the correct Docker image:

```bash
./check-zap-cve.sh https://morpheus-dev.loonar.dev/
# Option 2: zaproxy/zap-stable ✅ Successfully pulled and executed
```

### Migration Guide

If you were using the old image names in any custom scripts or configurations, update them as follows:

- `owasp/zap2docker-stable` → `zaproxy/zap-stable`
- `owasp/zap2docker-weekly` → `zaproxy/zap-weekly`

The GHCR image name remains unchanged: `ghcr.io/zaproxy/zaproxy:stable`

