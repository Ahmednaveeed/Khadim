import soundfile as sf
import numpy as np

# 0.1 seconds of silence at 16kHz
silence = np.zeros(int(16000 * 0.1), dtype=np.float32)
sf.write("empty.wav", silence, 16000)
