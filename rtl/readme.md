### Repository Structure

The files in this repository are organized as follows:

- **`ipbus_ethernet/`**  
  Contains a minimal, self-contained integration of IPBus and a Verilog Ethernet core.  
  - Modified to support **RMII**  
  - Uses a **single internal clock domain** for simplicity  
  - Intended as a lightweight reference implementation rather than a full-featured stack  

- **`demo_payload/`**  
  Provides example RTL demonstrating how to interface with the IPBus Ethernet module.  
  - Not intended for direct synthesis  
  - Serves as a **reference design** for:
    - Integrating a payload
    - Using the IPBus interface correctly  

- **`additional_asic/`**  
  Includes wrappers and adaptations specific to **ASIC implementations**.

- **`additional_fpga/`**  
  Includes wrappers and adaptations specific to **FPGA implementations**.