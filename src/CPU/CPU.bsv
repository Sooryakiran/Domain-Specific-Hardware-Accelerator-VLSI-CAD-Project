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
    
    module tests(Empty);
        Exec exec <- mkExec;
        Fetch fetch <- mkFetch;
        Imem imem <-mkImem("../asm/random");

        mkConnection (imem, fetch);
        mkConnection (fetch, exec);
        
    endmodule


endpackage : CPU