package example;
    
    import AHB::*;
    import StmtFSM::*;
    
    module mkExample (Empty);

        Reg #(Bit #(32)) just_reg <-mkRegU;

        // AhbMasterXActor #(TLMRequest #(`BUSCONFIG), TLMResponse #(`BUSCONFIG),  `BUSCONFIG) master_x_1 <- mkAhbMaster(3);

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
