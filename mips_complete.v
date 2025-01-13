// Complete MIPS Single Cycle Implementation
`timescale 1ns/1ps

// ALU Module (from morecode.txt)
module ALU(
    input [31:0] a,             // First operand
    input [31:0] b,             // Second operand
    input [2:0] alu_control,    // Control signal to select operation
    output reg [31:0] result,   // ALU result
    output reg zero             // Zero flag (1 if result is 0)
);
    always @(*) begin
        case (alu_control)
            3'b000: result = a + b;                  // Addition
            3'b001: result = a - b;                  // Subtraction
            3'b010: result = a & b;                  // Bitwise AND
            3'b011: result = a | b;                  // Bitwise OR
            3'b100: result = (a < b) ? 1 : 0;        // Set Less Than
            3'b101: result = ~(a | b);               // NOR
            default: result = 0;                     // Default: 0
        endcase
        zero = (result == 0) ? 1 : 0;
    end
endmodule

//Register Files
module RegisterFile ( 
    input clk,                  
    input reset,                
    input RegWrite,            
    input [4:0] read_reg1,    
    input [4:0] read_reg2,     
    input [4:0] write_reg,     
    input [31:0] write_data,    // 32 refers to the width of the data signals
    output [31:0] read_data1,  
    output [31:0] read_data2   

); 
    // 32 general-purpose registers, each 32 bits wide 
    reg [31:0] registers [31:0]; 

    // Read logic (combinational) 
    assign read_data1 = registers[read_reg1]; 
    assign read_data2 = registers[read_reg2]; 

    // Write logic (sequential) 
    always @(posedge clk or posedge reset) begin 
        if (reset) begin 
            // Reset all registers to 0 
            integer i; 
            for (i = 0; i < 32; i = i + 1) begin 
                registers[i] <= 32'b0; 
            end 
        end else if (RegWrite && write_reg != 0) begin 
            // Write data to the specified register (ignoring $0) 
            registers[write_reg] <= write_data; 
        end 
    end 
endmodule

// Instruction Memory Module (from morecode.txt)
module InstructionMemory(
    input [31:0] address,      // Address input (program counter)
    output [31:0] instruction  // Output instruction
);
    // 256 words (32-bit) instruction memory (1KB)
    reg [31:0] memory [0:255];

    // Initialize the instruction memory with some instructions
    initial begin
        $readmemh("instructions.mem", memory);  // Load instructions from file
    end

    // Fetch instruction from memory
    assign instruction = memory[address[31:2]]; // Word-aligned address
endmodule

// Data Memory Module
module DataMemory(
    input clk,
    input mem_write,
    input mem_read,
    input [31:0] address,
    input [31:0] write_data,
    output reg [31:0] read_data
);
    reg [31:0] memory [0:255];  // 1KB of memory

    // Read operation
    always @(*) begin
        if (mem_read)
            read_data = memory[address[31:2]];
        else
            read_data = 32'b0;
    end

    // Write operation
    always @(posedge clk) begin
        if (mem_write)
            memory[address[31:2]] <= write_data;
    end
endmodule

// Control Unit Module
module ControlUnit(
    input [5:0] opcode,
    input [5:0] funct,
    output reg [2:0] alu_control,
    output reg alu_src,
    output reg branch,
    output reg jump,
    output reg mem_to_reg,
    output reg mem_write,
    output reg reg_dst,
    output reg reg_write,
    output reg mem_read
);
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

        case(opcode)
            6'b000000: begin // R-type
                reg_dst = 1;
                reg_write = 1;
                case(funct)
                    6'b100000: alu_control = 3'b000; // ADD
                    6'b100010: alu_control = 3'b001; // SUB
                    6'b100100: alu_control = 3'b010; // AND
                    6'b100101: alu_control = 3'b011; // OR
                    6'b101010: alu_control = 3'b100; // SLT
                endcase
            end
            6'b001000: begin // ADDI
                alu_src = 1;
                reg_write = 1;
                alu_control = 3'b000;
            end
            6'b101011: begin // SW
                alu_src = 1;
                mem_write = 1;
                alu_control = 3'b000;
            end
            6'b000100: begin // BEQ
                branch = 1;
                alu_control = 3'b001;
            end
            6'b000010: begin // J
                jump = 1;
            end
        endcase
    end
endmodule

// Top-level MIPS Module
module MIPS_Processor(
    input clk,
    input reset,
    output [31:0] result
);
    // Internal wires
    wire [31:0] pc, next_pc;
    wire [31:0] instruction;
    wire [31:0] read_data1, read_data2, write_data;
    wire [31:0] alu_result;
    wire [31:0] mem_read_data;
    wire [31:0] sign_extended;
    wire [2:0] alu_control;
    wire alu_src, branch, jump, mem_to_reg, mem_write, reg_dst, reg_write, mem_read;
    wire zero;

    // Program Counter
    reg [31:0] pc_reg;
    always @(posedge clk or posedge reset) begin
        if (reset)
            pc_reg <= 0;
        else
            pc_reg <= next_pc;
    end
    assign pc = pc_reg;

    // Next PC logic
    wire [31:0] pc_plus4;
    wire [31:0] branch_target;
    wire [31:0] jump_target;
    wire branch_taken;
    
    assign pc_plus4 = pc + 4;
    assign sign_extended = {{16{instruction[15]}}, instruction[15:0]};
    assign branch_target = pc_plus4 + {sign_extended[29:0], 2'b00};
    assign jump_target = {pc_plus4[31:28], instruction[25:0], 2'b00};
    assign branch_taken = branch & zero;
    assign next_pc = jump ? jump_target : (branch_taken ? branch_target : pc_plus4);

    // Control Unit
    ControlUnit control_unit(
        .opcode(instruction[31:26]),
        .funct(instruction[5:0]),
        .alu_control(alu_control),
        .alu_src(alu_src),
        .branch(branch),
        .jump(jump),
        .mem_to_reg(mem_to_reg),
        .mem_write(mem_write),
        .reg_dst(reg_dst),
        .reg_write(reg_write),
        .mem_read(mem_read)
    );

    // Register File
    wire [4:0] write_reg_addr;
    assign write_reg_addr = reg_dst ? instruction[15:11] : instruction[20:16];

    RegisterFile register_file(
        .clk(clk),
        .reset(reset),
        .RegWrite(reg_write),
        .read_reg1(instruction[25:21]),
        .read_reg2(instruction[20:16]),
        .write_reg(write_reg_addr),
        .write_data(mem_to_reg ? mem_read_data : alu_result),
        .read_data1(read_data1),
        .read_data2(read_data2)
    );

    // ALU
    wire [31:0] alu_operand2;
    assign alu_operand2 = alu_src ? sign_extended : read_data2;

    ALU alu(
        .a(read_data1),
        .b(alu_operand2),
        .alu_control(alu_control),
        .result(alu_result),
        .zero(zero)
    );

    // Instruction Memory
    InstructionMemory instr_mem(
        .address(pc),
        .instruction(instruction)
    );

    // Data Memory
    DataMemory data_mem(
        .clk(clk),
        .mem_write(mem_write),
        .mem_read(mem_read),
        .address(alu_result),
        .write_data(read_data2),
        .read_data(mem_read_data)
    );

    // Output the ALU result for testing
    assign result = alu_result;
endmodule

// Test Bench
module MIPS_Processor_tb;
    reg clk;
    reg reset;
    wire [31:0] result;

    // Instantiate the MIPS processor
    MIPS_Processor mips(
        .clk(clk),
        .reset(reset),
        .result(result)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Test stimulus
    initial begin
        // Initialize
        reset = 1;
        #10 reset = 0;

        // Wait for some cycles to execute instructions
        #200;

        // Display results
        $display("\nSimulation completed!");
        $display("Final result: %h", result);
        $finish;
    end

    // Monitor changes
    initial begin
        $monitor("Time=%0d pc=%h instr=%h alu_result=%h zero=%b",
                $time, mips.pc, mips.instruction, mips.alu_result, mips.zero);
    end

    // Additional monitoring
    always @(posedge clk) begin
        if (!reset) begin
            $display("\nAt time %0d:", $time);
            $display("PC = %h", mips.pc);
            $display("Instruction = %h", mips.instruction);
            $display("Register values:");
            $display("$2 = %h", mips.register_file.registers[2]);
            $display("$3 = %h", mips.register_file.registers[3]);
            $display("$4 = %h", mips.register_file.registers[4]);
            $display("$5 = %h", mips.register_file.registers[5]);
            $display("ALU result = %h", mips.alu_result);
            $display("Memory[0] = %h", mips.data_mem.memory[0]);
        end
    end

    // Waveform generation
    initial begin
        $dumpfile("mips_test.vcd");
        $dumpvars(0, MIPS_Processor_tb);
    end
endmodule 