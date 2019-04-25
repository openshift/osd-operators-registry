SHELL := /usr/bin/env bash

# Include project specific values file
# Requires the following variables:
# - CATALOG_NAMESPACE
# - DOCKERFILE
# - CHANNEL
# - IMAGE_REGISTRY
# - IMAGE_REPOSITORY
# - IMAGE_NAME
include project.mk
include functions.mk

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

# Generate version and tag information
CATALOG_HASH=$(shell find catalog-manifests/ -type f -exec openssl md5 {} \; | sort | openssl md5 | cut -d ' ' -f2)
CATALOG_VERSION=$(CHANNEL)-$(CATALOG_HASH)
GIT_TAG=release-$(CATALOG_VERSION)

ALLOW_DIRTY_CHECKOUT?=false
SOURCE_DIR := operators

MANIFESTDIR := ./manifests
# List of github.org repositories containing operators
# This is in the format username/reponame separated by space:  user1/repo1 user2/repo2 user3/repo3
OPERATORS := openshift/dedicated-admin-operator openshift/configure-alertmanager-operator

# What variables should be reset at the top of various loops? These are the
# ones typically from `make env` that are evalled. 
# Reset with $(call reset_vars)
RESET_VARS := CREATE_OPERATOR_GROUP OPERATOR_NAME OPERATOR_VERSION OPERATOR_NAMESPACE OPERATOR_IMAGE_URI

.PHONY: default
default: build

.PHONY: clean
clean:
	# clean checked out operator source
	rm -rf $(SOURCE_DIR)/
	# clean generated catalog
	git clean -df catalog-manifests/ manifests/
	# revert packages and manifests/
	git checkout catalog-manifests/**/*.package.yaml manifests/

.PHONY: isclean
.SILENT: isclean
isclean:
	(test "$(ALLOW_DIRTY_CHECKOUT)" != "false" || test 0 -eq $$(git status --porcelain | wc -l)) || (echo "Local git checkout is not clean, commit changes and try again." && exit 1)

.PHONY: manifestdir
.SILENT: manifestdir
manifestdir:
	mkdir -p $(MANIFESTDIR)/hive

# create CatalogSource yaml
.PHONY: manifests/catalog
manifests/catalog: manifestdir catalog
	@$(call process_template,.,scripts/templates/catalog.yaml,manifests/00-catalog.yaml)
	@$(call process_template,.,scripts/templates/catalog.selectorsyncset.yaml,manifests/hive/01-catalog.selectorsyncset.yaml)

# create yaml per operator
.PHONY: manifests/operators
manifests/operators: manifestdir catalog
	@for operatorrepo in $(OPERATORS) ; do \
		$(call reset_vars) ;\
		reponame="$$(echo $$operatorrepo | cut -d / -f 2-)" ; \
		$(call process_template,$(SOURCE_DIR)/$$reponame,scripts/templates/operator.yaml,manifests/10-$${reponame}.yaml); \
		$(call process_template,$(SOURCE_DIR)/$$reponame,scripts/templates/operator.selectorsyncset.yaml,manifests/hive/20-$${reponame}.selectorsyncset.yaml); \
		eval $$($(MAKE) -C $(SOURCE_DIR)/$$reponame env --no-print-directory); \
		if [[ "$$(echo x$${CREATE_OPERATOR_GROUP} | tr [:upper:] [:lower:])" != "xfalse" ]]; then \
			$(call process_template,$(SOURCE_DIR)/$$reponame,scripts/templates/operatorgroup.yaml,manifests/15-$${reponame}.yaml); \
		fi ;\
	done

.PHONY: manifests
manifests: manifestdir manifests/catalog manifests/operators

.PHONY: operator-source
operator-source:
	@for operator in $(OPERATORS); do \
		org="$$(echo $$operator | cut -d / -f 1)" ; \
		reponame="$$(echo $$operator | cut -d / -f 2-)" ; \
		echo "org = $$org reponame = $$reponame" ; \
		$(call checkout_operator,$$org,$$reponame) ;\
		echo ;\
	done

.PHONY: catalog
catalog: manifestdir operator-source
	@for operatorrepo in $(OPERATORS); do \
		$(call reset_vars) ;\
		operator="$$(echo $$operatorrepo | cut -d / -f2)" ;\
		echo "Building catalog for $$operator in $(SOURCE_DIR)/$$operator" ;\
		eval $$($(MAKE) -C $(SOURCE_DIR)/$$operator env --no-print-directory); \
		if [[ -z "$${OPERATOR_NAME}" || -z "$${OPERATOR_NAMESPACE}" || -z "$${OPERATOR_VERSION}" || -z "$${OPERATOR_IMAGE_URI}" ]]; then \
			echo "Couldn't determine OPERATOR_NAME, OPERATOR_NAMESPACE, OPERATOR_VERSION or OPERATOR_IMAGE_URI from $(SOURCE_DIR)/$$operator. make env output follows" ; \
			$(MAKE) -C $(SOURCE_DIR)/$$operator env ; \
			exit 3 ;\
		else \
			./scripts/gen_operator_csv.py $(SOURCE_DIR)/$$operator $$OPERATOR_NAME $$OPERATOR_NAMESPACE $$OPERATOR_VERSION $$OPERATOR_IMAGE_URI $(CHANNEL) 1>/dev/null ;\
			if [[ $$? -ne 0 ]]; then \
				echo "Failed to generate, cleaning up catalog-manifests/$$OPERATOR_NAME/$$OPERATOR_VERSION" ;\
				rm -rf catalog-manifests/$$OPERATOR_NAME/$$OPERATOR_VERSION ;\
				exit 3; \
			fi ;\
		fi ; \
	done

.PHONY: check-operator-images
check-operator-images: operator-source
	@for operator in $(OPERATORS); do \
		$(call reset_vars) ;\
		org="$$(echo $$operator | cut -d / -f 1)" ; \
		reponame="$$(echo $$operator | cut -d / -f 2-)" ; \
		eval $$($(MAKE) -C $(SOURCE_DIR)/$$reponame env --no-print-directory); \
		if [[ -z "$${OPERATOR_NAME}" || -z "$${OPERATOR_NAMESPACE}" || -z "$${OPERATOR_VERSION}" || -z "$${OPERATOR_IMAGE_URI}" ]]; then \
			echo "Couldn't determine OPERATOR_NAME, OPERATOR_NAMESPACE, OPERATOR_VERSION or OPERATOR_IMAGE_URI from $(SOURCE_DIR)/$$operator. make env output follows" ; \
			$(MAKE) -C $(SOURCE_DIR)/$$operator env ; \
			exit 3 ;\
		else \
			docker pull $$OPERATOR_IMAGE_URI ;\
			if [[ $$? -ne 0 ]]; then \
				echo "Image cannot be pulled: $$OPERATOR_IMAGE_URI" ;\
				exit 1 ; \
			fi ;\
		fi ;\
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

.PHONY: git-tag
.SILENT: git-tag
git-tag:
	# attempt to tag, do not recreate a tag (only happens if changes happen outside of catalog-manifests/)
	git tag $(GIT_TAG) 2> /dev/null && echo "INFO: created tag: $(GIT_TAG)" || echo "INFO: git tag already exists, skipping tag creation: $(GIT_TAG)"

.PHONY: git-push
git-push: git-tag
	REMOTE=$(shell git status -sb | grep ^# | sed 's#.*[.]\([^./]*\)/[^./]*$$#\1#g'); \
	git push && git push $$REMOTE $(GIT_TAG)

.PHONY: version
version:
	@echo $(CATALOG_VERSION)

.PHONY: env
.SILENT: env
env:
	echo
