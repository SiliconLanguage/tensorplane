#cloud-config
# Note: Hugepages (2MB) are strictly required for zero-copy DMA.
# LSE atomics in GCC 11+ are vital for lock-free SQ/CQ polling.
packages:
  - gcc-11
  - g++-11
  - liburing-dev
  - pkg-config
  - python3-pip
runcmd:
  - curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  - echo 1024 > /sys/kernel/mm/hugepages/hugepages-2048kB/nr_hugepages
  - mkdir -p /mnt/huge && mount -t hugetlbfs nodev /mnt/huge
  - modprobe vfio-pci && chmod 666 /dev/vfio/vfio
  - echo "vm.nr_hugepages=1024" >> /etc/sysctl.conf
