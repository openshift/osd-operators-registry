# OSD Operators Registry

## Summary

This repository creates a `CatalogSource` that can be used by OLM to deploy OpenShift Dedicated operators.

The following operators are part of the bundle:

- [dedicated-admin-operator](https://github.com/openshift/dedicated-admin-operator.git)

# Adding to Catalog

This section outlines what needs to be true for the Operator and for the Registry in order for the catalog to include a new operator.

## Operator

Must have a `make` target called `env`.  The `env` target is evaluated by `make`.  Therefore, this target must output the following key-value-pairs in this format:

```
OPERATOR_NAME=dedicated-admin-operator
OPERATOR_NAMESPACE=openshift-dedicated-admin
OPERATOR_VERSION=0.1.70-2019-04-09-c42c4625
```

To make this easy, you can add something like the following to your `Makefile` in the operator:

```
.PHONY: env
.SILENT: env
env:
    echo OPERATOR_NAME=$(OPERATOR_NAME)
    echo OPERATOR_NAMESPACE=$(OPERATOR_NAMESPACE)
    echo OPERATOR_VERSION=$(OPERATOR_VERSION)
    echo OPERATOR_IMAGE_URI=$(OPERATOR_IMAGE_URI)
```

## Registry

In this repository (aka Registry) you need to simply add a call to `checkout_operator` in the `operator-source` target.  Note not to include spaces between function name and arguments in `call`:

```
OPERATORS := openshift/dedicated-admin-operator thenamespace/newhotness-operator
```

# Building

Build and push:
```
make build push
```

Push image and push git changes:
```
make push git-commit git-push
```

Cleanup uncommited changes that were generated:
```
make clean
```

## Makefile

The following are some of the `make` targets are included:

- clean - cleans up any uncommitted `catalog-manifests/` changes and wipes `manifests/`
- manifests - generates the `manifests/` scripts
- catalog - updates the `catalog-manifests/` if there are any updates
- build - build the container image
- push - pushes the container image (after verifying operator's currentCSV images exist)
- git-commit - commits `catalog-manifests/`
- git-push - pushes current branch

The following variables (with defaults) are available for overriding by the user of `make`:

- CHANNEL - name of the catalog's channel (git branch)
- IMAGE_REGISTRY - target container registry (quay.io)
- IMAGE_REPOSITORY - target container repository ($USER)
- IMAGE_NAME - target image name ($OPERATOR_NAME)
- ALLOW_DIRTY_CHECKOUT - if a dirty local checkout is allowed (false)
- SKIP_GITREFRESH - if set, skip performing `git reset` and `git pull` on all operator source trees (false)

Note that `IMAGE_REPOSITORY` defaults to the current user's name.  The default behavior of `make build` and `make push` will therefore be to create images in the user's namespace.  Automation would override this to push to an organization like this:

```
IMAGE_REGISTRY=quay.io IMAGE_REPOSITORY=openshift-sre make build push git-commit git-push
```

For local testing you might want to build with dirty checkouts.  Keep in mind version is based on the number of commits and the latest git hash, so this is not desired for any officially published image and can cause issues for pulling latest images in some scenarios if tags (based on version) are reused.

```
ALLOW_DIRTY_CHECKOUT=true make build
```

# Releasing

Any time there's a new version of a bundled operator that needs release we must push an update of the catalog.  A few things to keep in mind when doing this:

- the catalog's channel is based on the local branch name
- the catalog's version is based on number of commits and git hash
- the CatalogSource yaml is updated for both of these and must be committed and pushed
- the catalog-manifests/ is updated and must be committed and pushed
- no source in the repo needs changed to cut a new release
- the default IMAGE_REPOSITORY is ${USER} and must be overriden
- the make target `isclean` will verify no local changes are uncommited

For this reason it is recommend a direct push to the target branch this:

```
IMAGE_REPOSITORY=openshift-sre make isclean build push git-commit git-push
```
