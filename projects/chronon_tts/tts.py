from kokoro import KPipeline
import soundfile as sf
import numpy as np
import argparse

# Parse command-line arguments
parser = argparse.ArgumentParser(description="Generate TTS audio with Kokoro.")
parser.add_argument('--lang_code', default='a', help="Language code (e.g., 'a' for American English)")
parser.add_argument('--voice', default='af_heart', help="Voice name (e.g., 'af_heart')")
parser.add_argument('--speed', type=float, default=1.15, help="Speech speed (0.5-2.0)")
parser.add_argument('--output', default='output.wav', help="Target output WAV file path")
parser.add_argument('--text', required=True, help="Input text to synthesize (required)")
args = parser.parse_args()

# Initialize pipeline
pipeline = KPipeline(lang_code=args.lang_code)

# Generate audio segments
generator = pipeline(args.text, voice=args.voice, speed=args.speed)

# Collect all audio segments (numpy arrays)
audio_segments = []
for i, (graphemes, phonemes, audio) in enumerate(generator):
    audio_segments.append(audio)
    print(f"Processed segment {i}: {graphemes}")

# Concatenate into a single audio array if segments exist
if audio_segments:
    full_audio = np.concatenate(audio_segments)
    sf.write(args.output, full_audio, 24000)
    print(f"Saved combined audio to: {args.output}")
else:
    print("No audio generated.")