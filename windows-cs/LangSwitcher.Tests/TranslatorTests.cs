using System.Collections.Generic;
using Xunit;
using LangSwitcher;

namespace LangSwitcher.Tests
{
    public class TranslatorTests
    {
        private List<string> _enabledLangs = new() { "en", "ru", "ua" };
        private Dictionary<string, string> _mappings = new();
        private HashSet<string> _exceptions = new();

        [Theory]
        [InlineData("ghbdtn", "привет", "ru")]
        [InlineData("hello", null, null)] // Already valid English
        [InlineData("цкщтп", "wrong", "en")]
        [InlineData("і", "s", "en")] // single letters that map
        public void ChooseCorrection_Tests(string input, string expectedWord, string expectedLang)
        {
            var (word, lang) = Translator.ChooseCorrection(input, _enabledLangs, _mappings, _exceptions);
            Assert.Equal(expectedWord, word);
            Assert.Equal(expectedLang, lang);
        }

        [Fact]
        public void ChooseCorrection_UaOnly()
        {
            var (word, lang) = Translator.ChooseCorrection("ghbdsn", new List<string> { "en", "ua" }, _mappings, _exceptions);
            Assert.Equal("привіт", word);
            Assert.Equal("ua", lang);
        }

        [Fact]
        public void ChooseCorrection_WithCustomMapping()
        {
            var mappings = new Dictionary<string, string> { { "custom", "кастом" } };
            var (word, lang) = Translator.ChooseCorrection("custom", _enabledLangs, mappings, _exceptions);
            Assert.Equal("кастом", word);
            Assert.Equal("ru", lang); // default Cyrillic fallback for custom mappings without specific UA letters
        }

        [Fact]
        public void ChooseCorrection_WithException()
        {
            var exceptions = new HashSet<string> { "ghbdsn" };
            var (word, lang) = Translator.ChooseCorrection("ghbdsn", _enabledLangs, _mappings, exceptions);
            Assert.Null(word);
            Assert.Null(lang);
        }

        [Theory]
        [InlineData("hello", "ua", "руддщ", "ua")]
        [InlineData("привіт", "en", "ghbdsn", "en")]
        public void ForceTranslate_Tests(string input, string targetLangHint, string expectedWord, string expectedLang)
        {
            var (word, lang) = Translator.ForceTranslate(input, targetLangHint);
            Assert.Equal(expectedWord, word);
            Assert.Equal(expectedLang, lang);
        }
    }
}
