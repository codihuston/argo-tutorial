Table of Contents
- [Purpose](#purpose)
    - [Prerequisites](#prerequisites)
  - [Create Sample App](#create-sample-app)
    - [Initialize the App Source Code](#initialize-the-app-source-code)
    - [Initialize Dependencies](#initialize-dependencies)
    - [Run Sample Tests](#run-sample-tests)
  - [Argo Workflow (CI)](#argo-workflow-ci)
  - [Getting Started](#getting-started)
  - [Argo CD](#argo-cd)
  - [Vault Integration](#vault-integration)
    - [Install Vault](#install-vault)
    - [Initialize the Vault](#initialize-the-vault)
    - [Unsteal the Vault](#unsteal-the-vault)
    - [Create a Secret](#create-a-secret)
    - [Enable AppRole Auth Method Backend](#enable-approle-auth-method-backend)
    - [Create a Policy for our AppRole](#create-a-policy-for-our-approle)
    - [Create an AppRole](#create-an-approle)
    - [Login with RoleID and SecretID](#login-with-roleid-and-secretid)
    - [Read Secrets using AppRole Token](#read-secrets-using-approle-token)
  - [Argo Events](#argo-events)
  - [Argo Rollouts](#argo-rollouts)
- [References](#references)

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

## Vault Integration

This is step-by-step for implementing `argo-cd-vault-plugin` with Hashicorp
Vault. Once I understand this, I might create a backend integration with Conjur.

Vault is used to provide secrets to Argo Workflows and CD.

### Install Vault

See: [Install Vault](https://developer.hashicorp.com/vault/docs/platform/k8s/helm/run)

```bash
# install vault
helm repo add hashicorp https://helm.releases.hashicorp.com
helm search repo hashicorp/vault
helm install vault hashicorp/vault
helm status vault

# list vaults
kubectl get pods -l app.kubernetes.io/name=vault
```

The above creates a vault named `vault-0` in the `default` namespace (unless
your `kubectl` client is configured to use a specific namespace).

### Initialize the Vault

```bash
kubectl exec -ti vault-0 -- vault operator init
```

This will output a list of `Unseal Keys` and an `Initial Root Token`. We must
use 3 of these keys to unsteal the vault once it has been sealed. Save these
somewhere safe.

### Unsteal the Vault

Using any three of the keys above, unseal the vault"

```bash
# Unseal the first vault server until it reaches the key threshold
$ kubectl exec -ti vault-0 -- vault operator unseal # ... Unseal Key 1
$ kubectl exec -ti vault-0 -- vault operator unseal # ... Unseal Key 2
$ kubectl exec -ti vault-0 -- vault operator unseal # ... Unseal Key 3
```

The final output should note `Sealed: false`:

```bash
Key             Value
---             -----
Seal Type       shamir
Initialized     true
Sealed          false # <---
Total Shares    5
Threshold       3
Version         1.12.1
Build Date      2022-10-27T12:32:05Z
Storage Type    file
Cluster Name    vault-cluster-578822fc
Cluster ID      baec362c-5b8e-2faa-4a4c-f105b0415e7c
HA Enabled      false
```

### Create a Secret

See: [Your First Secret](https://developer.hashicorp.com/vault/tutorials/getting-started/getting-started-first-secret)

> Note: below, we bypass vault login in the CLI. You can use the GUI at
> [localhost:8200](localhost:8200) and signing in with the same token, given
> you use the provided [port-forward](./bin/port-forward.sh) script.

```bash
# Exec into the vault pod
kubectl exec -ti vault-0 -- sh

# Help menu
vault kv --help

# Export the root token from earlier so that `vault login` is not required
export VAULT_TOKEN=

# Init the `secret` path
vault secrets enable -path=secret/ kv

# Load the secret
vault kv put -mount=secret hello foo=world

# Getting a secret
vault kv get -mount=secret hello foo=world

# Output
vault kv get -mount=secret hello
=== Data ===
Key    Value
---    -----
foo    world
```

### Enable AppRole Auth Method Backend

See: [AppRole Auth Method](https://developer.hashicorp.com/vault/docs/auth/approle)

This allows machines or apps to authenticate with Vault-defined roles. First,
we must enable this backend:

```bash
# Enable the backend
vault auth enable approle

# List backends
vault auth list
```

### Create a Policy for our AppRole

This enables an AppRole to access secrets in a manner that we specify:

Create and write the policy to Vault:

```bash
policy=$(cat << EOF
path "secret/*" {
  capabilities = ["read"]
}
EOF
)

echo $policy | vault policy write read-all-secrets -
# Success! Uploaded policy: read-all-secrets

# List policies
vault policy list
```

### Create an AppRole

With the backend enabled, we can create an AppRole with a given policy

```bash
vault write auth/approle/role/argocd policies=read-all-secrets \
    role_id=77f0807d-ac28-47e8-ade4-3831b354288a
# Success! Data written to: auth/approle/role/argocd
```

Now Retrieve the Role ID:

```bash
vault read auth/approle/role/argocd/role-id
# Output
Key        Value
---        -----
role_id    77f0807d-ac28-47e8-ade4-3831b354288a
```

Generate a Secret ID:

```bash
vault write -force auth/approle/role/argocd/secret-id

# Output
Key                   Value
---                   -----
secret_id             ed0a642f-2acf-c2da-232f-1b21300d5f29
secret_id_accessor    a240a31f-270a-4765-64bd-94ba1f65703c
secret_id_num_uses    0
secret_id_ttl         0s
```

### Login with RoleID and SecretID

Retrieve a Token that the App would use to authenticate and fetch secrets:

```bash
vault write auth/approle/login role_id="77f0807d-ac28-47e8-ade4-3831b354288a" \
    secret_id="ed0a642f-2acf-c2da-232f-1b21300d5f29"
# Output
Key                     Value
---                     -----
token                   hvs.CAESIJdE3dMjtj22X5rMEDPXBrSe2jKUXNikg1dx9mqPviNqGh4KHGh2cy5jNE1GMVA4N2FQbnkySXA0Q2NZQ3l6REw
token_accessor          KujSYcSMky0LCkByUHylDCoC
token_duration          768h
token_renewable         true
token_policies          ["default" "read-all-secrets"]
identity_policies       []
policies                ["default" "read-all-secrets"]
token_meta_role_name    argocd
```

### Read Secrets using AppRole Token

```bash
export APP_TOKEN="s.ncEw5bAZJqvGJgl8pBDM0C5h"
VAULT_TOKEN=$APP_TOKEN vault kv get secret/hello

# Output
=== Data ===
Key    Value
---    -----
foo    world
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
- https://itnext.io/argocd-secret-management-with-argocd-vault-plugin-539f104aff05
