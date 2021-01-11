////////////////////////////////////////////////////////////////////////////////
//  Author        : Sooryakiran, Ashwini, Shailesh
//  Description   : Creates a minimal CPU
////////////////////////////////////////////////////////////////////////////////

package CPU;

////////////////////////////////////////////////////////////////////////////////
/// Imports
////////////////////////////////////////////////////////////////////////////////

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

////////////////////////////////////////////////////////////////////////////////
/// Exports
////////////////////////////////////////////////////////////////////////////////

export CPU (..);
export mkCPU;
export Exec::*;
export Fetch::*;

////////////////////////////////////////////////////////////////////////////////
/// Interfaces
////////////////////////////////////////////////////////////////////////////////

// An interface ot out CPU to connect with the Instruction Memory and the Bus
// Param wordlength     : Wordlength of out CPU, 32-Bit onwards supported
// Param datalength     : Length of the data registers
// Param busdatalength  : Width of the databus for the bus interface
// Param busaddrlength  : Width of the addressbus for the bus interface
// Param granularity    : Size of the smallest addresable unit. eg 1 Byte in RAMs
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

////////////////////////////////////////////////////////////////////////////////
/// Instances
////////////////////////////////////////////////////////////////////////////////

// Definition to connect the Fetch and the Execute stage
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

// Definintion to connect the instruction memory to the CPU core
instance Connectable #(Imem #(wordlength), 
                        Fetch #(wordlength, datalength));
    module mkConnection #(Imem #(wordlength) i, 
                            Fetch #(wordlength, datalength) f)(Empty);
        mkConnection (i, f.imem_client);
    endmodule
endinstance

// Defintion to connect the Exec unit to a BusMaster wrapper
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

////////////////////////////////////////////////////////////////////////////////
/// Modules
////////////////////////////////////////////////////////////////////////////////

// Creates a minimal 2 stage inorder pipelined CPU
// Param cpu_id : ID of the CPU (only for identification during debug)
// Param rom    : A string containing the path of the init IMEM
module mkCPU #(Integer cpu_id, String rom) (CPU #(wordlength, 
                                                    datalength, 
                                                    busdatalength, 
                                                    busaddrlength, 
                                                    granularity))

    provisos (Add# (na, 32, datalength), 
              Add# (nb, 32, busdatalength), 
              Add# (nc, 16, datalength),
              Add# (nf, 16, busdatalength),
              Add# (nd, 8,  datalength),
              Add# (nh, SizeOf #(Opcode),  datalength),
              Add# (ne, 8,  busdatalength),
              Add# (ni, 1,  busdatalength),
              Add# (ng, busaddrlength, TAdd#(TMax#(datalength, busaddrlength), 1)),
              Add# (wordlength,0, SizeOf #(Instruction #(wordlength))),
              Add# (n_, 16, TAdd#(wordlength, datalength)));

    Exec        #(datalength, 
                    busdatalength, 
                    busaddrlength, 
                    granularity) exec          <- mkExec;
    Fetch       #(wordlength, 
                    datalength) fetch          <- mkFetch;
    Imem        #(wordlength) imem_c           <- mkImem (rom);
    BusMaster   #(busdatalength, 
                    busaddrlength, 
                    granularity) bus_master_c <- mkBusMaster(cpu_id);

    // Connect IMEM to Fetch
    mkConnection (imem_c, fetch);
    // Connect Fetch to Exec
    mkConnection (fetch,  exec);
    // Connect Exec to BusMaster
    mkConnection (exec,   bus_master_c);

    interface imem       = imem_c;
    interface bus_master = bus_master_c;
endmodule

endpackage : CPU