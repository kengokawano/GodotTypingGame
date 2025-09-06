using Godot;
using System;

public partial class ControlUI : CanvasLayer
{
    // シグナルを定義
    [Signal]
    public delegate void StartGameEventHandler();
    
    [Signal]
    public delegate void StartTimeAttackEventHandler();

    private Button _btnStart;

    /// <summary>
    /// 結果画面のノード
    /// </summary>
    private Label _laScoreLabel => GetNode<Label>("laScore");


    public override void _Ready()
    {
        GD.Print("ControlUI _Ready called");
        try
        {
            _btnStart = GetNode<Button>("btnStart");
            GD.Print("Button found successfully");
            _btnStart.Pressed += OnStartButtonPressed;
            GD.Print("Button signal connected");
            
            // スコアがあれば表示
            if (GameData.Instance?.HasValidScore() == true)
            {
                int score = GameData.Instance.GetScore();
                _laScoreLabel.Text = $"あなたのスコア: {score}";
                GameData.Instance.ClearScore();
                GD.Print($"Score displayed: {score}");
            }
            else
            {
                _laScoreLabel.Text = "スタートボタンを押してゲームを始めよう！";
            }
        }
        catch (Exception e)
        {
            GD.PrintErr($"Error in ControlUI _Ready: {e.Message}");
            GetNode<Label>("laScore").Text = e.Message;
        }
    }

    private void OnStartButtonPressed()
    {
        GD.Print("Start button pressed!");
        _btnStart.Text = "Loading...";
        GD.Print("About to change scene to Main.tscn");
        var result = GetTree().ChangeSceneToFile("res://assets/scense/Main.tscn");
        GD.Print($"Scene change result: {result}");
    }

    /// <summary>
    /// 結果画面を表示する（Main.csから呼び出される）
    /// </summary>
    /// <param name="score">スコア</param>
    public void ShowResult(int score)
    {
        _laScoreLabel.Text = $"あなたのスコア: {score}";
       
    }
}
