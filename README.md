# lzispro
Multi process parallel acquisition tool for IP address data of ISP network operators in China

中国区 ISP 网络运营商 IP 地址数据多进程并行处理批量获取工具

*呵呵，妥妥的一个主机多进程网络性能，计算性能，读写性能测试工具！能以极致指标跑好这个脚本，才敢说有台好设备可以凑合用了。*

**v1.0.2**

工具采用 Shell 脚本编写，参考并借鉴 clangcn（ https://github.com/clangcn/everyday-update-cn-isp-ip.git ）项目代码和思路，通过多进程并行处理技术，对信息检索和数据写入过程进行优化，极大提高 ISP 运营商分项地址数据生成效率，减少运行时间。在提供 IPv4 数据获取的同时，增加 IPv6 数据获取功能，以及基于 CIDR 网段聚合算法的 IPv4/6 CIDR 地址数据的生成功能。

本产品同时也是本人单进程的 lzispcn 项目（ https://github.com/larsonzh/lzispcn.git ）的多进程版本。

脚本在 Linux 环境下使用，运行平台包括：Ubuntu，CentOS Stream，Rocky，Deepin，ASUSWRT-Merlin，OpenWrt，......

适用的 Shell 类型：sh，ash，dash，bash

# 功能
- 从 APNIC 下载最新 IP 信息数据。

- 从 APINC IP 信息数据中抽取出最新、最完整的中国大陆及港澳台地区所有 IPv4/6 原始地址数据。

- 采用多进程并行处理方式，向 APNIC 逐条查询中国大陆地区的 IPv4/6 原始地址数据，得到归属信息，生成能够包含中国大陆地区所有 IPv4/6 地址的 ISP 运营商分项数据。

- 通过 CIDR 聚合算法生成压缩过的 IPv4/6 CIDR 格式地址数据。

- 中国区 IPv4/6 地址数据：含 4 个地区分项和 7 个 ISP 运营商分项

    * 大陆地区

       - 中国电信

       - 中国联通/网通

       - 中国移动

       - 中国铁通

       - 中国教育网
 
       - 长城宽带/鹏博士

       - 中国大陆其他

  * 香港地区

  * 澳门地区

  * 台湾地区

# 安装及运行

## 一、安装支撑软件

脚本使用前最好将所在系统升级到最新版本，同时要在系统中联网安装脚本执行时必须依赖的软件模块：whois，wget

- Ubuntu | Deepin

```markdown
  sudo apt update
  sudo apt install whois
```

- CentOS Stream | Rocky

```markdown
  sudo dnf install -y epel-release
  sudo dnf update -y
  sudo dnf install -y gcc make perl kernel-devel kernel-headers bizp2 dkms whois
  sudo dnf update kernel-*
  sudo reboot
```

- ASUSWRT-Merlin

```markdown
  先安装 Entware 软件存储库：
  插入格式化为 ext4 格式的 USB 盘，键入
  系统自带的 amtm 命令，在终端菜单窗口中
  选择安装 Entware 到 USB 盘。
  opkg update
  opkg install whois
```

- OpenWrt

```markdown
  opkg update
  opkg install whois
  opkg install wget-ssl
```

其他 Linux 平台系统依此类推。

## 二、安装项目脚本

1. 下载本工具的软件压缩包 lzsipcn-[version ID].tgz（例如：lzispro-v1.0.2.tgz）。

2. 将压缩包复制到设备的任意有读写权限的目录。

3. 在 Shell 终端中使用解压缩命令在当前目录中解压缩，生成 lzispro-[version ID] 目录（例如：lzispro-v1.0.2），其中包含一个 lzispro 目录，是脚本所在目录。

```markdown
  tar -xzvf lzispro-[version ID].tgz
```

4. 将 lzispro 目录整体复制粘贴到设备中有读写运行权限的目录位置存储。

5. 在 lzispro 目录中，lzispro.sh 为本工具的可执行脚本，若读写运行权限不足，手工赋予 755 以上即可。

## 三、脚本运行命令

```markdown
  假设当前位于 lzispro 目录
  启动脚本         ./lzispro.sh
  强制停止         ./lzispro.sh stop
```

1. 通过 Shell 终端启动脚本后，在操作过程中不要关闭终端窗口，这会导致程序执行过程意外中断。

2. 主脚本在系统中只能有一个实例进程运行。若上次运行过程中非正常退出，再次运行如果提示有另一个实例正在运行，在确认系统中本脚本确实没有实例正在运行后，可以执行「强制停止」命令或重启系统，然后再执行「启动脚本」命令。由于采用多进程并行处理机制，一旦工作过程被打断，或强制关闭后，为避免残余进程还在后台运行，请执行一次「强制停止」命令，以清理脚本非正常退出后遗留的临时数据，同时关闭垃圾进程。

3. 进行 ISP 运营商分项数据归类时，脚本需要通过互联网访问 APNIC 做海量信息查询，可能要耗费一、两个小时以上时间。切勿中断此执行过程，并耐心等候。

4. 若要减少 ISP 运营商分项数据归类处理时间，可根据设备硬件平台性能，在不影响设备正常使用的前提下，酌情并适可而止的修改查询 ISP 信息归类数据的「并行查询处理多进程数量 PARA_QUERY_PROC_NUM」参数，取值越大，效率越高，用时越短。例如，从缺省的 4 进程，提高到 8 进程，16 进程，甚至 64 进程，效率可能获得翻倍，或数倍提高，大大降低程序运行时间，改善应用体验。

## 四、目录结构

