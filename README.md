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
> ownership of the files created by the above container by running the following
> command from your container host: `sudo chown $USER -R src/myapp/`.

If you are using Linux, before proceeding with the use of the docker-compose
file, initialize your `.env` file like such:

```bash
cd src/myapp
sed -e "s/{{ REPLACE_UID }}/$UID/g" -e "s/{{ REPLACE_GID }}/$UID/g" .env-example > .env
```

This will enable your container host user to modify files that were created by
these docker containers.

> Note: if you need to add new items to the `Gemfile`, you may need to
> remove the `user` field in [docker-compose.yml](./src/myapp/docker-compose.yml)
> so that the root of the container can be written to by the bundler.

### Initialize Dependencies

```bash
docker-compose run web bundle install
```

Initialize the test frameworks:

```
docker-compose run web rails generate rspec:install
docker-compose run web rails generate cucumber:install
```

> Note: be sure to take ownership of the files created again (if needed).

### Run Sample Tests

```bash
# unit / integration
docker-compose run web rspec

# end to end
docker-compose run web rake cucumber
```

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
