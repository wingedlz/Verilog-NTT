# v3: Planned Ciphertext Arithmetic Layer

Planned later step.

The goal of `v3` is to build ciphertext-level operations on top of the polynomial engine:

- ciphertext addition: `(a0, a1) + (b0, b1)`
- raw ciphertext multiplication:

```text
c0 = a0*b0
c1 = a0*b1 + a1*b0
c2 = a1*b1
```

This version will intentionally stop before key switching/relinearization unless that becomes the next implementation target.
