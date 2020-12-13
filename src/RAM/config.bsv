`define CONF_CBUS_ADDR_SIZE 32
`define CONF_CBUS_DATA_SIZE 32

typedef ModWithCBus #(`CONF_CBUS_ADDR_SIZE, `CONF_CBUS_DATA_SIZE, i) ConfModWithCBus #(type i);
typedef CBus        #(`CONF_CBUS_ADDR_SIZE, `CONF_CBUS_DATA_SIZE) ConfCBus;
typedef CRAddr      #(`CONF_CBUS_ADDR_SIZE, `CONF_CBUS_DATA_SIZE) ConfAddr;