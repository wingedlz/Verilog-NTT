# Coding Labeling Rules

---

## 1. General File and Directory Name

### File Name === Module Name

```text
rtl/<module_name>.v
module <module_name> (...);
```

example:

```verilog
// rtl/ntt_core.v
module ntt_core (...);
```


---

## 2. Verilog/SystemVerilog Name

### 2.1 Module Names

Module names: **lower_snake_case**.

```verilog
module mod_add (...);
module mod_sub (...);
```

Functional processing blocks: `*_engine` suffix

```text
poly_add_engine
pointwise_mul_engine
```

Testbenches: `tb_<target>` 

```verilog
module tb_v1;
```

---

### 2.2 Instance Names

Module instances: `u_` prefix

```text
u_<role>
u_<block>_<role>
```

example:

```verilog
mod_add u_fwd_add (...);
mod_sub u_fwd_sub (...);
```



---

### 2.3 Parameters, Localparams, Macros

Constant-like values, Header macros: **UPPER_SNAKE_CASE**.

```verilog
parameter COEFF_W = `COEFF_W;
parameter ADDR_W  = `ADDR_W;

`define NTT_N         4096
`define NTT_LOG_N     12
```

#### Width Constants

Bit-width constants: `_W` suffix.

```text
ADDR_W
COEFF_W
DATA_W
```

#### FSM States

FSM states: `S_` prefix + `UPPER_SNAKE_CASE`.

```verilog
localparam [4:0] S_IDLE     = 5'd0;
localparam [4:0] S_TW_REQ   = 5'd1;
localparam [4:0] S_TW_WAIT  = 5'd2;
localparam [4:0] S_TW_WRITE = 5'd3;
localparam [4:0] S_BF_REQ   = 5'd4;
localparam [4:0] S_BF_WAIT  = 5'd5;
localparam [4:0] S_BF_WRITE = 5'd6;
localparam [4:0] S_DONE     = 5'd7;
```

#### Owner and Memory ID Constants

Classification ID prefixes:

```verilog
OWNER_HOST
OWNER_NTT
OWNER_ADD
OWNER_PMUL

RAM_A
RAM_B
RAM_C
RAM_SUM
```

---

### 2.4 Basic Port and Signal Rules

General signals, registers, wires, ports: **lower_snake_case**.

```verilog
clk
rst
start
busy
done
```

---

### 2.5 Handshake, Control Suffixes

Suffixes used in RAM, ROM, and engine interfaces:

| Suffix | Meaning | Examples |
|---|---|---|
| `_req` | Request | `ram0_req`, `a_req`, `twiddle_fwd_req` |
| `_we` | Write enable | `ram0_we`, `a_we`, `host_a_we` |
| `_addr` | Address | `ram0_addr`, `a_addr`, `twist_addr` |
| `_wdata` | Write data | `ram0_wdata`, `c_wdata` |
| `_rdata` | Read data | `ram0_rdata`, `a_rdata` |
| `_valid` | Read/response valid | `ram0_valid`, `twist_fwd_valid` |
| `_start` | Engine start | `ntt_start`, `add_start`, `pmul_start` |
| `_busy` | Engine busy | `ntt_busy`, `add_busy`, `pmul_busy` |
| `_done` | Engine done pulse | `ntt_done`, `add_done`, `pmul_done` |

Recommended interface order:

```text
<block>_req
<block>_we
<block>_addr
<block>_wdata
<block>_rdata
<block>_valid
```

---

### 2.6 RAM, ROM, and Bus Prefixes

#### Single-Role Ports

Modules that access A/B/C RAMs use prefixes a, b, c.

```text
a_req, a_we, a_addr, a_wdata, a_rdata, a_valid
b_req, b_we, b_addr, b_wdata, b_rdata, b_valid
c_req, c_we, c_addr, c_wdata, c_rdata, c_valid
```

#### Dual-Port RAM

Inside `sync_ram_dp`, use ports a,b as suffixes.

```text
req_a, we_a, addr_a, wdata_a, rdata_a, valid_a
req_b, we_b, addr_b, wdata_b, rdata_b, valid_b
```

#### NTT Core RAM Ports

In `ntt_core`, dual ports are distinguished using numeric suffixes.

```text
ram0_req, ram0_we, ram0_addr, ram0_wdata, ram0_rdata, ram0_valid
ram1_req, ram1_we, ram1_addr, ram1_wdata, ram1_rdata, ram1_valid
```

#### Testbench Mux Signals

In the testbench, the RAM name and port number are combined.

```text
ram_a_req0, ram_a_we0, ram_a_addr0, ram_a_wdata0, ram_a_rdata0, ram_a_valid0
ram_a_req1, ram_a_we1, ram_a_addr1, ram_a_wdata1, ram_a_rdata1, ram_a_valid1
```

