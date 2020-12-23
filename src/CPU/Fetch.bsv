package Fetch;
    import FIFOF::*;
    import SpecialFIFOs::*;
    import GetPut::*;
    import Vector::*;
    import ClientServer::*;

    `include <config.bsv>

    /*----------------------------------------------------------------------
                                Interfaces
    -----------------------------------------------------------------------*/

    interface Registers;
        method Bit #(`DATA_LENGTH)  load  (Regname name);
        method Action               store (Bit #(`DATA_LENGTH) data, Regname name);
    endinterface : Registers

    interface Fetch;
        interface Put #(Bit #(SizeOf #(RegPackets)))                store_to_reg;
        interface Put #(Bit #(`DATA_LENGTH))                        put_branch;
        interface Client #(Bit #(`PC_SIZE), Bit #(`WORD_LENGTH))    imem_client; 
        interface Get #(Bit #(`DecodedInstructionSize))             get_decoded; 
    endinterface

    /*----------------------------------------------------------------------
                            Module Declarations
    -----------------------------------------------------------------------*/

    module mkRegisters (Registers);
        Vector #(8, Reg #(Bit #(`DATA_LENGTH))) regs <- replicateM(mkRegU);

        method Bit #(`DATA_LENGTH) load(Regname name);
            let x = pack(name);
            return ((x<8)? regs[x] : 0);
        endmethod

        method Action store (Bit #(`DATA_LENGTH) data, Regname name);
            action
                let x = pack(name);
                if (x < 8)
                begin
                    regs[x] <= data;
                end
            endaction
        endmethod
    endmodule : mkRegisters


    module mkFetch (Fetch);
        FIFOF #(Instruction) instructions   <- mkBypassFIFOF;
        FIFOF #(DecodedInstruction) decoded <- mkPipelineFIFOF;

        Reg #(Bit #(`PC_SIZE)) pc           <- mkReg(0);
        Reg #(Bit #(32)) debug_clk          <- mkReg(0);
        Reg #(Bit #(1)) wait_for_next_half  <- mkReg(0);
        Reg #(Regname) waiting_address      <- mkRegU;
        Reg #(Regname) future               <- mkReg(NO);
        Registers regs                      <- mkRegisters;
     
        PulseWire got_instruction               <- mkPulseWire();
        PulseWire wait_instruction              <- mkPulseWire();

        RWire #(RegPackets) store_from_exec     <- mkRWire();
        RWire #(RegPackets) store_from_fetch    <- mkRWire();
        RWire #(Bit #(`DATA_LENGTH)) branch     <- mkRWire();
        
        function Bit #(`DATA_LENGTH) check_load (Regname r) ;
            if (r == NO) return 0;
            else return regs.load(r);
        endfunction
        
        function Action store_back_to_regs (Bit #(SizeOf #(RegPackets)) new_stuff);
            action
                RegPackets x = unpack(new_stuff);
                store_from_exec.wset(x);
            endaction
        endfunction

        function Action put_instructions (Bit #(`WORD_LENGTH) new_stuff);
            action
                Instruction ins = unpack(new_stuff);
                Instruction nop = Instruction {
                                    code : NOP,
                                    src1 : NO,
                                    src2 : NO,
                                    aux  : NO,
                                    dst  : NO,
                                    pad  : ?};

                if (future != NO && (future == ins.src1 || future == ins.src2) && wait_for_next_half == 0)
                begin
                    instructions.enq(nop);
                    future <= NO;
                end
                else
                begin
                    instructions.enq(ins);
                    future <= ins.dst;
                    got_instruction.send();
                end
            endaction
        endfunction

        function ActionValue #(Bit #(`DecodedInstructionSize)) send_decoded;
            actionvalue
                let x = decoded.first();
                decoded.deq();
                return pack(x);
            endactionvalue
        endfunction

        `ifndef SMALL_WIDTH
        (* descending_urgency = "master_heavy, store_request" *)
        (* preempts           = "flush_and_branch, master_heavy" *)
        rule master_heavy (`WORD_LENGTH >= 64 );
            let x = instructions.first();
            $display("[", debug_clk ,"] PC:", pc, ", ", fshow(instructions.first().code));
            
            if (x.code == ASG_8 || x.code == ASG_16 || x.code == ASG_32)
            begin
                HeavyData heavy = unpack(pack(x));
                RegPackets current_store = RegPackets {
                                                data : heavy.data,
                                                register : x.src1};
                store_from_fetch.wset(current_store);
                
            end
            else
            begin
                DecodedInstruction current = DecodedInstruction {
                                            code : x.code,
                                            src1 : check_load(x.src1),
                                            src2 : check_load(x.src2),  
                                            aux  : check_load(x.aux),
                                            dst  : x.dst};   
                decoded.enq(current);
            end           
            instructions.deq();
        endrule
        `endif

        `ifndef HEAVY_WIDTH
        (* descending_urgency = "slave_32_bit, master_32_bit, store_request" *)
        (* preempts           = "flush_and_branch, (master_32_bit, increment_pc)" *)
        rule slave_32_bit (`WORD_LENGTH < 64 && wait_for_next_half == 1);
            
            let x = instructions.first();

            RegPackets current_store = RegPackets {
                            data     : extend(pack(x)),
                            register : waiting_address};

            store_from_fetch.wset(current_store);
            wait_for_next_half <= 0;
            instructions.deq();
        endrule

        rule master_32_bit (`WORD_LENGTH < 64 && wait_for_next_half == 0 );
            let x = instructions.first();
            $display("[", debug_clk ,"] PC:", pc, ", ", fshow(instructions.first().code));
            if(x.code == ASG_32)
            begin
                wait_for_next_half  <= 1;
                waiting_address     <= x.src1;
            end
            else
            begin
                if (x.code == ASG_8 || x.code == ASG_16)
                begin
                    RegPackets current_store = RegPackets {
                                data        : extend(pack(x)[22:7]),
                                register    : x.src1};
                    store_from_fetch.wset(current_store);
                end
                else
                begin
                    DecodedInstruction current = DecodedInstruction {
                                                code : x.code,
                                                src1 : check_load(x.src1),
                                                src2 : check_load(x.src2),  
                                                aux  : check_load(x.aux),
                                                dst  : x.dst};   
                    decoded.enq(current);
                end
            end
            instructions.deq();
        endrule
        `endif
        

        rule store_request;
            if(store_from_exec.wget() matches tagged Valid .packet_ex)
            begin
                if(store_from_fetch.wget() matches tagged Valid .packet_ft)
                begin
                    if(packet_ex.register != packet_ft.register)
                    begin
                        regs.store(packet_ex.data, packet_ex.register);
                        regs.store(packet_ft.data, packet_ft.register);
                    end
                    else regs.store(packet_ft.data, packet_ft.register);
                end
                else regs.store(packet_ex.data, packet_ex.register);
            end
            else if(store_from_fetch.wget() matches tagged Valid .packet_ft) 
            begin 
                regs.store(packet_ft.data, packet_ft.register);
            end
        endrule

        rule debug_clk_upd;
            debug_clk <= debug_clk + 1;
        endrule
    
        rule increment_pc (got_instruction);
            pc <= pc + 1;
        endrule

        rule flush_and_branch (branch.wget() matches tagged Valid .branch_id);
            instructions.clear();
            decoded.clear();
            pc <= branch_id;

            $display ("Branch recieved ", branch_id);
        endrule

        interface Put store_to_reg  = toPut(store_back_to_regs());

        interface Client imem_client;
            interface Get request   = toGet(pc);
            interface Put response  = toPut(put_instructions);
        endinterface

        interface Get get_decoded   = toGet(send_decoded());
        interface Put put_branch    = toPut(branch);
    endmodule : mkFetch

endpackage