#!/usr/bin/env python3
from pathlib import Path

N = 4096
Q = 65537
G = 3
PSI = pow(G, (Q - 1) // (2 * N), Q)
OMEGA = pow(PSI, 2, Q)
INV_OMEGA = pow(OMEGA, -1, Q)
INV_N = pow(N, -1, Q)
INV_PSI = pow(PSI, -1, Q)


def make_vectors():
    a = [((5 * i * i + 17 * i + 123) % Q) for i in range(N)]
    b = [((7 * i * i + 29 * i + 456) % Q) for i in range(N)]
    return a, b


def fwd_dif_cyclic(a):
    a = a[:]
    m = N
    while m >= 2:
        half = m // 2
        step = N // m
        for base in range(0, N, m):
            for j in range(half):
                w = pow(OMEGA, j * step, Q)
                u = a[base + j]
                v = a[base + j + half]
                a[base + j] = (u + v) % Q
                a[base + j + half] = ((u - v) * w) % Q
        m //= 2
    return a


def inv_dit_cyclic(a):
    a = a[:]
    m = 2
    while m <= N:
        half = m // 2
        step = N // m
        for base in range(0, N, m):
            for j in range(half):
                w = pow(INV_OMEGA, j * step, Q)
                u = a[base + j]
                v = (a[base + j + half] * w) % Q
                a[base + j] = (u + v) % Q
                a[base + j + half] = (u - v) % Q
        m *= 2
    return [(x * INV_N) % Q for x in a]


def negacyclic_ntt(a):
    return fwd_dif_cyclic([(x * pow(PSI, i, Q)) % Q for i, x in enumerate(a)])


def negacyclic_intt(a):
    x = inv_dit_cyclic(a)
    return [(v * pow(INV_PSI, i, Q)) % Q for i, v in enumerate(x)]


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


def main():
    a, b = make_vectors()
    A = negacyclic_ntt(a)
    recovered = negacyclic_intt(A)
    assert recovered == a, "INTT(NTT(a)) failed"

    B = negacyclic_ntt(b)
    C = [(x * y) % Q for x, y in zip(A, B)]
    ntt_mul = negacyclic_intt(C)
    direct_mul = direct_negacyclic_mul(a, b)
    assert ntt_mul == direct_mul, "NTT multiply != direct negacyclic multiply"

    print("PASS: Python golden model")
    print(f"N={N}, q={Q}, psi={PSI}, omega={OMEGA}")
    print("a[0:8]      =", a[:8])
    print("b[0:8]      =", b[:8])
    print("add[0:8]    =", [((x + y) % Q) for x, y in zip(a[:8], b[:8])])
    print("mul[0:8]    =", direct_mul[:8])


if __name__ == "__main__":
    main()
