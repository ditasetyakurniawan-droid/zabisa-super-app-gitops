# Zabisa DT deployment ownership

- Source and Kubernetes templates: `zabisa-super-app`.
- Immutable images: `harbor-dt.co.id/devops-apps/zabisa`.
- Rendered DT desired state: this repository.
- Reconciliation authority: ArgoCD.
- Database schema changes: seven ordered ArgoCD PreSync Jobs.

The ArgoCD Application is bootstrapped from
`bootstrap/argocd-application.yaml`. Its automated sync is intentionally absent.
Review the source revision, image tags, migration waves, backup evidence and
GitOps diff before starting a manual sync.

Rollback is a Git revert to an earlier reviewed desired-state commit. Database
rollback still follows the application runbook and is never inferred from a
manifest revert.
