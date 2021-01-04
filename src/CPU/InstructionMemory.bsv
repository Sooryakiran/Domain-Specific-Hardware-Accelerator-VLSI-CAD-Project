package InstructionMemory;

    import RegFile::*;
    import GetPut::*;
    import ClientServer::*;

    /*----------------------------------------------------------------------
                                Typedefs
    -----------------------------------------------------------------------*/
    typedef Server #(Bit #(wordlength), Bit #(wordlength)) Imem #(numeric type wordlength);

    /*----------------------------------------------------------------------
                            Module Declarations
    -----------------------------------------------------------------------*/

    module mkImem #(String rom) (Imem #(wordlength));
        RegFile #(Bit #(wordlength), Bit #(wordlength)) memory  <- mkRegFileFullLoad(rom);
        RWire   #(Bit #(wordlength))                  fast    <- mkRWire();

        function Action put_stuff (Bit #(wordlength) addr);
            action
                fast.wset(memory.sub(addr));
            endaction
        endfunction
        
        interface response  = toGet(fromMaybe(?, fast.wget()));
        interface request   = toPut(put_stuff);
    endmodule



endpackage : InstructionMemory