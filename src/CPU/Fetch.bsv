package Fetch;
    import FIFOF::*;
    import SpecialFIFOs::*;
    import GetPut::*;
    import Vector::*;
    import ClientServer::*;
    import CPUDefines::*;

    `include <VX_Address.bsv>
    /*----------------------------------------------------------------------
                                Interfaces
    -----------------------------------------------------------------------*/

    interface Registers #(numeric type datalength);
        method Bit #(datalength) load  (Regname name);
        method Action            store (Bit #(datalength) data, Regname name);
    endinterface : Registers

    interface Fetch #(numeric type wordlength, numeric type datalength);
        interface Put    #(Bit #(SizeRegPackets #(datalength)))         store_to_reg;
        interface Put    #(Bit #(datalength))                           put_branch;
        interface Client #(Bit #(wordlength), Bit #(wordlength))        imem_client; 
        interface Get    #(Bit #(DecodedInstructionSize #(datalength))) get_decoded; 
    endinterface

    /*----------------------------------------------------------------------
                            Module Declarations
    -----------------------------------------------------------------------*/

    module mkRegisters (Registers #(datalength));
        Vector #(8, Reg #(Bit #(datalength))) regs <- replicateM(mkRegU);

        method Bit #(datalength) load(Regname name);
            let x = pack(name);
            return ((x<8)? regs[x] : 0);
        endmethod

        method Action store (Bit #(datalength) data, Regname name);
            action
                let x = pack(name);
                if (x < 8)
                begin
                    regs[x] <= data;
                end
            endaction
        endmethod
    endmodule : mkRegisters


    module mkFetch (Fetch #(wordlength, datalength))
        provisos (Add# (wordlength,0, SizeOf #(Instruction #(wordlength))),
                  Add# (n_, 16, TAdd#(wordlength, datalength)),
                  Add# (e__, SizeOf #(Opcode), datalength));
        FIFOF #(Instruction #(wordlength)) instructions   <- mkBypassFIFOF;
        FIFOF #(DecodedInstruction #(datalength)) decoded <- mkPipelineFIFOF;

        Reg #(Bit #(wordlength)) pc         <- mkReg(0);
        Reg #(Bit #(32)) debug_clk          <- mkReg(0);
        Reg #(Bit #(1)) wait_for_next_half  <- mkReg(0);

        Reg #(Bool) busy_vec                <- mkReg(False);
        Reg #(Bit #(4)) vec_states          <- mkRegU;
        Reg #(Bit #(datalength)) vec_address       <- mkRegU;
        Reg #(Regname) waiting_address      <- mkRegU;
        Reg #(Regname) future               <- mkReg(NO);
        Registers #(datalength) regs        <- mkRegisters;
        PulseWire got_instruction           <- mkPulseWire();
        PulseWire wait_instruction          <- mkPulseWire();

        RWire #(RegPackets #(datalength)) store_from_exec     <- mkRWire();
        RWire #(RegPackets #(datalength)) store_from_fetch    <- mkRWire();
        RWire #(Bit #(datalength)) branch                     <- mkRWire();
        
        function Bit #(datalength) check_load (Regname r) ;
            if (r == NO) return 0;
            else return regs.load(r);
        endfunction
        
        function Action store_back_to_regs (Bit #(SizeRegPackets #(datalength)) new_stuff);
            action
                RegPackets #(datalength) x = unpack(new_stuff);
                store_from_exec.wset(x);
            endaction
        endfunction

        function Action put_instructions (Bit #(wordlength) new_stuff);
            action
                Instruction #(wordlength) ins = unpack(new_stuff);
                Instruction #(wordlength) nop = Instruction {
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

        function ActionValue #(Bit #(DecodedInstructionSize #(datalength))) send_decoded;
            actionvalue
                let x = decoded.first();
                decoded.deq();
                return pack(x);
            endactionvalue
        endfunction

        function Action vec_send(Bit #(datalength) val, Bit #(datalength) address);
            action
                DecodedInstruction #(datalength) current = DecodedInstruction {
                                                code : STORE_32,
                                                src1 : val,
                                                src2 : address,  
                                                aux  : ?,
                                                dst  : ?};
                decoded.enq(current);
            endaction
        endfunction

        // `ifndef SMALL_WIDTH
        (* descending_urgency = "master_heavy, store_request" *)
        (* preempts           = "flush_and_branch, master_heavy" *)
        rule master_heavy (valueOf(wordlength) >= 64 && !busy_vec);
            let x = instructions.first();
            // $display("[", debug_clk ,"] PC:", pc, ", ", fshow(instructions.first().code));
            
            if (x.code == ASG_8 || x.code == ASG_16 || x.code == ASG_32)
            begin
                HeavyData #(wordlength, datalength) heavy = unpack(pack(x));
                RegPackets #(datalength) current_store = RegPackets {
                                                data : heavy.data,
                                                register : x.src1};
                store_from_fetch.wset(current_store);
                
                DecodedInstruction #(datalength) current = DecodedInstruction {
                                                            code : NOP,
                                                            src1 : ?,
                                                            src2 : ?,  
                                                            aux  : ?,
                                                            dst  : ?};

                decoded.enq(current);
                instructions.deq();
            end
            else if (x.code == VEC_NEG_I8 || x.code == VEC_NEG_I16 || x.code == VEC_NEG_I32 || x.code == VEC_NEG_F32 ||
                    x.code == VEC_MIN_I8 || x.code == VEC_MIN_I16 || x.code == VEC_MIN_I32 || x.code == VEC_MIN_F32  )
            begin
                $display ("FETCH VEC");
                
                vec_send(check_load(x.src1), `VX_ADDRESS + 1);
                vec_states <= 1;
                busy_vec <= True;
                vec_address <= `VX_ADDRESS;
                
            end
                
            else
                
            begin
                DecodedInstruction #(datalength) current = DecodedInstruction {
                                            code : x.code,
                                            src1 : check_load(x.src1),
                                            src2 : check_load(x.src2),  
                                            aux  : check_load(x.aux),
                                            dst  : x.dst};   
                decoded.enq(current);
                instructions.deq();
            end           
            
        endrule
        
        rule vec_process (busy_vec);
            let x = instructions.first();
            // $display(vec_states, fshow(x));
            if (vec_states == 1) vec_send(check_load(x.src2), vec_address + 2);
            if (vec_states == 2) vec_send(check_load(x.aux),  vec_address + 3);
            if (vec_states == 3) vec_send(extend(pack(x.code)), vec_address + 4);
            if (vec_states == 4) vec_send(check_load(x.dst), vec_address + 6);
            if (vec_states == 5) vec_send(1, vec_address);
            if (vec_states == 6) 
            begin

                DecodedInstruction #(datalength) current = DecodedInstruction {
                            code : x.code,
                            src1 : check_load(x.src1),
                            src2 : check_load(x.src2),  
                            aux  : check_load(x.aux),
                            dst  : ?}; 
                $display ("END");

                decoded.enq(current);
                busy_vec <= False;
                instructions.deq();
            end
            vec_states <= vec_states + 1;
        endrule


        (* descending_urgency = "slave_32_bit, master_32_bit, store_request" *)
        (* preempts           = "flush_and_branch, (master_32_bit, increment_pc)" *)
        rule slave_32_bit (valueOf(wordlength) < 64 && wait_for_next_half == 1 && !busy_vec);
            
            let x = instructions.first();

            Bit #(TAdd #(wordlength, datalength)) temp_data = extend(pack(x));

            RegPackets #(datalength) current_store = RegPackets {
                                                        data     : truncate(temp_data),
                                                        register : waiting_address};

            store_from_fetch.wset(current_store);
            wait_for_next_half <= 0;
            instructions.deq();

            DecodedInstruction #(datalength) current = DecodedInstruction {
                    code : NOP,
                    src1 : ?,
                    src2 : ?,  
                    aux  : ?,
                    dst  : ?};

            decoded.enq(current);
        endrule

        rule master_32_bit (valueOf(wordlength) < 64 && wait_for_next_half == 0 && !busy_vec);
            let x = instructions.first();
            // $display("[", debug_clk ,"] PC:", pc, ", ", fshow(instructions.first().code));
            if(x.code == ASG_32)
            begin
                wait_for_next_half  <= 1;
                waiting_address     <= x.src1;

                instructions.deq();
            end
            else
            begin
                if (x.code == ASG_8 || x.code == ASG_16)
                begin

                    Bit #(TAdd #(wordlength, datalength)) temp_data = extend(pack(x)[22:7]);
                    RegPackets #(datalength) current_store = RegPackets {
                                data        : truncate(temp_data),
                                register    : x.src1};
                    store_from_fetch.wset(current_store);

                    DecodedInstruction #(datalength) current = DecodedInstruction {
                                                code : NOP,
                                                src1 : ?,
                                                src2 : ?,  
                                                aux  : ?,
                                                dst  : ?};

                    decoded.enq(current);
                    instructions.deq();
                end
                else if (x.code == VEC_NEG_I8 || x.code == VEC_NEG_I16 || x.code == VEC_NEG_I32 || x.code == VEC_NEG_F32 ||
                         x.code == VEC_MIN_I8 || x.code == VEC_MIN_I16 || x.code == VEC_MIN_I32 || x.code == VEC_MIN_F32  )
                begin
                    $display ("FETCH VEC_NEG");
                    
                    vec_send(check_load(x.src1), `VX_ADDRESS + 1);
                    vec_states <= 1;
                    busy_vec <= True;
                    vec_address <= `VX_ADDRESS;
                    
                end
                    
                else
                begin
                    DecodedInstruction #(datalength) current = DecodedInstruction {
                                                code : x.code,
                                                src1 : check_load(x.src1),
                                                src2 : check_load(x.src2),  
                                                aux  : check_load(x.aux),
                                                dst  : x.dst};   
                    decoded.enq(current);
                    instructions.deq();
                    // $display ("TEMP2 ", check_load(R3), ",", check_load(R4));
                    // $display ("TEMP1 ", x.src1, ",", x.src2);
                    
                end
            end
            
        endrule
        // `endif
        

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
            // $display ("R1 ", regs.load(R1));
            debug_clk <= debug_clk + 1;
        endrule
    
        rule increment_pc (got_instruction);
            pc <= pc + 1;
        endrule

        rule flush_and_branch (branch.wget() matches tagged Valid .branch_id);
            instructions.clear();
            decoded.clear();

            Bit #(TAdd #(datalength, wordlength)) temp_id = extend(branch_id);
            pc <= truncate(temp_id);

            // $display ("Branch recieved ", branch_id);
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