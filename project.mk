# Project specific values
CATALOG_NAMESPACE?=openshift-operator-lifecycle-manager
DOCKERFILE?=./Dockerfile
CHANNEL?=$(shell git rev-parse --abbrev-ref HEAD 2>&1)

# Image specific values
IMAGE_REGISTRY?=quay.io
IMAGE_REPOSITORY?=$(USER)
IMAGE_NAME?=osd-operators-registry

# Version specific values
VERSION_MAJOR?=0
VERSION_MINOR?=1
