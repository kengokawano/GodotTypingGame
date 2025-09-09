# ブラウザでのGZIP圧縮エラー修正

## 問題
ブラウザ環境でHTTPリクエスト時に以下のエラーが発生：
```
ERROR: Condition "err != 0 && err != 1" is true. Returning: FAILED
   at: _process (core/io/stream_peer_gzip.cpp:118)
```

## 原因
HTTPRequestがGZIP圧縮されたレスポンスを受信しようとして、StreamPeerGzipでの展開処理でエラーが発生。

## 修正内容

### QuestionLoader.gd の変更

1. **GZIP受け入れを完全に無効化**
   ```gdscript
   http_request.accept_gzip = false
   ```

2. **追加ヘッダーでの圧縮回避**
   ```gdscript
   var headers = PackedStringArray()
   headers.append("Accept-Encoding: identity")
   headers.append("Content-Encoding: identity")  # 新規追加
   ```

## 修正後のコード
```gdscript
# 圧縮を完全に無効化してエラーを回避
http_request.use_threads = false
http_request.accept_gzip = false

# HTTPヘッダーを設定して圧縮を完全に回避
var headers = PackedStringArray()
headers.append("Accept-Encoding: identity")
headers.append("Content-Encoding: identity")
http_request.request(external_path, headers)
```

## 効果
- ブラウザ環境でのGZIP展開エラーを完全に回避
- 外部JSONファイルの読み込みが安定化
- StreamPeerGzipの処理をバイパス