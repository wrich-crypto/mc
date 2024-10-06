import time
import sys
from typing import List

import requests
from pysui import SuiConfig, handle_result
from pysui.sui.sui_clients.sync_client import SuiClient
from pysui.sui.sui_txn.sync_transaction import SuiTransaction

import warnings
warnings.filterwarnings("ignore", category=DeprecationWarning)

url = 'https://fullnode.mainnet.sui.io/'

def get_fomo_balance(addr):
    print(f"正在查询地址 {addr} 的 FOMO 余额...")
    payload = {"jsonrpc": "2.0", "id": 3, "method": "suix_getBalance",
               "params": [addr, "0xa340e3db1332c21f20f5c08bef0fa459e733575f9a7e2f5faca64f72cd5a54f2::fomo::FOMO"]}
    resp = requests.post(url, json=payload)
    data = resp.json()
    balance = data['result']['totalBalance']
    print(f'地址 {addr} 的 FOMO 余额: {balance}')
    return balance

def merge_coin(client, addr):
    print(f"开始为地址 {addr} 合并代币...")
    payload = {"jsonrpc": "2.0", "id": 16, "method": "suix_getCoins",
               "params": [addr, "0xa340e3db1332c21f20f5c08bef0fa459e733575f9a7e2f5faca64f72cd5a54f2::fomo::FOMO", None, None]}
    resp = requests.post(url, json=payload)
    try:
        if resp.status_code != 200:
            print(f'请求错误，重试中!')
            merge_coin(client, addr)
        else:
            print(f'resp:{resp.text}')
            data_json = resp.json()
            data, has_next_page, next_cursor = data_json['result']['data'], data_json['result']['hasNextPage'], data_json['result']['nextCursor']
            if len(data) <= 1:
                print(f'只找到一个代币，跳过合并')
                return

            need_merge = []
            first_object_id = data[0]['coinObjectId']
            for i in range(1, len(data)):
                need_merge.append(data[i]['coinObjectId'])

            print(f"将要合并 {len(need_merge)} 个代币对象到 {first_object_id}")
            _merge_coin(client, first_object_id, need_merge)

            if has_next_page:
                merge_coin(client, addr)
                time.sleep(1)
    except Exception as e:
        print(f"合并过程中发生错误: {e}")
        time.sleep(1)
        merge_coin(client, addr)

def _merge_coin(client, merge_to: str, merge_from_list: List[str]):
    print(f"正在执行合并操作,目标代币: {merge_to}")
    tx = SuiTransaction(client=client)
    try:
        tx.merge_coins(
            merge_from=merge_from_list,
            merge_to=merge_to
        )
    except Exception as e:
        print(f"创建合并交易时发生错误: {e}")
        time.sleep(1)

    try:
        result = tx.execute(gas_budget='2000000')
        print(f"原始结果类型: {type(result)}")
        
        if isinstance(result, dict):
            print(f"结果内容: {result}")
        elif hasattr(result, '__dict__'):
            print(f"结果属性: {result.__dict__}")
        else:
            print(f"结果字符串表示: {str(result)}")
        
        handled_result = handle_result(result)
        print(f'处理后的合并结果: {handled_result}')
    except Exception as e:
        print(f"执行合并交易时发生错误: {e}")

def main(private_key):
    cfg = SuiConfig.user_config(prv_keys=[private_key], rpc_url=url)
    client = SuiClient(cfg)

    address = cfg.active_address.address
    print(f"开始处理地址: {address}")

    fomo_balance = int(get_fomo_balance(address))
    print(f'地址的 FOMO 余额: {fomo_balance}')

    merge_coin(client, address)
    print(f'地址 {address} 合并完成!')

if __name__ == '__main__':
    if len(sys.argv) != 2:
        print("Usage: python mc.py <private_key>")
        sys.exit(1)
    
    private_key = sys.argv[1]
    main(private_key)
