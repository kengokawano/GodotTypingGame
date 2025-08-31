using Godot;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using TypingGame; // RomanTypingParserJp.cs の namespace
using TypingGame.Data; // Question.cs の namespace

public partial class Main : Node2D
{
    // ================================================================
    // UIノードへの参照
    // ================================================================
    private Label _questionLabel;
    private Label _kanaLabel;
    private Label _statsLabel;
    private Button _startTimeAttackButton;
    private Button _startQuestButton;
    private Timer _gameTimer;

    // ================================================================
    // Form1.cs から持ってくるプロパティやフィールド
    // (ほぼそのままコピーできます)
    // ================================================================
    public enum GameMode { None, TimeAttack, Quest }
    private GameMode _currentMode = GameMode.None;
    private int _remainingTimeInSeconds = 0;
    private int _questionsCompleted = 0;
    private const int TotalQuestQuestions = 5;
    private bool _isGameStarted = false;
    private int _elapsedTimeInSeconds = 0;
    private int _comboCount = 0;
    private int _totalKeyPresses = 0;
    private List<int> _ranking = new List<int>();
    private List<Question> _allQuestions;
    private string _currentQuestionText;
    private Random _random = new Random();
    private List<string> _currentKana;
    private List<List<string>> _currentRoman;
    private int _currentKanaIndex = 0;
    private List<string> _candidateRomans;
    private int _inputRomanIndex = 0;

    // ================================================================
    // Godotのライフサイクルメソッド
    // ================================================================

    /// <summary>
    /// ノードがシーンツリーに追加されたときに一度だけ呼ばれる (初期化処理)
    /// </summary>
    public override void _Ready()
    {
        // UIノードへの参照を取得
        _questionLabel = GetNode<Label>("QuestionLabel");
        _kanaLabel = GetNode<Label>("KanaLabel");
        _statsLabel = GetNode<Label>("StatsLabel");
        _startTimeAttackButton = GetNode<Button>("StartTimeAttackButton");
        _startQuestButton = GetNode<Button>("StartQuestButton");
        _gameTimer = GetNode<Timer>("GameTimer");

        // ボタンのシグナル（イベント）を接続
        _startTimeAttackButton.Pressed += OnStartTimeAttackButtonPressed;
        _startQuestButton.Pressed += OnStartQuestButtonPressed;

        // タイマーのシグナルを接続
        _gameTimer.Timeout += OnGameTimerTimeout;

        // ゲームの初期化
        RomanTypingParserJp.ReadJsonFile(); // パース辞書の読み込み
        LoadQuestions();
        UpdateDisplay();
    }

    /// <summary>
    /// キー入力があったときに呼ばれる
    /// </summary>
    public override void _Input(InputEvent @event)
    {
        if (!_isGameStarted) return;

        // キープレスイベントかどうかの判定
        if (@event is InputEventKey eventKey && eventKey.Pressed && !eventKey.IsEcho())
        {
            // 入力された文字を取得
            // GodotではKeycodeからUnicode文字を取得する必要があります
            string inputChar = OS.GetKeycodeString(eventKey.Keycode);

            // 小文字に変換
            if (inputChar == "Minus" || inputChar == "Hyphen" || inputChar == "KpSubtract") inputChar = "-";
            if (inputChar.Length == 1)
            {
                inputChar = inputChar.ToLower();
                HandleKeyPress(inputChar); // Form1_KeyPress内のロジックを呼び出す
            }
        }
    }


    // ================================================================
    // Form1.cs から移植するメソッド群
    // (メソッドの中身はほぼそのままコピーできます)
    // ================================================================

    private void LoadQuestions()
    {
        try
        {
            GD.Print("  Loading questions from JSON file...");
            // Godotのファイルパス (res://) を使用
            _allQuestions = QuestionLoader.LoadQuestionsFromFile("res://questions.json");


            GD.Print($"問題ファイルを正常に読み込みました。問題数: {_allQuestions.Count}" );
        }
        catch (Exception ex)
        {
            GD.PrintErr($"問題ファイルの読み込みに失敗しました: {ex.Message}");
            // エラー時のダミー問題
            _allQuestions = new List<Question>
            {
                new Question { id = 0, text = "エラー", kana = "えらー", tags = new List<string> { "エラー" }, era = 2025 }
            };
        }
    }

    private void StartGame(GameMode mode)
    {
        _currentMode = mode;
        _isGameStarted = true;

        _comboCount = 0;
        _totalKeyPresses = 0;
        _currentKanaIndex = 0;
        _inputRomanIndex = 0;
        _candidateRomans = null;

        if (_currentMode == GameMode.TimeAttack)
        {
            _remainingTimeInSeconds = 60;
        }
        else if (_currentMode == GameMode.Quest)
        {
            _elapsedTimeInSeconds = 0;
            _questionsCompleted = 0;
        }

        // UIの表示/非表示
        _startTimeAttackButton.Visible = false;
        _startQuestButton.Visible = false;

        LoadNextQuestion();
        _gameTimer.Start();
    }

    private void LoadNextQuestion()
    {

        GD.Print("LoadNextQuestion called");
        _currentKanaIndex = 0;
        _inputRomanIndex = 0;
        _candidateRomans = null;

        var question = _allQuestions[_random.Next(_allQuestions.Count)];
        _currentQuestionText = question.text;



        (_currentKana, _currentRoman) = RomanTypingParserJp.ConstructTypeSentence(question.kana);

        UpdateDisplay();
    }

