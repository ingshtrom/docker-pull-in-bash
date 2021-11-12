#!/usr/bin/env bash
# vim: ft=bash


image=${1:-library/alpine}
tag=${2:-latest}
registry="${3:-registry-1.docker.io}"
auth_url=""
registry_service=""

token=""
final_digest=""

log_file="docker_pull_$(echo $registry | sed 's/\//-/')_$(echo $image | sed 's/\//-/')_$(echo $tag | sed 's/\//-/').log"

function validate_necessary_input() {
  if [[ -z "$auth_url" ]] || [[ -z "$registry_service" ]];
  then
    echo "auth_url (${auth_url}) or registry_service (${registry_service}) is empty, contact the developer" | tee -a $log_file
    exit 1
  fi
}

function get_bearer_and_service() {
  www_auth_header=$(curl -sSL -I -X GET "https://${registry}/v2/" | grep -i 'www-authenticate' | grep -o -e 'Bearer .*' | awk '{print substr($0,8)}')
  realm=$(echo $www_auth_header | awk '{split($0,a,","); gsub(/(realm=|")/, "", a[1]); print a[1]}')
  service=$(echo $www_auth_header | awk '{split($0,a,","); gsub(/(service=|")/, "", a[2]); print a[2]}')

  auth_url=$(echo $realm | tr -d '[:space:]')
  registry_service=$(echo $service | tr -d '[:space:]')
}

function prep_log_file() {
  rm $log_file 2>&1 > /dev/null || true
  touch $log_file
}

function log_tool_versions() {
  echo '--- grep version ------------------' | tee $log_file
  grep --version

  echo '--- jq version ------------------' | tee $log_file
  jq --version

  echo '--- sed version ------------------' | tee $log_file
  sed --version

  echo '--- curl version ------------------' | tee $log_file
  curl --version

  echo "--- pulling image ${registry}/${image}:${tag} ------------------" | tee -a $log_file
}

function get_token() {
  token=$(curl -sSL -G --data-urlencode "scope=repository:${image}:pull" "${auth_url}?&service=${registry_service}" | jq -r .token)
}

function get_final_digest() {
  digest=$(curl -sSL --head "https://${registry}/v2/${image}/manifests/${tag}" -H "Authorization: Bearer ${token}" -H "Accept: application/vnd.oci.image.manifest.v1+json" -H "Accept: application/vnd.docker.distribution.manifest.v2+json" -H "Accept: Accept: application/vnd.docker.distribution.manifest.v1+prettyjws" -H "Accept: application/json" -H "Accept: application/vnd.docker.distribution.manifest.list.v2+json" -H "Accept: Accept: application/vnd.oci.image.index.v1+json" | grep "docker-content-digest" | grep -o -e 'sha256:.*' | tr -d '[:space:]')

  echo "--- digest: $digest ------------------" | tee -a $log_file

  final_manifest=$(curl -sSL "https://${registry}/v2/${image}/manifests/${digest}" -H "Authorization: Bearer ${token}" -H "Accept: application/vnd.oci.image.manifest.v1+json" -H "Accept: application/vnd.docker.distribution.manifest.v2+json" -H "Accept: Accept: application/vnd.docker.distribution.manifest.v1+prettyjws" -H "Accept: application/json" -H "Accept: application/vnd.docker.distribution.manifest.list.v2+json" -H "Accept: Accept: application/vnd.oci.image.index.v1+json")
  new_digest=$(echo $final_manifest | jq -r '.manifests[] | select(.platform.architecture == "amd64") | .digest')
  if [[ "$?" == 0 ]]; then
    # we need to re-fetch the final manifest as the first was just a pointer to
    # manifests for each architecture
    echo "--- new digest: $new_digest ------------------" | tee -a $log_file
    final_manifest=$(curl -sSL "https://${registry}/v2/${image}/manifests/${new_digest}" -H "Authorization: Bearer ${token}" -H "Accept: application/vnd.oci.image.manifest.v1+json" -H "Accept: application/vnd.docker.distribution.manifest.v2+json" -H "Accept: Accept: application/vnd.docker.distribution.manifest.v1+prettyjws" -H "Accept: application/json" -H "Accept: application/vnd.docker.distribution.manifest.list.v2+json" -H "Accept: Accept: application/vnd.oci.image.index.v1+json" )
  fi

  echo "--- final manifest: $final_manifest ------------------" | tee -a $log_file
}

function download_blobs() {
  for blob_digest in $(echo $final_manifest | jq -r '.layers[].digest')
  do
    echo "--- blob_digest: $blob_digest ------------------" | tee -a $log_file
    curl -o /dev/null "https://${registry}/v2/${image}/blobs/${blob_digest}" -H "Authorization: Bearer ${token}" -H "Connection: close" -H "Accept-Encoding: identity" -w "content_type: %{content_type}\nhttp_code: %{http_code}\nhttp_connect: %{http_connect}\nhttp_version: %{http_version}\nnum_connects: %{num_connects}\nnum_redirects: %{num_redirects}\nproxy_ssl_verify_result: %{proxy_ssl_verify_result}\nredirect_url: %{redirect_url}\nremote_ip: %{remote_ip}\nscheme: %{scheme}\nsize_download: %{size_download}\nsize_header: %{size_header}\nsize_request: %{size_request}\nsize_upload: %{size_upload}\nspeed_download: %{speed_download}\nspeed_upload: %{speed_upload}\nssl_verify_result: %{ssl_verify_result}\ntime_appconnect: %{time_appconnect}\ntime_connect: %{time_connect}\ntime_namelookup: %{time_namelookup}\ntime_pretransfer: %{time_pretransfer}\ntime_redirect: %{time_redirect}\ntime_starttransfer: %{time_starttransfer}\ntime_total: %{time_total}\nurl_effective: %{url_effective}\n" -vsSL 2>&1 | sed 's/Authorization: Bearer [A-z0-9_\.-]*/Authorization: Bearer <redacted>/' | tee -a $log_file
  done
}

log_tool_versions
get_bearer_and_service
validate_necessary_input
get_token
get_final_digest
download_blobs

