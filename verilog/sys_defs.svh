/////////////////////////////////////////////////////////////////////////
//                                                                     //
//   Modulename :  sys_defs.svh                                        //
//                                                                     //
//  Description :  This file defines macros and data structures used   //
//                 throughout the processor.                           //
//                                                                     //
/////////////////////////////////////////////////////////////////////////

`ifndef __SYS_DEFS_SVH__
`define __SYS_DEFS_SVH__

// all files should `include "sys_defs.svh" to at least define the timescale
`timescale 1ns/100ps

///////////////////////////////////
// ---- Starting Parameters ---- //
///////////////////////////////////

// some starting parameters that you should set
// this is *your* processor, you decide these values (try analyzing which is best!)

// superscalar width
`define N 3
`define LOGN $clog2(`N)
`define N_CNT_WIDTH $clog2(`N+1)
`define CDB_SZ `N // This MUST match your superscalar width
`define FU_ROB_PACKET_SZ `NUM_FU_ALU + `N

// sizes
`define ROB_SZ 24
`define RS_SZ 16
`define RS_CNT_WIDTH $clog2(`RS_SZ + 1)
`define PHYS_REG_SZ_P6 32
`define PHYS_REG_SZ_R10K (32 + `ROB_SZ)
`define ARCH_REG_SZ 32
`define PRN_WIDTH $clog2(`PHYS_REG_SZ_R10K)
`define FREE_LIST_CTR_WIDTH $clog2(`PHYS_REG_SZ_R10K+1)
`define FREE_LIST_PTR_WIDTH $clog2(`PHYS_REG_SZ_R10K)

`define ROB_CNT_WIDTH $clog2(`ROB_SZ + 1)
`define ROB_PTR_WIDTH $clog2(`ROB_SZ)

// worry about these later
`define BRANCH_PRED_SZ 4
// `define LSQ_SZ 8

// functional units (you should decide if you want more or fewer types of FUs)
`define NUM_FU_ALU 4
`define NUM_FU_MULT 2
`define NUM_FU_LOAD 3
`define NUM_FU_STORE 2

// `define LOAD_Q_INDEX_WIDTH $clog2(`NUM_FU_LOAD)
// `define STORE_Q_INDEX_WIDTH $clog2(`NUM_FU_STORE)

// number of mult stages (2, 4) (you likely don't need 8)
`define MULT_STAGES 2

// cache
`define ICACHE_LINES 32
`define ICACHE_SETS 4

`define ICACHE_WAYS `ICACHE_LINES / `ICACHE_SETS
`define ILRU_WIDTH $clog2(`ICACHE_WAYS)
`define ICACHE_INDEX_BITS $clog2(`ICACHE_SETS)
`define ICACHE_BLOCK_OFFSET_BITS 3
`define ICACHE_TAG_BITS 32-`ICACHE_BLOCK_OFFSET_BITS-`ICACHE_INDEX_BITS

// `define CACHE_LINE_BITS $clog2(`CACHE_LINES)

`define MAX_PREFETCH_LINE 4

// lsq
`define NUM_SQ_DCACHE `N // cannot change to other value
`define SQ_LEN  2 * `N
`define SQ_IDX_BITS $clog2(`SQ_LEN + 2)

`define NUM_LU_DCACHE `N // cannot change to other value
`define LU_IDX_BITS $clog2(`NUM_FU_LOAD + 1)

// dcache
`define DCACHE_LINES 64 // pw of 2
`define DCACHE_SETS 16  // pw of 2

`define DCACHE_WAYS  `DCACHE_LINES / `DCACHE_SETS
`define LRU_WIDTH $clog2(`DCACHE_WAYS)

`define DCACHE_INDEX_BITS $clog2(`DCACHE_SETS)
`define DCACHE_BLOCK_OFFSET_BITS 2
`define DCACHE_TAG_BITS 32-`DCACHE_BLOCK_OFFSET_BITS-`DCACHE_INDEX_BITS
`define DMSHR_SIZE 4

// local history table
`define BHT_WIDTH 8
`define BHT_SIZE  16
`define BHT_IDX_WIDTH $clog2(`BHT_SIZE)

`define GSHARE_PC_WIDTH 5
`define GSHARE_HS_WIDTH 4
`define GSHARE_PHT_SIZE 2 ** `GSHARE_PC_WIDTH

// BTB
`define BTB_SIZE 32
`define BTB_INDEX_BITS $clog2(`BTB_SIZE)
`define BTB_TAG_BITS 32-2-`BTB_INDEX_BITS

// pattern history table
`define PHT_SIZE 2**`BHT_WIDTH

`define RAS_SIZE 16
`define RAS_CTR_WIDTH $clog2(`RAS_SIZE+1)
`define RAS_PTR_WIDTH $clog2(`RAS_SIZE)

///////////////////////////////
// ---- Basic Constants ---- //
///////////////////////////////

// NOTE: the global CLOCK_PERIOD is defined in the Makefile

// useful boolean single-bit definitions
`define FALSE 1'h0
`define TRUE  1'h1

// word and register sizes
typedef logic [31:0] ADDR;
typedef logic [31:0] DATA;
typedef logic [4:0] REG_IDX;

typedef logic [`PRN_WIDTH-1:0]         PRN;
typedef logic [`ROB_CNT_WIDTH-1:0]     ROBN;

typedef logic [`SQ_IDX_BITS-1:0] SQ_IDX;

typedef logic [`LU_IDX_BITS-1:0] LU_IDX;

typedef logic [`RAS_PTR_WIDTH  :0] RAS_CTR;
typedef logic [`RAS_PTR_WIDTH-1:0] RAS_PTR;

// the zero register
// In RISC-V, any read of this register returns zero and any writes are thrown away
`define ZERO_REG 5'd0

// Basic NOP instruction. Allows pipline registers to clearly be reset with
// an instruction that does nothing instead of Zero which is really an ADDI x0, x0, 0
`define NOP 32'h00000013

//////////////////////////////////
// ---- Memory Definitions ---- //
//////////////////////////////////

// Cache mode removes the byte-level interface from memory, so it always returns
// a double word. The original processor won't work with this defined. Your new
// processor will have to account for this effect on mem.
// Notably, you can no longer write data without first reading.
// `define CACHE_MODE

// you are not allowed to change this definition for your final processor
// the project 3 processor has a massive boost in performance just from having no mem latency
// see if you can beat it's CPI in project 4 even with a 100ns latency!
// `define MEM_LATENCY_IN_CYCLES  0
`define MEM_LATENCY_IN_CYCLES (100.0/`CLOCK_PERIOD+0.49999)
// the 0.49999 is to force ceiling(100/period). The default behavior for
// float to integer conversion is rounding to nearest

// memory tags represent a unique id for outstanding mem transactions
// 0 is a sentinel value and is not a valid tag
`define NUM_MEM_TAGS 15
typedef logic [3:0] MEM_TAG;

`define MEM_SIZE_IN_BYTES (64*1024)
`define MEM_64BIT_LINES   (`MEM_SIZE_IN_BYTES/8)

// A memory or cache block
typedef union packed {
    logic [7:0][7:0]  byte_level;
    logic [3:0][15:0] half_level;
    logic [1:0][31:0] word_level;
    logic      [63:0] dbbl_level;
} MEM_BLOCK; // If change mem_block to other size, be aware cache needs to change

typedef union packed {
    logic [3:0][7:0]  byte_level;
    logic [1:0][15:0] half_level;
    logic      [31:0] word_level;
} DCACHE_BLOCK;

typedef enum logic [1:0] {
    BYTE   = 2'h0,
    HALF   = 2'h1,
    WORD   = 2'h2,
    DOUBLE = 2'h3
} MEM_SIZE;

// Memory bus commands
typedef enum logic [1:0] {
    MEM_NONE   = 2'h0,
    MEM_LOAD   = 2'h1,
    MEM_STORE  = 2'h2
} MEM_COMMAND;

typedef enum logic {
    INST_LOAD   = 1'h0,
    INST_STORE  = 1'h1
} INST_COMMAND;

typedef enum logic [2:0] {
    MEM_BYTE  = 3'h0,
    MEM_HALF  = 3'h1,
    MEM_WORD  = 3'h2,
    MEM_BYTEU = 3'h4,
    MEM_HALFU = 3'h5
} MEM_FUNC;

typedef enum logic [1:0] {
    IMSHR_INVALID   = 2'h0,
    IMSHR_PENDING   = 2'h1, // not sent request
    IMSHR_WAIT_TAG  = 2'h2,
    IMSHR_WAIT_DATA = 2'h3
} IMSHR_STATE;

typedef enum logic [1:0] {
    DMSHR_INVALID   = 2'h0,
    DMSHR_PENDING   = 2'h1, // not sent request
    DMSHR_WAIT_TAG  = 2'h2,
    DMSHR_WAIT_DATA = 2'h3
} DMSHR_STATE;

// pattern history state
typedef enum logic {
    NOT_TAKEN = 1'h0,
    TAKEN     = 1'h1
} PHT_ENTRY_STATE;

typedef struct packed {
    logic                     valid;
    ADDR                      PC;
    logic [`BTB_TAG_BITS-1:0] tag;
} BTB_ENTRY;

///////////////////////////////
// ---- Exception Codes ---- //
///////////////////////////////

/**
 * Exception codes for when something goes wrong in the processor.
 * Note that we use HALTED_ON_WFI to signify the end of computation.
 * It's original meaning is to 'Wait For an Interrupt', but we generally
 * ignore interrupts in 470
 *
 * This mostly follows the RISC-V Privileged spec
 * except a few add-ons for our infrastructure
 * The majority of them won't be used, but it's good to know what they are
 */

typedef enum logic [3:0] {
    INST_ADDR_MISALIGN  = 4'h0,
    INST_ACCESS_FAULT   = 4'h1,
    ILLEGAL_INST        = 4'h2,
    BREAKPOINT          = 4'h3,
    LOAD_ADDR_MISALIGN  = 4'h4,
    LOAD_ACCESS_FAULT   = 4'h5,
    STORE_ADDR_MISALIGN = 4'h6,
    STORE_ACCESS_FAULT  = 4'h7,
    ECALL_U_MODE        = 4'h8,
    ECALL_S_MODE        = 4'h9,
    NO_ERROR            = 4'ha, // a reserved code that we use to signal no errors
    ECALL_M_MODE        = 4'hb,
    INST_PAGE_FAULT     = 4'hc,
    LOAD_PAGE_FAULT     = 4'hd,
    HALTED_ON_WFI       = 4'he, // 'Wait For Interrupt'. In 470, signifies the end of computation
    STORE_PAGE_FAULT    = 4'hf
} EXCEPTION_CODE;

///////////////////////////////////
// ---- Instruction Typedef ---- //
///////////////////////////////////

// from the RISC-V ISA spec
typedef union packed {
    logic [31:0] inst;
    struct packed {
        logic [6:0] funct7;
        logic [4:0] rs2; // source register 2
        logic [4:0] rs1; // source register 1
        logic [2:0] funct3;
        logic [4:0] rd; // destination register
        logic [6:0] opcode;
    } r; // register-to-register instructions
    struct packed {
        logic [11:0] imm; // immediate value for calculating address
        logic [4:0]  rs1; // source register 1 (used as address base)
        logic [2:0]  funct3;
        logic [4:0]  rd;  // destination register
        logic [6:0]  opcode;
    } i; // immediate or load instructions
    struct packed {
        logic [6:0] off; // offset[11:5] for calculating address
        logic [4:0] rs2; // source register 2
        logic [4:0] rs1; // source register 1 (used as address base)
        logic [2:0] funct3;
        logic [4:0] set; // offset[4:0] for calculating address
        logic [6:0] opcode;
    } s; // store instructions
    struct packed {
        logic       of;  // offset[12]
        logic [5:0] s;   // offset[10:5]
        logic [4:0] rs2; // source register 2
        logic [4:0] rs1; // source register 1
        logic [2:0] funct3;
        logic [3:0] et;  // offset[4:1]
        logic       f;   // offset[11]
        logic [6:0] opcode;
    } b; // branch instructions
    struct packed {
        logic [19:0] imm; // immediate value
        logic [4:0]  rd; // destination register
        logic [6:0]  opcode;
    } u; // upper-immediate instructions
    struct packed {
        logic       of; // offset[20]
        logic [9:0] et; // offset[10:1]
        logic       s;  // offset[11]
        logic [7:0] f;  // offset[19:12]
        logic [4:0] rd; // destination register
        logic [6:0] opcode;
    } j;  // jump instructions

// extensions for other instruction types
`ifdef ATOMIC_EXT
    struct packed {
        logic [4:0] funct5;
        logic       aq;
        logic       rl;
        logic [4:0] rs2;
        logic [4:0] rs1;
        logic [2:0] funct3;
        logic [4:0] rd;
        logic [6:0] opcode;
    } a; // atomic instructions
`endif
`ifdef SYSTEM_EXT
    struct packed {
        logic [11:0] csr;
        logic [4:0]  rs1;
        logic [2:0]  funct3;
        logic [4:0]  rd;
        logic [6:0]  opcode;
    } sys; // system call instructions
`endif

} INST; // instruction typedef, this should cover all types of instructions

////////////////////////////////////////
// ---- Datapath Control Signals ---- //
////////////////////////////////////////

// ALU opA input mux selects
typedef enum logic [1:0] {
    OPA_IS_RS1  = 2'h0,
    OPA_IS_NPC  = 2'h1,
    OPA_IS_PC   = 2'h2,
    OPA_IS_ZERO = 2'h3
} ALU_OPA_SELECT;

// ALU opB input mux selects
typedef enum logic [3:0] {
    OPB_IS_RS2    = 4'h0,
    OPB_IS_I_IMM  = 4'h1,
    OPB_IS_S_IMM  = 4'h2,
    OPB_IS_B_IMM  = 4'h3,
    OPB_IS_U_IMM  = 4'h4,
    OPB_IS_J_IMM  = 4'h5
} ALU_OPB_SELECT;

// ALU function code
typedef enum logic [3:0] {
    ALU_ADD     = 4'h0,
    ALU_SUB     = 4'h1,
    ALU_SLT     = 4'h2,
    ALU_SLTU    = 4'h3,
    ALU_AND     = 4'h4,
    ALU_OR      = 4'h5,
    ALU_XOR     = 4'h6,
    ALU_SLL     = 4'h7,
    ALU_SRL     = 4'h8,
    ALU_SRA     = 4'h9
} ALU_FUNC;

// MULT funct3 code
// we don't include division or rem options
typedef enum logic [3:0] {
    M_MUL,
    M_MULH,
    M_MULHSU,
    M_MULHU
} MULT_FUNC;

////////////////////////////////
// ---- Datapath Packets ---- //
////////////////////////////////

/**
 * Packets are used to move many variables between modules with
 * just one datatype, but can be cumbersome in some circumstances.
 *
 * Define new ones in project 4 at your own discretion
 */

/**
 * IF_ID Packet:
 * Data exchanged from the IF to the ID stage
 */
typedef struct packed {
    INST  inst;
    ADDR  PC;
    ADDR  NPC; // PC + 4
    logic valid;
    logic predict_taken;
    ADDR  predict_target;
} IF_ID_PACKET;

/**
 * ID_EX Packet:
 * Data exchanged from the ID to the EX stage
 */
typedef struct packed {
    INST inst;
    ADDR PC;
    ADDR NPC; // PC + 4

    DATA rs1_value; // reg A value
    DATA rs2_value; // reg B value

    ALU_OPA_SELECT opa_select; // ALU opa mux select (ALU_OPA_xxx *)
    ALU_OPB_SELECT opb_select; // ALU opb mux select (ALU_OPB_xxx *)

    REG_IDX  dest_reg_idx;  // destination (writeback) register index
    ALU_FUNC alu_func;      // ALU function select (ALU_xxx *)
    logic    rd_mem;        // Does inst read memory?
    logic    wr_mem;        // Does inst write memory?
    logic    cond_branch;   // Is inst a conditional branch?
    logic    uncond_branch; // Is inst an unconditional branch?
    logic    halt;          // Is this a halt?
    logic    illegal;       // Is this instruction illegal?
    logic    csr_op;        // Is this a CSR operation? (we only used this as a cheap way to get return code)

    logic    valid;
} ID_EX_PACKET;

/**
 * EX_MEM Packet:
 * Data exchanged from the EX to the MEM stage
 */
typedef struct packed {
    DATA alu_result;
    ADDR NPC;

    logic    take_branch; // Is this a taken branch?
    // Pass-through from decode stage
    DATA     rs2_value;
    logic    rd_mem;
    logic    wr_mem;
    REG_IDX  dest_reg_idx;
    logic    halt;
    logic    illegal;
    logic    csr_op;
    logic    rd_unsigned; // Whether proc2Dmem_data is signed or unsigned
    MEM_SIZE mem_size;
    logic    valid;
} EX_MEM_PACKET;

/**
 * MEM_WB Packet:
 * Data exchanged from the MEM to the WB stage
 *
 * Does not include data sent from the MEM stage to memory
 */
typedef struct packed {
    DATA    result;
    ADDR    NPC;
    REG_IDX dest_reg_idx; // writeback destination (ZERO_REG if no writeback)
    logic   take_branch;
    logic   halt;    // not used by wb stage
    logic   illegal; // not used by wb stage
    logic   valid;
} MEM_WB_PACKET;

/**
 * No WB output packet as it would be more cumbersome than useful
 */

/**
 * RS Packet:
 * Data exchanged between decoder and reservation stations
 * Also includes the ROBN, RAT check result
 */

// TODO change data padding
typedef union packed {
    DATA value;
    DATA prn;
} OP_FIELD;

typedef enum logic [1:0] { 
    FU_ALU,
    FU_MULT,
    FU_LOAD,
    FU_STORE
} FU_TYPE;

// TODO
typedef union packed {
    ALU_FUNC  alu;
    MULT_FUNC mult;
} FU_FUNC;

typedef struct packed {
    INST     inst; // Opcode & Immediate
    logic    valid;
    ADDR     PC;
    FU_TYPE  fu;
    FU_FUNC  func;
    logic    op1_ready, op2_ready;
    OP_FIELD op1,       op2;
    PRN      dest_prn;
    ROBN     robn;
    ALU_OPA_SELECT opa_select; // used for select signal in FU, 2 bits
    ALU_OPB_SELECT opb_select; // same as above, 4 bits
    logic cond_branch;
    logic uncond_branch;
    SQ_IDX sq_idx;
    MEM_FUNC mem_func;
} RS_ENTRY;

typedef struct packed {
    RS_ENTRY [`N-1:0] entries;
} RS_IS_PACKET;

typedef struct packed {
    INST     inst; // Opcode & Immediate
    logic    valid;
    ADDR     PC;
    FU_TYPE  fu;
    FU_FUNC  func;
    ALU_OPA_SELECT opa_select; // used for select signal in FU, 2 bits
    ALU_OPB_SELECT opb_select; // same as above, 4 bits
    logic cond_branch;
    logic uncond_branch;
    MEM_FUNC mem_func;
} ID_RS_PACKET;


typedef struct packed {
    logic          [`N_CNT_WIDTH-1:0] completed_inst;
    EXCEPTION_CODE           [`N-1:0] exception_code;
    REG_IDX                  [`N-1:0] wr_idx;
    DATA                     [`N-1:0] wr_data;
    logic                    [`N-1:0] wr_en;
    ADDR                     [`N-1:0] NPC;
} OOO_CT_PACKET;

/**
 * FU Packet:
 * Data exchanged between reservation stations and the FU
 */
typedef struct packed {
    logic    valid;
    INST     inst;
    ADDR     PC;
    FU_FUNC  func;
    DATA     op1, op2;
    PRN      dest_prn;
    ROBN     robn;
    ALU_OPA_SELECT opa_select; // used for select signal in FU
    ALU_OPB_SELECT opb_select; // same as above
    logic    cond_branch;
    logic    uncond_branch;
    SQ_IDX   sq_idx;
    MEM_FUNC mem_func;
} FU_PACKET;

/**
 * CDB Packet:
 * Data exchanged between CDB and RS
 */
typedef struct packed {
    PRN   dest_prn;
    DATA  value;
} CDB_PACKET;

/**
 * ROB Packet:
 * Data exchanged between decoder and the ROB
 */
typedef struct packed {
    logic    executed;
    logic    success; // branch_taken prediction success
    logic    is_store;
    logic    cond_branch;
    logic    uncond_branch;
    logic    resolve_taken;
    logic    predict_taken;
    ADDR     predict_target;
    ADDR     resolve_target;
    PRN      dest_prn; // debug only
    REG_IDX  dest_arn;
    ADDR     PC;
    ADDR     NPC;     // PC + 4
    logic    halt;    // Is this a halt?
    logic    illegal; // Is this instruction illegal?
    logic    csr_op;  // Is this a CSR operation? (we only used this as a cheap way to get return code)
} ROB_ENTRY;

typedef struct packed {
    logic     [`N-1:0] valid; // all valid entries are in the front of the packet
    ROB_ENTRY [`N-1:0] entries;
} ROB_IS_PACKET;

typedef struct packed {
    ROBN  robn;
    logic executed;
    logic branch_taken;
    ADDR  target_addr;
} FU_ROB_PACKET;

typedef struct packed {
    ROB_ENTRY [`N-1:0] entries;
} ROB_CT_PACKET;

/**
 * RAT Packet:
 * Data for the register alias table
 */

typedef struct packed {
    REG_IDX dest_arn; 
    REG_IDX op1_arn, op2_arn;
} RAT_INPUT_ENTRY;

typedef struct packed {
    PRN     dest_prn;
    PRN     op1_prn, op2_prn;
} RAT_OUTPUT_ENTRY;

typedef struct packed {
    RAT_INPUT_ENTRY [`N-1:0] entries;
} RAT_IS_INPUT;

typedef struct packed {
    RAT_OUTPUT_ENTRY [`N-1:0] entries;
} RAT_IS_OUTPUT;

/**
 * RRAT Packet:
 */

typedef struct packed {
    logic   [`N-1:0] success;
    REG_IDX [`N-1:0] arns; // arn = 0 encodes no valid dest_arn 
} RRAT_CT_INPUT;

typedef struct packed {
    logic valid;
    PRN   prn;
} FREE_LIST_PACKET;

typedef struct packed {
    FREE_LIST_PACKET        [`N-1:0] free_packet;
    logic                            squash;
    PRN           [`ARCH_REG_SZ-1:0] entries;
    PRN                              head, tail;
    logic [`FREE_LIST_CTR_WIDTH-1:0] free_list_counter;
    PRN      [`PHYS_REG_SZ_R10K-1:0] free_list;
} RRAT_CT_OUTPUT;

typedef struct packed {
    logic valid;
    DATA  value;
} PRF_ENTRY;

typedef struct packed {
    DATA value;
    PRN  prn;
} PRF_WRITE;

typedef struct packed {
    ROBN robn;
    PRN dest_prn;
    DATA result;
} FU_STATE_BASIC_PACKET;

typedef struct packed {
    FU_STATE_BASIC_PACKET basic;
    logic take_branch;
    logic cond_branch;
    logic uncond_branch;
    ADDR NPC;
} FU_STATE_ALU_PACKET;

typedef struct packed {
    // prepared and actual packet splitted for simplicity in input of priority selectors
    logic                 [`NUM_FU_ALU-1:0]  alu_prepared;
    FU_STATE_ALU_PACKET   [`NUM_FU_ALU-1:0]  alu_packet;
    logic                 [`NUM_FU_MULT-1:0] mult_prepared;
    FU_STATE_BASIC_PACKET [`NUM_FU_MULT-1:0] mult_packet;
    logic                 [`NUM_FU_LOAD-1:0] load_prepared;
    FU_STATE_BASIC_PACKET [`NUM_FU_LOAD-1:0] load_packet;
} FU_STATE_PACKET;

// typedef struct packed {
//     logic valid;
//     ADDR PC;
//     ADDR target_addr;
// } CDB_PREDICTOR_PfACKET;

typedef struct packed {
    logic valid;
    logic success;
    logic predict_taken;
    ADDR  predict_target;
    logic resolve_taken;
    ADDR  resolve_target;
    ADDR  PC;
    logic is_branch;
} ROB_IF_ENTRY;

typedef struct packed {
    ROB_IF_ENTRY [`N-1:0] entries;
} ROB_IF_PACKET;

typedef struct packed {
    logic taken;
    logic valid;
    ADDR  PC;
} PC_ENTRY;

typedef struct packed {
    logic valid;
    // MEM_SIZE byte_info;
    MEM_FUNC byte_info;
} ID_SQ_PACKET;

typedef struct packed {
    ID_RS_PACKET  [`N-1:0] id_rs_packet;
    ID_SQ_PACKET  [`N-1:0] id_sq_packet;
    ROB_IS_PACKET          rob_is_packet;
    RAT_IS_INPUT           rat_is_input;
} ID_OOO_PACKET;

typedef struct packed {
    logic [`ICACHE_INDEX_BITS-1:0]  index;           // cache index
    logic [`ICACHE_TAG_BITS-1:0]  tag;             // cache tag
    MEM_TAG                       transaction_tag; // tag returned from memory
    IMSHR_STATE                   state;           // MISS, WAIT
} IMSHR_ENTRY;

typedef struct packed {
    logic [`DCACHE_INDEX_BITS-1:0]  index;           // cache index
    logic [`DCACHE_TAG_BITS-1:0]    tag;             // cache tag
    MEM_TAG                         transaction_tag; // tag returned from memory
    DMSHR_STATE                     state;           // MISS, WAIT
} DMSHR_ENTRY;

typedef struct packed {
    INST_COMMAND                          inst_command;
    MEM_FUNC                              mem_func;
    DATA                                  data;
    logic [`DCACHE_BLOCK_OFFSET_BITS-1:0] block_offset;
    LU_IDX                                lq_idx;
} DMSHR_Q_PACKET;

typedef struct packed {
    logic valid;
    ADDR  base;
    logic signed [11:0] offset;
    DATA  data;
    SQ_IDX sq_idx;
} RS_SQ_PACKET;

typedef struct packed {
    logic  valid;
    LU_IDX lq_idx;
    DATA   data;
} DCACHE_LQ_PACKET;

typedef struct packed {
    logic    valid;
    LU_IDX   lq_idx;
    ADDR     addr;
    MEM_FUNC mem_func;
} LQ_DCACHE_PACKET;

typedef struct packed {
    logic     valid;
    ADDR      addr;
    MEM_FUNC  mem_func;
    DATA      data;
} SQ_DCACHE_PACKET;

typedef struct packed {
    DCACHE_BLOCK                 data;
    logic [`DCACHE_TAG_BITS-1:0] tag; // 32 - block index bits
    logic                        valid;
    logic                        dirty;
} DCACHE_ENTRY;

typedef struct packed {
    logic    valid;
    // MEM_SIZE byte_info;
    MEM_FUNC byte_info;
    ADDR     addr;
    DATA     data;
    logic    ready;
    logic    accepted;
    logic    commited;
} SQ_ENTRY;

typedef struct packed {
    logic valid;
    // logic signext;
    // MEM_SIZE size;
    MEM_FUNC sign_size;
    ADDR base;
    logic signed [11:0] offset;
    PRN prn;
    ROBN robn;
    SQ_IDX   tail_store;
} RS_LQ_PACKET;

typedef struct packed {
    logic  valid;
    ADDR   addr;
    DATA   data;
    SQ_IDX sq_idx;
} SQ_REG;

typedef enum logic [1:0] {KNOWN, NO_FORWARD, ASKED} LU_STATE;

typedef struct packed {
    logic    valid;
    // logic    signext;
    // MEM_SIZE byte_info;
    logic [3:0] forwarded;
    MEM_FUNC byte_info;
    ADDR     addr;
    DATA     data;
    SQ_IDX   tail_store;
    PRN      prn;
    ROBN     robn;
    LU_STATE load_state;
} LD_ENTRY;

typedef struct packed {
    logic valid;
    // logic signext;
    // MEM_SIZE size;
    MEM_FUNC sign_size;
    ADDR addr;
    PRN prn;
    ROBN robn;
    SQ_IDX   tail_store;
} LU_REG;

typedef struct packed {
    logic valid;
    // logic signext;
    // MEM_SIZE size;
    logic [3:0] forwarded;
    MEM_FUNC sign_size;
    ADDR addr;
    PRN prn;
    ROBN robn;
    SQ_IDX   tail_store;
    DATA value;
    logic fwd_valid;
} LU_FWD_REG;

typedef struct packed {
    logic   valid;
    ADDR    NPC;
    REG_IDX rs, rd;
} ID_RAS_PACKET;

typedef struct packed {
    logic valid;
    ADDR  ra;
} RAS_IF_PACKET;

`endif // __SYS_DEFS_SVH__
