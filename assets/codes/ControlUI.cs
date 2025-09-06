using Godot;
using System;

public partial class ControlUI : CanvasLayer
{
    private Button _btnStart;
    private Button _btnDebugToggle;
    private Panel _debugPanel;
    private LineEdit _startIdInput;
    private LineEdit _endIdInput;
    private Button _btnDebugStart;
    private Button _btnDebugClose;

    /// <summary>
    /// 結果画面のノード
    /// </summary>
    private Label _laScoreLabel => GetNode<Label>("laScore");


    public override void _Ready()
    {
        try
        {
            _btnStart = GetNode<Button>("btnStart");
            _btnStart.Pressed += OnStartButtonPressed;
            
            // デバッグ関連のノードを取得
            _btnDebugToggle = GetNode<Button>("btnDebugToggle");
            _debugPanel = GetNode<Panel>("DebugPanel");
            _startIdInput = GetNode<LineEdit>("DebugPanel/StartIdInput");
            _endIdInput = GetNode<LineEdit>("DebugPanel/EndIdInput");
            _btnDebugStart = GetNode<Button>("DebugPanel/btnDebugStart");
            _btnDebugClose = GetNode<Button>("DebugPanel/btnDebugClose");
            
            // デバッグボタンのシグナル接続
            _btnDebugToggle.Pressed += OnDebugTogglePressed;
            _btnDebugStart.Pressed += OnDebugStartPressed;
            _btnDebugClose.Pressed += OnDebugClosePressed;
            
            if (GameData.Instance?.HasValidScore() == true)
            {
                int score = GameData.Instance.GetScore();
                _laScoreLabel.Text = $"あなたのスコア: {score}";
                GameData.Instance.ClearScore();
            }
            else
            {
                _laScoreLabel.Text = "スタートボタンを押してゲームを始めよう！";
            }
        }
        catch (Exception e)
        {
            GD.PrintErr($"Error in ControlUI _Ready: {e.Message}");
            _laScoreLabel.Text = e.Message;
        }
    }

    private void OnStartButtonPressed()
    {
        _btnStart.Text = "Loading...";
        GetTree().ChangeSceneToFile("res://assets/scense/Main.tscn");
    }
    
    private void OnDebugTogglePressed()
    {
        _debugPanel.Visible = !_debugPanel.Visible;
    }
    
    private void OnDebugStartPressed()
    {
        string startText = _startIdInput.Text;
        string endText = _endIdInput.Text;
        
        if (int.TryParse(startText, out int startId) && int.TryParse(endText, out int endId))
        {
            if (startId <= endId)
            {
                GameData.Instance?.SetDebugMode(startId, endId);
                _btnDebugStart.Text = "Loading...";
                GetTree().ChangeSceneToFile("res://assets/scense/Main.tscn");
            }
            else
            {
                GD.PrintErr("Start ID must be less than or equal to End ID");
            }
        }
        else
        {
            GD.PrintErr("Please enter valid numbers for Start ID and End ID");
        }
    }
    
    private void OnDebugClosePressed()
    {
        _debugPanel.Visible = false;
    }

}
