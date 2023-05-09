//
// Created by noic on 09/05/23.
//

#ifndef VORTEX_VX_UART_H
#define VORTEX_VX_UART_H

#define UART_MODULE_ADDR    0xFF000000
#define DATA_BITS   8
#define UART_RX_ADDR     (UART_MODULE_ADDR + 0x00)
#define UART_TX_ADDR     (UART_MODULE_ADDR + 0x04)
#define UART_CTRL_ADDR   (UART_MODULE_ADDR + 0x08)
#define UART_STAT_ADDR   (UART_MODULE_ADDR + 0x0C)


typedef struct __attribute__((packed)) {
    unsigned reset_rx_fifo : 1;
    unsigned reset_tx_fifo : 1;
    unsigned reserved_2 : 2;
    unsigned enable_intr : 1;
    unsigned reserved_1 : 27;
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
    unsigned char data;
    unsigned reserved : 24;
} uart_fifo_t;

//static_assert(sizeof(uart_status_t) == sizeof(unsigned int));
//static_assert(sizeof(uart_ctrl_t)   == sizeof(unsigned int));
//static_assert(sizeof(uart_fifo_t)   == sizeof(unsigned int));

static volatile uart_ctrl_t* UART_CTRL     = (uart_ctrl_t*) UART_CTRL_ADDR;
static volatile uart_status_t* UART_STAT   = (uart_status_t*) UART_STAT_ADDR;
static volatile uart_fifo_t* UART_RX       = (uart_fifo_t*) UART_RX_ADDR;
static volatile uart_fifo_t* UART_TX       = (uart_fifo_t*) UART_TX_ADDR;

#endif //VORTEX_VX_UART_H
