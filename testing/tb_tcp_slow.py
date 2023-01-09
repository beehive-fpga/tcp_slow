import logging
import random
import collections
from pathlib import Path

import cocotb
from cocotb.queue import Queue as CocoQueue
from cocotb.binary import BinaryValue
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, ReadOnly, Combine, First, Event
from cocotb.triggers import ClockCycles, with_timeout, Join
from cocotb.result import SimTimeoutError
from cocotb.log import SimLog
from cocotb.utils import get_sim_time
import scapy

from scapy.layers.l2 import Ether, ARP
from scapy.layers.inet import IP, UDP, TCP
from scapy.packet import Raw

import sys
import os
sys.path.append(os.environ["BEEHIVE_PROJECT_ROOT"] + "/cocotb_testing/common/")

from tcp_driver import TCPFourTuple
from generic_val_rdy import GenericValRdyBus, GenericValRdySource, GenericValRdySink
from tcp_slow_test_utils import TCPSlowTB, PayloadBufStruct
from tcp_slow_test_utils import payloadPtrBitfield, reset

@cocotb.test()
async def run_tcp_test(dut):
    tb = TCPSlowTB(dut)
    cocotb.start_soon(Clock(dut.clk, 4, units='ns').start())

    await reset(dut)
    # start up all the hw mimic tasks
    app_flow_notif = cocotb.start_soon(tb.app_mimic.flow_notif())
    app_loop = cocotb.start_soon(tb.app_mimic.app_loop())
    buf_copy = cocotb.start_soon(tb.buf_cpy_obj.req_loop())

    # start up the app tasks
    timers = CocoQueue()
    send_task = cocotb.start_soon(run_send_loop(dut, tb, timers))
    recv_task = cocotb.start_soon(run_recv_loop(dut, tb))
    timer_task = cocotb.start_soon(timer_tasks(tb, timers))

    await Combine(app_flow_notif, app_loop, buf_copy, send_task, recv_task,
            timer_task)


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
            if timer is not None:
                await timer_queue.put(timer)

            await tb.input_op.xmit_frame(pkt_to_send)

        else:
            if tb.TCP_driver.all_flows_done():
                cocotb.log.info("Send loop exiting")
                return
            else:
                await RisingEdge(dut.clk)

def reassemble_pkt(tb, src_ip, dst_ip, tcp_pkt_bytes):
    eth_hdr = Ether()
    eth_hdr.src = tb.IP_TO_MAC[src_ip]
    eth_hdr.dst = tb.IP_TO_MAC[dst_ip]

    ip_pkt = IP()
    ip_pkt.src = src_ip
    ip_pkt.dst = dst_ip
    ip_pkt.flags = "DF"
    ip_pkt.proto = 6
    ip_pkt.add_payload(bytes(tcp_pkt_bytes))

    pkt = eth_hdr/ip_pkt
    return pkt

async def run_recv_loop(dut, tb):
    while True:
        tx_pkt_out = None
        try:
            resp_coro = cocotb.start_soon(tb.tx_pkt_out_op.recv_resp())
            tx_pkt_out = await with_timeout(resp_coro,
                    tb.CLOCK_CYCLE_TIME*500, timeout_unit="ns")
        except SimTimeoutError:
            if tb.TCP_driver.all_flows_closed():
                cocotb.log.info("Recv loop exiting")
                tb.done_event.set()
                return
            continue
        tcp_pkt_bytes = bytearray(tx_pkt_out["tcp_hdr"].buff)
        src_ip = socket.inet_ntoa(tx_pkt_out["src_ip"].buff)
        dst_ip = socket.inet_ntoa(tx_pkt_out["dst_ip"].buff)
        # go and find the payload
        payload_des = PayloadBufStruct(init_bitstring=tx_pkt_out["payload"])
        cocotb.log.info(f"Received payload entry is {payload_des}")
        payload_addr = payload_des.getBitfield("addr")
        addr = payloadPtrBitfield("addr", init_bitfield=payload_addr).to_addr()
        size = payload_des.getField("size")
        flowid = tx_pkt_out["flowid"]
        recv_buf = tb.tx_circ_bufs[flowid].read_from(addr, size)
        cocotb.log.info(f"Received buffer is {recv_buf}")
        tcp_pkt_bytes.extend(recv_buf)

        pkt = reassemble_pkt(tb, src_ip, dst_ip, tcp_pkt_bytes)

        cocotb.log.info(f"Received pkt {pkt.show2(dump=True)}")

        tb.TCP_driver.recv_packet(pkt.build())

        if tb.TCP_driver.all_flows_closed():
            cocotb.log.info("Recv loop exiting")
            tb.done_event.set()
            return


