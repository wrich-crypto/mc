#!/bin/bash

# 检查是否提供了必要的参数
if [ "$#" -ne 2 ]; then
    echo "使用方法: $0 <密钥短语> <钱包地址>"
    exit 1
fi

SECRET_PHRASE="$1"
WALLET_ADDRESS="$2"

# 记录初始目录
INITIAL_DIR=$(pwd)

# 安装必要的依赖
apt-get update
apt-get install -y nodejs npm software-properties-common git

# 安装 pip
apt-get install -y python3-pip

# 更新 pip 并安装依赖
python3 -m pip install --upgrade pip
python3 -m pip install requests pysui

# 克隆并设置 sui_meta_miner
git clone https://github.com/suidouble/sui_meta_miner.git
cd sui_meta_miner
npm install
SUI_META_MINER_DIR=$(pwd)

# 定义一个函数来启动挖矿进程
start_mining() {
    cd "$SUI_META_MINER_DIR"
    nohup node mine.js --fomo --chain=mainnet --phrase="$SECRET_PHRASE" > mining.log 2>&1 &
    echo $! > mining.pid
    cd "$INITIAL_DIR"
}

# 定义一个函数来停止挖矿进程
stop_mining() {
    if [ -f "$SUI_META_MINER_DIR/mining.pid" ]; then
        kill $(cat "$SUI_META_MINER_DIR/mining.pid")
        rm "$SUI_META_MINER_DIR/mining.pid"
    fi
}

# 主循环
while true; do
    # 启动挖矿
    start_mining
    echo "挖矿进程已启动"

    # 等待一小时
    sleep 3600

    # 停止挖矿
    stop_mining
    echo "挖矿进程已停止"

    # 运行 fomo.py
    python3 mc.py "$WALLET_ADDRESS"
    echo "mc.py 已执行完毕"

    # 短暂暂停以确保所有进程都已正确结束
    sleep 5
done
