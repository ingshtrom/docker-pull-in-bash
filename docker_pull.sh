#!/usr/bin/env bash
# vim: ft=bash

sep=-----
image=${1:-library/alpine}
tag_or_sha=${2:-latest}
registry="${3:-registry-1.docker.io}"
auth_url=""
registry_service=""
is_sha=$(printf "%s" "$tag_or_sha" | grep 'sha256:' >/dev/null && echo true || echo false)

token=""

log_file="docker_pull_$(printf "%s" "$registry" | sed 's/\//-/')_$(echo "$image" | sed 's/\//-/')_$(echo "$tag_or_sha" | sed 's/\//-/').log"

function validate_necessary_input() {
  echo 'DEBUG: validate necessary input' | tee -a "$log_file"
  if [[ -z "$auth_url" ]] || [[ -z "$registry_service" ]]; then
    printf "auth_url (%s) or registry_service (%s) is empty, contact the developer" "$auth_url" "$registry_service" | tee -a "$log_file"
    exit 1
  fi
}

function get_bearer_and_service() {
  echo 'DEBUG: getting bearer token and service' | tee -a "$log_file"
  www_auth_header=$(curl -sSLIX GET "https://${registry}/v2/" | grep -i 'www-authenticate' | grep -o -e 'Bearer .*' | awk '{print substr($0,8)}')
  realm=$(printf "%s" "$www_auth_header" | awk '{split($0,a,","); gsub(/(realm=|")/, "", a[1]); print a[1]}')
  service=$(printf "%s" "$www_auth_header" | awk '{split($0,a,","); gsub(/(service=|")/, "", a[2]); print a[2]}')

  auth_url=$(printf "%s" "$realm" | tr -d '[:space:]')
  registry_service=$(printf "%s" "$service" | tr -d '[:space:]')
}

function prep_log_file() {
  echo 'DEBUG: prep log file' | tee -a "$log_file"
  rm "$log_file" >/dev/null 2>&1 || true
  touch "$log_file"
}

function log_tool_versions() {
  echo 'DEBUG: log tool versions' | tee -a "$log_file"
  printf "%s grep version %s" $sep $sep | tee "$log_file"
  grep --version | tee "$log_file"

  printf "%s jq version %s" $sep $sep | tee "$log_file"
  jq --version | tee "$log_file"

  echo "$sep sed version $sep" | tee "$log_file"
  sed --version | tee "$log_file"

  echo "$sep curl version $sep" | tee "$log_file"
  curl --version | tee "$log_file"

  echo
  echo

  echo "$sep is this a sha instead of a tag? $is_sha  $sep" | tee "$log_file"
  if [[ $is_sha == true ]]; then
    echo "$sep pulling image ${registry}/${image}@${tag_or_sha} $sep" | tee -a "$log_file"
  else
    echo "$sep pulling image ${registry}/${image}:${tag_or_sha} $sep" | tee -a "$log_file"
  fi
}

function get_token() {
  echo 'DEBUG: get token' | tee -a "$log_file"
  token=$(curl -sSL -G --data-urlencode "scope=repository:${image}:pull" "${auth_url}?&service=${registry_service}" | jq -r .token)
}

