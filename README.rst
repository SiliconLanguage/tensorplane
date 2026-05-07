====================================================
TensorPlane: The Recursive Self-Improving AI Foundry
====================================================

.. image:: https://img.shields.io/badge/Architecture-Compute--Continuum-blue
.. image:: https://img.shields.io/badge/Foundry-Recursive--Self--Improving-orange
.. image:: https://img.shields.io/badge/Stack-Go%20%7C%20Rust%20%7C%20Cpp%20%7C%20RISC--V-green

Executive Vision & Overview
===========================

TensorPlane (also operating as ``dataplane-emu``) is an end-to-end Recursive Self-Improving AI Foundry. It is engineered as a hardware-accurate data plane emulator and orchestration framework designed to span the entire compute continuum: from Go-based cloud orchestration to C++/Rust kernel-bypass storage, down to bare-metal RISC-V execution.

**Technical Dimension & Industry Alignment**

Anticipating macro industry trends—most notably the collision with the fundamental "Memory Wall" and the architectural shift toward Prefill-Decode (PD) disaggregation—TensorPlane operates at the definitive edge of **hardware-software co-design**. It bridges the gap between hyper-optimized **AI/LLM inference ecosystems** (leveraging vLLM, SGLang, and KVCache-centric memory tiering) and raw silicon execution. By dynamically orchestrating Triton/MLIR compilers for specific silicon realities like NVIDIA Blackwell's NVFP4 precision and Tensor Memory (TMEM), and bypassing the legacy OS tax entirely via CXL 3.1 pooling and zero-copy RDMA, the framework is built to sustain microsecond-latency for trillion-parameter MoE expert streaming and global KV cache pooling.

The system utilizes a specialized Multi-Agent System (MAS) driven by the Model Context Protocol (MCP) to autonomously monitor, evaluate, and rewrite its own compute kernels based on real-time hardware telemetry. This recursive loop ensures the continuous elimination of I/O and latency bottlenecks without human intervention.


📄 Architectural Research & Whitepapers
=======================================

The orchestration mechanics and data planes within the Tensorplane AI Foundry are governed by our published research on post-Von Neumann, 0-kernel AI infrastructure.

* `0-Kernel, 0-Copy Data Movement: Scaling LLM Point-to-Point and Collective Communication <./docs/whitepapers/Hyperscale_0_Kernel_Network_Communication/0-Kernel-0-Copy-Data-Movement-Hyperscale-LLM.pdf>`_
  
  * **Focus:** Scale-out Network Data Planes. Exposes the "Hyperscale Wall" of traditional BSP and NCCL collectives. Details the transition to host-driven, zero-copy abstractions (NIXL, fabric-lib) and Dynamic Queue Pair Load Balancing (DQPLB) to bypass GPU SM starvation across 100,000+ GPU clusters.

* `Demolishing the Memory Wall for AGI-Scale LLM Inference <./docs/whitepapers/demolishing-the-memory-wall/Demolishing%20the%20Memory%20Wall%20for%20AGI-Scale%20LLM%20Inference.pdf>`_
  
  * **Focus:** Scale-up Storage and Memory Disaggregation. Examines how Disaggregated KV Cache Tiering and CXL 3.1 memory pooling are utilized to demolish the memory wall, supporting massive context windows and multi-turn state persistence in agentic workflows.

* `Navigating Architectural Frontiers: Pioneering AI Supercomputing via 0-Kernel, 0-Copy Storage Virtualization <./docs/whitepapers/Supercomputing_0_Kernel_Storage_Virtualization/Ping_Long_AI_Supercomputing_0_Kernel_Storage_Architecture.pdf>`_

  * **Focus:** Scale-up Storage Virtualization and Legacy Acceleration. Resolves the "Compatibility-Performance Paradox" by introducing the "Double Trampoline" architecture. Synthesizes SPDK kernel bypass, zIO transparent zero-copy, and eBPF/XRP B-Tree offloading to achieve bare-metal NVMe latency for unmodified legacy systems (e.g., PostgreSQL).

The "Team of Agents" Architecture
=================================

The ``/team_of_agents/`` directory implements "Scalable Agency" through a series of hyper-specialized pools:

* **Orchestrator:** The AgentOps manager responsible for task routing and MAS state.
* **Ops (Telemetry & Triage):** Monitors P99 tail latency via eBPF (Cilium/Hubble), manages GPU fractioning (``ops_resource_optimizer``), and handles thermal/DVFS scaling (``ops_power_monitor``).
* **Dev (The Builders):**
    * ``/dev_cpp_dataplane/``: SPDK and io_uring high-performance implementations.
    * ``/dev_rust_kernel/``: eBPF and XRP (eXpress Resubmission Path) hooks.
    * ``/dev_go_controlplane/``: Kubernetes and FaaS orchestration logic.
    * ``/dev_bare_metal/``: RISC-V Assembly and hardware-software co-design.
* **Eval & Deployment:** Agents that sandbox, benchmark, and safely hot-swap compiled C++/CUDA/Triton kernels into the live data plane.

The Compute Continuum & Tech Stack
==================================

The Zero-Copy Storage Plane
---------------------------
TensorPlane leverages the **Rust** (``usrbio`` crate) and **C++** for lock-free Submission/Completion Queues (SQ/CQ). By bypassing the kernel via **SPDK** and utilizing **eBPF XRP** hooks, the system achieves near-theoretical hardware performance.

The Bare-Metal Silicon Layer
----------------------------
Targeting the **RISC-V "Snitch"** pseudo dual-issue processor, the foundry utilizes **Stream Semantic Registers (SSR)** to elide load/store instructions. Performance is further tuned via the ``Zawrs`` (Wait-on-Reservation-Set) and ``Zihintntl`` (Non-Temporal Locality) extensions for energy-efficient polling.

The Control Plane
-----------------
A distributed **FaaS (Serverless Lambda)** deployment of MCP servers managed by **Go**, providing a scalable gateway for agentic orchestration.

Infrastructure as Code (IaC) & Provisioning
===========================================

The ``/provision/`` directory ensures the Foundry is fully reproducible across hyperscale environments:

.. code-block:: text

    /provision/
    ├── ai_common/      # Foundational GPU dependencies (CUDA 12.x / ROCm 7).
    ├── ai_inference/   # vLLM/SGLang engines with PagedAttention.
    ├── ai_training/    # Distributed Ray clusters for multi-node LLM training.
    ├── dev_control/    # Go toolchain and eBPF kernel headers for observability.
    └── dev_data/       # AWS Graviton (ARM64) setup with 2MB hugepages and LSE atomics.

Prior Art & Inspiration
=======================

TensorPlane incorporates paradigms from:
* **DeepSeek 3FS:** For RDMA and zero-copy NVMe separation logic.
* **Intel DAOS:** For transparent POSIX interception models.
* **MemPool/Snitch:** For RISC-V tightly-coupled memory and SSR architectures.

