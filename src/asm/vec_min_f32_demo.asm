NOP                  ; Store Array [13.0, 12.1, 11.8, -13.9, 15.8]
ASG_32 R3 128        ; Console address
ASG_32 R1 13.0       ; Value
ASG_32 R2 1024       ; Address
STORE_32 R1 R2       ; Store to RAM
STORE_32 R1 R3       ; Print
ASG_32 R1 12.1       ; Value
ASG_32 R2 1028       ; Address
STORE_32 R1 R2       ; Store to RAM
STORE_32 R1 R3       ; Print
ASG_32 R1 11.8       ; Value
ASG_32 R2 1032       ; Address
STORE_32 R1 R2       ; Store to RAM
STORE_32 R1 R3       ; Print
ASG_32 R1 -13.9      ; Value
ASG_32 R2 1036       ; Address
STORE_32 R1 R2       ; Store to RAM
STORE_32 R1 R3       ; Print
ASG_32 R1 15.8       ; Value
ASG_32 R2 1040       ; Address
STORE_32 R1 R2       ; Store to RAM
STORE_32 R1 R3       ; Print
NOP
ASG_32 R1 1024       ; Vector starting location
ASG_32 R2 5          ; Vector size
ASG_32 R4 1024       ; Minimum dst
ASG_32 R5 1028       ; Argmin dst
VEC_MIN_F32 R1 R2 R4 R5  ; Vec op
LOAD_32 R4 R6        ; Load minima
STORE_32 R6 R3       ; Print minima
LOAD_32 R5 R7        ; Load argmin
STORE_32 R7 R3       ; Print argmin