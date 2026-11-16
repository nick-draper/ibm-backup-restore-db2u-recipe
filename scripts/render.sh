#!/bin/bash
# Fill the manifest templates from .env and write them to build/.
#
# Why this exists:
#   The YAML files under templates/ hold ${NAME} placeholders for your
#   namespaces, instance name, license, storage class, environment label and
#   object-storage details. This writes filled copies to build/ at the same
#   path minus templates/, so templates/db2u-instance/db2u-instance.yaml
#   becomes build/db2u-instance/db2u-instance.yaml. You then apply those
#   with oc. It only writes local files: it never runs oc or contacts a cluster.
#
#   S3_CA_CERT is optional: the path, from the repository root, of the
#   object-storage endpoint's CA certificate (PEM). When set, its contents fill
#   ca-cert-secret.yaml; when empty, that file is skipped and the storage
#   location loses its privateCertificateName line.
#
#   ENV_LABEL_UPPER is not set in .env: it is ENV_LABEL in capitals, for the
#   restore target's display name.
#
#   Only the names below are replaced. ${GROUP...} in the recipes and ${ENV}
#   in the transform are Fusion's own variables and pass through unchanged.
#
# Usage (from the repository root):
#   cp .env.example .env      # once, then fill it in
#   ./scripts/render.sh [env-file]
#
# build/ holds your license and keys. It and .env are git-ignored.

set -euo pipefail
shopt -u patsub_replacement 2>/dev/null || true   # bash 5.2+: keep & literal in replacements

root=$(cd "$(dirname "$0")/.." && pwd)
cd "${root}"
env_file=${1:-.env}
out=build

NAMES="CLUSTER_DOMAIN FUSION_NS OP_NS SOURCE_NS TARGET_NS DB2_INSTANCE_NAME DB2_LICENSE STORAGE_CLASS ENV_LABEL S3_BUCKET_NAME S3_ENDPOINT S3_REGION S3_ACCESS_KEY_ID S3_ACCESS_KEY"
# Optional keys, read from .env but not required.
OPTIONAL="S3_CA_CERT"
# Values the templates hold inside single quotes; a ' in them is doubled for YAML.
QUOTED=" DB2_INSTANCE_NAME DB2_LICENSE ENV_LABEL ENV_LABEL_UPPER S3_ENDPOINT S3_ACCESS_KEY_ID S3_ACCESS_KEY "

fail() { echo "ERROR: $*" >&2; exit 1; }

[ -f "${env_file}" ] || fail "${env_file} not found. Copy .env.example to .env and fill it in."

# Read KEY=value lines without running the file as shell code.
while IFS= read -r line || [ -n "${line}" ]; do
  line=${line%$'\r'}
  case "${line}" in ''|'#'*) continue ;; esac
  [[ "${line}" == *=* ]] || fail "${env_file}: not KEY=value: ${line}"
  key=${line%%=*}; key=${key//[[:space:]]/}
  val=${line#*=}
  if [[ "${val}" =~ ^\"(.*)\"$ ]] || [[ "${val}" =~ ^\'(.*)\'$ ]]; then val=${BASH_REMATCH[1]}; fi
  case " ${NAMES} ${OPTIONAL} " in
    *" ${key} "*) printf -v "v_${key}" '%s' "${val}" ;;
    *) echo "WARN: ${env_file}: ${key} is not used by the templates" >&2 ;;
  esac
done < "${env_file}"

value() { local n="v_$1"; printf '%s' "${!n-}"; }

# Every value in NAMES is required; check the ones with a fixed shape.
dns='^[a-z0-9]([-a-z0-9]*[a-z0-9])?$'
missing=""
for n in ${NAMES}; do [ -n "$(value "${n}")" ] || missing="${missing} ${n}"; done
case "${missing}" in
  *S3_*) fail "set these in ${env_file}:${missing}
       The S3_ values come from step 1, object storage (docs/object-storage-setup.md)." ;;
  ?*) fail "set these in ${env_file}:${missing}" ;;
