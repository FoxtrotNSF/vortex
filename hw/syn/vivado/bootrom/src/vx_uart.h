#ifndef VORTEX_VX_UART_H
#define VORTEX_VX_UART_H
#include <inttypes.h>

extern uint8_t UART_MODULE_ADDR;
#define UART_ADDR ((uintptr_t) &UART_MODULE_ADDR)
#define DATA_BITS   8
#define UART_RX_ADDR     (UART_ADDR + 0x00)
#define UART_TX_ADDR     (UART_ADDR + 0x04)
#define UART_STAT_ADDR   (UART_ADDR + 0x08)
#define UART_CTRL_ADDR   (UART_ADDR + 0x0C)


typedef struct __attribute__((packed)) {
    unsigned reset_rx_fifo : 1;
    unsigned reset_tx_fifo : 1;
    unsigned reserved_1 : 2;
    unsigned enable_intr : 1;
    unsigned reserved_2 : 27;
} uart_ctrl_t;

typedef struct __attribute__((packed)) {
    unsigned rx_fifo_valid : 1;
    unsigned rx_fifo_full : 1;
    unsigned tx_fifo_empty : 1;
    unsigned tx_fifo_full : 1;
    unsigned intr_enabled : 1;
    unsigned overrun_error : 1;
    unsigned frame_error : 1;
    unsigned parity_error : 1;
    unsigned reserved : 24;
} uart_status_t;

typedef struct __attribute__((packed)) {
    char data;
    unsigned reserved : 24;
} uart_fifo_t;

//static_assert(sizeof(uart_status_t) == sizeof(unsigned int));
//static_assert(sizeof(uart_ctrl_t)   == sizeof(unsigned int));
//static_assert(sizeof(uart_fifo_t)   == sizeof(unsigned int));

void uart_init(unsigned int enable_intr);

int uart_write(unsigned char data);

void uart_blocking_write(unsigned char data);

char uart_read();

void uart_flush();

int uart_available();

char uart_blocking_read();

uint32_t uart_blocking_read_unsigned();

#endif //VORTEX_VX_UART_H
