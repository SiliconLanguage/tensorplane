# **Demolishing the Memory Wall for AGI-Scale LLM Inference**

## A Strategic Briefing on Memory Tiering, CXL Disaggregation, and Agentic Compute Capitalization

### ---

**Author**: Ping Long, Chief Systems Architect, Lead Researcher, SiliconLanguage Foundry  
***Contact**: [LinkedIn](https://www.linkedin.com/in/pinglong) | [GitHub](https://github.com/ping-long-github) | siliconlanguage.com | plongpingl@gmail.com*

### ---

# I. Executive Summary: The Memory Wall and Disaggregation

The unprecedented scaling of Large Language Models (LLMs) has precipitated a fundamental shift in data center architecture, transitioning the primary performance bottleneck from raw computational throughput to memory bandwidth and capacity. This "**Memory Wall**" is particularly acute in inference environments, where the autoregressive nature of token generation necessitates the persistent storage of the **Key-Value (KV) cache**. As context windows expand toward millions of tokens and agentic workflows demand multi-turn state persistence, traditional monolithic GPU memory architectures are becoming economically and technically unsustainable. The industry is consequently moving toward software-defined, tiered memory hierarchies that disaggregate compute from stateful storage, utilizing a combination of High Bandwidth Memory (HBM), DDR5 DRAM, and NVMe NAND flash. To achieve AGI-scale inference, infrastructure must evolve into a vertically integrated, software-defined machine that leverages kernel-bypass mechanisms to guarantee microsecond-latency data delivery.

This strategic briefing details the transition toward **Distributed KV Cache Tiering, CXL 3.1 Memory Disaggregation**, and **Agentic Compute Capitalization**—synthesized through a 0-kernel monadic data plane that guarantees microsecond-latency execution.

# II. The KV Cache Crisis and Tiered Memory Orchestration

The Key-Value (KV) cache represents the primary stateful component of transformer-based inference, storing the intermediate attention tensors required to generate subsequent tokens without recomputing the entire prompt sequence. In modern agentic deployment scenarios, the memory footprint of this cache frequently exceeds the size of the model weights themselves, necessitating sophisticated tiering strategies.

## A. The Mathematical Reality of the Memory Wall

Calculating the capacity requirements for the KV cache is a prerequisite for cluster procurement. The standard formula for the memory footprint of the KV cache per token processed in a transformer model is a function of the number of layers, the number of Key-Value heads, the head dimension, and the numerical precision used for storage.

*KV SizePerToken* ≈ 2 × *Layers* × *HeadsKV* × *DimensionHead* × *PrecisionBytes*

For a flagship model such as Llama 3.1-405B, which utilizes 126 layers, 8 KV heads (under Grouped-Query Attention), and a head dimension of 128, the memory consumed per token in FP16 precision (2 bytes) is approximately 516,096 bytes, or 504 KiB. When this is scaled to a full context window of 127,188 tokens, the cache for a single user session reaches approximately 61 GB. For an enterprise serving 100,000 concurrent agents with a typical prompt size of 64K tokens and a retention multiplier of 15 to ensure a seamless user experience, the total addressable storage requirement balloons to 45 petabytes.

| Model Parameter | Llama 3.1-405B | Llama 3-70B | Mistral-7B (GQA) |
| ----- | ----- | ----- | ----- |
| Layers | 126 | 80 | 32 |
| KV Heads | 8 | 8 | 8 |
| Head Dimension | 128 | 128 | 128 |
| Precision | FP16 (2 bytes) | FP16 (2 bytes) | FP16 (2 bytes) |
| KV Cache / Token | \~504 KiB | \~320 KiB | \~64 KiB |
| Cache for 8K Context | 4.03 GB | 2.56 GB | 0.51 GB |
| Cache for 128K Context | 61 GB | 40 GB | 8 GB |

Data compiled from.\[5, 11, 12\]

## B. Software-Defined Tiered Hierarchies and Disaggregation

To manage this massive footprint, hyperscale infrastructure decouples the compute-heavy prefill phase from the memory-bound decode phase. This disaggregation allows workflows to be optimized by independently scheduling these phases.

Data is orchestrated across a four-tiered hardware hierarchy to provide necessary capacity at lower cost points:

* **G1 (Hot):** GPU High Bandwidth Memory (HBM), reserved for active token decoding.

* **G2 (Warm):** CPU DRAM, "Warm" storage for parking inactive KV blocks.

* **G3 (Cold):** Local NVMe SSDs, "Cold" capacity for evicting paused contexts.

* **G4 (Persistent):** Shared Network Storage, shared persistence for multi-turn agent state.

Memory fragmentation within these tiers is eliminated using engines like vLLM (which utilizes PagedAttention to allocate memory in non-contiguous virtual blocks) and SGLang (which utilizes RadixAttention to construct prefix trees that automatically reuse shared system prompts across agentic requests).

## C. Software Configuration and Orchestration Frameworks

Best-practice software configurations for managing this tiering involve the integration of inference engines like vLLM and SGLang with management layers such as NVIDIA Dynamo and LMCache.\[6, 7, 14\] These systems utilize PagedAttention and RadixAttention to eliminate memory fragmentation and enable cache reuse.\[6, 10, 15\]

PagedAttention, implemented in vLLM, treats GPU memory as virtual memory, partitioning the KV cache into fixed-size blocks (typically 16 to 128 tokens).\[10, 11, 16\] This allows for non-contiguous storage and reduces internal fragmentation to below 5%, compared to the 60-80% waste seen in traditional contiguous allocation.\[10, 11\]

SGLang utilizes RadixAttention, which maintains an LRU (Least Recently Used) cache of KV blocks in a radix tree structure.\[11, 15\] This enables automatic identifying and reuse of shared prefixes across different requests, which is critical for agentic workloads with repeated system prompts or RAG (Retrieval-Augmented Generation) documents.\[4, 15\] SGLang has demonstrated up to 3.7x faster Time to First Token (TTFT) and 33% higher throughput in multi-turn conversations through these reuse mechanisms.\[4\]

For enterprise-grade orchestration, NVIDIA Dynamo provides the KVBM (KV Block Manager) and the NIXL transfer library.\[7, 17, 18\] Configurations for Dynamo include specific environment variables to limit memory usage across tiers:

* `DYN_KVBM_CPU_CACHE_GB=4`: Allocates 4GB of host DRAM for warm KV cache offloading.\[6\]

* `DYN_KVBM_DISK_CACHE_GB=8`: Allocates 8GB of local SSD for cold storage.\[6\]

* `LMCACHE_CHUNK_SIZE=256`: Sets the granularity for cache transfers.\[6\]

LMCache acts as an extension to these engines, enabling the sharing of KV caches across the entire datacenter.\[14, 19\] By combining LMCache with vLLM, developers can achieve up to 15x improvements in throughput for document analysis and multi-round QA workloads.\[19, 20\] However, industrial context truncation techniques can reduce the prefix cache hit ratio by up to 50%, necessitating careful management of sequence lengths in procurement planning.\[19\]

# III. MoE Streaming, NAND Flash Offloading, and SSD Endurance

The emergence of Mixture-of-Experts (MoE) architectures, exemplified by models like DeepSeek-V3, has fundamentally changed the memory requirements of inference.\[2, 21\] DeepSeek-V3 possesses 671 billion total parameters, yet only 37 billion are activated per token, allowing for high computational efficiency if the inactive "expert" weights can be efficiently managed.\[21, 22\]

## A. NAND Flash for KV Swapping and Expert Streaming

NAND flash is increasingly utilized for two primary use cases: KV cache swapping and MoE weight streaming.\[10, 17\] In long-context or memory-intensive workloads, local SSDs act as a cost-effective capacity tier.\[10\] Frameworks like HiFC (High-efficiency Flash-based KV Cache) enable direct GPU-SSD swapping by integrating a Flash Cache (FC) block allocator into the vLLM Block Manager.\[10\]

To prevent the typical 10ms latency stalls associated with the standard Linux kernel I/O path, these systems utilize NVIDIA GPUDirect Storage (GDS) or SPDK (**kernel-bypass**).\[7, 10, 23\] GDS creates a direct DMA path between NVMe SSDs and GPU HBM, bypassing the host CPU and DRAM entirely.\[10\] Benchmarking of HiFC using the `gdsio` tool shows that sequential read throughput can reach 4.987 GiB/s, nearly saturating the PCIe interface and allowing flash-based swapping to perform within 2% of DRAM-based alternatives while reducing expansion costs by 4.5x.\[10\]

## B. Communication Frameworks and Expert Parallelism

DeepSeek's DeepEP framework is a specialized communication library designed for expert parallelism in MoE models.\[1\] It optimizes the all-to-all communication patterns required when different tokens in a batch are routed to different experts across a GPU cluster.\[1\] Combined with 3FS (DeepSeek's disaggregated file system), this allows for highly efficient routing logic and throughput improvements in large-scale non-blocking networks, such as 512-node Clos topologies.\[1\]

