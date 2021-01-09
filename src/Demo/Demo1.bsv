////////////////////////////////////////////////////////////////////////////////
//  Author        : Sooryakiran, Ashwini, Shailesh
//  Description   : CPU only demo
////////////////////////////////////////////////////////////////////////////////

package Demo1;

////////////////////////////////////////////////////////////////////////////////
/// Imports
////////////////////////////////////////////////////////////////////////////////

import Vector::*;
import Connectable::*;
import DRAMSlave::*;
import CPU::*;
import Bus::*;
import Console::*;

////////////////////////////////////////////////////////////////////////////////
/// Defines
////////////////////////////////////////////////////////////////////////////////

`define WORD_LENGTH 64  // We are making a 64 bit machine
`define DATA_LENGTH 32  // The data size of our machine
`define BUS_DATA_LEN 32 // Data bus width
`define ADDR_LENGTH 20  // Addr bus width

`define GRANULARITY 8   // Smallest addressible unit (1 Byte at every address)
`define RAM_BYTES 64    // Ram size (number of addressible units)
`define RAM_PORTS 4     // 4 ports, 4 x 8 for 32 bit bus

`define RAM_ADDRESS_OFFSET 1000 // Address of the RAM
`define CONSOLE_ADDRESS 128     // Address of the Console

////////////////////////////////////////////////////////////////////////////////
/// Modules
////////////////////////////////////////////////////////////////////////////////

// Testbench
module mkDemo (Empty);

    // Create a CPU with ID 1, Imem init from the given file
    CPU #(`WORD_LENGTH,
          `DATA_LENGTH, 
          `BUS_DATA_LEN, 
          `ADDR_LENGTH, 
          `GRANULARITY) 
           my_core <- mkCPU(1, "../asm/fibonacci"); 
    
    // Create a DRAM
    DRAMSlave #(`GRANULARITY, 
                `RAM_BYTES, 
                `RAM_ADDRESS_OFFSET, 
                `BUS_DATA_LEN, 
                `ADDR_LENGTH, 
                `RAM_PORTS) my_dram <- mkDRAMSlave(0);

    // Create a console for debug
    Console #(`BUS_DATA_LEN,
                `ADDR_LENGTH,
                `GRANULARITY) my_console <- mkConsole(1, `CONSOLE_ADDRESS);

    // Create BusMaster and BusSlave vectors
    Vector #(1, BusMaster #(`BUS_DATA_LEN, 
                            `ADDR_LENGTH, 
                            `GRANULARITY)) master_vec;

    Vector #(2, BusSlave  #(`BUS_DATA_LEN, 
                            `ADDR_LENGTH, 
                            `GRANULARITY)) slave_vec;

    // Assign the bus master and slave vectors
    master_vec[0] = my_core.bus_master;
    slave_vec[0]  = my_dram.dram_slave;
    slave_vec[1]  = my_console.bus_slave;

    // Create the bus
    Bus #(1, 2,           // 1 Master, 2 Slaves
         `BUS_DATA_LEN, 
         `ADDR_LENGTH, 
         `GRANULARITY) bus <- mkBus(master_vec, slave_vec);

    // Connect the masters to the bus
    mkConnection (master_vec, bus);
    // Connect the slaves to the bus
    mkConnection (slave_vec, bus);

    Reg #(Bit #(32)) debug_clk <- mkReg(0);

    // Debug rule
    rule debug;
        debug_clk <= debug_clk + 1;
        if (debug_clk > 1024) $finish();
    endrule
    
endmodule
endpackage