#!/bin/bash

# References: https://argoproj.github.io/argo-workflows/quick-start/
main(){
  ARGO_WORKFLOWS_VERSION="3.4.4"
  kubectl create namespace argo
  kubectl apply -n argo -f "https://github.com/argoproj/argo-workflows/releases/download/v$ARGO_WORKFLOWS_VERSION/install.yaml"

  kubectl patch deployment \
    argo-server \
    --namespace argo \
    --type='json' \
    -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/args", "value": [
    "server",
    "--auth-mode=server"
  ]}]'

  argo submit -n argo --watch https://raw.githubusercontent.com/argoproj/argo-workflows/master/examples/hello-world.yaml

  argo list -n argo

  argo get -n argo @latest
}

main "$@"