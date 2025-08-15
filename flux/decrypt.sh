#!/bin/bash

export SOPS_AGE_KEY_FILE="./.sops/ny-eevee-bot.agekey"
sops \
  --decrypt \
  --in-place \
  --ignore-mac \
  "${1}"
