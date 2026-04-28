#!/bin/bash

export SOPS_AGE_KEY_FILE="./.sops/flux.agekey"
sops \
  --encrypt \
  --in-place \
  "${1}"
