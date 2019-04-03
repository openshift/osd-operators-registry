FROM quay.io/openshift/origin-operator-registry:latest

COPY catalog-manifests manifests
RUN initializer

CMD ["registry-server", "-t", "/tmp/terminate.log"]
