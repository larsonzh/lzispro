# lzispro
Multi process parallel acquisition tool for IP address data of ISP network operators in China

中国区 ISP 网络运营商 IP 地址数据多进程并行处理批量获取工具

*哈哈，牛逼玩意儿 ！！！*

**v1.0.2**

工具采用 Shell 脚本编写，参考并借鉴 clangcn（ https://github.com/clangcn/everyday-update-cn-isp-ip.git ）项目代码和思路，通过多进程并行处理技术，对信息检索和数据写入过程进行优化，极大提高 ISP 运营商分项地址数据生成效率，减少运行时间。在提供 IPv4 数据获取的同时，增加 IPv6 数据获取功能，以及基于 CIDR 网段聚合算法的 IPv4/6 CIDR 地址数据的生成功能。

本产品同时也是本人单进程的 lzispcn 项目（ https://github.com/larsonzh/lzispcn.git ）的多进程版本。

脚本在 Linux 环境下使用，运行平台包括：Ubuntu，CentOS，Deepin，ASUSWRT-Merlin，OpenWrt，......

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

# 一、安装支撑软件

脚本使用前最好将所在系统升级到最新版本，同时要在系统中联网安装脚本执行时必须依赖的软件模块：whois，wget

- Ubuntu | Deepin

```markdown
  sudo apt update
  sudo apt install whois
```

- CentOS

```markdown
  sudo yum update
  sudo yum install whois
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

# 二、安装项目脚本

1. 下载本工具的软件压缩包 lzsipcn-[version ID].tgz（例如：lzispro-v1.0.2.tgz）。

2. 将压缩包复制到设备的任意有读写权限的目录。

3. 在 Shell 终端中使用解压缩命令在当前目录中解压缩，生成 lzispro-[version ID] 目录（例如：lzispro-v1.0.2），其中包含一个 lzispro 目录，是脚本所在目录。

```markdown
  tar -xzvf lzispro-[version ID].tgz
```

4. 将 lzispro 目录整体复制粘贴到设备中有读写运行权限的目录位置存储。

5. 在 lzispro 目录中，lzispro.sh 为本工具的可执行脚本，若读写运行权限不足，手工赋予 755 以上即可。

# 三、脚本运行命令

```markdown
  假设当前位于 lzispro 目录
  启动脚本         ./lzispro.sh
  强制停止         ./lzispro.sh stop
```

1. 通过 Shell 终端启动脚本后，在操作过程中不要关闭终端窗口，这会导致程序执行过程意外中断。

2. 主脚本在系统中只能有一个实例进程运行。若上次运行过程中非正常退出，再次运行如果提示有另一个实例正在运行，在确认系统中本脚本确实没有实例正在运行后，可以执行「强制停止」命令或重启系统，然后再执行「启动脚本」命令。由于采用多进程并行处理机制，一旦工作过程被打断，或强制关闭后，为避免残余进程还在后台运行，请执行一次「强制停止」命令，以清理脚本非正常退出后遗留的临时数据，同时关闭垃圾进程。

3. 进行 ISP 运营商分项数据归类时，脚本需要通过互联网访问 APNIC 做海量信息查询，可能要耗费一、两个小时以上时间。切勿中断此执行过程，并耐心等候。

4. 若要减少 ISP 运营商分项数据归类处理时间，可根据设备硬件平台性能，在不影响设备正常使用的前提下，酌情并适可而止的修改查询 ISP 信息归类数据的「并行查询处理多进程数量 PARA_QUERY_PROC_NUM」参数，取值越大，效率越高，用时越短。例如，从缺省的 4 进程，提高到 8 进程，16 进程，甚至 64 进程，效率可能获得翻倍，或数倍提高，大大降低程序运行时间，改善应用体验。

# 四、目录结构

在项目目录 lzispro 下，脚本为获取和生成的每类文本形式的数据设有独立的存储目录，在程序执行完成后，从这些目录中可获取所需数据。用户也可以根据需要，在脚本参数配置时修改最终输出的目录名称、路径，以及具体的数据文件名称。

```markdown
  [lzispro]
    [func]
      lzispdata.sh  -- 子进程脚本
    [apnic]         -- APNIC 的 IP 信息数据
    [isp]           -- IPv4 原始地址数据
    [cidr]          -- IPv4 CIDR 地址数据
    [ipv6]          -- IPv6 原始地址数据
    [cidr_ipv6]     -- IPv6 CIDR 地址数据
    [tmp]           -- 运行中的临时数据
    lzispro.sh      -- 主进程脚本
```

# 五、参数配置

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

# 运行效果图

华硕 GT-AX6000 梅林固件路由器，四核心 ARM CPU，主频 2.0 MHz，脚本「并行查询处理多进程数量」参数设置为：PARA_QUERY_PROC_NUM="48"。实际用时从单进程的两个多小时减少到 10 分钟以下。并行查询处理多进程同时运行时，CPU 四个内核的资源占用率均在 60 ~ 70 % 之间，路由器网络内外之间均保持畅通。

![lzispro_asuswrt-merlin](https://user-images.githubusercontent.com/73221087/231459621-1431b97e-6ac3-4703-8812-18d36805d6ef.jpg)

使用 64 个查询处理进程，OpenWrt 跑疯了，不可思议！

![lzispro_op](https://user-images.githubusercontent.com/73221087/230794508-b896d8b1-ff2b-47ea-8505-ff689c0648ff.png)

