#!/bin/bash

main(){
  ARGO_CD_NAMESPACE="argocd"
  ARGO_WORKFLOW_NAMESPACE="argo"
  kubectl port-forward svc/argocd-server -n "$ARGO_CD_NAMESPACE" 8080:443 &
  kubectl port-forward deployment/argo-server -n "$ARGO_WORKFLOW_NAMESPACE" 2746:2746 &
  kubectl port-forward vault-0 -n "default" 8200:8200 &
}

main "$@"