import os
import torch
import librosa
from transformers import WhisperProcessor, WhisperForConditionalGeneration

MODEL_PATH = os.getenv("WHISPER_MODEL_PATH", r"D:\Final YEar Project\voice\whisper_urdu_final")

print("Loading Whisper model (safetensors)...")
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
print("Device =", device)
print("Whisper model path =", MODEL_PATH)

# Load processor
processor = WhisperProcessor.from_pretrained(
    MODEL_PATH,
    language="ur",
    task="transcribe"
)

# Load model (supports safetensors automatically)
model = WhisperForConditionalGeneration.from_pretrained(
    MODEL_PATH,
    torch_dtype=torch.float32,   # safe for CPU
    low_cpu_mem_usage=True
).to(device)

def transcribe_audio(audio_path: str) -> str:
    audio, sr = librosa.load(audio_path, sr=16000)

    inputs = processor(
        audio,
        sampling_rate=16000,
        return_tensors="pt"
    ).to(device)

    predicted_ids = model.generate(inputs.input_features)
    text = processor.batch_decode(
        predicted_ids,
        skip_special_tokens=True
    )[0]

    return text
