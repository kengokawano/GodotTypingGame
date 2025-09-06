using Godot;
using System;
using System.Collections.Generic;
using System.Linq;
using TypingGame;
using TypingGame.Data;

public partial class Main : Node2D
{
    private Label _questionLabel;
    private RichTextLabel _kanaProgressLabel;
    private RichTextLabel _kanaLabel;
    private Label _timeLabel;
    private Label _comboLabel;
    private Label _scoreLabel;
    private Label _modeLabel;
    private Timer _gameTimer;

    public enum GameMode { None, TimeAttack, Quest, Debug }

    private GameMode _currentMode = GameMode.None;
    private int _remainingTimeInSeconds = 0;
    private int _questionsCompleted = 0;
    private const int TotalQuestQuestions = 5;
    private bool _isGameStarted = false;
    private int _elapsedTimeInSeconds = 0;
    private int _comboCount = 0;
    private int _totalKeyPresses = 0;
    private readonly List<int> _ranking = new();
    private List<Question> _allQuestions;
    private string _currentQuestionText;
    private readonly Random _random = new();
    private List<string> _currentKana;
    private List<List<string>> _currentRoman;
    private int _currentKanaIndex = 0;
    private List<string> _candidateRomans;
    private int _inputRomanIndex = 0;
    
    // デバッグモード用
    private List<Question> _debugQuestions;
    private int _debugStartId = 0;
    private int _debugEndId = 0;
    private int _debugCurrentIndex = 0;

    public override void _Ready()
    {
        try
        {
            _questionLabel = GetNode<Label>("QuestionLabel");
            _kanaProgressLabel = GetNode<RichTextLabel>("KanaProgressLabel");
            _kanaLabel = GetNode<RichTextLabel>("KanaRitch");
            _timeLabel = GetNode<Label>("TimeLabel");
            _comboLabel = GetNode<Label>("ComboLabel");
            _scoreLabel = GetNode<Label>("ScoreLabel");
            _modeLabel = GetNode<Label>("ModeLabel");
            _gameTimer = GetNode<Timer>("GameTimer");

            _gameTimer.Timeout += OnGameTimerTimeout;
            RomanTypingParserJp.ReadJsonFile();
            LoadQuestions();
            UpdateDisplay();
            
            // デバッグモードチェック
            if (GameData.Instance?.IsDebugMode == true)
            {
                CallDeferred(nameof(StartDebugFromGameData));
            }
            else
            {
                CallDeferred(nameof(StartTimeAttack));
            }
        }
        catch (Exception ex)
        {
            GD.PrintErr($"Error in _Ready: {ex.Message}");
        }
    }

    public override void _Input(InputEvent @event)
    {
        if (!_isGameStarted) return;

        if (@event is InputEventKey eventKey && eventKey.Pressed && !eventKey.IsEcho())
        {
            string inputChar = OS.GetKeycodeString(eventKey.Keycode);
            if (inputChar == "Minus" || inputChar == "Hyphen" || inputChar == "KpSubtract") inputChar = "-";

            if (inputChar.Length == 1)
            {
                inputChar = inputChar.ToLower();
                HandleKeyPress(inputChar);
            }
        }
    }

    private void LoadQuestions()
    {
        try
        {
            _allQuestions = QuestionLoader.LoadQuestionsFromFile("res://assets/data/questions.json");
        }
        catch (Exception ex)
        {
            GD.PrintErr($"Failed to load questions: {ex.Message}");
            _allQuestions = new List<Question>
            {
                new Question { id = 0, text = "Fallback", kana = "あ", tags = new List<string> { "fallback" }, era = 2025 }
            };
        }
    }

    public void StartTimeAttack()
    {
        StartGame(GameMode.TimeAttack);
    }
    
    public void StartDebugMode(int startId, int endId)
    {
        _debugStartId = startId;
        _debugEndId = endId;
        _debugCurrentIndex = 0;
        
        // 指定範囲の問題を抽出
        _debugQuestions = _allQuestions
            .Where(q => q.id >= startId && q.id <= endId)
            .OrderBy(q => q.id)
            .ToList();
            
        if (_debugQuestions.Count == 0)
        {
            GD.PrintErr($"No questions found in range {startId}-{endId}");
            return;
        }
        
        StartGame(GameMode.Debug);
    }
    
    private void StartDebugFromGameData()
    {
        if (GameData.Instance != null)
        {
            StartDebugMode(GameData.Instance.DebugStartId, GameData.Instance.DebugEndId);
            GameData.Instance.ClearDebugMode();
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
            _remainingTimeInSeconds = 10;
        }
        else if (_currentMode == GameMode.Quest)
        {
            _elapsedTimeInSeconds = 0;
            _questionsCompleted = 0;
        }
        else if (_currentMode == GameMode.Debug)
        {
            _elapsedTimeInSeconds = 0;
            _questionsCompleted = 0;
        }

        LoadNextQuestion();
        _gameTimer.Start();
    }

    private void LoadNextQuestion()
    {
        _currentKanaIndex = 0;
        _inputRomanIndex = 0;
        _candidateRomans = null;

        Question question;
        if (_currentMode == GameMode.Debug)
        {
            if (_debugCurrentIndex >= _debugQuestions.Count)
            {
                FinishGame();
                return;
            }
            question = _debugQuestions[_debugCurrentIndex];
        }
        else
        {
            question = _allQuestions[_random.Next(_allQuestions.Count)];
        }
        
        _currentQuestionText = question.text;
        (_currentKana, _currentRoman) = RomanTypingParserJp.ConstructTypeSentence(question.kana);
        UpdateDisplay();
    }

