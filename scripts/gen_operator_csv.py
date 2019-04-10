#!/usr/bin/env python
#
# Generate an operator bundle for publishing to OLM. Copies appropriate files
# into a directory, and composes the ClusterServiceVersion which needs bits and
# pieces of our rbac and deployment files.
#

import datetime
import os
import sys
import yaml
import shutil
import subprocess

if __name__ == '__main__':

    if len(sys.argv) != 7:
        print("USAGE: %s OPERATOR_DIR OPERATOR_NAME OPERATOR_NAMESPACE OPERATOR_VERSION OPERATOR_IMAGE CHANNEL_NAME" % sys.argv[0])
        sys.exit(1)

    operator_dir = sys.argv[1]
    operator_name = sys.argv[2]
    operator_namespace = sys.argv[3]
    operator_version = sys.argv[4]
    operator_image = sys.argv[5]
    channel_name = sys.argv[6]

    catalog_dir = os.path.join("catalog-manifests", operator_name)
    opeartor_assets_dir = os.path.join(operator_dir, "manifests")

    if not os.path.exists(catalog_dir):
        os.mkdir(catalog_dir)

    # fail if there is a bundle for the target version already
    version_dir = os.path.join(catalog_dir, operator_version)
    if os.path.exists(version_dir):
        print >> sys.stderr, "INFO version already exists, skipping: {}".format(version_dir)
        sys.exit(0)

    # doesn't exist, create the target version
    os.mkdir(version_dir)

    # update operator package
    package_filename = operator_name + ".package.yaml"
    package_file = os.path.join(catalog_dir, package_filename)
    prev_csv = "__undefined__"
    if os.path.isfile(package_file):
        with open(package_file) as stream:
            yaml_file = yaml.safe_load_all(stream)
            for obj in yaml_file:
                prev_csv = obj['channels'][0]['currentCSV']

    # create package content
    package = {}
    package['packageName'] = operator_name
    package['channels'] = []
    package['channels'].append({'currentCSV': "%s.v%s" % (operator_name, operator_version), 'name': channel_name})

    with open(package_file, 'w') as outfile:
        yaml.dump(package, outfile, default_flow_style=False)

    print("Wrote Package: %s" % package_file)

    print("Generating CSV for version: %s" % operator_version)

    with open('scripts/templates/csv.yaml', 'r') as stream:
        csv = yaml.safe_load(stream)

    # set templated values
    csv['metadata']['name'] = operator_name
    csv['metadata']['namespace'] = operator_namespace
    csv['metadata']['containerImage'] = operator_image
    csv['spec']['displayName'] = operator_name
    csv['spec']['description'] = "SRE operator - " + operator_name
    csv['spec']['version'] = operator_version

    csv['spec']['install']['spec']['clusterPermissions'] = []

    SA_NAME = operator_name
    clusterrole_names_csv = []

    for subdir, dirs, files in os.walk(opeartor_assets_dir):
        for file in files:
            file_path = subdir + os.sep + file

            # Parse each file and look for ClusterRoleBindings to the SA
            with open(file_path) as stream:
                yaml_file = yaml.safe_load_all(stream)
                for obj in yaml_file:
                    if obj['kind'] == 'ClusterRoleBinding':
                        for subject in obj['subjects']:
                            if subject['kind'] == 'ServiceAccount' and subject['name'] == SA_NAME:
                                clusterrole_names_csv.append(obj['roleRef']['name'])

    csv['spec']['install']['spec']['deployments'] = []
    csv['spec']['install']['spec']['deployments'].append({'spec':{}})

    for subdir, dirs, files in os.walk(opeartor_assets_dir):
        for file in files:
            file_path = subdir + os.sep + file
            # Parse files to manage clusterPermissions and deployments in csv
            with open(file_path) as stream:
                yaml_file = yaml.safe_load_all(stream)
                for obj in yaml_file:
                    if obj['kind'] == 'ClusterRole' and any(obj['metadata']['name'] in cr for cr in clusterrole_names_csv):
                        print('Adding ClusterRole to CSV: {}'.format(file_path))
                        csv['spec']['install']['spec']['clusterPermissions'].append(
                        {
                            'rules': obj['rules'],
                            'serviceAccountName': SA_NAME,
                        })
                    if obj['kind'] == 'Deployment' and obj['metadata']['name'] == operator_name:
                        print('Adding Deployment to CSV: {}'.format(file_path))
                        csv['spec']['install']['spec']['deployments'][0]['spec'] = obj['spec']
                        csv['spec']['install']['spec']['deployments'][0]['name'] = operator_name
                    if obj['kind'] == 'ClusterRole' or obj['kind'] == 'Role' or obj['kind'] == 'RoleBinding' or obj['kind'] == 'ClusterRoleBinding':
                        if obj['kind'] in ('RoleBinding', 'ClusterRoleBinding'):
                            try:
                                print(obj['roleRef']['kind'])
                            except KeyError:
                                # require a well formed roleRef, olm doesn't check this until deployed and InstallPlan fails
                                print >> sys.stderr, "ERROR {} '{}' is missing .roleRef.kind in file {}".format(obj['kind'], obj['metadata']['name'], file_path)
                                sys.exit(1)

                        print('Adding {} to Catalog: {}'.format(obj['kind'], file_path))
                        shutil.copyfile(file_path, os.path.join(version_dir, file.lower()))

    # Update the deployment to use the defined image:
    csv['spec']['install']['spec']['deployments'][0]['spec']['template']['spec']['containers'][0]['image'] = operator_image

    # Update the versions to include git hash:
    csv['metadata']['name'] = "%s.v%s" % (operator_name, operator_version)
    csv['spec']['version'] = operator_version
    if prev_csv != "__undefined__":
        csv['spec']['replaces'] = prev_csv

    # Set the CSV createdAt annotation:
    now = datetime.datetime.now()
    csv['metadata']['annotations']['createdAt'] = now.strftime("%Y-%m-%dT%H:%M:%SZ")

    # Write the CSV to disk:
    csv_filename = "%s.v%s.clusterserviceversion.yaml" % (operator_name, operator_version)
    csv_file = os.path.join(version_dir, csv_filename)
    with open(csv_file, 'w') as outfile:
        yaml.dump(csv, outfile, default_flow_style=False)
    print("Wrote ClusterServiceVersion: %s" % csv_file)
