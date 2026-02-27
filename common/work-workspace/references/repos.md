# Work Repository Reference

## Supported Repositories

| Repo Name | gh Repo Path | Description |
|-----------|--------------|-------------|
| argocd-deployments | `clumio/argocd-deployments` | ArgoCD production GitOps configs |
| argocd-dev | `clumio/argocd-dev` | ArgoCD dev/testing GitOps configs |
| cdf | `clumio/cdf` | Clumio Data Fabric |
| infra-charts | `clumio/infra-charts` | Helm charts |
| infra-kubernetes | `clumio/infra-kubernetes` | Kubernetes infrastructure configs |
| infra-terraform | `clumio/infra-terraform` | Terraform/Terragrunt infrastructure |
| jenkins-ci-lib | `clumio/jenkins-ci-lib` | Jenkins CI shared library |
| jenkins-lib | `clumio/jenkins-lib` | Jenkins shared library |
| jenkins-system | `clumio/jenkins-system` | Jenkins job DSL + automation |
| jenkins_publish | `clumio/jenkins_publish` | Artifact publishing automation |
| jobutil | `clumio/jobutil` | Legacy Jenkins/Jira utilities |
| terraform-provider-clumio-internal | `clumio/terraform-provider-clumio-internal` | Internal Terraform provider |
| tf-aws-sso-permissionsets | `clumio/tf-aws-sso-permissionsets` | AWS SSO permission set IaC |

## Directory Layout

All repos are stored under `~/Desktop/clumio/`:

```
~/Desktop/clumio/
└── <repo>/
    ├── main/                 # source clone (do not use for ticket edits)
    ├── CENG-1234/            # ticket worktree (default)
    └── CENG-1234-variant/    # optional ticket variant worktree
```

## Naming Conventions

### Worktree directory

- Preferred: `CENG-####`
- Optional variant suffix when multiple streams are needed for one ticket:
  - `CENG-####-<suffix>` (examples: `CENG-5721-ce`, `CENG-5266-phase2`)

### Branch naming

Recommended pattern:

`user/choru/${JIRA_TICKET}_${SUMMARY}/${TARGET_BRANCH}`

Examples:
- `user/choru/CENG-1234_add-retry-logic/main`
- `user/choru/CENG-5678_fix-deployment/release-2.0`

Legacy branch names may exist. Do not auto-rename old branches unless user asks.

## Common Operations

### Check if repo is set up

```bash
ls -d ~/Desktop/clumio/REPO/main 2>/dev/null && echo "Setup" || echo "Not setup"
```

### Clone repo with gh

```bash
gh repo clone "clumio/$REPO" ~/Desktop/clumio/$REPO/main
```

### List worktrees

```bash
cd ~/Desktop/clumio/$REPO/main && git worktree list
```
