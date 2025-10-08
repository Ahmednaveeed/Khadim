from datasets import load_from_disk
from transformers import WhisperForConditionalGeneration, WhisperProcessor, Seq2SeqTrainer, Seq2SeqTrainingArguments
import evaluate
import torch

# -----------------------------
# Config
# -----------------------------
MODEL_NAME = "openai/whisper-small"
DATASET_PATH = r"C:\Users\zaina\OneDrive\Desktop\Khadim-Whisper\urdu_dataset_prepared"

MAX_LABEL_LENGTH = 448  # max decoder tokens for Whisper-small

# -----------------------------
# Device setup
# -----------------------------
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
print(f"Using device: {device}")
if device.type == "cuda":
    print(f"GPU: {torch.cuda.get_device_name(0)}")

# -----------------------------
# Load processor and dataset
# -----------------------------
processor = WhisperProcessor.from_pretrained(MODEL_NAME, language="ur", task="transcribe")
dataset = load_from_disk(DATASET_PATH)

# Truncate labels to max length
def truncate_labels(batch):
    labels = batch["labels"]
    if len(labels) > MAX_LABEL_LENGTH:
        labels = labels[:MAX_LABEL_LENGTH]
    batch["labels"] = labels
    return batch

dataset = dataset.map(truncate_labels)

# -----------------------------
# Load model
# -----------------------------
model = WhisperForConditionalGeneration.from_pretrained(MODEL_NAME).to(device)
model.config.forced_decoder_ids = None
model.config.suppress_tokens = []
model.config.max_length = MAX_LABEL_LENGTH  # ensure generation respects max length

# -----------------------------
# Metric
# -----------------------------
metric = evaluate.load("wer")

def compute_metrics(pred):
    pred_ids = pred.predictions
    label_ids = pred.label_ids
    pred_str = processor.batch_decode(pred_ids, skip_special_tokens=True)
    label_str = processor.batch_decode(label_ids, skip_special_tokens=True)
    return {"wer": metric.compute(predictions=pred_str, references=label_str)}

# -----------------------------
# Custom collator
# -----------------------------
def collate_fn(batch):
    input_features = [example["input_features"] for example in batch]
    labels = [example["labels"] for example in batch]

    # Pad input features
    batch_input = processor.feature_extractor.pad(
        {"input_features": input_features}, return_tensors="pt"
    )
    # Pad labels
    batch_labels = processor.tokenizer.pad(
        {"input_ids": labels}, return_tensors="pt"
    )["input_ids"]

    batch_input["labels"] = batch_labels
    return batch_input

# -----------------------------
# Training arguments
# -----------------------------
training_args = Seq2SeqTrainingArguments(
    output_dir="whisper_urdu_finetuned",
    eval_strategy="epoch",
    learning_rate=1e-5,
    per_device_train_batch_size=4,
    per_device_eval_batch_size=4,
    num_train_epochs=2,
    fp16=torch.cuda.is_available(),  # enable fp16 only if GPU is available
    logging_dir="logs",
    save_total_limit=2,
    predict_with_generate=True,
    remove_unused_columns=False  # important for custom collator
)

# -----------------------------
# Trainer
# -----------------------------
trainer = Seq2SeqTrainer(
    model=model,
    args=training_args,
    train_dataset=dataset["train"],
    eval_dataset=dataset["test"],
    data_collator=collate_fn,
    tokenizer=processor.feature_extractor,
    compute_metrics=compute_metrics,
)

# -----------------------------
# Start training
# -----------------------------
trainer.train()
