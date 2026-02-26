---
id: select-repository
description: Select supported repository and resolve local path + gh repo mapping.
status: active
tags: [node, repository]
links:
  - [[extract-ticket-number]]
  - [[setup-repository]]
---

# Select Repository

Prefer explicit repository from user input.
If missing, ask user to choose from supported repositories in `references/repos.md`.

Current supported repos:
- `argocd-deployments`
- `argocd-dev`
- `cdf`
- `infra-charts`
- `infra-kubernetes`
- `infra-terraform`
- `jenkins-ci-lib`
- `jenkins-lib`
- `jenkins-system`
- `jenkins_publish`
- `jobutil`
- `terraform-provider-clumio-internal`
- `tf-aws-sso-permissionsets`

Use `references/repos.md` for canonical mapping and examples.

Return:
- `repo_name`
- local root path `~/Desktop/clumio/<repo_name>/`
- source clone path `~/Desktop/clumio/<repo_name>/main`
