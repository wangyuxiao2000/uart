/*************************************************************/
//function: UART数据接收模块
//Author  : WangYuxiao
//Email   : wyxee2000@163.com
//Data    : 2023.7.19
//Version : V 1.1.2
/*************************************************************/
`timescale 1 ns / 1 ps

module uart_rx (clk,rst_n,rx_en,rx_clk,rx,m_axis_tready,m_axis_tdata,m_axis_tvalid,rx_clk_en,check_flag);
/******************************************工作参数设置******************************************/
parameter data_bits=8;          /*定义数据位数,在5-8取值*/
parameter check_mode=1;         /*定义校验位类型——check_mode=0-无校验位,check_mode=1-偶校验位,check_mode=2-奇校验位,check_mode=3-固定0校验位,check_mode=4-固定1校验位*/
/************************************************************************************************/

input clk;                      /*系统时钟*/
input rst_n;                    /*低电平异步复位信号*/
input rx_en;                    /*接收模块使能信号,高电平有效*/
input rx_clk;                   /*接收模块波特率时钟*/
input rx;                       /*FPGA端UART接收口*/
input m_axis_tready;            /*下游模块传来的读请求或读确认信号,高电平有效*/
output reg [7:0] m_axis_tdata;  /*输出UART接收到的数据*/
output reg m_axis_tvalid;       /*输出数据有效标志,高电平有效*/
output reg rx_clk_en;           /*接收模块波特率时钟使能信号,高电平有效*/
output reg check_flag;          /*校验标志位:当校验位存在且校验出错时,check_flag被拉到高电平,data_out_valid也可作为check_flag的有效标志*/



/*****************************************检测起始位到来******************************************/
wire start_flag;
reg rx_reg_0,rx_reg_1,rx_reg_2,rx_reg_3;

always@(posedge clk or negedge rst_n)
begin
  if(!rst_n)
    begin
      rx_reg_0<=1'b0;
      rx_reg_1<=1'b0;
      rx_reg_2<=1'b0;
      rx_reg_3<=1'b0;
    end
  else
    begin
      rx_reg_0<=rx;
      rx_reg_1<=rx_reg_0;
      rx_reg_2<=rx_reg_1;
      rx_reg_3<=rx_reg_2;	
    end
end

assign start_flag=(~rx_reg_2)&&rx_reg_3;
/************************************************************************************************/



/********************************************进行RX接收*******************************************/
reg [4:0] rx_state; /*UART接收状态机*/
reg [data_bits-1:0] data; 
reg [2:0] data_cnt;
reg bit_check;

always@(posedge clk or negedge rst_n)
begin
  if(!rst_n)
    begin
      rx_state<=5'b00001;
      rx_clk_en<=1'b0;
      data_cnt<=0;
      data<=0;
      m_axis_tdata<=0;
      m_axis_tvalid<=1'b0; 
      check_flag<=1'b0; 
    end
  else if (rx_en)
    begin
      case(rx_state)
        5'b00001 : begin/*等待有效数据输入*/
                     if(start_flag)
                       begin
                         rx_state<=5'b00010;
                         rx_clk_en<=1'b1;
                         data_cnt<=0;
                         data<=0;
                         m_axis_tdata<=m_axis_tdata;
                         m_axis_tvalid<=m_axis_tvalid; 
                         check_flag<=check_flag;						  
                       end
                     else
                       begin
                         rx_state<=rx_state;
                         rx_clk_en<=rx_clk_en;
                         data_cnt<=data_cnt;
                         data<=data;
                         m_axis_tdata<=m_axis_tdata;
                         m_axis_tvalid<=m_axis_tvalid; 
                         check_flag<=check_flag; 						
                       end
                   end
        5'b00010 : begin/*接收起始位*/
                     if(rx_clk)
                       begin
                         rx_state<=5'b00100;
                         rx_clk_en<=rx_clk_en;
                         data_cnt<=data_cnt;
                         data<=data;
                         m_axis_tdata<=m_axis_tdata;
                         check_flag<=check_flag;							  
                       end
                     else
                       begin
                         rx_state<=rx_state;
                         rx_clk_en<=rx_clk_en;
                         data_cnt<=data_cnt;
                         data<=data;
                         m_axis_tdata<=m_axis_tdata;
                         check_flag<=check_flag;
                       end
                     
                     if(m_axis_tready)
                       m_axis_tvalid<=1'b0;
                     else
                       m_axis_tvalid<=m_axis_tvalid;
                   end					
        5'b00100 : begin/*接收数据位*/
                     if(rx_clk)
                       begin
                         rx_clk_en<=rx_clk_en;
                         m_axis_tdata<=m_axis_tdata;
                         check_flag<=check_flag;	
                         if(data_cnt==data_bits-1)
                           begin
                             data_cnt<=0;	
                             data[data_cnt]<=rx;
                             rx_state<=5'b01000;							  						  
                           end
                         else
                           begin
                             data_cnt<=data_cnt+1;	
                             data[data_cnt]<=rx;	
                             rx_state<=rx_state;							  
                           end									  
                       end
                     else
                       begin
                         rx_state<=rx_state;
                         rx_clk_en<=rx_clk_en;
                         data_cnt<=data_cnt;
                         data<=data;
                         m_axis_tdata<=m_axis_tdata;
                         check_flag<=check_flag;						
                       end
                     
                     if(m_axis_tready)
                       m_axis_tvalid<=1'b0;
                     else
                       m_axis_tvalid<=m_axis_tvalid;					   
                   end					
        5'b01000 : begin/*接收校验位或第一位停止位后,产生有效输出*/
                     if(rx_clk)
                       begin
                         rx_state<=5'b10000;
                         rx_clk_en<=1'b0;
                         data_cnt<=data_cnt;
                         data<=data;
                         m_axis_tdata<=data;
                         m_axis_tvalid<=1'b1;
                         if(bit_check==rx)
                           check_flag<=1'b0;
                         else
                           check_flag<=1'b1;
                       end
                     else
                       begin
                         rx_state<=rx_state;
                         rx_clk_en<=rx_clk_en;
                         data_cnt<=data_cnt;
                         data<=data;
                         m_axis_tdata<=m_axis_tdata;
                         check_flag<=check_flag;	
                         if(m_axis_tready)
                           m_axis_tvalid<=1'b0;
                         else
                           m_axis_tvalid<=m_axis_tvalid;						 
                       end
                   end
        5'b10000 : begin
                     if(m_axis_tready)/*数据被后级模块读走*/
                       begin
                         rx_state<=5'b00001;
                         rx_clk_en<=rx_clk_en;
                         data_cnt<=data_cnt;
                         data<=data;
                         m_axis_tdata<=m_axis_tdata;
                         m_axis_tvalid<=0;
                         check_flag<=check_flag;
                       end
                     else
                       begin
                         if(start_flag)/*第n次结果没被取走,但发送端的第n+1次传输已经开始,如果继续停留在状态5'b10000,将错过接收第n+1次传输的起始位从而导致同步错误*/
                           begin
                             rx_state<=5'b00010;
                             rx_clk_en<=1'b1;
                             data_cnt<=0;
                             data<=0;
                             m_axis_tdata<=m_axis_tdata;
                             m_axis_tvalid<=m_axis_tvalid;/*虽已开始第n+1次数据接收,但在第n+1次接收的过程中,仍保持第n次接收结果的输出;如果在第n+1次接收的过程中data_out_ready变为高电平,后级模块仍可取走第n次接收结果,如果直至第n+1次接收完成data_out_ready始终保持低电平,则第n次接收结果被第n+1次接收结果冲掉*/
                             check_flag<=check_flag;												 
                           end
                         else
                           begin
                             rx_state<=rx_state;
                             rx_clk_en<=rx_clk_en;
                             data_cnt<=data_cnt;
                             data<=data;
                             m_axis_tdata<=m_axis_tdata;
                             m_axis_tvalid<=m_axis_tvalid;
                             check_flag<=check_flag;						   
                           end
                       end
                   end
	    default : begin
                    rx_state<=5'b00001;
                    rx_clk_en<=1'b0;
                    data_cnt<=0;
                    data<=0;
                    m_axis_tdata<=0;
                    m_axis_tvalid<=1'b0; 
                    check_flag<=1'b0; 		            
                  end
      endcase
    end
  else
    begin
      rx_state<=5'b00001;
      rx_clk_en<=1'b0;
      data_cnt<=0;
      data<=0;
      m_axis_tdata<=0;
      m_axis_tvalid<=1'b0; 
      check_flag<=1'b0; 
    end
end

/*计算校验位理论值*/
always@(*)
begin
  if(!rst_n)
    bit_check=1'b0;
  else
    begin
      case(check_mode)
        3'd0 : bit_check=1'b1;   /*无校验位*/
        3'd1 : bit_check=^data;  /*异或运算产生偶校验位*/
        3'd2 : bit_check=^~data; /*同或运算产生奇校验位*/
        3'd3 : bit_check=1'b0;   /*固定0校验位*/
        3'd4 : bit_check=1'b1;   /*固定1校验位*/
        default:bit_check=1'b0;
      endcase	  
    end
end
/************************************************************************************************/
endmodule