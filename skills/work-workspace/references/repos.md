# Work Repository Reference

## Supported Repositories

| Repo Name | gh Repo Path | Description |
|-----------|--------------|-------------|
| jenkins-lib | `clumio/jenkins-lib` | Jenkins shared library |
| infra-kubernetes | `clumio/infra-kubernetes` | Kubernetes infrastructure |
| infra-charts | `clumio/infra-charts` | Helm charts |
| cdf | `clumio/cdf` | Clumio Data Framework |

## Directory Layout

All repos are stored under `~/Desktop/clumio/`:

```
~/Desktop/clumio/
├── jenkins-lib/
│   ├── main/           # Primary clone
│   ├── CENG-1234/      # Worktree for ticket
│   └── CENG-5678/      # Another worktree
├── infra-kubernetes/
│   └── main/
├── infra-charts/
│   └── main/
└── cdf/
    └── main/
```

## Branch Naming Convention

Pattern: `user/choru/${JIRA_TICKET}_${SUMMARY}/${TARGET_BRANCH}`

Examples:
- `user/choru/CENG-1234_add-retry-logic/main`
- `user/choru/CENG-5678_fix-deployment/release-2.0`
- `user/choru/CENG-9012_update-helm-values/main`

## Common Operations

### Check if repo is set up

```bash
ls -d ~/Desktop/clumio/REPO/main 2>/dev/null && echo "Setup" || echo "Not setup"
```

### Clone repo with gh

```bash
gh repo clone "clumio/$REPO" ~/Desktop/clumio/$REPO/main
```
