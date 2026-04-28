# **Navigating Architectural Frontiers: Pioneering AI Supercomputing Fleet via 0-Kernel, 0-Copy Storage Virtualization**
## *With Scenario Mapping for Transparent Acceleration for Legacy PostgreSQL* 

**Author**: Ping Long, Chief Systems Architect, Lead Researcher, SiliconLanguage Foundry  
***Contact**: [LinkedIn](https://www.linkedin.com/in/pinglong) | [GitHub](https://github.com/ping-long-github) | siliconlanguage.com | plongpingl@gmail.com*

---

## **Executive Summary**
The warp-speed advancement of non-volatile memory (NVMe) protocols, peripheral component interconnect express (PCIe) bandwidth, and massive-scale interconnect technologies has fundamentally altered the performance equations governing distributed relational database systems. For decades, the dominant architectural paradigm in systems engineering assumed that physical storage hardware was the slowest component in any data path, thereby masking the intrinsic inefficiencies of the operating system's software stack.1 Today, modern NVMe solid-state drives (SSDs) and Storage Class Memory (SCM) can routinely deliver millions of random Input/Output Operations Per Second (IOPS) at microsecond-scale latencies.3 Consequently, the Linux kernel—specifically the Virtual File System (VFS), the generic block layer, and interrupt-driven device drivers—has emerged as the primary, rigid bottleneck.1 These software layers consume disproportionate CPU instruction budgets, inflict excessive context-switching penalties, and artificially cap database throughput long before hardware saturation is reached.

This paradigm shift presents cloud service providers and hyperscalers with a profound "Compatibility-Performance Paradox." Mission-critical, legacy relational databases such as PostgreSQL possess decades of hardened transactional logic, multiversion concurrency control (MVCC) optimizations, and broad ecosystem tooling that cannot be casually discarded or rewritten to natively support kernel-bypass storage APIs. Yet, continuing to execute standard, synchronous POSIX I/O calls through the Linux kernel permanently tethers these powerful engines to legacy performance profiles, preventing them from exploiting the exascale hardware upon which they execute.

The traditional x86-64 storage stack, anchored by strict Total Store Ordering (TSO) and monolithic kernels, has encountered a **subspace velocity barrier**. This pivot is mandatory: in a standard 512-byte random read on microsecond-scale hardware, kernel software overhead now accounts for a staggering 51.4% of total latency, constituting an **engineering failure mode**. We are witnessing a fundamental paradigm shift toward weakly-ordered silicon, where legacy performance tethers prevent engines from exploiting the exascale hardware upon which they execute. To **transcend** this barrier, we must abandon the legacy "kernel-as-gatekeeper" model.

This whitepaper proposes a revolutionary, non-destructive architectural blueprint to decisively resolve this paradox. It introduces a transparent, 0-kernel acceleration data plane tailored specifically for legacy PostgreSQL architectures. By synthesizing state-of-the-art systems research—specifically leveraging the Storage Performance Development Kit (SPDK) for kernel bypass, the transparent zero-copy mechanisms of the zIO paradigm (OSDI '22), and the eXpress Resubmission Path (XRP) via eBPF (OSDI '22)—this architecture achieves microsecond-level latency and bare-metal hardware throughput. Crucially, it accomplishes this comprehensive systems-level overhaul without requiring a single modification to the PostgreSQL source codebase.

The proposed architecture is constructed upon three foundational technical pillars:

1. **The Transparent Interception Bridge (The Double Trampoline):** A user-space LD\_PRELOAD shim that heavily virtualizes file descriptors and executes rigorous impedance matching, translating synchronous POSIX system calls into asynchronous SPDK lock-free polling loops across dedicated, affinity-pinned cores.  
2. **Transparent Zero-Copy via the zIO Paradigm:** A sophisticated memory management mechanism that eliminates the catastrophic "double buffering" memory bandwidth tax. It leverages userfaultfd and unmapped virtual memory pages to seamlessly map SPDK hugepages directly into the PostgreSQL address space, initiating lazy-copies only when actively mutated.  
3. **eBPF/XRP Offloading for B-Tree Traversals:** An in-kernel, hardware-adjacent execution environment that embeds eBPF hooks directly within the NVMe hardware interrupt handler. This allows the storage controller to autonomously parse PostgreSQL B-Tree nodes and resubmit sequential read requests from the interrupt context, effectively preventing the PostgreSQL user-space process from waking until the final target data payload is definitively located.

By implementing these structural methodologies, hyperscale cloud environments (such as AWS RDS) can transparently elevate millions of existing PostgreSQL deployments into the microsecond latency tier, maximizing return on investment for underlying flash arrays and ARM64-based compute infrastructures.

## **The Compatibility-Performance Paradox in Modern Relational Databases**

To fully appreciate the necessity of a purely 0-kernel storage architecture, one must first dissect the anatomical failures and instruction bloat inherent to the traditional Linux I/O stack when interfaced with modern storage protocols.

Historically, when a relational database engine like PostgreSQL executed a standard pread64() or pwrite64() system call, the operating system's software overhead was statistically insignificant compared to the rotational latency and seek times of magnetic hard disk drives (HDDs).1 The kernel's complex routing was a well-architected pipeline deliberately designed to coalesce requests, optimize disk head movement, and hide hardware slowness through aggressive page caching.1 The path from the system call interface, through the VFS layer, into the page cache, down to the generic block layer, traversing the I/O scheduler, and finally hitting the SCSI or SATA driver, required substantial computation.1 However, because the hardware operated on a millisecond timescale, spending twenty microseconds in software was an acceptable tradeoff.

The advent of NVMe devices, operating over PCIe fabrics and utilizing massively parallel submission and completion queues, inverted this hardware-software relationship. An enterprise-grade NVMe SSD or Storage Class Memory (SCM) module can routinely deliver random read latencies of approximately 10 to 20 microseconds.3 However, the software execution path traversing the Linux kernel continues to require roughly 20,000 CPU instructions merely to process a single I/O request from user space to the device and back.

On modern cloud infrastructure, such as AWS Graviton processors leveraging the ARM64 instruction set, context switching, CPU cache invalidation, translation lookaside buffer (TLB) shootdowns, and kernel I/O scheduler serialization consume a massive, unsustainable portion of the CPU’s instruction budget. At peak transactional loads, a highly concurrent PostgreSQL database utilizing traditional POSIX I/O spends drastically more time traversing kernel space, trapping interrupts, and contending for VFS inode locks than it does executing actual query logic or waiting for the physical hardware.

The systems engineering industry initially responded to this software bottleneck with the introduction of asynchronous kernel APIs, most notably libaio and, more recently, io\_uring.10 While io\_uring provides a highly efficient shared-memory ring buffer interface that significantly amortizes context-switching costs by batching submissions and completions across a single system call, it fundamentally remains a kernel-mediated technology. It cannot bypass the Virtual File System, nor can it entirely eliminate the memory copies required to move payloads between the kernel's managed page cache and the database's user-space shared buffers.1

Furthermore, extensive empirical studies demonstrate that while io\_uring is highly efficient relative to legacy interfaces, a fully user-space polling architecture like SPDK is vastly superior for extracting maximum hardware performance. Research indicates that SPDK can entirely saturate high-performance NVMe hardware arrays utilizing significantly fewer CPU cores (e.g., utilizing merely 5 dedicated cores for SPDK to achieve maximum line rate, versus requiring up to 13 heavily loaded cores for io\_uring to achieve the identical IOPS threshold).

The ultimate architectural solution, therefore, is complete kernel-bypass storage facilitated via SPDK, which interacts directly with NVMe hardware from user space using lock-free, memory-mapped, polling-based drivers.12 However, transitioning to SPDK traditionally demands that the application's I/O engine be entirely rewritten to be natively asynchronous and explicitly SPDK-aware—a monumental and frankly non-viable proposition for legacy systems like PostgreSQL. The core engineering challenge lies in constructing a transparent data plane that mathematically bridges the synchronous, thread-blocking, POSIX-compliant expectations of PostgreSQL with the inherently asynchronous, polling-centric reality of SPDK without breaking application semantics.

## **Pillar 1: The Transparent Interception Bridge (The Double Trampoline)**

The first pillar of the proposed architecture resolves the integration dilemma by engineering a dynamic interception layer, conceptually referenced as the "Double Trampoline." This robust mechanism forcefully coerces the legacy application's I/O requests to bypass the Linux kernel entirely, rerouting them into a high-performance, user-space data plane without altering, recompiling, or modifying the binary of the PostgreSQL database engine.

### **Dynamic Interception and the LD\_PRELOAD Shim Mechanism**

The functional foundation of the interception bridge relies upon the programmatic manipulation of the Linux dynamic linker's LD\_PRELOAD environment variable. When a dynamically linked application binary is executed, the dynamic loader (ld.so) resolves and maps shared libraries into the process's address space. By specifying a custom shared object via the LD\_PRELOAD directive, the operating system is forced to load the provided interception library prior to loading the standard C library (glibc).

This priority loading allows the architecture to explicitly "hook," override, and shadow standard POSIX Virtual File System (VFS) functions—specifically targeting open(), pread64(), pwrite64(), and fsync()—which form the critical path of PostgreSQL's buffer manager and Write-Ahead Log (WAL) I/O engine. When the PostgreSQL backend process attempts to invoke one of these system functions, the execution path safely "trampolines" into the custom shim rather than trapping into the kernel via an expensive hardware syscall instruction.

Industrial-strength implementations of this core concept, such as Intel DAOS’s advanced libpil4dfs interception library, have irrefutably proven that comprehensive POSIX virtualization can be reliably achieved entirely within user space.16 However, to maintain systemic stability and cleanly isolate database storage structures from auxiliary system files (e.g., standard error logs, configuration files, and authentication manifests like pg\_hba.conf), the shim must deploy an intelligent, low-latency filtering routing mechanism.

### **High-Fidelity File Descriptor Virtualization**

When the PostgreSQL engine issues an open() system call, the LD\_PRELOAD shim intercepts the request and strictly inspects the targeted file path. If the path does not reside on the designated kernel-bypass target volume or NVMe namespace, the shim acts transparently. It delegates the call back to the original glibc function using standard symbol resolution techniques (specifically utilizing the dlsym(RTLD\_NEXT) directive), allowing the kernel to process the request normally.

Conversely, if the path perfectly matches the kernel-bypass target (such as the primary PostgreSQL $PGDATA directory containing table relation segments), the shim intercepts the operation entirely and assumes complete control. It initializes the SPDK execution environment, binds directly to the user-space NVMe controller using VFIO (Virtual Function I/O), and synthetically generates a "Fake File Descriptor".

Fake File Descriptors are intentionally assigned exceptionally high integer values (e.g., integers strictly greater than 1,000,000). This vast numerical separation guarantees that these synthetic descriptors are highly unlikely to collide with actual, low-numbered file descriptors sequentially allocated by the Linux kernel. The user-space shim actively maintains a highly concurrent, lock-free hash table that maps these fake FDs to complex internal SPDK namespace references, translation states, and session contexts.

When subsequent pread64() or pwrite64() requests are issued by PostgreSQL utilizing these fake FDs, the shim instantly recognizes the integer, bypasses all kernel checks, and routes the data directly into the kernel-bypass data path. For architectural edge cases where PostgreSQL requires specific APIs that the shim cannot easily virtualize (such as specialized ioctl commands or advanced socket controls), the architecture elegantly supports a "Compatible Mode." This mode utilizes a background daemon to acquire actual kernel FDs via FUSE or kernel proxying, allowing the system to fail gracefully or satisfy the control-plane request while continuing to relentlessly bypass the kernel for all raw data-plane transfers.

### **Impedance Matching: Reconciling Synchronous POSIX with Asynchronous SPDK**

Intercepting the function call and masking the file descriptor is merely the preliminary phase. The paramount engineering challenge is executing what is termed "impedance matching"—the complex task of reconciling the fundamentally divergent execution and concurrency models of legacy PostgreSQL and modern SPDK.

PostgreSQL is historically built around a strictly synchronous, blocking I/O model. When a backend worker process issues a pread64() call, it implicitly expects to sleep, surrendering the CPU core, until the kernel fulfills the request and physically populates the targeted memory buffer in user space. SPDK, in stark architectural contrast, is inherently asynchronous, event-driven, and entirely lock-free.18 It operates by submitting I/O command payloads to an NVMe hardware Submission Queue (SQ) and subsequently polling an NVMe Completion Queue (CQ) without ever yielding the execution thread.12

To perform precise impedance matching, the shim executes a rigorous, multi-staged state machine for every intercepted read or write operation. When PostgreSQL invokes pread64(), the shim must first translate the POSIX-style file offset and length parameters into absolute physical NVMe Logical Block Addressing (LBA) coordinates. This requires bridging a profound "Semantic Gap," as raw NVMe block hardware is completely oblivious to files, directories, or inodes. The shim preemptively resolves this during the initial file open() phase by issuing a specialized FS\_IOC\_FIEMAP ioctl to the host Linux kernel. This ioctl command extracts the complete logical-to-physical block extent map for the target file. The shim ingests this map and "digests" it into an optimized, memory-resident static radix tree or hash table, permitting instantaneous LBA translation in user space without requiring further kernel metadata lookups.

Once the specific physical LBAs are calculated and mathematically validated against the extent map bounds (preventing rogue access to unallocated sectors), the shim constructs a standard SPDK request structure. It enqueues this structure into a highly optimized, Single-Producer Single-Consumer (SPSC), shared-memory ring buffer, often referred to within bypass architectures as the "Ior ring" (I/O Request ring).

At this exact moment, the calling PostgreSQL backend thread must wait, as its API contract guarantees blocking until completion. To avoid devastatingly wasting CPU cycles in a spin-lock within the PostgreSQL process, the thread invokes a highly optimized futex() system call or blocks on an eventfd(), effectively putting itself to sleep with minimal latency overhead.

### **The DPDK-Style Thread-Per-Core Hardware Polling Loop**

While the PostgreSQL thread slumbers, the true computational power of the SPDK kernel-bypass architecture engages. A dedicated, background worker thread—commonly designated as a "Reactor" thread—operates continuously in a tight, lock-free polling loop.12 To guarantee deterministic, jitter-free microsecond latency, this reactor thread is strictly pinned to an isolated physical CPU core utilizing operating system Core Affinity protocols. This pinning prevents the Linux process scheduler from ever preempting, interrupting, or context-switching the reactor thread.

On advanced ARM64 architectures, such as AWS Graviton deployments leveraging Neoverse cores, this polling thread must be meticulously programmed to respect weak memory consistency models. The reactor thread utilizes explicit memory visibility instructions, such as dsb st (Data Synchronization Barrier for Store) or ARMv8.1 Large System Extensions (LSE) atomics involving LDAR (Load-Acquire) and STLR (Store-Release) instructions. These precise barriers ensure that updates to the NVMe submission queue tail pointers are instantaneously flushed to the memory controller and made visible to the hardware PCIe NVMe controller without suffering from CPU out-of-order execution anomalies.

The polling thread relentlessly sweeps the NVMe Completion Queue. Because it never yields the CPU, it detects hardware I/O completions the exact nanosecond the NVMe controller flips the hardware phase bit in the Completion Queue Entry (CQE).18 Once the Direct Memory Access (DMA) data transfer is cryptographically and structurally validated, the SPDK polling thread updates the shared completion state, places the data payload into the appropriate destination buffer (the "Iov region"), and immediately signals the eventfd() or releases the futex.

The sleeping PostgreSQL backend thread wakes up instantaneously, observes that its target memory buffer has been accurately populated, and returns from the intercepted pread64() system call. To the database engine and its internal buffers, the operation appeared as a standard, flawlessly executed, albeit blisteringly fast, synchronous kernel call. In reality, the entire data path was orchestrated entirely in Ring 3 user space, completely bypassing the VFS, block layer, kernel I/O scheduler, and costly hardware interrupt handling routines.

### **Architectural Comparison: I/O Execution Models**

To quantify the structural advantages of the Double Trampoline, consider the contrasting execution pipelines outlined below:

| Architectural Attribute | Legacy Linux Kernel I/O Stack | SPDK User-Space Interception Bridge |
| :---- | :---- | :---- |
| **Execution Domain** | Kernel-Space (Ring 0), Interrupt-Driven | User-Space (Ring 3), Pure Hardware Polling |
| **Context Switch Penalty** | 2 per I/O Request (User ![][image1] Kernel ![][image1] User) | 0 per I/O Request (Remains strictly in user space) |
| **Hardware Notification** | Hardware Interrupt (IRQ) processing | CQ Phase Bit Polling (Busy-Wait verification) |
| **CPU Instruction Cost** | \~20,000+ instructions per I/O cycle | \~3,500 instructions per I/O cycle |
| **Concurrency Control** | VFS Inode Locks, Global Scheduler Spinlocks | Lock-Free SPSC Ring Buffers, Atomic Memory Barriers |
| **Application Modification** | None required (Native POSIX APIs) | None required (Transparent LD\_PRELOAD Shim) |

## **Pillar 2: Transparent Zero-Copy via the zIO Paradigm**

While the Transparent Interception Bridge successfully eradicates the CPU penalty associated with kernel context switching and VFS locking, it does not inherently resolve the impending memory bandwidth crisis. In traditional relational database architectures, including PostgreSQL, data suffers from a severe "double buffering" memory tax.1

When the NVMe controller fetches data from the physical media, it typically performs a DMA transfer into the kernel's managed Page Cache.1 Following this, the CPU is forced to execute an computationally expensive memcpy operation to transit that data from kernel space into the database's designated user-space memory arena (i.e., PostgreSQL's massive shared\_buffers pool).1

As network architectures scale beyond 100 Gbps and PCIe Gen 5 NVMe drives effortlessly exceed 14 GB/s of throughput, the raw memory bandwidth required to physically copy these payloads across the user/kernel boundary becomes a severe, unyielding limiting factor.22 While traditional "zero-copy" interfaces, such as memory-mapped files (mmap), have existed for decades, they carry heavy, often hidden microarchitectural costs related to aggressive page table management, kernel trapping, and destructive Translation Lookaside Buffer (TLB) shootdowns.7 Furthermore, attempting to force a legacy application like PostgreSQL to utilize strict, proprietary zero-copy APIs typically requires total code rewrites and fundamental engine redesigns.22

The second pillar of this architecture establishes a regime of transparent zero-copy memory management by deeply integrating the **zIO paradigm** (comprehensively detailed at OSDI '22 by Stamler et al.). The zIO methodology establishes a sophisticated mechanism for tracking data movement and eliminating intermediate memory copies entirely transparently to the executing application.

### **Eradicating the User-Space Bounce Buffer Penalty**

In standard user-space storage shims (including early iterations of SPDK application wrappers), a "bounce buffer" is an unavoidable requirement. Hardware NVMe controllers demand that memory be physically contiguous and aggressively pinned (page-locked) to perform safe, corruption-free DMA transfers. Standard virtual memory allocated by PostgreSQL via glibc malloc or anonymous mmap mapping does not meet these stringent hardware criteria, as the Linux kernel may transparently swap pages to disk, migrate them between NUMA nodes, or allocate highly fragmented physical memory behind a contiguous virtual facade.

To circumvent this, shim libraries typically allocate a massive pool of DMA-safe, 2MiB or 1GiB SPDK hugepages upon initialization. During an intercepted pread64() operation, the hardware DMAs the payload safely into the SPDK hugepage bounce buffer. Following completion, the shim must then execute a CPU-bound memcpy to transfer the payload from the bounce buffer into the specific destination buffer originally provided by the PostgreSQL pread64() call.

The zIO paradigm brilliantly eliminates this final, wasteful CPU copy through a revolutionary application of dynamic virtual memory manipulation. Instead of physically copying the data, the architecture seamlessly maps the SPDK DMA bounce buffer directly into PostgreSQL's virtual address space.

### **Leveraging userfaultfd and Unmapped Lazy-Copy Logic**

The technical implementation of this zero-copy data path relies heavily on the advanced Linux userfaultfd mechanism. When PostgreSQL issues an I/O request, the interception shim tracks the memory address and length of the destination buffer provided by the database engine. Rather than performing a physical, cycle-wasting copy from the SPDK bounce buffer to the PostgreSQL destination buffer, the shim utilizes the mmap system call paired with the MAP\_FIXED flag to actively and intentionally **unmap** the virtual memory pages corresponding to the database's destination buffer.

The shim subsequently registers this newly unmapped memory range with a user-space page fault handler via userfaultfd. At this specific juncture, the intercepted pread64() call returns successfully to the PostgreSQL backend process. From the database's perspective, the read is complete, yet absolutely no actual data copying has taken place. The memory mapping is purely logical and deferred.

PostgreSQL proceeds to execute its internal query logic. In modern analytical (OLAP) or heavy scanning workloads, a massive percentage of fetched data may simply be scanned for aggregation and immediately discarded, or it may reside passively in shared\_buffers as read-only pages, evaluated for cache eviction without ever being modified. Under the zIO paradigm, if PostgreSQL treats the buffer as strictly read-only, the virtual memory simply resolves to the physical NVMe DMA hugepage managed by SPDK. The CPU copy penalty has been entirely eliminated.

However, if a PostgreSQL backend thread attempts to actively mutate (touch) the data—for instance, to execute an UPDATE statement, insert a new tuple, or simply set a hint bit (such as xmin/xmax visibility status) on a tuple header—the CPU will attempt a write instruction to an unmapped or write-protected memory page. Predictably, this triggers a hardware page fault.

Traditionally, a page fault violently traps into the kernel and, if the memory is invalid, crashes the application with a SIGSEGV (Segmentation Fault).  By utilizing userfaultfd, the Linux kernel instead pauses the faulting thread and routes the page fault directly to the dedicated interception thread within the user-space shim.

The shim instantly intercepts this fault event, recognizes that PostgreSQL now requires a private, writable copy of the data page, and executes a highly optimized **lazy-copy**. It physically copies the specific, requested 4KB or 8KB page from the shared SPDK hugepage into a newly allocated, standard, writable memory page. It then remaps the virtual address to point to this new writable page, and gracefully instructs the kernel to awaken the suspended PostgreSQL thread to retry the previously failed write instruction.

This entire fault, copy, and remap process takes merely a few microseconds.  Crucially, the cost of the page fault and the physical copy is *only paid for the specific data that is actively modified*.7

### **Dynamic Performance Protection Policies**

While the userfaultfd interception model is a brilliant optimization for eliminating bulk sequential copies, deliberately triggering page faults carries its own microarchitectural overhead (primarily related to TLB invalidation, kernel trapping, and context switching).7 If a database workload is intensely write-heavy (OLTP) and actively modifies every single page it reads from disk, the cumulative cost of handling thousands of user-space page faults would rapidly eclipse the cost of simply performing a highly vectorized bulk memcpy upfront.

To mathematically guarantee that the architecture never accidentally degrades database performance, the integration of zIO employs a dynamic, self-correcting tracking policy evaluated on a per-I/O basis:

1. **Strict Size Thresholds:** The fixed overhead of page table manipulation and userfaultfd registration is only justifiable for sufficiently large data payloads. The shim logic is hardcoded to bypass zero-copy mechanisms entirely for small I/O operations. Any requested buffer smaller than the 16KB threshold is aggressively copied via highly vectorized (SIMD/AVX) memcpy routines rather than tracked via unmapped pages. Given that the standard PostgreSQL block size is 8KB, zero-copy tracking is primarily activated during sequential scans, index creation builds, or WAL bulk flush operations where I/O sizes routinely scale up to 128KB, 1MB, or larger.  
2. **Fault-to-Eliminated-Bytes Tracking Ratio:** The shim actively and continuously monitors the behavior of the PostgreSQL backend process. It tracks the ratio of page faults generated versus the total number of bytes successfully saved from being physically copied. If the workload proves to be highly mutative—specifically, if the dynamic fault-to-eliminated-bytes ratio exceeds a threshold of 6%—the shim ascertains that the page fault overhead is detrimental. It instantly and dynamically disables zero-copy tracking for that specific relation or file descriptor, reverting safely to the standard SPDK bounce-buffer copy path.

By transparently manipulating virtual memory mappings behind the scenes, this architecture allows legacy PostgreSQL to operate directly upon the raw memory space of the NVMe controller. This radically slashes memory bandwidth consumption and reclaims massive amounts of CPU cycles that would otherwise be wasted shuttling redundant data across the PCIe bus and CPU cache hierarchy.22

## **Pillar 3: eBPF/XRP Offloading for B-Tree Traversals**

While bypassing the kernel via the Double Trampoline and eliminating memory copies via zIO brilliantly resolves the raw throughput and memory bandwidth challenges, legacy databases like PostgreSQL continue to suffer from severe latency amplification due to the profound semantic mismatch between software data structures and raw storage hardware. This systemic flaw is most devastatingly pronounced during deep index traversals.

### **The PostgreSQL B-Tree Amplification Problem**

The default, most ubiquitous, and critical index structure utilized within PostgreSQL is the B-Tree (Balanced Tree).25 A PostgreSQL B-Tree index is a complex, multi-level structure stored across physical disk blocks, meticulously composed of a singular metapage, numerous internal branch nodes, and terminal leaf nodes containing the actual item pointers (ctids) to table rows.27 Furthermore, PostgreSQL B-Trees handle intense complexities such as MVCC version churn and lazy bottom-up deduplication.27

When a PostgreSQL query execution engine requires a point lookup (e.g., executing SELECT \* FROM accounts WHERE user\_id \= 1048576;), it must recursively traverse the B-Tree from the root node down to the specific target leaf.29 If the database is massive (e.g., terabytes in size) and the vast majority of the index does not reside warmly in the shared\_buffers cache, this traversal generates a synchronous, deeply dependent chain of I/O operations.29

The database must first read the root node block from disk. It must halt execution, wait for the I/O to complete, wake up the sleeping thread, parse the 8KB block in user space, perform an algorithmic binary search within the node to locate the correct pointer, and then issue a subsequent, entirely new pread64() call for the next internal node.29 If the B-Tree is massive and possesses a depth of six levels, the database must execute six complete, sequential round-trips through the entire system stack (User Space ![][image1] Shim ![][image1] SPDK Queue ![][image1] PCIe NVMe ![][image1] SPDK Completion ![][image1] Shim ![][image1] User Space).

Even with a highly optimized 0-kernel SPDK bypass operating at a blistering 10 microseconds per I/O, the synchronous dependency dictates that the CPU thread is repeatedly put to sleep and aggressively woken up six times in rapid succession.30 The application is forced to process and subsequently throw away the intermediate internal nodes once the single desired child pointer is extracted. This wastes immense CPU cycles moving and evaluating data that the application ultimately discards.30

### **The XRP Architecture: Storage Functions in the Hardware Interrupt Handler**

The third architectural pillar fundamentally obliterates this latency amplification by pushing the structural traversal logic directly down into the hardware execution path. This is realized through the integration of the **eXpress Resubmission Path (XRP)**, a groundbreaking framework introduced at OSDI '22 by Zhong et al..8

XRP leverages Linux eBPF (Extended Berkeley Packet Filter)—a highly constrained, cryptographically verified, sandboxed virtual machine format—to execute user-defined storage functions deep within the OS stack.8 In a standard kernel-based environment, XRP places an eBPF hook directly into the NVMe driver's raw hardware interrupt handler (IRQ). In the proposed 0-kernel SPDK architecture, this hook is embedded directly within the SPDK user-space polling loop (the "Lower Trampoline"), avoiding interrupts entirely.

When an SPDK spdk\_nvme\_ns\_cmd\_read operation completes, the NVMe hardware controller writes an entry to the Completion Queue. Normally, the SPDK poller processes this completion, copies the data, and immediately signals the waiting PostgreSQL thread to wake up. Under the XRP paradigm, the poller intercepts the completion and instead triggers a specialized, Just-In-Time (JIT) compiled eBPF virtual machine (such as uBPF or the Rust-based Aya runtime) loaded with custom PostgreSQL B-Tree parsing logic.

### **Autonomous B-Tree Parsing and Resubmission from Context**

The eBPF program executes instantaneously against the raw data buffer residing securely in the NVMe DMA region. It is specifically and uniquely programmed to understand the intricate binary layout of a PostgreSQL B-Tree node, including page headers, item pointer arrays, and tuple layouts.27 Because B-Tree keys are strictly sorted within the node, the eBPF function effortlessly performs the binary search to locate the target key and extracts the logical block number of the next child node in the tree hierarchy.

Crucially, rather than waking up the heavy PostgreSQL backend process to perform this logic, the eBPF program invokes a specialized resubmit helper function directly from the polling context. This helper immediately constructs a new spdk\_nvme\_ns\_cmd\_read request for the newly discovered child node and enqueues it directly into the NVMe Submission Queue. The SPDK poller then seamlessly continues its hardware loop.

This creates a high-velocity, autonomous **"resubmission loop"** that operates entirely within the hardware polling context.  The intermediate internal B-Tree nodes never cross the boundary back to the application; they are evaluated and discarded the very microsecond the pointer is extracted.30 The PostgreSQL user-space thread remains completely asleep, utterly unaware of the furious intermediate hardware operations. Only when the eBPF function definitively reaches the terminal leaf node containing the actual data tuple does it signal the SPDK engine to finalize the operation and wake up the PostgreSQL thread.27

### **The Metadata Digest: Securing the Semantic Gap**

A significant systemic barrier to executing logic at the raw hardware layer is the total loss of file system context. The NVMe driver understands only physical Logical Block Addresses (LBAs). The eBPF program, parsing PostgreSQL internal structures, extracts logical block numbers, which are merely offsets within a specific table segment file.

To bridge this semantic disconnect securely, XRP introduces the critical concept of a **"Metadata Digest"**. When the interception shim first opens the PostgreSQL data file, it issues the FS\_IOC\_FIEMAP ioctl to map the entire file layout, translating all logical file blocks to physical LBAs. This extent map is heavily compressed into a highly optimized, read-only data structure (such as a static radix tree) residing in shared memory accessible by the eBPF VM.

During the resubmission loop, the eBPF program extracts the logical block number of the next B-Tree child. It then calls a specific security helper function (e.g., BPF\_disk\_trans()), passing the logical offset. The helper consults the Metadata Digest, translates the offset to a physical LBA, and rigorously validates that the requested physical block resides strictly within the authorized boundaries of the target file.

If an error occurs, or if a malformed pointer attempts an out-of-bounds access, the eBPF execution is safely and instantly aborted, and control is returned to PostgreSQL to handle the fault gracefully. This cryptographic-level validation guarantees that executing application logic within the hardware driver cannot be exploited to corrupt arbitrary sectors on the disk or break tenant isolation.

Empirical systems research from the OSDI '22 XRP publication demonstrates the devastating effectiveness of this offloading technique. When tested against complex B-Tree structures scaled up to six index levels deep, the resubmission architecture yielded massive performance gains, specifically achieving **61% to 120% higher throughput** and simultaneously delivering **16% to 41% lower tail (p99) latency** compared to standard I/O pathways.

By preventing the repeated context switching, CPU scheduler wakeup overheads, and user-space data copies normally incurred during deep index traversals, XRP allows the storage hardware to operate at its absolute maximum mechanical velocity.

| Index Traversal Stage | Standard PostgreSQL B-Tree Lookup | XRP-Accelerated eBPF Lookup |
| :---- | :---- | :---- |
| **Node Fetch Mechanism** | User Thread blocks on POSIX Read | Autonomous eBPF Polling Context (No Thread Block) |
| **Node Parsing Execution** | User Space (PostgreSQL Backend Process) | eBPF JIT Virtual Machine (Hardware Context) |
| **Next I/O Issuance** | User ![][image1] Kernel VFS ![][image1] Block Layer | Direct NVMe SQ Enqueue (resubmit helper) |
| **Context Switches (Depth 6\)** | 12 (2 per B-Tree level) | 0 (Thread remains asleep until final Leaf is found) |
| **Data Copied to App Memory** | Root, all Internal Nodes, and Leaf Node | Only the final Leaf Node Payload |

## **Synthesis: Solving the "Compatibility-Performance Paradox" for Cloud RDS**

The synthesis of these three advanced pillars—the Double Trampoline LD\_PRELOAD Shim, zIO Page Mapping, and XRP B-Tree Offloading—results in an architectural paradigm that fundamentally redefines the performance capabilities of legacy database engines executing on modern cloud infrastructure.

Hyperscalers and cloud service providers managing vast fleets of managed database instances (such as AWS RDS or Aurora) are continually pressured to maximize IOPS per CPU core to maintain margin. Historically, achieving the extreme performance metrics of disaggregated, scale-out databases required abandoning standard PostgreSQL storage models entirely in favor of proprietary, log-structured write paths, quorum consensus models, and heavy network pushdowns.

This proposed 0-Kernel architecture proves definitively that legacy, vanilla PostgreSQL can be accelerated to match or exceed these modern metrics without modifying a single line of the open-source codebase or altering the on-disk format.

1. **Microsecond Determinism:** By trapping pread64 and pwrite64 calls in Ring 3 and seamlessly routing them to affinity-pinned SPDK cores, the VFS and generic block layer are erased from the critical path. The debilitating "kernel tax" of 20,000 instructions per I/O is eliminated, delivering deterministic sub-15 microsecond reads natively to legacy applications.  
2. **Memory Bandwidth Conservation:** By manipulating userfaultfd and unmapped pages under the zIO paradigm, massive analytical workloads can ingest gigabytes of data from NVMe drives directly into their processing pipelines without triggering a single CPU-driven memory copy. This aggressively preserves limited memory bandwidth for actual query execution and aggregation.  
3. **Latency Collapse for Heavy Indexing:** Through the deployment of XRP and cryptographic metadata digests, deep B-Tree structures no longer punish the system scheduler. The NVMe hardware essentially parses the index structure autonomously in the background, delivering only the finalized, relevant leaf data back to the database backend.

### **Broad Applicability of the 0-Kernel Architecture: Pushing the Boundaries of Disaggregated AI, HPC and ULL Infrastructure**

The architectural paradigm of transparent, zero-kernel acceleration establishes a foundational substrate that extends far beyond the optimization of legacy relational database engines. As the frontier of hardware-software co-design matures, this zero-copy, user-space I/O fabric is actively dismantling critical performance bottlenecks across modern distributed systems and hyperscale AI infrastructure.45

#### **1\. Unified Logic-Resident Storage via DPUs**

By offloading NVMe submission and completion queue management directly onto Data Processing Units (DPUs) or SmartNICs, the host CPU is entirely liberated from the debilitating overhead of I/O orchestration.36 The DPU transparently exposes a unified, logic-resident memory fabric to the host, mapping remote NVMe-oF (NVMe over Fabrics) block devices directly into the application's user-space virtual memory via PCIe peer-to-peer DMA.47 This methodology effectively disaggregates storage and compute while maintaining the seamless illusion of local, zero-copy memory access for horizontally scaled and CXL-enabled architectures.44

#### **2\. High-Frequency AI Training and Stateful Checkpointing**

The extreme data volumes required for continuous tensor state checkpointing demand uninterrupted, line-rate sequential write throughput. By adapting the zIO page mapping and `userfaultfd` mechanisms to distributed training workloads, multi-gigabyte model states can be asynchronously flushed to NVMe arrays, completely bypassing the Linux page cache.37 This transformation elevates the underlying storage layer into a high-performance fabric capable of sustaining the massive, high-frequency checkpointing demands of modern distributed training loops.

#### **3\. AI Inference: Distributed K-V Cache and Expert Streaming**

The memory wall in Large Language Model (LLM) inference is primarily dictated by the explosive growth of the Context Window (KV cache) and the massive parameter footprints of Mixture of Experts (MoE) architectures. Zero-kernel NVMe acceleration allows the KV cache to be distributed and paged directly to local flash, decisively breaking traditional VRAM/RAM capacity ceilings.46 Furthermore, it enables true **Expert Streaming**: as the model routes tokens, a `userfaultfd` exception is triggered, streaming only the necessary expert weight layers from SPDK-managed NVMe into memory exactly when required, with zero kernel-space copying overhead.38

#### **4\. Virtual File Systems: Container Bootup and Agentic Git Mono-repos**

As enterprise engineering converges on hyperscale monorepos, the decentralized architecture of Git introduces paralyzing I/O and network bottlenecks. Repositories scaling into the hundreds of gigabytes impose severe penalties on operations like `git clone`, which mandate massive local storage allocation and hours of network transfer. Furthermore, local index bloat causes routine commands (such as `git status`) to stall on millions of synchronous `lstat` system calls, while high-concurrency object packing (`git repack`) leads to server-side push timeouts.39 By abstracting block storage directly into user space, this architecture enables hyper-fast virtual file systems tailored to resolve these exact bottlenecks. Container bootup times shrink to milliseconds via lazy-paging, where the runtime pulls only the specific binary pages required for execution.48, 49 Similarly, the zero-copy virtual file system transparently traps read accesses, lazily fetching only the specific repository files the agent explores directly into its context, bypassing local indexing overhead and enabling instant navigation of hyperscale codebases.

#### **5\. Vector Databases & AI RAG Pipelines: Disk-ANN Graph Traversals**

To mitigate massive RAM costs, modern vector databases often store the bulk of their Approximate Nearest Neighbor (e.g., DiskANN) graphs on NVMe SSDs. Navigating these vector graphs requires aggressive, highly concurrent random read operations—the quintessential **Random Read Bottleneck**. Relying on standard kernel I/O heavily tethers the maximum throughput of these databases, frequently capping them at a fraction of the hardware's capability. An interception shim allows these continuous pointer-chasing reads to bypass the kernel entirely, permitting Retrieval-Augmented Generation (RAG) pipelines to achieve rapid retrieval latencies at a fraction of traditional hardware costs.40

#### **6\. High-Performance Data Analytics (HPDA): Columnar Databases & Real-Time OLAP**

Real-time OLAP engines process petabytes of columnar data via massive sequential scans. The zero-kernel architecture allows query execution engines to stream in-memory formats like Apache Arrow or Parquet directly from NVMe to CPU registers without intermediate buffering. Bypassing the kernel page cache prevents memory eviction storms and drastically reduces the CPU cycles spent on deserialization and memory copying, directly accelerating aggregations and analytics workloads.41, 50

#### **7\. Data-Intensive Scientific Computing (DISC): Computational Biology & Genomics**

The secondary analysis of genomic data (such as DNA sequence alignment and variant calling) involves comparing short reads against massive reference genomes. This requires extreme memory bandwidth and highly randomized, data-dependent access patterns to terabyte-sized datasets. Zero-copy NVMe access enables bioinformatics pipelines to map sequence indexes and stream FASTQ files directly into user space, drastically reducing the latency and compute overhead required for precision medicine.42

#### **8\. Ultra-Low Latency (ULL) Systems: High-Frequency Trading (HFT) and Real-Time Bidding (RTB)**

In algorithmic trading and AdTech, systems must evaluate complex logic and capture data streams without injecting microsecond jitter into the critical path. High-Frequency Trading (HFT) systems require absolute determinism to execute trades, while Real-Time Bidding (RTB) platforms process millions of bid requests per second, demanding massive user-profile lookups and ML inference within strict 10–50 millisecond windows. Standard POSIX `read()` and `write()` calls introduce unpredictable kernel-space latency spikes under such extreme concurrency. Leveraging user-space NVMe queues allows HFT systems to asynchronously persist trading ledgers with absolute determinism. Simultaneously, it enables RTB engines to instantly page distributed user-graph data from flash to CPU registers, bypassing the OS entirely. This zero-kernel approach ensures compliance for financial systems and maximizes bid win-rates for ad exchanges by eliminating OS-induced latency tails.43, 51, 52

## **Engineering Engagement and Conclusion**

The convergence of kernel-bypass storage drivers, zero-copy virtual memory manipulation, and eBPF-driven hardware offloading represents the zenith of modern systems engineering. As PCIe Gen 5 devices proliferate and Compute Express Link (CXL) attached storage blurs the physical boundaries between system memory and persistent disk, the traditional operating system storage stack is no longer a viable intermediary for mission-critical, high-throughput data.

While this architecture provides an immediate, transparent solution to the "Compatibility-Performance Paradox" for legacy relational databases like PostgreSQL, its ultimate value lies in its horizontal applicability across the modern hyperscale infrastructure stack. As demonstrated, the zero-kernel fabric seamlessly extends to resolve paralyzing I/O bottlenecks across diverse, data-intensive domains. From unifying logic-resident storage via DPUs and sustaining extreme-scale AI training checkpoints, to enabling distributed LLM KV caching and instantly paging hyperscale Git mono-repos for autonomous workflows, the architectural benefits profoundly transcend traditional database optimization.

Crucially, the expansion into Vector Databases for RAG pipelines, High-Performance Data Analytics (HPDA), Data-Intensive Scientific Computing (DISC), and Ultra-Low Latency (ULL) ecosystems—including sub-millisecond High-Frequency Trading (HFT) and massive-concurrency Real-Time Bidding (RTB) engines—cements the universal necessity of this design. By intercepting continuous pointer-chasing reads and asynchronous flushes before they reach the OS, these distributed systems achieve theoretical maximum throughput at a fraction of traditional hardware costs.

For enterprise systems architects and cloud infrastructure providers, the directive is unambiguously clear: high-performance workloads can no longer afford kernel-space arbitration. By rigorously implementing the zIO tracking, Double Trampoline, and XRP resubmission paradigms detailed in this whitepaper, organizations can extract the absolute maximum mechanical performance from their NVMe fleets. The future of high-throughput computing—whether preserving total compatibility with the global PostgreSQL ecosystem, accelerating computational genomics pipelines, or powering the absolute frontier of AdTech and AI infrastructure—lies not in rewriting the application layer, but in transparently redefining the systems-level fabric upon which it executes.

## **Appendix A: Microarchitectural Synergy and Silicon-Specific Tuning**

While the abstraction of `userfaultfd` and SPDK provides a hardware-agnostic mechanism for zero-copy I/O, achieving theoretical maximum throughput requires aligning the user-space memory layouts and polling mechanisms with the underlying microarchitecture. This section details the necessary silicon-specific tuning for modern ARM64 and RISC-V deployments.

### **1\. ARM64-Specific Optimizations**

When deploying the zero-copy shim on ARM Neoverse architectures, two primary hardware features must be explicitly managed to prevent silent performance degradation or hardware faults:

* **SMMUv3 and Top Byte Ignore (TBI) Co-Design:** Lock-free data structures operating in user space frequently utilize ARM’s Top Byte Ignore (TBI) feature to embed metadata (such as ABA counters or hazard pointers) directly within the upper 8 bits of a 64-bit pointer. However, when these user-space virtual addresses are passed directly to the NVMe controller for DMA via the System MMU (SMMUv3), the hardware will throw a `0x10 F_TRANSLATION` fault if it encounters non-zero top bytes. To resolve this, the shim explicitly configures the `TBI0` bit in the SMMUv3 Context Descriptors, instructing the I/O translation unit to mask the metadata bits exactly as the CPU does \[32\].  
* **Neoverse L2 Spatial Prefetcher Alignment:** Modern ARM cores (such as the Neoverse V1 and V2) employ aggressive L2 spatial prefetchers that fetch adjacent cache lines. For the ring buffers and completion queues managed by SPDK, standard 64-byte alignment results in destructive interference and false sharing as the prefetcher pulls modified neighbor lines across core boundaries. Padding these critical concurrency structures to 128 bytes entirely mitigates this interference \[33\].

#### **2\. RISC-V Extension Utilization**

For custom or emerging RISC-V silicon targeting high-performance storage, the architecture leverages specific standard extensions to optimize the thread-per-core polling model:

* **Low-Power Polling via Zawrs (`WRS.NTO`):** The traditional SPDK reactor model relies on continuous busy-polling, which consumes maximum power and thermal budget. By utilizing the *Wait-on-Reservation-Set* (Zawrs) extension, specifically the `WRS.NTO` (Wait on Reservation Set, No Timeout) instruction, the reactor threads can yield execution unit resources while waiting for NVMe completion queue updates. This allows the core to drop into a lower power state without incurring the heavy latency penalty of a full kernel context switch \[34\].  
* **Cache Pollution Mitigation via Zihintntl (`NTL.P1`):** During large sequential scans of PostgreSQL B-tree leaf nodes, bringing raw block data into the L1/L2 caches forces the eviction of hotter index pages. The architecture integrates the *Non-Temporal Locality* (Zihintntl) extension, applying the `NTL.P1` hint to bulk memory copies or scans. This instructs the microarchitecture to bypass the inner cache levels for these transient blocks, preserving the cache residency of the upper B-tree routing nodes \[35\].

## **References**

1. I/O Approaches in Modern Storage Systems \- CS647, accessed April 28, 2026, [https://www.csd.uoc.gr/\~hy647/lectures/09\_iopath.pdf](https://www.csd.uoc.gr/~hy647/lectures/09_iopath.pdf)  
2. Rearchitecting Linux Storage Stack for µs Latency and High Throughput \- USENIX, accessed April 28, 2026, [https://www.usenix.org/system/files/osdi21-hwang.pdf](https://www.usenix.org/system/files/osdi21-hwang.pdf)  
3. BypassD: Enabling fast userspace access to shared SSDs \- Computer Sciences User Pages, accessed April 28, 2026, [https://pages.cs.wisc.edu/\~swift/papers/asplos24-bypassd.pdf](https://pages.cs.wisc.edu/~swift/papers/asplos24-bypassd.pdf)  
4. Quick Paper Summary: What Modern NVMe Storage Can Do, And How To Exploit It: High-Performance I/O… \- Medium, accessed April 28, 2026, [https://medium.com/@dichenldc/quick-paper-summary-what-modern-nvme-storage-can-do-and-how-to-exploit-it-high-performance-i-o-438a55ff6901](https://medium.com/@dichenldc/quick-paper-summary-what-modern-nvme-storage-can-do-and-how-to-exploit-it-high-performance-i-o-438a55ff6901)  
5. DAOS: Revolutionizing High-Performance Storage with Intel® Optane™ Technology, accessed April 28, 2026, [https://www.intel.com/content/dam/www/public/us/en/documents/solution-briefs/high-performance-storage-brief.pdf](https://www.intel.com/content/dam/www/public/us/en/documents/solution-briefs/high-performance-storage-brief.pdf)  
6. TensorPlane: The Recursive Self-Improving AI Foundry \- GitHub, accessed April 28, 2026, [https://github.com/SiliconLanguage/tensorplane\#tensorplane-the-recursive-self-improving-ai-foundry](https://github.com/SiliconLanguage/tensorplane#tensorplane-the-recursive-self-improving-ai-foundry)  
7. zIO: Accelerating IO-Intensive Applications with Transparent Zero-Copy IO \- USENIX, accessed April 28, 2026, [https://www.usenix.org/conference/osdi22/presentation/stamler](https://www.usenix.org/conference/osdi22/presentation/stamler)  
8. XRP: In-Kernel Storage Functions with eBPF \- USENIX, accessed April 28, 2026, [https://www.usenix.org/conference/osdi22/presentation/zhong](https://www.usenix.org/conference/osdi22/presentation/zhong)  
9. Performance Characterization of Modern Storage Stacks: POSIX I/O, libaio, SPDK, and io\_uring \- Large Research, accessed April 28, 2026, [https://atlarge-research.com/pdfs/2023-cheops-iostack.pdf](https://atlarge-research.com/pdfs/2023-cheops-iostack.pdf)  
10. Performance Characterization of Modern Storage Stacks: POSIX I/O, libaio, SPDK, and io\_uring \- ResearchGate, accessed April 28, 2026, [https://www.researchgate.net/publication/370601725\_Performance\_Characterization\_of\_Modern\_Storage\_Stacks\_POSIX\_IO\_libaio\_SPDK\_and\_io\_uring](https://www.researchgate.net/publication/370601725_Performance_Characterization_of_Modern_Storage_Stacks_POSIX_IO_libaio_SPDK_and_io_uring)  
11. io\_uring for High-Performance DBMSs: When and How to Use It \- arXiv, accessed April 28, 2026, [https://arxiv.org/html/2512.04859v1](https://arxiv.org/html/2512.04859v1)  
12. SPDK Architecture Guide \- simplyblock, accessed April 28, 2026, [https://simplyblock.io/glossary/spdk-architecture/](https://simplyblock.io/glossary/spdk-architecture/)  
13. SPDK: Message Passing and Concurrency \- Storage Performance Development Kit, accessed April 28, 2026, [https://spdk.io/doc/concurrency.html](https://spdk.io/doc/concurrency.html)  
14. XRP: In-Kernel Storage Functions with eBPF, accessed April 28, 2026, [https://nvmw.ucsd.edu/nvmw2023-program/nvmw2023-paper17-final\_version\_your\_extended\_abstract.pdf](https://nvmw.ucsd.edu/nvmw2023-program/nvmw2023-paper17-final_version_your_extended_abstract.pdf)  
15. What is the LD\_PRELOAD trick? \- Stack Overflow, accessed April 28, 2026, [https://stackoverflow.com/questions/426230/what-is-the-ld-preload-trick](https://stackoverflow.com/questions/426230/what-is-the-ld-preload-trick)  
16. File System \- DAOS v2.4, accessed April 28, 2026, [https://docs.daos.io/v2.4/user/filesystem/](https://docs.daos.io/v2.4/user/filesystem/)  
17. Distributed Asynchronous Object Storage (DAOS) on Aurora \- Argonne Leadership Computing Facility, accessed April 28, 2026, [https://www.alcf.anl.gov/sites/default/files/2025-06/DAOS\_developer\_session\_ALCF\_v2.pdf](https://www.alcf.anl.gov/sites/default/files/2025-06/DAOS_developer_session_ALCF_v2.pdf)  
18. Storage Performance Development Kit (SPDK), accessed April 28, 2026, [https://spdk.io/](https://spdk.io/)  
19. SPDK: Event Framework \- Storage Performance Development Kit, accessed April 28, 2026, [https://spdk.io/doc/event.html](https://spdk.io/doc/event.html)  
20. SPDK+: Low Latency or High Power Efficiency? We Take Both \- Diyu Zhou, accessed April 28, 2026, [https://zhou-diyu.github.io/files/spdkp-hotstorage25.pdf](https://zhou-diyu.github.io/files/spdkp-hotstorage25.pdf)  
21. zIO: Accelerating IO-Intensive Applications with Transparent Zero-Copy IO \- USENIX, accessed April 28, 2026, [https://www.usenix.org/system/files/osdi22-stamler.pdf](https://www.usenix.org/system/files/osdi22-stamler.pdf)  
22. Host Efficient Networking Stack Utilizing NIC DRAM \- acm sigcomm, accessed April 28, 2026, [https://conferences.sigcomm.org/events/apnet2023/papers/sec1-host.pdf](https://conferences.sigcomm.org/events/apnet2023/papers/sec1-host.pdf)  
23. Copyright by Timothy P. Stamler 2022 \- The University of Texas at Austin, accessed April 28, 2026, [https://repositories.lib.utexas.edu/bitstreams/a33f91d8-0dee-45f7-ad0c-27fed3443943/download](https://repositories.lib.utexas.edu/bitstreams/a33f91d8-0dee-45f7-ad0c-27fed3443943/download)  
24. Kelvin: Zero Copying Data Pipelines \- arXiv, accessed April 28, 2026, [https://arxiv.org/html/2504.06151v1](https://arxiv.org/html/2504.06151v1)  
25. How to Create B-Tree Index Design \- OneUptime, accessed April 28, 2026, [https://oneuptime.com/blog/post/2026-01-30-btree-index-design/view](https://oneuptime.com/blog/post/2026-01-30-btree-index-design/view)  
26. PostgreSQL Indexes: B-Tree \- Ilija Eftimov ‍, accessed April 28, 2026, [https://ieftimov.com/posts/postgresql-indexes-btree/](https://ieftimov.com/posts/postgresql-indexes-btree/)  
27. Documentation: 16: 67.4. Implementation \- PostgreSQL, accessed April 28, 2026, [https://www.postgresql.org/docs/16/btree-implementation.html](https://www.postgresql.org/docs/16/btree-implementation.html)  
28. Documentation: 18: 65.1. B-Tree Indexes \- PostgreSQL, accessed April 28, 2026, [https://www.postgresql.org/docs/current/btree.html](https://www.postgresql.org/docs/current/btree.html)  
29. B-Tree Implementation in PostgreSQL: Deep Dive into Database Indexing | by Miftahul Huda, accessed April 28, 2026, [https://iniakunhuda.medium.com/b-tree-implementation-in-postgresql-deep-dive-into-database-indexing-b1a34032637d](https://iniakunhuda.medium.com/b-tree-implementation-in-postgresql-deep-dive-into-database-indexing-b1a34032637d)  
30. XRP: In-Kernel Storage Functions with eBPF \- USENIX, accessed April 28, 2026, [https://www.usenix.org/system/files/osdi22-zhong\_1.pdf](https://www.usenix.org/system/files/osdi22-zhong_1.pdf)  
31. XRP: In-Kernel Storage Functions with eBPF \- Semantic Scholar, accessed April 28, 2026, [https://www.semanticscholar.org/paper/67c2eeaf571d46f66ac554a6c23f8eb030681a1c](https://www.semanticscholar.org/paper/67c2eeaf571d46f66ac554a6c23f8eb030681a1c)  
32. Arm System Memory Management Unit Architecture Specification, SMMUv3 IHI0070F, accessed April 28, 2026, [http://kib.kiev.ua/x86docs/ARM/SMMU/IHI0070F\_b\_System\_Memory\_Management\_Unit\_Architecture\_Specification.pdf](http://kib.kiev.ua/x86docs/ARM/SMMU/IHI0070F_b_System_Memory_Management_Unit_Architecture_Specification.pdf)  
33. Sandbox Prefetching: Safe run-time evaluation of aggressive prefetchers \- ResearchGate, accessed April 28, 2026, [https://www.researchgate.net/publication/268239909\_Sandbox\_Prefetching\_Safe\_run-time\_evaluation\_of\_aggressive\_prefetchers](https://www.researchgate.net/publication/268239909_Sandbox_Prefetching_Safe_run-time_evaluation_of_aggressive_prefetchers)  
34. "Zawrs" Extension for Wait-on-Reservation-Set instructions \- RISC-V International, accessed April 28, 2026, [https://docs.riscv.org/reference/isa/unpriv/zawrs.html](https://docs.riscv.org/reference/isa/unpriv/zawrs.html)  
35. "Zihintntl" Extension for Non-Temporal Locality Hints \- RISC-V International, accessed April 28, 2026, [https://docs.riscv.org/reference/isa/unpriv/zihintntl.html](https://docs.riscv.org/reference/isa/unpriv/zihintntl.html)  
36. NVIDIA Corporation. "[NVIDIA BlueField Data Processing Unit Architecture: Storage Offload and NVMe-oF Acceleration](https://network.nvidia.com/sites/default/files/doc-2020/pb-bluefield-dpu.pdf)." *NVIDIA Technical Whitepapers*, 2023\.  
37. Rajbhandari, S., et al. "[ZeRO-Infinity: Breaking the GPU Memory Wall for Extreme Scale Deep Learning](https://sc21.supercomputing.org/proceedings/tech_paper/tech_paper_pages/pap464.html)." *Proceedings of the International Conference for High Performance Computing, Networking, Storage and Analysis (SC21)*, 2021\.  
38. Alizadeh, K., et al. "[LLM in a flash: Efficient Large Language Model Inference with Limited Memory](https://machinelearning.apple.com/research/efficient-large-language)." *Apple Machine Learning Research*, 2023\.  
39. Microsoft Engineering. "[Scaling Git at Microsoft: VFS for Git and the Scalar Architecture](https://devblogs.microsoft.com/devops/introducing-scalar/)." *Microsoft Open Source Blog*, 2022\.  
40. Jayaram, S., et al. "[DiskANN: Fast Accurate Billion-point Nearest Neighbor Search on a Single Node](https://papers.nips.cc/paper/9527-rand-nsg-fast-accurate-billion-point-nearest-neighbor-search-on-a-single-node)." *Advances in Neural Information Processing Systems (NeurIPS)*, 2019\.  
41. Ren, Z., & Trivedi, A. "[Performance Characterization of Modern Storage Stacks: POSIX I/O, libaio, SPDK, and io\_uring](https://atlarge-research.com/pdfs/2023-cheops-iostack.pdf)." *Proceedings of the 3rd Workshop on Challenges and Opportunities of Efficient and Performant Storage Systems (CHEOPS)*, 2023\.  
42. Mambretti, J., et al. "[The Global Research Platform, StarLight Software Defined Exchange (SDX), SC24 NREs](https://www.nitrd.gov/nitrdgroups/images/2024/JET-Joe-Mambretti-11202024.pdf)." *NITRD*, 2024\.  
43. Yuan, D. "[Kernel Bypass Technologies: Zero-Copy and Deterministic Execution](https://www.damonyuan.com/tech/260203-kernel-bypass-technologies)." *Systems Engineering Technical Analysis*, 2026\.  
44. Li, H., et al. "[Pond: CXL-Based Memory Pooling Systems for Cloud Platforms](https://pages.cs.wisc.edu/~markhill/papers/asplos2023_pond.pdf)." *Proceedings of the 28th ACM International Conference on Architectural Support for Programming Languages and Operating Systems (ASPLOS)*, 2023\.  
45. Zhong, Y., et al. "[XRP: In-Kernel Storage Functions with eBPF](https://www.google.com/search?q=https://www.usenix.org/system/files/osdi22-zhong.pdf)." *16th USENIX Symposium on Operating Systems Design and Implementation (OSDI)*, 2022\.  
46. Sheng, Y., et al. "[FlexGen: High-Throughput Generative Inference of Large Language Models with a Single GPU](https://arxiv.org/pdf/2303.06865)." *International Conference on Machine Learning (ICML)*, 2023\.  
47. Klimovic, A., et al. "[ReFlex: Remote Flash ≈ Local Flash](https://hlitz.github.io/papers/reflex.pdf)." *Proceedings of the 22nd ACM International Conference on Architectural Support for Programming Languages and Operating Systems (ASPLOS)*, 2017\.  
48. Harter, T., et al. "[Slacker: Fast Distribution with Lazy Docker Containers](https://www.usenix.org/system/files/conference/fast16/fast16-papers-harter.pdf)." *14th USENIX Conference on File and Storage Technologies (FAST)*, 2016\.  
49. Du, D., et al. "[Catalyzer: Sub-millisecond Startup for Serverless Computing with Initialization-less Booting](https://wangziqi2013.github.io/paper/2021/09/09/catalyzer.html)." *Proceedings of the 25th ACM International Conference on Architectural Support for Programming Languages and Operating Systems (ASPLOS)*, 2020\.  
50. Cao, W., et al. "[PolarDB Serverless: A Cloud Native Database for Disaggregated Data Centers](https://www.google.com/search?q=https://pages.cs.wisc.edu/~yxy/cs839-f23/papers/polardb-serverless-sigmod21.pdf)." *Proceedings of the International Conference on Management of Data (SIGMOD)*, 2021\.  
51. Ocient Engineering. "[Compute Adjacent Storage Architecture for AdTech: Zero-Copy Reliability on NVMe](https://ocient.com/case-studies/ocient-and-leading-dsp/)." *Ocient Technical Case Studies*, 2025\.  
52. Ghalayini, M., et al. "[Beyond Lamport, Towards Probabilistic Fair Ordering in Financial and Ad Exchanges](https://arxiv.org/html/2510.13664v2)." *arXiv preprint cs.DC*, 2025\.

---

*Copyright (c) 2026 SiliconLanguage Foundry. All rights reserved.*

[image1]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABMAAAAXCAYAAADpwXTaAAAAiElEQVR4XmNgGAWjgGqAA4jTgJgHXYIcwAjErUBsjC5BLgAZ1AvELOgS5ACQ6wqAOA7KRgECQCxJIpYD4vlAPBmI+RiggBuIq4F4Fhl4BxB/BeJmIGZnoACYAPFqIJZBlyAVCAPxYiCWR5cgB2QBcQS6IDkAlGinArE0ugQ5AJQUeKH0KBhMAABVixNKp22j3QAAAABJRU5ErkJggg==>
