#!/usr/bin/env bash
# vim: ft=bash

set -e

./docker_pull.sh home-assistant/odroid-n2-homeassistant 2021.11.0 ghcr.io
./docker_pull.sh library/ubuntu 16.04 registry-1.docker.io
./docker_pull.sh nvidia/cuda 11.4.2-cudnn8-runtime-ubuntu20.04


./layer_download_minimum.sh library/ubuntu 16.04 registry-1.docker.io 952132ac251a8df1f831b354a0b9a4cc7cd460b9c332ed664b4c205db6f22c29
