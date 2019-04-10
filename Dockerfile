FROM quay.io/openshift/origin-operator-registry:v4.0

COPY catalog-manifests manifests
RUN initializer

CMD ["registry-server", "-t", "/tmp/terminate.log"]
