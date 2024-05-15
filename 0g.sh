#!/bin/bash

# 检查是否以root用户运行脚本
if [ "$(id -u)" != "0" ]; then
    echo "此脚本需要以root用户权限运行。"
    echo "请尝试使用 'sudo -i' 命令切换到root用户，然后再次运行此脚本。"
    exit 1
fi

# 配置参数功能
function set_info() {
    # 检查 ~/.bashrc 是否存在，如果不存在则创建
    if [ ! -f ~/.bashrc ]; then
        touch ~/.bashrc
    fi
    echo "接下来请确认是否成功查询出钱包地址和验证者地址，如果没有正确输出两个地址 请重新执行一遍配置参数功能获取地址"
    read -p "请输入创建节点时的密码: " new_pwd

    # 检查 ~/.bashrc 中是否已存在 0g_pwd，如果存在则替换为新密码，如果不存在则追加
    if grep -q '^0g_pwd=' ~/.bashrc; then
    sed -i "s|^0g_pwd=.*$|0g_pwd=$new_pwd|" ~/.bashrc
    else
    echo "0g_pwd=$new_pwd" >> ~/.bashrc
    fi

    # 输入钱包名
    read -p "请输入钱包名: " wallet_name

    # 检查 ~/.bashrc 中是否已存在 0g_wallet，如果存在则替换为新钱包名，如果不存在则追加
    if grep -q '^0g_wallet=' ~/.bashrc; then
    sed -i "s|^0g_wallet=.*$|0g_wallet=$wallet_name|" ~/.bashrc
    else
    echo "0g_wallet=$wallet_name" >> ~/.bashrc
    fi

    echo "正在查询钱包地址"
    # 检查 ~/.bashrc 中是否已存在 0g_address，如果存在则替换为新地址，如果不存在则追加
    if grep -q '^0g_address=' ~/.bashrc; then
        # 执行命令，并将输出赋值给变量shg_address
        shg_address=$(0gchaind keys show $wallet_name -a)
        sed -i "s|^0g_address=.*$|0g_address=$shg_address|" ~/.bashrc
        echo "钱包地址为: $shg_address"
    else
        echo "0g_address=$shg_address" >> ~/.bashrc
        echo "钱包地址为: $shg_address"
    fi

    # 输入验证者名字
    read -p "请输入验证者名字: " validator_name

    # 检查 ~/.bashrc 中是否已存在 0g_validator_name，如果存在则替换为新钱包名，如果不存在则追加
    if grep -q '^0g_validator_name=' ~/.bashrc; then
    sed -i "s|^0g_validator_name=.*$|0g_validator_name=$validator_name|" ~/.bashrc
    else
    echo "0g_validator_name=$validator_name" >> ~/.bashrc
    fi

    echo "正在查询验证者地址"
    # 检查 ~/.bashrc 中是否已存在 0g_validator
    if grep -q '^0g_validator=' ~/.bashrc; then
        shg_validator=$(0gchaind keys show $wallet_name --bech val -a)
        sed -i "s|^0g_validator=.*$|0g_validator=$shg_validator|" ~/.bashrc
        echo "验证者地址为: $shg_validator"
    else
        shg_validator=$(0gchaind keys show $wallet_name --bech val -a)
        echo "0g_validator=$shg_validator" >> ~/.bashrc
        echo "验证者地址为: $shg_validator"
    fi

  echo "参数已设置成功，并写入到 ~/.bashrc 文件中"

  read -p "按回车键返回主菜单"

  # 返回主菜单
  main_menu
}

# 查询钱包列表功能
function check_wallet() {
    echo "正在查询中，请稍等"
    0gchaind keys list

    read -p "按回车键返回主菜单"

     # 返回主菜单
    main_menu
}

