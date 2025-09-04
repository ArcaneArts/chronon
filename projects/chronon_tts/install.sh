#!/bin/bash

brew install espeak-ng ffmpeg
python3 -m venv kokoro-env
source kokoro-env/bin/activate
pip3 install "kokoro>=0.9.2" soundfile torch numpy
export PYTORCH_ENABLE_MPS_FALLBACK=1
deactivate