| Framework | Function | Optimization Target |
| ----- | ----- | ----- |
| DeepEP | Expert Parallelism | All-to-all communication latency \[1\] |
| 3FS | Disaggregated File System | Large-scale KV cache and model weight storage \[1, 7\] |
| NIXL | Transfer Library | Cross-node KV cache movement \[7, 18\] |
| HiFC | Flash-based Swapping | GPU-SSD direct I/O via GDS \[10\] |

Data synthesized from.\[1, 7, 10\]

## C. SSD Endurance and Wear-Leveling in Kernel-Bypass Data Planes

The continuous, volatile read/write patterns of KV cache swapping subject NVMe SSDs to extreme endurance stress.\[10\] Technical analysis reveals a significant performance and endurance delta between different regions of the NAND.\[10\]

* **Sequential Writes (pSLC):** Sustained throughput of 4.715 GiB/s average, which is ideal for batching KV block evictions.\[10\]

* **Random Writes (TLC):** Throughput drops to 1.617 GiB/s due to internal garbage collection and the migration of data from the pSLC cache to the main TLC storage.\[10\]

* **Performance Delta:** While pSLC sequential writes sustain 4.715 GiB/s, random TLC writes drop to 1.617 GiB/s due to garbage collection \[37\].

* **Endurance (P/E Cycles):** Continuous swapping can rapidly deplete the Program/Erase cycles of standard TLC drives.

