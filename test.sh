#!/usr/bin/env bash
# vim: ft=bash

set -e

./docker_pull.sh home-assistant/odroid-n2-homeassistant 2021.11.0 ghcr.io
./docker_pull.sh library/ubuntu 16.04 registry-1.docker.io
./docker_pull.sh nvidia/cuda 11.4.2-cudnn8-runtime-ubuntu20.04
