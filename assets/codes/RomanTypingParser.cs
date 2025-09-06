using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using Newtonsoft.Json;
using Godot;

namespace TypingGame
{
    public static class RomanTypingParserJp
    {
        private static readonly Dictionary<string, string[]> _mappingDictionary = new();

        public static void ReadJsonFile()
        {
            if (_mappingDictionary.Count > 0) return;

            string jsonStr = Godot.FileAccess.GetFileAsString("res://assets/codes/romanTypingParseDictionary.json");
            var jsonData = JsonConvert.DeserializeObject<RomanMapping[]>(jsonStr);
            if (jsonData == null)
            {
                throw new InvalidDataException("Error: JsonData is null");
            }

            foreach (var mapData in jsonData)
            {
                _mappingDictionary[mapData.Pattern] = mapData.TypePattern;
            }
        }

        public static (List<string>, List<List<string>>) ConstructTypeSentence(string sentenceHiragana)
        {
            var idx = 0;
            var judge = new List<List<string>>();
            var parsedStr = new List<string>();

            while (idx < sentenceHiragana.Length)
            {
                List<string> validTypeList;

                var uni = sentenceHiragana[idx].ToString();
                var bi = (idx + 1 < sentenceHiragana.Length) ? sentenceHiragana.Substring(idx, 2) : "";
                var tri = (idx + 2 < sentenceHiragana.Length) ? sentenceHiragana.Substring(idx, 3) : "";

                // Special-case: Katakana long vowel mark 'ー'
                if (uni == "ー")
                {
                    validTypeList = new List<string> { "-" };
                    idx += 1;
                    parsedStr.Add(uni);
                }
                else if (_mappingDictionary.ContainsKey(tri))
                {
                    validTypeList = _mappingDictionary[tri].ToList();
                    idx += 3;
                    parsedStr.Add(tri);
                }
                else if (_mappingDictionary.ContainsKey(bi))
                {
                    validTypeList = _mappingDictionary[bi].ToList();
                    idx += 2;
                    parsedStr.Add(bi);
                }
                else if (_mappingDictionary.ContainsKey(uni))
                {
                    validTypeList = _mappingDictionary[uni].ToList();
                    idx++;
                    parsedStr.Add(uni);
                }
                else
                {
                    throw new InvalidDataException($"Error: Unsupported n-gram / uni-gram => {uni}, bi-gram => {bi}, tri-gram => {tri}");
                }

                judge.Add(validTypeList);
            }

            return (parsedStr, judge);
        }
    }

    public class RomanMapping
    {
        public string Pattern { get; set; }
        public string[] TypePattern { get; set; }
    }
}
