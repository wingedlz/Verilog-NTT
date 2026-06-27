# FHE NTT Accelerator

Toy Verilog/SystemVerilog repository for homomorphic-encryption hardware accelerator.

## Versions

| Version | Status | Goal |
|---|---:|---|
| `v1` | implemented | Minimal polynomial arithmetic engine: negacyclic NTT, INTT, pointwise multiplication, and polynomial addition. Includes an Icarus Verilog testbench. |
| `v2` | planned | Replace the correctness-first direct NTT with a staged butterfly/FSM architecture and explicit local memory. |
| `v3` | planned | Add ciphertext-level operations: ciphertext addition and unrelinearized ciphertext multiplication `(c0, c1) * (d0, d1) -> (e0, e1, e2)`. |
