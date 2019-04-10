SHELL := /usr/bin/env bash

# Include project specific values file
# Requires the following variables:
# - CATALOG_NAMESPACE
# - DOCKERFILE
# - CHANNEL
# - IMAGE_REGISTRY
# - IMAGE_REPOSITORY
# - IMAGE_NAME
# - VERSION_MAJOR
# - VERSION_MINOR
include project.mk
include checkout-operator.mk

# Validate variables in project.mk exist
ifndef CATALOG_NAMESPACE
$(error CATALOG_NAMESPACE is not set; check project.mk file)
endif
ifndef DOCKERFILE
$(error DOCKERFILE is not set; check project.mk file)
endif
ifndef CHANNEL
$(error CHANNEL is not set; check project.mk file)
endif
ifndef IMAGE_REGISTRY
$(error IMAGE_REGISTRY is not set; check project.mk file)
endif
ifndef IMAGE_REPOSITORY
$(error IMAGE_REPOSITORY is not set; check project.mk file)
endif
ifndef IMAGE_NAME
$(error IMAGE_NAME is not set; check project.mk file)
endif
ifndef VERSION_MAJOR
$(error VERSION_MAJOR is not set; check project.mk file)
endif
ifndef VERSION_MINOR
$(error VERSION_MINOR is not set; check project.mk file)
endif

# Generate version and tag information from inputs
COMMIT_NUMBER=$(shell git rev-list `git rev-list --parents HEAD | egrep "^[a-f0-9]{40}$$"`..HEAD --count)
BUILD_DATE=$(shell date -u +%Y-%m-%d)
CURRENT_COMMIT=$(shell git rev-parse --short=8 HEAD)
CATALOG_VERSION?=$(CHANNEL)-$(BUILD_DATE)-$(CURRENT_COMMIT)

ALLOW_DIRTY_CHECKOUT?=false
SOURCE_DIR := operators

# List of github.org repositories containing operators
# This is in the format username/reponame separated by space:  user1/repo1 user2/repo2 user3/repo3
OPERATORS := openshift/dedicated-admin-operator

.PHONY: default
default: build

.PHONY: clean
clean:
	# clean checked out operator source
	rm -rf $(SOURCE_DIR)/
	# clean generated catalog
	git clean -df catalog-manifests/
	# revert packages and manifests/
	git checkout catalog-manifests/**/*.package.yaml manifests/

.PHONY: isclean
.SILENT: isclean
isclean:
	(test "$(ALLOW_DIRTY_CHECKOUT)" != "false" || test 0 -eq $$(git status --porcelain | wc -l)) || (echo "Local git checkout is not clean, commit changes and try again." && exit 1)

# One big sed command instead of a function because OPERATOR_X vars 
# are provided by shell, not make vars, and hard (imposisble?) to
# pass as args to a function.  
SED_CMD=sed -e "s/\#IMAGE_REGISTRY\#/${IMAGE_REGISTRY}/g" \
			-e "s/\#IMAGE_REPOSITORY\#/${IMAGE_REPOSITORY}/g" \
			-e "s/\#IMAGE_NAME\#/${IMAGE_NAME}/g" \
			-e "s/\#CATALOG_NAMESPACE\#/${CATALOG_NAMESPACE}/g" \
			-e "s/\#CHANNEL\#/${CHANNEL}/g" \
			-e "s/\#CATALOG_VERSION\#/${CATALOG_VERSION}/g" \
			-e "s/\#CURRENT_COMMIT\#/${CURRENT_COMMIT}/g" \
			-e "s/\#OPERATOR_NAME\#/$${OPERATOR_NAME}/g" \
			-e "s/\#OPERATOR_NAMESPACE\#/$${OPERATOR_NAMESPACE}/g"

.PHONY: manifests/catalog
manifests/catalog:
	mkdir -p manifests/
	# create CatalogSource yaml
	TEMPLATE=scripts/templates/catalog.yaml; \
	DEST=manifests/00-catalog.yaml; \
	$(SED_CMD) $$TEMPLATE > $$DEST

# create yaml per operator
.PHONY: manifests/operators
manifests/operators: operator-source
	mkdir -p manifests/ ;\
	for DIR in $(SOURCE_DIR)/**/ ; do \
		eval $$($(MAKE) -C $$DIR env --no-print-directory); \
		TEMPLATE=scripts/templates/operator.yaml; \
		DEST=manifests/10-$${OPERATOR_NAME}.yaml; \
		$(SED_CMD) $$TEMPLATE > $$DEST; \
	done

.PHONY: manifests
manifests: manifests/catalog manifests/operators

.PHONY: operator-source
operator-source:
	for operator in $(OPERATORS); do \
		org="$$(echo $$operator | cut -d / -f 1)" ; \
		reponame="$$(echo $$operator | cut -d / -f 2-)" ; \
		echo "org = $$org reponame = $$reponame" ; \
		$(call checkout_operator,$$org,$$reponame) ;\
		echo ;\
	done

.PHONY: catalog
catalog: operator-source
	for DIR in $(SOURCE_DIR)/**/; do \
		eval $$($(MAKE) -C $$DIR env --no-print-directory); \
		./scripts/gen_operator_csv.py $$DIR $$OPERATOR_NAME $$OPERATOR_NAMESPACE $$OPERATOR_VERSION $(IMAGE_REGISTRY)/$(IMAGE_REPOSITORY)/$$OPERATOR_NAME:v$$OPERATOR_VERSION $(CHANNEL) || (echo "Failed to generate, cleaning up catalog-manifests/$$OPERATOR_NAME/$$OPERATOR_VERSION" && rm -rf catalog-manifests/$$OPERATOR_NAME/$$OPERATOR_VERSION && exit 3); \
	done

.PHONY: check-operator-images
check-operator-images: operator-source
	for DIR in $(SOURCE_DIR)/**/; do \
		eval $$($(MAKE) -C $$DIR env --no-print-directory); \
		docker pull $(IMAGE_REGISTRY)/$(IMAGE_REPOSITORY)/$$OPERATOR_NAME:v$$OPERATOR_VERSION || (echo "Image cannot be pulled: $(IMAGE_REGISTRY)/$(IMAGE_REPOSITORY)/$$OPERATOR_NAME:v$$OPERATOR_VERSION" && exit 1); \
	done

.PHONY: build
build: isclean operator-source manifests catalog build-only

.PHONY: build-only
build-only:
	docker build -f ${DOCKERFILE} --tag "${IMAGE_REGISTRY}/${IMAGE_REPOSITORY}/${IMAGE_NAME}:${CATALOG_VERSION}" .

.PHONY: push
push: check-operator-images
	docker push "${IMAGE_REGISTRY}/${IMAGE_REPOSITORY}/${IMAGE_NAME}:${CATALOG_VERSION}"

.PHONY: git-commit
git-commit:
	git add catalog-manifests/ manifests/
	git commit -m "New catalog: $(CATALOG_VERSION)" --author="OpenShift SRE <aos-sre@redhat.com>"

.PHONY: git-push
git-push:
	git push

.PHONY: version
version:
	@echo $(CATALOG_VERSION)
