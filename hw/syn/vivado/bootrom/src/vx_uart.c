#include <vx_uart.h>

void write_reg(uintptr_t reg, void* data){
    *(volatile uint32_t*) reg = *(uint32_t*) data;
}

void read_reg(uintptr_t reg, void* data){
    *(volatile uint32_t*) data = *(uint32_t*) reg;
}

void uart_init(unsigned int enable_intr){
    uart_ctrl_t ctrl_data = {.reset_rx_fifo = 1,
            .reset_tx_fifo = 1,
            .reserved_1 = 0,
            .enable_intr = enable_intr,
            .reserved_2 = 0};
    write_reg(UART_CTRL_ADDR, &ctrl_data);
}

int uart_write(unsigned char data){
    uart_status_t uart_stat;
    read_reg(UART_STAT_ADDR, &uart_stat);
    if(uart_stat.tx_fifo_full) return 0;
    uart_fifo_t tx_data = {.data = data,
            .reserved = 0};
    write_reg(UART_TX_ADDR, &tx_data);
    return 1;
}

void uart_flush(){
    uart_status_t uart_stat;
    read_reg(UART_STAT_ADDR, &uart_stat);
    while(!uart_stat.tx_fifo_empty) read_reg(UART_STAT_ADDR, &uart_stat);
}

void uart_blocking_write(unsigned char data){
    while (!uart_write(data));
}

int uart_available(){
    uart_status_t uart_stat;
    read_reg(UART_STAT_ADDR, &uart_stat);
    return uart_stat.rx_fifo_valid;
}

char uart_read(){
    uart_fifo_t uart_rx;
    read_reg(UART_RX_ADDR, &uart_rx);
    return uart_rx.data;
}

char uart_blocking_read(){
    while(!uart_available());
    return uart_read();
}

uint32_t uart_blocking_read_unsigned(){
    char data[sizeof(uint32_t)];
    for(int i = 0; i < sizeof(uint32_t); i++) data[i] = uart_blocking_read();
    return *(uint32_t*) &data;
}

#ifdef USE_UART_FOR_VX_PRINT
void vx_putchar(int c){
    uart_blocking_write((unsigned char) c);
}
#endif
