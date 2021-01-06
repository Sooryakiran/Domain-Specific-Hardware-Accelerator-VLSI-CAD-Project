NOP                 ; =================== IMPORTANT ======================
NOP                 ; TO RUN IN 32-bit, PLEASE CHANGE THE ADDRESS TO JMP, 
NOP                 ; BECAUSE ASG_32 INSTR ARE ACTUALLY 2 INSTRS IN 32-bit
ASG_8 R1 0          ; Initialisation
ASG_8 R2 10         ; Num loops
ASG_32 R3 1024      ; Address
ASG_8 R4 1          ; Value increment delta
ASG_32 R5 1         ; Address increment delta
ASG_32 R0 128       ; Address of console
STORE_8 R1 R3       ;
STORE_8 R1 R0       ; Print console
ADD_I8 R1 R4 R1     ; Increment value
ADD_I32 R3 R5 R3    ; Increment address
ASG_32 R7 1
IS_EQ R1 R2 R6      ; Compare
ADD_I32 R6 R7 R6
ASG_32 R7 9
JMPIF R7 R6         ; Jump if not Eq
NOP
NOP
ASG_32 R3 1024
VEC_NEG_I8 R3 R2 R3 ; Vector negation
NOP
NOP
ASG_8 R1 0
LOAD_8 R3 R4        ; Load from memory
STORE_8 R4 R0       ; Print
ADD_I32 R3 R5 R3    ; Incement address
ASG_8 R4 1
ADD_I8 R1 R4 R1     ; Increment Loop
ASG_32 R7 1
IS_EQ R1 R2 R6      ; Compare
ADD_I32 R6 R7 R6
ASG_32 R7 25
JMPIF R7 R6         ; Jump if not Eq