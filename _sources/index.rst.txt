.. Tensorplane AI Foundry documentation master file

Welcome to the Tensorplane AI Foundry Documentation
===================================================

Tensorplane (operating as ``dataplane-emu``) is an end-to-end Recursive Self-Improving AI Foundry. It is engineered as a hardware-accurate data plane emulator and orchestration framework designed to eliminate the I/O and latency bottlenecks of hyperscale AI. By treating the compute continuum as a dynamic, programmable fabric, TensorPlane bridges high-level cloud orchestration with bare-metal silicon execution.

At its core, the system utilizes a specialized Multi-Agent System (MAS) driven by the Model Context Protocol (MCP). This "Team of Agents" autonomously monitors, evaluates, and rewrites its own compute kernels in real-time. By leveraging hardware-software co-design, the Foundry achieves theoretical hardware limits in throughput and power efficiency without human intervention.

.. toctree::
   :maxdepth: 2
   :caption: Developer Guide:

   architecture
   data_plane
   bare_metal
   infrastructure
