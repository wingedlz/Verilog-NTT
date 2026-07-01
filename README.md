# FHE NTT Accelerator

Toy Verilog/SystemVerilog repository for homomorphic-encryption hardware accelerator.

## Versions

| Version | Status | Goal |
|---|---:|---|
| `v1` | implemented | negacyclic NTT, INTT, pointwise multiplication, and polynomial addition. Includes Icarus Verilog testbench. |
| `v2` | planned | Replace the direct NTT with a staged butterfly/FSM architecture and explicit local memory. |
| `v3` | planned | Add ciphertext addition and ciphertext multiplication `(c0, c1) * (d0, d1) -> (e0, e1, e2)`. |
