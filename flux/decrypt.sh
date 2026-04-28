#!/bin/bash

export SOPS_AGE_KEY_FILE="./.sops/flux.agekey"
sops \
  --decrypt \
  --in-place \
  --ignore-mac \
  "${1}"
