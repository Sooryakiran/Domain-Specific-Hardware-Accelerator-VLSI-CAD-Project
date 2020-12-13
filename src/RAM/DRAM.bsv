package DRAM;
    import StmtFSM::*;
    import Vector::*;
    import CBus::*;

    `include "config.bsv"
    /*----------------------------------------------------------------------
                                Typedefs
    -----------------------------------------------------------------------*/

    
    /*----------------------------------------------------------------------
                                Interfaces
    -----------------------------------------------------------------------*/
    interface DRAM #(type block, numeric type size, numeric type offset);
        method block    read  (Bit #(TLog #(size)) addr);
        method Action   write (Bit #(TLog #(size)) addr, block data);
        interface ConfCBus bus_wires;
    endinterface : DRAM

    interface DRAMBody #(type block, numeric type size, numeric type offset);
        method block    read  (Bit #(TLog #(size)) addr);
        method Action   write (Bit #(TLog #(size)) addr, block data);
    endinterface

    interface DRAM_csr #(type block, numeric type size);
        method Bool is_idle();
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
    
    module [Module] mkDRAM (DRAM #(block, size, offset))
        provisos (Arith #(block), Bits #(block, block_sz));

        IWithCBus #(ConfCBus, DRAMBody #(block, size, offset)) inst <- exposeCBusIFC(mkDRAMBody);

        interface bus_wires = inst.cbus_ifc;
        interface read      = inst.device_ifc.read;
        interface write     = inst.device_ifc.write;
    endmodule
    
    module [ConfModWithCBus] mkDRAM_csr #(Bit #(`CONF_CBUS_ADDR_SIZE) addr) (DRAM_csr #(block, size))
        provisos (Arith #(block), Bits #(block, block_sz));
        
        Reg #(Bit #(2))            control <- mkCBRegRW(CRAddr { a: addr,     o : 0}, 0);
        Reg #(Bit #(TLog #(size))) address <- mkCBRegRW(CRAddr { a: addr + 1, o : 0}, ?);
        Reg #(block)               data    <- mkCBRegRW(CRAddr { a: addr + 2, o : 0}, ?);
    
        method Bool is_idle;
            return (control == 0);
        endmethod : is_idle

        method Bool read_req;
            return (control == 1);
        endmethod : read_req

        method Bool write_req;
            return (control == 2);
        endmethod : write_req

        method Action set_idle;
            action
                control <= 0;
            endaction
        endmethod

        method Action set_data(block value);
            action
                data <= value;
            endaction
        endmethod 

        method block get_data();
            return data;
        endmethod

        method Bit #(TLog #(size)) get_address();
            return address;
        endmethod


        
    endmodule

    module [ConfModWithCBus] mkDRAMBody (DRAMBody #(block, size, offset))
        provisos (Arith #(block), Bits #(block, block_sz));
        

        Vector #(size, Reg #(block)) data <- replicateM (mkRegU);

        Bit #(`CONF_CBUS_ADDR_SIZE) offset_value = fromInteger(valueof(offset));
        Integer num_ports_ceil = valueOf(TDiv #(`CONF_CBUS_DATA_SIZE, SizeOf #(block)));
        Integer num_ports      = (num_ports_ceil*valueOf(SizeOf #(block))>`CONF_CBUS_DATA_SIZE)? num_ports_ceil - 1 : num_ports_ceil;
        DRAM_csr #(block, size) csr_s[num_ports];


        
        // function cater_read(Integer i);
        //     if(
        // endfunction

        for (Integer i = 0; i < num_ports; i = i + 1)
            csr_s[i] <- mkDRAM_csr(offset_value + 3*fromInteger(i));
        
        
        


        // rule debug;
        //     $display("Num ports %d", num_ports);
        // endrule

        function Action aux(Integer i);
            action
                if(csr_s[i].read_req())
                    begin
                        csr_s[i].set_data(data[csr_s[i].get_address()]);
                        csr_s[i].set_idle();
                    end
                
                if(csr_s[i].write_req())
                    begin
                        data[csr_s[i].get_address()] <= csr_s[i].get_data();
                        csr_s[i].set_idle();
                    end

            endaction
        endfunction

        rule main_rule;
            for (Integer i = 0; i < num_ports; i = i + 1)
                aux(i); 

        endrule
        
        function block read_val (Bit #(TLog #(size)) addr);
            return data[addr];
        endfunction
        
        function Action write_val (Bit #(TLog #(size)) addr, block value);
            action
            data[addr] <= value;
            endaction
        endfunction
      
        method block read   (Bit #(TLog #(size)) addr);
            return data[addr];
        endmethod 

        method Action write (Bit #(TLog #(size)) addr, block value);
            data[addr] <= value;
        endmethod

    endmodule : mkDRAMBody

    module mkTestDRAM(Empty);

        DRAM #(Bit #(8), 64, 1) my_ram <-mkDRAM;

        Stmt tests = seq
            
            my_ram.write(1, 23);
            action
                let x = my_ram.bus_wires.read(3);
                $display("Value %d", x);
            endaction

            $display("All test Done!");
            $finish(0);
            
        endseq;

        mkAutoFSM(tests);

    endmodule : mkTestDRAM
endpackage : DRAM