#!/bin/bash
# Inventory an instance namespace before you publish or change include-lists.
#
# Why this exists:
#   This pack backs up an allow-list (includedResourceTypes), not a denylist.
#   That is safer, but only if you have checked the namespace for resource
#   types the recipe does not yet include. Run this against a real instance
#   namespace and compare the output to the child recipe groups.
#
# Requires the kubectl/oc get-resources plugin:
#   https://github.com/Sandeep-Prajapati/kubectl-get-resources
# Background:
#   https://community.ibm.com/community/user/blogs/sandeep-prajapati/2026/01/11/making-kubernetes-or-openshift-backup-and-restore
#
# Usage (from the repository root):
#   ./scripts/discover-instance-resources.sh <DB2U_INSTANCE_NAMESPACE>

set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Inventory namespace-scoped resources for recipe include-list review."
  echo "Usage: $0 <DB2U_INSTANCE_NAMESPACE>"
  exit 1
fi

NS=$1

if ! oc get-resources --help >/dev/null 2>&1; then
  echo "oc get-resources is not installed."
  echo "Install: https://github.com/Sandeep-Prajapati/kubectl-get-resources"
  exit 1
fi

echo "Namespace-scoped resources in ${NS} (cluster-scoped excluded):"
oc get-resources --namespace "${NS}" --exclude-cluster-resources=true

# The allow-list, read from the child recipe so it never goes stale: each
# group's name and type, and the resource types a resource group includes.
recipe="$(cd "$(dirname "$0")/.." && pwd)/templates/ibm-backup-restore/recipe/child-recipe.yaml"
echo
echo "Compare the kinds above with the child recipe's groups (${recipe#"$(pwd)/"}):"
awk '
  /^  groups:/                { in_groups = 1; next }
  in_groups && /^  [a-z]/     { exit }
  in_groups && /^    - name:/ { name = $3 }
  in_groups && /^      type:/ { printf "  %-20s %s%s\n", name, $2, ($2 == "volume" ? ": every PVC in the namespace" : ":"); next }
  in_groups && /^        - /  { print "    " $2 }
' "${recipe}"
