using System.Diagnostics;

string apimUrl = "https://perftest-api-czg2m6zlvmmwc.azure-api.net/api/latency/";
string mockedClientId = "66372705";
string backendClientId = "99999999";

int warmupRounds = 20; 
int testingRounds = 550;
int excludeMaxOutliers = 50;

Dictionary<string, string> endpoints = new Dictionary<string, string>
{
    { "Only Mock" , "normal/mock" },
    { "Only Backend" , "normal/backend" },
    { "Mock if found 100 CSV" , "mockiffound/100/csv" },
    { "Mock if found 370 CSV" , "mockiffound/370/csv" },
    { "Mock if found 100 Json" , "mockiffound/100/json" },
    { "Mock if found 370 Json" , "mockiffound/370/json" },
    { "Mock if found 100 policy fragment" , "mockiffound/100/fragment" },
    { "Mock if found 370 policy fragment" , "mockiffound/370/fragment" },
    { "Mock if found 1000 policy fragment" , "mockiffound/1000/fragment" },
};

var baseUri = new Uri(apimUrl);
List<(string Name, bool Mocked, string Data)> results = new();
foreach (var (name, path) in endpoints)
{
    var url = new Uri(baseUri, path);

    if (name  != "Only Backend"){
        Console.WriteLine($"Testing {name} with mocking... ({url})");
        var mockedData = await RunTestAsync(url, mockedClientId);
        results.Add((name, true, mockedData));
    }

    if (name  != "Only Mock"){
        Console.WriteLine($"Testing {name} without mocking... ({url})");
        var backendData = await RunTestAsync(url, backendClientId);
        results.Add((name, false, backendData));
    }
}

Console.WriteLine("Saving results...");
File.WriteAllText("results.csv", "Name,Mocked,Count,Min,Max,Avg\n" + string.Join("\n", results.Select(r => $"{r.Name},{r.Mocked},{r.Data}")));
Console.WriteLine("Done");

async Task<string> RunTestAsync(Uri url, string clientId)
{
    using var client = new HttpClient();
    client.DefaultRequestHeaders.Add("X-Client-Id", clientId);

    Console.Write("Warming up");
    for(int i=0; i<warmupRounds; i++)
    {
        using var response = await client.GetAsync(url);
        response.EnsureSuccessStatusCode();
        Console.Write(".");
    }
    Console.WriteLine();
    
    Console.Write("Calling");
    List<long> times = new();
    for(int i=0; i< testingRounds; i++)
    {
        var sw = Stopwatch.StartNew();
        using var response = await client.GetAsync(url);
        sw.Stop();
        response.EnsureSuccessStatusCode();
        times.Add(sw.ElapsedMilliseconds);
        Console.Write(".");
    }
    Console.WriteLine();

    // Remove outliers
    times = times.OrderByDescending(t => t).Skip(excludeMaxOutliers).ToList();
    var min = times.Min();
    var max = times.Max();
    var avg = times.Average();
    Console.WriteLine($"{times.Count} {min}ms - {max}ms - {avg:0.00}ms");
    return $"{times.Count},{min},{max},{avg:0.00}";
}


record Data(long min, long max, long count, long sum)
{
    public static Data StartingPoint => new Data(long.MaxValue, long.MinValue, 0, 0);
    public Data AddPoint(long value) => new Data(Math.Min(min, value), Math.Max(max, value), count + 1, sum + value);

    public string Results() => $"Min: {min}, Max: {max}, Avg: {sum/(double)count:0.00}";
    public string ResultsCsv() => $"{count},{min},{max},{sum/(double)count:0.00}";
}