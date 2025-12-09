# R2P2でHTTP/HTTPS通信を行う手順

このドキュメントは、PicoRubyで作成したプログラムをR2P2上で実行し、外部サーバーとHTTP/HTTPS通信するまでの手順をまとめたものです。

## 構成方針
- R2P2ファームウェアにネットワーク系gemを組み込む：`picoruby-net`（必要に応じて`picoruby-net-http`）、TLSが必要なら`picoruby-mbedtls`。
- ネットワークIFはボード依存。公式に含まれるドライバはQuectelセルラーモデム向け（下記参照）。Wi‑Fi/Ethernetを使う場合は対応ドライバをR2P2側に組み込む。
- POSIX版なら`bin/r2p2`で即動作確認できる。Pico版はR2P2公式リポジトリのPico向けビルド設定に上記gemを追加してビルドする。

## Raspberry Pi Pico 2 Wで同一LAN上HTTPアクセスする場合
- 必要gem: `picoruby-net`（HTTPクライアント）、`picoruby-cyw43`（Pico W内蔵Wi‑Fi）、HTTPSが要る場合は`picoruby-mbedtls`。
- ビルド時の定義: `USE_WIFI` を`cc.defines`へ入れる（`cyw43`の実装ガード）。
- ツールチェーン: Pico SDK 2.x（`PICO_BOARD=pico2w`対応）、arm-none-eabi-gcc、CMake、Python。
- R2P2（Pico版）リポジトリで`build_config/pico2w-net.rb`のような設定を用意し、上記gemを指定してビルド（UF2生成）→Pico 2 Wへドラッグ&ドロップで書き込み。
- 動作確認は同一ネットワーク内のSinatraサーバー（`bind '0.0.0.0'`で待ち受け）にアクセスする。

### Wi‑Fi接続＋HTTP GETサンプル（Pico 2 W）
SinatraサーバーのIP/ポートに置き換えて利用。

```ruby
require 'cyw43'
require 'net'

SSID = "YourSSID"
PASS = "YourPass"
HOST = "192.168.1.50" # SinatraサーバーのIP
PORT = 4567

# Wi‑Fi初期化と接続
raise "CYW43 init failed" unless CYW43.init("JP")
CYW43.enable_sta_mode
ok = CYW43.connect_timeout(SSID, PASS, CYW43::Auth::WPA2_AES_PSK, 15000)
raise "WiFi connect failed" unless ok
raise "No DHCP" unless CYW43.dhcp_supplied?
puts "IP: #{CYW43.ipv4_address}"

# HTTP GET（ローカルLAN内のSinatraへ）
client = Net::HTTPClient.new(HOST, PORT)
res = client.get("/hello")
if res
  puts "status: #{res[:status]}"
  puts "body:\n#{res[:body]}"
else
  puts "no response"
end
```

### Pico 2 Wでの注意点
- Sinatra側のファイアウォールでポートを開け、`bind '0.0.0.0'`を指定。
- 電波状況で失敗する場合はAPを近づけるかチャンネルを調整。
- HTTPS利用時は`picoruby-mbedtls`を入れ、CA証明書を同梱（証明書サイズとRAM/フラッシュに注意）。

## HTTP/HTTPSクライアントの最小例
PicoRuby標準の簡易HTTPクライアント（`picoruby-net`）を利用します。

```ruby
require 'net'

# HTTP
client = Net::HTTPClient.new("example.com", 80)
res = client.get("/api/data")
puts res[:status]
puts res[:body]

# HTTPS（TLSが必要な場合、ビルドに picoruby-mbedtls を含める）
https = Net::HTTPSClient.new("api.example.com", 443)
res = https.get("/secure/data")
puts res[:status]
```

## Quectelセルラーモデム経由で通信する場合
`picoruby-quectel_cellular`を有効化し、UART経由でモジュールを操作します（対応: EC21/EC20/BG96）。

```ruby
require 'quectel_cellular'

uart = UART.new(unit: :RP2040_UART1, txd_pin: 8, rxd_pin: 9, baudrate: 115200)
client = QuectelCellular::UDPClient.new(uart: uart)
client.check_sim_status
client.configure_and_activate_context
client.send("example.com", 1234, "Hello, World!")
```

- HTTPS送信の実例は`mrbgems/picoruby-quectel_cellular/example/ambient.rb`を参照。
- APNや認証情報はREADMEのデフォルト（SORACOM向け）を任意に上書き可能。

## デプロイと実行
1. Rubyスクリプトをバイトコード化：`./bin/picorbc app.rb -o main.mrb`
2. R2P2のフラッシュ領域に`main.mrb`を配置（R2P2シェルがある場合はそこからロード／実行）。
3. 事前にネットワークIFの初期化を済ませてからHTTPリクエストを行う。
4. まずはPOSIX版`bin/r2p2 main.rb`で動作確認するとデバッグしやすい。

## つまずきやすいポイント
- TLSを使う場合、CA証明書をファームに同梱し、クライアントでパスを指定する（証明書サイズとRAM/フラッシュ容量に注意）。
- Pico版はメモリが限られるため、リクエスト／レスポンスボディサイズを抑える。
- セルラーの場合はSIM状態確認→PDPコンテキスト有効化を必ず行う。

