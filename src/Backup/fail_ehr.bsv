package EHR;
    import StmtFSM::*;

    import Vector::*;

    // interface Ehr #(numeric type n, type a);

    //     // interface Vector #(n, interface Ports #(a)) ports;
    // endinterface

    interface Ports #(type a);
        method Action _write (a x1);
        method a _read();
    endinterface

    module mkEhrU #(Integer n) (Reg #(a) reg_vec[])
        provisos (Bits#(a, a__));
        
        Reg #(a) core <- mkRegU;

        // RWires
        RWire #(a) wire_write[n];
        RWire #(a) wire_main[n+1];

        for (Integer i = 0; i < n; i = i + 1)
        begin
            wire_write[i] <- mkRWire;
            wire_main[i] <- mkRWire;
        end
        wire_main[n] <- mkRWire;


        rule up_date;
            wire_main[0].wset(core);
            if(wire_main[n].wget matches tagged Valid .final_to_write)
                core <= final_to_write;
        endrule

        function Action route(Integer i);
            action
                if (wire_write[i].wget matches tagged Valid .new_write)
                    wire_main[i+1].wset(new_write);
                else if(wire_main[i].wget matches tagged Valid .old_val)
                    wire_main[i+1].wset(old_val);
            endaction
        endfunction

        for (Integer i = 0; i < n; i = i + 1)
        begin
            rule router;
                route(i);
            endrule
        end

        for (Integer i = 0; i < n; i = i + 1)
        begin
            interface reg_vec[i] = ?
        end

  
        
    endmodule

    module test (Empty);

        Array #(Reg #(Bit #(10))) my_ehr <- mkEhrU(10);

        Stmt lol = seq
            $display ("All tests done!");
        endseq;

        mkAutoFSM(lol);

    endmodule

endpackage