* **Mitigation:** The architecture enforces **asynchronous, sequential batched writes** and monitors a "Retention Multiplier" to avoid unnecessary cycling of identical blocks.

Best practices for wear-leveling in kernel-bypass data planes include the use of asynchronous writes. NVIDIA Dynamo's KVBM avoids real-time write stalls by batching evicted blocks into large, sequential operations that minimize SSD write amplification.\[5\] Furthermore, the system can monitor the "Retention Multiplier" to ensure that the same blocks are not unnecessarily cycled, effectively using the SSD as an ephemeral capacity extension rather than a persistent storage medium.\[5\]

# IV. CXL and the Era of Disaggregated Memory Pooling

Compute Express Link (CXL) technology is reaching production maturity, offering a mechanism to decouple memory capacity from the CPU and GPU, thereby bypassing the need for exclusively HBM-based scaling.\[8, 9, 24\]

## A. CXL 3.1 and Memory Expanders

CXL 3.1 Memory eXpander Controllers (MXC), such as Montage Technology's M88MX6852 (Gen3 MXC), enable servers to access pooled DRAM over a PCIe 6.2 interface.\[25\] These controllers support both CXL.mem and CXL.io protocols, delivering data transfer rates of up to 64 GT/s.\[25\] The integration of dual-channel DDR5 controllers supporting speeds of 8000 MT/s allows for high-bandwidth memory expansion that sits between local DRAM and SSDs in the performance hierarchy.\[8, 25\]

CXL memory pooling transforms server economics by allowing multiple hosts to share access to a centralized memory pool, dynamically allocating capacity based on real-time workload demands.\[8, 24\] Microsoft research indicates that this approach could reduce the total DRAM required in a datacenter by 10%, leading to a 5% reduction in overall server cost.\[8\] For 1TB memory configurations, pairing cheaper standard DIMMs with CXL add-in cards can provide up to 40% cost savings compared to high-density host-attached DIMMs.\[8\]

**Feasibility and Production Timelines**

## B. Feasibility and Production Timelines

* **September 1, 2025:** Montage Technology announced the launch and sampling of its CXL 3.1 MXC (M88MX6852) for next-generation data center servers.\[25\]

* **November 18, 2025:** Microsoft Azure announced the industry's first deployment of CXL-attached memory in its M-series virtual machines preview, utilizing Astera Labs Leo CXL Smart Memory Controllers.\[9, 24, 26\]

* **December 2025:** Microsoft launched its first CXL-equipped cloud instances for broader customer evaluation.\[8\]

* **2026:** Projections suggest AI-optimized memory investment will approach half of total IT budgets, with CXL playing a primary role in memory disaggregation.\[27\]

