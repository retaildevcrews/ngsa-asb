# Image Automation with Flux Spike

The following instructions will demonstrate how to bootstrap a Kubernetes Cluster with FluxCD v2, Image Reflector, and Image Automation controllers to show the image automation end-to-end flow. These are for spike purposes only and should be applied to a vanilla Kubernetes cluster such as k3d.

## Install Flux and Bootstrap with Image Reflector and Image Automation controllers

``` bash

# Install Flux
curl --location --silent --output /tmp/flux.tar.gz "https://github.com/fluxcd/flux2/releases/download/v0.29.5/flux_0.29.5_linux_amd64.tar.gz"
sudo tar --extract --gzip --directory /usr/local/bin --file /tmp/flux.tar.gz
rm /tmp/flux.tar.gz

# Set branch for flux to listen to
export BRANCH='image-automation'

# Set a GitHub personal access token that flux will use to read and write to the repo
export GITHUB_TOKEN=<yourToken>

git checkout -b $BRANCH

git push --set-upstream origin $BRANCH

flux bootstrap git \
  --url "https://github.com/retaildevcrews/ngsa-asb" \
  --branch $BRANCH \
  --token-auth \
  --password ${GITHUB_TOKEN} \
  --path "/spikes/image-versioning/deploy" \
  --components-extra=image-reflector-controller,image-automation-controller

  git pull
  ```

## Deploy NGSA Application

```bash
kubectl create ns ngsa

flux create kustomization "ngsa" \
    --source GitRepository/flux-system \
    --path "/deploy/ngsa" \
    --namespace flux-system \
    --prune true \
    --interval 1m \
    --export > spikes/image-versioning/deploy/bootstrap/ngsa-kustomization.yaml

git add spikes/image-versioning/deploy/bootstrap/ && \
    git commit -m "Add ngsa kustomization" && \
    git push && \
    flux reconcile source git flux-system && \
    flux reconcile kustomization flux-system
```

### View current image version

``` bash
kubectl get deployment/ngsa-memory -oyaml -n ngsa | grep 'image:'
```

## Configure Image Scanning

Create an ImageRepository to tell Flux which container registry to scan for new tags:

``` bash
flux create image repository ngsa \
--image=ghcr.io/joaquinrz/ngsa-app \
--interval=1m \
--export > ./spikes/image-versioning/deploy/ngsa/ngsa-app-registry.yaml
```

Create an ImagePolicy to tell Flux which semver range to use when filtering tags:

``` bash
flux create image policy ngsa \
--image-ref=ngsa \
--select-semver=1.2.x \
--export > ./spikes/image-versioning/deploy/ngsa/ngsa-app-policy.yaml
```

Commit changes and reconcile

``` bash
git add ./spikes/image-versioning/deploy && \
git commit -m "add ngsa image scan" && \
git push && \
flux reconcile kustomization flux-system --with-source
```

Wait for Flux to fetch the image tag list from GitHub container registry:

``` bash
flux get image repository ngsa

flux get image policy ngsa
```

Create an ImageUpdateAutomation to tell Flux which Git repository to write image updates to:

``` bash
flux create image update flux-system \
--git-repo-ref=flux-system \
--git-repo-path="./spikes/image-versioning/deploy/ngsa" \
--checkout-branch=$BRANCH \
--push-branch=$BRANCH \
--author-name=fluxcdbot \
--author-email=fluxcdbot@users.noreply.github.com \
--commit-template="{{range .Updated.Images}}{{println .}}{{end}}" \
--export > ./deploy/ngsa/flux-system-automation.yaml
```

Commit changes and reconcile

``` bash
git add ./spikes/image-versioning/deploy && \
git commit -m "Added image updates automation" && \
git push && \
flux reconcile kustomization flux-system --with-source
```

> 🛑 Do changes to ngsa-app and bump version. In case your current ngsa-app setup does not support semantic versioning, add this following to your github action workflow file

``` yaml
    - name: Bump version
      id: bump
      uses: vers-one/dotnet-project-version-updater@v1.2
      with:
        file: "Ngsa.App.csproj"
        version: bump-build


    - name: Commit Version Bump
      run: |
          git config user.name "Joaquin Rodriguez"
          git config user.email "rjoaquin@microsoft.com"
          git add .
          git commit -m "Update project version to ${{ steps.bump.outputs.newVersion }}"
          git push
    - name: Docker Tag and Push
      run: |
       # VERSION=$(docker run --rm image --version)
       # tag the repo with latest version and :beta
       NEW_VERSION=${{ steps.bump.outputs.newVersion }}
       docker tag image $DOCKER_REPO:beta
       docker tag image $DOCKER_REPO:$NEW_VERSION
       # Push to the repo
       docker push -a $DOCKER_REPO
```

### Flux reconcile

``` bash
flux reconcile kustomization flux-system --with-source

kubectl describe ImageUpdateAutomation flux-system -n flux-system
```

### Verify new image version

``` bash
kubectl get deployment/ngsa-memory -oyaml -n ngsa | grep 'image:'
```
