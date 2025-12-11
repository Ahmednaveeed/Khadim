# import os
# import random
# import pandas as pd
# import torch
# import soundfile as sf
# import librosa
# from tqdm import tqdm
# from transformers import WhisperForConditionalGeneration, WhisperProcessor
# import evaluate

# # ====== PATHS ======
# MODEL_PATH = "openai/whisper-small"
# TSV_FILE = r"D:\FAST\FYP\Khadim\voice\Data\final_main_dataset.tsv"
# AUDIO_DIR = r"D:\FAST\FYP\Khadim\voice\Data\limited_wav_files"

# # ====== LOAD MODEL + PROCESSOR ======
# device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
# print(f"Using device: {device}")

# model = WhisperForConditionalGeneration.from_pretrained(MODEL_PATH).to(device)
# processor = WhisperProcessor.from_pretrained(MODEL_PATH)

# # ====== LOAD TSV METADATA ======
# df = pd.read_csv(TSV_FILE, sep="\t")

# if "path" not in df.columns or "sentence" not in df.columns:
#     raise ValueError("TSV file must contain 'path' and 'sentence' columns!")

# # Build absolute .wav paths (replace .mp3 → .wav)
# df["full_path"] = df["path"].apply(
#     lambda x: os.path.join(AUDIO_DIR, os.path.basename(x).replace(".mp3", ".wav"))
# )

# # Keep only existing files
# df = df[df["full_path"].apply(os.path.exists)]
# print(f"Found {len(df)} valid audio-transcript pairs.")

# sample_df = df.sample(n=min(50, len(df)), random_state=42).reset_index(drop=True)

# # ====== METRIC ======
# wer_metric = evaluate.load("wer")

# pred_texts, ref_texts = [], []

# # ====== INFERENCE LOOP ======
# for i, row in sample_df.iterrows():
#     audio_path = row["full_path"]
#     reference = str(row["sentence"]).strip()

#     try:
#         # Load and resample to 16kHz if needed
#         audio, sr = sf.read(audio_path)
#         if sr != 16000:
#             audio = librosa.resample(audio, orig_sr=sr, target_sr=16000)

#         # Preprocess for Whisper
#         input_features = processor(audio, sampling_rate=16000, return_tensors="pt").input_features.to(device)

#         # Predict
#         with torch.no_grad():
#             predicted_ids = model.generate(input_features)

#         transcription = processor.batch_decode(predicted_ids, skip_special_tokens=True)[0].strip()

#         pred_texts.append(transcription)
#         ref_texts.append(reference)

#         print(f"\n{os.path.basename(audio_path)}")
#         print(f"Reference: {reference}")
#         print(f"Predicted: {transcription}")

#     except Exception as e:
#         print(f"Error processing {audio_path}: {e}")

# # ====== COMPUTE WER ======
# if pred_texts:
#     wer_score = wer_metric.compute(predictions=pred_texts, references=ref_texts)
#     print("\n=======================================")
#     print(f"Word Error Rate (WER): {wer_score:.4f}")
#     print("=======================================")
# else:
#     print("No successful transcriptions — please check file paths!")


import os
import random
import pandas as pd
import torch
import soundfile as sf
import librosa
from tqdm import tqdm
from transformers import WhisperForConditionalGeneration, WhisperProcessor
import evaluate

# ====== PATHS ======
MODEL_PATH = r"D:\FAST\FYP\Khadim\voice\whisper_urdu_final"
TSV_FILE = r"D:\FAST\FYP\Khadim\voice\Data\final_main_dataset.tsv"
AUDIO_DIR = r"D:\FAST\FYP\Khadim\voice\Data\limited_wav_files"

# ====== LOAD MODEL + PROCESSOR ======
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
print(f"Using device: {device}")

model = WhisperForConditionalGeneration.from_pretrained(MODEL_PATH).to(device)
processor = WhisperProcessor.from_pretrained(MODEL_PATH)

# ====== LOAD TSV METADATA ======
df = pd.read_csv(TSV_FILE, sep="\t")

if "path" not in df.columns or "sentence" not in df.columns:
    raise ValueError("TSV file must contain 'path' and 'sentence' columns!")

# Build absolute .wav paths (replace .mp3 → .wav)
df["full_path"] = df["path"].apply(
    lambda x: os.path.join(AUDIO_DIR, os.path.basename(x).replace(".mp3", ".wav"))
)

# Keep only existing files
df = df[df["full_path"].apply(os.path.exists)]
print(f"Found {len(df)} valid audio-transcript pairs.")

sample_df = df.sample(n=min(50, len(df)), random_state=42).reset_index(drop=True)

# ====== METRIC ======
wer_metric = evaluate.load("wer")

pred_texts, ref_texts = [], []

# ====== INFERENCE LOOP ======
for i, row in sample_df.iterrows():
    audio_path = row["full_path"]
    reference = str(row["sentence"]).strip()

    try:
        # Load and resample to 16kHz if needed
        audio, sr = sf.read(audio_path)
        if sr != 16000:
            audio = librosa.resample(audio, orig_sr=sr, target_sr=16000)

        # Preprocess for Whisper
        input_features = processor(audio, sampling_rate=16000, return_tensors="pt").input_features.to(device)

        # Predict
        with torch.no_grad():
            predicted_ids = model.generate(
                input_features,
                language="ur",
                task="transcribe"
            )

        transcription = processor.batch_decode(predicted_ids, skip_special_tokens=True)[0].strip()

        pred_texts.append(transcription)
        ref_texts.append(reference)

        print(f"\n{os.path.basename(audio_path)}")
        print(f"Reference: {reference}")
        print(f"Predicted: {transcription}")

    except Exception as e:
        print(f"Error processing {audio_path}: {e}")

# ====== COMPUTE WER ======
if pred_texts:
    wer_score = wer_metric.compute(predictions=pred_texts, references=ref_texts)
    print("\n=======================================")
    print(f"Word Error Rate (WER): {wer_score:.4f}")
    print("=======================================")
else:
    print("No successful transcriptions — please check file paths!")