#!/bin/bash

# This script installs the latest version of the nvidia driver packages.
# If the latest version of nvidia-compute-utils-G06 fails to install,
# then fallsback to a version that is known to work.

source /etc/os-release

export FALLBACK_DRIVER_VERSION_SLES="${FALLBACK_DRIVER_VERSION_SLES:-'575.57.08'}"
export FALLBACK_DRIVER_VERSION_SLE_MICRO="${FALLBACK_DRIVER_VERSION_SLE_MICRO:-'570.133.20'}"

SUCCESS_MARKER="/var/log/nvidia_driver_install_success.log"

if [[ "$ID" == "sles" ]]; then
  export PACKAGE_NAME="nv-prefer-signed-open-driver"
  export FALLBACK_DRIVER_VERSION=$FALLBACK_DRIVER_VERSION_SLES
else
  export PACKAGE_NAME="nvidia-open-driver-G06-signed-cuda-kmp-default"
  export FALLBACK_DRIVER_VERSION=$FALLBACK_DRIVER_VERSION_SLE_MICRO
fi

zypper in -y --auto-agree-with-licenses $PACKAGE_NAME
latest_version=$(rpm -qa --queryformat '%{VERSION}\n' $PACKAGE_NAME | cut -d "_" -f1 | sort -u | tail -n 1)

# for validation purpose
zypper ar --refresh -G https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo
zypper in -y --auto-agree-with-licenses nvidia-container-toolkit

# Attempt to install nvidia-compute-utils-G06=$latest_version using zypper
zypper in -y --auto-agree-with-licenses nvidia-compute-utils-G06=$latest_version

# Check the status of the nvidia-compute-utils-G06 package latest version install

if [ $? -ne 0 ]; then
  echo "zypper install failed! Retry with a version known to work"
  
  # uninstall
  zypper remove -y $PACKAGE_NAME

  echo "Trying with ${FALLBACK_DRIVER_VERSION}"
  zypper in -y --auto-agree-with-licenses $PACKAGE_NAME="${FALLBACK_DRIVER_VERSION}"
  zypper in -y --auto-agree-with-licenses nvidia-compute-utils-G06="${FALLBACK_DRIVER_VERSION}"
  # Check if fallback succeeded
  if [ $? -eq 0 ]; then
      echo "SUCCESS: ${FALLBACK_DRIVER_VERSION}" > "$SUCCESS_MARKER"
      echo "Wrote success marker to $SUCCESS_MARKER"
  else
      echo "Fallback install failed!"
  fi
  echo ${FALLBACK_DRIVER_VERSION}
else
  echo "zypper install succeeded."
  echo "SUCCESS: ${latest_version}" > "$SUCCESS_MARKER"
  echo $latest_version
fi

