ASG_32 R1 0         ; Initialisation
ASG_32 R2 10        ; Num loops
ASG_32 R3 1024      ; Address
ASG_32 R4 1         ; Value increment delta
ASG_32 R5 4         ; Address increment delta
ASG_32 R0 128       ; Address of console
loop_init: STORE_32 R1 R3      ;
    STORE_32 R1 R0      ; Print console
    ADD_I32 R1 R4 R1    ; Increment value
    ADD_I32 R3 R5 R3    ; Increment address
    ASG_32 R7 1
    IS_EQ R1 R2 R6      ; Compare
    ADD_I32 R6 R7 R6
    ASG_32 R7 $loop_init
    JMPIF R7 R6         ; Jump if not Eq
ASG_32 R3 1024
VEC_NEG_I32 R3 R2 R3    ; Vector negation
ASG_32 R1 0
loop_print: LOAD_32 R3 R4   ; Load from memory
    STORE_32 R4 R0          ; Print
    ADD_I32 R3 R5 R3        ; Incement address
    ASG_32 R4 1
    ADD_I32 R1 R4 R1        ; Increment Loop
    ASG_32 R7 1
    IS_EQ R1 R2 R6          ; Compare
    ADD_I32 R6 R7 R6
    ASG_32 R7 $loop_print
    JMPIF R7 R6             ; Jump if not Eq