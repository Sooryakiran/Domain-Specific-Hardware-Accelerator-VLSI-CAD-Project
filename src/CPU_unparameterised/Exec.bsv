package Exec;
    import FIFOF::*;
    import SpecialFIFOs::*;
    import GetPut::*;
    import Vector::*;
    import ClientServer::*;
    import FloatingPoint::*;
    import Bus::*;
    `include <config.bsv>

    /*----------------------------------------------------------------------
                                Interfaces
    -----------------------------------------------------------------------*/
    interface Exec;
        interface Put #(Bit #(`DecodedInstructionSize)) put_decoded;  
        interface Get #(Bit #(SizeOf #(RegPackets))) send_computed_value;
        interface Get #(Bit #(`DATA_LENGTH)) get_branch;

        interface Put #(Chunk #(`BUS_DATA_LEN, `ADDR_LENGTH, `GRANULARITY)) put_from_bus;
        interface Get #(Chunk #(`BUS_DATA_LEN, `ADDR_LENGTH, `GRANULARITY)) get_to_bus;

    endinterface

    /*----------------------------------------------------------------------
                            Module Declarations
    -----------------------------------------------------------------------*/
    module mkExec (Exec);
        FIFOF #(Bit #(`DecodedInstructionSize)) incoming    <- mkBypassFIFOF;
        FIFOF #(RegPackets)                     out_to_regs <- mkBypassFIFOF;
        RWire #(Bit #(`DATA_LENGTH))            branch      <- mkRWire();
        Reg   #(Bit #(32))                      debug_clk   <- mkReg(0);
        Reg   #(Bool)                           wait_load   <- mkReg(False);
        Reg   #(Bool)                           wait_store  <- mkReg(False);
        Reg   #(Regname)                        wait_reg    <- mkReg(NO);
        FIFOF #(Chunk #(`BUS_DATA_LEN, `ADDR_LENGTH, `GRANULARITY)) bus_out <- mkBypassFIFOF;
        FIFOF #(Chunk #(`BUS_DATA_LEN, `ADDR_LENGTH, `GRANULARITY)) bus_in <- mkBypassFIFOF;


        rule load_from_bus (wait_load == True && wait_reg != NO);
            let x = bus_in.first(); bus_in.deq();
            let p = x.present;
            
            // Bit #(`DATA_LENGTH) value;
            if (p == 1)
            begin
                // Load 8
                Bit #(8) r = truncate(x.data);
                Bit #(`DATA_LENGTH) value = extend(r);

                RegPackets packet = RegPackets {
                                        data        : value,
                                        register    : wait_reg};
                out_to_regs.enq(packet);
            end
            else if (p == 2)
            begin
                // Load 16
                Bit #(16) r = truncate(x.data);
                Bit #(`DATA_LENGTH) value = extend(r);

                RegPackets packet = RegPackets {
                    data        : value,
                    register    : wait_reg};
                out_to_regs.enq(packet);
            end
            else if (p == 4)
            begin
                // Load 32
                Bit #(32) r = truncate(x.data);
                Bit #(`DATA_LENGTH) value = extend(r);

                RegPackets packet = RegPackets {
                    data        : value,
                    register    : wait_reg};
                out_to_regs.enq(packet);
            end

            $display (fshow(x));

            wait_load <= False;
            incoming.deq();
        endrule

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

        function Action load (Bit #(`DATA_LENGTH) addr, Regname dst, Bit #(PresentSize #(`BUS_DATA_LEN, `GRANULARITY)) p);
            action
            
            // $display ("Load, ", p);
            Bit #(TAdd #(TMax#(`DATA_LENGTH, `ADDR_LENGTH), 1)) address = extend(addr);
            Chunk #(`BUS_DATA_LEN, `ADDR_LENGTH, `GRANULARITY) x = Chunk {
                                                                        control : Read,
                                                                        data : ?,
                                                                        addr : truncate(address),
                                                                        present : p
                                                                    };
            bus_out.enq(x);
            wait_load <= True;
            wait_reg <= dst;
            endaction
        endfunction

        function store (Bit #(`DATA_LENGTH) data, Bit #(`DATA_LENGTH) addr, Regname dst, Bit #(PresentSize #(`BUS_DATA_LEN, `GRANULARITY)) p);
            action

            
            Bit #(TAdd #(TMax#(`DATA_LENGTH, `ADDR_LENGTH), 1)) address = extend(addr);
            Bit #(TAdd #(TMax#(`DATA_LENGTH, `BUS_DATA_LEN), 1)) data_b = extend(data);

            Chunk #(`BUS_DATA_LEN, `ADDR_LENGTH, `GRANULARITY) x = Chunk {
                                                                        control : Write,
                                                                        data : truncate(data_b),
                                                                        addr : truncate(address),
                                                                        present : p
                                                                    };
            bus_out.enq(x);
            incoming.deq();
            // $display ("STORAGE ADDRESS ", addr);
            endaction
        endfunction
        
        rule exec_master (!wait_load && !wait_store);
            DecodedInstruction x = unpack(incoming.first);
            // $display (fshow(x));
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
            if (x.code == LOAD_8)   load    (x.src1, x.dst, 1);
            if (x.code == LOAD_16)  load    (x.src1, x.dst, 2);
            if (x.code == LOAD_32)  load    (x.src1, x.dst, 4);
            if (x.code == STORE_8)  store   (x.src1, x.src2, x.dst, 1);
            if (x.code == STORE_16) store   (x.src1, x.src2, x.dst, 2);
            if (x.code == STORE_32) incoming.deq();
    
        endrule

        rule debug;
            debug_clk <= debug_clk + 1;
            if(debug_clk>150) $finish();
        endrule 

        interface Get get_branch = toGet(branch);
        interface Put put_decoded = toPut(incoming);
        interface Get send_computed_value = toGet(send_back_to_regs()); // sayooj is
    
        interface Put put_from_bus = toPut(bus_in);
        interface Get get_to_bus = toGet(bus_out);
    endmodule
endpackage : Exec