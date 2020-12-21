package InstructionMemory;

    import RegFile::*;
    import GetPut::*;
    import ClientServer::*;

    `include <config.bsv>
    
    /*----------------------------------------------------------------------
                                Typedefs
    -----------------------------------------------------------------------*/
    typedef Server #(Bit #(`PC_SIZE), Bit #(`WORD_LENGTH)) Imem;

    /*----------------------------------------------------------------------
                            Module Declarations
    -----------------------------------------------------------------------*/

    module mkImem #(String rom) (Imem);
        RegFile #(Bit #(`PC_SIZE), Bit #(`WORD_LENGTH)) memory  <- mkRegFileFullLoad(rom);
        RWire   #(Bit #(`WORD_LENGTH))                  fast    <- mkRWire();

        function Action put_stuff (Bit #(`PC_SIZE) addr);
            action
                fast.wset(memory.sub(addr));
            endaction
        endfunction

        interface response  = toGet(fromMaybe(?, fast.wget()));
        interface request   = toPut(put_stuff);
    endmodule



endpackage : InstructionMemory