#!/bin/bash
# Note: Optimizes shared memory for multi-node LLM training.
pip install "ray[default]"
ray start --head --port=6379 --object-manager-port=8076
