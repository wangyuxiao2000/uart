/*************************************************************/
//function: UART波特率时钟发生模块
//Author  : WangYuxiao
//Email   : wyxee2000@163.com
//Data    : 2023.7.19
//Version : V 1.1.2
/*************************************************************/
`timescale 1 ns / 1 ps 

module baud_rate_clk (clk,rst_n,tx_clk_en,rx_clk_en,tx_clk,rx_clk);
/*******************************************工作参数设置******************************************/
parameter system_clk=50_000000;    /*定义系统时钟频率*/
parameter band_rate=9600;          /*定义波特率*/
localparam N=system_clk/band_rate; /*计算分频系数*/
/************************************************************************************************/
input clk;          /*系统时钟*/
input rst_n;        /*低电平异步复位信号*/
input tx_clk_en;    /*发送模块波特率时钟使能信号,高电平有效*/
input rx_clk_en;    /*接收模块波特率时钟使能信号,高电平有效*/
output tx_clk;      /*发送模块波特率时钟*/
output rx_clk;      /*接收模块波特率时钟*/



/*******************************************产生tx_clk*******************************************/
reg [$clog2(N-1):0] tx_clk_cnt;
always@(posedge clk or negedge rst_n)
begin
  if(!rst_n)
    tx_clk_cnt<=0;
  else if(tx_clk_en)
    begin
      if(tx_clk_cnt==N-1)
        tx_clk_cnt<=0;
      else
        tx_clk_cnt<=tx_clk_cnt+1'd1;
    end
  else 
    tx_clk_cnt<=0;
end

assign tx_clk=(tx_clk_cnt==1)?1:0;
/************************************************************************************************/



/*******************************************产生rx_clk*******************************************/
reg [$clog2(N-1):0] rx_clk_cnt;
always@(posedge clk or negedge rst_n)
begin
  if(!rst_n)
    rx_clk_cnt<=0;
  else if(rx_clk_en)
    begin
      if(rx_clk_cnt==N-1)
        rx_clk_cnt<=0;
      else
        rx_clk_cnt<=rx_clk_cnt+1'd1;
    end
  else 
    rx_clk_cnt<=0;
end

assign rx_clk=(rx_clk_cnt==N/2)?1:0;
/************************************************************************************************/

endmodule 