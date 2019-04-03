# OSD Operators Registry

## Summary

This repository creates a `CatalogSource` that can be used by OLM to deploy OpenShift Dedicated operators.

# Building

NOTE the source for operators is checked out in a temp directory.
You can run out of disk space if not cleaned up.  Either use the `cleantemp` target or clean manually.

Build and push with cleanup:
```
make build push cleantemp
```

Clean manually:
```
rm -rf /tmp/**/
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
- cleantemp - cleans up temp directories created to checkout operator source
- manifests - generates the `manifests/` scripts
- catalog - updates the `catalog-manifests/` if there are any updates
- build - build the container image
- push - pushes the container image
- git-commit - commits `catalog-manifests/`
- git-push - pushes current branch

The following variables (with defaults) are available for overriding by the user of `make`:

- CHANNEL - name of the catalog's channel (git branch)
- IMAGE_REGISTRY - target container registry (quay.io)
- IMAGE_REPOSITORY - target container repository ($USER)
- IMAGE_NAME - target image name ($OPERATOR_NAME)
- ALLOW_DIRTY_CHECKOUT - if a dirty local checkout is allowed (false)

Note that `IMAGE_REPOSITORY` defaults to the current user's name.  The default behavior of `make build` and `make push` will therefore be to create images in the user's namespace.  Automation would override this to push to an organization like this:

```
IMAGE_REGISTRY=quay.io IMAGE_REPOSITORY=openshift-sre make build push git-commit git-push
```

For local testing you might want to build with dirty checkouts.  Keep in mind version is based on the number of commits and the latest git hash, so this is not desired for any officially published image and can cause issues for pulling latest images in some scenarios if tags (based on version) are reused.

```
ALLOW_DIRTY_CHECKOUT=true make build
```
