NOP                 ; Store Array [13, 12, 11, -13, 15]
ASG_32 R3 128       ; Console address
ASG_8 R1 13         ; Value
ASG_32 R2 1024      ; Address
STORE_8 R1 R2       ; Store to RAM
STORE_8 R1 R3       ; Print
ASG_8 R1 12         ; Value
ASG_32 R2 1025      ; Address
STORE_8 R1 R2       ; Store to RAM
STORE_8 R1 R3       ; Print
ASG_8 R1 11         ; Value
ASG_32 R2 1026      ; Address
STORE_8 R1 R2       ; Store to RAM
STORE_8 R1 R3       ; Print
ASG_8 R1 -13        ; Value
ASG_32 R2 1027      ; Address
STORE_8 R1 R2       ; Store to RAM
STORE_8 R1 R3       ; Print
ASG_8 R1 15         ; Value
ASG_32 R2 1028      ; Address
STORE_8 R1 R2       ; Store to RAM
STORE_8 R1 R3       ; Print
NOP
ASG_32 R1 1024      ; Vector starting location
ASG_32 R2 5         ; Vector size
ASG_32 R4 1024      ; Minimum dst
ASG_32 R5 1025      ; Argmin dst
VEC_MIN_I8 R1 R2 R4 R5  ; Vec op
LOAD_8 R4 R6        ; Load minima
STORE_8 R6 R3       ; Print minima
LOAD_8 R5 R7        ; Load argmin
STORE_8 R7 R3       ; Print argmin