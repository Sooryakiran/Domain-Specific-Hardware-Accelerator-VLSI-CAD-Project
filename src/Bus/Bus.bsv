package Bus;
    import Vector::*;
    import GetPut::*;
    import Arbiter::*;
    import Connectable::*;
    import FIFOF::*;
    import SpecialFIFOs::*;

    /*----------------------------------------------------------------------
                                Exports
    -----------------------------------------------------------------------*/
    export ControlSignal (..);
    export Chunk (..);
    export PresentSize (..);

    export Bus (..);
    export BusMaster (..);
    export BusSlave (..);

    export mkBusSlave;
    export mkBusMaster;
    export mkBus;

    /*----------------------------------------------------------------------
                                Typedefs
    -----------------------------------------------------------------------*/
    
    typedef enum {Response, Read, Write} ControlSignal deriving (Bits, Eq, FShow);

    typedef TLog #(TAdd #(TDiv #(datasize, granularity), 1)) 
    PresentSize #(numeric type datasize,
                  numeric type granularity);


    typedef struct {ControlSignal control;
                    Bit #(datasize) data;
                    Bit #(addrsize) addr;
                    Bit #(PresentSize #(datasize, granularity)) present;}

                    Chunk #(numeric type datasize,
                            numeric type addrsize,
                            numeric type granularity) deriving (Bits, FShow);


    /*----------------------------------------------------------------------
                                Interfaces
    -----------------------------------------------------------------------*/

    interface Bus #(numeric type masters,
                   numeric type slaves, 
                   numeric type datasize, 
                   numeric type addrsize, 
                   numeric type granularity);
        interface Put #(Chunk #(datasize, addrsize, granularity)) write_to_bus;
        interface Put #(Chunk #(datasize, addrsize, granularity)) write_to_bus_slave;
        interface Get #(Chunk #(datasize, addrsize, granularity)) read_from_bus;
    endinterface

    interface BusMaster #(numeric type datasize,
                          numeric type addrsize, 
                          numeric type granularity);
        // Frontend
        interface Put #(Chunk #(datasize, addrsize, granularity)) job_send;
        interface Get #(Chunk #(datasize, addrsize, granularity)) job_done;

        // Backend
        method Bool valid;
        method Action granted (Bool permission);
        method Action available (Bool availability);
        interface Put #(Chunk #(datasize, addrsize, granularity)) put_states;
        interface Get #(Chunk #(datasize, addrsize, granularity)) get_states;
    endinterface

    interface BusSlave #(numeric type datasize,
                        numeric type addrsize, 
                        numeric type granularity);
        // Front end
        interface Get #(Chunk #(datasize, addrsize, granularity)) job_recieve;
        interface Put #(Chunk #(datasize, addrsize, granularity)) job_done;

        // Backend
        method Bool is_address_valid (Bit #(addrsize) addr);
        interface Put #(Chunk #(datasize, addrsize, granularity)) put_states;
        interface Get #(Chunk #(datasize, addrsize, granularity)) get_states;
    endinterface

    /*----------------------------------------------------------------------
                                Instances
    -----------------------------------------------------------------------*/

    instance Connectable #(BusSlave #(datasize, addrsize, granularity), 
                           Bus #(masters, slaves, datasize, addrsize, granularity));
        module mkConnection #(BusSlave #(datasize, addrsize, granularity) slave,
                              Bus #(masters, slaves, datasize, addrsize, granularity) bus) (Empty);

            mkConnection (slave.put_states, bus.read_from_bus);
            mkConnection (slave.get_states, bus.write_to_bus_slave);
        endmodule
    endinstance


    instance Connectable #(BusMaster #(datasize, addrsize, granularity),
                           Bus #(masters, slaves, datasize, addrsize, granularity));
        module mkConnection #(BusMaster #(datasize, addrsize, granularity) master,
                                Bus #(masters, slaves, datasize, addrsize, granularity) bus) (Empty);
        
            mkConnection (bus.read_from_bus, master.put_states);
            mkConnection (bus.write_to_bus, master.get_states);
        endmodule
    endinstance

    instance Connectable #(Vector #(capacity, BusSlave #(datasize, addrsize, granularity)),
                           Bus #(masters, slaves, datasize, addrsize, granularity));
        module mkConnection #(Vector #(capacity, BusSlave #(datasize, addrsize, granularity)) slave_v,
            Bus #(masters, slaves, datasize, addrsize, granularity) bus) (Empty);

            Integer num_capacity = valueOf(capacity);
            for (Integer i = 0; i < num_capacity; i = i + 1)
                mkConnection(slave_v[i], bus);
        endmodule
    endinstance

    instance Connectable #(Vector #(capacity, BusMaster #(datasize, addrsize, granularity)),
                           Bus #(masters, slaves, datasize, addrsize, granularity));
        module mkConnection #(Vector #(capacity, BusMaster #(datasize, addrsize, granularity)) master_v,
            Bus #(masters, slaves, datasize, addrsize, granularity) bus) (Empty);
            
            Integer num_capacity = valueOf(capacity);
            for (Integer i = 0; i < num_capacity; i = i + 1)
                mkConnection(master_v[i], bus);
        endmodule
    endinstance

    instance Arbitable #(BusMaster#(datasize, addrsize, granularity));
        module mkArbiterRequest #(BusMaster#(datasize, addrsize, granularity) bus_master)
        (ArbiterRequest_IFC);

            method Bool request; return bus_master.valid;   endmethod
            method Bool lock;    return False;              endmethod
            method Action grant; bus_master.granted(True);  endmethod
        
        endmodule
    endinstance
        
    /*----------------------------------------------------------------------
                                Modules
    -----------------------------------------------------------------------*/
    module mkBusSlave #(Bit #(addrsize) lower_bound,
                        Bit #(addrsize) upper_bound,
                        Integer id) (BusSlave #(datasize, addrsize, granularity));
        
        
        FIFOF #(Chunk #(datasize, addrsize, granularity)) jobs <- mkBypassFIFOF;
        FIFOF #(Chunk #(datasize, addrsize, granularity)) done <- mkBypassFIFOF;
        FIFOF #(Chunk #(datasize, addrsize, granularity)) done_to_sent <- mkBypassFIFOF;

        RWire #(Chunk #(datasize, addrsize, granularity)) readings <- mkRWire;

        Reg #(Bool) busy <- mkReg(False);

        function Bool is_my_job (Bit #(addrsize) address);
            return (lower_bound <= address && upper_bound >= address);
        endfunction

        rule check_for_requests (!busy);
            if (readings.wget() matches tagged Valid .reading_val)
            begin
                if(is_my_job (reading_val.addr) && !busy && reading_val.control != Response)
                begin
                    busy <= True;
                    jobs.enq(reading_val);
                end
            end
        endrule

        rule check_job_done (busy);
            let x = done.first();
            done_to_sent.enq(x);
            busy <= False;
            done.deq();
        endrule

        method Bool is_address_valid (Bit #(addrsize) address);
            if (lower_bound <= address && upper_bound >= address) return True;
            else return False;
        endmethod

        interface Put put_states = toPut (readings);
        interface Get get_states = toGet (done_to_sent);
       
        interface Put job_done = toPut (done);
        interface Get job_recieve = toGet (jobs);
    endmodule

    module mkBusMaster #(Integer id) (BusMaster #(datasize, addrsize, granularity));
        
        Reg #(Bool) need_bus    <- mkReg(False);
        Reg #(Bool) busy        <- mkReg(False);
        PulseWire no_traffic    <- mkPulseWire();
        
        RWire #(Chunk #(datasize, addrsize, granularity)) to_read       <- mkRWire;
        FIFOF #(Chunk #(datasize, addrsize, granularity)) to_write      <- mkBypassFIFOF;
        FIFOF #(Chunk #(datasize, addrsize, granularity)) buff_to_write <- mkBypassFIFOF;
        FIFOF #(Chunk #(datasize, addrsize, granularity)) responses     <- mkBypassFIFOF;
        
        rule need_bus_update (busy == False);
            need_bus <= buff_to_write.notEmpty();
        endrule

        rule get_response (busy);
            if(to_read.wget() matches tagged Valid .readings)
            begin
                if(readings.control == Response)
                begin
                    responses.enq(readings);   
                    busy <= False;
                end
            end
        endrule
        
        method Action granted(Bool permission) if(!busy);
            if(!busy && permission && no_traffic && buff_to_write.notEmpty())
            begin
                let x = buff_to_write.first();
                to_write.enq(x); 
                buff_to_write.deq();
                if (x.control == Read)
                    busy <= True;
                need_bus <= False;
            end   
        endmethod


        method Bool valid;
            return need_bus;
        endmethod

        method Action available (Bool availability);
            if (availability) no_traffic.send();
        endmethod

        interface put_states = toPut(to_read);
        interface get_states = toGet(to_write);
        interface job_send   = toPut(buff_to_write);
        interface job_done   = toGet(responses);

    endmodule

    module mkBus #(Vector #(masters, BusMaster #(datasize, addrsize, granularity)) master_vec,
                    Vector #(slaves, BusSlave #(datasize, addrsize, granularity)) slave_vec) (Bus #(masters, slaves, datasize, addrsize, granularity));
        
        Reg #(Bit #(32)) debug_clk <- mkReg(0);
        

        Integer master_count = valueOf(masters);
        Integer slave_count  = valueOf(slaves);
        

        Arbiter_IFC #(masters) master_arb_clients       <- mkArbiter(False);
        Vector #(masters, ArbiterRequest_IFC) requests  <- mapM(mkArbiterRequest, master_vec);
        zipWithM(mkConnection, master_arb_clients.clients, requests);

        
        Reg #(Chunk #(datasize, addrsize, granularity)) bus_state <- mkReg(Chunk {
                                                                        control : Response,
                                                                        data    : ?,
                                                                        addr    : ?,
                                                                        present : ?
                                                                    });

        RWire #(Chunk #(datasize, addrsize, granularity)) bus_state_inc    <- mkRWire;
        RWire #(Chunk #(datasize, addrsize, granularity)) bus_state_slaves <- mkRWire;


        rule update_states;
            if (bus_state_inc.wget matches tagged Valid .x) 
            begin
                bus_state <= x;
            end
            else if (bus_state_slaves.wget matches tagged Valid .y)
            begin
                bus_state <= y;
            end
        endrule

        rule put_availability;
            for (Integer i = 0; i < master_count ; i = i + 1)
            begin
                master_vec[i].available(bus_state.control == Response);
            end
        endrule

        interface Put write_to_bus       = toPut(bus_state_inc);
        interface Put write_to_bus_slave = toPut(bus_state_slaves);
        interface Get read_from_bus      = toGet(bus_state);          
    endmodule

endpackage : Bus