# v1 — RAM-handshake NTT polynomial 

tb_v1.sv
 ├─ sync_ram_dp      // A polynomial RAM
 ├─ sync_ram_dp      // B polynomial RAM
 ├─ sync_ram_dp      // C/output RAM
 ├─ ntt_core         // forward / inverse NTT 수행
 ├─ poly_add_engine  // A+B mod q
 └─ pointwise_mul_engine // A[i]*B[i] mod q

ntt_core
 ├─ rd_addr0 / rd_en0 → RAM read port
 ├─ rd_addr1 / rd_en1 → RAM read port
 ├─ rd_data0 / rd_data1 ← RAM
 ├─ wr_addr0 / wr_en0 / wr_data0 → RAM
 └─ wr_addr1 / wr_en1 / wr_data1 → RAM


## Parameter

```text
N = 4096
q = 65537
coefficient width = 17 bits
address width = 12 bits
psi = 6561        // primitive 2N-th root of unity
omega = 54449     // psi^2, primitive N-th root of unity
```

`q = 65537` -> `q ≡ 1 mod 2N`
## 구현된 기능

```text
poly_add:
    c[i] = a[i] + b[i] mod q

forward negacyclic NTT:
    a[i] <- a[i] * psi^i
    DIF NTT using omega

inverse negacyclic NTT:
    DIT INTT using omega^-1
    a[i] <- a[i] * N^-1 * psi^-i

pointwise multiplication:
    c[i] = A[i] * B[i] mod q

polynomial multiplication:
    NTT(a), NTT(b), pointwise multiply, INTT(product)
```

```text
start -> busy -> RAM read/write 반복 -> done
```

RTL modules:

```text
rtl/he_params.vh
rtl/mod_add.v
rtl/mod_sub.v
rtl/mod_mul.v              // '%' 없는 Barrett reduction
rtl/sync_ram_dp.v          // synchronous dual-port RAM, req/valid handshake
rtl/table_rom.v            // table memory, req/valid handshake
rtl/ntt_core.v             // forward/inverse negacyclic NTT FSM
rtl/poly_add_engine.v
rtl/pointwise_mul_engine.v
```

Tables:

```text
table/twist_fwd.mem         // psi^i
table/twist_inv_scale.mem   // N^-1 * psi^-i
table/twiddle_fwd.mem       // forward DIF twiddles
table/twiddle_inv.mem       // inverse DIT twiddles
```

Testbench:

```text
tb/hardwired_vectors.svh
```

## Run

Ubuntu/WSL:

```bash
sudo apt update
sudo apt install make iverilog
```

Simulation:

```bash
make sim
```

Python golden model:

```bash
make golden
```


```bash
make tables
```

Regenerate expected vectors

```bash
make expected
```

Expected result:

```text
PASS: all v1 RAM/handshake NTT tests passed
```

## Notes on Algorithm

negacyclic convolution

```text
A = NTT_omega(a[i] * psi^i)
B = NTT_omega(b[i] * psi^i)
C[i] = A[i] * B[i] mod q
c = INTT_omega(C)
c[i] = c[i] * N^-1 * psi^-i mod q
```
