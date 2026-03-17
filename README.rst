===========
TensorPlane
===========

An enterprise-grade AI data plane accelerator achieving true zero-copy I/O. Inspired by DeepSeek's 3FS USRBIO API, TensorPlane physically separates command queues from bulk data payloads to achieve line-rate GPUDirect RDMA streaming and SmartNIC/DPU offloading, bypassing legacy POSIX bottlenecks for hyperscale AI workloads.

Architecture Overview (The DAOS Model)
======================================
TensorPlane employs a strict language-to-domain split to optimize both developer velocity for cloud-native orchestration and bare-metal performance for the I/O path.

Control Plane (Go)
------------------
Located in ``control_plane/``. Manages cloud-native orchestration, Kubernetes CSI drivers, gRPC session management, and Agentic AI Model Context Protocol (MCP) servers.

Data Plane (Rust)
-----------------
Located in ``data_plane/``. Manages the microsecond-critical I/O path. It interfaces directly with bare-metal hardware, utilizing ARMv8.1 LSE hardware atomics for lock-free queues, and is configured for ``no_std`` targets to support NVIDIA BlueField-3 DPU offloading.

Core Primitives
===============
* **Ior (I/O Ring):** Lock-free command queues for highly concurrent submission/completion events.
* **Iov (I/O Vector):** Bulk data payloads mapped to contiguous memory regions for DMA operations.