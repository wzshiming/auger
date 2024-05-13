#!/usr/bin/env bash
# Copyright 2024 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -o errexit
set -o nounset
set -o pipefail

DIR="$(dirname "${BASH_SOURCE[0]}")"
ROOT_DIR="$(realpath "${DIR}/..")"
REPO=https://github.com/kubernetes/api

function clone_or_checkout() {
  local version=$1
  local dest=$2

  if [[ -d "${dest}" ]]; then
    echo "Checking out ${REPO}#${version} to ${dest}"
    pushd "${dest}"
    git fetch origin
    git checkout "${version}"
    popd
  else
    echo "Cloning ${REPO}#${version} to ${dest}"
    git clone --branch "${version}" --depth 1 "${REPO}" "${dest}"
  fi
}

function find_package() {
  local dir=$1
  find "${dir}" | grep register.go | sed "s#/register.go##g" | sed "s#${dir}/##g" || :
}

apiset=()

function append_api() {
    local api=$1
    if [[ ! " ${apiset[@]} " =~ " ${api} " ]]; then
        apiset+=("${api}")
        return 0
    fi
    return 1
}

function clone_api() {
  local release=$1
  local skip=$2
  version="release-1.${release}"
  version_dir="${ROOT_DIR}/_tmp/k8s-api/${version}"
  clone_or_checkout "${version}" "${version_dir}"
  for api in $(find_package "${version_dir}"); do
    if append_api "${api}" ; then
      if [[ "${release}" -eq "${skip}" ]]; then
        continue
      fi
      dir_api="${ROOT_DIR}/pkg/old/apis/${api}"
      echo "Copying ${version_dir}/${api}/*.go to ${dir_api}"
      mkdir -p "${dir_api}"
      cp "${version_dir}/${api}"/*.go "${dir_api}"
      echo "# k8s.io/api/${api}

Copying from ${REPO}/tree/${version}/${api}

Generated by ./hack/clone_old_apis.sh" > "${dir_api}/README.md"
    fi
  done
}

last_release=${1}

# 1.8 incompatible
# 1.9 ~ 1.17 no removed APIs
first_release=18

for release in $(seq "${last_release}" -1 "${first_release}"); do
  clone_api "${release}" "${last_release}"
done