    private void FinishGame()
    {
        _gameTimer.Stop();
        _isGameStarted = false;
        var sb = new StringBuilder();

        if (_currentMode == GameMode.Quest)
        {
            sb.AppendLine("🎉🎉🎉 クエストクリア！ 🎉🎉🎉");
            sb.AppendLine($"クリアタイム: {_elapsedTimeInSeconds} 秒");
            sb.AppendLine($"総タイプ数: {_totalKeyPresses}");
        }
        else if (_currentMode == GameMode.TimeAttack)
        {
            sb.AppendLine("⌛⌛⌛ タイムアップ！ ⌛⌛⌛");
            sb.AppendLine($"スコア: {_totalKeyPresses} 打");
        }

        _kanaLabel.Text = sb.ToString();
        _questionLabel.Text = "";

        // スタートボタンを再表示
        _startTimeAttackButton.Visible = true;
        _startQuestButton.Visible = true;

        _currentMode = GameMode.None;
    }


    private void UpdateDisplay()
    {
        if (!_isGameStarted)
        {
            _kanaLabel.Text = "モードを選んでスタートしてください";
            _questionLabel.Text = "タイピングゲーム";
            _statsLabel.Text = "";
            return;
        }

        // --- ゲーム中の表示 ---

        // 1. 問題文の表示
        _questionLabel.Text = _currentQuestionText;

        // 2. 現在のターゲット（かな＋ローマ字）の表示
        var currentKana = _currentKana.Count > _currentKanaIndex ? _currentKana[_currentKanaIndex] : "";
        var currentRomans = _currentRoman.Count > _currentKanaIndex ? _currentRoman[_currentKanaIndex] : new List<string>();
        string romanText;

        if (_candidateRomans != null && _candidateRomans.Any() && _inputRomanIndex > 0)
        {
            // 入力中の場合、入力済み部分と未入力部分を分けて表示
            var formattedCandidates = _candidateRomans.Select(r =>
            {
                var completed = r.Substring(0, _inputRomanIndex);
                var remaining = r.Substring(_inputRomanIndex);
                return $"[{completed}]{remaining}"; // 例: [k]a
            });
            romanText = string.Join(", ", formattedCandidates);
        }
        else
        {
            // 初期状態の場合、すべての候補を表示
            romanText = string.Join(", ", currentRomans);
        }
        _kanaLabel.Text = $"{currentKana} : {romanText}";

        // 3. 統計情報の表示
        string statsText = "";
        if (_currentMode == GameMode.Quest)
        {
            statsText = $"Time: {_elapsedTimeInSeconds}s | Combo: {_comboCount} | Q: {_questionsCompleted + 1}/{TotalQuestQuestions}";
        }
        else if (_currentMode == GameMode.TimeAttack)
        {
            statsText = $"Time Left: {_remainingTimeInSeconds}s | Combo: {_comboCount} | Score: {_totalKeyPresses}";
        }
        _statsLabel.Text = statsText;
    }

    private void HandleKeyPress(string inputChar)
    {
        if (string.IsNullOrEmpty(inputChar)) return;

        _totalKeyPresses++;

        // 現在のかなに対応するローマ字リストを取得
        var allRomans = _currentRoman.Count > _currentKanaIndex ? _currentRoman[_currentKanaIndex] : new List<string>();

        // 1. 最初の文字の入力処理
        if (_inputRomanIndex == 0)
        {
            _candidateRomans = allRomans.Where(r => r.StartsWith(inputChar)).ToList();
            if (_candidateRomans.Any())
            {
                _inputRomanIndex = 1;
            }
            else
            {
                _comboCount = 0; // ミス
            }
        }
        // 2. 二文字目以降の入力処理
        else
        {
            var nextCandidates = _candidateRomans
                .Where(r => r.Length > _inputRomanIndex && r[_inputRomanIndex].ToString() == inputChar)
                .ToList();

            if (nextCandidates.Any())
            {
                _candidateRomans = nextCandidates;
                _inputRomanIndex++;
            }
            else
            {
                // ミス：状態をリセットして、もう一度最初の文字から
                _inputRomanIndex = 0;
                _candidateRomans = null;
                _comboCount = 0;
                // ミスしたが、今回の入力が別の候補の先頭文字かもしれないので再評価
                HandleKeyPress(inputChar);
                return; // 再帰呼び出ししたので、この後の処理は不要
            }
        }

        // 3. かな入力完了の判定
        if (_candidateRomans != null && _candidateRomans.Any(r => r.Length == _inputRomanIndex))
        {
            _currentKanaIndex++; // 次のかなへ
            _inputRomanIndex = 0;
            _candidateRomans = null;
            _comboCount++;

            // 4. 1問すべての入力が完了したかどうかの判定
            if (_currentKanaIndex >= _currentKana.Count)
            {
                if (_currentMode == GameMode.Quest)
                {
                    _questionsCompleted++;
                    if (_questionsCompleted >= TotalQuestQuestions)
                    {
                        FinishGame();
                        return;
                    }
                }
                LoadNextQuestion(); // 次の問題へ
                return;
            }
        }

        // 5. 表示の更新
        UpdateDisplay();
    }


    // ================================================================
    // シグナルハンドラ (イベント処理)
    // ================================================================

    private void OnStartTimeAttackButtonPressed()
    {
        StartGame(GameMode.TimeAttack);
    }

    private void OnStartQuestButtonPressed()
    {
        StartGame(GameMode.Quest);
    }

    private void OnGameTimerTimeout()
    {
        // (Form1.csのGameTimer_Tickの中身を移植)
        if (_currentMode == GameMode.Quest)
        {
            _elapsedTimeInSeconds++;
        }
        else if (_currentMode == GameMode.TimeAttack)
        {
            _remainingTimeInSeconds--;
            if (_remainingTimeInSeconds <= 0)
            {
                FinishGame();
            }
        }
        UpdateDisplay();
    }
}
