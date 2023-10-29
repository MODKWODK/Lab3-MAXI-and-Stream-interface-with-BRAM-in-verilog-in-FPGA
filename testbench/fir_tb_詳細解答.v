//`include "fir-dev/bram/bram11.v"
//`include "fir-dev/rtl/fir.v"
// `include "fir-ans/fir/out_gold.dat"
// `include "fir-ans/fir/samples_triangular_wave.dat"
`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/20/2023 10:38:55 AM
// Design Name: 
// Module Name: fir_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module fir_tb
#(  parameter pADDR_WIDTH = 12,
    parameter pDATA_WIDTH = 32,
    parameter Tape_Num    = 11,
    parameter Data_Num    = 600
)();
    wire                        awready;
    wire                        wready;
    reg                         awvalid;
    reg   [(pADDR_WIDTH-1): 0]  awaddr;
    reg                         wvalid;
    reg signed [(pDATA_WIDTH-1) : 0] wdata;
    wire                        arready;
    reg                         rready;
    reg                         arvalid;
    reg         [(pADDR_WIDTH-1): 0] araddr;
    wire                        rvalid;
    wire signed [(pDATA_WIDTH-1): 0] rdata;
    reg                         ss_tvalid;
    reg signed [(pDATA_WIDTH-1) : 0] ss_tdata;
    reg                         ss_tlast;
    wire                        ss_tready;
    reg                         sm_tready;
    wire                        sm_tvalid;
    wire signed [(pDATA_WIDTH-1) : 0] sm_tdata;
    wire                        sm_tlast;
    reg                         axis_clk;
    reg                         axis_rst_n;

// ram for tap
    wire [3:0]               tap_WE;
    wire                     tap_EN;
    wire [(pDATA_WIDTH-1):0] tap_Di;
    wire [(pADDR_WIDTH-1):0] tap_A;
    wire [(pDATA_WIDTH-1):0] tap_Do;

// ram for data RAM
    wire [3:0]               data_WE;
    wire                     data_EN;
    wire [(pDATA_WIDTH-1):0] data_Di;
    wire [(pADDR_WIDTH-1):0] data_A;
    wire [(pDATA_WIDTH-1):0] data_Do;

//  parameters
    reg error_coef;    


/*.xxx(xxx)腳位，命名*/
    fir fir_DUT( //調用FIR的資料
        .awready(awready),
        .wready(wready),
        .awvalid(awvalid),
        .awaddr(awaddr),
        .wvalid(wvalid),
        .wdata(wdata),
        .arready(arready),
        .rready(rready),
        .arvalid(arvalid),
        .araddr(araddr),
        .rvalid(rvalid),
        .rdata(rdata),
        .ss_tvalid(ss_tvalid),
        .ss_tdata(ss_tdata),
        .ss_tlast(ss_tlast),
        .ss_tready(ss_tready),
        .sm_tready(sm_tready),
        .sm_tvalid(sm_tvalid),
        .sm_tdata(sm_tdata),
        .sm_tlast(sm_tlast),

        // ram for tap
        .tap_WE(tap_WE),
        .tap_EN(tap_EN),
        .tap_Di(tap_Di),
        .tap_A(tap_A),
        .tap_Do(tap_Do),

        // ram for data
        .data_WE(data_WE),
        .data_EN(data_EN),
        .data_Di(data_Di),
        .data_A(data_A),
        .data_Do(data_Do),

        .axis_clk(axis_clk),
        .axis_rst_n(axis_rst_n)

        );
    
    // RAM for tap
    bram11 tap_RAM ( //對照好BRAM的接口，用於儲存FIR的輸入數據
        .CLK(axis_clk),
        .WE(tap_WE),
        .EN(tap_EN),
        .Di(tap_Di),
        .A(tap_A),
        .Do(tap_Do)
    );

    // RAM for data: choose bram11 or bram12
    bram11 data_RAM( //對照好BRAM的接口，用於儲存FIR的係數(tap coefficients)
        .CLK(axis_clk),
        .WE(data_WE),
        .EN(data_EN),
        .Di(data_Di),
        .A(data_A),
        .Do(data_Do)
    );

    reg signed [(pDATA_WIDTH-1):0] Din_list[0:(Data_Num-1)];//開一個Din_list大小，每個處存位置bit數為pDATA_WIDTH-1。
    reg signed [(pDATA_WIDTH-1):0] golden_list[0:(Data_Num-1)];//同理於136。




    //initail語法會前後執行，並非所有initial同步

    initial begin //這兩行程式碼是用來產生模擬波形檔（VCD 檔案）的命令。
        $dumpfile("fir.vcd"); 
        $dumpvars();
    end


    initial begin
        axis_clk = 0; //初始化CLK
        forever begin
            #5 axis_clk = (~axis_clk); //它會週期性地切換 axis_clk 訊號的值，即在每5個時間單元之後，將 axis_clk 取反。這是一種創建模擬時脈訊號的方法，以便在模擬中模擬系統的時序行為。
        end
    end

    initial begin
        axis_rst_n = 0;
        @(posedge axis_clk); @(posedge axis_clk); //第二個CLK啟動reset，兩個上升後把axis_rst_n設為1。
        axis_rst_n = 1;
    end


    //程式碼初始化了 data_length，開啟了兩個外部文件，迭代讀取這些文件中的數據，將數據儲存在相應的數組中，並追蹤已讀取的數據量。這些數據將在後續的模擬過程中用於輸入和驗證。
    reg [31:0]  data_length;
    integer Din, golden, input_data, golden_data, m;
    initial begin
        data_length = 0; //表示在模擬開始時，還沒有讀取任何資料。
        Din = $fopen("./samples_triangular_wave.dat","r"); //開啟外部文件 samples_triangular_wave.dat 。這些文件用於儲存輸入資料和期望的輸出資料。定義Din要做的工作。
        golden = $fopen("./out_gold.dat","r"); //開啟外部文件out_gold.dat。這些文件用於儲存輸入資料和期望的輸出資料。定義golden要做的工作。
        for(m=0;m<Data_Num;m=m+1) begin
            input_data = $fscanf(Din,"%d", Din_list[m]); //從檔案 Din 中讀取整數，並將其儲存在 input_data 中。然後，將 input_data 儲存在 Din_list 陣列的第 m 個位置
            $display("%d.",Din_list[m]); //在模擬過程中顯示已經讀取的數據，以進行偵錯和追蹤。
            golden_data = $fscanf(golden,"%d", golden_list[m]); //這一行從檔案 golden 中讀取整數，並將其儲存在 golden_data 中。然後，將 golden_data 儲存在 golden_list 陣列的第 m 個位置。
            data_length = data_length + 1;
        end
    end

    //底下兩段用於模擬 FIR 濾波器的輸入資料傳輸、輸出資料驗證，檢查狀態位，記錄錯誤，然後根據錯誤狀態輸出對應的訊息，並結束模擬過程。這是用於驗證 FIR 濾波器設計的測試台中的一個重要部分。
    integer i;
    initial begin
        $display("------------Start simulation-----------");
        ss_tvalid = 0; // ss_tvalid 訊號設為0，表示資料流的有效性為否，目前尚未準備好。
        $display("----Start the data input(AXI-Stream)----");
        for(i=0;i<(data_length-1);i=i+1) begin //將輸入資料傳送到 FIR 濾波器。
            ss_tlast = 0; //ss_tlast = 0;：在每次循環迭代中，將 AXI-Stream 介面的 ss_tlast 訊號設為0，表示資料幀不是最後一個。
            ss(Din_list[i]); //ss(Din_list[i]);：呼叫 ss 任務，將 Din_list 中的輸入資料傳送至 FIR 濾波器。
        end
        config_read_check(12'h00, 32'h00, 32'h0000_000f); // check idle = 0 (0x00 [bit 0~3]=4'b0000) 。檢查 FIR 濾波器的狀態。它檢查 ap_idle 位元是否為1（0x00 [bit 0~3]=4'b0000），表示濾波器處於閒置狀態。
        ss_tlast = 1; ss(Din_list[(Data_Num-1)]); //這行程式碼將 AXI-Stream 介面的 ss_tlast 訊號設為1，表示資料幀是最後一個，然後將最後一個輸入資料傳送到 FIR 濾波器。
        @(posedge axis_clk) begin
            ss_tlast =0; //ss_tlast = 0;：將 ss_tlast 訊號重新設為0，表示資料幀不是最後一個。
            ss_tvalid=0; //ss_tvalid = 0;：將 ss_tvalid 訊號設為0，表示資料流的有效性為否，目前尚未準備好。
        end
        $display("------End the data input(AXI-Stream)------");
    end

    integer k;
    reg error;
    reg status_error;
    initial begin
        error = 0; status_error = 0; //這兩行聲明了兩個暫存器，分別用於記錄錯誤狀態和狀態錯誤。
        sm_tready = 1; //將 AXI-Stream 介面中的 sm_tready 訊號設為1，表示系統已準備好接收資料。
        wait (sm_tvalid); //ready一直=1，只要等待 AXI-Stream 介面中的 sm_tvalid 訊號變為1，就表示資料準備好傳送到 FIR 濾波器。
        for(k=0;k < data_length;k=k+1) begin
            sm(golden_list[k],k); //呼叫 sm 任務，將 golden_list 中的期望輸出資料傳送到 FIR 濾波器。同時，記錄錯誤狀態。
        end

        //這兩行分別用於檢查 ap_done 位元和 ap_idle 位元的狀態，以驗證濾波器的完成和閒置狀態

        //底下這行三個數字分別用來：(1)用於檢查 ap_done 位元的狀態。 
        //(2)32'h02 的所有位元都是0，除了最低位為1。去和ap_done比對，若不=32'h02(也就是1)，則表示檢查失敗。
        //(3)用於指定要檢查的位元。在這種情況下，32'h0000_0002 表示只檢查最低位元（ap_done 位元）是否符合。
        config_read_check(12'h00, 32'h02, 32'h0000_0002); // check ap_done = 1 (0x00 [bit 1])
        //下面這行同理
        config_read_check(12'h00, 32'h04, 32'h0000_0004); // check ap_idle = 1 (0x00 [bit 2])
        if (error == 0 & error_coef == 0) begin //一行檢查 error 和 error_coef 變數的狀態，如果它們都是0，表示沒有錯誤和係數錯誤，將輸出「Congratulations! Pass」 訊息。
            $display("---------------------------------------------");
            $display("-----------Congratulations! Pass-------------");
        end
        else begin
            $display("--------Simulation Failed---------"); //如果存在錯誤，將輸出「Simulation Failed」 訊息。
        end
        $finish; //結束模擬過程
    end

    // Prevent hang。這段程式碼用於在仿真運行的時脈週期達到一定數量後，結束仿真，以避免仿真無限掛起或陷入無限循環。這是一種常見的安全措施，以確保模擬不會無限持續，而是在合理的時間內完成。
    integer timeout = (1000000); //這個值表示允許模擬運行的最大時脈週期數。
    initial begin
        while(timeout > 0) begin //它會在允許的時脈週期數內運行
            @(posedge axis_clk);
            timeout = timeout - 1;
        end
        $display($time, "Simualtion Hang ...."); //一旦 while 迴圈退出，表示已經消耗了指定的時脈週期
        $finish;
    end


    reg signed [31:0] coef[0:10]; // 使用FIR計算時需要的係數，fill in coef 
    initial begin
        coef[0]  =  32'd0;
        coef[1]  = -32'd10;
        coef[2]  = -32'd9;
        coef[3]  =  32'd23;
        coef[4]  =  32'd56;
        coef[5]  =  32'd63;
        coef[6]  =  32'd56;
        coef[7]  =  32'd23;
        coef[8]  = -32'd9;
        coef[9]  = -32'd10;
        coef[10] =  32'd0;
    end

    reg error_coef;// 這段程式碼用來初始化FIR濾波器的係數和配置暫存器，然後啟動FIR濾波器的操作。它還包括了檢查已寫入的係數以確保一致性的步驟。
    initial begin
        error_coef = 0;
        $display("----Start the coefficient input(AXI-lite)----");
        config_write(12'h10, data_length);//呼叫名為 config_write 的任務，向FIR濾波器的配置暫存器寫入資料。在這裡，12'h10 是配置暫存器的位址，data_length 是要寫入的資料。這個操作似乎用於設定資料的長度
        for(k=0; k< Tape_Num; k=k+1) begin
            config_write(12'h20+4*k, coef[k]); //用於初始化FIR濾波器的係數。 
        end
        awvalid <= 0; wvalid <= 0; //初始化，表示尚未被啟動
        // read-back and check
        $display(" Check Coefficient ...");
        for(k=0; k < Tape_Num; k=k+1) begin
            config_read_check(12'h20+4*k, coef[k], 32'hffffffff); //於從FIR濾波器的配置暫存器讀回係數，並檢查讀回的值是否與期望值 (coef[k]) 相符。 32'hffffffff 用作掩碼，表示檢查所有位元。
        end
        arvalid <= 0; //將AXI-Stream介面的 arvalid 訊號設為0，即reset。
        $display(" Tape programming done ...");
        $display(" Start FIR");
        @(posedge axis_clk) config_write(12'h00, 32'h0000_0001);  // 等待 axis_clk 的上升沿，然後呼叫 config_write 任務，將 ap_start 位元設為1，以啟動FIR濾波器的操作。
        @(posedge axis_clk) config_write(12'h00, 32'h0000_0000); //再次等待 axis_clk 的上升沿，然后将 ap_start 位设置为0，表示操作结束。
        $display("----End the coefficient input(AXI-lite)----");
        //@(posedge wready)config_write(12'h00, 32'h0000_0000); 
    end


    //這段程式碼用於向FIR濾波器的配置暫存器寫入資料。它透過設定 awvalid、wvalid 以及對應的位址和資料來啟動寫入操作，然後等待介面準備好接收資料。一旦介面準備好，任務結束。
    task config_write;
        input [11:0]    addr;
        input [31:0]    data;
        begin
            awvalid <= 0; wvalid <= 0; //初始化，表示尚未被啟動
            @(posedge axis_clk);
            awvalid <= 1; awaddr <= addr; //在上升沿到來後，將 awvalid 設為1，表示寫入操作已啟動。同時，將 awaddr 設定為傳遞給任務的 addr 值，即配置暫存器的位址。
            wvalid  <= 1; wdata <= data; //將 wvalid 設為1，表示資料有效。同時，將 wdata 設定為傳遞給任務的 data 值，也就是要寫入的資料。
            @(posedge axis_clk);//@(posedge axis_clk);：再次等待下一個 axis_clk 訊號的上升沿。
            while (!wready) @(posedge axis_clk);//這是一個循環，它會在等待 wready 訊號變為1時退出。 wready 表示AXI-Stream介面已準備好接受資料。在循環中，等待 wready 變為1，然後任務結束。
        end
    endtask


    //底下用於請求讀取FIR濾波器的配置暫存器，然後檢查實際讀取的資料是否與期望資料一致。如果一致，輸出“OK”訊息，否則輸出“ERROR”訊息。這有助於驗證FIR濾波器的配置和狀態。
    task config_read_check;
        //這三行addr 是配置暫存器的位址，exp_data 是期望的讀回數據，mask 是一個用於掩碼匹配的值。
        input [11:0]        addr;
        input signed [31:0] exp_data;
        input [31:0]        mask; 
        begin
            arvalid <= 0; //將AXI-Stream介面的 arvalid 訊號設為0，表示讀取操作未啟動。
            @(posedge axis_clk);
            arvalid <= 1; araddr <= addr; //在上升沿到來後，將 arvalid 設為1，表示讀取操作已啟動。同時，將 araddr 設定為傳遞給任務的 addr 值，即配置暫存器的位址。
            rready <= 1;
            @(posedge axis_clk);
            while (!rvalid) @(posedge axis_clk);
            if( (rdata & mask) != (exp_data & mask)) begin
                $display("ERROR: exp = %d, rdata = %d", exp_data, rdata);
                error_coef <= 1;
            end else begin
                $display("OK: exp = %d, rdata = %d", exp_data, rdata);
            end
        end
    endtask


    //使用AXI-Stream工作
    task ss;
        input  signed [31:0] in1;
        begin
            ss_tvalid <= 1;
            ss_tdata  <= in1; //將 in1 的值賦給 ss_tdata，即將輸入資料放入 AXI-Stream 介面中。
            @(posedge axis_clk);
            while (!ss_tready) begin //等待 ss_tready 訊號變為1，這表示介面已經準備好接受下一個資料。
                @(posedge axis_clk); //一旦 ss_tready 變成1，任務就會退出，表示資料已經成功傳輸。
            end
        end
    endtask


    //這個任務用來比較你​​的設計產生的數據與預期的黃金數據是否一致，以驗證設計的正確性。如果兩者不一致，將會報告錯誤。
    task sm;
        input  signed [31:0] in2; // golden data
        input         [31:0] pcnt; // pattern count
        begin
            sm_tready <= 1; //sm_tready 訊號設定為 1，表示資料準備好。
            @(posedge axis_clk) 
            wait(sm_tvalid); //等待 sm_tvalid 訊號變為 1，表示資料有效。
            while(!sm_tvalid) @(posedge axis_clk); //在資料有效之前，不斷等待時脈訊號。
            if (sm_tdata != in2) begin //比較處理後的資料 sm_tdata 與黃金資料 in2 是否相等。
                $display("[ERROR] [Pattern %d] Golden answer: %d, Your answer: %d", pcnt, in2, sm_tdata); //如果 sm_tdata 不等於 in2，則顯示錯誤訊息，顯示黃金答案和你的答案，然後將 error 訊號設為 1，表示出現錯誤。
                error <= 1; //如果 sm_tdata 等於 in2，則顯示透過訊息，顯示黃金答案和你的答案。
            end
            else begin
                $display("[PASS] [Pattern %d] Golden answer: %d, Your answer: %d", pcnt, in2, sm_tdata);
            end
            @(posedge axis_clk);
        end
    endtask
endmodule

