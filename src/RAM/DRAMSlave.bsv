////////////////////////////////////////////////////////////////////////////////
//  Author        : Sooryakiran, Ashwini, Shailesh
//  Description   : The RAM and its BusSlave wrapper
////////////////////////////////////////////////////////////////////////////////

package DRAMSlave;

////////////////////////////////////////////////////////////////////////////////
/// Imports
////////////////////////////////////////////////////////////////////////////////

import DRAMCore::*;
import Bus::*;
import FIFOF::*;
import SpecialFIFOs::*;
import GetPut::*;
import CBus::*;
import List::*;
import Vector::*;
import EHR::*;
import Connectable::*;

////////////////////////////////////////////////////////////////////////////////
/// Imports
////////////////////////////////////////////////////////////////////////////////

export DRAMSlave (..);
export DRAMWrapper (..);
export mkDRAMSlave;
export mkDRAMWrapper;

////////////////////////////////////////////////////////////////////////////////
/// Interfaces
////////////////////////////////////////////////////////////////////////////////

// An interface for our BusSlave wrapper
// Param block      : Type of individual units
// Param size       : Size of the ram
// Param offset     : Offset address of the ram
// Param datasize   : Width of the databus
// Param addrsize   : Width of the address bus
// Param ports      : Number of ports for the RAM  
interface DRAMSlave #(numeric type blocksize,
                     numeric type size,
                     numeric type offset, 
                     numeric type datasize, 
                     numeric type addrsize, 
                     numeric type ports);
    interface BusSlave #(datasize, addrsize, blocksize) dram_slave;
endinterface

// An interface for the wrapped DRAM
// Param block      : Type of individual units
// Param size       : Size of the ram
// Param offset     : Offset address of the ram
// Param datasize   : Width of the databus
// Param addrsize   : Width of the address bus
// Param ports      : Number of ports for the RAM  
interface DRAMWrapper #(numeric type blocksize, 
                        numeric type size, 
                        numeric type offset, 
                        numeric type datasize, 
                        numeric type addrsize, 
                        numeric type ports);
    interface Get #(Chunk #(datasize, addrsize, blocksize)) get_responses;
    interface Put #(Chunk #(datasize, addrsize, blocksize)) put_requests;
endinterface

////////////////////////////////////////////////////////////////////////////////
/// Instances
////////////////////////////////////////////////////////////////////////////////

// Defines the connection betweem the Wrapper and the BusSlave
instance Connectable #(DRAMWrapper #(blocksize,
                                     size, 
                                     offset, 
                                     datasize, 
                                     addrsize, 
                                     ports),
                        BusSlave  #(datasize,
                                    addrsize, 
                                    blocksize));

    module mkConnection #(DRAMWrapper #(blocksize,
                                        size, 
                                        offset, 
                                        datasize, 
                                        addrsize, 
                                        ports) wrap,
                            BusSlave  #(datasize,
                                        addrsize, 
                                        blocksize) slave) (Empty);

        mkConnection (wrap.put_requests, slave.job_recieve);
        mkConnection (slave.job_done, wrap.get_responses);
    endmodule

                    
endinstance

////////////////////////////////////////////////////////////////////////////////
/// Modules
////////////////////////////////////////////////////////////////////////////////

// Creates a DRAM Wrapper
module [Module] mkDRAMWrapper #(Integer id) (DRAMWrapper #(blocksize,
                                                           size, 
                                                           offset, 
                                                           datasize, 
                                                           addrsize, 
                                                           ports));

    Integer num_ports       = valueOf(ports);
    Integer num_offset      = valueOf(offset);
    Integer num_block_size  = valueOf(blocksize);

    FIFOF #(Chunk #(datasize,
                    addrsize,
                    blocksize)) requests  <- mkBypassFIFOF;
    FIFOF #(Chunk #(datasize,
                    addrsize,
                    blocksize)) responses <- mkBypassFIFOF;

    Vector #(size, EHR #(TAdd #(1, ports), Bit #(blocksize))) data <- replicateM (mkEHR(?));
    
    Reg #(Bool) reading <- mkReg (False);
    Reg #(Bool) writing <- mkReg (False);

    Reg #(Bit #(datasize)) temporary_data <- mkRegU;
    Reg #(Chunk #(datasize, addrsize, blocksize)) read_chunk <- mkRegU;

    // Check for incoming requests
    rule check_requests (!(reading || writing));
        let x = requests.first(); requests.deq();

        // Read requests
        if (x.control == Read)
        begin
            Bit #(datasize) wires[num_ports + 1];
            wires[0] = 0;

            for (Integer i = 0; i < num_ports; i = i + 1)
            begin
                if (fromInteger(i) < x.present)
                begin
                    Bit #(addrsize) address = fromInteger(i) +
                                                x.addr - 
                                                fromInteger(num_offset);

                    Bit #(TAdd #(blocksize,
                            datasize)) temp_wire = extend(pack(data[address][i]));
                    wires[i+1] = (wires[i]) +
                                    (truncate(temp_wire) << 
                                    num_block_size * fromInteger(i));
                end
                else 
                begin
                    wires[i+1] = wires[i];
                end

            end
            Chunk #(datasize,
                    addrsize, 
                    blocksize) write_done = Chunk {
                                        control : Response,
                                        data    : wires[num_ports],
                                        addr    : ?,
                                        present : x.present};
            responses.enq(write_done);
        end

        // Write requests
        else if (x.control == Write)
        begin
            for (Integer i = 0; i < num_ports; i = i + 1)
            begin
                
                if (fromInteger(i) < x.present)
                begin
                    Bit #(addrsize) address = fromInteger(i) +
                                                x.addr - 
                                                fromInteger(num_offset);
                    
                    Bit #(blocksize) curr_data = unpack(x.data[fromInteger(i+1) * 
                                                        fromInteger(num_block_size) - 1 : 
                                                        fromInteger(i) * fromInteger(num_block_size)]);
                    data[address][i] <= unpack(curr_data);
                end
            end

            Chunk #(datasize,
                    addrsize,
                    blocksize) write_done = Chunk {
                                                        control : Response,
                                                        data    : x.data,
                                                        addr    : ?,
                                                        present : ?};
            responses.enq(write_done);
        end 
    endrule

    interface get_responses = toGet (responses);
    interface put_requests  = toPut (requests);
endmodule

// Creates a wrapped DRAM Slave
module [Module] mkDRAMSlave #(Integer id) (DRAMSlave #(blocksize, 
                                                        size, 
                                                        offset, 
                                                        datasize, 
                                                        addrsize, 
                                                        ports));
    Bit #(addrsize) lower_bound = fromInteger(valueOf(offset));
    Bit #(addrsize) upper_bound = fromInteger(valueOf(offset) + valueOf(size));
    DRAMWrapper #(blocksize,
                 size, 
                 offset, 
                 datasize, 
                 addrsize, 
                 ports) wrap <- mkDRAMWrapper(id);

    BusSlave #(datasize,
               addrsize, 
               blocksize) slave_ifc <- mkBusSlave(lower_bound,
                                                  upper_bound,
                                                  id);

    // Connect the Slave Ifc with the wrapper
    mkConnection (wrap, slave_ifc); 
    interface dram_slave = slave_ifc;
endmodule

endpackage