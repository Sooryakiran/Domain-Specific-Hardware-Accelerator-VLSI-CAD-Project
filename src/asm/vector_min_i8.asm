NOP ; Load Vectors to ram
ASG_8 R1 13     ; Value
ASG_32 R2 1024   ; Address
STORE_8 R1 R2
ASG_8 R1 14     
ASG_32 R2 1025
STORE_8 R1 R2
ASG_8 R1 15
ASG_32 R2 1026
STORE_8 R1 R2
ASG_8 R1 16
ASG_32 R2 1027
STORE_8 R1 R2
ASG_8 R1 17
ASG_32 R2 1028
STORE_8 R1 R2
ASG_8 R1 18
ASG_32 R2 1029
STORE_8 R1 R2
ASG_8 R1 11
ASG_32 R2 1030
STORE_8 R1 R2
ASG_8 R1 -101
ASG_32 R2 1031
STORE_8 R1 R2
ASG_8 R1 11
ASG_32 R2 1032
STORE_8 R1 R2
ASG_8 R1 -99
ASG_32 R2 1033
STORE_8 R1 R2
ASG_32 R3 1024
ASG_32 R4 19
ASG_32 R5 1060
VEC_MIN_I8 R3 R4 R3 R5 ; starting from R3's pointed address, R4 block, write back to R3's pointed address
ASG_32 R3 1024
LOAD_8 R3 R1
ASG_32 R2 128
STORE_8 R1 R2
ASG_32 R3 1025
LOAD_8 R3 R1
ASG_32 R2 128
STORE_8 R1 R2
ASG_32 R3 1026
LOAD_8 R3 R1
ASG_32 R2 128
STORE_8 R1 R2
ASG_32 R3 1027
LOAD_8 R3 R1
ASG_32 R2 128
STORE_8 R1 R2
ASG_32 R3 1028
LOAD_8 R3 R1
ASG_32 R2 128
STORE_8 R1 R2
ASG_32 R3 1029
LOAD_8 R3 R1
ASG_32 R2 128
STORE_8 R1 R2
ASG_32 R3 1030
LOAD_8 R3 R1
ASG_32 R2 128
STORE_8 R1 R2