package CPU;

    import StmtFSM::*;
    import FIFOF::*;
    import SpecialFIFOs::*;
    import GetPut::*;
    import Vector::*;
    import ClientServer::*;
    import Connectable::*;


    import CPUDefines::*;
    import InstructionMemory::*;
    import Fetch::*;
    import Exec::*;
    import Bus::*;

    export CPU (..);
    export mkCPU;

    `include <testparams.bsv>

    
    interface CPU #(numeric type wordlength, numeric type datalength, numeric type busdatalength, numeric type busaddrlength, numeric type granularity);
        interface Imem #(wordlength) imem;
        interface BusMaster #(busdatalength, busaddrlength, granularity) bus_master;
    endinterface

    instance Connectable #(Fetch #(wordlength, datalength), Exec #(datalength, busdatalength, busaddrlength, granularity));
        module mkConnection #(Fetch #(wordlength, datalength) f , Exec #(datalength, busdatalength, busaddrlength, granularity) e)(Empty);
            mkConnection (f.get_decoded, e.put_decoded);
            mkConnection (e.send_computed_value, f.store_to_reg);
            mkConnection (e.get_branch, f.put_branch);
        endmodule
    endinstance

    instance Connectable #(Imem #(wordlength), Fetch #(wordlength, datalength));
        module mkConnection #(Imem #(wordlength) i, Fetch #(wordlength, datalength) f)(Empty);
            mkConnection (i, f.imem_client);
        endmodule
    endinstance
    
    instance Connectable #(Exec #(datalength, busdatalength, busaddrlength, granularity), BusMaster #(busdatalength, busaddrlength, granularity));
        module mkConnection #(Exec #(datalength, busdatalength, busaddrlength, granularity) x,
                             BusMaster #(busdatalength, busaddrlength, granularity) m)
                             (Empty);
            mkConnection (x.get_to_bus, m.job_send);
            mkConnection (x.put_from_bus, m.job_done);
        endmodule
    endinstance

    


    module mkCPU #(Integer cpu_id, String rom) (CPU #(wordlength, datalength, busdatalength, busaddrlength, granularity))

        provisos (Add# (na, 32, datalength),     // Datalength always >= 32
                  Add# (nb, 32, busdatalength),  // Busdatalen >= 32
                  Add# (nc, 16, datalength),
                  Add# (nf, 16, busdatalength),
                  Add# (nd, 8,  datalength),
                  Add# (ne, 8,  busdatalength),
                  Add# (ng, busaddrlength, TAdd#(TMax#(datalength, busaddrlength), 1)),
                  Add# (wordlength,0, SizeOf #(Instruction #(wordlength))),
                  Add# (n_, 16, TAdd#(wordlength, datalength)));    // Just to satisfy the compiler


        Exec #(datalength, busdatalength, busaddrlength, granularity) exec <- mkExec;
        Fetch #(wordlength, datalength) fetch <- mkFetch;
        Imem #(wordlength) imem_c <- mkImem (rom);
        BusMaster #(busdatalength, busaddrlength, granularity) bus_master_c <- mkBusMaster(cpu_id);


        mkConnection (imem_c, fetch);
        mkConnection (fetch, exec);
        mkConnection (exec, bus_master_c);

        interface imem = imem_c;
        interface bus_master = bus_master_c;
    endmodule
    
    module tests(Empty);
        Reg #(Bit #(32)) cntr <- mkReg (0);

        CPU #(`WORD_LENGTH, `DATA_LENGTH, `BUS_DATA_LEN, `ADDR_LENGTH, `GRANULARITY) my_core <- mkCPU(1, "../asm/random");

        Vector #(1, BusMaster #(`BUS_DATA_LEN, `ADDR_LENGTH, `GRANULARITY)) master_vec;
        master_vec[0] = my_core.bus_master;

        Vector #(2, BusSlave#(`BUS_DATA_LEN, `ADDR_LENGTH, `GRANULARITY)) my_slaves;
        
        my_slaves[0] <- mkBusSlave(0, 100, 0);
        my_slaves[1] <- mkBusSlave(101, 200, 1);

        Bus #(1, 2, `BUS_DATA_LEN, `ADDR_LENGTH, `GRANULARITY) bus <- mkBus(master_vec, my_slaves);
        
        mkConnection (master_vec, bus);
        mkConnection (my_slaves, bus);

        Chunk #(64, 20, 8) blah = Chunk {
                                    control : Response,
                                    data : 103,
                                    addr : 101,
                                    present : 1};

        Chunk #(64, 20, 8) blah2 = Chunk {
                                        control : Response,
                                        data : 276,
                                        addr : 101,
                                        present : 2};
        rule yaay (cntr == 5);
            // $display ("Changed");
            let x = my_slaves[0].jobs_recieve.get();
            my_slaves[0].jobs_done.put(blah);
        endrule        
        
        
        rule yaay2 (cntr == 16);
        // $display ("Changed");
            let x = my_slaves[0].jobs_recieve.get();
            my_slaves[0].jobs_done.put(blah2);
        endrule          



        rule debug;
            cntr <= cntr + 1;
        endrule
        
    endmodule


endpackage : CPU