* **2028:** The CXL market is projected to reach $15 billion, with over $12 billion of that spend dedicated to DRAM situated behind CXL controllers.\[8\]

| Vendor | Product | Status | Key Metric |
| ----- | ----- | ----- | ----- |
| Astera Labs | Leo CXL Smart Memory Controller | Production (Azure) | 2 TB per controller; CXL 2.0/1.1 \[24\] |
| Montage Tech | M88MX6852 (Gen3 MXC) | Sampling (Sept 2025\) | CXL 3.1; 64 GT/s; dual-channel DDR5-8000 \[25\] |
| Microsoft Azure | M-series Cloud Instances | Preview (Nov 2025\) | First announced CXL cloud deployment \[9, 26\] |
| Smart Modular | CXL Add-in Cards | Evaluation | 40% savings for 1TB memory configs \[8\] |

Data synthesized from.\[8, 9, 24, 25, 26\]

## C. Global Integrated Memory (GIM) and Switch Topologies

Advanced CXL 3.1 deployments are moving toward switch-based topologies and Global Integrated Memory (GIM).\[8, 25\] These architectures allow for true memory sharing, where multiple hosts can access the same memory segment with consistent data views.\[8\] While CXL-attached DRAM adds approximately 70 nanoseconds of latency compared to local DIMMs, it remains 20x to 50x faster than NVMe storage, making it the ideal tier for the warm KV cache blocks managed by systems like NVIDIA Dynamo.\[5, 8\]

# V. Agentic Compute Capitalization: The CPU as a Smart Router

Agentic AI workflows, characterized by multi-step reasoning, tool invocation, and stateful orchestration, are shifting a significant portion of compute demand back to high-core-count CPUs.\[12, 15, 28\] Rather than burning expensive GPU cycles on control logic, these CPUs act as "Smart Routers"  and orchestrators for the fabric, managing the complex logic of task decomposition and routing requests to specialized Small Language Models (SLMs).\[12, 28\]

By assigning the deterministic orchestration of the Multi-Agent System (via the Model Context Protocol) to these Smart Routers, the cluster protects its flagship GPUs (like the NVIDIA Blackwell B200) exclusively for the heavy lifting of massive MoE weight streaming and dense tensor math.

## A. The CPU as a Smart Router and State Manager

In agentic systems, a "Router" model (often an SLM under 10B parameters) identifies which specialized agent (e.g., a coder or a reviewer) should handle a specific prompt.\[12\] These workflows are bursty and unpredictable, requiring high-core-count CPUs with substantial memory bandwidth to manage the growing KV cache associated with long-turn conversations.\[12, 29\]

AWS Graviton4 and Intel Xeon 6 processors are being deployed as the primary compute for these orchestrators.\[28, 30\] Graviton4, for instance, features 96 Neoverse V2 cores and 12 DDR5-5600 channels, providing 75% more memory bandwidth than Graviton3.\[28, 29\] This bandwidth is critical for memory-bound applications like Full Waveform Inversion or the high-intensity state management required for 100,000 concurrent agents.\[5, 29\] Case studies from companies like Depot show that migrating orchestration and build workloads to Graviton4 can result in 20% cost improvements and 30% reductions in build times.\[30\]

## B. SLM Deployment and Specialized CPU Instructions

In hyperscale routing, lightweight SLMs (under 10B parameters) classify and direct incoming requests. If query complexity is low, it is resolved entirely by the SLM running on cost-effective CPU infrastructure to handle tool-calling and agentic routing.  
Specialized Small Language Models (SLMs) are increasingly deployed on CPUs using instructions like AVX-512, VNNI, or Intel AMX (Advanced Matrix Extensions).\[28, 31\] Intel AMX, introduced with 4th Generation Xeon Scalable processors, utilizes eight 1KB tile registers and a Tile Matrix Multiply Unit (TMUL) to perform matrix operations directly on the core.\[31\]

Configurations for accelerating CPU-based inference include specific oneDNN library environment variables:

* `export DNNL_MAX_CPU_ISA=AVX512_CORE_AMX`: Enables the AMX instruction set.\[31\]

* `export ONEDNN_DEFAULT_FPMATH_MODE=bf16`: Automatically enables AMX acceleration by setting the default precision to Brain Floating Point 16.\[31\]