    private void FinishGame()
    {
        _gameTimer.Stop();
        _isGameStarted = false;
        
        int finalScore = _currentMode == GameMode.TimeAttack ? _totalKeyPresses : _elapsedTimeInSeconds;
        GameData.Instance?.SetScore(finalScore);
        GetTree().ChangeSceneToFile("res://assets/scense/Control.tscn");
        
        _currentMode = GameMode.None;
    }

    private void UpdateDisplay()
    {
        if (!_isGameStarted)
        {
            _questionLabel.Text = "Typing Game";
            _kanaProgressLabel.Text = "";
            _kanaLabel.Text = "Press a button to start";
            _timeLabel.Text = "";
            _comboLabel.Text = "";
            _scoreLabel.Text = "";
            _modeLabel.Text = "READY";
            return;
        }

        // 1行目: 問題文（漢字あり）
        _questionLabel.Text = _currentQuestionText;
        
        // 2行目: かな全体の進捗表示
        var kanaProgressText = "";
        for (int i = 0; i < _currentKana.Count; i++)
        {
            if (i < _currentKanaIndex)
            {
                // 完了済み（赤色）
                kanaProgressText += $"[color=#ff7f7f]{_currentKana[i]}[/color]";
            }
            else if (i == _currentKanaIndex)
            {
                // 現在入力中（青色で大きく）
                kanaProgressText += $"[color=blue][font_size=42]{_currentKana[i]}[/font_size][/color]";
            }
            else
            {
                // 未入力（通常色）
                kanaProgressText += _currentKana[i];
            }
        }
        _kanaProgressLabel.Text = kanaProgressText;

        // 3行目: 入力すべきキー表示
        var currentKana = _currentKana.Count > _currentKanaIndex ? _currentKana[_currentKanaIndex] : "";
        var currentRomans = _currentRoman.Count > _currentKanaIndex ? _currentRoman[_currentKanaIndex] : new List<string>();
        string romanText;

        if (_candidateRomans != null && _candidateRomans.Any() && _inputRomanIndex > 0)
        {
            var formattedCandidates = _candidateRomans.Select(r =>
            {
                var completed = r.Substring(0, _inputRomanIndex);
                var nextChar = _inputRomanIndex < r.Length ? r[_inputRomanIndex].ToString() : "";
                var remaining = _inputRomanIndex + 1 < r.Length ? r.Substring(_inputRomanIndex + 1) : "";
                
                if (!string.IsNullOrEmpty(nextChar))
                {
                    return $"[color=#ff7f7f]{completed}[/color][color=yellow]{nextChar}[/color]{remaining}";
                }
                else
                {
                    return $"[color=#ff7f7f]{completed}[/color]";
                }
            });
            romanText = string.Join("   ", formattedCandidates);
        }
        else
        {
            var formattedRomans = currentRomans.Select(r =>
            {
                if (r.Length > 0)
                {
                    var firstChar = r[0].ToString();
                    var remaining = r.Length > 1 ? r.Substring(1) : "";
                    return $"[color=yellow]{firstChar}[/color]{remaining}";
                }
                return r;
            });
            romanText = string.Join("   ", formattedRomans);
        }
        _kanaLabel.Text = romanText;

        // コンボ表示（3コンボ以下なら非表示）
        if (_comboCount > 3)
        {
            _comboLabel.Text = $"{_comboCount}コンボ";
        }
        else
        {
            _comboLabel.Text = "";
        }

        // モード別表示
        if (_currentMode == GameMode.Quest)
        {
            _timeLabel.Text = $"{_elapsedTimeInSeconds}秒経過";
            _scoreLabel.Text = $"Q: {_questionsCompleted + 1}/{TotalQuestQuestions}";
            _modeLabel.Text = "QUEST";
        }
        else if (_currentMode == GameMode.TimeAttack)
        {
            _timeLabel.Text = $"{_remainingTimeInSeconds}";
            _scoreLabel.Text = $"Score: {_totalKeyPresses}";
            _modeLabel.Text = "TIME ATTACK";
        }
        else if (_currentMode == GameMode.Debug)
        {
            var currentId = _debugCurrentIndex < _debugQuestions.Count ? _debugQuestions[_debugCurrentIndex].id : -1;
            _timeLabel.Text = $"ID: {currentId}";
            _scoreLabel.Text = $"{_questionsCompleted}/{_debugQuestions.Count}";
            _modeLabel.Text = $"DEBUG ({_debugStartId}-{_debugEndId})";
        }
    }

    private void HandleKeyPress(string inputChar)
    {
        if (string.IsNullOrEmpty(inputChar)) return;

        _totalKeyPresses++;

        var allRomans = _currentRoman.Count > _currentKanaIndex ? _currentRoman[_currentKanaIndex] : new List<string>();

        if (_inputRomanIndex == 0)
        {
            _candidateRomans = allRomans.Where(r => r.StartsWith(inputChar)).ToList();
            if (_candidateRomans.Any())
            {
                _inputRomanIndex = 1;
            }
            else
            {
                _comboCount = 0;
            }
        }
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
                _inputRomanIndex = 0;
                _candidateRomans = null;
                _comboCount = 0;
                HandleKeyPress(inputChar);
                return;
            }
        }

        if (_candidateRomans != null && _candidateRomans.Any(r => r.Length == _inputRomanIndex))
        {
            _currentKanaIndex++;
            _inputRomanIndex = 0;
            _candidateRomans = null;
            _comboCount++;

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
                else if (_currentMode == GameMode.Debug)
                {
                    _questionsCompleted++;
                    _debugCurrentIndex++;
                }
                LoadNextQuestion();
                return;
            }
        }

        UpdateDisplay();
    }


    private void OnGameTimerTimeout()
    {
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

