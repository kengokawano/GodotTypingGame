using Godot;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using TypingGame; // RomanTypingParserJp
using TypingGame.Data; // Question, QuestionLoader

//https://www.reddit.com/r/godot/comments/wg90nh/debugging_godot_4x_mono_from_vs_code/
// debugのブレーク方法はこちら

public partial class Main : Node2D
{

    [Signal]
    public delegate void GameOverEventHandler(int score);

    private Label _questionLabel;
    private Label _kanaLabel;
    private Label _statsLabel;
    private Timer _gameTimer;

    public enum GameMode { None, TimeAttack, Quest }

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

    public override void _Ready()
    {
        GD.Print("Program started");
        try
        {
            GD.Print("Getting nodes...");
            _questionLabel = GetNode<Label>("QuestionLabel");
            _kanaLabel = GetNode<Label>("KanaLabel");
            _statsLabel = GetNode<Label>("StatsLabel");

            _gameTimer = GetNode<Timer>("GameTimer");
            GD.Print("All nodes found successfully");

            GD.Print("Connecting timer signal...");
            _gameTimer.Timeout += OnGameTimerTimeout;

            GD.Print("Reading JSON file...");
            RomanTypingParserJp.ReadJsonFile();
            
            GD.Print("Loading questions...");
            LoadQuestions();
            
            GD.Print("Updating display...");
            UpdateDisplay();
            
            // ゲームを自動的に開始（少し遅延させる）
            GD.Print("About to call StartTimeAttack deferred");
            CallDeferred(nameof(StartTimeAttack));
            GD.Print("_Ready completed successfully");
        }
        catch (Exception ex)
        {
            GD.PrintErr($"Error in _Ready: {ex.Message}");
            GD.PrintErr($"Stack trace: {ex.StackTrace}");
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
        GD.Print("StartTimeAttack called");
        StartGame(GameMode.TimeAttack);
    }
    
    private void StartGame(GameMode mode)
    {
        GD.Print($"StartGame called with mode: {mode}");
        _currentMode = mode;
        _isGameStarted = true;
        GD.Print($"Game started, _isGameStarted: {_isGameStarted}");

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

        LoadNextQuestion();
        GD.Print("Starting game timer");
        _gameTimer.Start();
        GD.Print($"Timer started, wait_time: {_gameTimer.WaitTime}");
    }

    private void LoadNextQuestion()
    {
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
        
        int finalScore = _currentMode == GameMode.TimeAttack ? _totalKeyPresses : _elapsedTimeInSeconds;
        GD.Print($"Game finished with score: {finalScore}");
        
        // スコアを保存
        GameData.Instance?.SetScore(finalScore);
        
        // Control画面に戻る
        GetTree().ChangeSceneToFile("res://assets/scense/Control.tscn");
        
        _currentMode = GameMode.None;
    }

    private void UpdateDisplay()
    {
        if (!_isGameStarted)
        {
            _kanaLabel.Text = "Press a button to start";
            _questionLabel.Text = "Typing Game";
            _statsLabel.Text = "";
            return;
        }

        _questionLabel.Text = _currentQuestionText;

        var currentKana = _currentKana.Count > _currentKanaIndex ? _currentKana[_currentKanaIndex] : "";
        var currentRomans = _currentRoman.Count > _currentKanaIndex ? _currentRoman[_currentKanaIndex] : new List<string>();
        string romanText;

        if (_candidateRomans != null && _candidateRomans.Any() && _inputRomanIndex > 0)
        {
            var formattedCandidates = _candidateRomans.Select(r =>
            {
                var completed = r.Substring(0, _inputRomanIndex);
                var remaining = r.Substring(_inputRomanIndex);
                return $"[{completed}]{remaining}";
            });
            romanText = string.Join(", ", formattedCandidates);
        }
        else
        {
            romanText = string.Join(", ", currentRomans);
        }
        _kanaLabel.Text = $"{currentKana} : {romanText}";

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
                LoadNextQuestion();
                return;
            }
        }

        UpdateDisplay();
    }

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
    
    private void EmitGameOverSignal()
    {
        int finalScore = _currentMode == GameMode.TimeAttack ? _totalKeyPresses : _elapsedTimeInSeconds;
        EmitSignal(SignalName.GameOver, finalScore);
    }
}

