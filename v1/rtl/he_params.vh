`ifndef HE_PARAMS_VH
`define HE_PARAMS_VH

// -----------------------------------------------------------------------------
// v1 parameters
// -----------------------------------------------------------------------------
// N=4096.
// q=65537 satisfies q = 1 mod 2N.
// primitive 2N-th root psi exists for negacyclic multiplication mod x^N + 1.


`define NTT_N              4096
`define NTT_LOG_N          12
`define ADDR_W             12
`define COEFF_W            17
`define MOD_Q              65537

// Primitive roots for q=65537, N=4096.
// generator g=3, psi = g^((q-1)/(2N)) = 6561
// omega = psi^2 = 54449
// inv_omega = omega^(-1) mod q = 3505
// inv_N = N^(-1) mod q = 65521
`define ROOT_PSI           6561
`define ROOT_OMEGA         54449
`define ROOT_INV_OMEGA     3505
`define INV_N              65521

// Barrett constants for mod_mul.
// product width is 2*COEFF_W = 34 bits. 
`define BARRETT_SHIFT      34
`define BARRETT_MU         262140

`endif
