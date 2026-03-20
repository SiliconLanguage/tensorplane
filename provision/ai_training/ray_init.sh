#!/bin/bash
# Note: Ray clusters require pinning shared memory (/dev/shm) for high-speed
# tensor movement during distributed training.
pip install "ray[default]"
ray start --head --port=6379 --dashboard-host=0.0.0.0
