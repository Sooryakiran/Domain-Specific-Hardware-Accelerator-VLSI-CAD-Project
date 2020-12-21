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

    

    module tests(Empty);
        Exec exec <- mkExec;
        Fetch fetch <- mkFetch;
        Imem imem <-mkImem("../asm/random");

        mkConnection(imem, fetch.imem_client);
        mkConnection (toGet(fetch.get_decoded), toPut(exec.put_decoded));
        mkConnection (toGet(exec.send_computed_value), toPut(fetch.store_to_reg));
    endmodule


endpackage : CPU