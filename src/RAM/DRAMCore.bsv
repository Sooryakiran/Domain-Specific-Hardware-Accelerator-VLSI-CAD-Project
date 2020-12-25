package DRAMCore;
    import StmtFSM::*;
    import Vector::*;
    import CBus::*;
    import EHR::*;

    export DRAM (..);
    export mkDRAM;

    /*----------------------------------------------------------------------
                                Interfaces
    -----------------------------------------------------------------------*/
    interface DRAM #(type block, numeric type size, numeric type offset, numeric type datasize, numeric type addrsize, numeric type ports);
        method block    read  (Bit #(TLog #(size)) addr);
        method Action   write (Bit #(TLog #(size)) addr, block data);
        interface CBus #(addrsize, datasize) bus_wires;
    endinterface : DRAM

    interface DRAMBody #(type block, numeric type size, numeric type offset, numeric type datasize, numeric type addrsize, numeric type ports);
        method block    read  (Bit #(TLog #(size)) addr);
        method Action   write (Bit #(TLog #(size)) addr, block data);
    endinterface

    interface DRAM_csr #(type block, numeric type size, numeric type datasize, numeric type addrsize);
        method Bool read_req();
        method Bool write_req();
        method Action set_idle();
        method Action set_data(block value);
        method block get_data();
        method Bit #(TLog #(size)) get_address();
    endinterface


    /*----------------------------------------------------------------------
                            Module Declarations
    -----------------------------------------------------------------------*/
    

    module [Module] mkDRAM (DRAM #(block, size, offset, datasize, addrsize, ports))
        provisos (Arith #(block), Bits #(block, block_sz));

        IWithCBus #(CBus #(addrsize, datasize), DRAMBody #(block, size, offset, datasize, addrsize, ports)) inst <- exposeCBusIFC(mkDRAMBody);

        interface bus_wires = inst.cbus_ifc;
        interface read      = inst.device_ifc.read;
        interface write     = inst.device_ifc.write;
    endmodule
    

    module [ModWithCBus #(addrsize, datasize)] mkDRAM_csr #(Bit #(addrsize) addr) (DRAM_csr #(block, size, datasize, addrsize))
        provisos (Arith #(block), Bits #(block, block_sz));
        
        Reg #(Bit #(2))            control  <- mkCBRegRW(CRAddr { a: addr,     o : 0}, 0);
        Reg #(Bit #(TLog #(size))) address  <- mkCBRegRW(CRAddr { a: addr + 1, o : 0}, ?);
        Reg #(block)               data_in  <- mkCBRegRW(CRAddr { a: addr + 2, o : 0}, ?);
        Reg #(block)               data_out <- mkCBRegRW(CRAddr { a: addr + 3, o : 0}, ?);
        
        PulseWire read_req_signal <- mkPulseWire;
        PulseWire write_req_signal <- mkPulseWire;
    
        rule master_rule;
            let x = control;
            if (x == 1) read_req_signal.send();
            if (x == 2) write_req_signal.send();
            control <= 0;
        endrule

        method Bool read_req;
            return read_req_signal;
        endmethod : read_req

        method Bool write_req;
            return write_req_signal;
        endmethod : write_req

        method Action set_idle;
            action
                control <= 0;
            endaction
        endmethod

        

        method Action set_data(block value);
            action
                data_out <= value;
            endaction
        endmethod 

        method block get_data();
            return data_in;
        endmethod

        method Bit #(TLog #(size)) get_address();
            return address;
        endmethod

    endmodule

    module [ModWithCBus #(addrsize, datasize)] mkDRAMBody (DRAMBody #(block, size, offset, datasize, addrsize, ports))
        provisos (Arith #(block), Bits #(block, block_sz));

       
        Bit #(kt) hi = 0;
        Bit #(addrsize) offset_value = fromInteger(valueof(offset));
        Integer num_ports = valueOf(ports);

        DRAM_csr #(block, size, datasize, addrsize) csr_s[num_ports];
        
        Vector #(size, EHR #(TAdd #(1, ports), block)) data <- replicateM (mkEHR(?));
        for (Integer i = 0; i < num_ports; i = i + 1)
            csr_s[i] <- mkDRAM_csr(offset_value + 4*fromInteger(i));
        
        
        function Action aux(Integer i);
            action
                if(csr_s[i].read_req())
                    begin 
                        csr_s[i].set_data(data[csr_s[i].get_address()][i]);
                    end
                else
                    begin
                    if(csr_s[i].write_req())
                        begin
                            data[csr_s[i].get_address()][i] <= csr_s[i].get_data();
                        end
                    end
            endaction
        endfunction

        for (Integer j = 0; j < num_ports; j = j + 1)
            rule port_rule;
                aux(j);
            endrule

        method block read   (Bit #(TLog #(size)) addr);
            return data[addr][num_ports];
        endmethod 

        method Action write (Bit #(TLog #(size)) addr, block value);
            data[addr][num_ports] <= value;
        endmethod

    endmodule : mkDRAMBody
    
    

    // module test(Empty);
    //     DRAM #(Bit #(8), 32, 0, 64, 20, 8) my_ram <-mkDRAM;

    //     Stmt tests = seq
            
    //         my_ram.write(1, 23);
    //         // 0, 1, 2, 3
    //         my_ram.bus_wires.write(1, 1);   // address
    //         my_ram.bus_wires.write(0, 1);   // command read
    //         $display("Waiting for read");
    //         action
    //             let x = my_ram.bus_wires.read(3);
    //             $display("%d", x);
    //         endaction

    //         // 4, 5, 6, 7
    //         action
    //             my_ram.bus_wires.write(5, 30);  // Put Address
    //             my_ram.bus_wires.write(6, 100); // Put Value
    //             // my_ram.bus_wires.write(4, 2);   // Write command
    //         endaction
    //         my_ram.bus_wires.write(4, 2);   // Write command
    //         $display("Waiting to write");
    //         action
    //             let x = my_ram.read(30);
    //             $display("%d", x);
    //         endaction


    //         $display("All test Done!");
    //         // $finish(0);
            
    //     endseq;

    //     mkAutoFSM(tests);
    // endmodule : test
endpackage : DRAMCore