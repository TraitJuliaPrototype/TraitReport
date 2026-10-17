# Row 10, pandas side: the report's work on a large file, best of 5 after a first call.
#     python scripts/row10.py <csv>
import sys, time, os
import numpy as np, pandas as pd, matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
path = sys.argv[1]
def work():
    df = pd.read_csv(path)
    t1 = time.perf_counter()
    s = [(c.mean(), c.std(), c.min(), c.max(), c.sum()) for _, c in df.items()]
    x = df.iloc[:, 0].to_numpy()
    counts, edges = np.histogram(x, bins=24)
    fig, ax = plt.subplots(figsize=(12, 8), dpi=100)
    ax.bar((edges[:-1] + edges[1:]) / 2, counts, width=edges[1] - edges[0])
    ax.axvline(x.mean(), color="red")
    fig.savefig("/tmp/claude-1000/row10_py.png"); plt.close(fig)
    return t1
for i in range(6):
    t0 = time.perf_counter(); t1 = work(); t2 = time.perf_counter()
    if i > 0: print(f"pandas: read {t1 - t0:.3f} s, summary and plot {t2 - t1:.3f} s, total {t2 - t0:.3f} s")
