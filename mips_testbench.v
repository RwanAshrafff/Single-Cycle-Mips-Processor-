`timescale 1ns/1ps

module MIPS_Processor_tb;
    reg clk;
    reg reset;
    wire [31:0] result;
    integer file_handle;

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
        // Open file for writing
        file_handle = $fopen("simulation_output.txt", "w");
        
        // Initialize
        reset = 1;
        #10 reset = 0;
        
        // Wait for some cycles to execute instructions
        #300;  // Extended simulation time for longer program

        // Display results
        $display("\nSimulation completed!");
        $display("Final result: %b", result);
        $fdisplay(file_handle, "\nSimulation completed!");
        $fdisplay(file_handle, "Final result: %b", result);
        
        // Close file
        $fclose(file_handle);
        $finish;
    end

    // Monitor changes
    initial begin
        $monitor("Time=%0d pc=%b instr=%b alu_result=%b zero=%b",
                $time, mips.pc, mips.instruction, mips.alu_result, mips.zero);
    end

    // Additional monitoring
    always @(posedge clk) begin
        if (!reset) begin
            // Display to console
            $display("\nAt time %0d:", $time);
            $display("PC = %b", mips.pc);
            $display("Instruction = %b", mips.instruction);
            $display("ALU result = %b", mips.alu_result);
            $display("Read Data 1 = %b", mips.read_data1);
            $display("Read Data 2 = %b", mips.read_data2);
            if (mips.branch) $display("Branch condition: zero=%b", mips.zero);
            if (mips.jump) $display("Jump target: %b", {mips.pc[31:28], mips.instruction[25:0], 2'b00});

            // Write to file
            $fdisplay(file_handle, "\nAt time %0d:", $time);
            $fdisplay(file_handle, "PC = %b", mips.pc);
            $fdisplay(file_handle, "Instruction = %b", mips.instruction);
            $fdisplay(file_handle, "ALU result = %b", mips.alu_result);
            $fdisplay(file_handle, "Read Data 1 = %b", mips.read_data1);
            $fdisplay(file_handle, "Read Data 2 = %b", mips.read_data2);
            if (mips.branch) $fdisplay(file_handle, "Branch condition: zero=%b", mips.zero);
            if (mips.jump) $fdisplay(file_handle, "Jump target: %b", {mips.pc[31:28], mips.instruction[25:0], 2'b00});
        end
    end

    // Waveform generation
    initial begin
        $dumpfile("mips_test.vcd");
        $dumpvars(0, MIPS_Processor_tb);
    end
endmodule 