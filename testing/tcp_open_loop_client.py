import sys, os

sys.path.append(os.environ["BEEHIVE_PROJECT_ROOT"] + "/cocotb_testing/common/")
from open_loop_generator import OpenLoopGenerator, ClientDir

from scapy.utils import PcapWriter
from scapy.data import DLT_EN10MB

from cocotb.queue import Queue

sys.path.append(os.environ["BEEHIVE_PROJECT_ROOT"] + "/sample_designs/tcp_open_loop")
import tb_tcp_open_loop_top
from tb_tcp_open_loop_top import setup_conn_list

from tcp_slow_test_utils import TCPSlowTB
from tcp_automaton_driver import TCPAutomatonDriver

from open_loop_generator import OpenLoopGenerator
from tcp_open_loop import OpenLoopMimic


class TCPOpenLoopTB(TCPSlowTB):
    def __init__(self, dut, num_conns, direction, num_reqs, buf_size):
        super().__init__(dut)
        self.logfile = PcapWriter("debug_pcap.pcap", linktype=DLT_EN10MB)
        self.num_conns = num_conns
        self.num_reqs = num_conns
        self.direction = direction
        self.buf_size = buf_size
        self.conn_list = setup_conn_list(self.num_conns, num_reqs, direction,
                buf_size)

        self.TCP_driver = TCPAutomatonDriver(num_conns, OpenLoopGenerator, (self.MAC_W,
            1024, 64, 2),
                dut.clk, req_gen_list=self.conn_list)

        self.timer_queue = Queue()

        self.app_mimic = OpenLoopMimic(dut.clk, self.CLOCK_CYCLE_TIME,
                self.done_event, self.rx_circ_bufs,
                self.tx_circ_bufs,
                self.flow_notif_op, self.sched_update_op,
                self.rx_head_wr_op, self.rx_head_rd_req_op, self.rx_head_rd_resp_op,
                self.rx_commit_rd_req_op, self.rx_commit_rd_resp_op,
                self.tx_head_rd_req_op, self.tx_head_rd_resp_op,
                self.tx_tail_wr_op, self.tx_tail_rd_req_op, self.tx_tail_rd_resp_op)

async def run_send_loop(tb):
    await tb_tcp_open_loop_top.run_setup(tb)
    await tb_tcp_open_loop_top.run_send_loop(tb)

async def run_recv_loop(tb, stats_queue):
    await tb_tcp_open_loop_top.run_recv_loop(tb, stats_queue=stats_queue)

async def timer_tasks(tb):
    await tb_tcp_open_loop_top.timer_tasks(tb)
