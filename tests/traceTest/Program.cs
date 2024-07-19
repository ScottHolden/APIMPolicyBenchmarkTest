string apimUrl = "https://fill-in.azure-api.net/api/latency/";
string mockedClientId = "66372705";
string backendClientId = "99999999";

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
List<(string Name, bool Mocked, Dictionary<string, string[]>)> results = new();

static async Task<string> RunTestAsync(Uri url, string clientId)
{
    int warmupRounds = 6; 
    int testingRounds = 24;
    int excludeMaxOutliers = 4;

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
    List<string> traces = new();
    for(int i=0; i< testingRounds; i++)
    {
        traces.Add(await CallForTraceAsync(client, url));
        Console.Write(".");
    }
    Console.WriteLine();

    return $"";
}

static async Task<string> CallForTraceAsync(HttpClient client, Uri url)
{
    using var response = await client.GetAsync(url);
    response.EnsureSuccessStatusCode();
    using var traceResponse = await client.GetAsync();
    traceResponse.EnsureSuccessStatusCode();
    return "";
}