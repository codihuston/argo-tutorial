# Purpose

To demo Argo Workflow, Events, and CD.

### Prerequisites

1. [Install Argo Workflows CLI](https://github.com/argoproj/argo-workflows/releases)
2. [Install Argo CD CLI](https://argo-cd.readthedocs.io/en/stable/cli_installation/)
3. [Kubernetes Cluster](https://kind.sigs.k8s.io/)

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

See: [Repo](https://github.com/argoproj/argo-workflows).

Install and test a sample workflow:

```
./bin/001-install-argo-workflow.sh
```

Port forward the UI:

```
kubectl -n argo port-forward deployment/argo-server 2746:2746
```

Run the workflow for `myapp`:

```
./ci/test.sh
```

This workflow will:

1. Clone the repository
2. Build the image (rootless buildkit)
3. Push it to the internal KinD registry
4. Run RSpec tests in this image
5. Run Cucumber tests in this image

## Getting Started

Argo Workflows, Argo CD, Argo Events, and Argo Rollouts typically all live on
the same Kubernetes cluster.

Kubernetes provides a common platform for deploying and managing containers,
making it the natural choice for running Argo Workflows, Argo CD, and Argo
Events. Having all of these components on the same cluster allows for easy
integration and communication between them, enabling you to create a complete
CI/CD automation platform that can be easily managed and scaled.

It's possible to run Argo Workflows, Argo CD, and Argo Events on separate
clusters, at the cost of increasing the complexity of the setup and would
require additional infrastructure and network configuration to ensure
communication between the clusters. In most cases, it's recommended to run all
components on the same cluster for ease of use and management.

## Argo CD

See: [Repo](https://github.com/argoproj/argo-cd/releases).

Argo CD runs inside of Kubernetes. It will sync a given repo (application state)
to a Kubernetes cluster. So the workflow would be:

1. Run a workflow to build, test, and publish your application container
2. In Argo CD, register an application repo
3. When it's time to deploy to production, make a change in the [repo](https://github.com/codihuston/argo-cd-tutorial)
   that Argo CD is monitoring

   Argo CD will then sync the manifests to the Kubernetes cluster.

In reality, Argo Workflows would commit a change to the repo that Argo CD is
watching once the workflow is successful. Argo CD automatically polls repos for
changes every 3 minutes. You can configure this to use [webhooks instead](https://argo-cd.readthedocs.io/en/stable/operator-manual/webhook/#:~:text=Git%20Webhook%20Configuration-,Overview,Bitbucket%2C%20Bitbucket%20Server%20and%20Gogs.).

Install `Argo CD` and configure it to sync the [myapp gitops repository](https://github.com/codihuston/argo-cd-tutorial).

```
./bin/002-install-argo-cd-and-deploy-myapp.sh
```

This script will automatically port forward the UI, but in the case that
it doesn't (port forwarding seems to be flaky for me) you can run this command
below:

```
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

## Argo Events

See: [Repo](https://argoproj.github.io/argo-events/)

Argo Events is an event management solution for the Argo ecosystem. It can
watch a number of external services for changes and trigger Workflows or CD.

To kick off a workflow, CD, or Rollout, we use Argo Events.

Argo Events can trigger both Argo Workflows and Argo CD.

In one scenario, Argo Events can be used to trigger an Argo Workflow in response
to a specific event. For example, you can configure Argo Events to trigger
an Argo Workflow whenever a new image is pushed to a container registry. The
Argo Workflow can then perform tasks such as building images, testing code,
and deploying applications.

In another scenario, Argo Workflows can trigger Argo CD by modifying the desired
state of the applications being managed by Argo CD. For example, you can create
an Argo Workflow that updates the source code or configuration of an
application and commits the changes to the source repository. Argo CD is
configured to continuously sync the desired state of the application with the
actual state in the target environment, so when it detects changes in the source
repository, it will trigger a redeployment of the updated application.

In summary, Argo Events can trigger either Argo Workflows or Argo CD, depending
on the desired automation scenario, and both Argo Workflows and Argo CD can be
used together to automate complex CI/CD pipelines and continuously manage the
desired state of your applications.

## Argo Rollouts

See: [Repo](https://argo-rollouts.readthedocs.io/en/stable/)


Argo Rollouts provides advanced deployment capabilities for your applications,
allowing you to perform progressive delivery and canary releases, automate
rollbacks, and control traffic routing. 

# References

- https://github.com/argoproj/argo-workflows/blob/master/examples/buildkit-template.yaml
- https://github.com/moby/buildkit
- https://kind.sigs.k8s.io/docs/user/local-registry/
- https://argoproj.github.io/argo-workflows/enhanced-depends-logic/
