////////////////////////////////////////////////////////////////////////////////
//  Author        : Sooryakiran, Ashwini, Shailesh
//  Description   : Common params and types for VX
////////////////////////////////////////////////////////////////////////////////

package VectorDefines;

////////////////////////////////////////////////////////////////////////////////
/// Imports
////////////////////////////////////////////////////////////////////////////////

import CPUDefines::*;

////////////////////////////////////////////////////////////////////////////////
/// Exports
////////////////////////////////////////////////////////////////////////////////

export VectorUnaryInstruction (..);
export VectorBinaryInstruction (..);
export DataChunk (..);
export AddrChunk (..);
export WriteChunk (..);
export ExecSignals (..);
export BufferChunk (..);
export PresentSize (..); // Duplicate. Already in Bus::*;
export CPUDefines::*;

////////////////////////////////////////////////////////////////////////////////
/// Types
////////////////////////////////////////////////////////////////////////////////

typedef enum {Continue, Break} ExecSignals deriving(Bits, FShow, Eq);

typedef struct {
    Opcode code;                    
    Bit #(datasize) src1;         
    Bit #(datasize) src2;         
    Bit #(datasize) blocksize;          
    Bit #(datasize) dst;
    Bit #(datasize) aux;                    
}  VectorBinaryInstruction #(numeric type datasize) deriving(Bits, FShow); 

typedef struct {
    Opcode code;                    
    Bit #(datasize) src1;         
    Bit #(datasize) blocksize;          
    Bit #(datasize) dst;
    Bit #(datasize) aux;                 
}  VectorUnaryInstruction #(numeric type datasize) deriving(Bits, FShow); 


typedef struct {
    ExecSignals signal;
    Opcode code;
    Bit #(datasize) dst;
    Bit #(datasize) aux;
    Bit #(vectordatasize) vector_data;
    Bit #(PresentSize #(vectordatasize, granularity)) present;
    
} BufferChunk #(numeric type datasize,
                numeric type vectordatasize,
                numeric type granularity) deriving (Bits, FShow);

typedef TLog #(TAdd #(TDiv #(busdatasize, granularity), 1)) 
                    PresentSize #(numeric type busdatasize,
                                numeric type granularity);
                                
typedef struct {Bit #(busdatasize) data;
                Bit #(PresentSize #(busdatasize, granularity)) present;}
                DataChunk #(numeric type busdatasize,
                            numeric type granularity) deriving (Bits, FShow);

typedef struct {Bit #(busaddrsize) addr;
                Bit #(PresentSize #(busdatasize, granularity)) present;}
                AddrChunk #(numeric type busdatasize,
                            numeric type busaddrsize,
                            numeric type granularity) deriving (Bits, FShow);

typedef struct {ExecSignals signal;
                Bit #(busdatasize) data;
                Bit #(addrsize) addr;
                Bit #(PresentSize #(busdatasize, granularity)) present;}

                WriteChunk #(numeric type busdatasize,
                             numeric type addrsize,
                             numeric type granularity) deriving (Bits, FShow);
endpackage