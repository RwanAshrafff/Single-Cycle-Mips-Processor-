`timescale 1ns/1ps

module MIPS_Processor(
    input clk,
    input reset,
    output reg [31:0] result
);
    // Internal registers
    reg [31:0] pc;
    reg [31:0] instruction;
    reg [31:0] read_data1, read_data2;
    reg [31:0] write_data;
    reg [31:0] alu_result;
    reg [31:0] mem_read_data;
    reg [31:0] sign_extended;
    reg [2:0] alu_control;
    reg alu_src, branch, jump, mem_to_reg, mem_write, reg_dst, reg_write, mem_read;
    reg zero;
    reg [4:0] write_reg_addr;
    reg [31:0] alu_operand2;

    // Instruction Memory
    reg [31:0] instr_memory [0:255];
    
    // Register File
    reg [31:0] registers [0:31];
    
    // Data Memory
    reg [31:0] data_memory [0:255];
    
    initial begin
        $readmemb("instructions.mem", instr_memory);
    end

    // Program Counter
    always @(posedge clk or posedge reset) begin
        if (reset)
            pc <= 0;
        else begin
            if (jump)
                pc <= {pc[31:28], instruction[25:0], 2'b00};
            else if (branch && zero)
                pc <= pc + 4 + (sign_extended << 2);
            else
                pc <= pc + 4;
        end
    end

    // Instruction Fetch
    always @(*) begin
        instruction = instr_memory[pc[7:2]];
    end

    // Control Unit
    always @(*) begin
        // Default values
        alu_src = 0;
        branch = 0;
        jump = 0;
        mem_to_reg = 0;
        mem_write = 0;
        reg_dst = 0;
        reg_write = 0;
        mem_read = 0;
        alu_control = 3'b000;

        case(instruction[31:26])
            6'b000000: begin // R-type
                reg_dst = 1;
                reg_write = 1;
                case(instruction[5:0])
                    6'b100000: alu_control = 3'b000; // add
                    6'b100010: alu_control = 3'b001; // sub
                    6'b100100: alu_control = 3'b010; // and
                    6'b100101: alu_control = 3'b011; // or
                    6'b101010: alu_control = 3'b100; // slt
                endcase
            end
            6'b001000: begin // addi
                reg_write = 1;
                alu_src = 1;
                alu_control = 3'b000;
            end
            6'b100011: begin // lw
                reg_write = 1;
                alu_src = 1;
                mem_to_reg = 1;
                mem_read = 1;
                alu_control = 3'b000;
            end
            6'b101011: begin // sw
                alu_src = 1;
                mem_write = 1;
                alu_control = 3'b000;
            end
            6'b000100: begin // beq
                branch = 1;
                alu_control = 3'b001;
            end
            6'b000010: begin // j
                jump = 1;
            end
        endcase
    end

    // Sign Extension
    always @(*) begin
        sign_extended = {{16{instruction[15]}}, instruction[15:0]};
    end

    // Register File Read
    always @(*) begin
        read_data1 = registers[instruction[25:21]];
        read_data2 = registers[instruction[20:16]];
        write_reg_addr = reg_dst ? instruction[15:11] : instruction[20:16];
    end

    // Register File Write
    integer i;
    always @(negedge clk) begin
        if (reset) begin
            for (i = 0; i < 32; i = i + 1)
                registers[i] <= 0;
        end
        else if (reg_write && write_reg_addr != 0) begin
            registers[write_reg_addr] <= write_data;
            $display("R[%b] <= %b", write_reg_addr, write_data);
        end
    end

    // ALU
    always @(*) begin
        alu_operand2 = alu_src ? sign_extended : read_data2;
        case (alu_control)
            3'b000: alu_result = read_data1 + alu_operand2;
            3'b001: alu_result = read_data1 - alu_operand2;
            3'b010: alu_result = read_data1 & alu_operand2;
            3'b011: alu_result = read_data1 | alu_operand2;
            3'b100: alu_result = (read_data1 < alu_operand2) ? 1 : 0;
            default: alu_result = 0;
        endcase
        zero = (alu_result == 0);
    end

    // Data Memory Read
    always @(*) begin
        mem_read_data = mem_read ? data_memory[alu_result[7:2]] : 0;
    end

    // Data Memory Write
    always @(posedge clk) begin
        if (mem_write) begin
            data_memory[alu_result[7:2]] <= read_data2;
            $display("M[%b] <= %b", alu_result, read_data2);
        end
    end

    // Write data selection
    always @(*) begin
        write_data = mem_to_reg ? mem_read_data : alu_result;
    end

    // Result output
    always @(*) begin
        result = alu_result;
    end

    // Debug
    always @(posedge clk) begin
        if (!reset) begin
            $display("PC=%b", pc);
            $display("Instruction=%b", instruction);
            $display("ALU Result=%b", alu_result);
        end
    end
endmodule 