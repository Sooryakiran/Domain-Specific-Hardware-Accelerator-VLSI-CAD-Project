package DRAMSlave;
    import StmtFSM::*;

    import DRAMCore::*;
    import Bus::*;
    import FIFOF::*;
    import SpecialFIFOs::*;
    import GetPut::*;
    import CBus::*;
    import List::*;

    interface DRAMSlave #(type block, numeric type size, numeric type offset, numeric type datasize, numeric type addrsize, numeric type ports);
        interface BusSlave #(offset, addrsize, SizeOf #(block)) dram_slave;
    endinterface

    interface DRAMWrapper #(type block, numeric type size, numeric type offset, numeric type datasize, numeric type addrsize, numeric type ports);
        interface Get #(Chunk #(datasize, addrsize, SizeOf #(block))) get_responses;
        interface Put #(Chunk #(datasize, addrsize, SizeOf #(block))) put_requests;
    endinterface

    module [Module] mkDRAMWrapper #(Integer id) (DRAMWrapper #(block, size, offset, datasize, addrsize, ports))
        provisos (Arith #(block), Bits #(block, block_sz));

        Integer num_ports = valueOf(ports);
        Integer num_offset = valueOf(offset);
        Integer num_block_size = valueOf(SizeOf #(block));

        FIFOF #(Chunk #(datasize, addrsize, SizeOf #(block))) requests <- mkBypassFIFOF;
        FIFOF #(Chunk #(datasize, addrsize, SizeOf #(block))) responses <- mkBypassFIFOF;

        DRAM #(block, size, offset, datasize, addrsize, ports) my_ram <-mkDRAM;        

        Reg #(Bool) reading <- mkReg (False);
        Reg #(Bool) writing <- mkReg (False);

        Reg #(Chunk #(datasize, addrsize, SizeOf #(block))) read_chunk <- mkRegU;
        
        rule check_requests (!(reading || writing));
            let x = requests.first(); requests.deq();
            if (x.control == Read)
            begin
                $display ("Read Req");
                read_chunk <= x;
                for (Integer i = 0; i < num_ports; i = i + 1)
                begin
                    if( fromInteger(i) < x.present)
                    begin
                        $display (i);
                        Bit #(addrsize) control_addr = fromInteger (num_offset) + 4* fromInteger(i);

                        Bit #(TAdd#(datasize, addrsize)) temp_addr = extend(x.addr);
                        Bit #(datasize) address = truncate(temp_addr);

                        my_ram.bus_wires.write(control_addr, 1); // Command read
                        my_ram.bus_wires.write(control_addr + 1,  address + fromInteger(i)); // address 
                    end
                end
                reading <= True;
            end
            else if (x.control == Write)
            begin
                $display ("Write Req");
                for (Integer i = 0; i < num_ports; i = i + 1)
                begin
                    if( fromInteger(i) < x.present)
                    begin
                        Bit #(addrsize) control_addr = fromInteger (num_offset) + 4* fromInteger(i);

                        Bit #(TAdd#(datasize, addrsize)) temp_addr = extend(x.addr);
                        Bit #(datasize) address = truncate(temp_addr);

                        Bit #(datasize) all_data = pack(x.data);
                        Bit #(datasize) current_data = all_data[fromInteger(i+1)*fromInteger(num_block_size)-1:fromInteger(i)*fromInteger(num_block_size)];

                        my_ram.bus_wires.write(control_addr, 2); // Command write
                        my_ram.bus_wires.write(control_addr + 1,  address + fromInteger(i)); // address 
                        my_ram.bus_wires.write(control_addr + 2, current_data); // data
                        
                        // $display ("%b | %b", x.data, current_data);
                        
                    end
                end
                writing <= True;
            end 
        endrule

        rule rl_read (reading == True);
            let x = read_chunk;
            $display ("Read response");

            // List #(Bit #(8)) t = {0, 1, 2, 3, 4};
            Bit #(datasize) data[num_ports+1];

            data[0] = 0;

            
            for (Integer i = 0; i < num_ports; i = i + 1)
            begin
                if (fromInteger(i) < x.present)
                begin
                    Bit #(addrsize) control_addr = fromInteger (num_offset) + 4* fromInteger(i);

                    // let r <- my_ram.bus_wires.read(0);
                    
                    data[i+1] = data[i] + 0 << num_block_size;
                end
            end

            $display ("%b", data[num_ports]);
            reading <= False;
        endrule

        rule rl_write (writing == True);
            Chunk #(datasize, addrsize, SizeOf #(block)) write_response = Chunk {
                                                                            control : Response,
                                                                            data : ?,
                                                                            addr : ?,
                                                                            present : ?};
            responses.enq(write_response);
            writing <= False;
        endrule

        interface get_responses = toGet (responses);
        interface put_requests = toPut (requests);
        
    endmodule

    module [Module] mkDRAMSlave #(Integer id) (DRAMSlave #(block, size, offset, datasize, addrsize, ports))
        provisos (Arith #(block), Bits #(block, block_sz));
        
        DRAMWrapper #(block, size, offset, datasize, addrsize, ports) my_ram <- mkDRAMWrapper(0);


        Reg #(Bit #(32)) cntr <- mkReg(0);

        Chunk #(datasize, addrsize, SizeOf #(block)) blah2 = Chunk {
            control : Read,
            data : 125623,
            addr : 4,
            present : 3};

        rule send (cntr == 2);
            my_ram.put_requests.put(blah2);
        endrule

        rule debug_clk;
            cntr <= cntr + 1;
            if (cntr > 20) $finish();
        endrule

        
  
    endmodule


    module [Module] test (Empty);

        

        DRAMSlave #(Bit #(8), 64, 0, 32, 20, 4) my_slave <- mkDRAMSlave(0);
        
        



        // Stmt lol = seq



        // $display("All tests done!");
        // endseq;

        // mkAutoFSM(lol);
    endmodule
endpackage