* `export KMP_AFFINITY=granularity=fine,compact,1,0`: Optimizes thread affinity for better cache performance.\[31\]

Deploying a quantized SLM (e.g., 4-bit) on a Graviton instance like the r8g.8xlarge using llama.cpp has been shown to deliver high-performance inference for agentic tool-calling at a fraction of the cost of a GPU-resident model.\[23, 28\] These CPUs support SVE and SVE2 instructions, allowing performance-critical kernels to be optimized at runtime.\[23\]

### **C. Hardware Acceleration for Agentic Control Planes**

Modern silicon is engineered specifically to alleviate the bottlenecks of low-latency decision orchestration:

* **Intel Xeon 6:** Leverages Intel Advanced Matrix Extensions (AMX), utilizing a high-performance Tile Matrix Multiplication (TMUL) unit and dedicated 1KB tile registers to accelerate INT8 tensor operations natively, bypassing the need for discrete GPU resources.\[31\]  
* **AWS Graviton4 (ARM64):** Employs Scalable Vector Extension 2 (SVE2) to maximize computational throughput for specialized kernels.\[23, 28\] Execution of quantized 4-bit SLMs on these Graviton nodes provides a 40% improvement in price-to-performance metrics compared to traditional x86 architecture, significantly optimizing infrastructure capital efficiency.\[28\]

## D. Quantitative Forecasts on CPU/GPU CAPEX Ratios

The shift toward AI-ready infrastructure is driving a massive surge in capital expenditure (CAPEX).\[32, 33, 34\] Global data center CAPEX is projected to reach $1.7 trillion by 2030, with annual spending approaching $1 trillion as early as 2026.\[32, 35\]

While accelerated servers (GPUs) will account for approximately two-thirds (66-70%) of total data center infrastructure spend by 2030, the decoupling of memory capacity through CXL and tiered storage is stabilizing the CPU/GPU investment ratio.\[32, 35\]

* **Server Market:** Projected to quintuple from $204 billion in 2024 to $987 billion by 2030.\[33\]

* **Infrastructure Segmentation (2024):** IT infrastructure accounted for 78% of total spend, with servers representing 61%, networking 10%, and storage 6.5%.\[33\]

* **Power Consumption:** AI-optimized servers are projected to account for 44% of total data center power usage by 2030, up from 21% in 2025.\[36\]

* **Inference Shift:** By 2027, inference workloads will become the main AI requirement, moving the bottleneck from training throughput to inference capacity and state management.\[34, 35\]

| Financial Metric | 2024 Actual | 2026 Forecast | 2030 Forecast |
| ----- | ----- | ----- | ----- |
| Global Data Center CAPEX | $290 Billion \[33\] | \~$1 Trillion \[32\] | $1.7 Trillion \[35\] |
| Server Market Size | $204 Billion \[33\] | N/A | $987 Billion \[33\] |
| AI % of IT Budget | N/A | 41.5% \[27\] | \~50% \[27\] |
| DC Electricity Usage (TWh) | N/A | 448 TWh (2025) \[36\] | 980 TWh \[36\] |

Data compiled from.\[27, 32, 33, 35, 36\]

# VI. The Monadic Data Plane: 0-Kernel, 0-Copy Execution

The ultimate convergence of tiered memory, CXL pooling, and GPU execution is limited by one final bottleneck: the Linux operating system. The traditional Virtual File System (VFS), POSIX compliance layers, and hardware interrupts impose a "kernel tax" that accounts for up to 50% of I/O latency when fetching from ultra-fast NVMe storage  
.  
The 0-Kernel Solution To achieve speed-of-light execution, AGI-scale factories deploy a Monadic Data Plane—a zero-host-CPU architecture where data movement completely bypasses the OS  
.

* **Lock-Free User-Space Queues**: Legacy Linux storage stacks are replaced with the Storage Performance Development Kit (SPDK), allowing inference applications to poll NVMe drives directly from user space.  
* **GPUDirect Storage (GDS)**: When an inactive Mixture-of-Experts (MoE) weight or a cold KV cache block needs to be loaded from a PCIe NVMe SSD, it is streamed directly into the GPU's High Bandwidth Memory (HBM) using Direct Memory Access (DMA), entirely sidestepping the host CPU's bounce buffers.  
* **DPU Offloading**: Data Processing Units (DPUs) like the NVIDIA BlueField-3 offload all RDMA network transfers, cryptography, and storage orchestration to their embedded Arm cores, leaving 100% of the host x86/ARM64 CPU available for agentic routing.

