package tcp_pkg;

    localparam DUP_ACK_CNT_W = 4;
    localparam DUP_ACK_RT = 3;

    localparam TIMESTAMP_W = 64;

    localparam MAX_TCP_FLOWS = 8;
    localparam FLOWID_W = $clog2(MAX_TCP_FLOWS);

    localparam PAYLOAD_BUF_PTR_W = 12;
    localparam RX_PAYLOAD_PTR_W = PAYLOAD_BUF_PTR_W;
    localparam TX_PAYLOAD_PTR_W = PAYLOAD_BUF_PTR_W;

    localparam PAYLOAD_ENTRY_ADDR_W = 32;
    localparam PAYLOAD_ENTRY_LEN_W = 16;
    typedef struct packed {
        logic   [PAYLOAD_ENTRY_ADDR_W-1:0]  payload_addr;
        logic   [PAYLOAD_ENTRY_LEN_W-1:0]   payload_len;
    } smol_payload_buf_struct;

    typedef struct packed {
        ack_state_struct            our_ack_state;
        logic   [`ACK_NUM_W-1:0]    their_ack_num;
        logic   [`WIN_SIZE_W-1:0]   their_win_size;
        logic   [`WIN_SIZE_W-1:0]   our_win_size;
    } smol_rx_state_struct;
    localparam SMOL_RX_STATE_STRUCT_W = $bits(smol_rx_state_struct);

    typedef struct packed {
        logic   [`SEQ_NUM_W-1:0]    our_seq_num;
    } smol_tx_state_struct;
    localparam SMOL_TX_STATE_STRUCT_W = $bits(smol_tx_state_struct);

    typedef struct packed {
        logic   [TIMESTAMP_W-1:0]   timestamp;
        logic                       timer_armed;
    } tx_ack_timer_struct;

    typedef struct packed {
        logic   [`ACK_NUM_W-1:0]    ack_num;
        logic   [DUP_ACK_CNT_W-1:0] dup_ack_cnt;
    } ack_state_struct;

    // 1 second
    localparam RT_TIMEOUT_CYCLES = 250000000;
endpackage
