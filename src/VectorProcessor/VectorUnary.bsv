package VectorUnary;
    import GetPut::*;
    import FIFOF::*;
    import SpecialFIFOs::*;
    import Connectable::*;

    import Bus::*;

    import VectorMemoryController::*;
    import VectorUnaryFetch::*;
    import VectorDefines::*;
    import VectorCSR::*;
    import VectorExec::*;

    export VectorUnary (..);
    export mkVectorUnary;
    interface VectorUnary #(numeric type datasize,
                             numeric type vectordatasize,
                             numeric type busdatasize,
                             numeric type busaddrsize,
                             numeric type granularity);

        interface BusMaster #(busdatasize, busaddrsize, granularity) bus_master;
        interface BusSlave  #(busdatasize, busaddrsize, granularity) bus_slave;
        
    endinterface

    module mkVectorUnary #(Bit #(busaddrsize) address, Integer temp_storage_size, Integer id) (VectorUnary #(datasize, vectordatasize, busdatasize, busaddrsize, granularity))
        provisos (Add #(na, datasize, busdatasize), 
                  Add #(nb, 1,        busdatasize), 
                  Add #(nc, SizeOf #(Opcode), busdatasize), 
                  Add #(nd, vectordatasize, busdatasize),
                  Mul #(ne, granularity, vectordatasize),
                  Add #(nf, PresentSize #(vectordatasize, granularity), PresentSize #(busdatasize, granularity)),
                  Add #(ng, 8, vectordatasize),
                  Add #(nh, 16, vectordatasize),
                  Add #(ni, 32, vectordatasize),
                  Add #(nj, 8,  busdatasize),
                  Add #(nk, 16, busdatasize),
                  Add #(nl, 32, busdatasize));

        VectorUnaryCSR #(datasize, busdatasize, busaddrsize, granularity) csr <- mkVectorUnaryCSR (address);
        BusMaster #(busdatasize, busaddrsize, granularity) bus_master_c <- mkBusMaster(id);
        BusSlave  #(busdatasize, busaddrsize, granularity) bus_slave_c  <- mkBusSlave(address, address + 6, id);
        mkConnection (csr, bus_slave_c);

        VectorUnaryFetch #(datasize, vectordatasize, busdatasize, busaddrsize, granularity) fetch <- mkVectorUnaryFetch (temp_storage_size);
        mkConnection (fetch, csr);

        VectorMemoryController #(busdatasize, busaddrsize, granularity) mcu <- mkVectorMemoryController;
        mkConnection (fetch, mcu);
        mkConnection (mcu, bus_master_c);

        VectorExec #(datasize, vectordatasize, busdatasize, busaddrsize, granularity) exec <- mkVectorExec;
        mkConnection (fetch, exec);
        mkConnection (exec, mcu);
        
        mkConnection(mcu, csr);

        interface bus_slave = bus_slave_c;
        interface bus_master = bus_master_c;
    endmodule

    // module test (Empty);
    //     Reg #(Bit #(32)) debug_clk <- mkReg(0);

    //     rule rl_debug;
    //         debug_clk <= debug_clk + 1;
    //         if (debug_clk > 20) $finish();
    //     endrule
    // endmodule


endpackage
