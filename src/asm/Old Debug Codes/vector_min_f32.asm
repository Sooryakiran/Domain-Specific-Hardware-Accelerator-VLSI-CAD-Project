NOP ; Load Vectors to ram
ASG_32 R1 101000.0     ; Value
ASG_32 R2 1024   ; Address
STORE_32 R1 R2
ASG_32 R1 140000.0     
ASG_32 R2 1028
STORE_32 R1 R2
ASG_32 R1 -9.9
ASG_32 R2 1032
STORE_32 R1 R2
ASG_32 R1 -111.9
ASG_32 R2 1036
STORE_32 R1 R2
ASG_32 R1 17.0
ASG_32 R2 1040
STORE_32 R1 R2
ASG_32 R1 18.0
ASG_32 R2 1044
STORE_32 R1 R2
ASG_32 R1 11.0
ASG_32 R2 1048
STORE_32 R1 R2
ASG_32 R1 -101.2
ASG_32 R2 1052
STORE_32 R1 R2
ASG_32 R1 11.1
ASG_32 R2 1056
STORE_32 R1 R2
ASG_32 R1 -99.22
ASG_32 R2 1060
STORE_32 R1 R2
ASG_32 R1 -30000.01 ; -30000 is the minimum at index 16
ASG_32 R2 1064
STORE_32 R1 R2
ASG_32 R3 1024
ASG_32 R4 7
ASG_32 R5 1024
ASG_32 R6 1028
VEC_MIN_F32 R3 R4 R5 R6 ; starting from R3's pointed address, R4 block, write back to R5's pointed address
ASG_32 R3 1024
LOAD_32 R3 R1
ASG_32 R2 128
STORE_32 R1 R2
ASG_32 R3 1028
LOAD_32 R3 R1
ASG_32 R2 128
STORE_32 R1 R2