////////////////////////////////////////////////////////////////////////////////
//  Author        : Sooryakiran, Ashwini, Shailesh
//  Description   : The vector Unary Unit
////////////////////////////////////////////////////////////////////////////////

package VectorUnary;

////////////////////////////////////////////////////////////////////////////////
/// Imports
////////////////////////////////////////////////////////////////////////////////

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

////////////////////////////////////////////////////////////////////////////////
/// Exports
////////////////////////////////////////////////////////////////////////////////

export VectorUnary (..);
export mkVectorUnary;

////////////////////////////////////////////////////////////////////////////////
/// Interfaces
////////////////////////////////////////////////////////////////////////////////

// Interface of the Vector accelerator
// Param datasize       : Datasize of the Registers
// Param vectordatasize : Number of bits that can be parallelly operated upon
// Param busdatasize    : Width of the databus
// Param busaddrsize    : Width of the address bus
// Param granularity    : The smallest addressable unit size
interface VectorUnary #(numeric type datasize,
                        numeric type vectordatasize,
                        numeric type busdatasize,
                        numeric type busaddrsize,
                        numeric type granularity);

    interface BusMaster #(busdatasize, busaddrsize, granularity) bus_master;
    interface BusSlave  #(busdatasize, busaddrsize, granularity) bus_slave;
    
endinterface

////////////////////////////////////////////////////////////////////////////////
/// Modules
////////////////////////////////////////////////////////////////////////////////

// Creates a vector unary accelerator
// Param address           : Memory mapped address of the accelerator
// Param temp_storage_size : Size of the temp. data storage FIFOFs
// Param id                : ID of the unit
module mkVectorUnary #(Bit #(busaddrsize) address, 
                       Integer temp_storage_size, 
                       Integer id) (VectorUnary #(datasize, 
                                                  vectordatasize, 
                                                  busdatasize, 
                                                  busaddrsize, 
                                                  granularity))
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
    // Connect the fetch to CSR
    mkConnection (fetch, csr);

    VectorMemoryController #(busdatasize, busaddrsize, granularity) mcu <- mkVectorMemoryController;
    // Connect the fetch to memory controller
    mkConnection (fetch, mcu);
    // Connect to memory controller to bus master ifc
    mkConnection (mcu, bus_master_c);

    VectorExec #(datasize, vectordatasize, busdatasize, busaddrsize, granularity) exec <- mkVectorExec;
    // Connect the fetch to execute
    mkConnection (fetch, exec);
    // Connect the execute and memory controller
    mkConnection (exec, mcu);
    
    mkConnection(mcu, csr);

    interface bus_slave = bus_slave_c;
    interface bus_master = bus_master_c;
endmodule

endpackage
