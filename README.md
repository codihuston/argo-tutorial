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
  - [Setup Hashicorp Vault](#setup-hashicorp-vault)
    - [Install Vault](#install-vault)
    - [Initialize the Vault](#initialize-the-vault)
    - [Unsteal the Vault](#unsteal-the-vault)
    - [Create a Secret](#create-a-secret)
    - [Enable AppRole Auth Method Backend](#enable-approle-auth-method-backend)
    - [Create a Policy for our AppRole](#create-a-policy-for-our-approle)
    - [Create an AppRole](#create-an-approle)
    - [Login with RoleID and SecretID](#login-with-roleid-and-secretid)
    - [Read Secrets using AppRole Token](#read-secrets-using-approle-token)
  - [Setup Argo CD Vault Plugin](#setup-argo-cd-vault-plugin)
    - [Add the Plugin to the Argo CD Server Deployment](#add-the-plugin-to-the-argo-cd-server-deployment)
    - [Register the Plugin with Argo CD](#register-the-plugin-with-argo-cd)
    - [Point Argo CD Repo Server to Vault](#point-argo-cd-repo-server-to-vault)
    - [Register an Application with ArgoCD that Leverages a Vault Secret](#register-an-application-with-argocd-that-leverages-a-vault-secret)
  - [Argo Events](#argo-events)
  - [Argo Rollouts](#argo-rollouts)
- [After Thoughts and Concerns](#after-thoughts-and-concerns)
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

## Setup Hashicorp Vault

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
./bin/vault-cli vault operator init
```

This will output a list of `Unseal Keys` and an `Initial Root Token`. We must
use 3 of these keys to unsteal the vault once it has been sealed. Save these
somewhere safe.

### Unsteal the Vault

Using any three of the keys above, unseal the vault"

```bash
# Unseal the first vault server until it reaches the key threshold
$ ./bin/vault-cli vault operator unseal # ... Unseal Key 1
$ ./bin/vault-cli vault operator unseal # ... Unseal Key 2
$ ./bin/vault-cli vault operator unseal # ... Unseal Key 3
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
./bin/vault-cli sh

# Help menu
vault kv --help

# Export the root token from earlier so that `vault login` is not required
export VAULT_TOKEN=

# Init the `secret` path
vault secrets enable -path="secret" kv-v2

# Load the secret
vault kv put -mount=secret hello foo=world

# Getting a secret
vault kv get secret/hello

# Output
== Secret Path ==
secret/data/hello

======= Metadata =======
Key                Value
---                -----
created_time       2023-02-05T09:12:14.7971105Z
custom_metadata    <nil>
deletion_time      n/a
destroyed          false
version            1

=== Data ===
Key    Value
---    -----
foo    world
```

> Important: apparently `kv` version 1 and 2 differ in that, when creating a
> secret when using 2 will prefix the created secret with `/data/`. For example
> `secret/hello` would be read using `secret/data/argocd/secrets`. You can check
> your `kv` version for a given mount `secret` as follows: `vault read -format=json /sys/mounts/secret/tune`.
> Or verify the options column for the `secret` mount: `vault secrets list -detailed`
>
> If the options.version field is null, it means that the secrets engine does
> not support multiple versions of secrets. In this case, the secrets engine
>  will only store the latest version of each secret, and there will not be any
>  way to roll back to previous versions of secrets.
>
> From this tutorial, `vault version` is reporting `Vault v1.12.1 (e34f8a14fb7a88af4640b09f3ddbb5646b946d9c), built 2022-10-27T12:32:05Z`.

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

## Setup Argo CD Vault Plugin

Once you have [Setup Hashicorp Vault](#setup-hashicorp-vault), you can proceed
with this section.

Integrating with Vault will allow you to template the values of
Kubernetes Secret resources with values that exist in Vault. That is, if your
application depends on Kubernetes Secrets (say, `envFrom secretRef`), then
this is the use case of Argo CD Vault Plugin.

Whether or not this integration can be used with Argo Workflows is TBD.

### Add the Plugin to the Argo CD Server Deployment

This is done by making changes to the Kubernetes manifest used for installing
Argo CD. I have already done this. This is done in 3 parts:

1. Creating an `emptyDir` volume to hold custom binaries (`spec.volumes`)
2. Use an init container to download/copy/build custom binaries into `emptyDir`
3. Mount the custom binary to the bin directory (spec.containers[*].volumeMounts on the `argocd-repo-server` container)

Apply the manifest:

```bash
kubectl apply -n "argocd" -f kubernetes/argo-cd-2.5.10-install.yaml
```

Verify the plugin binary exists and is runnable:

```bash
# Note: this is a proxy script used to find the argocd deployment pod. If
# multiple of these pods are reconciling, you will want to wait till there
# is only one pod before verifying. The script outputs all of the pods matching
# the label: app.kubernetes.io/name=argocd-repo-server
./bin/argo-cd-repo-server-cli argocd-vault-plugin

# Output
This is a plugin to replace <placeholders> with Vault secrets

Usage:
  argocd-vault-plugin [flags]
  argocd-vault-plugin [command]

Available Commands:
  completion  generate the autocompletion script for the specified shell
  generate    Generate manifests from templates with Vault values
  help        Help about any command
  version     Print argocd-vault-plugin version information

Flags:
  -h, --help   help for argocd-vault-plugin

Use "argocd-vault-plugin [command] --help" for more information about a command.
```

### Register the Plugin with Argo CD

This is done by updating the Argo CD ConfigMap by adding the following:

> Note: this has already been injected into the provided argocd installation
> manifest.

```yaml
data:
  configManagementPlugins: |-
    - name: argocd-vault-plugin
      generate:
        command: ["argocd-vault-plugin"]
        args: ["generate", "./"]
```

### Point Argo CD Repo Server to Vault

Next, let's create a set of secrets that the Argo CD Server will consume:

```bash
kubectl apply -f kubernetes/argocd-vault-plugin-credentials.yml -n argocd
```

This secret map contains the values required to find the Vault and the
credentials used to authenticate.

You must then restart the argocd server:

```
kubectl delete  pod -n argocd -l app.kubernetes.io/name=argocd-repo-server
```

### Register an Application with ArgoCD that Leverages a Vault Secret

We will use a repository that will deploy a Kubernetes Secret that references
a secret from Vault.

Register it with Argo CD as such:

```bash
APP_NAMESPACE="example-secret-app"
APP_NAME="$APP_NAMESPACE"
APP_PATH="$APP_NAME"
REPO="https://github.com/codihuston/argo-cd-tutorial"

kubectl create ns "$APP_NAMESPACE" || true

# IMPORTANT: DO NOT FORGET --config-management-plugin argument!
argocd app create "$APP_NAME" --repo "$REPO" \
  --path "$APP_PATH" \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace "$APP_NAMESPACE" \
  --config-management-plugin argocd-vault-plugin

# Verify the secret exists and contains the right value
kubectl get secret example-secret -n "$APP_NAMESPACE"
kubectl get secret example-secret -n "$APP_NAMESPACE" -o jsonpath='{.data}'
```

The secrets engine for `vault kv` is `kv-v2`.

> WARNING: See deprecation notice: WARN[0000] spec.plugin.name is set, which
> means this Application uses a plugin installed in the argocd-cm ConfigMap.
> Installing plugins via that ConfigMap is deprecated in Argo CD v2.5. Starting
> in Argo CD v2.6, this Application will fail to sync. Contact your Argo CD
> admin to make sure an upgrade plan is in place. More info: https://argo-cd.readthedocs.io/en/latest/operator-manual/upgrading/2.4-2.5/ 
> [The solution is to install via sidecar](https://argo-cd.readthedocs.io/en/stable/user-guide/config-management-plugins/#option-2-configure-plugin-via-sidecar).


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

# After Thoughts and Concerns

1. The Argo Workflow is using `rootless buildkit` to build images in Docker.
   First, is building docker images in Kubernetes safe at the runtime level,
   and if not, how to secure it? See: [Sysbox](https://github.com/nestybox/sysbox)

   Need to consider whether or not the build methods used will produce the
   exact same docker image as if it were built outside of Kubernetes.

2. While there is integration with Argo CD with Vault, discovery as to whether
   or not the same integration existing for Workflows (CI) is WIP

   It seems that the Vault integration with Argo CD is used to deliver secrets
   from Vault as native Kubernetes Secrets.
   
   Conjur's Secrets Provider delivers secrets to via Push-to-File or
   Kubernetes Secrets. Applications can fetch secrets at runtime using the
   Conjur SDKs so long as they have an authenticator sidecar or init container.

   So instead of end-users defining Kubernetes Secrets in a templated manner
   with the Argo CD Vault Plugin for integration with a Secrets Management as a
   backend, they would simply commit deployment manifests to their gitops repo,
   which would contain the Secrets Provider configuration.

   So the answer to the question as to whether there needs to be Argo CD
   integration with Conjur seems to be "No" at the moment.

   For Workflows: we can use the authenticator to ensure that any tooling pods
   can access the secrets needed. Our tooling pods would just need to use
   Summon or the like to fetch those values (API Keys, URLs, etc.) when running
   their workflow steps. There may be a challenge would be configuring a Conjur
   Host such that it can authenticate. Though, I believe all Argo Workflows
   are run in the same Namespace with the same Service Account?

3. Argo CD can be configured to deploy to multiple Kubernetes clusters, though
   such patterns don't seem to be well documented by Argo themselves

   See:
   - [Building a Fleet with ArgoCD and GKE](https://cloud.google.com/blog/products/containers-kubernetes/building-a-fleet-with-argocd-and-gke)
   - [Multi-Cluster Management for Kubernetes with Cluster API and Argo CD](https://aws.amazon.com/blogs/containers/multi-cluster-management-for-kubernetes-with-cluster-api-and-argo-cd/)

# References

- https://github.com/argoproj/argo-workflows/blob/master/examples/buildkit-template.yaml
- https://github.com/moby/buildkit
- https://kind.sigs.k8s.io/docs/user/local-registry/
- https://argoproj.github.io/argo-workflows/enhanced-depends-logic/
- Configuring the Vault Plugin: https://itnext.io/argocd-secret-management-with-argocd-vault-plugin-539f104aff05

    ConfigMap Install Method is Deprecated, see below:

    - https://argocd-vault-plugin.readthedocs.io/en/stable/installation/#initcontainer-and-configuration-via-sidecar
    - https://argo-cd.readthedocs.io/en/stable/user-guide/config-management-plugins/#option-2-configure-plugin-via-sidecar