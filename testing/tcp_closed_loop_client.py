import cocotb
import sys
import os
from collections import deque
from cocotb.result import SimTimeoutError
from cocotb.triggers import Timer, RisingEdge, ReadOnly, Combine, First, Event
from cocotb.triggers import ClockCycles, with_timeout, Join

from scapy.layers.l2 import Ether
from scapy.layers.inet import IP, UDP, TCP

from cocotb.log import SimLog

sys.path.append(os.environ["BEEHIVE_PROJECT_ROOT"] + "/sample_designs/tcp_with_logging")
from tb_tcp_with_logging_top import setup_conn_list

sys.path.append(os.environ["BEEHIVE_PROJECT_ROOT"] + "/cocotb_testing/common/")
from tcp_slow_test_utils import TCPSlowTB
from tcp_automaton_driver import TCPAutomatonDriver, EchoGenerator

from tcp_closed_echo import HWEchoMimic

class TCPClosedLoopTB(TCPSlowTB):
    def __init__(self, dut, num_conns):
        super().__init__(dut)

        self.req_gen_list = setup_conn_list(1, self.MAC_W, 64, 64, 2, self.done_event,
                                            self.CLOCK_CYCLE_TIME, 10)

        self.TCP_driver = TCPAutomatonDriver(dut.clk, self.req_gen_list)
        

        self.app_mimic = HWEchoMimic(dut.clk, self.done_event, self.rx_circ_bufs,
                self.tx_circ_bufs, self.CLIENT_LEN_BYTES, int(self.MAC_W/8),
                self.flow_notif_op, self.sched_update_op,
                self.rx_head_wr_op, self.rx_head_rd_req_op, self.rx_head_rd_resp_op,
                self.rx_commit_rd_req_op, self.rx_commit_rd_resp_op,
                self.tx_head_rd_req_op, self.tx_head_rd_resp_op,
                self.tx_tail_wr_op, self.tx_tail_rd_req_op, self.tx_tail_rd_resp_op)

async def timer_tasks(tb, timer_queue):
    queue_get = cocotb.start_soon(timer_queue.get())
    timer = await First(tb.done_event.wait(), Join(queue_get))
    if timer is None:
        cocotb.log.info("Timer loop exiting")
        return

    await timer

async def run_send_loop(dut, tb, timer_queue):
    pkts_sent = 0
    done_event = Event()

    while True:
        pkt_to_send, timer = await tb.TCP_driver.get_packet_to_send()
        if pkt_to_send is not None:
            cocotb.log.info(f"Sending pkt {pkt_to_send.show2(dump=True)}")
            if timer is not None:
                timer_queue.put_nowait(timer)

            eth = Ether()
            eth.src = tb.IP_TO_MAC[pkt_to_send[IP].src]
            eth.dst = tb.IP_TO_MAC[pkt_to_send[IP].dst]

            pkt_to_send = eth/pkt_to_send
            pkt_bytes = bytearray(pkt_to_send.build())

            if len(pkt_to_send) < tb.MIN_PKT_SIZE:
                padding = tb.MIN_PKT_SIZE - len(pkt_to_send)
                pad_bytes = bytearray([0] * padding)
                pkt_bytes.extend(pad_bytes)

            await tb.input_op.xmit_frame(pkt_bytes)
            pkts_sent += 1
            cocotb.log.info(f"Pkts sent {pkts_sent}")

        else:
            if tb.done_event.is_set():
                cocotb.log.info("Send loop exiting")
                return
            else:
                await RisingEdge(dut.clk)


async def run_recv_loop(dut, tb):
    while True:
        pkt_out = None
        try:
            resp_coro = cocotb.start_soon(tb.output_op.recv_resp())
            pkt_out = await with_timeout(resp_coro,
                    tb.CLOCK_CYCLE_TIME*500, timeout_unit="ns")
        except SimTimeoutError:
            if tb.TCP_driver.all_flows_closed():
                cocotb.log.info("Recv loop exiting")
                tb.done_event.set()
                return
            continue

        tb.TCP_driver.recv_packet(pkt_out)

        if tb.TCP_driver.all_flows_closed():
            cocotb.log.info("Recv loop exiting")
            tb.done_event.set()
            return
