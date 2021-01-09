////////////////////////////////////////////////////////////////////////////////
//  ** DEPRECIATED **
//  Author        : Sooryakiran, Ashwini, Shailesh
//  Description   : The RAM implementation with CBus wrapper
//                  Replaced by DramSlave
////////////////////////////////////////////////////////////////////////////////

package DRAMCore;

////////////////////////////////////////////////////////////////////////////////
/// Imports
////////////////////////////////////////////////////////////////////////////////

import StmtFSM::*;
import Vector::*;
import CBus::*;
import EHR::*;

////////////////////////////////////////////////////////////////////////////////
/// Exports
////////////////////////////////////////////////////////////////////////////////

export DRAM (..);
export mkDRAM;

////////////////////////////////////////////////////////////////////////////////
/// Interfaces
////////////////////////////////////////////////////////////////////////////////

// The RAM interface wrapped with CBus
// Param block      : Type of individual units
// Param size       : Size of the ram
// Param offset     : Offset address of the ram
// Param datasize   : Width of the databus
// Param addrsize   : Width of the address bus
// Param ports      : Number of ports for the RAM  
interface DRAM #(type block, 
                 numeric type size, 
                 numeric type offset, 
                 numeric type datasize, 
                 numeric type addrsize, 
                 numeric type ports);
    method block    read  (Bit #(TLog #(size)) addr);
    method Action   write (Bit #(TLog #(size)) addr, block data);
    interface CBus #(addrsize, datasize) bus_wires;
endinterface : DRAM

// The core RAM interface
// Param block      : Type of individual units
// Param size       : Size of the ram
// Param offset     : Offset address of the ram
// Param datasize   : Width of the databus
// Param addrsize   : Width of the address bus
// Param ports      : Number of ports for the RAM  
interface DRAMBody #(type block, 
                     numeric type size, 
                     numeric type offset, 
                     numeric type datasize, 
                     numeric type addrsize, 
                     numeric type ports);
    method block    read  (Bit #(TLog #(size)) addr);
    method Action   write (Bit #(TLog #(size)) addr, block data);
endinterface

// Sub interface for RAM CSRs
// Param block      : Type of individual units
// Param size       : Size of the ram
// Param datasize   : Width of the databus
// Param addrsize   : Width of the address bus
interface DRAM_csr #(type block, 
                     numeric type size, 
                     numeric type datasize, 
                     numeric type addrsize);
    method Bool     read_req();
    method Bool     write_req();
    method Action   set_idle();
    method Action   set_data(block value);
    method block    get_data();
    method Bit #(TLog #(size)) get_address();
endinterface

////////////////////////////////////////////////////////////////////////////////
/// Modules
////////////////////////////////////////////////////////////////////////////////

// Creates a CBus wrapper for RAM
module [Module] mkDRAM (DRAM #(block, 
                               size, 
                               offset, 
                               datasize, 
                               addrsize, 
                               ports))
    provisos (Arith #(block), Bits #(block, block_sz));

    IWithCBus #(CBus #(addrsize, datasize), DRAMBody #(block, 
                                                       size, 
                                                       offset, 
                                                       datasize, 
                                                       addrsize, 
                                                       ports)) inst <- exposeCBusIFC(mkDRAMBody);

    interface bus_wires = inst.cbus_ifc;
    interface read      = inst.device_ifc.read;
    interface write     = inst.device_ifc.write;
endmodule

// Creates the CSRs for our RAM
module [ModWithCBus #(addrsize, datasize)] mkDRAM_csr #(Bit #(addrsize) addr) (DRAM_csr #(block, 
                                                                                            size, 
                                                                                            datasize, 
                                                                                            addrsize))
    provisos (Arith #(block), Bits #(block, block_sz));
    Reg #(Bit #(2))            control  <- mkCBRegRW(CRAddr { a: addr,     o : 0}, 0);
    Reg #(Bit #(TLog #(size))) address  <- mkCBRegRW(CRAddr { a: addr + 1, o : 0}, ?);
    Reg #(block)               data_in  <- mkCBRegRW(CRAddr { a: addr + 2, o : 0}, ?);
    Reg #(block)               data_out <- mkCBRegRW(CRAddr { a: addr + 3, o : 0}, ?);
    
    PulseWire read_req_signal <- mkPulseWire;
    PulseWire write_req_signal <- mkPulseWire;

    // Reads the control CSR and directs the proper action
    rule master_rule;
        let x = control;
        if (x == 1) read_req_signal.send();
        if (x == 2) write_req_signal.send();
        control <= 0;
    endrule

    // If got a read request 
    method Bool read_req;
        return read_req_signal;
    endmethod : read_req

    // If got a write request
    method Bool write_req;
        return write_req_signal;
    endmethod : write_req

    // Set status flag to idle
    method Action set_idle;
        action
            control <= 0;
        endaction
    endmethod

    // Set the output data CSR 
    method Action set_data(block value);
        action
            data_out <= value;
        endaction
    endmethod 

    // Input data CSR's value
    method block get_data();
        return data_in;
    endmethod

    // Get the value of the address CSR
    method Bit #(TLog #(size)) get_address();
        return address;
    endmethod
endmodule

// Creates the bdy of our RAM
module [ModWithCBus #(addrsize, datasize)] mkDRAMBody (DRAMBody #(block, 
                                                                 size, 
                                                                 offset, 
                                                                 datasize, 
                                                                 addrsize, 
                                                                 ports))
    provisos (Arith #(block), Bits #(block, block_sz));
    
    Bit #(kt) hi                    = 0;
    Bit #(addrsize) offset_value    = fromInteger(valueof(offset));
    Integer num_ports               = valueOf(ports);

    DRAM_csr #(block, size, datasize, addrsize) csr_s[num_ports];
    
    Vector #(size, EHR #(TAdd #(1, ports), block)) data <- replicateM (mkEHR(?));
    for (Integer i = 0; i < num_ports; i = i + 1)
        csr_s[i] <- mkDRAM_csr(offset_value + 4*fromInteger(i));
    
    // Port requests
    function Action aux(Integer i);
        action
            if(csr_s[i].read_req())
                begin 
                    csr_s[i].set_data(data[csr_s[i].get_address()][i]);
                end
            else
                begin
                if(csr_s[i].write_req())
                    begin
                        data[csr_s[i].get_address()][i] <= csr_s[i].get_data();
                    end
                end
        endaction
    endfunction

    for (Integer j = 0; j < num_ports; j = j + 1)
        rule port_rule;
            aux(j);
        endrule

    // Device read request
    method block read   (Bit #(TLog #(size)) addr);
        return data[addr][num_ports];
    endmethod 

    // Device write request
    method Action write (Bit #(TLog #(size)) addr, block value);
        data[addr][num_ports] <= value;
    endmethod
endmodule : mkDRAMBody

endpackage : DRAMCore