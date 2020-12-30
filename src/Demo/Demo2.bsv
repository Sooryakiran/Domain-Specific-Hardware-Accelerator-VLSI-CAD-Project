package Demo2;
    import Vector::*;
    import Connectable::*;
    
    import DRAMSlave::*;
    import CPU::*;
    import Bus::*;
    import Console::*;
    import VectorUniary::*;

    `include <VX_Address.bsv>

    `define WORD_LENGTH 32
    `define DATA_LENGTH 32
    `define BUS_DATA_LEN 64
    `define ADDR_LENGTH 20
    `define VECTOR_DATA_SIZE `BUS_DATA_LEN
    `define VX_STORAGE_SIZE 2

    `define GRANULARITY 8   // Smallest addressible unit
    `define RAM_BYTES 32    // Ram size (number of addressible units)
    `define RAM_PORTS 8     // 4 ports, 1 byte per port for 32 bits
    `define RAM_ADDRESS_OFFSET 1024

    `define CONSOLE_ADDRESS 128

    module mkDemo (Empty);
        CPU #(`WORD_LENGTH,
              `DATA_LENGTH, 
              `BUS_DATA_LEN, 
              `ADDR_LENGTH, 
              `GRANULARITY) my_core <- mkCPU(0, "../asm/vector");
        
        DRAMSlave #(`GRANULARITY, 
                    `RAM_BYTES, 
                    `RAM_ADDRESS_OFFSET, 
                    `BUS_DATA_LEN, 
                    `ADDR_LENGTH, `RAM_PORTS) my_slave <- mkDRAMSlave(0);

        Console #(`BUS_DATA_LEN,
                  `ADDR_LENGTH,
                  `GRANULARITY)      my_console <- mkConsole(1, `CONSOLE_ADDRESS);

        VectorUniary #(`DATA_LENGTH,
                       `VECTOR_DATA_SIZE,
                       `BUS_DATA_LEN,
                       `ADDR_LENGTH,
                       `GRANULARITY) vec_uniary <- mkVectorNeg (`VX_NEG, `VX_STORAGE_SIZE, 1);

        Vector #(2, BusMaster #(`BUS_DATA_LEN, 
                                `ADDR_LENGTH, 
                                `GRANULARITY)) master_vec;

        Vector #(3, BusSlave  #(`BUS_DATA_LEN, 
                                `ADDR_LENGTH, 
                                `GRANULARITY)) slave_vec;


        master_vec[0] = my_core.bus_master;
        master_vec[1] = vec_uniary.bus_master;

        slave_vec[0]  = my_slave.dram_slave;
        slave_vec[1]  = my_console.bus_slave;
        slave_vec[2]  = vec_uniary.bus_slave;

        Bus #(2, 3, `BUS_DATA_LEN, 
                    `ADDR_LENGTH, 
                    `GRANULARITY) bus <- mkBus(master_vec, slave_vec);

        mkConnection (master_vec, bus);
        mkConnection (slave_vec, bus);
        


        Reg #(Bit #(32)) debug_clk <- mkReg(0);

        rule debug;
            debug_clk <= debug_clk + 1;
            if (debug_clk > 200) $finish();
        endrule

        
    endmodule
endpackage