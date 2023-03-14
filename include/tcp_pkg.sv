package tcp_pkg;
    `include "soc_defs.vh"

    localparam DUP_ACK_CNT_W = 4;
    localparam DUP_ACK_RT = 3;

    localparam TIMESTAMP_W = 64;

    localparam MAX_FLOW_CNT = 16;
    localparam FLOWID_W = $clog2(MAX_FLOW_CNT);

    localparam PAYLOAD_PTR_W = 14;
    localparam RX_PAYLOAD_PTR_W = PAYLOAD_PTR_W;
    localparam TX_PAYLOAD_PTR_W = PAYLOAD_PTR_W;

    localparam RT_ACK_THRESHOLD = 3;
    localparam RT_ACK_THRESHOLD_W = $clog2(RT_ACK_THRESHOLD) + 1;;

    localparam PAYLOAD_ENTRY_ADDR_W = 32;
    localparam PAYLOAD_ENTRY_LEN_W = 16;
    typedef struct packed {
        logic   [PAYLOAD_ENTRY_ADDR_W-1:0]  payload_addr;
        logic   [PAYLOAD_ENTRY_LEN_W-1:0]   payload_len;
    } payload_buf_struct;
    localparam SMOL_PAYLOAD_BUF_STRUCT_W = $bits(payload_buf_struct);

    typedef struct packed {
        logic   [`ACK_NUM_W-1:0]    ack_num;
        logic   [DUP_ACK_CNT_W-1:0] dup_ack_cnt;
    } ack_state_struct;

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
        logic   [FLOWID_W-1:0]  flowid;
        logic                   accept_payload;
        payload_buf_struct      payload_entry;
    } rx_store_buf_q_struct;
    localparam RX_STORE_BUF_Q_STRUCT_W = $bits(rx_store_buf_q_struct);

    // 1 second
    localparam RT_TIMEOUT_CYCLES = 250000000;
    
    localparam RX_TMP_BUF_NUM_SLABS = 2;
    localparam RX_TMP_BUF_SLAB_NUM_W = $clog2(RX_TMP_BUF_NUM_SLABS);
    localparam RX_TMP_BUF_SLAB_BYTES = 9152;
    localparam RX_TMP_BUF_SLAB_BYTES_W = $clog2(RX_TMP_BUF_SLAB_BYTES);

    // some nice log trick math
    localparam RX_TMP_BUF_ADDR_W = (RX_TMP_BUF_SLAB_NUM_W + RX_TMP_BUF_SLAB_BYTES_W);
    // calculate the number of bytes available across all slabs and then divide by the number of bytes 
    // in the MAC data interface to get els needed in the memory
    localparam RX_TMP_BUF_MEM_ELS = ((RX_TMP_BUF_NUM_SLABS * RX_TMP_BUF_SLAB_BYTES)/(`MAC_INTERFACE_BYTES));
    localparam RX_TMP_BUF_MEM_ADDR_W = $clog2(RX_TMP_BUF_MEM_ELS);

endpackage