Recommended standard:

- `_a` and `_b` for physical dual-port RAM pins
- `0` and `1` for operation-core port indexes

---

### 2.7 Functional Prefixes

Since multiple blocks share the same RAM buses, prefixes are used to distinguish the source block.

| Prefix | Meaning | Examples |
|---|---|---|
| `host_` | Testbench host access | `host_a_req`, `host_sum_wdata` |
| `ntt_` | NTT core interface | `ntt_start`, `ntt_addr0`, `ntt_valid1` |
| `add_` | Polynomial add engine | `add_start`, `add_a_req`, `add_c_wdata` |
| `pmul_` | Pointwise multiply engine | `pmul_start`, `pmul_a_req`, `pmul_c_wdata` |
| `ram_` | RAM-side mux/interface | `ram_a_req0`, `ram_sum_valid1` |
| `twist_` | Twist table | `twist_fwd_req`, `twist_inv_data` |
| `twiddle_` | Twiddle table | `twiddle_fwd_req`, `twiddle_inv_valid` |
| `fwd_` | Forward NTT datapath | `fwd_sum`, `fwd_diff`, `fwd_prod` |
| `inv_` | Inverse NTT datapath | `inv_v_tw`, `inv_sum`, `inv_diff` |

---

### 2.8 Register and Intermediate Calculation Suffixes

Intermediate values stored in clocked registers: `_reg` suffix.

```verilog
u_reg
v_reg
```

values with extended width : `_full` or `_wide` suffix.

```verilog
bf_addr0_full
bf_addr1_full
tw_addr_full
r0_wide
```

---

### 2.9 Testbench Task Names

Tasks use **lower_snake_case**. Begin with a verb.

```text
<verb>_<object>
<verb>_<object>_<detail>
```

Example:

```verilog
task clear_host_controls;
task set_ram_owner;
task load_inputs;
task check_mul_ram;
```


---

## 3. Abbreviation Rules


| Abbreviation | Meaning | Examples |
|---|---|---|
| `ntt` | Number Theoretic Transform | `ntt_core`, `ntt_start` |
| `intt` or `inv` | Inverse transform | `negacyclic_intt`, `twiddle_inv` |
| `fwd` | Forward | `twist_fwd`, `fwd_sum` |
| `inv` | Inverse | `inv_sum`, `INV_N` |
| `pmul` | Pointwise multiplication | `OWNER_PMUL`, `pmul_start` |
| `addr` | Address | `ram0_addr` |
| `wdata` | Write data | `c_wdata` |
| `rdata` | Read data | `a_rdata` |
| `req` | Request | `table_req`, `ram0_req` |
| `we` | Write enable | `host_a_we` |
| `tb` | Testbench | `tb_v1.sv`, `TB` |
| `bf` | Butterfly | `S_BF_REQ`, `bf_addr0_full` |
| `tw` | Twiddle | `tw_reg`, `tw_addr_full` |


- Keep existing project abbreviations unchanged.
- When adding a new abbreviation, document here.


---

# Verilog Header Guide

Recommended location:

```text
rtl/include/<header_name>.vh
```

Examples:

```text
rtl/include/ntt_params.vh
rtl/include/ram_ids.vh
rtl/include/owner_ids.vh
rtl/include/project_defs.vh
```

- include guard.
- Macros use UPPER_SNAKE_CASE.
- Prefer using header macros as **default parameter values**, while keeping module parameters overrideable.
- Headers should contain only compile-time definitions.

examples:

```verilog
`define NTT_N       4096
`define NTT_LOG_N   12
`define COEFF_W     32
`define ADDR_W      12
```

```verilog
`define OWNER_HOST  0
`define OWNER_NTT   1
`define OWNER_ADD   2
`define OWNER_PMUL  3
```

```verilog
`define RAM_A       0
`define RAM_B       1
`define RAM_C       2
`define RAM_SUM     3
```

example:

```verilog
`include "ntt_params.vh"

module ntt_core #(
    parameter integer N       = `NTT_N,
    parameter integer LOG_N   = `NTT_LOG_N,
    parameter integer COEFF_W = `COEFF_W,
    parameter integer ADDR_W  = `ADDR_W
)(
    input  wire clk,
    input  wire rst
);
```



## Header Include Path

The RTL include directory must be passed to simulation and synthesis tools.

Example directory structure:

```text
project/
├── rtl/
│   ├── include/
│   │   ├── ntt_params.vh
│   │   ├── owner_ids.vh
│   │   └── ram_ids.vh
│   ├── ntt_core.v
│   ├── mod_add.v
│   └── mod_sub.v
└── tb/
    └── tb_v1.sv
```


---



---

# `` `timescale`` and `` `default_nettype``

Do not mix project parameters with compiler behavior settings.

