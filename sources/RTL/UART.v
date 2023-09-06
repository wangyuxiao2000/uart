/*************************************************************/
//function: UART顶层模块
//Author  : WangYuxiao
//Email   : wyxee2000@163.com
//Data    : 2023.7.19
//Version : V 1.1.2
/*************************************************************/
`timescale 1 ns / 1 ps

module UART (clk,rst_n,tx_en,s_axis_tdata,s_axis_tvalid,s_axis_tready,tx,rx_en,rx,m_axis_tready,m_axis_tdata,m_axis_tvalid,m_axis_tuser);
/******************************************工作参数设置******************************************/
parameter system_clk=50_000000;    /*定义系统时钟频率*/
parameter band_rate=9600;          /*定义波特率*/
parameter data_bits=8;             /*定义数据位数,在5-8取值*/
parameter check_mode=1;            /*定义校验位类型——check_mode=0-无校验位,check_mode=1-偶校验位,check_mode=2-奇校验位,check_mode=3-固定0校验位,check_mode=4-固定1校验位*/
parameter stop_mode=0;             /*定义停止位类型——stop_mode=0——1位停止位,stop_mode=1——1.5位停止位,stop_mode=2——2位停止位*/
parameter tx_fifo_deepth=16;       /*定义发送FIFO的深度(2的n次方)*/
parameter rx_fifo_deepth=16;       /*定义接收FIFO的深度(2的n次方)*/
/************************************************************************************************/
input clk;                  /*系统时钟*/
input rst_n;                /*低电平异步复位信号*/

input tx_en;                /*发送模块使能信号,高电平有效*/
input [7:0] s_axis_tdata;   /*输入数据*/
input s_axis_tvalid;        /*输入数据有效标志,高电平有效*/
output s_axis_tready;       /*向上游模块发送读请求或读确认信号,高电平有效*/
output tx;                  /*FPGA端UART发送口*/

input rx_en;                /*接收模块使能信号,高电平有效*/
input rx;                   /*FPGA端UART接收口*/
input m_axis_tready;        /*下游模块传来的读请求或读确认信号,高电平有效*/
output [7:0] m_axis_tdata;  /*输出数据*/
output m_axis_tvalid;       /*输出数据有效标志,高电平有效*/
output m_axis_tuser;        /*校验标志位:当校验位存在且校验出错时m_axis_tuser被拉到高电平,m_axis_tvalid也可作为m_axis_tuser的有效标志*/



/************************************************************************************************/
wire tx_clk_en,rx_clk_en;
wire tx_clk,rx_clk;
wire [7:0] tx_data,rx_data;
wire tx_data_valid,tx_data_ready,rx_data_valid,rx_data_ready;

baud_rate_clk #(.system_clk(system_clk),
                .band_rate(band_rate)
                ) U1 (.clk(clk),
                      .rst_n(rst_n),
                      .tx_clk_en(tx_clk_en),
                      .rx_clk_en(rx_clk_en),
                      .tx_clk(tx_clk),
                      .rx_clk(rx_clk)
                     );
generate
  if(tx_fifo_deepth==0)
    begin
      assign tx_data=s_axis_tdata;
      assign tx_data_valid=s_axis_tvalid;
      assign s_axis_tready=tx_data_ready;
    end
  else
    begin 
      data_fifo #(.Width(8),
                  .Deepth(tx_fifo_deepth)
                  ) U_tx_fifo (.clk(clk),
                               .rst_n(rst_n),
                               .s_axis_tdata(s_axis_tdata),
                               .s_axis_tvalid(s_axis_tvalid),
                               .s_axis_tready(s_axis_tready),
                               .m_axis_tdata(tx_data),
                               .m_axis_tvalid(tx_data_valid),
                               .m_axis_tready(tx_data_ready)
                              );
    end
endgenerate

uart_tx #(.system_clk(system_clk),
          .band_rate(band_rate),
          .data_bits(data_bits),
          .check_mode(check_mode),
          .stop_mode(stop_mode)
          ) U2 (.clk(clk),
                .rst_n(rst_n),
                .tx_en(tx_en),
                .tx_clk(tx_clk),
                .s_axis_tdata(tx_data),
                .s_axis_tvalid(tx_data_valid),
                .s_axis_tready(tx_data_ready),
                .tx(tx),
                .tx_clk_en(tx_clk_en)
               );	
			   
uart_rx #(.data_bits(data_bits),  
          .check_mode(check_mode)
          ) U3 (.clk(clk),
                .rst_n(rst_n),
                .rx_en(rx_en),
                .rx_clk(rx_clk),
                .rx(rx),
                .m_axis_tready(rx_data_ready),
                .m_axis_tdata(rx_data),
                .m_axis_tvalid(rx_data_valid),
                .rx_clk_en(rx_clk_en),
                .check_flag(m_axis_tuser)
               );

generate
  if(rx_fifo_deepth==0)
    begin
      assign m_axis_tdata=rx_data;
      assign m_axis_tvalid=rx_data_valid;
      assign rx_data_ready=m_axis_tready;
    end
  else
    begin 
      data_fifo #(.Width(8),
                  .Deepth(rx_fifo_deepth)
                  ) U_rx (.clk(clk),
                          .rst_n(rst_n),
                          .s_axis_tdata(rx_data),
                          .s_axis_tvalid(rx_data_valid),
                          .s_axis_tready(rx_data_ready),
                          .m_axis_tdata(m_axis_tdata),
                          .m_axis_tvalid(m_axis_tvalid),
                          .m_axis_tready(m_axis_tready)
                         );
    end
endgenerate
/************************************************************************************************/
  
endmodule