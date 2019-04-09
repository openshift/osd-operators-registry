#!/bin/bash

set -exv

# build the registry image
REGISTRY_IMG="quay.io/openshift-sre/osd-operators"
DOCKERFILE_REGISTRY="./Dockerfile"
CHANNEL="production"
GIT_SHA=`git rev-parse HEAD | cut -c1-8`

cat <<EOF > $DOCKERFILE_REGISTRY
FROM quay.io/openshift/origin-operator-registry:latest

COPY operators manifests
RUN initializer

CMD ["registry-server", "-t", "/tmp/terminate.log"]
EOF

docker build -f $DOCKERFILE_REGISTRY --tag "${REGISTRY_IMG}:${CHANNEL}-${GIT_SHA}" .
docker push "${REGISTRY_IMG}:${CHANNEL}-${GIT_SHA}"

sed "s/#SHA#/${GIT_SHA}/g" templates/template_osd-operators.CatalogSource.yaml > manifests/00_osd-operators.CatalogSource.yaml



