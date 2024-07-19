using System.Text.Json;

string outputFolder = "../../deploy/misc";
if (!Directory.Exists(outputFolder)) Directory.CreateDirectory(outputFolder);

int[] lengths = [
    100,
    370,
    1000
];

Func<IEnumerable<string>, (string Extension, string Value)>[] formats = [
    x => (".txt", string.Join("\n", x)),
    x => (".csv", string.Join(",", x)),
    x => (".json", JsonSerializer.Serialize(x))
];

Func<string> generate = () => Random.Shared.Next(10000000, 99999999).ToString();

int maxLength = lengths.Max();

// RIP memory
Console.WriteLine($"Generating {maxLength} ids");
string[] ids = new string[maxLength];
for (int i = 0; i < maxLength; i++)
{
    ids[i] = generate();
}

foreach (var l in lengths)
{
    foreach (var f in formats)
    {
        var (extension, value) = f(ids.Take(l));
        var path = Path.Combine(outputFolder, $"ids_{l}{extension}");
        File.WriteAllText(path, value);
        Console.WriteLine($"Generated {path}");
    }
}

Console.WriteLine("Done");