/*************************************************************/
//function: UART数据发送模块
//Author  : WangYuxiao
//Email   : wyxee2000@163.com
//Data    : 2023.7.19
//Version : V 1.1.2
/*************************************************************/
`timescale 1 ns / 1 ps

module uart_tx (clk,rst_n,tx_en,tx_clk,s_axis_tdata,s_axis_tvalid,s_axis_tready,tx,tx_clk_en);
/******************************************工作参数设置******************************************/
parameter system_clk=50_000000;    /*定义系统时钟频率*/
parameter band_rate=9600;          /*定义波特率*/
parameter data_bits=8;             /*定义数据位数,在5-8取值*/
parameter check_mode=1;            /*定义校验位类型——check_mode=0-无校验位,check_mode=1-偶校验位,check_mode=2-奇校验位,check_mode=3-固定0校验位,check_mode=4-固定1校验位*/
parameter stop_mode=0;             /*定义停止位类型——stop_mode=0——1位停止位,stop_mode=1——1.5位停止位,stop_mode=2——2位停止位*/
localparam N=system_clk/band_rate; /*计算每bit持续的时钟数*/
localparam stop_time=(stop_mode==0)?(N-1):((stop_mode==1)?(3*N/2-1):(2*N-1)); /*计算停止位持续的时钟数*/
/************************************************************************************************/

input clk;                         /*系统时钟*/
input rst_n;                       /*低电平异步复位信号*/
input tx_en;                       /*发送模块使能信号,高电平有效*/
input tx_clk;                      /*发送模块波特率时钟*/
input [7:0] s_axis_tdata;          /*待发送数据*/
input s_axis_tvalid;               /*待发送数据有效标志,高电平有效*/
output reg s_axis_tready;          /*向上游模块发送读请求或读确认信号,高电平有效*/
output reg tx;                     /*FPGA端UART发送口*/
output reg tx_clk_en;              /*发送模块波特率时钟使能信号,高电平有效*/



/********************************************计算校验位*******************************************/
reg bit_check;             /*校验位*/
reg [data_bits-1:0] data;  /*寄存AXIS接口传来的待发送数据*/

always@(*)
begin
  if(!rst_n)
    bit_check=1'b0;
  else
    begin
      case(check_mode)
        3'd0 : bit_check=1'b0;   /*无校验位*/
        3'd1 : bit_check=^data;  /*异或运算产生偶校验位*/
        3'd2 : bit_check=^~data; /*同或运算产生奇校验位*/
        3'd3 : bit_check=1'b0;   /*固定0校验位*/
        3'd4 : bit_check=1'b1;   /*固定1校验位*/
        default:bit_check=1'b0;
      endcase
    end
end
/************************************************************************************************/



/*******************************************进行TX发送********************************************/
reg [5:0] tx_state;                 /*UART发送状态机*/
reg [2:0] data_cnt;                 /*已发送数据个数的计数信号*/
reg [$clog2(2*N-1):0] stop_cnt;     /*停止位的计时信号*/

always@(posedge clk or negedge rst_n)
begin
  if(!rst_n)
    begin
      tx_state<=6'b000001;
      s_axis_tready<=1'b0;
      data<=0;
      tx_clk_en<=1'b0;
      tx<=1'b1;
      data_cnt<=0;
      stop_cnt<=0;      
    end
  else
    begin
      case(tx_state)
        6'b000001 : begin/*等待有效数据输入*/
                      if(s_axis_tvalid&&s_axis_tready)
                        begin
                          tx_state<=6'b000010;
                          s_axis_tready<=1'b0;
                          data<=s_axis_tdata;
                          tx_clk_en<=1'b1;
                          tx<=1'b1;
                          data_cnt<=0;
                          stop_cnt<=0;
                        end
                      else
                        begin
                          tx_state<=tx_state;
                          s_axis_tready<=1'b1;
                          data<=data;
                          tx_clk_en<=1'b0;
                          tx<=1'b1;
                          data_cnt<=0;
                          stop_cnt<=0;
                        end
                    end

        6'b000010 : begin/*发送起始位*/
                      if(tx_clk)
                        begin
                          tx_state<=6'b000100;
                          s_axis_tready<=s_axis_tready;
                          tx_clk_en<=tx_clk_en;
                          stop_cnt<=stop_cnt;
                          data_cnt<=data_cnt;
                          tx<=1'b0;
                        end
                      else
                        begin
                          tx_state<=tx_state;
                          s_axis_tready<=s_axis_tready;
                          data<=data;
                          tx_clk_en<=tx_clk_en;
                          tx<=tx;
                          data_cnt<=data_cnt;
                          stop_cnt<=stop_cnt;
                        end
                    end

        6'b000100 : begin/*发送数据位(按从LSB到MSB的顺序发送)*/
                      if(tx_clk)
                        begin
                          s_axis_tready<=s_axis_tready;
                          data<=data;
                          tx_clk_en<=tx_clk_en;
                          tx<=data[data_cnt];
                          stop_cnt<=stop_cnt;
                          if(data_cnt==data_bits-1)
                            begin
                              data_cnt<=0;
                              if(check_mode==3'd0)/*无校验位*/
                                tx_state<=6'b010000;
                              else
                                tx_state<=6'b001000;
                            end
                          else
                            begin
                              data_cnt<=data_cnt+1;
                              tx_state<=tx_state;
                            end
                        end
                      else
                        begin
                          tx_state<=tx_state;
                          s_axis_tready<=s_axis_tready;
                          data<=data;
                          tx_clk_en<=tx_clk_en;
                          tx<=tx;
                          data_cnt<=data_cnt;
                          stop_cnt<=stop_cnt;
                        end
                    end

        6'b001000 : begin/*发送校验位*/
                      if(tx_clk)
                        begin
                          tx_state<=6'b010000;
                          s_axis_tready<=s_axis_tready;
                          data<=data;
                          tx_clk_en<=tx_clk_en;
                          tx<=bit_check; 
                          stop_cnt<=stop_cnt;
                          data_cnt<=data_cnt;                
                        end
                      else
                        begin
                          tx_state<=tx_state;
                          s_axis_tready<=s_axis_tready;
                          data<=data;
                          tx_clk_en<=tx_clk_en;
                          tx<=tx;
                          data_cnt<=data_cnt;
                          stop_cnt<=stop_cnt;                          
                        end
                    end

        6'b010000 : begin/*发送停止位*/
                      if(tx_clk)
                        begin
                          tx_state<=6'b100000;
                          s_axis_tready<=s_axis_tready;
                          data<=data;
                          tx_clk_en<=tx_clk_en;
                          tx<=1'b1;
                          stop_cnt<=stop_cnt;
                          data_cnt<=data_cnt;
                        end
                      else
                        begin
                          tx_state<=tx_state;
                          s_axis_tready<=s_axis_tready;
                          data<=data;
                          tx_clk_en<=tx_clk_en;
                          tx<=tx;
                          data_cnt<=data_cnt;
                          stop_cnt<=stop_cnt; 
                        end		        
                    end

        6'b100000 : begin/*等待停止位发送完成*/
                      if(stop_cnt==stop_time)
                        begin
                          data_cnt<=data_cnt;
                          stop_cnt<=stop_cnt+1;
                          tx_state<=6'b000001;
                          s_axis_tready<=1'b1;
                          data<=data;
                          tx_clk_en<=1'b0;
                          tx<=1'b1;
                          data_cnt<=0;
                          stop_cnt<=0;
                        end
                      else
                        begin
                          tx_state<=tx_state;
                          s_axis_tready<=s_axis_tready;
                          data<=data;
                          tx_clk_en<=tx_clk_en;
                          tx<=tx;
                          data_cnt<=data_cnt;
                          stop_cnt<=stop_cnt+1;
                        end                      
                    end

        default : begin
                    tx_state<=6'b000001;
                    s_axis_tready<=1'b0;
                    data<=0;
                    tx_clk_en<=1'b0;
                    tx<=1'b1;
                    data_cnt<=0;
                    stop_cnt<=0;
                  end
      endcase
    end
end
/************************************************************************************************/

endmodule