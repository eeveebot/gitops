#!/bin/bash

sops \
  --encrypt \
  --in-place \
  "${1}"
