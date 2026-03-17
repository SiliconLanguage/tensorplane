#![no_std]

//! USRBIO: User-Space Ring Buffer I/O
//!
//! Provides bare-metal, zero-copy I/O primitives that separate
//! command queues (`Ior`) from bulk data payloads (`Iov`).

use core::sync::atomic::{AtomicU32, AtomicU64, Ordering};

/// I/O Vector (Iov)
///
/// Represents bulk data payloads physically mapped to contiguous memory regions.
/// Designed for zero-copy transfers, GPUDirect RDMA, and bypassing the kernel page cache.
pub struct Iov<'a> {
    /// Direct reference to the memory region payload.
    data: &'a [u8],
    /// Physical or IOMMU-mapped base address for DMA engines.
    dma_base_address: u64,
    /// Length of the contiguous block.
    len: usize,
}

impl<'a> Iov<'a> {
    /// Binds a raw byte slice to an Iov descriptor.
    pub fn new(data: &'a [u8], dma_base_address: u64) -> Self {
        Self {
            len: data.len(),
            data,
            dma_base_address,
        }
    }
}

/// I/O Ring (Ior)
///
/// Lock-free command queue optimized for ARMv8.1 LSE atomics.
/// Handles multi-producer/multi-consumer submission and completion events
/// physically isolated from the `Iov` data payload.
pub struct Ior {
    /// Ring buffer head, modified by producers (submission path).
    head: AtomicU32,
    /// Ring buffer tail, modified by consumers (completion path).
    tail: AtomicU32,
    /// Capacity of the ring buffer, must be a power of 2.
    capacity: u32,
    /// Memory-mapped MMIO base address of the hardware queue (e.g., SmartNIC doorbell).
    queue_base: AtomicU64,
}

impl Ior {
    /// Initializes a new I/O Ring descriptor.
    pub fn new(capacity: u32, queue_base: u64) -> Self {
        Self {
            head: AtomicU32::new(0),
            tail: AtomicU32::new(0),
            capacity,
            queue_base: AtomicU64::new(queue_base),
        }
    }

    /// Submit a hardware command. (Stub for trait/interface design)
    #[inline(always)]
    pub fn submit_cmd(&self) -> Result<(), &'static str> {
        let _current_head = self.head.load(Ordering::Acquire);
        // TODO: Ring buffer push logic utilizing hardware atomics
        Ok(())
    }

    /// Poll for hardware completion. (Stub for trait/interface design)
    #[inline(always)]
    pub fn poll_cqe(&self) -> Result<(), &'static str> {
        let _current_tail = self.tail.load(Ordering::Acquire);
        // TODO: Ring buffer pop logic utilizing hardware atomics
        Ok(())
    }
}