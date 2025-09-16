# Unified Posit/IEEE-754 Vector MAC Unit for Transprecision Computing  

This repository accompanies the paper:  

```bibtex
@article{crespo2022,
  title={Unified posit/IEEE-754 vector MAC unit for transprecision computing},
  author={Crespo, Luis and Tomas, Pedro and Roma, Nuno and Neves, Nuno},
  journal={IEEE Transactions on Circuits and Systems II: Express Briefs},
  volume={69},
  number={5},
  pages={2478--2482},
  year={2022},
  publisher={IEEE}
}
```
Maintainer: Luís Crespo <luis.miguel.crespo@tecnico.ulisboa.pt>

# Overview  

Transprecision computing aims to improve **energy efficiency** by adjusting 
arithmetic precision to application needs. While most solutions rely solely
on IEEE-754, this project introduces a **unified hardware architecture** 
that supports both IEEE-754 and **Posit** number formats for multiple 
precisions.  

The **Unified Posit/IEEE-754 Vector Multiply-Accumulate (VMAC) unit**:

- Provides a **32-bit variable-precision datapath** 
(supporting 32-, 16-, and 8-bit operations).  
- Supports **SIMD vectorization** (1×32, 2×16, 4×8-bit).  
- Offers **unified compatibility** with IEEE-754 and Posit formats.  
- Enables **inter-format operations and conversions**. 