package Exec;
    import FIFOF::*;
    import SpecialFIFOs::*;
    import GetPut::*;
    import Vector::*;
    import ClientServer::*;

    `include <config.bsv>

    interface Exec;
        interface Put #(Bit #(`DecodedInstructionSize)) put_decoded;  
        interface Get #(Bit #(SizeOf #(RegPackets))) send_computed_value;
    endinterface

    module mkExec (Exec);
        FIFOF #(Bit #(`DecodedInstructionSize)) incoming <- mkBypassFIFOF;
        FIFOF #(RegPackets) out_to_regs <- mkBypassFIFOF;

        Reg #(Bit #(32)) debug_clk <- mkReg(0);

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
                                        data : value,
                                        register : name
                                    };
                out_to_regs.enq(packet);
            endaction
        endfunction

        rule exec_master;
            DecodedInstruction x = unpack(incoming.first);
            $display(fshow(x.code));

            if (x.code == MOV) mov (x.src1, x.dst);

            incoming.deq();
        endrule

        rule debug;
            debug_clk <= debug_clk + 1;
            if(debug_clk>25) $finish();
        endrule 


        interface Put put_decoded = toPut(incoming);
        interface Get send_computed_value = toGet(send_back_to_regs()); // sayooj is
    endmodule
endpackage : Exec