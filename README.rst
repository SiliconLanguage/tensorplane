================================================================================
TensorPlane: The Recursive Self-Improving AI Foundry
================================================================================

.. image:: https://img.shields.io/badge/Architecture-Compute--Continuum-blue
.. image:: https://img.shields.io/badge/Foundry-Recursive--Self--Improving-orange
.. image:: https://img.shields.io/badge/Stack-Go%20%7C%20Rust%20%7C%20Cpp%20%7C%20RISC--V-green

Executive Vision & Overview
===========================

**TensorPlane** (also operating as `dataplane-emu`) is an end-to-end **Recursive Self-Improving AI Foundry**. It is engineered as a hardware-accurate data plane emulator and orchestration framework designed to span the entire compute continuum: from Go-based cloud orchestration to C++/Rust kernel-bypass storage, down to bare-metal RISC-V execution.

The system utilizes a specialized **Multi-Agent System (MAS)** driven by the **Model Context Protocol (MCP)** to autonomously monitor, evaluate, and rewrite its own compute kernels. This recursive loop ensures the continuous elimination of I/O and latency bottlenecks without human intervention.

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