# 检查并安装 Node.js 和 npm
function install_nodejs_and_npm() {
    if command -v node > /dev/null 2>&1; then
        echo "Node.js 已安装"
    else
        echo "Node.js 未安装，正在安装..."
        curl -fsSL https://deb.nodesource.com/setup_16.x | sudo -E bash -
        sudo apt-get install -y nodejs
    fi

    if command -v npm > /dev/null 2>&1; then
        echo "npm 已安装"
    else
        echo "npm 未安装，正在安装..."
        sudo apt-get install -y npm
    fi
}

# 检查并安装 PM2
function install_pm2() {
    if command -v pm2 > /dev/null 2>&1; then
        echo "PM2 已安装"
    else
        echo "PM2 未安装，正在安装..."
        npm install pm2@latest -g
    fi
}

# 检查Go环境
function check_go_installation() {
    if command -v go > /dev/null 2>&1; then
        echo "Go 环境已安装"
        return 0
    else
        echo "Go 环境未安装，正在安装..."
        return 1
    fi
}

# 节点安装功能
function install_node() {

    install_nodejs_and_npm
    install_pm2

    # 检查curl是否安装，如果没有则安装
    if ! command -v curl > /dev/null; then
        sudo apt update && sudo apt install curl git -y
    fi

    # 更新和安装必要的软件
    sudo apt update && sudo apt upgrade -y
    sudo apt install curl git wget htop tmux build-essential jq make lz4 gcc unzip liblz4-tool -y

    # 安装 Go
    if ! check_go_installation; then
        sudo rm -rf /usr/local/go
        curl -L https://go.dev/dl/go1.22.0.linux-amd64.tar.gz | sudo tar -xzf - -C /usr/local
        echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> $HOME/.bash_profile
        source $HOME/.bash_profile
        go version
    fi

    # 安装所有二进制文件
    git clone -b v0.1.0 https://github.com/0glabs/0g-chain.git
    cd 0g-chain
    make install

    # 配置0gchaind
    export MONIKER="My_Node"
    export WALLET_NAME="wallet"

    # 获取初始文件和地址簿
    cd $HOME
    0gchaind init $MONIKER --chain-id zgtendermint_16600-1
    0gchaind config chain-id zgtendermint_16600-1
    0gchaind config node tcp://localhost:26657


    # 配置节点
    wget -O ~/.0gchain/config/genesis.json https://github.com/0glabs/0g-chain/releases/download/v0.1.0/genesis.json
    0gchaind validate-genesis
    wget https://smeby.fun/0gchaind-addrbook.json -O $HOME/.0gchain/config/addrbook.json

    # 配置节点
    SEEDS="31e5b7a44cfffc25ff9f4c1a7ae51fa1782a5970@121.37.192.245:26656,c4d619f6088cb0b24b4ab43a0510bf9251ab5d7f@54.241.167.190:26656,44d11d4ba92a01b520923f51632d2450984d5886@54.176.175.48:26656,f2693dd86766b5bf8fd6ab87e2e970d564d20aff@54.193.250.204:26656,f878d40c538c8c23653a5b70f615f8dccec6fb9f@54.215.187.94:26656"
    PEERS="f29bfef196ca62751a9c0d0b4bcd823254a43b88@138.201.221.84:26656,75a398f9e3a7d24c6b3ba4ab71bf30cd59faee5c@95.216.42.217:26656,5a202fb905f20f96d8ff0726f0c0756d17cf23d8@43.248.98.100:26656,9d88e34a436ec1b50155175bc6eba89e7a1f0e9a@213.199.61.18:26656,2b8ee12f4f94ebc337af94dbec07de6f029a24e6@94.16.31.161:26656,52e30a030ff6ded32e7a499de6246c574f57cc27@152.53.32.51:26656,a8d7c5a051c4649ba7e267c94e48a7c64a00f0eb@65.108.127.146:26656,8f463ad676c2ea97f88a1274cdcb9f155522fd49@209.126.8.121:26657,bcfbafecc407b1cfd7737a172adda535580c62ed@62.169.19.5:26656,a8d7c5a051c4649ba7e267c94e48a7c64a00f0eb@65.108.127.146:26656,8f463ad676c2ea97f88a1274cdcb9f155522fd49@209.126.8.121:26657,75a398f9e3a7d24c6b3ba4ab71bf30cd59faee5c@95.216.42.217:26656,5a202fb905f20f96d8ff0726f0c0756d17cf23d8@43.248.98.100:26656,9d88e34a436ec1b50155175bc6eba89e7a1f0e9a@213.199.61.18:26656,2b8ee12f4f94ebc337af94dbec07de6f029a24e6@94.16.31.161:26656,52e30a030ff6ded32e7a499de6246c574f57cc27@152.53.32.51:26656,8f463ad676c2ea97f88a1274cdcb9f155522fd49@209.126.8.121:26657,bcfbafecc407b1cfd7737a172adda535580c62ed@62.169.19.5:26656,30f35c4bd9d78a05257413cf8151e9a7d33a3d43@84.247.154.58:26656"
    sed -i "s/persistent_peers = \"\"/persistent_peers = \"$PEERS\"/" $HOME/.0gchain/config/config.toml
    sed -i "s/seeds = \"\"/seeds = \"$SEEDS\"/" $HOME/.0gchain/config/config.toml

    #  配置端口
    node_address="tcp://localhost:13457"
    sed -i -e "s%^proxy_app = \"tcp://127.0.0.1:26658\"%proxy_app = \"tcp://127.0.0.1:13458\"%; s%^laddr = \"tcp://127.0.0.1:26657\"%laddr = \"tcp://127.0.0.1:13457\"%; s%^pprof_laddr = \"localhost:6060\"%pprof_laddr = \"localhost:13460\"%; s%^laddr = \"tcp://0.0.0.0:26656\"%laddr = \"tcp://0.0.0.0:13456\"%; s%^prometheus_listen_addr = \":26660\"%prometheus_listen_addr = \":13466\"%" $HOME/.0gchain/config/config.toml
    sed -i -e "s%^address = \"tcp://localhost:1317\"%address = \"tcp://0.0.0.0:13417\"%; s%^address = \":8080\"%address = \":13480\"%; s%^address = \"localhost:9090\"%address = \"0.0.0.0:13490\"%; s%^address = \"localhost:9091\"%address = \"0.0.0.0:13491\"%; s%:8545%:13445%; s%:8546%:13446%; s%:6065%:13465%" $HOME/.0gchain/config/app.toml
    echo "export OG_RPC_PORT=$node_address" >> $HOME/.bash_profile
    source $HOME/.bash_profile
    # 使用 PM2 启动节点进程
    pm2 start 0gchaind -- start && pm2 save && pm2 startup
    
    pm2 stop 0gchaind
    SNAP_NAME=$(curl -s https://testnet.anatolianteam.com/0g/ | egrep -o ">zgtendermint_16600-1.*\.tar.lz4" | tr -d ">")
    curl -L https://testnet.anatolianteam.com/0g/${SNAP_NAME} | tar -I lz4 -xf - -C $HOME/.0gchain
    mv $HOME/.0gchain/priv_validator_state.json.backup $HOME/.0gchain/data/priv_validator_state.json 

    pm2 restart 0gchaind

}

# 查看0gai 服务状态
function check_service_status() {
    pm2 list
}

# 0gai 验证节点日志查询
function view_logs() {
    pm2 logs 0gchaind
}

# 0gai 重启验证节点
function restart_node() {
    pm2 restart 0gchaind
echo '====================== 已重启验证节点，请通过查询验证节点日志功能或者pm2 logs 0gchaind查询 ==========================='
}

# 0gai 重启存储节点
function restart_storage(){

    cd 0g-storage-node/run
    screen -X -S zgs_node_session quit
    screen -dmS zgs_node_session ../target/release/zgs_node --config config.toml
echo '====================== 已重启存储节点，请通过screen -r zgs_node_session 查询 ==========================='
}

# 创建钱包
function add_wallet() {
    read -p "请输入钱包名: " wallet_name
    0gchaind keys add $wallet_name --eth
}

# 导入钱包
function import_wallet() {
    read -p "请输入钱包名: " wallet_name
    0gchaind keys add $wallet_name --recover --eth
}

# 查询余额
function check_balances() {
    wallet_address=$(grep '^0g_address=' ~/.bashrc | cut -d '=' -f 2)
    0gchaind query bank balances "$wallet_address"
}

# 查看节点同步状态
function check_sync_status() {
    0gchaind status 2>&1 | jq .sync_info
}


# 创建验证者
function add_validator() {

echo "正在创建验证者，请稍等······"
wallet_name=$(grep '^0g_wallet=' ~/.bashrc | cut -d '=' -f 2)
validator_name=$(grep '^0g_validator_name=' ~/.bashrc | cut -d '=' -f 2)

0gchaind tx staking create-validator \
  --amount=1000000ua0gi \
  --pubkey=$(0gchaind tendermint show-validator) \
  --moniker=$validator_name \
  --chain-id=zgtendermint_16600-1 \
  --commission-rate=0.05 \
  --commission-max-rate=0.10 \
  --commission-max-change-rate=0.01 \
  --min-self-delegation=1 \
  --from=$wallet_name \
  --identity="" \
  --website="" \
  --details="" \
  --gas=auto \
  --gas-adjustment=1.4
}

function install_storage_node() {

    sudo apt-get update
    sudo apt-get install clang cmake build-essential git screen cargo -y


# 安装Go
    sudo rm -rf /usr/local/go
    curl -L https://go.dev/dl/go1.22.0.linux-amd64.tar.gz | sudo tar -xzf - -C /usr/local
    echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> $HOME/.bash_profile
    export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin
    source $HOME/.bash_profile


# 克隆仓库
git clone https://github.com/0glabs/0g-storage-node.git

#进入对应目录构建
cd 0g-storage-node
git submodule update --init

# 构建代码
cargo build --release

#后台运行
cd run


read -p "请输入EVM钱包私钥(不要有0x): " minerkey

sed -i "s/miner_id = \"\"/miner_id = \"$(openssl rand -hex 32)\"/" config.toml
sed -i "s/miner_key = \"\"/miner_key = \"$minerkey\"/" config.toml




screen -dmS zgs_node_session ../target/release/zgs_node --config config.toml

echo '====================== 安装完成 ==========================='
echo '===进入对应路径:/0g-storage-node/run/log，使用tail -f logs文件名，查看logs 即可========================'

}


function install_storage_kv() {

# 克隆仓库
git clone https://github.com/0glabs/0g-storage-kv.git


#进入对应目录构建
cd 0g-storage-kv
git submodule update --init

# 构建代码
cargo build --release

#后台运行
cd run

echo "请输入RPC节点信息: "
read blockchain_rpc_endpoint


cat > config.toml <<EOF
stream_ids = ["000000000000000000000000000000000000000000000000000000000000f2bd", "000000000000000000000000000000000000000000000000000000000000f009", "00000000000000000000000000"]

db_dir = "db"
kv_db_dir = "kv.DB"

rpc_enabled = true
rpc_listen_address = "127.0.0.1:6789"
zgs_node_urls = "http://127.0.0.1:5678"

log_config_file = "log_config"

blockchain_rpc_endpoint = "$blockchain_rpc_endpoint"
log_contract_address = "0x22C1CaF8cbb671F220789184fda68BfD7eaA2eE1"
log_sync_start_block_number = 670000

EOF

echo "成功更新配置文件"
screen -dmS storage_kv ../target/release/zgs_kv --config config.toml

}

# 质押
function delegate() {
read -p "请输入质押数量(按照脚本查询余额的数量格式填写，单位为ua0gai): " math
read -p "请输入钱包名: " wallet_name
0gchaind tx staking delegate $(0gchaind keys show $wallet_name --bech val -a)  ${math}ua0gi --from $wallet_name   --gas=auto --gas-adjustment=1.4 -y

}

# 查看存储节点同步状态
function check_storage_status() {
    tail -f "$(find ~/0g-storage-node/run/log/ -type f -printf '%T+ %p\n' | sort -r | head -n 1 | cut -d' ' -f2-)"
}

# 查看存储节点同步状态
function start_storage() {
cd 0g-storage-node/run && screen -dmS zgs_node_session ../target/release/zgs_node --config config.toml
echo '====================== 启动成功，请通过screen -r zgs_node_session 查询 ==========================='

}

# 转换ETH地址
function evm_address() {

    wallet_name=$(grep '^0g_wallet=' ~/.bashrc | cut -d '=' -f 2)
    echo "0x$(0gchaind debug addr $(0gchaind keys show $wallet_name -a) | grep hex | awk '{print $3}')"

}

# 卸载验证节点功能
function uninstall_node() {
    echo "开始卸载节点程序..."
    pm2 stop 0gchaind
    pm2 delete 0gchaind
    rm -rf $HOME/.0gchain $HOME/0gchain $(which 0gchaind) 0g-chain
    echo "节点程序卸载完成。"
}

# 卸载旧版本节点功能
function uninstall_old() {

            echo "正在卸载上一期测试网节点..."
            pm2 stop evmosd && pm2 delete evmosd
            rm -rf $HOME/.evmosd $HOME/evmos $(which evmosd) && rm -rf 0g-evmos
            echo "卸载完成"
}

# 安装expect（暂未实现）
function install() {
    sudo apt-get update
    sudo apt-get install -y expect
    sudo apt install screen

    echo "==============================模块安装完成=============================="

    read -p "按回车键返回主菜单"

  # 返回主菜单
  main_menu
}

function walletlist() {
    0gchaind keys list
}

# 自动委托功能（暂未实现）
function delegate_staking() {

  # 获取密码和钱包名
  local art_pwd art_wallet
  art_pwd=$(grep -oP 'art_pwd=\K.*' ~/.bashrc)
  art_wallet=$(grep -oP 'art_wallet=\K.*' ~/.bashrc)
  art_address=$(grep -oP 'art_address=\K.*' ~/.bashrc)
  art_validator=$(grep -oP 'art_validator=\K.*' ~/.bashrc)
  art_amount=$(grep -oP 'art_amount=\K.*' ~/.bashrc)

  # 获取 art.sh 脚本
  wget -O art.sh https://raw.githubusercontent.com/run-node/Artela-node/main/art.sh && chmod +x art.sh

    # 获取密码并替换 art.sh 中的占位符
    sed -i "s|\$pwd|$art_pwd|g" art.sh

    # 获取钱包名并替换 art.sh 中的占位符
    sed -i "s|\$wallet|$art_wallet|g" art.sh

    # 获取质押数量并替换 art.sh 中的占位符
    sed -i "s|\$amount|$art_amount|g" art.sh

    # 获取钱包地址并替换 art.sh 中的占位符
    sed -i "s|\$address|$art_address|g" art.sh

    # 获取验证者地址并替换 art.sh 中的占位符
    sed -i "s|\$validator|$art_validator|g" art.sh

  # 检查并关闭已存在的 screen 会话
  if screen -list | grep -q delegate; then
    screen -S delegate -X quit
    echo "正在关闭之前设置的自动质押······"
  fi

  # 创建一个screen会话并运行命令
  screen -dmS delegate bash -c './art.sh'
  echo "===========自动质押已开启；每隔1~5小时自动质押(保证交互时间不一致)==========="
  read -p "按回车键返回主菜单"
  # 返回主菜单
  main_menu
}


# 主菜单
function main_menu() {
    while true; do
        clear
        echo "========================自用脚本 盗者必究========================="
        echo "需要测试网节点部署托管 技术指导 定制脚本 请联系Telegram :https://t.me/linzeusasa"
        echo "需要测试网节点部署托管 技术指导 定制脚本 请联系Wechat :llkkxx001"
        echo "===================0G.AI最新测试网节点一键部署===================="
        echo "创建好验证者后请填写表单申请资格 https://docs.google.com/forms/d/e/1FAIpQLScsa1lpn43F7XAydVlKK_ItLGOkuz2fBmQaZjecDn76kysQsw/viewform"
        echo "首次安装请直接执行安装节点--钱包管理--配置参数--查询信息--创建验证者"
        echo "验证者哈希请前往官网获取 https://testnet.explorer.liveraven.net/zero-gravity/account"
        echo "请选择要执行的操作:"
        echo "1. 安装节点"
        echo "2. 钱包管理"
        echo "3. 配置参数"
        echo "4. 查询信息"
        echo "5. 创建验证者(等待高度同步上后再执行)"
        echo "6. 质押代币"
        echo "7. 重启节点"
        echo "8. 卸载节点"
        read -p "请输入选项（1-8）: " OPTION

        case $OPTION in
        1)
            echo "=========================安装节点菜单============================"
            echo "请选择要执行的操作:"
            echo "1. 安装验证节点"
            echo "2. 创建存储节点(新测试网未出)"
            read -p "请输入选项（1-2）: " NODE_OPTION
            case $NODE_OPTION in
            1) install_node ;;
            2) install_storage_node ;;
            *) echo "无效选项。" ;;
            esac
            ;;
        2)
            echo "=========================钱包管理菜单============================"
            echo "请选择要执行的操作:"
            echo "1. 创建钱包"
            echo "2. 导入钱包"
            echo "3. 钱包列表"
            read -p "请输入选项（1-2）: " WALLET_OPTION
            case $WALLET_OPTION in
            1) add_wallet ;;
            2) import_wallet ;;
            3) walletlist ;;
            *) echo "无效选项。" ;;
            esac
            ;;
        3)
            set_info ;;

        4)
            echo "=========================查询信息菜单============================"
            echo "请选择要执行的操作:"
            echo "1. 查看钱包地址余额"
            echo "2. 查询evm地址(请前往 https://faucet.0g.ai/ 领水)"
            echo "3. 查看节点同步状态"
            echo "4. 查看当前服务状态"
            echo "5. 查询验证节点日志"
            echo "6. 查看存储节点日志"
            read -p "请输入选项（1-6）: " INFO_OPTION
            case $INFO_OPTION in
            1) check_balances ;;
            2) evm_address ;;
            3) check_sync_status ;;
            4) check_service_status ;;
            5) view_logs ;;
            6) check_storage_status ;;
            *) echo "无效选项。" ;;
            esac
            ;;
        5)
            add_validator ;;
        6)
            delegate ;;
        7)
            echo "===========================重启节点=============================="
            echo "请选择要执行的操作:"
            echo "1. 重启验证节点"
            echo "2. 重启存储节点"
            read -p "请输入选项（1-2）: " RESTART_OPTION
            case $RESTART_OPTION in
            1) restart_node ;;
            2) restart_storage ;;
            *) echo "无效选项。" ;;
            esac
            ;;
        8)
            echo "=========================卸载节点菜单============================"
            echo "请选择要执行的操作:"
            echo "1. 卸载验证节点"
            echo "2. 卸载旧版验证节点"
            read -p "请输入选项（1-2）: " UNINSTALL_OPTION
            case $UNINSTALL_OPTION in
            1) uninstall_node ;;
            2) uninstall_old ;;
            *) echo "无效选项。" ;;
            esac
            ;;

        *) echo "无效选项。" ;;
        esac
        echo "按任意键返回主菜单..."
        read -n 1
    done
}

# 显示主菜单
main_menu
