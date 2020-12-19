ASG_32 R1 8
MOV R1 R3
ASG_16 R2 1
ASG_8 R5 -12
ASG_8 R6 10
ASG_32 R0 11
ASG_32 R4 12.34
ASG_16 R0 15
MOV R1 R2 # Move R1 to R2
ADD_I8 R1 R2 R3
ADD_I16 R2 R3 R4
SUB_F32 R2 R3 R4
IS_EQ R2 R1 R7
ASG_32 R1 23
ASG_16 R0 15
JMP R0
LOAD_32 R1 R2 # Load value at address pointed by R1 to R2
STORE_16 R1 R2 # Store value of R1 to address R2
VEC_NEG_I16 R1 R2 R3 # R1 : Vec src, R2: Block size, R3: Dst Addresses
VEC_NEG_I16 R3 R2 R3 # R3 : Vec src, R2: Block size, R3: Dst Addresses