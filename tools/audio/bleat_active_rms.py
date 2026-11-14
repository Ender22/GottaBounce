import sys, numpy as np
from scipy.io import wavfile
sr, x = wavfile.read(sys.argv[1]); x = x.astype(np.float64) / 32768.0; h = int(0.02 * sr)
fr = np.array([np.sqrt(np.mean(x[i:i + h] ** 2)) for i in range(0, len(x) - h, h)])
fr = fr[fr > 10 ** (-40 / 20)]
print(round(20 * np.log10(np.sqrt(np.mean(fr ** 2))), 2))
