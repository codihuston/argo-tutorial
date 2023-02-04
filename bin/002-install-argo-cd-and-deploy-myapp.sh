#!/bin/bash

# References: https://argo-cd.readthedocs.io/en/stable/getting_started/
main(){
  ARGO_CD_VERSION="2.5.10"
  APP_NAMESPACE="myapp"
  ARGO_CD_NAMESPACE="argocd"
  ARGO_SERVER="localhost:8080"
  REPO="https://github.com/codihuston/argo-cd-tutorial.git"
  SELECTOR="app.kubernetes.io/name=argocd-server"

  kubectl create namespace argocd
  kubectl apply -n "$ARGO_CD_NAMESPACE" -f https://raw.githubusercontent.com/argoproj/argo-cd/v$ARGO_CD_VERSION/manifests/install.yaml

  while ! kubectl -n "$ARGO_CD_NAMESPACE" get secret argocd-initial-admin-secret;
  do
    echo "Waiting for secret to be available..."
    sleep 1
  done

  admin_pwd=$(kubectl -n "$ARGO_CD_NAMESPACE" get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo)

  while [[ $(kubectl get pods -n "$ARGO_CD_NAMESPACE" -l "$SELECTOR" -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo "Waiting for for pod: $SELECTOR..." && sleep 1; done

  echo "Port forwarding on localhost:8080..."
  kubectl port-forward svc/argocd-server -n "$ARGO_CD_NAMESPACE" 8080:443 &

  echo "ArgoCD Admin Username: admin"
  echo "ArgoCD Admin Password: $admin_pwd"
  argocd login "$ARGO_SERVER"

  # Register the KinD cluster that we will deploy apps to
  yes | argocd cluster add kind-kind

  # Deploy an application
  kubectl create ns "$APP_NAMESPACE"
  argocd app create myapp  --repo "$REPO" --path myapp --dest-server https://kubernetes.default.svc --dest-namespace "$APP_NAMESPACE"
}

main "$@"