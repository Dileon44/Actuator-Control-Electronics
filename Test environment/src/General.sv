// Actuator control electronics
// ==============================================================================
// Описание:
// Данный файл содержит пакет функций, используемых в проекте.
// ==============================================================================

`ifndef General_Done
`define General_Done

package General;
	typedef bit [31:0] uint32_t;
	typedef bit [ 7:0] uint8_t;
	typedef bit [ 3:0] uint4_t;
	
	localparam uint4_t MINUS 	   = 4'b1010;
	localparam uint4_t AMPLITUDE   = 4'b1011;
	localparam uint4_t FREQUENCY   = 4'b1100;
	localparam uint4_t K_VISCOUS   = 4'b1101;
	localparam uint4_t FIXED_POINT = 4'b1110;
	localparam uint4_t EMPTY 	   = 4'b1111;

	// Logarithm functions 
	function automatic uint32_t clog10 (uint32_t n);
		if (n < 1) begin
			clog10 = 1;
		end else begin
			for (clog10 = 0; n > 0; n /= 10) begin
				clog10++;
			end
		end
	endfunction

	function automatic uint32_t clog2 (uint32_t n);
		if (n < 1) begin
			clog2 = 1;
		end else begin
			for (clog2 = 0; n > 0; n >>= 1) begin
				clog2++;
			end
		end
	endfunction

	// Binary to Binary-Coded Decimal
	function automatic uint32_t Bin2BCD (uint32_t B, Size); 
		if (Size == 4) begin
			Bin2BCD = B;
		end else begin
			Bin2BCD = 0;
			for (int i = 0; i < Size; i += 4) begin
				Bin2BCD[i +: 4] = B % 10;
				B /= 10;
			end
		end
	endfunction

	// Binary-Coded Decimal to Eight-Segment Code
	function automatic uint8_t BCD2ESC (input uint4_t x);
		uint8_t res;
		
		case (x)
			4'h0    	: res = 8'b1100_0000;
			4'h1    	: res = 8'b1111_1001;
			4'h2    	: res = 8'b1010_0100;
			4'h3    	: res = 8'b1011_0000;
			4'h4    	: res = 8'b1001_1001;
			4'h5    	: res = 8'b1001_0010;
			4'h6    	: res = 8'b1000_0010;
			4'h7    	: res = 8'b1111_1000;
			4'h8    	: res = 8'b1000_0000;
			4'h9    	: res = 8'b1001_0000;
			MINUS	    : res = 8'b1011_1111;
			AMPLITUDE   : res = 8'b0000_1000;
		    FREQUENCY   : res = 8'b0000_1110;
			K_VISCOUS   : res = 8'b0011_0110;
			FIXED_POINT : res = 8'b0100_0000;
			EMPTY	    : res = 8'b1111_1111;
		endcase
		return res; 
	endfunction

	// Binary-Coded Decimal to ASCII Code
	function automatic uint8_t BCD2ASCII (input uint4_t x);
		uint8_t res;
		case (x)
			0:  res = 8'h30;
			1:  res = 8'h31;
			2:  res = 8'h32;
			3:  res = 8'h33;
			4:  res = 8'h34;
			5:  res = 8'h35;
			6:  res = 8'h36;
			7:  res = 8'h37;
			8:  res = 8'h38;
			9:  res = 8'h39;
			10: res = 8'h2D;
			15: res = 8'h20;
		endcase
		return res; 
	endfunction

	function automatic uint4_t Binary2Fixed (input uint4_t x);
		case (x)
			0:  Binary2Fixed = 4'h0;
			1:  Binary2Fixed = 4'h0;
			2:  Binary2Fixed = 4'h1;
			3:  Binary2Fixed = 4'h2;
			4:  Binary2Fixed = 4'h3;
			5:  Binary2Fixed = 4'h3;
			6:  Binary2Fixed = 4'h4;
			7:  Binary2Fixed = 4'h4;
			8:  Binary2Fixed = 4'h5;
			9:  Binary2Fixed = 4'h6;
			10: Binary2Fixed = 4'h6;
			11: Binary2Fixed = 4'h7;
			12: Binary2Fixed = 4'h8;
			13: Binary2Fixed = 4'h8;
			14: Binary2Fixed = 4'h9;
			15: Binary2Fixed = 4'h9;
		endcase
	endfunction

	function automatic uint32_t  DeleteNullBCD(uint32_t BCD, uint8_t size_BCD);
		bit sign_is_find 		 = 0;
		bit first_number_is_find = 0;
		bit [3:0] sign_bufer     = 4'hF;

		DeleteNullBCD 			 = 32'hFFFFFFFF;

		for (int i = size_BCD; i > 0; i -= 4) begin
			if (|BCD[(i - 1) -: 4]) begin
				if (sign_is_find) begin
					if (~first_number_is_find) begin
						first_number_is_find = 1;
						DeleteNullBCD[(i - 1 + 4) -: 4] = sign_bufer;
					end
					DeleteNullBCD[(i - 1) -: 4] = BCD[(i - 1) -: 4];
				end else begin
					sign_is_find = 1;
					sign_bufer = (BCD[(i - 1) -: 4] == 4'hF) ? EMPTY : MINUS;
				end
			end else begin
				if (first_number_is_find || (i == 4)) begin
					DeleteNullBCD[(i - 1) -: 4] = BCD[(i - 1) -: 4];
				end 
			end
		end
	endfunction

	function automatic uint32_t DeleteNullBCDUnsigned(uint32_t BCD, uint8_t size_BCD);
		bit first_number_is_find = 0;

		DeleteNullBCDUnsigned = 32'hFFFFFFFF;

		for (int i = size_BCD; i > 0; i -= 4) begin
			if (|BCD[(i - 1) -: 4]) begin
				if (~first_number_is_find) begin
					first_number_is_find = 1;
				end
				DeleteNullBCDUnsigned[(i - 1) -: 4] = BCD[(i - 1) -: 4];
			end else begin
				if (first_number_is_find || (i == 4)) begin
					DeleteNullBCDUnsigned[(i - 1) -: 4] = BCD[(i - 1) -: 4];
				end 
			end
		end
	endfunction

endpackage: General
`endif