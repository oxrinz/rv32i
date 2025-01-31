module instruction_memory (
    input  wire [31:0] addr,
    output reg  [31:0] instr_out
);
  reg [31:0] memory[0:1023];
  integer i;
  integer file;
  integer status;
  reg continue_reading;

  initial begin 
    for (i = 0; i < 1024; i = i + 1) begin
      memory[i] = 32'h0;
    end

    file = $fopen("program", "rb");
    if (file == 0) begin
      $display("Error: Failed to open file");
      $finish;
    end

    i = 0;
    continue_reading = 1;

    while (continue_reading && i < 1024) begin
      status = $fgetc(file);
      if (status != -1) begin
        memory[i][31:24] = status;

        status = $fgetc(file);
        if (status != -1) begin
          memory[i][23:16] = status;

          status = $fgetc(file);
          if (status != -1) begin
            memory[i][15:8] = status;

            status = $fgetc(file);
            if (status != -1) begin
              memory[i][7:0] = status;
            end else begin
              memory[i][7:0]   = 8'h00;
              continue_reading = 0;
            end
          end else begin
            memory[i][15:0]  = 16'h0000;
            continue_reading = 0;
          end
        end else begin
          memory[i][23:0]  = 24'h000000;
          continue_reading = 0;
        end
        i = i + 1;
      end else begin
        continue_reading = 0;
      end
    end

    $fclose(file);
    $display("Loaded %0d 32-bit instructions", i);
  end

  always @(*) begin
    instr_out = memory[addr>>2];
  end

endmodule