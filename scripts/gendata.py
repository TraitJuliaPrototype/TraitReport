# The report's second and third datasets, deterministic (a linear congruential generator, no
# dependencies). Writes data/sensors.csv (a second shape: a time column, three numeric columns
# with missing cells, a count with missing cells, a strings column) and data/items.csv (a strings
# column whose cells fit InlineStrings' String15, then numbers).
#
#     python3 scripts/gendata.py
import math, os
here = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "data")
state = [12345]
def rnd():
    state[0] = (1103515245 * state[0] + 12345) % 2**31
    return state[0] / 2**31
def normal():
    return math.sqrt(-2 * math.log(max(rnd(), 1e-12))) * math.cos(2 * math.pi * rnd())
TAGS = ["alpha", "beta", "gamma", "delta"]
with open(os.path.join(here, "sensors.csv"), "w") as f:
    f.write("t,s1,s2,s3,n,tag\n")
    for k in range(1, 501):
        cells = ["%.1f" % (0.1 * k)]
        for j in range(1, 4):
            cells.append("" if rnd() < 0.03 else "%.4f" % (normal() + j))
        cells.append("" if rnd() < 0.02 else str(int(rnd() * 20)))
        cells.append(TAGS[int(rnd() * 4)])
        f.write(",".join(cells) + "\n")
with open(os.path.join(here, "items.csv"), "w") as f:
    f.write("name,x,n\n")
    for i in range(1, 201):
        f.write("item%d,%s,%d\n" % (i, repr(0.5 * i), i))
