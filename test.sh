#!/usr/bin/env bash
# vim: ft=bash

set -e

./docker_pull.sh home-assistant/odroid-n2-homeassistant 2021.11.0 ghcr.io
./docker_pull.sh library/ubuntu 16.04 registry-1.docker.io
./docker_pull.sh nvidia/cuda 11.4.2-cudnn8-runtime-ubuntu20.04
./docker_pull.sh library/ubuntu sha256:635f0aa53d99017b38d1a0aa5b2082f7812b03e3cdb299103fe77b5c8a07f1d2 registry-1.docker.io


./layer_download_minimum.sh library/ubuntu 16.04 registry-1.docker.io 952132ac251a8df1f831b354a0b9a4cc7cd460b9c332ed664b4c205db6f22c29
