# To generate/deploy a catalog image

```console
$ scripts/build_image_catalog.sh
$ oc apply -f manifests/00_osd-operators.CatalogSource.yaml
$ oc apply -f manifests/01_dedicated-admin-operator.Subscription.yaml
```