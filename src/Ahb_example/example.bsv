package example;
    // import"../ABH/AHB.bsv"
    import Ahb::*;
    import TLM3::*;
    import StmtFSM::*;
    // import TLM2Defines::*;

    `include "TLM.defines"

    `define BUSCONFIG   4, 16, 32, 10, 0
    `define CONTENTS    TLMRequest#(`BUSCONFIG), TLMResponse#(`BUSCONFIG) 

    module mkExample (Empty);

        Reg #(Bit #(32)) just_reg <-mkRegU;


        // function ActionValue #(TLMResponse #(`BUSCONFIG)) get_response(Bit #(32) value);
        //     actionvalue
        //         TLMData #(`BUSCONFIG)     message = value;
        //         TLMResponse #(`BUSCONFIG) out = TLMResponse {
        //                                             command : READ,
        //                                             data : message,
        //                                             prty : 1,
        //                                             thread_id : 1,
        //                                             transaction_id : 1,
        //                                             export_id : 1,
        //                                             custom : 0
        //                                             };
        //         return out;
        //     endactionvalue
        // endfunction


        // One slaveX
        // function Bool addr_match_slave_1(AHBAddr #(`BUSCONFIG) addr);
        //     return True;
        // endfunction

        // AHBSlaveXActor     #(`TLM_RR_STD, `TLM_PRM_STD) slave_x_1 <- mkAHBSlaveStd (addr_match_slave_1);
        // AHBSlaveXActor #(`CONTENTS, `BUSCONFIG) slave_x_1 <- mkAHBSlave (addr_match_slave_1);
        
        // One MasterX

        AhbMasterXActor #(TLMRequest #(`BUSCONFIG), TLMResponse #(`BUSCONFIG),  `BUSCONFIG) master_x_1 <- mkAhbMaster(3);

        Stmt tests = seq
            action
                // let x <- just_reg;
                // slave_x_1.tlm.tx(get_response(x, x));
            endaction
            $display ("All tests finished!");
        endseq;

        mkAutoFSM(tests);
    endmodule
endpackage
