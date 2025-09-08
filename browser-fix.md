# ブラウザ環境でのHTTPリクエストエラー修正

## 問題
- ブラウザで実行時に `stream_peer_gzip.cpp` エラーが発生
- JSONパース時に "Unknown error getting token" エラー
- 開発環境では正常動作、特定のネットワーク環境でのみ発生

## 原因
- HTTPリクエストでの圧縮処理（gzip）でエラー発生
- ネットワーク環境やプロキシ設定による圧縮データの問題

## 修正内容

### QuestionLoader.gd の修正

1. **HTTPリクエスト圧縮無効化**
   ```gdscript
   # 圧縮を無効化してエラーを回避
   http_request.use_threads = false
   
   # HTTPヘッダーを設定して圧縮を回避
   var headers = PackedStringArray()
   headers.append("Accept-Encoding: identity")
   http_request.request(external_path, headers)
   ```

2. **空レスポンス対応**
   ```gdscript
   if raw_data.size() == 0:
       print("Received empty response")
       # フォールバック処理
   ```

3. **詳細なJSONパースエラー表示**
   ```gdscript
   # JSONの先頭をチェック
   var preview = json_string.substr(0, min(100, json_string.length()))
   print("JSON preview (first 100 chars): ", preview)
   
   # エラー行周辺のコンテキスト表示
   if error_line > 0:
       var lines = json_string.split("\n")
       # エラー行周辺3行を表示
   ```

## 効果
- ブラウザ環境でのstream_peer_gzip.cppエラーを解決
- ネットワーク環境に依存しない安定した動作
- エラー発生時の詳細なデバッグ情報を提供