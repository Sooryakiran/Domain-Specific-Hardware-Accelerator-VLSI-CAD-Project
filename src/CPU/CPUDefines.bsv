typedef enum {NOP,
    ASG_8,    
    ASG_16,
    ASG_32,   
    MOV,

    ADD_I8,
    ADD_I16,
    ADD_I32,
    ADD_F32,

    SUB_I8,
    SUB_I16,
    SUB_I32,
    SUB_F32,

    IS_EQ,

    JMP, 
    JMPIF,

    LOAD_8,
    LOAD_16,
    LOAD_32,

    STORE_8,
    STORE_16,
    STORE_32,

    VEC_NEG_I8,
    VEC_NEG_I16,
    VEC_NEG_I32,
    VEC_NEG_F32,

    VEC_MIN_I8,
    VEC_MIN_I16,
    VEC_MIN_I32,
    VEC_MIN_F32
}
Opcode deriving (Bits, Eq, FShow);

typedef enum {R0, R1, R2, R3, R4, R5, R6, R7, NO} Regname deriving (Bits, Eq, FShow);

typedef struct {
    Opcode code;    //5 bits
    Regname src1;   //4 bits
    Regname src2;   //4 bits
    Regname aux;    //4 bits
    Regname dst;    //4 bits
    Bit #(TSub #(wordlength, 21)) pad; // Upto n bits
} Instruction #(numeric type wordlength) deriving(Bits);

typedef struct{
    Opcode code;    //5 bits
    Regname src1;   //4 bits
    Bit #(datalength) data; //32 bits
    Bit #(TSub #(wordlength, TAdd #(datalength, 9))) pad;
} HeavyData #(numeric type wordlength, numeric type datalength) deriving(Bits);

typedef struct {
    Opcode code;                    // 5 bits
    Bit #(datalength) src1;       // DATALEN
    Bit #(datalength) src2;       // DATALEN
    Bit #(datalength) aux;        // DATALEN
    Regname dst;                    // 4 bits
}  DecodedInstruction #(numeric type datalength) deriving(Bits, FShow); // 9 + e TMul(`DATALEN, 3)

typedef TAdd #(9, TMul #(3, datalength)) DecodedInstructionSize #(numeric type datalength);
// `define DecodedInstructionSize TAdd #(TMul #(datalength, 3), 9)

typedef struct {
    Bit #(datalength) data;
    Regname register;
} RegPackets #(numeric type datalength) deriving (Bits);

typedef TAdd #(datalength, SizeOf #(Regname)) SizeRegPackets #(numeric type datalength);