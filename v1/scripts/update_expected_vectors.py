#!/usr/bin/env python3
from pathlib import Path
import re

N = 4096
Q = 65537
COEFF_W = 17
ROOT = Path(__file__).resolve().parents[1]
VEC_FILE = ROOT / "tb" / "hardwired_vectors.svh"

ASSIGN_RE = re.compile(r"^(a_init|b_init)\[(\d+)\]\s*=\s*\d+'d(\d+)\s*;")


def parse_vectors(path: Path):
    a = [0] * N
    b = [0] * N
    for line in path.read_text().splitlines():
        m = ASSIGN_RE.match(line.strip())
        if not m:
            continue
        name, idx_s, val_s = m.groups()
        idx = int(idx_s)
        val = int(val_s) % Q
        if 0 <= idx < N:
            if name == "a_init":
                a[idx] = val
            else:
                b[idx] = val
    return a, b


def direct_negacyclic_mul(a, b):
    c = [0] * N
    for i, ai in enumerate(a):
        for j, bj in enumerate(b):
            p = (ai * bj) % Q
            k = i + j
            if k >= N:
                c[k - N] -= p
            else:
                c[k] += p
        if (i & 127) == 0:
            c = [x % Q for x in c]
    return [x % Q for x in c]


def write_vectors(path: Path, a, b):
    add = [(x + y) % Q for x, y in zip(a, b)]
    mul = direct_negacyclic_mul(a, b)
    with path.open("w") as f:
        f.write("// Auto-generated/updated by scripts/update_expected_vectors.py.\n")
        f.write("// You may edit a_init[] and b_init[] directly, then run `make expected`.\n")
        f.write("// exp_add[] and exp_mul[] are golden references for the testbench.\n\n")
        for name, vec in [("a_init", a), ("b_init", b), ("exp_add", add), ("exp_mul", mul)]:
            f.write(f"// {name}\n")
            for i, v in enumerate(vec):
                f.write(f"{name}[{i}] = {COEFF_W}'d{v};\n")
            f.write("\n")


def main():
    a, b = parse_vectors(VEC_FILE)
    write_vectors(VEC_FILE, a, b)
    print(f"Updated expected vectors in {VEC_FILE.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
