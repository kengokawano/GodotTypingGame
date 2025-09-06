# Godot 3 Migration Guide

## 概要
このプロジェクトをGodot 4からGodot 3に移行し、C#スクリプトを維持するためのガイドです。

## 1. プロジェクト設定の変更

### project.godot の主要変更点
```ini
[application]
config/name="TypingGame"
run/main_scene="res://assets/scenes/Control.tscn"

[mono]
project/assembly_name="TypingGame"

[rendering]
environment/default_environment="res://default_env.tres"
```

### 削除する設定
- `config/features` (Godot 3では不要)
- `[dotnet]` セクション全体
- `[rendering]` の `renderer/rendering_method` など

## 2. シーンファイル (.tscn) の変更

### 基本構造の変更
Godot 4 → Godot 3:
```
[gd_scene load_steps=4 format=3]  →  [gd_scene load_steps=4 format=2]
```

### ノード構造の変更
- `CanvasLayer` → そのまま使用可能
- `VBoxContainer`, `HBoxContainer` → そのまま使用可能
- `RichTextLabel` → そのまま使用可能

### 主要な変更点
1. **アンカー設定**:
   ```
   anchors_preset = 15  →  anchor_left = 0.0, anchor_right = 1.0, etc.
   ```

2. **レイアウトモード**:
   ```
   layout_mode = 2  →  削除（Godot 3では不要）
   ```

## 3. C#スクリプトの変更

### 基本的な変更
1. **名前空間**:
   ```csharp
   using Godot;  // そのまま
   ```

2. **ノード継承**:
   ```csharp
   public class Main : CanvasLayer  // そのまま
   ```

### 主要なAPI変更

#### ファイルアクセス
Godot 4:
```csharp
var json_str = FileAccess.GetFileAsString("res://data.json");
```
Godot 3:
```csharp
var file = new File();
file.Open("res://data.json", File.ModeFlags.Read);
var json_str = file.GetAsText();
file.Close();
```

#### JSON解析
Godot 4:
```csharp
var json = new Json();
var parse_result = json.Parse(json_str);
var data = json.Data;
```
Godot 3:
```csharp
var json_parse_result = JSON.Parse(json_str);
if (json_parse_result.Error == Error.Ok)
{
    var data = json_parse_result.Result;
}
```

#### 文字列操作
Godot 4:
```csharp
str.Substr(0, 2)
```
Godot 3:
```csharp
str.Substr(0, 2)  // そのまま使用可能
```

#### 配列操作
Godot 4:
```csharp
var arr = new Array<string>();
```
Godot 3:
```csharp
var arr = new Godot.Collections.Array<string>();
```

## 4. 移行するファイル一覧

### C#スクリプト
- `Main.cs` → `Main.cs` (API変更適用)
- `ControlUI.cs` → `ControlUI.cs` (API変更適用)
- `GameData.cs` → `GameData.cs` (AutoLoad設定)
- `Question.cs` → `Question.cs` (そのまま)
- `RomanTypingParser.cs` → `RomanTypingParser.cs` (ファイルアクセス変更)

### シーンファイル
- `Control.tscn` → format=2に変更、レイアウト調整
- `Main.tscn` → format=2に変更、レイアウト調整

### データファイル
- `questions.json` → そのまま
- `romanTypingParseDictionary.json` → そのまま

### アセット
- `assets/fonts/` → そのまま
- その他のアセット → そのまま

## 5. 移行手順

### Step 1: 新規Godot 3プロジェクト作成
1. Godot 3.5を使用
2. C#プロジェクトとして作成
3. プロジェクト名: TypingGame

### Step 2: ファイル構造作成
```
assets/
  codes/
  scenes/
  fonts/
  data/
```

### Step 3: スクリプト移行
1. 各C#ファイルをコピー
2. API変更を適用
3. ビルドエラーを修正

### Step 4: シーンファイル再作成
1. Control.tscn を手動で再作成
2. Main.tscn を手動で再作成
3. ノード配置とプロパティ設定

### Step 5: テスト
1. デバッグモードでテスト
2. 通常ゲームモードでテスト
3. UI表示の確認

## 6. 注意点

### パフォーマンス
- Godot 3はGodot 4より軽量
- C#のパフォーマンスは安定

### 互換性
- Web出力: Godot 3でもC#はWeb出力不可
- モバイル: C#はAndroid/iOS対応

### デバッグ
- Godot 3のデバッガーは安定
- C#デバッグはVisual Studio推奨

## 7. 予想される問題と解決策

### ファイルアクセスエラー
- File.Open()の戻り値チェックを追加
- try-catchでエラーハンドリング

### JSON解析エラー
- JSON.Parse()の結果をチェック
- エラーハンドリングを強化

### レイアウト崩れ
- アンカー設定を手動で調整
- サイズフラグを適切に設定

### AutoLoadエラー
- project.godotでAutoLoad設定確認
- singletonパターンの実装確認

## 8. 完了後の確認項目
- [ ] プロジェクトが正常にビルドできる
- [ ] Control画面が正しく表示される
- [ ] ゲームが開始できる
- [ ] タイピング機能が動作する
- [ ] デバッグモードが動作する
- [ ] スコア表示が正常
- [ ] タイマーが正常に動作する