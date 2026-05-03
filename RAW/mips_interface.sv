
interface mips_interface (input logic clk);

    logic reset;
  
    // Driver feeds one instruction per cycle
    // When stall=1 Driver feeds NOP
    logic [31:0] instruction;

    // Monitor watches these every cycle
    // When wb_reg_write=1 capture dest and data
    logic wb_reg_write;
    logic [4:0] wb_reg_dest;
    logic [31:0] wb_reg_data;

    // When stall=1 Driver holds current instruction
    // Monitor counts stall cycles
    logic stall;

    // CLOCKING BLOCKS
    // cb_driver - Driver drives on NEGEDGE
    // cb_monitor - Monitor samples on POSEDGE
    // driving and sampling separate to avoid race conditions
    clocking cb_driver @(negedge clk);
        output reset;
        output instruction;
    endclocking

    clocking cb_monitor @(posedge clk);
        input wb_reg_write;
        input wb_reg_dest;
        input wb_reg_data;
        input stall;
    endclocking

endinterface