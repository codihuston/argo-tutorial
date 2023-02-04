# Purpose

To demo Argo Workflow, Events, and CD.

### Prerequisites

1. [Install Argo CLI](https://github.com/argoproj/argo-workflows/releases)
2. [Kubernetes Cluster](https://kind.sigs.k8s.io/)


## Argo Workflow (CI)

Install and test a sample workflow:

```
./install-argo-workflow.sh
```

Port forward the UI:

```
kubectl -n argo port-forward deployment/argo-server 2746:2746
```

### Getting Started

## Argo CD

## Argo Rollouts

## Argo Events

To kick off a workflow, CD, or Rollout, we use Argo Events.
