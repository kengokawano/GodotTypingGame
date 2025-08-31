
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Newtonsoft.Json;
using Godot;

namespace TypingGame.Data
{
    public class Question
    {
        public int id { get; set; }
        public string text { get; set; }
        public string kana { get; set; }
        public List<string> tags { get; set; }
        public int era { get; set; }
    }

    public static class QuestionLoader
    {
        /// <summary>
        //* 指定されたパスのJSONファイルを読み込み、Questionオブジェクトのリストを返す
        //* </summary>
        //* <param name = "filePath" > 読み込むJSONファイルのパス </ param >
        //* < returns > Questionオブジェクトのリスト </ returns >
        public static List<Question> LoadQuestionsFromFile(string filePath)
        {

            string jsonText = Godot.FileAccess.GetFileAsString(filePath);

            // ★★★ 修正箇所 ★★★
            // JsonConvert.DeserializeObject を使うだけ。オプションは不要。
            List<Question> questions = JsonConvert.DeserializeObject<List<Question>>(jsonText);

            return questions;

        }
    }
}