在项目目录 lzispro 下，脚本为获取和生成的每类文本形式的数据设有独立的存储目录，在程序执行完成后，从这些目录中可获取所需数据。用户也可以根据需要，在脚本参数配置时修改最终输出的目录名称、路径，以及具体的数据文件名称。

```markdown
  [lzispro]
    [func]
      lzispdata.sh  -- ISP 数据进程脚本
    [apnic]         -- APNIC 的 IP 信息数据
    [isp]           -- IPv4 原始地址数据
    [cidr]          -- IPv4 CIDR 地址数据
    [ipv6]          -- IPv6 原始地址数据
    [cidr_ipv6]     -- IPv6 CIDR 地址数据
    [tmp]           -- 运行中的临时数据
    lzispro.sh      -- 主进程脚本
```

## 五、参数配置

lzispro.sh 脚本是本工具的主程序，可用文本编辑工具打开查看、修改其中的内容。
    
该代码的前部分有供用户自定义的变量参数，具体使用可参考内部注释。

```markdown
  项目目录
  目标数据文件名
  需要获取哪类数据
  并行查询处理多进程数量
  信息查询失败后的重试次数
  是否显示进度条
  系统日志文件定义
  ......
```

# 卸载

直接删除 lzispro 目录。

# 效果图

## ASUSWRT-Merlin

华硕 GT-AX6000 梅林固件路由器，四核心 ARM CPU，主频 2.0 MHz，脚本「并行查询处理多进程数量」参数设置为：PARA_QUERY_PROC_NUM="48"。实际用时从单进程的两个多小时减少到 10 分钟以下。并行查询处理多进程同时运行时，CPU 四个内核的资源占用率均在 60 ~ 70 % 之间，路由器网络内外之间均保持畅通。

![lzispro_asuswrt-merlin](https://user-images.githubusercontent.com/73221087/231459621-1431b97e-6ac3-4703-8812-18d36805d6ef.jpg)

## OpenWrt

使用 64 个查询处理进程，OpenWrt 跑疯了。这是在 VirtualBox 虚拟机里的软路由，主机系统 Windows 11，11 代 U 的笔记本电脑，无线连接路由器，平时看不出有啥性能，不可思议！

![lzispro_openwrt_64](https://user-images.githubusercontent.com/73221087/231570822-a8cc1445-5396-4dd6-8b62-a3250912541f.png)

能跑哈，再折腾下，128 个进程，行不？3 分钟半，大部分时间耗在 CIDR 聚合计算上，ISP 数据生成用时很少，若放到服务器上，效果更好。

![lzispro_openwrt_128](https://user-images.githubusercontent.com/73221087/231569234-b2c92800-8afb-4ada-9211-7f64176aa280.png)

## CentOS Stream

安装在 11 代 U 笔记本电脑 VirtualBox 虚拟机里的 Linux 服务器，配置 4 GB 内存和 4 个处理器。脚本「并行查询处理多进程数量」参数设置为：PARA_QUERY_PROC_NUM="128"，使用 128 个查询处理进程。

2 分钟 8 秒，太快了！

![lzispro_centos](https://user-images.githubusercontent.com/73221087/232160640-e03aa2bf-afa6-4a25-8bff-6f5e69c47ba8.jpg)

## Ubuntu

使用装在 VirtualBox 虚拟机里的 Ubuntu Server，还是 128 个查询进程，开启进度条显示，

过程中规中矩，扣除起始时快时慢的 APNIC IP 信息数据 FTP 下载时间，大多数时候没有 CentOS Stream、Rocky 快。虚拟机里还有 Ubuntu 桌面版和一个 Deepin 桌面版，跑起来总体上要比服务器版慢。

所有系统都升级到当前最新正式版本，除去两个 Linux 路由器专用系统，为表示公平，其他虚拟机中的 Linux 系统，内存、处理器、存储、网卡等均采用相同配置，都走中国移动的千兆宽带，运行中尽可能使用执行速度更快的 Shell 环境，如 sh、ash、dash，bash 比较臃肿，效率有些低，但也只在理论上，实际受其他影响，差别没想象的大。

几轮测试下来，最大影响因素还是网络。一般夜里，或凌晨前测试效果较好，白天时段较慢，肯定与业务繁忙程度、网络节点中继效率及国际出口拥堵状况有关，最好找我区绝大部分人类活动能力较弱的垃圾网络时间折腾。由于 APNIC 负责亚太地区网络地址，主机活跃时间与我兔作息或许较为接近，如此这般吗？我也仅是打酱油时无意间特么猜测，总有些不规矩的家伙要反人类时间加班加点忙活，搞得到处都是鸡毛。。。

![lzispro_ubuntu_srv](https://user-images.githubusercontent.com/73221087/232861999-617c2501-888c-4764-b10f-e0a59c9790be.png)

## Deepin

谁说国货不行，无意间又用 128 进程测了一下这个刚升级的桌面版系统，结果逆天，还特么怎么玩，一分多钟。。。

![lzispro_deepin](https://user-images.githubusercontent.com/73221087/232901131-7bcdc031-b14c-43f4-aac3-b207ef475d90.png)

## Ubuntu

最后用 Ubuntu 桌面版测了一下 128 个进程并行查询处理的情况，结果令人失望，比过去最快曾到过 2 分 51 秒慢的很多，有些离谱，可能此刻网络状况变差了。折腾一宿，感觉测的是网络状态，无语！

![lzispro_ubuntu](https://user-images.githubusercontent.com/73221087/232913271-92722e0a-1a65-42d0-9911-6ffd90c46e2b.png)
