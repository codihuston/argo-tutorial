# Purpose

To demo Argo Workflow, Events, and CD.

### Prerequisites

1. [Install Argo CLI](https://github.com/argoproj/argo-workflows/releases)
2. [Kubernetes Cluster](https://kind.sigs.k8s.io/)

## Create Sample App 

The commands below will be run from the `src` directory.

### Initialize the App Source Code

1. Build the ruby image

  ```
  docker build -f Dockerfile.rails -t init-rails .
  ```

1. Create the rails app

  ```bash
  docker run -it --rm -v "$PWD":/app -w /app init-rails

  # in the container
  rails new --skip-git myapp
  ```

> Note: if you are using Linux (Ubuntu) aka not Docker Desktop, you must take
> ownership of the files created by the above container:
> `sudo chown $USER -R src/myapp/`.

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
