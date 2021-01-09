NOP                     ; A test code to print that prints the Fibonacci series
ASG_32 R7 128           ; Assign the address of the console
ASG_32 R1 1             ; Initialize first two elements
ASG_32 R2 1             ;
ASG_32 R6 8             ; Loop count. Print 10 (2 + 8) elements including the first 2 
ASG_32 R5 0             ; Loop initialise
ASG_32 R4 1             ; Loop increment
STORE_32 R1 R7          ; Print first 2 values through memory mapped console
STORE_32 R2 R7          ;
loop: ADD_I32 R1 R2 R3       ; Calculate the next element
    ASG_32 R7 128            ; Assign the console address again
    STORE_32 R3 R7           ; Print the new term
    MOV R2 R1                ; Forget the past and move ahead
    MOV R3 R2                ; 
    ADD_I32 R5 R4 R5         ; Loop increment          
    IS_EQ R5 R6 R3           ; 
    ADD_I32 R3 R4 R3         ; IS_EQ outputs 1 if true. But we need 1 to jump.  
    ASG_32 R7 $loop          ; Jump branch destination      
    JMPIF R7 R3              ; Conditional Jump