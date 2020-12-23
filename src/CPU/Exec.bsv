package Exec;
    import FIFOF::*;
    import SpecialFIFOs::*;
    import GetPut::*;
    import Vector::*;
    import ClientServer::*;
    import FloatingPoint::*;

    `include <config.bsv>

    /*----------------------------------------------------------------------
                                Interfaces
    -----------------------------------------------------------------------*/
    interface Exec;
        interface Put #(Bit #(`DecodedInstructionSize)) put_decoded;  
        interface Get #(Bit #(SizeOf #(RegPackets))) send_computed_value;
        interface Get #(Bit #(`DATA_LENGTH)) get_branch;
    endinterface

    /*----------------------------------------------------------------------
                            Module Declarations
    -----------------------------------------------------------------------*/
    module mkExec (Exec);
        FIFOF #(Bit #(`DecodedInstructionSize)) incoming    <- mkBypassFIFOF;
        FIFOF #(RegPackets)                     out_to_regs <- mkBypassFIFOF;
        RWire #(Bit #(`DATA_LENGTH))            branch      <- mkRWire();
        Reg   #(Bit #(32))                      debug_clk   <- mkReg(0);

        function ActionValue #(Bit #(SizeOf #(RegPackets))) send_back_to_regs;
            actionvalue
                let x = pack(out_to_regs.first());
                out_to_regs.deq();
                return pack(x);
            endactionvalue
        endfunction

        function Action mov(Bit #(`DATA_LENGTH) value, Regname name);
            action
                RegPackets packet = RegPackets {
                                        data        : value,
                                        register    : name};
                out_to_regs.enq(packet);
                incoming.deq();
            endaction
        endfunction

        function Action addi8 (Bit #(`DATA_LENGTH) x1, Bit #(`DATA_LENGTH) x2, Regname name);
            action
                Int #(8) int_1          = unpack(truncate(x1));
                Int #(8) int_2          = unpack(truncate(x2));
                Int #(`DATA_LENGTH) out = extend(int_1 + int_2);

                RegPackets packet = RegPackets {
                                        data        : pack(out),
                                        register    : name};
                out_to_regs.enq(packet);
                incoming.deq();
            endaction
        endfunction

        function Action addi16 (Bit #(`DATA_LENGTH) x1, Bit #(`DATA_LENGTH) x2, Regname name);
            action
                Int #(16) int_1         = unpack(truncate(x1));
                Int #(16) int_2         = unpack(truncate(x2));
                Int #(`DATA_LENGTH) out = extend(int_1 + int_2);

                RegPackets packet = RegPackets {
                                        data        : pack(out),
                                        register    : name
                                    };
                out_to_regs.enq(packet);
                incoming.deq();
            endaction
        endfunction

        function Action addi32 (Bit #(`DATA_LENGTH) x1, Bit #(`DATA_LENGTH) x2, Regname name);
            action
                Int #(32) int_1         = unpack(truncate(x1));
                Int #(32) int_2         = unpack(truncate(x2));
                Int #(`DATA_LENGTH) out = extend(int_1 + int_2);

                RegPackets packet = RegPackets {
                                        data        : pack(out),
                                        register    : name
                                    };
                out_to_regs.enq(packet);
                incoming.deq();
            endaction
        endfunction

        function Action addf32 (Bit #(`DATA_LENGTH) x1, Bit #(`DATA_LENGTH) x2, Regname name);
            action
                Float f32_1 = unpack(x1);
                Float f32_2 = unpack(x2);
                Float out   = f32_1 + f32_2;

                RegPackets packet = RegPackets {
                                        data        : pack(out),
                                        register    : name
                                    };
                out_to_regs.enq(packet);
                incoming.deq();
            endaction
        endfunction

        function Action subi8 (Bit #(`DATA_LENGTH) x1, Bit #(`DATA_LENGTH) x2, Regname name);
            action
                Int #(8) int_1          = unpack(truncate(x1));
                Int #(8) int_2          = unpack(truncate(x2));
                Int #(`DATA_LENGTH) out = extend(int_1 - int_2);

                RegPackets packet = RegPackets {
                                        data        : pack(out),
                                        register    : name
                                    };
                out_to_regs.enq(packet);
                incoming.deq();
            endaction
        endfunction

        function Action subi16 (Bit #(`DATA_LENGTH) x1, Bit #(`DATA_LENGTH) x2, Regname name);
            action
                Int #(16) int_1         = unpack(truncate(x1));
                Int #(16) int_2         = unpack(truncate(x2));
                Int #(`DATA_LENGTH) out = extend(int_1 - int_2);

                RegPackets packet = RegPackets {
                                        data        : pack(out),
                                        register    : name
                                    };
                out_to_regs.enq(packet);
                incoming.deq();
            endaction
        endfunction

        function Action subi32 (Bit #(`DATA_LENGTH) x1, Bit #(`DATA_LENGTH) x2, Regname name);
            action
                Int #(32) int_1         = unpack(truncate(x1));
                Int #(32) int_2         = unpack(truncate(x2));
                Int #(`DATA_LENGTH) out = extend(int_1 - int_2);

                RegPackets packet = RegPackets {
                                        data        : pack(out),
                                        register    : name
                                    };
                out_to_regs.enq(packet);
                incoming.deq();
            endaction
        endfunction

        function Action subf32 (Bit #(`DATA_LENGTH) x1, Bit #(`DATA_LENGTH) x2, Regname name);
            action
                Float f32_1 = unpack(x1);
                Float f32_2 = unpack(x2);
                Float out = f32_1 - f32_2;

                RegPackets packet = RegPackets {
                                        data : pack(out),
                                        register : name
                                    };
                
                out_to_regs.enq(packet);
                incoming.deq();
            endaction
        endfunction

        function Action iseq (Bit #(`DATA_LENGTH) x1, Bit #(`DATA_LENGTH) x2, Regname name);
            action
                Bit #(`DATA_LENGTH) out = (x1 == x2)? 1: 0;
                RegPackets packet   = RegPackets {
                                        data        : out,
                                        register    : name
                                    };
                
                out_to_regs.enq(packet);
                incoming.deq();
            endaction
        endfunction

        function Action jmp (Bit #(`DATA_LENGTH) dst);
            action
                branch.wset(dst);
                incoming.deq();
            endaction
        endfunction

        function Action jmpif (Bit #(`DATA_LENGTH) dst, Bit #(`DATA_LENGTH) cond);
            action
                if (cond == 1)
                begin
                branch.wset(dst);
                end
                incoming.deq();
            endaction
        endfunction
        
        rule exec_master;
            DecodedInstruction x = unpack(incoming.first);

            if (x.code == NOP)      incoming.deq();
            if (x.code == MOV)      mov     (x.src1, x.dst);
            if (x.code == ADD_I8)   addi8   (x.src1, x.src2, x.dst);
            if (x.code == ADD_I16)  addi16  (x.src1, x.src2, x.dst);
            if (x.code == ADD_I32)  addi32  (x.src1, x.src2, x.dst);
            if (x.code == ADD_F32)  addf32  (x.src1, x.src2, x.dst);
            if (x.code == SUB_I8)   subi8   (x.src1, x.src2, x.dst);
            if (x.code == SUB_I16)  subi16  (x.src1, x.src2, x.dst);
            if (x.code == SUB_I32)  subi32  (x.src1, x.src2, x.dst);
            if (x.code == SUB_F32)  subf32  (x.src1, x.src2, x.dst);
            if (x.code == IS_EQ)    iseq    (x.src1, x.src2, x.dst);
            if (x.code == JMP)      jmp     (x.src1);
            if (x.code == JMPIF)    jmpif   (x.src1, x.src2);
            if (x.code == STORE_32) incoming.deq();
    
        endrule

        rule debug;
            debug_clk <= debug_clk + 1;
            if(debug_clk>100) $finish();
        endrule 

        interface Get get_branch = toGet(branch);
        interface Put put_decoded = toPut(incoming);
        interface Get send_computed_value = toGet(send_back_to_regs()); // sayooj is
    endmodule
endpackage : Exec