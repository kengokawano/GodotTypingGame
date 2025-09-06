using Godot;
using System;

public partial class ControlUI : CanvasLayer
{

    private Button _btnStart;

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

}