# VII. Strategic Implications for Infrastructure Procurement

The findings of this report indicate that the procurement of AI infrastructure must move beyond simple GPU counting to a holistic, software-defined strategy centered on memory disaggregation.

For the KV cache, the adoption of tiering frameworks like NVIDIA Dynamo and LMCache allows for a 3-10x improvement in throughput and a significant reduction in Total Cost of Ownership (TCO) by offloading state to CPU DRAM and NVMe SSDs.\[7, 14, 20\] Organizations must size their G3 (SSD) and G4 (Remote Storage) tiers based on the "Retention Multiplier" of their specific user base, with massive 45PB pools required for large-scale agentic deployments.\[5\]

The feasibility of CXL 3.1 is no longer theoretical, with Azure's 2025 rollout providing a blueprint for decoupling expensive HBM from general-purpose inference capacity.\[8, 9\] Controllers from Montage and Astera Labs are now enabling true DRAM pooling, which can reduce overall memory over-provisioning by 10% and save 40% on high-capacity memory configurations.\[8, 25\]

The revitalization of high-core-count CPUs as "Smart Routers" and SLM executors underscores the need for a balanced CAPEX allocation.\[12, 28\] As agentic AI handles up to half of all workloads by 2030, the ability to utilize AVX-512, AMX, and SVE2 instructions will be a critical differentiator in maintaining high token-per-dollar efficiency.\[31, 34\] By unifying the stack with a 0-kernel, zero-copy data plane, enterprises can achieve the microsecond-latency and terabyte-per-second throughput demanded by the next generation of artificial intelligence. Finally, infrastructure architects must prioritize liquid-cooled, high-density racks (projected to reach 1,000kW by 2029\) to support these complex tiered deployments while managing the escalating energy demands of the next decade.\[33, 36\]

# References

