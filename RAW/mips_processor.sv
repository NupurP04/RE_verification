module mips_processor (
    input  logic clk,
    input  logic reset,
    input  logic [31:0] instruction,
    output logic wb_reg_write,
    output logic [4:0] wb_reg_dest,
    output logic [31:0] wb_reg_data,
    output logic stall
);

    logic [31:0] reg_file [0:31];

    integer i;

    initial begin
        for (i = 0; i < 32; i++)
        reg_file[i] = 32'd0;
        reg_file[2] = 32'd10;
        reg_file[3] = 32'd5;
        reg_file[5] = 32'd3;
        reg_file[7] = 32'd15;
        reg_file[8] = 32'd8;
        reg_file[9] = 32'd4;
    end

    // IF/ID
    logic [31:0] IFID_instr;

    // ID/EX
    logic [5:0] IDEX_funct;
    logic [4:0] IDEX_rs, IDEX_rt, IDEX_rd;
    logic [31:0] IDEX_rs_val, IDEX_rt_val;
    logic IDEX_reg_write;

    // EX/MEM
    logic [4:0] EXMEM_rd;
    logic [31:0] EXMEM_alu_result;
    logic EXMEM_reg_write;

    // MEM/WB
    logic [4:0] MEMWB_rd;
    logic [31:0] MEMWB_result;
    logic MEMWB_reg_write;

    logic [5:0] id_opcode;
    logic [4:0] id_rs, id_rt, id_rd;
    logic [5:0] id_funct;
    logic id_reg_write;

    assign id_opcode = IFID_instr[31:26];
    assign id_rs = IFID_instr[25:21];
    assign id_rt = IFID_instr[20:16];
    assign id_rd = IFID_instr[15:11];
    assign id_funct = IFID_instr[5:0];
    assign id_reg_write = (id_opcode == 6'b000000) && (IFID_instr != 32'b0);

    // HAZARD DETECTION — STALL LOGIC
    always_comb begin
        stall = 1'b0;
        // EX stage vs ID stage (0-gap RAW)
        if (IDEX_reg_write && IDEX_rd != 5'd0 &&
            (IDEX_rd == id_rs || IDEX_rd == id_rt))
            stall = 1'b1;
        // MEM stage vs ID stage (1-gap RAW)
        if (EXMEM_reg_write && EXMEM_rd != 5'd0 &&
            (EXMEM_rd == id_rs || EXMEM_rd == id_rt))
            stall = 1'b1;
    end

    // IF STAGE
    // When stall=1 freeze IFID register
    always_ff @(posedge clk or posedge reset) begin
        if (reset)
            IFID_instr <= 32'b0;
        else if (!stall)
            IFID_instr <= instruction;
    end

    // ID STAGE
    // When stall=1 insert NOP bubble into IDEX
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            IDEX_funct <= 6'b0;
            IDEX_rs <= 5'b0;
            IDEX_rt <= 5'b0;
            IDEX_rd <= 5'b0;
            IDEX_rs_val <= 32'b0;
            IDEX_rt_val <= 32'b0;
            IDEX_reg_write <= 1'b0;
        end
        else if (stall) begin
            // Insert NOP bubble
            IDEX_funct <= 6'b0;
            IDEX_rs <= 5'b0;
            IDEX_rt <= 5'b0;
            IDEX_rd <= 5'b0;
            IDEX_rs_val <= 32'b0;
            IDEX_rt_val <= 32'b0;
            IDEX_reg_write <= 1'b0;
        end
        else begin
            IDEX_funct <= id_funct;
            IDEX_rs <= id_rs;
            IDEX_rt <= id_rt;
            IDEX_rd <= id_rd;
            IDEX_rs_val <= (id_rs == 5'd0) ? 32'd0 : reg_file[id_rs];
            IDEX_rt_val <= (id_rt == 5'd0) ? 32'd0 : reg_file[id_rt];
            IDEX_reg_write <= id_reg_write;
        end
    end

    // EX STAGE — ALU
    logic [31:0] alu_result;

    always_comb begin
        alu_result = 32'b0;
        case (IDEX_funct)
            6'b100000: alu_result = IDEX_rs_val + IDEX_rt_val; // ADD
            6'b100010: alu_result = IDEX_rs_val - IDEX_rt_val; // SUB
            6'b100100: alu_result = IDEX_rs_val & IDEX_rt_val; // AND
            6'b100101: alu_result = IDEX_rs_val | IDEX_rt_val; // OR
            default: alu_result = 32'b0;
        endcase
    end

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            EXMEM_rd <= 5'b0;
            EXMEM_alu_result <= 32'b0;
            EXMEM_reg_write <= 1'b0;
        end
        else begin
            EXMEM_rd <= IDEX_rd;
            EXMEM_alu_result <= alu_result;
            EXMEM_reg_write <= IDEX_reg_write;
        end
    end

    // MEM STAGE — Pass through for R-type
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            MEMWB_rd <= 5'b0;
            MEMWB_result <= 32'b0;
            MEMWB_reg_write <= 1'b0;
        end
        else begin
            MEMWB_rd <= EXMEM_rd;
            MEMWB_result <= EXMEM_alu_result;
            MEMWB_reg_write <= EXMEM_reg_write;
        end
    end

    // WB STAGE — Write back + drive outputs
    // Monitor watches wb_reg_write, wb_reg_dest, wb_reg_data
    assign wb_reg_write = MEMWB_reg_write;
    assign wb_reg_dest = MEMWB_rd;
    assign wb_reg_data = MEMWB_result;

    always_ff @(posedge clk) begin
        if (!reset && MEMWB_reg_write && MEMWB_rd != 5'd0)
            reg_file[MEMWB_rd] <= MEMWB_result;
    end

endmodule