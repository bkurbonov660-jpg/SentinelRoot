import math, struct, wave, os
os.makedirs("assets", exist_ok=True)
sample_rate = 22050
duration_sec = 2.0
num_samples = int(sample_rate * duration_sec)
with wave.open("assets/alarm_siren.wav", "w") as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(sample_rate)
    frames = bytearray()
    for i in range(num_samples):
        t = i / sample_rate
        # Двухтональная тревожная сирена 880 Гц <-> 1480 Гц
        freq = 880.0 + 600.0 * (0.5 * (1.0 + math.sin(2.0 * math.pi * 2.0 * t)))
        sample = int(28000.0 * math.sin(2.0 * math.pi * freq * t))
        frames.extend(struct.pack('<h', max(-32767, min(32767, sample))))
    w.writeframes(bytes(frames))
