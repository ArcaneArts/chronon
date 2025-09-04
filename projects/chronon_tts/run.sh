#!/bin/bash

python3 -m venv kokoro-env
source kokoro-env/bin/activate
export PYTORCH_ENABLE_MPS_FALLBACK=1
python3 tts.py "$@"
deactivate