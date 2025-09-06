using Godot;

public partial class GameData : Node
{
    public static GameData Instance { get; private set; }
    
    public int LastScore { get; set; } = 0;
    public bool HasScore { get; set; } = false;

    public override void _Ready()
    {
        Instance = this;
    }
    
    public void SetScore(int score)
    {
        LastScore = score;
        HasScore = true;
    }
    
    public int GetScore() => LastScore;
    
    public bool HasValidScore() => HasScore;
    
    public void ClearScore()
    {
        HasScore = false;
        LastScore = 0;
    }
}