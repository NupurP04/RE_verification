// Flows between all testbench components

class mips_transaction;

    typedef enum logic [2:0] {
        ADD = 3'd0,
        SUB = 3'd1,
        AND = 3'd2,
        OR  = 3'd3,
        LW  = 3'd4,
        NOP = 3'd5
    } instr_type_e;

    instr_type_e instr_type;
    int dest_reg;
    int src1_reg;
    int src2_reg;

    // Generator fills these using software reg_file
    logic [31:0] src1_val;
    logic [31:0] src2_val;
    logic [31:0] expected_result;

    // RAW HAZARD FIELDS
    // Generator fills these automatically
    // has_RAW = does this instruction have a RAW?
    // RAW_gap = how many instructions between writer/reader
    // RAW_reg = which register has the dependency
    bit has_RAW;
    int RAW_gap;
    int RAW_reg;


    // STALL FIELDS
    // expected_stalls computed from RAW_gap and observed_stalls filled by Monitor
    int expected_stalls;
    int observed_stalls;

 
    // OBSERVED FIELDS
    // Monitor fills these when DUT writes back
    logic [4:0] obs_dest_reg;
    logic [31:0] obs_result;

    int seq_id;
    string instr_label;

    function new();
        instr_type = NOP;
        dest_reg = 0;
        src1_reg = 0;
        src2_reg = 0;
        src1_val = 32'd0;
        src2_val = 32'd0;
        expected_result = 32'd0;
        has_RAW = 0;
        RAW_gap = -1;
        RAW_reg = -1;
        expected_stalls = 0;
        observed_stalls = 0;
        obs_dest_reg = 5'd0;
        obs_result = 32'd0;
        seq_id = 0;
        instr_label = "UNKNOWN";
    endfunction

    // COMPUTE EXPECTED STALLS
    // Based on RAW gap, how many stalls should occur?
    function void compute_expected_stalls();
        if (!has_RAW) begin
            expected_stalls = 0;
        end else begin
            case (RAW_gap)
                0: expected_stalls = 2;
                1: expected_stalls = 1;
                default: expected_stalls = 0;
            endcase
        end
    endfunction

    function void build_label();
        string type_str;
        case (instr_type)
            ADD: type_str = "ADD";
            SUB: type_str = "SUB";
            AND: type_str = "AND";
            OR: type_str = "OR";
            LW: type_str = "LW";
            NOP: type_str = "NOP";
            default: type_str = "UNK";
        endcase

        if (instr_type == NOP)
            instr_label = $sformatf("[%0d] NOP", seq_id);
        else
            instr_label = $sformatf(
                "[%0d] %s R%0d,R%0d,R%0d | exp=%0d | RAW=%0b gap=%0d stalls=%0d",
                seq_id, type_str,
                dest_reg, src1_reg, src2_reg,
                expected_result,
                has_RAW, RAW_gap, expected_stalls);
    endfunction

    function void print(string prefix = "");
        build_label();
        $display("%s %s", prefix, instr_label);
    endfunction

endclass