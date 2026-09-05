#!/usr/bin/env bash

set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OVERLAY="$ROOT/apps/zabisa/overlays/dt"
EXPECTED_REPOSITORY='https://github.com/ditasetyakurniawan-droid/zabisa-super-app-gitops.git'

fail() {
  echo "[gitops-verify] ERROR: $*" >&2
  exit 1
}

for required in \
  "$ROOT/bootstrap/argocd-application.yaml" \
  "$OVERLAY/kustomization.yaml" \
  "$OVERLAY/SOURCE_REVISION" \
  "$OVERLAY/manifests/platform.yaml" \
  "$OVERLAY/manifests/migrations.yaml"; do
  [[ -s "$required" ]] || fail "missing file: ${required#"$ROOT/"}"
done

revision="$(<"$OVERLAY/SOURCE_REVISION")"
[[ "$revision" =~ ^[0-9a-f]{40}$ ]] || fail 'SOURCE_REVISION is not a full Git SHA'

grep -Fq "repoURL: $EXPECTED_REPOSITORY" \
  "$ROOT/bootstrap/argocd-application.yaml" || fail 'ArgoCD repository mismatch'
grep -Fq 'path: apps/zabisa/overlays/dt' \
  "$ROOT/bootstrap/argocd-application.yaml" || fail 'ArgoCD path mismatch'
if grep -RqE 'REPLACE_SHA|:latest([[:space:]]|$)' "$OVERLAY"; then
  fail 'mutable or unresolved image reference found'
fi

mapfile -t image_refs < <(
  grep -RhE '^[[:space:]]*image:[[:space:]]+harbor-dt\.co\.id/zabisa/' \
    "$OVERLAY/manifests" | awk '{print $2}'
)
[[ "${#image_refs[@]}" == 16 ]] || fail "expected 16 image references, found ${#image_refs[@]}"

for image in "${image_refs[@]}"; do
  [[ "$image" =~ ^harbor-dt\.co\.id/zabisa/[a-z0-9-]+:${revision}$ ]] \
    || fail "image does not match SOURCE_REVISION: $image"
done

resource_count="$(grep -c '^  - manifests/.*\.yaml$' "$OVERLAY/kustomization.yaml")"
manifest_count="$(find "$OVERLAY/manifests" -maxdepth 1 -type f -name '*.yaml' | wc -l | tr -d ' ')"
[[ "$resource_count" == "$manifest_count" ]] \
  || fail "Kustomize resources=$resource_count manifests=$manifest_count"

if command -v kubectl >/dev/null 2>&1; then
  kubectl kustomize "$OVERLAY" >/dev/null
  echo '[gitops-verify] OK: kubectl kustomize render'
else
  echo '[gitops-verify] SKIP: kubectl unavailable; structural validation passed'
fi

echo "[gitops-verify] PASS: revision=$revision images=16 manifests=$manifest_count"
