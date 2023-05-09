import logging
import cocotb
import sys
import os

from collections import deque

from cocotb.binary import BinaryValue
from cocotb.queue import Queue
from cocotb.log import SimLog
from cocotb.result import SimTimeoutError
from cocotb.triggers import with_timeout, Combine, Event, RisingEdge
from cocotb.utils import get_sim_time

from tcp_slow_test_utils import AppIFMimic, payloadPtrBitfield
from circ_buf_helpers import payloadPtrBitfield
from tcp_slow_test_structs import SchedCmdStruct

sys.path.append(os.environ["BEEHIVE_PROJECT_ROOT"] + "/cocotb_testing/common/")
from tcp_open_bw_log_read import TCPOpenBwLogEntry
from open_loop_generator import ClientDir

class OpenLoopMimic(AppIFMimic):
    FIELD_BYTES = 4

    def __init__(self, clk, cycle_time, done_event, rx_circ_bufs, tx_circ_bufs,
            flow_notif_op, sched_update_op,
            rx_head_wr_op, rx_head_rd_req_op, rx_head_rd_resp_op,
            rx_commit_rd_req_op, rx_commit_rd_resp_op,
            tx_head_rd_req_op, tx_head_rd_resp_op,
            tx_tail_wr_op, tx_tail_rd_req_op, tx_tail_rd_resp_op):
        # order matters here, we need the parent class to set up the instance
        # variables
        super().__init__(flow_notif_op, sched_update_op,
            rx_head_wr_op, rx_head_rd_req_op, rx_head_rd_resp_op,
            rx_commit_rd_req_op, rx_commit_rd_resp_op,
            tx_head_rd_req_op, tx_head_rd_resp_op,
            tx_tail_wr_op, tx_tail_rd_req_op, tx_tail_rd_resp_op)

        self.done_event = done_event
        self.clk = clk
        self.cycle_time = cycle_time
        self.active_flows = Queue()
        self.hdr_bytes = (OpenLoopMimic.FIELD_BYTES * 3) + 1
        self.rx_circ_bufs = rx_circ_bufs
        self.tx_circ_bufs = tx_circ_bufs

        self.rx_head_ptr_bitfield = payloadPtrBitfield("rx_head_ptr",
                size=self.rx_head_rd_resp_op._bus.data.value.n_bits)
        self.rx_commit_ptr_bitfield = payloadPtrBitfield("rx_commit_ptr",
                size=self.rx_commit_rd_resp_op._bus.data.value.n_bits)
        self.tx_head_ptr_bitfield = payloadPtrBitfield("tx_head_ptr",
                size=self.tx_head_rd_resp_op._bus.data.value.n_bits)
        self.tx_tail_ptr_bitfield = payloadPtrBitfield("tx_tail_ptr",
                size=self.tx_tail_rd_resp_op._bus.data.value.n_bits)

        self.log = SimLog("cocotb.tb.app")
        self.log.setLevel(logging.DEBUG)

    async def flow_notif(self):
        self.log.info("Started flow notif coroutine")
        while not self.done_event.is_set():
            flow_notif_data = None;
            try:
                resp_coro = cocotb.start_soon(self.flow_notif_op.recv_resp())
                flow_notif_data = await with_timeout(resp_coro,
                        2000, timeout_unit="ns")
            except SimTimeoutError:
                continue
            self.active_flows.put_nowait(flow_notif_data)
            self.log.info(f"Got new flow {flow_notif_data['flowid']}")
        self.log.info("Flow notif coroutine exiting")

    async def parallel_rd_resp(self, op, value_event):
        data = await op.recv_resp()
        value_event.set(data)

    async def get_space_used(self, flowid):
        # go read the head and commit pointers at the same time
        hd_rd_req = cocotb.start_soon(self.rx_head_rd_req_op.send_req(
            {"addr": flowid}))
        commit_rd_req = cocotb.start_soon(self.rx_commit_rd_req_op.send_req(
            {"addr": flowid}))
        await Combine(hd_rd_req, commit_rd_req)

        hd_event = Event()
        commit_event = Event()
        hd_rd_resp = cocotb.start_soon(self.parallel_rd_resp(self.rx_head_rd_resp_op,
            hd_event))
        commit_rd_resp = cocotb.start_soon(self.parallel_rd_resp(self.rx_commit_rd_resp_op,
            commit_event))
        await Combine(hd_rd_resp, commit_rd_resp)

        self.rx_head_ptr_bitfield.set_value(hd_event.data["data"].integer)
        self.rx_commit_ptr_bitfield.set_value(commit_event.data["data"].integer)
        space_used = self.rx_commit_ptr_bitfield.sub(self.rx_head_ptr_bitfield)

        return space_used

    async def get_space_avail(self, flowid):
        hd_rd_req = cocotb.start_soon(self.tx_head_rd_req_op.send_req(
            {"addr": flowid}))
        tail_rd_req = cocotb.start_soon(self.tx_tail_rd_req_op.send_req(
            {"addr": flowid}))

        await Combine(hd_rd_req, tail_rd_req)

        hd_event = Event()
        tail_event = Event()
        hd_rd_resp = cocotb.start_soon(self.parallel_rd_resp(self.tx_head_rd_resp_op,
            hd_event))
        tail_rd_resp = cocotb.start_soon(self.parallel_rd_resp(self.tx_tail_rd_resp_op,
            tail_event))
        await Combine(hd_rd_resp, tail_rd_resp)

        self.tx_head_ptr_bitfield.set_value(hd_event.data["data"].integer)
        self.tx_tail_ptr_bitfield.set_value(tail_event.data["data"].integer)

        space_used = self.tx_tail_ptr_bitfield.sub(self.tx_head_ptr_bitfield)

        max_val = 1 << self.tx_head_ptr_bitfield.num_ptr_w
        space_avail = max_val - space_used

        return space_avail

    async def enqueue_tx_data(self, flowid, payload):
        space_avail = 0
        while space_avail < len(payload):
            space_avail = await self.get_space_avail(flowid)

        self.tx_circ_bufs[flowid].write_from(self.tx_tail_ptr_bitfield.to_addr(),
                        payload)

        # kick the tail pointer. we need to use value rather than
        # to_addr, because we need all the bits
        new_tail_ptr = self.tx_tail_ptr_bitfield.value + len(payload)
        self.tx_tail_ptr_bitfield.set_value(new_tail_ptr)
        new_tail_binval = BinaryValue(value=self.tx_tail_ptr_bitfield.bitfield_format(),
                n_bits = self.tx_tail_ptr_bitfield.size)
        await self.tx_tail_wr_op.send_req(
                {"addr": flowid,
                 "data": new_tail_binval})

        # kick scheduler
        sched_cmd = SchedCmdStruct(flowid=flowid.integer,
                                    rt_cmd=SchedCmdStruct.NOP,
                                    ack_cmd=SchedCmdStruct.NOP,
                                    data_cmd=SchedCmdStruct.SET)
        await self.sched_update_op.send_req({"cmd": sched_cmd.toBinaryValue()})

    async def dequeue_rx_data(self, flowid, payload_len):
        space_used = 0
        while space_used < payload_len:
            space_used = await self.get_space_used(flowid)
            self.log.info(f"Beehive: app RX space used: {space_used}")

        data = self.rx_circ_bufs[flowid].read_from(self.rx_head_ptr_bitfield.to_addr(),
                self.hdr_bytes)

        # kick the head pointer to consume the request too
        new_head_ptr = self.rx_head_ptr_bitfield.value + payload_len
        self.rx_head_ptr_bitfield.set_value(new_head_ptr)
        new_head_binval = BinaryValue(value=self.rx_head_ptr_bitfield.bitfield_format(),
                n_bits=self.rx_head_ptr_bitfield.size)
        await self.rx_head_wr_op.send_req(
                {"addr": flowid,
                 "data": new_head_binval})

        return data

    async def run_setup(self, flowid):
        self.log.info(f"Beehive: app mimic starting setup {flowid}")

        setup_data = await self.dequeue_rx_data(flowid, self.hdr_bytes)

        self.num_reqs = int.from_bytes(setup_data[0:OpenLoopMimic.FIELD_BYTES],
                byteorder="big")
        self.buf_size = int.from_bytes(
                setup_data[OpenLoopMimic.FIELD_BYTES:OpenLoopMimic.FIELD_BYTES*2],
                byteorder="big")
        self.num_conns = int.from_bytes(
                setup_data[OpenLoopMimic.FIELD_BYTES*2:OpenLoopMimic.FIELD_BYTES*3],
                byteorder="big")
        self.dir = ClientDir(setup_data[OpenLoopMimic.FIELD_BYTES*3])

        self.log.info(f"num_reqs: {self.num_reqs} "
                      f"buf_size: {self.buf_size} "
                      f"num_conns: {self.num_conns} "
                      f"dir: {self.dir}")

        # send response
        payload = bytearray([0] * 64)
        payload[63] = 1

        await self.enqueue_tx_data(flowid, payload)
        self.log.info(f"Beehive: app mimic finished setup {flowid}")


    async def app_loop(self, stats_queue):
        # wait for the first connection
        first_conn = await self.active_flows.get()
        flowid = first_conn["flowid"]

        await self.run_setup(flowid)

        # wait for all the connections
        bench_conns = deque()
        while len(bench_conns) < self.num_conns:
            new_conn = await self.active_flows.get()
            new_conn_flowid = new_conn["flowid"]
            self.log.info(f"app loop received new flow")
            bench_conns.append(Connection(new_conn_flowid))

        msg_times = []
        if self.dir == ClientDir.SEND:
            msg_times = await self.recv_bench(bench_conns)
        else:
            msg_times = await self.send_bench(bench_conns)

        stats_queue.put_nowait(msg_times)

        while not self.done_event.is_set():
            await RisingEdge(self.clk)

    async def send_bench(self, bench_conns):
        while len(bench_conns) != 0:
            connection = bench_conns.popleft()
            payload = bytearray([60] * self.buf_size)
            await self.enqueue_tx_data(connection.flowid, payload)

            connection.reqs_done += 1
            self.log.info(f"Flow {connection.flowid} finished req {connection.reqs_done}")
            # reenqueue if not done
            if connection.reqs_done < self.num_reqs:
                bench_conns.append(connection)

    async def recv_bench(self, bench_conns):
        message_entries = []
        tot_bytes = 0
        while len(bench_conns) != 0:
            connection = bench_conns.popleft()

            await self.dequeue_rx_data(connection.flowid, self.buf_size)
            curr_time = get_sim_time(units='ns')
            tot_bytes += self.buf_size
            cycles = int(curr_time/self.cycle_time)
            cycles_bytes = cycles.to_bytes(TCPOpenBwLogEntry.TIMESTAMP_BYTES, byteorder="big")
            tot_bytes_bytes = tot_bytes.to_bytes(TCPOpenBwLogEntry.BYTES_RECV_BYTES,
                            byteorder="big")
            entry_bytearray = cycles_bytes + tot_bytes_bytes
            message_entries.append(TCPOpenBwLogEntry(entry_bytearray))

            connection.reqs_done += 1
            if connection.reqs_done < self.num_reqs:
                bench_conns.append(connection)
        return message_entries

class Connection():
    def __init__(self, flowid):
        self.flowid = flowid
        self.reqs_done = 0
