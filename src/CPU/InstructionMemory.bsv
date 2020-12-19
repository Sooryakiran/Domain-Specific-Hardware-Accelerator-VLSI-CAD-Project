package InstructionMemory;

    `include <config.bsv>

    import RegFile::*;
    import FIFO::*;
    import GetPut::*;
    import ClientServer::*;
    import StmtFSM::*;
    
    typedef Server #(Bit #(`PC_SIZE), Bit #(`WORD_LENGTH)) Imem;

    module mkImem #(String rom) (Imem);
        RegFile #(Bit #(`PC_SIZE), Bit #(`WORD_LENGTH)) memory <- mkRegFileFullLoad(rom);
        // FIFO #(Bit #(`PC_SIZE)) res <- mkFIFO;
        Reg #(Bit #(`WORD_LENGTH)) res <- mkReg(0);

        RWire #(Bit #(`WORD_LENGTH)) fast <- mkRWire();
        function Action put_stuff (Bit #(`PC_SIZE) addr);
            action
                res <= memory.sub(addr);
                fast.wset(memory.sub(addr));
            endaction
        endfunction

        interface response = toGet(fromMaybe(?, fast.wget()));
        interface request = toPut(put_stuff);

    endmodule


    // module tests (Empty);
    //     Imem my_imem <- mkImem;
    //     Bit #(32) x = 32;
    //     Stmt test = seq
    //         $display("Starting %d", x);
    //         my_imem.request;
    //         // $display(my_imem.response);
    //     endseq;

    //     mkAutoFSM(test);

    // endmodule

endpackage : InstructionMemory