function get_final_digest() {
  echo 'DEBUG: get final digest' | tee -a "$log_file"
  # if you want to debug at this point
  # echo "curl -sSL --head 'https://${registry}/v2/${image}/manifests/${tag_or_sha}' -H 'Authorization: Bearer ${token}' -H 'Accept: application/vnd.oci.image.manifest.v1+json' -H 'Accept: application/vnd.docker.distribution.manifest.v2+json' -H 'Accept: Accept: application/vnd.docker.distribution.manifest.v1+prettyjws' -H 'Accept: application/json' -H 'Accept: application/vnd.docker.distribution.manifest.list.v2+json' -H 'Accept: Accept: application/vnd.oci.image.index.v1+json'"
  manifest=$(curl -sSL --head "https://${registry}/v2/${image}/manifests/${tag_or_sha}" -H "Authorization: Bearer ${token}" -H "Accept: application/vnd.oci.image.manifest.v1+json" -H "Accept: application/vnd.docker.distribution.manifest.v2+json" -H "Accept: Accept: application/vnd.docker.distribution.manifest.v1+prettyjws" -H "Accept: application/json" -H "Accept: application/vnd.docker.distribution.manifest.list.v2+json" -H "Accept: Accept: application/vnd.oci.image.index.v1+json")
  digest=$(printf "%s" "$manifest" | grep "docker-content-digest" | grep -o -e 'sha256:.*' | tr -d '[:space:]')

  if [[ "$?" != "0" ]]; then
    printf "could not parse the manifest: %s" "$manifest" | tee -a "$log_file"
    exit 1
  fi

  echo "$sep digest: $digest $sep" | tee -a "$log_file"

  # curl -vsSL "https://${registry}/v2/${image}/manifests/${digest}" -H "Authorization: Bearer ${token}" -H "Accept: application/vnd.oci.image.manifest.v1+json" -H "Accept: application/vnd.docker.distribution.manifest.v2+json" -H "Accept: Accept: application/vnd.docker.distribution.manifest.v1+prettyjws" -H "Accept: application/json" -H "Accept: application/vnd.docker.distribution.manifest.list.v2+json" -H "Accept: Accept: application/vnd.oci.image.index.v1+json"
  # exit 1

  final_manifest=$(curl -sSL "https://${registry}/v2/${image}/manifests/${digest}" -H "Authorization: Bearer ${token}" -H "Accept: application/vnd.oci.image.manifest.v1+json" -H "Accept: application/vnd.docker.distribution.manifest.v2+json" -H "Accept: Accept: application/vnd.docker.distribution.manifest.v1+prettyjws" -H "Accept: application/json" -H "Accept: application/vnd.docker.distribution.manifest.list.v2+json" -H "Accept: Accept: application/vnd.oci.image.index.v1+json")
  new_digest=$(printf "%s" "$final_manifest" | jq -r '.manifests[] | select(.platform.architecture == "amd64" and .platform.os == "linux") | .digest')
  if [[ "$?" == 0 ]]; then
    # we need to re-fetch the final manifest as the first was just a pointer to
    # manifests for each architecture
    echo "$sep new digest: $new_digest $sep" | tee -a "$log_file"
    final_manifest=$(curl -sSL "https://${registry}/v2/${image}/manifests/${new_digest}" -H "Authorization: Bearer ${token}" -H "Accept: application/vnd.oci.image.manifest.v1+json" -H "Accept: application/vnd.docker.distribution.manifest.v2+json" -H "Accept: Accept: application/vnd.docker.distribution.manifest.v1+prettyjws" -H "Accept: application/json" -H "Accept: application/vnd.docker.distribution.manifest.list.v2+json" -H "Accept: Accept: application/vnd.oci.image.index.v1+json")
  fi

  echo "$sep final manifest: $final_manifest $sep" | tee -a "$log_file"
}

function download_blobs() {
  echo 'DEBUG: download blobs' | tee -a "$log_file"
  for blob_digest in $(printf "%s" "$final_manifest" | jq -r '.layers[].digest'); do
    echo "$sep blob_digest: $blob_digest $sep" | tee -a "$log_file"
    curl -sSLkvo /dev/null "https://${registry}/v2/${image}/blobs/${blob_digest}" -H "Authorization: Bearer ${token}" -H "Connection: close" -H "Accept-Encoding: identity" -w 'DNS Lookup: %{time_namelookup}s\nConnect: %{time_connect}s\nStart Transfer: %{time_starttransfer}s\nTotal Time: %{time_total}s\n' 2>&1 | sed 's/Authorization: Bearer [A-Za-z0-9_\.-]*/Authorization: Bearer \<redacted\>/' | tee -a "$log_file"
  done
}

log_tool_versions
get_bearer_and_service
validate_necessary_input
get_token
get_final_digest
download_blobs
