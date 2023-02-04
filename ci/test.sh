#!/bin/bash
# shellcheck disable=SC1091
source "$(git rev-parse --show-toplevel)/bin/functions"

main(){
  REPO_NAME="https://github.com/codihuston/argo-tutorial"
  BRANCH="$(git_current_branch)"
  DOCKERFILE_DIR="src/myapp"
  # Use the following path inside k8s, see: https://kind.sigs.k8s.io/docs/user/local-registry/
  REGISTRY_PUSH="kind-registry:5000"
  REGISTRY_PULL="localhost:5001"
  IMAGE="myapp:$(git_sha)"

  argo submit -n argo --watch "$(repo_root)/workflows/myapp/myapp.yaml" \
    --parameter "repo=$REPO_NAME" \
    --parameter "branch=$BRANCH" \
    --parameter "path=$DOCKERFILE_DIR" \
    --parameter "registry_push=$REGISTRY_PUSH" \
    --parameter "registry_pull=$REGISTRY_PULL" \
    --parameter "image=$IMAGE"
}

main "$@"
