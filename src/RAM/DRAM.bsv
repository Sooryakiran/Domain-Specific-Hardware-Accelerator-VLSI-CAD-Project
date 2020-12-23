package DRAM;
    import StmtFSM::*;
    import Vector::*;
    import CBus::*;
    import TLM2::*;
    
    
    `define TLM_PRM_DCL numeric type id_size,   \
                        numeric type addr_size, \
                        numeric type data_size, \
                        numeric type uint_size, \
                        type cstm_type

    `define TLM_PRM     id_size,   \
                        addr_size, \
                        data_size, \
                        uint_size, \
                        cstm_type


    `include "config.bsv"
    // `include "../TLM/TLM2.defines"

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
        // method Bool is_idle();
        method Bool read_req();
        method Bool write_req();
        method Action set_idle();
        method Action set_data(block value);
        method block get_data();
        method Bit #(TLog #(size)) get_address();
    endinterface

    // typedef TLMRecvIFC #(`TLM_PRM) TLM_  DRAM #(`TLM_PRM_DCL);

    // interface DRAM_PORT #(type block, numeric type size, numeric type offset);
        
    // endinterface

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
        
        Reg #(Bit #(2))            control  <- mkCBRegRW(CRAddr { a: addr,     o : 0}, 0);
        Reg #(Bit #(TLog #(size))) address  <- mkCBRegRW(CRAddr { a: addr + 1, o : 0}, ?);
        Reg #(block)               data_in  <- mkCBRegRW(CRAddr { a: addr + 2, o : 0}, ?);
        Reg #(block)               data_out <- mkCBRegRW(CRAddr { a: addr + 3, o : 0}, ?);
        
        PulseWire read_req_signal <- mkPulseWire;
        PulseWire write_req_signal <- mkPulseWire;
    
        rule master_rule;
            let x = control;
            if (x == 1)
                begin
                    read_req_signal.send();
                end
            if (x == 2)
                begin
                    write_req_signal.send();
                end
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

    module [ConfModWithCBus] mkDRAMBody (DRAMBody #(block, size, offset))
        provisos (Arith #(block), Bits #(block, block_sz));

        Bit #(`CONF_CBUS_ADDR_SIZE) offset_value = fromInteger(valueof(offset));
        Integer num_ports_ceil = valueOf(TDiv #(`CONF_CBUS_DATA_SIZE, SizeOf #(block)));
        Integer num_ports      = (num_ports_ceil*valueOf(SizeOf #(block))>`CONF_CBUS_DATA_SIZE)? num_ports_ceil - 1 : num_ports_ceil;
        DRAM_csr #(block, size) csr_s[num_ports];

        Vector #(size, Array #(Reg #(block))) data <- replicateM (mkCRegU(num_ports + 1));

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

        // No worries, this loop will get unrolled
        for (Integer i = 0; i < num_ports; i = i + 1)
            rule port_i_rule;
                aux(i);
            endrule
        
      
        method block read   (Bit #(TLog #(size)) addr);
            return data[addr][num_ports];
        endmethod 

        method Action write (Bit #(TLog #(size)) addr, block value);
            data[addr][num_ports] <= value;
        endmethod

    endmodule : mkDRAMBody
    
    

    module mkTestDRAM(Empty);

        // TLM2RecvIFC #(TLMRequest#(`TLM_PRM), TLMResponse#(`TLM_PRM)) TLM_Ram <- mk
        DRAM #(Bit #(8), 64, 0) my_ram <-mkDRAM;

        Stmt tests = seq
            
            my_ram.write(1, 23);
            // 0, 1, 2, 3
            my_ram.bus_wires.write(1, 1);   // address
            my_ram.bus_wires.write(0, 1);   // command read
            $display("Waiting for read");
            action
                let x = my_ram.bus_wires.read(3);
                $display("%d", x);
            endaction

            // 4, 5, 6, 7
            action
                my_ram.bus_wires.write(5, 34);  // Put Address
                my_ram.bus_wires.write(6, 100); // Put Value
                // my_ram.bus_wires.write(4, 2);   // Write command
            endaction
            my_ram.bus_wires.write(4, 2);   // Write command
            $display("Waiting to write");
            action
                let x = my_ram.read(34);
                $display("%d", x);
            endaction


            $display("All test Done!");
            // $finish(0);
            
        endseq;

        mkAutoFSM(tests);

    endmodule : mkTestDRAM
endpackage : DRAM