package FIFOSingle;
    
    import StmtFSM::*;

    interface FIFOSingle #(type t);
        method Action enq(t elem);
        method t first();
        method Action deq();
        method Action clear();
    endinterface

    module mkFIFOSingle (FIFOSingle #(t))
        provisos (Bits #(t, ts));
        Reg #(t) storage <- mkRegU;
        Reg #(Bool) is_present <- mkReg(False);
        
        method Action enq(t elem); if (is_present == False)
            action
                storage <= elem;
                is_present <= True;
            endaction
        endmethod

        method t first() if (is_present);
            return storage;                
        endmethod

        method Action deq();
            is_present <= False;
        endmethod

        method Action clear();
            is_present <= False;
        endmethod
    endmodule
endpackage : FIFOSingle