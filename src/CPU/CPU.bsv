package CPU;

    import StmtFSM::*;
    import FIFOF::*;
    import SpecialFIFOs::*;
    import GetPut::*;
    import Vector::*;
    import ClientServer::*;
    import Connectable::*;

    import InstructionMemory::*;
    import Fetch::*;
    import Exec::*;
    import Bus::*;

    `include <config.bsv>

    instance Connectable #(Fetch, Exec);
        module mkConnection #(Fetch f, Exec e)(Empty);
            mkConnection (f.get_decoded, e.put_decoded);
            mkConnection (e.send_computed_value, f.store_to_reg);
            mkConnection (e.get_branch, f.put_branch);
        endmodule
    endinstance

    instance Connectable #(Imem, Fetch);
        module mkConnection #(Imem i, Fetch f)(Empty);
            mkConnection (i, f.imem_client);
        endmodule
    endinstance
    
    instance Connectable #(Exec, BusMaster #(`BUS_DATA_LEN, `ADDR_LENGTH, `GRANULARITY));
        module mkConnection #(Exec x,
                             BusMaster #(`BUS_DATA_LEN, `ADDR_LENGTH, `GRANULARITY) m)
                             (Empty);
            mkConnection (x.get_to_bus, m.job_send);
            mkConnection (x.put_from_bus, m.job_done);
        endmodule
    endinstance

    
    interface CPU;
        interface Imem imem;
        interface BusMaster #(`BUS_DATA_LEN, `ADDR_LENGTH, `GRANULARITY) bus_master;
    endinterface

    module mkCPU #(Integer cpu_id, String rom) (CPU);
        Exec exec <- mkExec;
        Fetch fetch <- mkFetch;
        Imem imem_c <- mkImem (rom);
        BusMaster #(`BUS_DATA_LEN, `ADDR_LENGTH, `GRANULARITY) bus_master_c <- mkBusMaster(cpu_id);


        mkConnection (imem_c, fetch);
        mkConnection (fetch, exec);
        mkConnection (exec, bus_master_c);

        interface imem = imem_c;
        interface bus_master = bus_master_c;
    endmodule
    
    module tests(Empty);
        Reg #(Bit #(32)) cntr <- mkReg (0);

        CPU my_core <- mkCPU(1, "../asm/random");

        Vector #(1, BusMaster #(`BUS_DATA_LEN, `ADDR_LENGTH, `GRANULARITY)) master_vec;
        master_vec[0] = my_core.bus_master;

        Vector #(2, BusSlave#(`BUS_DATA_LEN, `ADDR_LENGTH, `GRANULARITY)) my_slaves;
        
        my_slaves[0] <- mkBusSlave(0, 100, 0);
        my_slaves[1] <- mkBusSlave(101, 200, 1);

        Bus #(1, 2, `BUS_DATA_LEN, `ADDR_LENGTH, `GRANULARITY) bus <- mkBus(master_vec, my_slaves);
        
        mkConnection (master_vec, bus);
        mkConnection (my_slaves, bus);

        Chunk #(64, 32, 8) blah = Chunk {
                                    control : Response,
                                    data : 103,
                                    addr : 101,
                                    present : 1};

        Chunk #(64, 32, 8) blah2 = Chunk {
                                        control : Response,
                                        data : 276,
                                        addr : 101,
                                        present : 2};
        rule yaay (cntr == 5);
            // $display ("Changed");
            let x = my_slaves[0].jobs_recieve.get();
            my_slaves[0].jobs_done.put(blah);
        endrule        
        
        
        rule yaay2 (cntr == 8);
        // $display ("Changed");
            let x = my_slaves[1].jobs_recieve.get();
            my_slaves[1].jobs_done.put(blah2);
        endrule          



        rule debug;
            cntr <= cntr + 1;
        endrule
        
    endmodule


endpackage : CPU