1. Insights into DeepSeek-V3: Scaling Challenges and Reflections on Hardware for AI Architectures \- ResearchGate, [https://www.researchgate.net/publication/391741510\_Insights\_into\_DeepSeek-V3\_Scaling\_Challenges\_and\_Reflections\_on\_Hardware\_for\_AI\_Architectures](https://www.researchgate.net/publication/391741510_Insights_into_DeepSeek-V3_Scaling_Challenges_and_Reflections_on_Hardware_for_AI_Architectures)  
2. Insights into DeepSeek-V3: Scaling Challenges and Reflections on Hardware for AI Architectures \- arXiv, [https://arxiv.org/html/2505.09343v2](https://arxiv.org/html/2505.09343v2)  
3. Scaling Multi-Turn LLM Inference with KV Cache Storage Offload and Dell RDMA-Accelerated Architecture, [https://infohub.delltechnologies.com/p/scaling-multi-turn-llm-inference-with-kv-cache-storage-offload-and-dell-rdma-accelerated-architecture/](https://infohub.delltechnologies.com/p/scaling-multi-turn-llm-inference-with-kv-cache-storage-offload-and-dell-rdma-accelerated-architecture/)  
4. LLM Deployment Pipeline Explained Step by Step \- Portkey, [https://portkey.ai/blog/llm-deployment/](https://portkey.ai/blog/llm-deployment/)  
5. NVIDIA Dynamo \+ VAST \= Scalable, Optimized Inference \- VAST Data, [https://www.vastdata.com/blog/nvidia-dynamo-vast-scalable-optimized-inference](https://www.vastdata.com/blog/nvidia-dynamo-vast-scalable-optimized-inference)  
6. How to Reduce KV Cache Bottlenecks with NVIDIA Dynamo | NVIDIA Technical Blog, [https://developer.nvidia.com/blog/how-to-reduce-kv-cache-bottlenecks-with-nvidia-dynamo/](https://developer.nvidia.com/blog/how-to-reduce-kv-cache-bottlenecks-with-nvidia-dynamo/)  
7. Introduction | NVIDIA Dynamo Documentation, [https://docs.nvidia.com/dynamo/getting-started/introduction](https://docs.nvidia.com/dynamo/getting-started/introduction)  
8. CXL Memory Expansion | Introl Blog, [https://introl.com/blog/cxl-memory-expansion-pooling-disaggregated-memory-ai-data-center-2025](https://introl.com/blog/cxl-memory-expansion-pooling-disaggregated-memory-ai-data-center-2025)  
9. Astera Labs' Leo CXL Smart Memory Controllers on Microsoft Azure M-series Virtual Machines Overcome the Memory Wall, [https://www.asteralabs.com/news/astera-labs-leo-cxl-smart-memory-controllers-on-microsoft-azure-m-series-virtual-machines-overcome-the-memory-wall/](https://www.asteralabs.com/news/astera-labs-leo-cxl-smart-memory-controllers-on-microsoft-azure-m-series-virtual-machines-overcome-the-memory-wall/)  
10. HiFC: High-efficiency Flash-based KV Cache ... \- OpenReview, [https://openreview.net/pdf/54ad85c547f1d3f857eaf95351118ce21c8de1d6.pdf](https://openreview.net/pdf/54ad85c547f1d3f857eaf95351118ce21c8de1d6.pdf)  
11. KV Cache Explained: The Complete Guide to KV Cache in LLM Inference | Medium, [https://luv-bansal.medium.com/the-evolution-of-kv-cache-from-simple-buffers-to-distributed-memory-systems-df51cb8ce26f](https://luv-bansal.medium.com/the-evolution-of-kv-cache-from-simple-buffers-to-distributed-memory-systems-df51cb8ce26f)  
12. How to Build GPU Infrastructure for AI Agents: The 2026 Compute Playbook | Spheron Blog, [https://www.spheron.network/blog/gpu-infrastructure-ai-agents-2026/](https://www.spheron.network/blog/gpu-infrastructure-ai-agents-2026/)  
13. Revisiting Disaggregated Large Language Model Serving for Performance and Energy Implications \- arXiv, [https://arxiv.org/html/2601.08833v1](https://arxiv.org/html/2601.08833v1)  
14. LMCache/LMCache: Supercharge Your LLM with the Fastest KV Cache Layer \- GitHub, [https://github.com/lmcache/lmcache](https://github.com/lmcache/lmcache)  
15. What Is Inference Engineering? The 2026 GPU Cloud Guide | Spheron Blog, [https://www.spheron.network/blog/inference-engineering-guide-2026/](https://www.spheron.network/blog/inference-engineering-guide-2026/)  
16. Memory-Efficient Cloud Architecture Patterns to Reduce DRAM Dependency in 2026, [https://www.softwareseni.com/memory-efficient-cloud-architecture-patterns-to-reduce-dram-dependency-in-2026/](https://www.softwareseni.com/memory-efficient-cloud-architecture-patterns-to-reduce-dram-dependency-in-2026/)  
17. Enhancing Distributed Inference Performance with the NVIDIA Inference Transfer Library, [https://developer.nvidia.com/blog/enhancing-distributed-inference-performance-with-the-nvidia-inference-transfer-library/](https://developer.nvidia.com/blog/enhancing-distributed-inference-performance-with-the-nvidia-inference-transfer-library/)  
18. Overall Architecture | NVIDIA Dynamo Documentation, [https://docs.nvidia.com/dynamo/design-docs/overall-architecture](https://docs.nvidia.com/dynamo/design-docs/overall-architecture)  
19. LMCache: An Efficient KV Cache Layer for Enterprise-Scale LLM Inference \- arXiv, [https://arxiv.org/html/2510.09665v2](https://arxiv.org/html/2510.09665v2)  
20. LMCache: Accelerating LLM Inference \- Emergent Mind, [https://www.emergentmind.com/topics/lmcache](https://www.emergentmind.com/topics/lmcache)  
21. DeepSeek-V3 Technical Report \- arXiv, [https://arxiv.org/pdf/2412.19437](https://arxiv.org/pdf/2412.19437)  
22. The Circle of Life for LLMs. Was the Reaction to DeepSeek Justified?, [https://shmaes.wordpress.com/2025/02/15/the-circle-of-life-for-llms-was-the-reaction-to-deepseek-justified/](https://shmaes.wordpress.com/2025/02/15/the-circle-of-life-for-llms-was-the-reaction-to-deepseek-justified/)  
23. Introduction / Case Studies \- AWS Graviton technical guide, [https://aws.github.io/graviton/](https://aws.github.io/graviton/)  
24. Astera Leo CXL Memory in Azure M-series Preview: Cloud Memory ..., [https://windowsforum.com/threads/astera-leo-cxl-memory-in-azure-m-series-preview-cloud-memory-expansion-ahead.390059/](https://windowsforum.com/threads/astera-leo-cxl-memory-in-azure-m-series-preview-cloud-memory-expansion-ahead.390059/)  
25. Montage Technology Introduces CXL® 3.1 Memory eXpander ..., [https://www.montage-tech.com/Press\_Releases/20250901](https://www.montage-tech.com/Press_Releases/20250901)  
26. Astera Labs powers Microsoft's first CXL memory expansion for Azure \- Investing.com, [https://www.investing.com/news/company-news/astera-labs-powers-microsofts-first-cxl-memory-expansion-for-azure-93CH-4366344](https://www.investing.com/news/company-news/astera-labs-powers-microsofts-first-cxl-memory-expansion-for-azure-93CH-4366344)  
27. Gartner Forecasts IT Spending Surge Driven by AI | Let's Data Science, [https://letsdatascience.com/news/gartner-forecasts-it-spending-surge-driven-by-ai-91586cc7](https://letsdatascience.com/news/gartner-forecasts-it-spending-surge-driven-by-ai-91586cc7)  
28. Running GenAI Inference with AWS Graviton and Arcee AI Models, [https://aws.amazon.com/blogs/apn/running-genai-inference-with-aws-graviton-and-arcee-ai-models/](https://aws.amazon.com/blogs/apn/running-genai-inference-with-aws-graviton-and-arcee-ai-models/)  
29. Performance gains with AWS Graviton4 – a DevitoPRO case study | AWS HPC Blog, [https://aws.amazon.com/blogs/hpc/performance-gains-with-aws-graviton4-a-devitopro-case-study/](https://aws.amazon.com/blogs/hpc/performance-gains-with-aws-graviton4-a-devitopro-case-study/)  
30. Accelerating software builds using AWS Graviton4 with Depot, [https://aws.amazon.com/solutions/case-studies/depot-graviton-case-study/](https://aws.amazon.com/solutions/case-studies/depot-graviton-case-study/)  
31. Accelerate CPU-based AI inference workloads using Intel AMX on Amazon EC2 \- AWS, [https://aws.amazon.com/blogs/compute/accelerate-cpu-based-ai-inference-workloads-using-intel-amx-on-amazon-ec2/](https://aws.amazon.com/blogs/compute/accelerate-cpu-based-ai-inference-workloads-using-intel-amx-on-amazon-ec2/)  
32. AI Boom Drives Data Center Capex to $1.7 Trillion by 2030, According to Dell'Oro Group, [https://www.delloro.com/news/ai-boom-drives-data-center-capex-to-1-7-trillion-by-2030/](https://www.delloro.com/news/ai-boom-drives-data-center-capex-to-1-7-trillion-by-2030/)  
33. Data Center infrastructure market: AI-driven CapEx pushing IT and ..., [https://iot-analytics.com/data-center-infrastructure-market/](https://iot-analytics.com/data-center-infrastructure-market/)  
34. 13 Data Center Growth Projections That Will Shape 2026-2030 \- Avid Solutions, [https://avidsolutionsinc.com/13-data-center-growth-projections-that-will-shape-2026-2030/](https://avidsolutionsinc.com/13-data-center-growth-projections-that-will-shape-2026-2030/)  
35. Data center capex to hit $1.7 trillion by 2030 due to AI boom \- CIO, [https://www.cio.com/article/4131876/data-center-capex-to-hit-1-7-trillion-by-2030-due-to-ai-boom.html](https://www.cio.com/article/4131876/data-center-capex-to-hit-1-7-trillion-by-2030-due-to-ai-boom.html)  
36. Gartner Says Electricity Demand for Data Centers to Grow 16% in 2025 and Double by 2030, [https://www.gartner.com/en/newsroom/press-releases/2025-11-17-gartner-says-electricity-demand-for-data-centers-to-grow-16-percent-in-2025-and-double-by-2030](https://www.gartner.com/en/newsroom/press-releases/2025-11-17-gartner-says-electricity-demand-for-data-centers-to-grow-16-percent-in-2025-and-double-by-2030)  
37. In-place Switch Designs for Wear Mitigation \- arXiv, [https://arxiv.org/html/2409.14360v3](https://arxiv.org/html/2409.14360v3)

---

*Copyright (c) 2026 SiliconLanguage Foundry. All rights reserved.*

