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

    /*----------------------------------------------------------------------
                                Interfaces
    -----------------------------------------------------------------------*/
    interface CPU #(numeric type wordlength, 
                    numeric type datalength, 
                    numeric type busdatalength, 
                    numeric type busaddrlength, 
                    numeric type granularity);
        interface Imem #(wordlength) imem;
        interface BusMaster #(busdatalength, 
                              busaddrlength, 
                              granularity) bus_master;
    endinterface

    /*----------------------------------------------------------------------
                                Instances
    -----------------------------------------------------------------------*/

    instance Connectable #(Fetch #(wordlength, 
                                   datalength), 
                           Exec  #(datalength, 
                                   busdatalength, 
                                   busaddrlength, 
                                   granularity));
        module mkConnection #(Fetch #(wordlength, 
                                      datalength) f , 
                              Exec  #(datalength, 
                                      busdatalength, 
                                      busaddrlength, 
                                      granularity) e)(Empty);
            mkConnection (f.get_decoded,         e.put_decoded);
            mkConnection (e.send_computed_value, f.store_to_reg);
            mkConnection (e.get_branch,          f.put_branch);
        endmodule
    endinstance

    instance Connectable #(Imem #(wordlength), 
                          Fetch #(wordlength, datalength));
        module mkConnection #(Imem #(wordlength) i, 
                             Fetch #(wordlength, datalength) f)(Empty);
            mkConnection (i, f.imem_client);
        endmodule
    endinstance
    
    instance Connectable #(Exec #(datalength, 
                                  busdatalength, 
                                  busaddrlength, 
                                  granularity), 
                           BusMaster #(busdatalength, 
                                       busaddrlength, 
                                       granularity));
        module mkConnection #(Exec #(datalength, 
                                     busdatalength, 
                                     busaddrlength, 
                                     granularity) x,
                             BusMaster #(busdatalength, 
                                         busaddrlength, 
                                         granularity) m)
                             (Empty);
            mkConnection (x.get_to_bus,   m.job_send);
            mkConnection (x.put_from_bus, m.job_done);
        endmodule
    endinstance

    module mkCPU #(Integer cpu_id, String rom) (CPU #(wordlength, 
                                                      datalength, 
                                                      busdatalength, 
                                                      busaddrlength, 
                                                      granularity))

        provisos (Add# (na, 32, datalength),     // Datalength always >= 32
                  Add# (nb, 32, busdatalength),  // Busdatalen >= 32
                  Add# (nc, 16, datalength),
                  Add# (nf, 16, busdatalength),
                  Add# (nd, 8,  datalength),
                  Add# (nh, SizeOf #(Opcode),  datalength),
                  Add# (ne, 8,  busdatalength),
                  Add# (ni, 1,  busdatalength),
                  Add# (ng, busaddrlength, TAdd#(TMax#(datalength, busaddrlength), 1)),
                  Add# (wordlength,0, SizeOf #(Instruction #(wordlength))),
                  Add# (n_, 16, TAdd#(wordlength, datalength)));    // Just to satisfy the compiler

        Exec        #(datalength, 
                     busdatalength, 
                     busaddrlength, 
                     granularity) exec          <- mkExec;
        Fetch       #(wordlength, 
                     datalength) fetch          <- mkFetch;
        Imem        #(wordlength) imem_c        <- mkImem (rom);
        BusMaster   #(busdatalength, 
                      busaddrlength, 
                      granularity) bus_master_c <- mkBusMaster(cpu_id);

        mkConnection (imem_c, fetch);
        mkConnection (fetch,  exec);
        mkConnection (exec,   bus_master_c);

        interface imem       = imem_c;
        interface bus_master = bus_master_c;
    endmodule

endpackage : CPU