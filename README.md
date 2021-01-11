# Domain Specific Hardware Accelerators: Vector Processing Units
This repository contains the source code for VLSI CAD Project, Domain Specific Hardware Accelerators, as apart of coursework in 

CS6230 : CAD for VLSI. 

Fall, 2020.

## What does this repo enclose?
![Overview](https://raw.githubusercontent.com/Sooryakiran/Domain-Specific-Hardware-Accelerator-VLSI-CAD-Project/main/docs/Final%20Report%20Source/Images/Overview-Overview.png )

The following components are implemented in Bluespec System Verilog:
* CPU
* RAM
* Bus
* Vector Processor


### CPU
A minimal 2 stage pipelined inorder processor.

### Vector Processor
A vector processor capable of:
* Vector Negation (int8, int16, int32, float32)
* Vector Minima (int8, int16, int32, float32)

See https://arm-software.github.io/CMSIS_5/DSP/html/group__groupMath.html for details about the functions.
### Bus
A minimal custom bus for demonstration.

# Documentation
See Final Report.pdf
