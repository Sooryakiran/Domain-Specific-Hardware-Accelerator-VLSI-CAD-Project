package Demo1;
    import Vector::*;
    import Connectable::*;
    
    import DRAMSlave::*;
    import CPU::*;
    import Bus::*;

    `define WORD_LENGTH 32
    `define DATA_LENGTH 32
    `define BUS_DATA_LEN 64
    `define ADDR_LENGTH 20

    `define GRANULARITY 8   // Smallest addressible unit
    `define RAM_BYTES 64    // Ram size (number of addressible units)
    `define RAM_PORTS 4     // 4 ports, 1 byte per port for 32 bits

    `define RAM_ADDRESS_OFFSET 1000

    module mkDemo (Empty);
        CPU #(`WORD_LENGTH,
              `DATA_LENGTH, 
              `BUS_DATA_LEN, 
              `ADDR_LENGTH, 
              `GRANULARITY) my_core <- mkCPU(1, "../asm/random");
        
        DRAMSlave #(`GRANULARITY, 
                    `RAM_BYTES, 
                    `RAM_ADDRESS_OFFSET, 
                    `BUS_DATA_LEN, 
                    `ADDR_LENGTH, 4) my_slave <- mkDRAMSlave(0);

        Vector #(1, BusMaster #(`BUS_DATA_LEN, 
                                `ADDR_LENGTH, 
                                `GRANULARITY)) master_vec;

        Vector #(1, BusSlave  #(`BUS_DATA_LEN, 
                                `ADDR_LENGTH, 
                                `GRANULARITY)) slave_vec;

        master_vec[0] = my_core.bus_master;
        slave_vec[0]  = my_slave.dram_slave;

        Bus #(1, 1, `BUS_DATA_LEN, 
                    `ADDR_LENGTH, 
                    `GRANULARITY) bus <- mkBus(master_vec, slave_vec);

        mkConnection (master_vec, bus);
        mkConnection (slave_vec, bus);
        




        
    endmodule
endpackage