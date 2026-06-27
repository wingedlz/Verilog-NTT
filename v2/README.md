# v2: Planned Staged NTT Accelerator

Planned next step.

The goal of `v2` is to replace the direct matrix-style transform in `v1` with a more hardware-like architecture:

- butterfly unit
- twiddle ROM
- staged NTT/INTT schedule
- explicit coefficient memory
- start/done control FSM
- reusable datapath for forward NTT and inverse NTT

No RTL is implemented here yet.
