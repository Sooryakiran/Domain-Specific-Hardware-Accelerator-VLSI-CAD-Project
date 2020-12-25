`ifndef CPU_CONF
    `define CPU_CONF
    `define WORD_LENGTH 64
    `define SMALL_WIDTH     // Comment this line for >32 bits. Explaination: ASG_32 instruction has 64 bit length even for 32 bit systems. :(

    `define DATA_LENGTH 32
    `define BUS_DATA_LEN 64
    `define ADDR_LENGTH 20
    `define GRANULARITY 8 // Lowest addressible unit size = 1 Byte in RAM
    
// /*-------------------------------------------------------------------------------
//                         DONOT MODIFY ANYTHING BELOW THIS LINE
// -------------------------------------------------------------------------------*/

//     `define PC_SIZE `WORD_LENGTH
//     `ifndef SMALL_WIDTH
//         `define HEAVY_WIDTH
//     `endif

//     typedef enum {NOP,
//         ASG_8,    
//         ASG_16,
//         ASG_32,   
//         MOV,

//         ADD_I8,
//         ADD_I16,
//         ADD_I32,
//         ADD_F32,

//         SUB_I8,
//         SUB_I16,
//         SUB_I32,
//         SUB_F32,

//         IS_EQ,

//         JMP, 
//         JMPIF,

//         LOAD_8,
//         LOAD_16,
//         LOAD_32,

//         STORE_8,
//         STORE_16,
//         STORE_32,

//         VEC_NEG_I8,
//         VEC_NEG_I16,
//         VEC_NEG_I32,
//         VEC_NEG_F32,

//         VEC_MIN_I8,
//         VEC_MIN_I16,
//         VEC_MIN_I32,
//         VEC_MIN_F32
//     }
//     Opcode deriving (Bits, Eq, FShow);

//     typedef enum {R0, R1, R2, R3, R4, R5, R6, R7, NO} Regname deriving (Bits, Eq, FShow);

//     typedef struct {
//         Opcode code;    //5 bits
//         Regname src1;   //4 bits
//         Regname src2;   //4 bits
//         Regname aux;    //4 bits
//         Regname dst;    //4 bits
//         Bit #(TSub #(`WORD_LENGTH, 21)) pad; // Upto n bits
//     } Instruction deriving(Bits);

//     typedef struct{
//         Opcode code;    //5 bits
//         Regname src1;   //4 bits
//         Bit #(`DATA_LENGTH) data; //32 bits
//         Bit #(TSub #(`WORD_LENGTH, TAdd #(`DATA_LENGTH, 9))) pad;
//     } HeavyData deriving(Bits);

//     typedef struct {
//         Opcode code;                    // 5 bits
//         Bit #(`DATA_LENGTH) src1;       // DATALEN
//         Bit #(`DATA_LENGTH) src2;       // DATALEN
//         Bit #(`DATA_LENGTH) aux;        // DATALEN
//         Regname dst;                    // 4 bits
//     }  DecodedInstruction deriving(Bits, FShow); // 9 + e TMul(`DATALEN, 3)

//     `define DecodedInstructionSize TAdd #(TMul #(`DATA_LENGTH, 3), 9)

//     typedef struct {
//         Bit #(`DATA_LENGTH) data;
//         Regname register;
//     } RegPackets deriving (Bits);

`endif