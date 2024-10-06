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

# 创建日志目录
mkdir -p logs

# 安装必要的依赖
apt-get update
apt-get install -y nodejs npm software-properties-common git python3-venv python3-pip python3-full

# 创建虚拟环境
python3 -m venv venv
source venv/bin/activate

# 更新 pip 并安装依赖
pip install --upgrade pip
pip install requests pysui

# 检查 sui_meta_miner 目录是否存在
if [ ! -d "sui_meta_miner" ]; then
    git clone https://github.com/suidouble/sui_meta_miner.git
fi

cd sui_meta_miner
npm install
SUI_META_MINER_DIR=$(pwd)

# 定义一个函数来启动挖矿进程
start_mining() {
    cd "$SUI_META_MINER_DIR"
    nohup node mine.js --fomo --chain=mainnet --phrase="$SECRET_PHRASE" > "$INITIAL_DIR/logs/mining_$(date +%Y%m%d_%H%M%S).log" 2>&1 &
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
    echo "挖矿进程已启动，日志保存在 logs/mining_$(date +%Y%m%d_%H%M%S).log"

    # 等待一小时
    sleep 3600

    # 停止挖矿
    stop_mining
    echo "挖矿进程已停止"

    # 运行 mc.py
    "$INITIAL_DIR/venv/bin/python3" "$INITIAL_DIR/mc.py" "$WALLET_ADDRESS" > "$INITIAL_DIR/logs/mc_$(date +%Y%m%d_%H%M%S).log" 2>&1
    echo "mc.py 已执行完毕，日志保存在 logs/mc_$(date +%Y%m%d_%H%M%S).log"

    # 短暂暂停以确保所有进程都已正确结束
    sleep 5
done

# 退出虚拟环境
deactivate