esac
v=$(value CLUSTER_DOMAIN)
[[ "${v}" =~ ^[a-z0-9]([-a-z0-9]*[a-z0-9])?(\.[a-z0-9]([-a-z0-9]*[a-z0-9])?)*$ ]] && [ ${#v} -le 253 ] || fail "CLUSTER_DOMAIN must be a DNS name (lowercase letters, digits, - and .), such as my.cluster"
for n in FUSION_NS OP_NS SOURCE_NS TARGET_NS; do
  v=$(value "${n}")
  [[ "${v}" =~ ${dns} ]] && [ ${#v} -le 63 ] || fail "${n} must be a valid namespace name (lowercase letters, digits, -)"
done
[[ "$(value DB2_INSTANCE_NAME)" =~ ${dns} ]] && [ ${#v_DB2_INSTANCE_NAME} -le 63 ] || fail "DB2_INSTANCE_NAME must be a valid resource name (lowercase letters, digits, -)"
[[ "$(value ENV_LABEL)" =~ ^[A-Za-z0-9]([-A-Za-z0-9_.]*[A-Za-z0-9])?$ ]] && [ ${#v_ENV_LABEL} -le 63 ] || fail "ENV_LABEL must be a valid label value"
[[ "$(value STORAGE_CLASS)" =~ ^[a-z0-9]([-a-z0-9.]*[a-z0-9])?$ ]] || fail "STORAGE_CLASS must be a valid storage class name"
[[ "$(value S3_BUCKET_NAME)" =~ ^[a-z0-9][-a-z0-9.]{1,61}[a-z0-9]$ ]] || fail "S3_BUCKET_NAME must be a valid bucket name"
[[ "$(value S3_REGION)" =~ ^[a-z0-9-]+$ ]] || fail "S3_REGION must be letters, digits and -"
[[ "$(value S3_ENDPOINT)" =~ ^https?://[^[:space:]]+$ ]] || fail "S3_ENDPOINT must be an http(s) URL"
[ "$(value SOURCE_NS)" != "$(value TARGET_NS)" ] || fail "SOURCE_NS and TARGET_NS must differ"
for n in ${NAMES}; do
  case "$(value "${n}")" in *$'\n'*) fail "${n} must be on one line" ;; esac
done

# Derived values: ENV_LABEL in capitals, for display names such as "(DEV)".
v_ENV_LABEL_UPPER=$(printf '%s' "$(value ENV_LABEL)" | tr '[:lower:]' '[:upper:]')

# The endpoint's CA certificate, if it has a private one.
ca_cert=$(value S3_CA_CERT)
cert_tpl=templates/ibm-backup-restore/backend-storage-location/ca-cert-secret.yaml
bsl_tpl=templates/ibm-backup-restore/backend-storage-location/backup-storage-location.yaml
if [ -n "${ca_cert}" ]; then
  [ -f "${ca_cert}" ] || fail "S3_CA_CERT: ${ca_cert} not found (the path is from the repository root). Save the endpoint's CA certificate there, or leave S3_CA_CERT empty for a publicly trusted endpoint."
  grep -q -- '-----BEGIN CERTIFICATE-----' "${ca_cert}" || fail "S3_CA_CERT: ${ca_cert} is not a PEM certificate (no BEGIN CERTIFICATE line)"
  v_S3_CA_CERT_DATA=$(base64 < "${ca_cert}" | tr -d '\n')
fi

# Write the filled copies. build/ holds secrets, so keep it private to you.
umask 077
rm -rf "${out}"
count=0
while IFS= read -r -d '' src; do
  if [ -z "${ca_cert}" ] && [ "${src}" = "${cert_tpl}" ]; then continue; fi
  content=$(cat "${src}"; printf x); content=${content%x}
  if [ -z "${ca_cert}" ] && [ "${src}" = "${bsl_tpl}" ]; then
    content=${content//$'\n'"  privateCertificateName: minio-registry-cert-secret"/}
  fi
  for n in ${NAMES} ENV_LABEL_UPPER S3_CA_CERT_DATA; do
    v=$(value "${n}")
    case "${QUOTED}" in *" ${n} "*) v=${v//\'/\'\'} ;; esac
    content=${content//"\${${n}}"/"${v}"}
  done
  dst="${out}/${src#templates/}"
  mkdir -p "$(dirname "${dst}")"
  printf '%s' "${content}" > "${dst}"
  count=$((count + 1))
done < <(find templates -name '*.yaml' -print0 | sort -z)

# Anything left in ${...} must be one of Fusion's own variables.
left=$(grep -rhoE '\$\{[A-Za-z_][A-Za-z0-9_.-]*\}' "${out}" | sort -u | grep -vE '^\$\{(GROUP\..*|ENV)\}$' || true)
[ -z "${left}" ] || fail "unfilled placeholders in ${out}/: ${left//$'\n'/ }"

# The names the commands in docs/deployment-guide.md use: source build/env.sh
{
  echo "# Written by scripts/render.sh from ${env_file}. Names only; no secrets."
  for n in CLUSTER_DOMAIN FUSION_NS OP_NS SOURCE_NS TARGET_NS STORAGE_CLASS ENV_LABEL; do printf 'export %s=%q\n' "${n}" "$(value "${n}")"; done
  printf 'export ENV_KEY=%q\n' "$(value CLUSTER_DOMAIN)/environment"
  printf 'export INSTANCE=%q\n' "$(value DB2_INSTANCE_NAME)"
} > "${out}/env.sh"

echo "Wrote ${count} manifests and env.sh to ${out}/ from ${env_file}."
if [ -n "${ca_cert}" ]; then
  echo "CA certificate: ${ca_cert} is in ${out}/${cert_tpl}."
else
  echo "CA certificate: none (S3_CA_CERT is empty); the storage location has no privateCertificateName."
fi
echo "Next: source ${out}/env.sh, then apply from ${out}/ as docs/deployment-guide.md describes."

# Git never turns a repository's hooks on by itself; say so if this clone's are off.
if git rev-parse --git-dir >/dev/null 2>&1 && [ "$(git config --get core.hooksPath || true)" != ".githooks" ]; then
  echo "WARN: the pre-commit check is off in this clone, so a filled-in template or your .env could be committed." >&2
  echo "      Turn it on once: git config core.hooksPath .githooks" >&2
fi
